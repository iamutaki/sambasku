# API Riwayat Vote Saya

Mengikuti `api-base-stack.md`: Section 9 (OpenAPI), 13 (envelope), 15
(rate limit), 19 (ID opaque). Toggle, counts, dan state tombol tetap di
`08-api-upvote-downvote.md`. Antrean admin tetap
`GET /api/v1/admin/votes`.

Satu list milik user login: semua jenis target yang sudah ada, lemma
kata induk di-resolve di server. Bukan pengganti
`GET /api/v1/votes/my?targets=`.

---

## Endpoint

Middleware: `authenticate` (semua role) + rate 100/menit per `user_id`
(key `vote-history:`).

### GET /api/v1/votes/history

Query:

| Field | Aturan | Default |
| ----- | ------ | ------- |
| `limit` | int 1-50 | 20 |
| `cursor` | id item terakhir, opsional | - |
| `target_type` | `word\|meaning\|example\|pronunciation\|word_image\|comment`, opsional | semua |
| `value` | `1` atau `-1`, opsional | semua |

Urutan: `votes.id DESC` (waktu pasang pertama, bukan `updated_at`).
Cursor: `id < cursor`. Page dulu (LIMIT+1), baru resolve kata induk.
Baris tidak dibuang kalau target atau kata hilang.

Item:

```json
{
  "id": "01JDVOTESMAKATN00000000001",
  "target_type": "word",
  "target_id": "01JDWORDMAKATN0000000000A",
  "value": 1,
  "voted_at": "2026-09-21T10:00:00.000Z",
  "word": {
    "id": "01JDWORDMAKATN0000000000A",
    "lemma": "makatn",
    "word_type": "lemma",
    "is_verified": true
  }
}
```

- `voted_at` = `votes.created_at` ISO
- `word` = subset bookmark (`id`, `lemma`, `word_type`, `is_verified`)
- `word` = `null` jika parent tidak ada atau `words.deleted_at` terisi
- Hop kata induk: `word` langsung; `meaning.word_id`;
  `example` → `meanings.word_id`; `pronunciation.word_id`;
  `word_image.word_id`; `comment.word_id`

401 tanpa token. Query rusak → 400 `VALIDATION_ERROR`. Meta cursor
standar (`limit`, `next_cursor`, `has_more`).

`GET /api/v1/votes/my?targets=` tidak berubah: wajib `targets`, tanpa
meta, tanpa `word`.

---

## Modul

- `ListMyVoteHistoryUseCase`
- `VoteRepository.listByUser` + resolve parent word (batch per jenis)
- Mount: `GET /history` di `createVoteRoutes` (`/api/v1/votes`)

Migrasi index saja: `votes (user_id, id)`. Unique lama tetap.
Tidak ada error code baru, tidak ada audit.
