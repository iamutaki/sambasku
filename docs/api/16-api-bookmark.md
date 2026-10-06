# API Bookmark - Kata Tersimpan Per User

Mengikuti `api-base-stack.md`: Section 3 (struktur folder), 7 (perubahan
skema), 9 (`@hono/zod-openapi` + Scalar), 10 (testing), 11 (versioning
`/api/v1/`), 13 (envelope & error), 15 (rate limiting), 19 (ULID). Pola
tabel user-state mengikuti `votes` (unique constraint + hard delete),
pola FK langsung ke words mengikuti `comments` - bookmark HANYA
menarget kata, jadi tidak perlu polymorphic.

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):
- SUDAH ADA: tabel words/users, authenticate, envelope, rateLimit
  middleware, pola modul 4 lapis, cursor pagination id-based (word
  search, komentar), error `WORD_NOT_FOUND`.
- Yang BELUM: tabel `bookmarks`, modul bookmark, endpoint, tests,
  Bruno, docs/json.

KEPUTUSAN PRODUK (2026-09-20):
- Bookmark HANYA user login (semua role termasuk contributor). 1 user =
  1 bookmark per kata - unique constraint, bukan logika aplikasi.
- Perilaku TOGGLE satu arah idempotent: sudah ada = lepas, belum ada =
  pasang (beda dari vote yang punya arah +1/-1).
- Bookmark TIDAK di-audit (Section 21) - preseden vote: baris
  user-state volume tinggi, bukan aksi admin.
- Sumber kebenaran API (bukan favorit lokal per device) - keputusan
  [`../backlogs/NEXT.md`](../backlogs/NEXT.md); cache offline lokal
  ditunda (bagian Medium - cache offline tipis).
- Tidak ada endpoint counts publik - jumlah bookmark orang lain bukan
  data produk (beda dari vote yang tampil publik).

---

## Prompt

