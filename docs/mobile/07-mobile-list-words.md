# Mobile - Daftar Kata A-Z (List All)

Mengikuti `mobile-base-stack.md`: Section 2 (3 lapis per fitur), 5 (pola
fitur lengkap), 5a (list UI compact), 6 (networking retrofit + envelope +
cursor pagination), 7 (router per fitur), 10 (testing), 11 (mapping
error_code). Kontrak API: `18-api-list-words.md` - daftar publik semua
kata published urut lemma A-Z, cursor komposit opaque, filter `q`
server-side. Keputusan produk: `../backlogs/PLAN_LIST_ALL.md`.

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):
- SUDAH ADA (API): `GET /api/v1/words/search` (pencarian; cursor ULID,
  `ORDER BY id DESC` - TIDAK cocok untuk browsing A-Z), `GET
  /api/v1/words/:id`. Endpoint list A-Z masih kontrak (`18-api`).
- SUDAH ADA (mobile, fitur dictionary): `WordSummaryDto`/entity,
  `WordSearchPage`, `DictionaryRemoteDatasource` + repo + parsing meta
  envelope manual, `DictionarySearchNotifier` (debounce/reqId/
  sync-lock), `HomeSearchPage` (skeleton/empty/infinite scroll), route
  `/words/:id` + `WordDetailPage`.
- Yang belum dulu: halaman/provider/route list, tombol entry A-Z di
  beranda.

---

## Prompt

```text
Buatkan fitur "Daftar Kata A-Z" (list all) di mobile mengikuti pola
fitur 3 lapis + presentation (Section 2 & 5 mobile-base-stack) - EXTEND
fitur dictionary existing, jangan buat fitur baru. Kontrak API:
docs/api/18-api-list-words.md. Keputusan produk:
docs/backlogs/PLAN_LIST_ALL.md.

LOKASI: lib/features/dictionary/ (extend existing)

STRUKTUR:
├── domain/
│   ├── repositories/dictionary_repository.dart      # UBAH: +listWords
│   ├── usecases/list_words_use_case.dart            # BARU - tipis:
│   │             # ListWordsParams{q, limit=20, cursor} → repo
│   └── providers/dictionary_domain_providers.dart   # UBAH:
│             # +listWordsUseCase (watch dictionaryRepositoryProvider)
├── data/
│   ├── datasources/dictionary_remote_datasource.dart  # UBAH (+codegen):
│   │             # @GET('/api/v1/words')
│   │             # Future<ApiResponse<List<WordSummaryDto>>>
│   │             #   listWords(@Queries() Map<String, dynamic> query)
│   └── repositories/dictionary_repository_impl.dart   # UBAH: +listWords
│                 # query map {q, limit, ?cursor, ?word_type};
│                 # meta manual next_cursor/has_more - pola searchWords
├── presentation/
│   ├── models/word_list_state.dart    # BARU - plain class + copyWith
│   │             # {q, items, nextCursor, hasMore, isLoading,
│   │             #  isLoadingMore, errorMessage} + sentinel
│   │             # clearNextCursor/clearErrorMessage
│   ├── providers/word_list_providers.dart  # BARU - @riverpod
│   │             # class WordListNotifier extends _$WordListNotifier
│   │             # (autoDispose)
│   └── pages/word_list_page.dart      # BARU - HookConsumerWidget
└── dictionary_router.dart             # UBAH: +static const list =
                                       # RouteDefiner(path: '/words',
                                       # name: 'DictionaryRouter.list')
                                       # + daftar di routes (root
                                       # navigator key)

PERILAKU:
1. WordListNotifier: build awal state (q '', isLoading true) lalu fetch
   halaman pertama (limit 20). autoDispose - state mati saat page pop.
2. onQueryChanged(q): update state.q + clear errorMessage; q kosong →
   cancel debounce + reset ke full A-Z; selain itu jadwalkan debounce
   400ms → reset items/cursor/hasMore + fetch halaman pertama. Filter
   SERVER-SIDE, bukan filter lokal (supaya tetap benar saat pagination
   cursor).
3. Race guard (SALIN pola DictionarySearchNotifier, jangan reinvent):
   _reqId + _loadMoreReqId buang respons stale; sync-lock
   _isSearchingSync/_isLoadingMoreSync anti double-fire per frame;
   ref.onDispose cancel timer + mute callback.
4. loadMore(): guard !_isLoadingMoreSync && !state.isLoadingMore &&
   state.hasMore && state.nextCursor != null; sukses → merge
   [...state.items, ...page.items] + nextCursor/hasMore; gagal →
   errorMessage (item lama tetap).
5. refresh(): invalidate provider → halaman pertama dengan q terakhir
   (pull-to-refresh: ref.invalidate + await future).
6. List NORMAL tanpa grouping header huruf - client TIDAK mengurutkan
   ulang (pagination keyset; urutan server = urutan kamus en_US.utf8,
   apostrof/kapital diabaikan level primer). Grouping dari karakter
   pertama mentah berosilasi ('#, A, #, B') untuk lemma ber-apostrof -
   sengaja TIDAK dipakai (keputusan user 2026-09-20).
7. WordListPage: FScaffold + FHeader.nested 'Daftar Kata A-Z' +
   FHeaderAction.back; FTextField cari (clearable, onChange →
   onQueryChanged); ListView.separated infinite scroll (trigger di
   maxScrollExtent - 200, keyboardDismissBehavior onDrag); separator
   Gap(2) COMPACT - list memuat banyak data: tile SATU BARIS (lemma
   ellipsis + label wordTypeLabel hanya jika bukan 'word' + suffix
   badgeCheck 16 saat isVerified), TANPA subtitle bahasa (ada di
   detail).
8. State halaman: isLoading → skeleton (pola _WordSkeletonList);
   items kosong → empty 'Tidak ada kata' + hint hapus filter saat q
   berisi; errorMessage → FAlert destructive + FButton 'Coba lagi'
   (ref.invalidate); isLoadingMore → footer loading-more; body
   pull-to-refresh.
9. Tap item → FocusManager unfocus + context.push(
   DictionaryRouter.detail.path.replaceFirst(':id', item.id)) - detail
   existing TANPA perubahan; back → posisi list terjaga.

WIRING:
- Beranda: lib/features/dictionary/presentation/pages/
  home_search_page.dart - DI BAWAH tombol arah [Sambas][Indonesia],
  FTileGroup berisi FTile 'Daftar Kosakata' (subtitle 'Telusuri semua
  kata dari A sampai Z', prefix listOrdered, suffix chevronRight) →
  context.push(DictionaryRouter.list.path). Tile + subtitle dipilih
  bukan ikon app bar supaya fungsinya jelas.
- Router: tidak ada perubahan app_router.dart - DictionaryRouter.routes
  sudah diagregasi; go_router: '/words' exact hanya match list, TIDAK
  bentrok '/words/:id'.

TESTING: test/features/dictionary/
- word_list_providers_test.dart - mock repository: halaman pertama,
  loadMore merge + nextCursor, onQueryChanged reset + refetch (debounce
  di-flush), error → errorMessage (tidak throw).
- word_list_page_test.dart - widget: render item + header huruf
  (termasuk bucket '#'), tap item → push route detail (template
  bookmark_page_error_test.dart: ProviderScope override + FTheme +
  pump 5 frame).
- Fixture: test/fixtures/json/word/list-words.200.json (snapshot
  docs/json/word/ setelah endpoint jadi - bentuk item sama
  search-words.200.json).

Command verifikasi: flutter analyze && flutter test
```

