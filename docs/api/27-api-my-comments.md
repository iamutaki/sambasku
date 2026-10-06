# API Komentar Saya

Mengikuti `api-base-stack.md`. List publik per kata dan tulis/hapus di
`09-api-comment.md`.

Setelah post-moderation (2026-09-22): user melihat komentar miliknya
dengan status `published` | `taken_down` | `deleted_by_author` (body
penuh di `/my`; list publik me-redact body non-published).

---

## Endpoint

### GET /api/v1/comments/my

Query: `limit`, `cursor`, `status?` (`published` | `taken_down` |
`deleted_by_author`).

Item: `id`, `word_id`, `word_lemma`, `body`, `status`, `created_at`,
`reviewed_at`.

## Modul

- `ListMyCommentsUseCase` + `CommentRepository.listByUser`
