# API Auth Facebook - Masuk dengan Access Token Graph

Status **V1 implemented** (2026-09-21). Mengikuti `api-base-stack.md`
Section 3, 9, 10, 11, 13, 15, 21, 23. Sumber produk:
[`docs/backlogs/AUTH_FACEBOOK.md`](../backlogs/AUTH_FACEBOOK.md). Klien:
[`19-mobile-auth-facebook.md`](../mobile/19-mobile-auth-facebook.md).

Backend **bukan** target redirect OAuth. Client (SDK Facebook) mengirim
access token Graph; API memverifikasi `debug_token` + `/me` lalu
menerbitkan JWT sendiri (envelope login yang sama).

## Endpoint

`POST /api/v1/auth/facebook` (publik). Rate limit 5/15 menit per IP
(sebelah `/login` dan `/google`). OpenAPI tag `Auth`.

Body:

```json
{
  "access_token": "EAAGm0PX4ZCpsBA...",
  "client_type": "mobile"
}
```

`client_type`: `'web'` (default) | `'mobile'`. Web: Set-Cookie
`refresh_token` path `/api/v1/auth`. Mobile: `refresh_token` di body,
tanpa cookie.

Response 200 = envelope login (`loginResponseSchema`). Sample:
[`docs/json/auth/login-facebook.200.mobile.json`](../json/auth/login-facebook.200.mobile.json).

## Aturan akun (no-autolink)

Urutan:

1. `auth_identities (facebook, id)` ada + user aktif → login. Tidak audit.
2. Tidak ada identity → buat user baru:
   - Username: slug dari nama Facebook / local-part email (`a-z0-9._`, tanpa hyphen).
     Bentrok → `base_facebook` / `base_xxxxx_facebook`.
   - Email: email Facebook bila unik; kalau bentrok → sintetis
     `fb_{id}@users.noreply.sambasku.local`.
   - `email_at_provider`: email asli Facebook (boleh sama dengan akun lain).
   - `password_hash` null, `email_verified` true, role `contributor`.
   - Audit `action: 'create'`, `newData.via: 'facebook'` (tanpa token).
3. **Tidak** auto-link ke user yang sudah punya email sama (akun terpisah
   sampai user menautkan secara sadar lewat `/facebook/link`).

Identity `deleted_at` terisi, user `is_active=false` / `deleted_at` /
token rusak (`is_valid` / `app_id` / expired / email absen) → satu kode
**401 `INVALID_FACEBOOK_TOKEN`**, pesan "Tidak bisa masuk dengan
Facebook." (anti-enumeration). Race unique identity → lookup ulang,
lanjut login.

Identitas stabil = Facebook Graph `id`, bukan email. Role tidak dari
Facebook.

## Error

| HTTP | error_code | Kapan |
| ---- | ---------- | ----- |
| 400 | `VALIDATION_ERROR` | `access_token` kosong |
| 401 | `INVALID_FACEBOOK_TOKEN` | token / app_id / is_valid / expired / email absen / akun nonaktif / identity terhapus |
| 429 | `RATE_LIMITED` | 5/15 menit per IP |
| 503 | `FACEBOOK_AUTH_UNAVAILABLE` | `FACEBOOK_APP_ID` atau `FACEBOOK_APP_SECRET` kosong/whitespace |

Sample: `docs/json/auth/login-facebook.401.json`, `.503`.
Bruno: `http/auth/login-facebook.bru`.

## Verifier

`FacebookTokenVerifierPort` + `fetch` Graph API (pin `v21.0`):

1. `GET /debug_token?input_token=...&access_token={APP_ID}|{APP_SECRET}`
   - `data.is_valid === true`
   - `data.app_id === FACEBOOK_APP_ID`
   - `data.user_id` ada
   - `data.expires_at` belum lewat (`0` = tidak kedaluwarsa)
2. `GET /me?fields=id,name,email&access_token=...`
   - `id` === `user_id` debug_token
   - `email` non-kosong
   - `name` opsional

`FACEBOOK_APP_ID` atau `FACEBOOK_APP_SECRET` kosong: **jangan** panggil
Graph; 503. App ID publik di `env.ts`, `.env.example`, komentar
`wrangler.toml` `[vars]`. App Secret via `wrangler secret put
FACEBOOK_APP_SECRET`. Flutter `FACEBOOK_APP_ID_STAGING` /
`_PRODUCTION` harus sama dengan env API matching.

Graph gagal jaringan / 5xx: tetap `401 INVALID_FACEBOOK_TOKEN`.

E2E tidak hit Graph: ganti
`facebookTokenVerifierHolder.current` setelah import app.

## File

```
modules/auth/
  application/ports/facebook-token-verifier.port.ts
  application/use-cases/login-with-facebook.use-case.ts
  infrastructure/facebook-token-verifier.ts
  infrastructure/facebook-token-verifier.holder.ts
  presentation/v1/validators/facebook-login.validator.ts
```

Sesi JWT reuse `application/utils/issue-login-session.ts`. Transaksi
user baru reuse `createUserWithGoogleIdentity` dengan
`provider: 'facebook'`.

Lupa password tetap mengisi `password_hash` akun Facebook. Ubah
password sebelum itu: `OAUTH_NO_PASSWORD`.

## Di luar V1

Tombol Facebook admin, Apple/GitHub, taut/lepas akun, foto Facebook,
Limited Login OIDC sebagai jalur tunggal, `GET /auth/providers`, data
deletion callback Meta.
