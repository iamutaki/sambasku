# API Comment - Komentar Lemma & Moderasi Admin (Post-moderation)

Mengikuti `api-base-stack.md`: Section 3 (struktur folder), 7 (perubahan
skema), 9 (`@hono/zod-openapi` + Scalar), 10 (testing), 11 (versioning
`/api/v1/`), 13 (envelope & error), 15 (rate limiting), 19 (ULID), 21
(audit trail). **Pengecualian Section 22:** komentar TIDAK memakai
approval gate / pre-moderation. Lihat catatan di `api-base-stack.md`.

KEPUTUSAN PRODUK (2026-09-22, menggantikan pre-moderation 2026-09-18):
- Komentar HANYA oleh user login (semua role termasuk contributor).
- POST-MODERATION: create → langsung `published` (tayang publik).
- Admin/root/reviewer bisa **takedown** → `taken_down` (tetap di list
  publik, body di-redact; client tampilkan pesan standar komunitas).
- Penulis bisa hapus sendiri → `deleted_by_author` (tetap di list,
  body di-redact; client tampilkan "dihapus oleh penulis").
- Soft-delete (`deleted_at`) hanya untuk purge keras (jejak hilang dari
  list); bukan jalur utama hapus penulis / takedown.
- Body melewati **blocklist** (lihat `10-api-comment-blocklist.md`)
  sebelum disimpan: replacement kata terlarang, bukan auto-takedown.
  Jika berubah, `body_original` disimpan; admin bisa **uncensor**.
- Komentar terikat ke LEMMA (`word_id` FK), bukan polymorphic.
- Vote boleh menarget komentar; UI sebaiknya nonaktifkan vote pada
  status non-`published`.

Status aktif: `published` | `taken_down` | `deleted_by_author`.
Backfill: `pending_review` → `published`; `rejected` → `taken_down`.

---

## Endpoint

### 1. GET /api/v1/words/:wordId/comments

List komentar yang tampil (status `published` | `taken_down` |
`deleted_by_author`, `deleted_at IS NULL`), terbaru dulu.

Response item:
- `status` selalu dikirim.
- `body`: string penuh jika `published`; `null` jika `taken_down` /
  `deleted_by_author` (redact server-side).
- `upvotes` / `downvotes` tetap ada.
- `username` / `display_name`: handle untuk link; label UI pakai
  `display_name` (fallback username). Akun terhapus: keduanya
  "Akun tidak ditemukan".
- `avatar_url`: URL avatar publik (nullable); null jika tanpa foto
  atau akun terhapus.
- `is_verifier`: true jika role penulis termasuk verifikator
  (`admin` | `editor` | `root` | `reviewer`).
- `audio_url` / `audio_mime_type` / `audio_duration_ms`: null jika
  tanpa audio atau status non-`published`.

### 2. POST /api/v1/words/:wordId/comments

Authenticate + rate limit tulis. Body `{ "body": "..." }` (trim, 1..1000).

Urutan use case:
1. Gate tulis UGC (`assertCanContribute`): `is_active`, `contribute_muted_until`,
   `can_contribute` → else 403 `ACCOUNT_INACTIVE` / `CONTRIBUTION_MUTED` /
   `CONTRIBUTION_NOT_ALLOWED`.
2. Heuristik kualitas teks → else 400 `UGC_INPUT_REJECTED` (+ strike
   `input_rejected`).
3. Word ada & `published` → else 404/409.
4. Filter body lewat blocklist aktif (replacement whole-word,
   case-insensitive → `***`). Jika berubah, simpan `body_original`.
   Sensor berat (≥50% teks hilang) → strike `heavy_censor`.
5. `create` dengan `status: published`.
6. Audit `create`.
7. Notifikasi diskusi (best-effort, tidak menggagalkan create):
   - Penerima = komentator sebelumnya pada kata itu **plus**
     `words.created_by` (pemilik), kecuali aktor, Anonim, dan
     Pengimpor Data CSV.
   - Inbox type `word_comment`, `target_kind: word`, upsert unread
     per `(user, word)` (`refreshOnConflict`).
   - Push FCM dengan title/body yang sama, mode Skip: push pertama per
     user langsung; berikutnya ditahan
     `notification.word_comment_push_cooldown_minutes` (default `3`).
     Inbox **tidak** di-throttle.
   - Body dinamis: `{displayName} juga berkomentar di "{lemma}": {cuplikan}`.

