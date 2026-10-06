# API Words - Daftar Publik Semua Kata A-Z (List All)

Mengikuti `api-base-stack.md`: Section 3 (struktur folder), 7 (perubahan
skema), 9 (`@hono/zod-openapi` + Scalar), 10 (testing), 11 (versioning
`/api/v1/`), 13 (envelope & cursor pagination), 15 (rate limiting), 19
(ULID), 20 (Bruno). Pola endpoint publik mengikuti `/words/search`; pola
list tanpa search-miss mengikuti `ListAdminWordsUseCase` (15-api); preseden
cursor komposit encode/decode mengikuti modul vote (08-api, admin votes
list). Keputusan produk: `../backlogs/PLAN_LIST_ALL.md`.

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):
- SUDAH ADA: modul word 4 lapis, `/words/search` (cursor ULID tunggal,
  `ORDER BY id DESC`), `/words/:id`, serializer `toListItem`,
  rateLimit 100/menit per IP di `createPublicWordRoutes`, helper
  `escapeLike`, envelope list + meta.
- Yang BELUM: endpoint list A-Z, use case `ListWordsUseCase`, cursor
  komposit `(lemma, id)`, index `(lemma, id)`, tests, Bruno, docs/json.

KEPUTUSAN PRODUK (2026-09-20, dari PLAN_LIST_ALL.md):
- Browsing A-Z, bukan pencarian: `q` = filter `ILIKE %q%` pada lemma
  saja - TANPA variasi penulisan, TANPA rekaman search-miss (miss hanya
  direkam `/words/search` - kontrak 12).
- Urutan `lemma ASC, id ASC` - id wajib sebagai tie-breaker karena lemma
  tidak unik.
- Cursor komposit base64url `lemma\x00id` - BEDA bentuk dari ULID
  `/words/search`; client memperlakukan cursor sebagai opaque. TIDAK
  share validator zod `length(26)`.
- Publik tanpa auth; hanya `status = 'published'` + `deleted_at IS NULL`.
- Browse tanpa `q`: sembunyikan kata ber-label `kasar` / `diskriminatif`
  (`BROWSE_EXCLUDED_USAGE_LABELS`) supaya tidak terekspos di listing A-Z /
  sitemap. Filter `q` (pencarian manual di halaman daftar),
  `/words/search`, dan detail by lemma/id tetap menampilkan + badge.
- `letter` (opsional, satu karakter A-Z): filter **prefix** lemma
  (`lower(lemma) LIKE 'd%'`). Dipakai panel A-Z beranda. Beda dari `q`
  yang tetap **contains** (`ILIKE %q%`).

---

## Prompt

