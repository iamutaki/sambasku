# Mobile - Bookmark Kata (Per User)

Mengikuti `mobile-base-stack.md`: Section 2 (3 lapis per fitur), 5 (pola
fitur lengkap), 6 (networking retrofit + envelope + cursor pagination),
10 (testing), 11 (mapping error_code). Kontrak API:
`16-api-bookmark.md` - toggle + daftar milik user; sumber kebenaran API
(bukan favorit lokal per device).

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):
- SUDAH ADA (API): `POST /api/v1/bookmarks` (toggle idempotent satu
  arah, 30/menit per user), `GET /api/v1/bookmarks/my` (cursor +
  filter `word_ids` mode cek status batch).
- SUDAH ADA (mobile, fitur lain): auth status provider (isAuth), pola
  fitur 3+1 lapis, retrofit + `ApiResponse`, riverpod codegen, pola
  list controller cursor (komentar), tile Bookmark di Profil (masih
  toast "segera hadir").
- Yang belum dulu: fitur bookmark itu sendiri (modul
  `features/bookmark`), halaman Bookmark, wiring tombol di detail kata.

Selesai diimplementasikan (verifikasi terakhir 2026-09-20): `flutter
analyze` bersih, `flutter test` hijau (termasuk `test/features/bookmark/`
- DTO + reproduksi bug 4xx tanpa loop), codegen retrofit + riverpod
tanpa konflik.

---

## Prompt

```text
Buatkan fitur bookmark kata di mobile mengikuti pola fitur 3 lapis +
presentation (Section 2 & 5 mobile-base-stack).

LOKASI: lib/features/bookmark/ (fitur baru)

STRUKTUR:
├── domain/
│   ├── entities/bookmark_word.dart    # BookmarkWord{id,lemma,wordType,
│   │                                  #   isVerified,wordTypeLabel}
│   ├── entities/bookmark_item.dart    # BookmarkItem{wordId,bookmarkedAt,word}
│   ├── entities/bookmark_page.dart    # BookmarkPage{items,nextCursor,hasMore}
│   ├── entities/bookmark_status.dart  # BookmarkStatus{wordId,isBookmarked,
│   │                                  #   bookmarkedAt} - state toggle
│   ├── failures/bookmark_failure.dart # BookmarkFailure EXTENDS Error (lihat
│   │                                  #   catatan) + isNotFound/isRateLimited
│   ├── repositories/bookmark_repository.dart  # toggle/myBookmarks/statuses
│   ├── providers/bookmark_domain_providers.dart
│   └── usecases/  toggle_bookmark / get_my_bookmarks / get_bookmark_statuses
├── data/
│   ├── models/  toggle_bookmark_request_dto / toggle_bookmark_response_dto /
│   │            bookmark_item_dto (+BookmarkWordDto nested)  (freezed)
│   ├── datasources/bookmark_remote_datasource.dart  # retrofit:
│   │            POST /api/v1/bookmarks, GET /my (Queries limit/cursor/word_ids)
│   ├── repositories/bookmark_repository_impl.dart   # _mapDio + meta manual
│   └── providers/bookmark_data_providers.dart
├── presentation/
│   ├── models/bookmark_list_state.dart    # {items,nextCursor,hasMore,
│   │                                      #  isLoadingMore} + copyWith
│   ├── providers/bookmark_providers.dart  # BookmarkToggleController
│   │                                      #   (family wordId) + ListController
│   ├── widgets/bookmark_button.dart       # dumb stateful, ikon
│   │                                      #   bookmark/bookmarkCheck
│   └── pages/bookmark_page.dart           # list + guest + empty + error
└── bookmark_router.dart                   # /bookmarks (root navigator)

PERILAKU:
1. BookmarkToggleController.build(wordId): guest (snapshot authStatus,
   BUKAN await .future) = unbookmarked; saat login, seed status dari
   GET /my?word_ids= (degrade senyap saat 401 stale-session - pola
   VoteController). toggle() return BookmarkFailure? (null = sukses);
   state di-update dari response server (state final, bukan optimistik).
2. BookmarkListController.build(): guest = state kosong (halaman
   menampilkan prompt login); login = halaman pertama (limit 20).
   loadMore() guard hasMore && !isLoadingMore && nextCursor != null
   (pola CommentListController). remove(wordId) optimistik + restore
   saat gagal; toast failure di UI.
3. BookmarkButton: widget tampilan murni - TIDAK mengambil data &
   TIDAK menjaga login guard; guard _inFlight anti double-tap;
   Semantics label 'Simpan/Lepas kata dari bookmark'.
4. Guard login: caller (adapter _WordBookmarkHeaderAction di
   word_detail_page) memeriksa isAuth sebelum toggle; anonim → toast
   'Masuk dulu untuk menyimpan kata' + push /login (pola _vote).
5. Halaman Bookmark: guest → prompt login; empty → 'Belum ada kata
   tersimpan.'; error → pesan + tombol Coba lagi (ref.invalidate);
   baris kata → tap push /words/:id, tombol hapus → remove.

WIRING:
- Detail kata: lib/features/dictionary/presentation/pages/
  word_detail_page.dart - suffixes FHeader.nested =
  _WordBookmarkHeaderAction(wordId) (tombol hidup sejak loading state
  karena wordId sudah diketahui).
- Profil: lib/features/profile/presentation/pages/profile_page.dart -
  tile Bookmark (hanya tampil saat login) → context.push('/bookmarks').
- Router: lib/core/router/app_router.dart + BookmarkRouter.routes.

TESTING: test/features/bookmark/bookmark_dto_test.dart (deserialisasi
fixture docs/json/bookmark), bookmark_page_error_test.dart (4xx →
error UI sekali, TANPA loop rebuild). Fixture:
test/fixtures/json/bookmark/*.

Command verifikasi: flutter analyze && flutter test
```

