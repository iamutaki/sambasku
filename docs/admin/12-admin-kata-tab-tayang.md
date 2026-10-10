# Admin UI - Tab Tayang di menu Kata

Mengikuti `admin-base-stack.md` (Tabs seperti Moderasi Komentar /
Search Miss). Kontrak API:

- `GET /api/v1/admin/words?published=true|false|(omit)` - lihat
  `docs/api/15-api-admin-list-words.md`

Status fondasi:

- SUDAH ADA: `/words` list via search publik (hanya published); Switch
  tayang per baris; create/edit/delete.
- YANG DITUTUP: tabs Tayang | Tidak tayang | Semua; list lewat endpoint
  admin (semua status, tanpa catat search miss).

---

## Keputusan UX

1. Tabs di bawah PageHeader (default **Tayang**):
   - Tayang → `published=true`
   - Tidak tayang → `published=false` (draft / pending_review / rejected)
   - Semua → omit `published`
2. Dropdown sinonim/antonim (`WordSearchSelect`) tetap hanya published
   (`published=true` eksplisit).
3. Antrean kontributor `pending_review` tetap ada di `/contributions`;
   tab Tidak tayang di Kata juga menampilkannya (overlap OK - admin bisa
   temukan dari dua tempat).

---

## Prompt

```text
WordsPage: Tabs published; useWordList(published); listWordsRequest →
GET /admin/words. WordSearchSelect: published:true.
```