```text
Buatkan endpoint publik daftar semua kata A-Z untuk backend Kamus Digital
Sambas-Indonesia di modul word existing (4 lapis - Section 3). Keputusan
produk: docs/backlogs/PLAN_LIST_ALL.md.

LOKASI MODUL: modules/word/ (modul existing - TAMBAH, bukan modul baru)

STRUKTUR FILE YANG PERLU DIBUAT/DIUBAH:

modules/word/
├── domain/
│   └── repositories/word.repository.ts      # UBAH: +encodeListCursor/
│                                            #   decodeListCursor + listAtoZ
├── application/
│   └── use-cases/list-words.use-case.ts     # BARU
├── infrastructure/
│   └── word.repository.impl.ts              # UBAH: +listAtoZ keyset
└── presentation/v1/
    ├── word.routes.ts                       # UBAH: +listWordsRoute '/'
    ├── word.controller.ts                   # UBAH: +list()
    └── validators/create-word.validator.ts  # UBAH: +listWordsQuerySchema

shared/database/drizzle/schema/words.schema.ts  # UBAH: +index (lemma, id)
app.ts                                          # UBAH: +DI ListWordsUseCase

PERUBAHAN SKHEMA (WAJIB - ikuti alur Section 7):
- TIDAK ada tabel/kolom baru. Tambahan INDEX komposit di words.schema.ts:
  index('words_lemma_id_idx').on(t.lemma, t.id)
  (saat ini hanya words_language_lemma_idx (language_id, lemma) - TIDAK
  menopang ORDER BY lemma, id; Section 13 mengizinkan sort kolom non-id
  hanya jika cursor unik + terindeks).
- Alur: pnpm drizzle-kit generate --name=words-lemma-id-index → REVIEW
  SQL (harus CREATE INDEX, bukan recreate tabel) → pnpm drizzle-kit
  migrate. Index tambahan pada tabel existing - tanpa backfill.
- Update docs/dbdiagram.dbml di PR yang sama.

REPOSITORY - interface WordRepository (domain) TAMBAH:
- encodeListCursor(c: { lemma: string; id: string }): string
  Buffer.from(`${lemma}\x00${id}`).toString('base64url') - separator
  NUL tidak mungkin muncul di lemma varchar, jadi tanpa escaping
  (preseden vote pakai ':' pada ISO date; NUL lebih aman untuk teks
  bebas).
- decodeListCursor(s: string): { lemma: string; id: string }
  decode base64url → split '\x00' → HARUS tepat 2 bagian dan id 26
  char; selain itu throw Error('INVALID_CURSOR_FORMAT') (preseden
  vote.repository).
- listAtoZ(params: { q: string; limit: number; wordType?: string;
  cursor?: { lemma: string; id: string } }): Promise<{ items:
  WordListItem[]; nextCursor: string | null; hasMore: boolean }>
  nextCursor SUDAH ter-encode (impl memanggil encodeListCursor pada
  item terakhir saat hasMore).

USE CASE: ListWordsUseCase - TIPIS (pola ListAdminWordsUseCase, BUKAN
SearchWordsUseCase):
a. Decode cursor SEBELUM panggil repo (helper domain); Error
   'INVALID_CURSOR_FORMAT' diteruskan untuk dipetakan controller jadi
   400 VALIDATION_ERROR (lihat endpoint).
b. repo.listAtoZ({ q: q.trim(), limit, wordType, cursor decoded }).
   published + deleted_at DIJAMIN repo (bukan opsional seperti admin
   list - endpoint ini publik).
c. TANPA search-miss recording - browsing daftar bukan pencarian gagal
   (KEPUTUSAN PRODUK; miss hanya di /words/search - kontrak 12).

REPOSITORY IMPL - listAtoZ (Drizzle):
- WHERE: isNull(words.deleted_at) AND eq(words.status, 'published')
  (published = nilai status, BUKAN kolom boolean) AND [jika q]:
  ilike(words.lemma, '%' + escapeLike(q) + '%')  (helper existing;
  TIDAK ikut word_variants - beda dari search()) AND [jika wordType]:
  eq(words.wordType, wordType) AND [jika is_verified di query]:
  eq(words.isVerified, nilai) AND [jika cursor]:
  sql`(${words.lemma}, ${words.id}) > (${c.lemma}, ${c.id})`
  (row comparison Postgres; alternatif ekuivalen:
  OR(and(eq(lemma, c.lemma), gt(id, c.id)), gt(lemma, c.lemma))).
- INNER JOIN languages (language_code untuk serializer).
- ORDER BY lower(lemma) COLLATE "C" ASC, id ASC (case-insensitive;
  collation "C" dipin supaya urutan sama di semua locale DB). Cursor
  keyset memakai ekspresi yang sama: `(lower(lemma) COLLATE "C", id) >
  (lower(c.lemma) COLLATE "C", c.id)`. Index `words_lemma_az_idx`
  menopang ekspresi ini. LIMIT limit + 1.
- hasMore = rows.length > limit → slice ke limit; nextCursor = hasMore
  ? encodeListCursor(item terakhir) : null.

ENDPOINT:

1. GET /api/v1/words (daftar semua kata A-Z)

(path '/' di createPublicWordRoutes - pola listAdminWordsRoute '/' di
admin words)
Middleware: TANPA tambahan - otomatis tercakup rateLimit 100/menit per
IP existing `routes.use('*', rateLimit({ points: 100, duration: 60 }))`
(tier baca publik Section 15). TANPA authenticate (guest boleh).
Route WAJIB didaftarkan SEBELUM '/:id' (pola '/search' existing).
Query:
  q          trim max 255, default '' - filter ILIKE %q% lemma saja
  limit      1-100, default 20
  cursor     opaque base64url komposit - z.string().optional(),
             BUKAN length(26) (beda bentuk /words/search - jangan
             share validator)
  word_type  word|idiom|peribahasa|ungkapan, opsional
  is_verified  opsional. Omit = semua yang tayang. true = hanya
             terverifikasi (dipakai sitemap web). false = belum
             diverifikasi. Halaman kata yang belum diverifikasi tetap
             bisa dibuka; web memasang noindex.
Use case: ListWordsUseCase (lihat atas).
Response 200 (envelope list standar Section 13; item = toListItem.
Bedanya dari /words/search: daftar A-Z selalu menyertakan `updated_at`):
{
  "success": true,
  "data": [
    {
      "id": "01JDWORDMAKATN000000000000",        // ULID 26
      "lemma": "makatn",
      "language_id": "01JDSBSLANG000000000000000",
      "language_code": "SBS",
      "word_type": "word",    // word|idiom|peribahasa|ungkapan
      "status": "published",  // selalu published di endpoint ini
      "is_verified": true,
      "updated_at": "2026-09-26T03:00:00.000Z" // null bila kolom kosong
    }
  ],
  "meta": {
    "limit": 20,
    "next_cursor": "bWFrYXRuAAAxSkRXT1JETUFLQVRO...", // base64url
                                             // lemma\x00id; null = habis
    "has_more": true
  }
}
Response gagal:
  400 VALIDATION_ERROR - query salah, atau cursor invalid (decode
      gagal) → details [{ "field": "cursor",
      "message": "Format cursor tidak valid" }]
  429 RATE_LIMITED - header Retry-After (middleware existing)
TIDAK ada error_code baru (ERROR_CODES.md tanpa perubahan).

KEPUTUSAN SEMANTIK (disengaja):
- q = FILTER, bukan pencarian: tanpa variasi penulisan (word_variants
  tidak di-join), tanpa normalisasi apostrof, tanpa rekam search-miss.
  Alasan: set hasil harus statis agar pagination keyset konsisten;
  pencarian semantik tetap lewat /words/search.
- status published + deleted_at IS NULL dijaga repo, bukan query param
  (beda /admin/words yang punya filter published untuk internal).
- id sebagai tie-breaker: lemma tidak unik, (lemma, id) unik karena id
  PK - keyset stabil lintas halaman tanpa duplikat/lompat.
- next_cursor null + has_more false = halaman terakhir (Section 13).

CARA DEFINISI ENDPOINT (WAJIB - Section 9): createRoute() +
app.openapi() di word.routes.ts, tags ['Words'], schema Zod request DAN
response - response pakai wordListResponseSchema existing (reuse
serializer + schema admin list). Factory createPublicWordRoutes tidak
berubah (controller sudah di-inject). Dokumentasi otomatis di /docs.

KEAMANAN & CATATAN:
- Endpoint baca publik tanpa data pribadi - tanpa authorize.
- Log akses standar (request_id, Section 14) - TANPA audit trail
  (bukan aksi admin).
- Deliverable termasuk Bruno: http/word/list-words.bru (Section 20)
  dengan blok tests (200 + meta has_more; halaman 2 pakai next_cursor
  urutan lanjut tanpa duplikat; q memfilter; cursor acak → 400;
  limit 0/101 → 400).
- Deliverable termasuk docs/json/word/list-words.200.json + baris
  mapping di docs/json/README.md di PR yang sama.

TESTING (Section 10):
- Unit list-words.use-case.test.ts (mock repository):
  * q di-trim; cursor invalid → error decode diteruskan, repo TIDAK
    dipanggil
  * passthrough limit/wordType/cursor decoded
- Integration word.repository.impl.test.ts (DB nyata):
  * urutan alfabetis stabil: lemma ASC lalu id ASC
  * keyset benar lintas lemma sama: cursor jatuh di antara dua kata
    ber-lemma identik → keduanya muncul tepat sekali
  * q ILIKE memfilter; karakter % _ \ di-q di-escape
  * hanya published + deleted_at IS NULL; word_type memfilter
  * LIMIT+1 has_more; next_cursor decode → (lemma, id) item terakhir
- E2E list-words.e2e.test.ts:
  * guest tanpa token → 200 + envelope + meta
  * cursor invalid → 400 VALIDATION_ERROR details cursor
  * browsing TIDAK menambah baris search_miss (bandingkan count
    sebelum/sesudah - q yang tidak ketemu pun tidak merekam)
  * limit=0 / limit=101 → 400
```