---

## Catatan Implementasi

- **BookmarkFailure extends Error (DELIBERAT)**: Riverpod 3 auto-retry
  (`defaultRetry`, maks 10x backoff 200ms-6.4s) hanya berlaku untuk
  exception non-Error. Failure 4xx (401/404/429) bersifat terminal -
  sebagai objek biasa, tiap kegagalan build memicu retry: halaman
  stuck loading + spam request (reproduksi: test error test dengan
  repository selalu gagal - panggilan jadi 2+ dan UI spinner terus).
  Sebagai Error, build yang throw langsung AsyncError → UI error.
  VoteFailure/CommentFailure belum memakai pola ini (bug laten sama -
  keputusan terpisah).
- Auth snapshot di build memakai `ref.watch(authStatusProvider).value`
  (bukan `await .future`): await .future memicu rebuild ganda saat
  transisi loading→data; provider tetap rebuild otomatis saat
  authStatus berubah karena di-watch.
- Toggle memakai RESPONSE server sebagai source of truth (pola vote):
  is_bookmarked final dari backend, bukan optimistik.
- Mode `word_ids` (cek status batch) sengaja TANPA meta - client
  membedakan mode daftar vs cek status dari keberadaan meta.
- Ringkasan kata minimal (id, lemma, word_type, is_verified) - endpoint
  list API memang tidak mengirim gambar/language; detail lengkap diambil
  saat baris di-tap (buka /words/:id).

## Referensi Terkait

- `docs/api/16-api-bookmark.md` - kontrak bookmark (toggle/my,
  keputusan semantic, rate limit 30/menit).
- `docs/mobile/02-vote-upvote-downvote.md` - preseden toggle controller
  + degrade stale-session + guard login di caller.
- `mobile-base-stack.md` - Section 2, 5 (pola fitur), 6 (networking +
  cursor pagination), 10 (testing), 11 (mapping error_code → UI).
- `mobile/test/fixtures/json/bookmark/` - fixture DTO (snapshot
  docs/json/bookmark).
- `docs/backlogs/NEXT.md` - bookmark selesai; cache offline masih
  medium (bukan `SharedPreferences` untuk data kamus besar).
