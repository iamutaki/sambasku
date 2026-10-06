# API Auth Google - Masuk dengan ID Token

Status **V1 implemented** (2026-09-21). Mengikuti `api-base-stack.md`
Section 3, 9, 10, 11, 13, 15, 21. Sumber produk:
[`docs/backlogs/AUTH_GOOGLE.md`](../backlogs/AUTH_GOOGLE.md). Klien:
[`13-mobile-auth-google.md`](../mobile/13-mobile-auth-google.md).

Backend **bukan** target redirect OAuth. Client (SDK Google) mengirim
ID token; API memverifikasi JWKS lalu menerbitkan JWT sendiri (envelope
login yang sama).

## Endpoint

`POST /api/v1/auth/google` (publik). Rate limit 5/15 menit per IP
(sebelah `/login`). OpenAPI tag `Auth`.

Body:

```json
{
  "id_token": "eyJhbGciOiJSUzI1NiIs...",
  "client_type": "mobile"
}
```

`client_type`: `'web'` (default) | `'mobile'`. Web: Set-Cookie
`refresh_token` path `/api/v1/auth`. Mobile: `refresh_token` di body,
tanpa cookie.

Response 200 = envelope login (`loginResponseSchema`). Sample:
[`docs/json/auth/login-google.200.mobile.json`](../json/auth/login-google.200.mobile.json).

## Aturan akun (no-autolink)

Urutan:

1. `auth_identities (google, sub)` ada + user aktif → login. Tidak audit.
2. Tidak ada identity → buat user baru:
   - Username: slug dari nama Google / local-part email (`a-z0-9._`, tanpa hyphen).
     Bentrok → `base_google` / `base_xxxxx_google`.
   - Email: email Google bila unik; kalau bentrok → sintetis
     `go_{sub}@users.noreply.sambasku.local`.
   - `email_at_provider`: email asli Google (boleh sama dengan akun lain).
   - `password_hash` null, `email_verified` true, role `contributor`.
   - Audit `action: 'create'`, `newData.via: 'google'` (tanpa token).
3. **Tidak** auto-link ke user yang sudah punya email sama (akun terpisah
   sampai user menautkan secara sadar lewat `/google/link`).

Identity `deleted_at` terisi, user `is_active=false` / `deleted_at` /
token rusak (`iss`/`aud`/`exp`/`email_verified`) → satu kode
**401 `INVALID_GOOGLE_TOKEN`**, pesan "Tidak bisa masuk dengan Google."
(anti-enumeration). Race unique identity → lookup ulang, lanjut login.

Identitas stabil = Google `sub`, bukan email. Role tidak dari Google.

## Error

| HTTP | error_code | Kapan |
| ---- | ---------- | ----- |
| 400 | `VALIDATION_ERROR` | `id_token` kosong |
| 401 | `INVALID_GOOGLE_TOKEN` | token / iss / aud / exp / email belum verified / akun nonaktif / identity terhapus |
| 429 | `RATE_LIMITED` | 5/15 menit per IP |
| 503 | `GOOGLE_AUTH_UNAVAILABLE` | `GOOGLE_CLIENT_ID` kosong/whitespace |

Sample: `docs/json/auth/login-google.401.json`, `.503`.
Bruno: `http/auth/login-google.bru`.

## Verifier

`GoogleTokenVerifierPort` + `jose` (`createRemoteJWKSet` + `jwtVerify`):

- `iss` ∈ `https://accounts.google.com` | `accounts.google.com`
- `aud` === `GOOGLE_CLIENT_ID` (Web client ID)
- `exp` (lewat `jwtVerify`)
- `email_verified === true` (boolean atau string `'true'`)
- `sub` dan `email` ada

`GOOGLE_CLIENT_ID` kosong: **jangan** panggil jose; 503. Env opsional di
`env.ts`, `.env.example`, komentar `wrangler.toml` `[vars]` (bukan
secret). Flutter `GOOGLE_WEB_CLIENT_ID_STAGING` / `_PRODUCTION` harus
sama dengan env API matching.

E2E tidak hit Google: ganti
`googleTokenVerifierHolder.current` setelah import app.

## File

```
modules/auth/
  domain/entities/auth-identity.entity.ts
  domain/repositories/auth-identity.repository.ts
  application/ports/google-token-verifier.port.ts
  application/use-cases/login-with-google.use-case.ts
  infrastructure/google-token-verifier.ts
  infrastructure/google-token-verifier.holder.ts
  infrastructure/auth-identity.repository.impl.ts
  presentation/v1/validators/google-login.validator.ts
```

Sesi JWT di-extract ke `application/utils/issue-login-session.ts` (login
password, verify-email, Google).

Lupa password tetap mengisi `password_hash` akun Google. Ubah password
sebelum itu: `OAUTH_NO_PASSWORD`.

## Di luar V1 login

Tombol Google admin, Apple/GitHub, foto Google, banyak `aud`
(Android/iOS terpisah).

## Taut / lepas akun (2026-09-24)

Authenticated (Bearer). Login publik tetap **no-autolink**.

| Method | Path | Fungsi |
|--------|------|--------|
| `GET` | `/api/v1/auth/providers` | Daftar provider aktif `{ provider, linked_at }` |
| `POST` | `/api/v1/auth/google/link` | Body `{ id_token }` - hubungkan Google ke sesi |
| `DELETE` | `/api/v1/auth/google/link` | Lepas Google; **409 `LAST_AUTH_METHOD`** jika OAuth-only tanpa password |

Conflict `sub` milik user lain → **409 `GOOGLE_ALREADY_LINKED`**. Belum
terhubung saat unlink → **404 `GOOGLE_NOT_LINKED`**.
