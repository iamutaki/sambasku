# API Auth GitHub - Masuk dengan Access Token / Authorization Code

Mengikuti pola Google (`24-api-auth-google.md`). Client mengirim
**access token** (Bruno/SDK) atau **authorization code** (mobile AppAuth);
API memverifikasi ke `api.github.com` lalu menerbitkan JWT sendiri.

## Endpoint

### Login

`POST /api/v1/auth/github` (publik). Rate limit 5/15 menit per IP.

Body (salah satu):

```json
{
  "access_token": "gho_...",
  "client_type": "mobile"
}
```

atau (mobile - secret tetap di server):

```json
{
  "code": "...",
  "redirect_uri": "https://sambasku.com/oauth/github",
  "code_verifier": "...",
  "client_type": "mobile"
}
```

Response 200 = envelope login.

### Link / unlink

- `POST /api/v1/auth/github/link` (auth) - body sama seperti login tanpa
  `client_type` (`access_token` atau `code` + `redirect_uri`).
- `DELETE /api/v1/auth/github/link` (auth) - 409 `LAST_AUTH_METHOD` jika
  ini satu-satunya cara masuk.

## Aturan akun

1. `auth_identities (github, id)` ada + user aktif → login.
2. Tidak ada identity → buat user baru:
   - Username: slug dari `login` GitHub (`a-z0-9._`, tanpa hyphen). Bentrok →
     `base_github` / `base_xxxxx_github`.
   - `display_name`: `name` atau `login`.
   - Email: email verified primary bila unik; kalau bentrok / tidak ada
     → sintetis `gh_{id}@users.noreply.sambasku.local`.
   - `email_at_provider`: email asli GitHub (boleh sama dengan akun lain).
   - `password_hash` null, `email_verified` true.
3. **Tidak** auto-link ke user yang sudah punya email sama (akun terpisah
   sampai user menautkan secara sadar).

## Env

| Var | Wajib | Keterangan |
| --- | ----- | ---------- |
| `GITHUB_CLIENT_ID` | ya (enable) | Publik. Kosong → 503. |
| `GITHUB_CLIENT_SECRET` | untuk path `code` | Hanya server. |

## Error

| HTTP | error_code | Kapan |
| ---- | ---------- | ----- |
| 400 | `VALIDATION_ERROR` | token/code kosong |
| 401 | `INVALID_GITHUB_TOKEN` | token / code / user tidak valid |
| 404 | `GITHUB_NOT_LINKED` | unlink tanpa tautan |
| 409 | `GITHUB_ALREADY_LINKED` / `LAST_AUTH_METHOD` | link bentrok / metode terakhir |
| 429 | `RATE_LIMITED` | 5/15 menit per IP (login) |
| 503 | `GITHUB_AUTH_UNAVAILABLE` | client id (atau secret untuk code) kosong |

## Setup OAuth App (manusia)

1. GitHub → Settings → Developer settings → OAuth Apps.
2. Authorization callback URL (**wajib https**, bukan custom scheme):
   - production: `https://sambasku.com/oauth/github`
   - staging: `https://sambasku-web-staging.iamutaki.com/oauth/github`
3. Scope: `read:user`, `user:email`.
4. Isi `GITHUB_CLIENT_ID` + `GITHUB_CLIENT_SECRET` di API; Client ID di
   flavor Flutter (`GITHUB_CLIENT_ID_STAGING` / `_PRODUCTION`).
