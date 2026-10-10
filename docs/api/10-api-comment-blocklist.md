# API Comment Blocklist - Sensor Kata Otomatis

Acuan filter otomatis saat create komentar (`09-api-comment.md`).
Bukan antrean moderasi dan bukan auto-takedown: hanya **replacement**
kata terlarang di `body` sebelum disimpan.

KEPUTUSAN PRODUK (2026-09-22):
- Admin/root mengelola daftar kata di CMS.
- Match: case-insensitive, whole-word; ganti token dengan `***`.
- Soft-delete entry = nonaktif (tidak dipakai filter).
- Komentar tetap `published` setelah filter.

---

## Skema

Tabel `comment_blocklist_words`:
- `id` ULID PK
- `word` text NOT NULL (disimpan lowercase trim; unik di antara aktif)
- `created_by` → users.id
- `created_at`, `updated_at`
- `deleted_at`, `deleted_by` (soft-delete)

Index unik parsial tidak tersedia di SQLite sederhana: uniqueness di
aplikasi (cek sebelum insert) + unique index pada `word` untuk baris
aktif cukup dijaga di use case (tolak duplikat aktif).

---

## Endpoint (admin)

Role: `admin` | `root`. Rate limit tier admin.

1. `GET /api/v1/admin/comment-blocklist?limit=&cursor=&q=`
   - Hanya baris `deleted_at IS NULL`, terbaru dulu.
   - `q` opsional, partial match case-insensitive (maks 100). Dipakai CMS
     untuk mencari kata lalu menghapusnya.
2. `POST /api/v1/admin/comment-blocklist` body `{ "word": "..." }`
   - Trim, lowercase, 1..100 char; duplikat aktif → 409.
3. `POST /api/v1/admin/comment-blocklist/bulk` body `{ "words": ["...", ...] }`
   - Maks 2000 entri per permintaan. CMS memecah file yang lebih besar.
   - Trim, lowercase; kosong dibuang; lebih dari 100 karakter dihitung
     `invalid_count` (batch tetap jalan).
   - Duplikat aktif atau berulang di batch yang sama diabaikan
     (`skipped_count`), bukan 409.
   - Respons 200: `{ created_count, skipped_count, invalid_count }`.
   - Semua token kosong → 400 `BLOCKLIST_BULK_EMPTY`.
4. `DELETE /api/v1/admin/comment-blocklist/:id`
   - Soft-delete; id hilang → 404.

---

## Integrasi create komentar

`CreateCommentUseCase` memuat semua word aktif, menerapkan replacement
pada `body`. Jika body berubah:
- `body` = hasil filter (tayang publik)
- `body_original` = teks sebelum filter (hanya admin)

Admin list mengekspos `body_original` + `is_censored`. Endpoint
`POST /admin/comments/:id/uncensor` memulihkan teks asli (lihat
`09-api-comment.md` #6).

## Referensi

- `09-api-comment.md`
- `docs/admin/07-comment-blocklist.md`
