// account-withdraw — 회원탈퇴 표준 Edge Function 템플릿 (재인증형 하이브리드)
//
// 클라이언트 흐름 (AuthKit):
//   1. 탈퇴 직전 `AuthService.reauthenticate(provider:)` 로 fresh credential 확보
//   2. `WithdrawalCredential(folding:)` 로 접어 이 함수 본문에 실어 호출
//   3. 성공 시 `AuthService.endSession()` 으로 로컬 정리
//
// 서버 처리:
//   - Apple:  재인증 authorizationCode → Apple 토큰 교환 → refresh token revoke
//   - Google: 재인증 access token → Google revoke 엔드포인트
//   - Kakao:  admin key + auth identities 의 kakao user id 로 unlink (클라 credential 불필요)
//   - revoke 는 best-effort — 실패해도 계정 삭제는 진행한다 (재인증 거부 시 credential
//     없이 호출해도 동일하게 동작)
//   - 마지막에 auth.admin.deleteUser 로 사용자 삭제
//
// 필요한 secrets (supabase secrets set KEY=VALUE):
//   APPLE_TEAM_ID       Apple Developer 팀 ID
//   APPLE_CLIENT_ID     앱 번들 ID (native signInWithIdToken 기준)
//   APPLE_KEY_ID        Sign in with Apple Key ID
//   APPLE_PRIVATE_KEY   .p8 키 내용 (BEGIN/END 라인 포함, 개행은 \n)
//   KAKAO_ADMIN_KEY     Kakao 어드민 키
// (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY 는 런타임이 자동 주입)
//
// 배포: supabase functions deploy account-withdraw

import { createClient } from "npm:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "npm:jose@5";

type WithdrawBody = {
  credential?:
    | { provider: "apple"; authorizationCode: string }
    | { provider: "google"; token: string }
    | { provider: "kakao"; idToken?: string };
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  if (!jwt) {
    return json({ error: "missing_authorization" }, 401);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 호출자의 access token 으로 본인 확인 — 남의 계정을 지울 수 없다.
  const { data: userData, error: userError } = await admin.auth.getUser(jwt);
  if (userError || !userData.user) {
    return json({ error: "invalid_token" }, 401);
  }
  const user = userData.user;

  const body: WithdrawBody = await req.json().catch(() => ({}));
  const revoked: Record<string, string> = {};

  // ── 1. 소셜 토큰 revoke (best-effort) ─────────────────────────────────
  try {
    const credential = body.credential;

    if (credential?.provider === "apple") {
      await revokeApple(credential.authorizationCode);
      revoked.apple = "ok";
    } else if (credential?.provider === "google") {
      await revokeGoogle(credential.token);
      revoked.google = "ok";
    }

    // Kakao 는 클라 credential 없이 admin key 로 unlink — identities 에서 찾는다.
    const kakaoIdentity = user.identities?.find((i) => i.provider === "kakao");
    if (kakaoIdentity) {
      await unlinkKakao(kakaoIdentity.id);
      revoked.kakao = "ok";
    }
  } catch (e) {
    // revoke 실패는 삭제를 막지 않는다 — 로그만 남긴다.
    console.error("revoke failed (continuing):", e);
    revoked.error = String(e);
  }

  // ── 2. 앱 데이터 정리 ─────────────────────────────────────────────────
  // public 스키마의 사용자 데이터는 FK ON DELETE CASCADE 로 함께 지워지게
  // 설계하는 것을 권장. CASCADE 가 없다면 여기서 명시적으로 삭제한다:
  //   await admin.from("users").delete().eq("id", user.id);

  // ── 3. auth 사용자 삭제 ───────────────────────────────────────────────
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    return json({ error: "delete_failed", detail: deleteError.message }, 500);
  }

  return json({ success: true, revoked });
});

// ── Apple: authorizationCode → 토큰 교환 → refresh token revoke ──────────

async function revokeApple(authorizationCode: string): Promise<void> {
  const clientId = Deno.env.get("APPLE_CLIENT_ID")!;
  const clientSecret = await appleClientSecret();

  // 1회성 code 를 토큰으로 교환 (재인증 직후라 유효)
  const tokenRes = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }),
  });
  if (!tokenRes.ok) {
    throw new Error(`apple token exchange ${tokenRes.status}: ${await tokenRes.text()}`);
  }
  const { refresh_token } = await tokenRes.json();

  const revokeRes = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      token: refresh_token,
      token_type_hint: "refresh_token",
    }),
  });
  if (!revokeRes.ok) {
    throw new Error(`apple revoke ${revokeRes.status}: ${await revokeRes.text()}`);
  }
}

/// Apple client secret — .p8 키로 서명한 ES256 JWT (매 호출 생성, 유효 5분이면 충분)
async function appleClientSecret(): Promise<string> {
  const teamId = Deno.env.get("APPLE_TEAM_ID")!;
  const keyId = Deno.env.get("APPLE_KEY_ID")!;
  const privateKeyPem = Deno.env.get("APPLE_PRIVATE_KEY")!.replaceAll("\\n", "\n");

  const key = await importPKCS8(privateKeyPem, "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .setExpirationTime("5m")
    .setAudience("https://appleid.apple.com")
    .setSubject(Deno.env.get("APPLE_CLIENT_ID")!)
    .sign(key);
}

// ── Google: access token revoke ──────────────────────────────────────────

async function revokeGoogle(accessToken: string): Promise<void> {
  const res = await fetch(
    `https://oauth2.googleapis.com/revoke?token=${encodeURIComponent(accessToken)}`,
    { method: "POST" },
  );
  // 이미 만료/revoke 된 토큰은 400 — 목적 달성이므로 통과시킨다.
  if (!res.ok && res.status !== 400) {
    throw new Error(`google revoke ${res.status}: ${await res.text()}`);
  }
}

// ── Kakao: admin key unlink ──────────────────────────────────────────────

async function unlinkKakao(targetId: string): Promise<void> {
  const adminKey = Deno.env.get("KAKAO_ADMIN_KEY")!;
  const res = await fetch("https://kapi.kakao.com/v1/user/unlink", {
    method: "POST",
    headers: {
      Authorization: `KakaoAK ${adminKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      target_id_type: "user_id",
      target_id: targetId,
    }),
  });
  if (!res.ok) {
    throw new Error(`kakao unlink ${res.status}: ${await res.text()}`);
  }
}

// ── util ─────────────────────────────────────────────────────────────────

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