```text
Buatkan modul bookmark (kata tersimpan per user) untuk backend Kamus
Digital Sambas-Indonesia, mengikuti pola modul vote (4 lapis: domain,
application, infrastructure, presentation - Section 3).

LOKASI MODUL: modules/bookmark/ (BARU - modul lengkap baru)

STRUKTUR FILE YANG PERLU DIBUAT/DIUBAH:

modules/bookmark/
├── domain/
│   └── repositories/bookmark.repository.ts     # BARU - interface
├── application/
│   └── use-cases/
│       ├── toggle-bookmark.use-case.ts         # BARU
│       └── get-my-bookmarks.use-case.ts        # BARU
├── infrastructure/
│   └── bookmark.repository.impl.ts             # BARU
└── presentation/v1/
    ├── bookmark.routes.ts                      # BARU
    ├── bookmark.controller.ts                  # BARU
    └── validators/bookmark.validator.ts        # BARU

shared/database/drizzle/schema/bookmarks.schema.ts  # BARU
shared/database/drizzle/schema/index.ts             # UBAH: +export
app.ts                                              # UBAH: wiring DI + mount

PERUBAHAN SKHEMA (WAJIB - ikuti alur Section 7):
- Tabel BARU `bookmarks`:
    id varchar(26) PK (ULID, Section 19)
    user_id varchar(26) NOT NULL ref users.id
    word_id varchar(26) NOT NULL ref words.id
    created_at timestamp NOT NULL default now
- UNIQUE (user_id, word_id) - jaminan 1 user 1 bookmark per kata,
  sekaligus penjaga race dua toggle bersamaan.
- INDEX (user_id, id) - list terbaru duluan (ORDER BY id DESC).
- TIDAK ADA kolom deleted_at/updated_at: bookmark mati = baris
  di-DELETE hard (preseden votes - baris user-state).
- Target word FK LANGSUNG (preseden comments), BUKAN polymorphic -
  bookmark hanya menarget kata; menambah jenis target kelak = migrasi
  baru saat kebutuhannya nyata.
- Alur: pnpm drizzle-kit generate --name=bookmarks → REVIEW SQL →
  pnpm drizzle-kit migrate. TANPA backfill (tabel baru).
- Update docs/dbdiagram.dbml di PR yang sama.

REPOSITORY - interface BookmarkRepository (domain):
- wordExists(wordId): Promise<boolean>
  Cek by PK + isNull(words.deleted_at). TIDAK memfilter status.
- toggle(userId, wordId): Promise<{ isBookmarked: boolean;
  bookmarkedAt: Date | null }>
  SATU transaction: DELETE ... WHERE user_id+word_id RETURNING id
  (kena → lepas, return false/null); kalau tidak kena → INSERT ...
  ON CONFLICT (user_id, word_id) DO NOTHING RETURNING created_at
  (kena race unik → re-select baris existing).
- listByUser(userId, { limit, cursor?, wordIds? }): Promise<{
  items: BookmarkItem[]; nextCursor: string | null; hasMore: boolean }>
  INNER JOIN words + isNull(words.deleted_at); ORDER BY bookmarks.id
  DESC; LIMIT+1 deteksi has_more; next_cursor = id item terakhir halaman
  (pola word search). Mode wordIds: inArray filter batch, TANPA
  pagination (hasMore selalu false).

ENDPOINT:

1. POST /api/v1/bookmarks (toggle bookmark kata)

Middleware: authenticate (SEMUA role) + rateLimit 30/menit per user_id
(tier tulis standar Section 15 - toggle bookmark interaksi lebih ringan
dari vote dan tidak butuh pengecualian 60/menit).
Body:
{
  "word_id": "01JDWORDMAKATN0000000000A"   // ULID 26 char
}
Use case: ToggleBookmarkUseCase - urutan WAJIB:
a. bookmarkRepo.wordExists → false → 404 WORD_NOT_FOUND (kata tidak
   ada / sudah soft-deleted; kode lama dipakai ulang, TIDAK ada kode
   BOOKMARK_* baru).
b. bookmarkRepo.toggle(...) - satu transaction (lihat repository).
c. TIDAK ADA audit (KEPUTUSAN PRODUK di atas).
Response 200:
{
  "success": true,
  "data": {
    "word_id": "01JDWORDMAKATN0000000000A",
    "is_bookmarked": true,     // state final
    "bookmarked_at": "2026-09-20T03:00:00.000Z"   // null setelah lepas
  }
}

2. GET /api/v1/bookmarks/my?limit=&cursor=&word_ids=

(daftar bookmark user login - halaman Bookmark di profil mobile)
Middleware: authenticate (semua role). Tanpa rate limit tambahan
(baca kecil bermakna user sendiri - pola votes/my).
Query:
  limit   1-50, default 20
  cursor  ULID 26 char (id bookmark item terakhir halaman sebelumnya)
  word_ids opsional - daftar ULID dipisah koma, maks 50, duplikat
  di-dedupe. Mode cek status batch (state tombol bookmark di detail
  kata); format salah → 400 VALIDATION_ERROR.
Response 200 (mode daftar):
{
  "success": true,
  "data": [
    {
      "word_id": "01J...",
      "bookmarked_at": "2026-09-20T03:00:00.000Z",
      "word": { "id": "01J...", "lemma": "makatn",
                "word_type": "word", "is_verified": true }
    }
  ],
  "meta": { "limit": 20, "next_cursor": null, "has_more": false }
}
Mode word_ids: TANPA meta (tidak berpaginasi), hanya kata yang
di-bookmark user yang muncul.
Ringkasan kata = subset minimal list UI (id, lemma, word_type,
is_verified) - konsisten toListItem word TANPA language/status;
endpoint list existing tidak memuat gambar.

KEPUTUSAN SEMANTIK (disengaja):
- TOGGLE di server, idempotent satu arah: client hanya kirim word_id;
  server yang memutuskan pasang/lepas. Response selalu menyertakan
  state final sehingga UI bisa merekonsiliasi (pola vote).
- EKSISTENSI kata hanya dicek di TOGGLE (endpoint tulis): bookmark ke
  kata yang sudah dihapus → 404 WORD_NOT_FOUND. Endpoint my TIDAK
  mengecek (baca; kata soft-deleted otomatis tak ikut list via JOIN).
- TIDAK memfilter status kata: kata pending_review pun bisa
  di-bookmark by id (pola vote - tidak bernahaya, tidak tampil publik).
- TANPA audit per bookmark (KEPUTUSAN PRODUK): preseden vote.
- TANPA endpoint counts publik / bookmark orang lain: data pribadi,
  tidak ada nilai produk untuk angka agregat.

CARA DEFINISI ENDPOINT (WAJIB - Section 9): createRoute() +
app.openapi() di bookmark.routes.ts, tags ['Bookmarks'], schema Zod
request DAN response (sukses + error 400/401/404/429). Query word_ids
divalidasi dengan transform: string koma → array ULID (alfabet longgar
[0-9A-Za-z]{26} - konsisten validator vote), maks 50. Factory
createBookmarkRoutes({ controller, authenticate }) - pola vote.routes.
Dokumentasi otomatis di /docs.

KEAMANAN & CATATAN:
- user_id SELALU dari token (c.get('user')), tidak pernah dari body.
- Mount /api/v1/bookmarks di app.ts (urutan tidak sensitif - tidak
  ada prefix bentrok).
- Log event bisnis 'bookmark toggled' level info + request_id
  (Section 14), TANPA audit trail.
- Deliverable termasuk Bruno: http/bookmark/toggle-bookmark.bru,
  get-my-bookmarks.bru, get-my-bookmarks-filtered.bru (Section 20)
  dengan blok tests (toggle 200 → toggle ulang is_bookmarked false;
  my 200 + meta; word_ids tanpa meta; 404 kata tidak dikenal; 401
  tanpa token).
- Deliverable termasuk docs/json/bookmark/ + baris mapping di
  docs/json/README.md di PR yang sama.

TESTING (Section 10):
- Unit toggle-bookmark.use-case.test.ts (mock repository):
  * toggle dipanggil dengan argumen benar; response diteruskan
  * wordExists false → 404 WORD_NOT_FOUND, toggle TIDAK dipanggil
- Unit get-my-bookmarks.use-case.test.ts: passthrough options.
- Integration bookmark.repository.impl.test.ts (DB nyata):
  * toggle ON → ulang OFF & baris hilang (hard delete)
  * user berbeda independen; unik (user_id, word_id) dijaga
  * wordExists hanya kata hidup (deleted_at IS NULL)
  * listByUser terbaru duluan + cursor halaman kedua + LIMIT+1
    has_more; mode wordIds tanpa paginasi; kata soft-deleted tidak
    ikut list
  * truncateAll (test-utils) ditambah tabel bookmarks
- E2E bookmark.e2e.test.ts:
  * happy path: register → login → toggle → 200 is_bookmarked true →
    toggle ulang → false + bookmarked_at null
  * my dengan token → ringkasan kata + meta; tanpa token → 401
  * word_ids → tanpa meta; 404 kata acak; 400 format word_id salah
```