Response 201: termasuk `status: "published"` dan body terfilter.

Rate limit tulis habis → 429 + strike `rate_lockout` (policy mute progresif).

### 2b. POST /api/v1/words/:wordId/comments/audio

Authenticate + rate limit tulis. Multipart: `audio` wajib (≤5 MB,
MIME sama pelafalan), `body` caption opsional (0..1000),
`duration_ms` opsional. Voice-only diizinkan (body kosong).

Urutan mirip create teks + upload ke GitHub
`assets/audio/comments/<wordId>/<ulid>.<ext>`. Notify cuplikan:
caption atau "mengirim rekaman suara".

Wire: `audio_url` / `audio_mime_type` / `audio_duration_ms` (null jika
status bukan `published`).

### 3. DELETE /api/v1/comments/:id

Hanya **penulis** → set `status = deleted_by_author` (bukan soft-delete).
Verifikator memakai takedown, bukan DELETE ini → 403 jika bukan penulis.

Response 200: `{ "success": true, "data": null }`.

### 4. GET /api/v1/admin/comments?status=&word_id=&limit=&cursor=

Role admin/root/reviewer. Filter status opsional
(`published` | `taken_down` | `deleted_by_author`; absen = semua).
Body tayang + `body_original` + `is_censored` (admin melihat sensor).

### 5. POST /api/v1/admin/comments/:id/takedown

Hanya dari `published` → `taken_down` (atomic WHERE). Race / sudah
bukan published → 409 `COMMENT_ALREADY_MODERATED`.

Setelah sukses: strike `comment_takedown` (bobot 3) ke penulis → policy
progresif (mute / pause `can_contribute` / deactivate).

Endpoint lama `approve` / `reject` **dihapus**.

Response 200: `{ id, status: "taken_down", reviewed_by, reviewed_at }`.

### 6. POST /api/v1/admin/comments/:id/uncensor

Pulihkan teks asli: `body = body_original`, `body_original = null`.
Tanpa `body_original` → 400 `COMMENT_NOT_CENSORED`.

Response 200: `{ id, body, body_original: null, is_censored: false }`.

---

## KEPUTUSAN SEMANTIK

- TERIKAT LEMMA (`word_id`), flat, tanpa threading, tanpa edit.
- POST-MODERATION: tayang dulu, moderasi kemudian (takedown).
- Blocklist = sensor kata saat create, bukan alasan status.
- Label: `display_name` (fallback username); link: `username`. Penulis terhapus → keduanya label akun terhapus.
- Word `pending_review` boleh dikomentari (cek ada + belum terhapus).
- Comment count TIDAK di word detail.

## TESTING (ringkas)

- create → 201 published; list langsung berisi item.
- blocklist word di body → body tersimpan ter-replace.
- takedown → list publik body null + status taken_down.
- author delete → status deleted_by_author, body null di publik.
- 409 double takedown; 403 delete oleh non-penulis.

## Referensi

- `10-api-comment-blocklist.md` - CMS + filter create
- `08-api-upvote-downvote.md` - vote target comment
- `23-api-notifications.md` - inbox/push `word_comment` ke peserta diskusi
- `docs/admin/06-comment-moderasi.md`, `06-detail-komentar.md`
- `docs/admin/07-comment-blocklist.md`
- `ERROR_CODES.md` - `COMMENT_NOT_FOUND`, `COMMENT_ALREADY_MODERATED`,
  `UGC_INPUT_REJECTED`, `CONTRIBUTION_MUTED`, `CONTRIBUTION_NOT_ALLOWED`,
  `ACCOUNT_INACTIVE`
- `http/comment/*.bru`
- Abuse ledger: `GET /api/v1/admin/users/:id/abuse-events`