---

## Catatan Implementasi

- **Cursor opaque**: `next_cursor` endpoint ini komposit base64url (beda
  dari ULID `/words/search`) - client TIDAK decode, hanya diteruskan
  apa adanya ke request berikutnya.
- **DictionaryFailure tetap plain class** (beda `BookmarkFailure extends
  Error` - 05-mobile-bookmark): `WordListNotifier` memakai
  `state.errorMessage` (Notifier), bukan throw ke AsyncValue, jadi
  auto-retry Riverpod 3 tidak berlaku. Keduanya sengaja.
- **q = filter, bukan pencarian**: hasil kosong di halaman ini TIDAK
  direkam search-miss; miss tetap tercatat lewat pencarian beranda
  `/words/search` (kontrak 12).
- **Posisi list terjaga struktural**: `/words` di-push ke root
  navigator, detail di-push di atasnya; shell IndexedStack tetap
  mounted dan autoDispose provider tetap di-watch page - tanpa
  RestorationMixin.
- Endpoint `/admin/words` JANGAN dipakai mobile - filter internal;
  endpoint publik baru sudah memaksa published.

## Referensi Terkait

- `docs/api/18-api-list-words.md` - kontrak endpoint list A-Z (cursor
  komposit, tanpa search-miss, rate limit 100/menit per IP).
- `04-mobile-search-miss-beranda.md` - batasan rekaman miss (hanya
  pencarian beranda) + preseden pola beranda.
- `mobile-base-stack.md` - Section 2, 5, 5a (list compact), 6 (cursor
  pagination retrofit), 7 (router per fitur), 10 (testing), 11
  (error_code → UI).
- `test/features/bookmark/bookmark_page_error_test.dart` - template
  widget test list page (ProviderScope override + FTheme).
- `docs/backlogs/PLAN_LIST_ALL.md` - keputusan produk fitur ini.
