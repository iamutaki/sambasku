# 28 - API Word of the Day (Kata Hari Ini)

Sumber keputusan: [`docs/backlogs/WORD_OF_THE_DAY.md`](../backlogs/WORD_OF_THE_DAY.md).
Kontrak terimplementasi di bawah adalah kebenaran final untuk endpoint ini.

## Ringkasan

`GET /api/v1/words/today` - publik, tanpa auth. Satu kata terbit per hari,
deterministik per tanggal WIB (Asia/Jakarta, UTC+7). Semua user melihat
kata yang sama pada hari yang sama.

- Rate limit: 100/menit per IP (middleware `*` route publik words).
- Response = payload detail kata (`GET /words/:id`) + `date` +
  `is_new_this_week`.
- Korpus kosong (belum ada kata published): `200` dengan `data: null`.

## Pemilihan kata

Stateless, tanpa tabel, tanpa COUNT/OFFSET:

```sql
SELECT id FROM words
WHERE status = 'published' AND deleted_at IS NULL
ORDER BY md5(id || ':' || $tanggal)   -- $tanggal = 'YYYY-MM-DD' WIB
LIMIT 1
```

Lalu detail diambil lewat `findDetailById` (published-only), sama dengan
endpoint publik `GET /words/:id`. Kata bisa terulang sebelum satu
putaran penuh - diterima V1.

## Field tambahan

| Field | Isi |
| ----- | --- |
| `date` | `"YYYY-MM-DD"` tanggal WIB yang dipakai seed |
| `is_new_this_week` | `true` saat `verified_at >= now() - 7 hari`. Proxy sadar: `verified_at` bisa berubah via verify/unverify pasca-publikasi; kolom `published_at` = migrasi menyusul kalau presisi penting |

## Contoh

```json
{
  "success": true,
  "data": {
    "id": "01HXYZABCDEF1234567890",
    "lemma": "makatn",
    "date": "2026-09-21",
    "is_new_this_week": false,
    "...": "field detail kata lainnya sama dengan GET /words/:id"
  }
}
```

Korpus kosong:

```json
{ "success": true, "data": null }
```

## Cache

Hasil (termasuk kasus kosong) di-cache in-memory per tanggal WIB di
`GetWordOfDayUseCase`. Invalid otomatis saat tanggal berganti.
Per-isolate di Workers - aman karena hasilnya deterministik, cache
hanya untuk performa.

## Jebakan routing

Route `/today` didaftarkan **sebelum** `/:id` di
`word.routes.ts` (`createPublicWordRoutes`) - kalau tidak, `today`
tertangkap param `:id` dan gagal validasi ULID 400.

## Modul

```text
api/src/modules/word/
├── application/use-cases/get-word-of-day.use-case.ts
├── domain/repositories/word.repository.ts        # +findWordOfDayId(date)
├── infrastructure/word.repository.impl.ts        # impl ORDER BY md5(...)
└── presentation/v1/
    ├── word.controller.ts                        # wordOfDay()
    ├── word.routes.ts                            # GET /today sebelum /:id
    └── validators/create-word.validator.ts       # wordOfDayResponseSchema
```

## Error

Tidak ada error code baru. Hanya reuse `RATE_LIMITED` (429) dari
middleware rate limit. Korpus kosong bukan error (200 + `data: null`).

## Bruno

- `http/word/get-word-of-day.bru`
- Fixture JSON: `docs/json/word/get-word-of-day.200.json`,
  `docs/json/word/get-word-of-day.empty.200.json`
