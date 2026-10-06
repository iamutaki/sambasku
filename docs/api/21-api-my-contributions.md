# API Kontribusi Saya (milik user login)

Mengikuti `api-base-stack.md`: Section 9 (OpenAPI), 13 (envelope), 15
(rate limit), 19 (ID opaque). Antrean admin tetap di
`03-api-kontribusi-verifikasi.md` (`/api/v1/admin/contributions`).
Usulan perubahan kata: `17-api-suggest-edit-word.md`.

Satu list untuk **usul kata baru** (`contributions`) dan **usul
perubahan** (`word_edit_suggestions`). Merge `id DESC` (ULID
time-sortable).

---

## Endpoint

Middleware: `authenticate` (semua role) + rate 100/menit per `user_id`.

### 1. GET /api/v1/contributions/my

Query: `limit` 1-100 (default 20), `cursor` (id item terakhir),
`status` opsional `pending|approved|rejected|corrected`.

Urutan: gabungan dua sumber, `id DESC`. Cursor: `id < cursor` di
masing-masing sumber lalu merge.

Item:

```json
{
  "id": "01H...",
  "kind": "contribution",
  "entity_type": "word",
  "lemma": "makatn",
  "status": "pending",
  "created_at": "2026-09-21T00:00:00.000Z",
  "review_comment": null,
  "word_id": "01H...",
  "action": "create",
  "reason": null,
  "reason_code": null,
  "reviewed_at": null
}
```

- `kind`: `contribution` | `suggestion`
- `entity_type`: `word|meaning|pronunciation|word_image|example` atau
  `word_suggestion`
- `review_comment`: alasan reviewer (null jika belum ada keputusan)
- `word_id`: id kata terkait (anak kontribusi = parent)

401 tanpa token. Meta cursor standar (`limit`, `next_cursor`, `has_more`).

### 2. GET /api/v1/contributions/my/:kind/:id

`kind` = `contribution` | `suggestion`.

Bukan milik pemohon atau tidak ada → **404**
`CONTRIBUTION_NOT_FOUND` / `SUGGESTION_NOT_FOUND` (bukan 403).

Response `data` = item list + `reason` / `reason_code` (suggestion)
dan `reviewed_at` bila sudah direview.

---

## Modul

- `ListMyContributionsUseCase`, `GetMyContributionDetailUseCase`
- `ContributionRepository.listMine`, `WordSuggestionRepository.listMine`
- Mount: `createMyContributionRoutes` di `/api/v1/contributions`
  (bersama POST `/words` anon)

Tidak ada migrasi. Data sudah ada di `contributions` dan
`word_edit_suggestions`.
