# API Vote Deck - Antrean kata belum di-vote user

Mengikuti `api-base-stack.md`. Melengkapi modul vote
([`08-api-upvote-downvote.md`](08-api-upvote-downvote.md),
[`26-api-my-votes.md`](26-api-my-votes.md)).

Backlog produk: [`../backlogs/KONTRIBUSI_VOTE_DECK.md`](../backlogs/KONTRIBUSI_VOTE_DECK.md).
Mobile: [`../mobile/22-mobile-kontribusi-vote-deck.md`](../mobile/22-mobile-kontribusi-vote-deck.md).

---

## Intent

User login membuka tab Kontribusi dan mendapat antrean kartu kata
**published** yang **belum pernah mereka vote**. Setelah
`POST /api/v1/votes` ke kata itu, kata hilang dari deck berikutnya.

Bukan antrean moderasi (itu `/admin/contributions`).

---

## Endpoint

### `GET /api/v1/votes/deck`

Middleware: `authenticate` (semua role) + `rateLimit` 100/menit per
`user_id` (tier baca auth).

Query:

| Param | Tipe | Default | Catatan |
| ----- | ---- | ------- | ------- |
| `limit` | int 1-20 | 10 | Maks lebih ketat dari `/words/latest` karena deck UI |
| `cursor` | string | - | Opaque; keyset pagination |

Filter (AND):

- `words.deleted_at IS NULL`
- `words.status = 'published'`
- feed-safe usage labels (sama `listLatest` / WOTD -
  `feedSafeUsageLabelsSql`)
- **NOT EXISTS** baris `votes` dengan
  `user_id = :me AND entity_type = 'word' AND entity_id = words.id`
- **NOT EXISTS** baris `user_skips` dengan
  `user_id = :me AND target_type = 'word' AND target_id = words.id`

Urutan:

1. Total vote global Asc (`upvotes + downvotes`, kata tanpa vote = 0)
2. `COALESCE(verified_at, approved_at-ish, created_at)` Asc (kata lebih
   lama / kurang dinilai dulu - atau pakai keyset stabil:
   `(total_votes ASC, COALESCE(verified_at, created_at) ASC, id ASC)`)
3. Cursor memotong keyset yang sama

Response 200 (envelope Section 13):

```json
{
  "success": true,
  "data": [
    {
      "id": "01JDWORD...",
      "lemma": "makan",
      "language_id": "01...",
      "language_code": "sambas",
      "word_type": "lemma",
      "status": "published",
      "is_verified": true,
      "approved_at": "2026-09-01T00:00:00.000Z",
      "sense": "menyantap makanan",
      "upvotes": 0,
      "downvotes": 0
    }
  ],
  "meta": {
    "limit": 10,
    "next_cursor": "...",
    "has_more": false
  }
}
```

Catatan:

- Bentuk item mengikuti `/words/latest` + `upvotes`/`downvotes`
  (opsional untuk client; **UI deck menyembunyikan count**).
- `sense`: semantik sama `listLatest` (makna published pertama /
  terjemahan pertama).
- `my_vote` **tidak** dikirim - by definition null untuk semua item.
- 401 tanpa token. Tidak ada 404 empty - `data: []` + `has_more: false`.

### Aksi vote

Reuse tanpa perubahan:

`POST /api/v1/votes` body
`{ "target_type": "word", "target_id": "...", "value": 1 | -1 }`

Setelah sukses, client buang kartu dari antrean lokal; request deck
berikutnya otomatis mengecualikan kata itu.

### Lewati kartu (tanpa vote)

`POST /api/v1/votes/skips` body `{ "word_id": "..." }`

`DELETE /api/v1/votes/skips/:wordId` - undo satu skip (idempoten).

Middleware sama tulis vote: `authenticate` + gate klien tulis +
`rateLimit` 60/menit per `user_id`.

- 200 `{ "word_id", "skipped": true | false }`. POST ulang tetap 200
  (unik per user + kata).
- 404 `VOTE_TARGET_NOT_FOUND` jika kata tidak ada (hanya POST).
- DELETE pada kata yang tidak punya baris skip tetap 200.
- Tidak menulis baris `votes`. Count upvote/downvote tidak berubah.
- User lain tetap melihat kata itu di deck mereka.

Setelah POST, `GET /votes/deck` user itu tidak mengembalikan `word_id`.
Setelah DELETE, kata boleh muncul lagi (selama belum di-vote).

---

## Layer modul

```
modules/vote/
├── application/use-cases/get-vote-deck.use-case.ts   # BARU
├── domain/repositories/vote.repository.ts            # +listDeckWords
├── infrastructure/vote.repository.impl.ts            # +SQL deck
└── presentation/v1/
    ├── vote.controller.ts                            # +deck()
    ├── vote.routes.ts                                # GET /deck
    └── validators/vote.validator.ts                  # query + response
```

Join ke `words` + agregat vote boleh di `VoteRepositoryImpl`, atau
delegate sense-attach ke helper yang sudah dipakai `WordRepository`
(`attachSenses` / batch setara). Hindari N+1.

---

## Testing

- Unit `get-vote-deck.use-case.test.ts`: kosong → `[]`; cursor
  diteruskan; limit di-clamp.
- E2E di `vote.e2e.test.ts`:
  - 401 tanpa token
  - login → deck berisi kata published yang belum di-vote
  - vote kata → deck berikutnya tidak berisi id itu
  - skip kata → deck user itu tidak berisi id itu, count vote tidak
    naik, user lain tetap melihat; DELETE skip mengembalikan kata
  - kata soft-deleted / non-published tidak muncul

Bruno: `http/vote/get-vote-deck.bru`.

---

## Referensi

- `08-api-upvote-downvote.md` - toggle / counts / my
- `18-api-list-words.md` / `28-api-word-of-the-day.md` - feed-safe
- `ERROR_CODES.md` - tidak ada code baru (401/400/429 standar)