---

## Catatan Implementasi

- Cursor endpoint ini dan `/words/search` BEDA bentuk (komposit
  base64url vs ULID 26) - jangan share validator zod; cursor dianggap
  opaque oleh client.
- Row comparison `(lemma, id) > (c.lemma, c.id)` tertolak index
  `(lemma, id)` - pastikan EXPLAIN memakai index, bukan seq scan.
- Urutan mengikuti collation default DB (data lemma efektif lowercase).
  Jika kelak data bercampur kapital dan urutan tampak salah, upgrade
  path: expression index `(lower(lemma), id)` + `ORDER BY lower(lemma)`
  - migrasi terpisah saat kebutuhannya nyata.
- `decodeListCursor` memvalidasi id 26 char sebagai pencegahan tambahan,
  tapi bentuk cursor tetap dianggap opaque oleh client.
- `/admin/words` tetap satu-satunya jalur list dengan filter status
  untuk internal - mobile/web TIDAK boleh memanggilnya.

## Referensi Terkait

- `api-base-stack.md` - stack, envelope + cursor pagination (Section
  13), rate limit (15), ULID (19), Bruno (20)
- `01-api-tambah-kata.md` - kontrak `/words/search` (pola endpoint
  publik + `toListItem`)
- `15-api-admin-list-words.md` - preseden list tanpa search-miss
  (`ListAdminWordsUseCase`)
- `08-api-upvote-downvote.md` - preseden cursor komposit
  encode/decode + wrapping error (vote admin list)
- `12-api-search-miss-contribute.md` - batasan rekaman miss (hanya
  `/words/search`)
- `../mobile/07-mobile-list-words.md` - konsumsi endpoint di mobile
- `../web/01-web-list-words.md` - konsumsi endpoint di web
- `docs/dbdiagram.dbml` - skema database (index BARU
  `words_lemma_id_idx`)
- `ERROR_CODES.md` - katalog error code (dipakai ulang, tanpa kode baru)
- repo `http/` - http/word/list-words.bru
