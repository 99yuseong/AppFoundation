/**
 * storage-sign — R2 presigned URL 발급 Worker (AppFoundation 템플릿)
 *
 * 클라이언트(WorkerR2Signer)와의 와이어 계약 — AppFoundation 과 같은 태그로
 * 버전되는 공개 계약이다. 형태를 바꾸면 breaking (CHANGELOG 명시):
 *
 *   요청  POST /  Authorization: Bearer {supabase access token}
 *         {"items":[{"bucket","path","method","contentType"?,"expiresIn"}]}
 *   응답  200 {"urls":[{"url","expiresAt"}]}   — items 순서 보존, all-or-nothing
 *   실패  4xx {"ok":false,"error":{"code","message"}}
 *
 * 역할: Supabase JWT 검증 → 본인 폴더 검사(path 접두 = 토큰 sub — storage RLS 의
 * 대응물) → SigV4 presign. R2 키는 이 Worker 밖으로 나가지 않는다.
 *
 * 시크릿(wrangler secret put): SUPABASE_JWT_SECRET, R2_ACCESS_KEY_ID,
 * R2_SECRET_ACCESS_KEY / vars: R2_ACCOUNT_ID
 */

import { AwsClient } from "aws4fetch";
import { jwtVerify } from "jose";

interface Env {
  SUPABASE_JWT_SECRET: string;
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  R2_ACCOUNT_ID: string;
}

interface SignItem {
  bucket: string;
  path: string;
  method: string;
  contentType?: string;
  expiresIn: number;
}

const MAX_ITEMS = 50;               // 배치 상한 — 목록 화면 1페이지 분량
const MAX_EXPIRES_IN = 24 * 3600;   // 서명 만료 상한(초)
const ALLOWED_METHODS = new Set(["GET", "PUT"]);

function fail(status: number, code: string, message: string): Response {
  return Response.json({ ok: false, error: { code, message } }, { status });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== "POST") {
      return fail(405, "method_not_allowed", "POST 만 지원");
    }

    // ── 1. Supabase JWT 검증 ──
    const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    let sub: string;
    try {
      const { payload } = await jwtVerify(token, new TextEncoder().encode(env.SUPABASE_JWT_SECRET));
      if (typeof payload.sub !== "string" || payload.sub.length === 0) throw new Error("no sub");
      sub = payload.sub;
    } catch {
      return fail(401, "unauthorized", "Supabase 토큰 검증 실패");
    }

    // ── 2. 요청 파싱·검증 ──
    let items: SignItem[];
    try {
      const body = (await request.json()) as { items?: SignItem[] };
      if (!Array.isArray(body.items) || body.items.length === 0) throw new Error("no items");
      items = body.items;
    } catch {
      return fail(400, "invalid_request", "items 배열이 필요");
    }
    if (items.length > MAX_ITEMS) {
      return fail(400, "invalid_request", `items 는 최대 ${MAX_ITEMS}개`);
    }

    for (const item of items) {
      if (!item.bucket || !item.path || !ALLOWED_METHODS.has(item.method)) {
        return fail(400, "invalid_request", "bucket/path/method(GET|PUT) 필수");
      }
      if (!Number.isFinite(item.expiresIn) || item.expiresIn <= 0 || item.expiresIn > MAX_EXPIRES_IN) {
        return fail(400, "invalid_request", `expiresIn 은 1..${MAX_EXPIRES_IN}`);
      }
      if (item.path.includes("..")) {
        return fail(400, "invalid_request", "path 에 .. 금지");
      }
      // 본인 폴더 검사 — storage RLS("본인 폴더만")의 대응물. 하나라도 실패하면
      // 전체 거절(all-or-nothing).
      if (!item.path.startsWith(`${sub}/`)) {
        return fail(403, "forbidden", "본인 폴더 밖 경로");
      }
    }

    // ── 3. SigV4 presign ──
    const aws = new AwsClient({
      accessKeyId: env.R2_ACCESS_KEY_ID,
      secretAccessKey: env.R2_SECRET_ACCESS_KEY,
      service: "s3",
      region: "auto",
    });

    const urls = [];
    for (const item of items) {
      const objectURL = new URL(
        `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${item.bucket}/${item.path}`,
      );
      objectURL.searchParams.set("X-Amz-Expires", String(Math.floor(item.expiresIn)));

      const headers: Record<string, string> = {};
      if (item.contentType) headers["Content-Type"] = item.contentType;   // 서명 포함 — 전송도 같은 값 필수

      const signed = await aws.sign(
        new Request(objectURL, { method: item.method, headers }),
        { aws: { signQuery: true } },
      );
      urls.push({
        url: signed.url,
        expiresAt: new Date(Date.now() + item.expiresIn * 1000).toISOString(),
      });
    }

    return Response.json({ urls });
  },
};
