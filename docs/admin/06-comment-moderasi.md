# Admin UI - Moderasi Komentar (takedown post-moderation)

Mengikuti `admin-base-stack.md`. Kontrak: `09-api-comment.md`.

KEPUTUSAN (2026-09-22):
- Tidak ada antrean approve/reject. Create langsung published.
- Tabs: Diterbitkan / Di-takedown / Dihapus penulis (default: Diterbitkan).
- Aksi pada baris `published`: **Takedown** →
  `POST /admin/comments/:id/takedown`.
- 409 `COMMENT_ALREADY_MODERATED` → toast + refetch.
- Body asli ditampilkan di admin (tidak di-redact).

## Halaman `/comments`

- DataTable + Tabs filter status + cursor pagination.
- Kolom: komentar, penulis, kata (link), status Tag, dikirim, direview, aksi.
- Menu sidebar "Komentar" (CommentOutlined).

## Referensi

- `09-api-comment.md`
- `06-detail-komentar.md` - marking di detail kata
- `07-comment-blocklist.md` - CMS blocklist
