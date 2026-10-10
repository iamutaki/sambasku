# Plan - Daftar Semua Lemma A-Z (List All)

Halaman browser kamus: semua lemma urut abjad A-Z, ada kotak pencarian,
tap item → halaman detail kata yang sudah ada (`/words/:id`).

Fondasi (JANGAN diduplikasi):

- Mobile: `docs/mobile/mobile-base-stack.md` (3 lapis + presentation,
  retrofit, Riverpod, envelope); fitur `features/dictionary` (search +
  detail) jadi pola.
- API: `01-api-tambah-kata.md` (search publik), `15-api-admin-list-words.md`.
- **GAP kunci**: `GET /words/search` diurut `ORDER BY words.id DESC`
  (terbaru dulu, ULID) dan cursor = ULID tunggal. Endpoint ini TIDAK BISA
  dipakai untuk browsing A-Z: urutan salah dan cursor tidak mendukung
  keyset alfabetis. Perlu endpoint baru.

---

## Keputusan

### API

1. **Endpoint baru**: `GET /api/v1/words` - publik tanpa auth,
   `published` saja + `deleted_at IS NULL`, rate limit sama dengan
   `/words/search` (100/menit per IP).
2. **Query**: `q` (default '', filter `ILIKE %q%` pada lemma - TANPA
   variasi penulisan, browsing bukan pencarian), `limit` (1-100, default
   20), `cursor` (opaque, opsional), `word_type` opsional.
3. **Urutan**: `ORDER BY lower(lemma) COLLATE "C" ASC, id ASC`
   (case-insensitive; collation "C" dipin agar sama di semua DB).
   **Cursor komposit** `(lower(lemma), id)` karena lemma tidak unik -
   keyset `(lower(lemma) COLLATE "C", id) > (lower(c.lemma) COLLATE "C",
   c_id)`. Format cursor wire: base64url `lemma\x00id` (lemma asli
   item terakhir; server membandingkan via `lower()`), TIDAK pakai zod
   `length(26)` ULID seperti search lama.
4. **TIDAK mencatat search-miss** - browsing daftar bukan pencarian
   gagal; jangan pakai jalur `SearchWordsUseCase` yang merekam miss.
   Search-miss hanya direkam di `/words/search` (kontrak `12-api`).
5. **Item = `WordSummary`** sama persis dengan `/words/search`
   (id, lemma, language_id, language_code, word_type, is_verified,
   status) - reuse serializer yang ada.
6. Dokumentasi: buat `docs/api/18-api-list-words.md` (17 sudah dipakai
   suggest-edit) + contoh request/response di `http/` setelah endpoint
   jadi. Contract mobile: `docs/mobile/07-mobile-list-words.md`.

### Mobile

1. **Halaman baru** `WordListPage` ("Daftar Kata A-Z") di
   `features/dictionary/presentation/pages/`; route `/words` (nama
   `DictionaryRouter.list`) - kompatibel dengan `/words/:id` existing
   (go_router: `/words` exact hanya match list).
2. **Pencarian di halaman**: `FTextField` + debounce, kirim `q` ke
   endpoint yang sama (filter server-side, BUKAN filter lokal) supaya
   tetap benar saat pagination cursor.
3. **List**: `ListView.builder` infinite scroll pakai `nextCursor`
   (pola sama `dictionary_search_providers.dart`); list NORMAL tanpa
   grouping header huruf - urutan server (lemma ASC = urutan kamus)
   dipakai apa adanya, client tidak mengurutkan ulang; tile compact
   satu baris karena list memuat banyak data.
4. **Tap item** → `context.push('/words/${item.id}')` - detail existing,
   tidak ada perubahan di `WordDetailPage`.
5. **Entry point**: tile "Daftar Kosakata" (dengan subtitle) di bawah
   tombol arah `[Sambas][Indonesia]` pada `HomeSearchPage` - lebih jelas
   fungsinya daripada ikon kecil di AppBar.
6. **Reuse**: `WordSummaryDto` + envelope parsing; provider baru
   `word_list_providers.dart` meniru `dictionary_search_providers.dart`;
   datasource: method `listWords(@Queries() Map)` baru di
   `DictionaryRemoteDatasource`.
7. State standar sesuai [`NEXT.md`](../NEXT.md) (Standar selesai): skeleton, empty, error + retry,
   pull-to-refresh, loading-more footer.

### Web

1. Contract: `docs/web/01-web-list-words.md` - stack-agnostic (submodule
   `web/` masih kosong); route `/words`, cursor + filter `q` server-side
   (perilaku sama mobile), tap → `/words/:id` (backlog terpisah).

---

## Prompt

```text
Tambah fitur "daftar semua lemma A-Z" (lihat docs/PLAN_LIST_ALL.md).

API (dulu):
1. GET /api/v1/words publik: published only, ORDER BY lemma ASC, id ASC,
   keyset cursor komposit (lemma,id) base64url - bukan ULID. q opsional
   ILIKE %q% lemma saja (tanpa variasi, tanpa rekam search-miss,
   tanpa jalur SearchWordsUseCase). limit 1-100 default 20, word_type
   opsional. Item WordSummary sama dengan /words/search. Rate limit
   100/menit per IP seperti /words/search.
2. Test: urutan alfabetis stabil, cursor keyset benar lintas lemma sama,
   q memfilter, guest bisa akses, tidak ada baris search-miss baru.
3. Dokumen: docs/api/18-api-list-words.md + contoh di http/.

MOBILE:
4. DictionaryRemoteDatasource.listWords(@Queries()); repo + use case
   tipis (pola search existing); provider word_list_providers.dart
   (state: items, nextCursor, isLoadingMore, error, q debounced).
5. WordListPage: FTextField pencarian (debounce → reset + refetch),
   ListView.builder infinite scroll nextCursor, header huruf per grup
   (non-alfabet → #), skeleton + empty + error retry + pull-to-refresh
   + footer loading-more. Tap → context.push('/words/${item.id}').
6. Route: DictionaryRouter.list = /words; tombol ikon A-Z di AppBar
   HomeSearchPage → context.push('/words').
7. Tes: DTO parse fixture, provider pagination + filter q, widget test
   render + tap item buka detail.

Verifikasi: api → npm run test && npm run typecheck; mobile →
flutter analyze && flutter test.
```

---

## Catatan Implementasi

- Cursor endpoint ini dan `/words/search` BEDA bentuk (komposit base64
  vs ULID 26) - jangan share validator zod; cursor dianggap opaque oleh
  client.
- Jangan panggil `/admin/words` dari mobile; endpoint publik baru sudah
  memaksa published.
- `q` di halaman ini = filter, bukan pencarian kamus; miss yang gagal
  tetap tercatat lewat pencarian beranda (`/words/search`), bukan di sini.
- Ditunda (YAGNI): sidebar quick-jump huruf (butuh filter prefix di
  server), grouping per dialek, cache offline daftar (menunggu item #5
  cache [`NEXT.md`](../NEXT.md)).

## Selesai jika

- Buka halaman → lemma tampil urut alfabetis (list normal), scroll
  terus memuat halaman berikutnya tanpa lompat/duplikat.
- Ketik di kotak cari → list terfilter (server-side), hapus query →
  kembali full A-Z.
- Tap lemma → halaman detail kata existing, back → posisi list terjaga.
- Guest + login, tema terang/gelap, jaringan lambat, dan error/retry
  berperilaku benar; tidak ada search-miss palsu tercatat saat browsing.