---

## Catatan Implementasi

- Use case TIDAK boleh import Drizzle - transaction toggle hidup di
  `BookmarkRepositoryImpl` (pola VoteRepositoryImpl).
- ON CONFLICT DO NOTHING (bukan DO UPDATE) + re-select untuk kasus
  kalah race - toggle satu arah tidak pernah menimpa baris.
- Konstanta `MAX_BOOKMARK_WORD_IDS = 50` didefinisikan di domain
  (dipakai validator + repository) - infrastructure tidak boleh import
  presentation.
- `meta` dihilangkan (bukan null) pada mode word_ids supaya client bisa
  membedakan mode daftar vs mode cek status.
- docs/json/bookmark/ + baris mapping di docs/json/README.md + ERROR
  WORD_NOT_FOUND di ERROR_CODES.md (tanpa kode baru) di PR sama.

## Referensi Terkait

- `api-base-stack.md` - stack, envelope, rate limit, ULID, testing
- `08-api-upvote-downvote.md` - preseden tabel user-state: toggle,
  hard delete, tanpa audit, endpoint my batch
- `09-api-comment.md` - preseden FK langsung ke words + cursor
  pagination list
- `15-api-admin-list-words.md` - pola toListItem (ringkasan kata list)
- `../mobile/05-mobile-bookmark.md` - konsumsi endpoint di mobile
- `docs/dbdiagram.dbml` - skema database (tabel bookmarks BARU)
- `ERROR_CODES.md` - katalog error code (WORD_NOT_FOUND dipakai ulang)
- repo `http/` - http/bookmark/*.bru
