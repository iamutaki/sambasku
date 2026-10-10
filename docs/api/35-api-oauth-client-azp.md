# API OAuth client + claim JWT `azp`

Gate klien API (`api_clients`) dan claim JWT `azp` (= `client_id`).
Tahap awal: blocking di jalur auth (login / social / verify-email) lewat
`ResolveFirstPartyClient`; gate write memakai middleware
`requireApprovedClient` pada write user-facing:

| Scope | Endpoint (ringkas) |
|---|---|
| `vote.write` | `POST /votes` |
| `comment.write` | `POST /words/:id/comments`, `DELETE /comments/:id` |
| `contribute.write` | media kata (pronounce/audio/gambar/makna/contoh), usulan edit, upload token gambar, kontribusi kata (jika Bearer) |
| `discussion.write` | tulis / balas / upload-token discussions |
| `bookmark.write` | `POST /bookmarks` |
| `device.write` | `POST /device/register`, `PATCH /device/revoke` |
| `profile.read` | `PATCH /users/me`, avatar |

Admin routes tetap dilindungi role (bukan focus gate third-party).
`OAUTH_REQUIRE_AZP=false` (default) = token tanpa `azp` masih lolos (legacy map).

## Env: `OAUTH_REQUIRE_AZP`

| Nilai | Perilaku |
|---|---|
| `false` / kosong / tidak di-set (**default**) | Grace / **backward-compatible**: JWT tanpa `azp` masih lolos write gated; di-map ke scope first-party penuh (`legacyMapped: true`). Setara mode lama `oauth.write_enforcement=legacy_map`. Kini hanya relevan untuk environment dev lokal - tidak dipakai lagi di produksi/staging. |
| `true` / `1` / `yes` | Ketat: JWT tanpa `azp` → `401 CLIENT_REQUIRED`. Setara mode lama `require_azp`. **Mode aktif di produksi & staging sejak issue #31.** |

### Status cutover (issue #31, 2026-10-02)

Produksi & staging memakai `OAUTH_REQUIRE_AZP=true`. Efek bagi sesi lama
(dibuat sebelum migration `0021`): refresh berikutnya → `401 SESSION_STALE`
→ aplikasi memaksa login ulang. Setelah itu semua JWT selalu ber-azp.
Grace mode (false) hanya relevan untuk environment dev lokal.

Cutover di staging/production: set di `.env` / `wrangler.toml` `[vars]` lalu
redeploy. **Bukan** `app_settings` dan **bukan** toggle Console.

Key DB lama `oauth.write_enforcement` dihapus migrasi
`0023_drop-oauth-write-enforcement-setting`.

## Apa yang tetap di DB / Console

`app_settings` (menu Console **Legal** / **OAuth**) tetap untuk config operasional lain:

- `oauth.third_party_registration` (`open` \| `closed`)
- `oauth.request_log_retention_days`
- `legal.terms_version` / `legal.privacy_version`

Data per klien (`api_clients`: status, `allowed_scopes`, channels) di DB.
Admin CRUD: `GET/POST/PATCH /api/v1/admin/api-clients` + menu Console **OAuth**.
First-party tidak boleh di-revoke; prefix `sambasku-` dicadangkan.

## Alur auth (first-party)

Body login/social/verify-email boleh mengirim `client_id` (opsional).
Kosong → default `sambasku-web` / `sambasku-mobile` menurut `client_type`.
`ResolveFirstPartyClient` menolak unknown / bukan first-party / tidak
approved / channel mismatch. Session baru mendapat JWT `azp` + `scope`.

Refresh: refresh token tanpa `client_id` (legacy) tetap mengeluarkan access
tanpa `azp` selama grace (`OAUTH_REQUIRE_AZP=false`).

## Error terkait

Lihat `api/ERROR_CODES.md`: `CLIENT_REQUIRED`, `CLIENT_NOT_ALLOWED`,
`CLIENT_MISMATCH`, `INSUFFICIENT_SCOPE`.

## Cutover aman

1. Pastikan web/mobile/console mengirim `client_id` (atau andalkan default channel) dan login ulang.
2. Tunggu refresh token legacy habis / user refresh sesi.
3. Set `OAUTH_REQUIRE_AZP=true` di staging, uji write (vote).
4. Production: sama + redeploy.

Referensi kode: `api/src/shared/config/env.ts`,
`api/src/shared/middlewares/require-approved-client.middleware.ts`,
`api/src/modules/developer-oauth/`.
