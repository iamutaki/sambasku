# Fix: Invalidate Detail Kata Setelah Usulan Dikirim (Issue #28)

## Akar Masalah

Setelah user mengajukan usulan kata, halaman detail kata masih menampilkan data basi karena dua lapis cache tidak dihapus:

1. **Riverpod `wordDetailProvider`** ([mobile/lib/features/dictionary/presentation/providers/word_detail_providers.dart](mobile/lib/features/dictionary/presentation/providers/word_detail_providers.dart)): `@Riverpod(keepAlive: true)`, kunci bisa lemma atau ULID. State lama tetap hidup di memori.
2. **L1 HTTP cache** di [dictionary_repository_impl.dart](mobile/lib/features/dictionary/data/repositories/dictionary_repository_impl.dart): `GET /api/v1/words/{id}` dan `GET /api/v1/words/lemma/{lemma}` di-cache dengan `CacheClass.dictionaryDetail` TTL 5 menit. Response `WORD_NOT_FOUND` juga masuk cache negatif (`negative404`, TTL 2 menit).

Flow submit di [contribute_page.dart](mobile/lib/features/contribution/presentation/pages/contribute_page.dart) hanya `invalidate(myContributionsListControllerProvider)` di baris 1131. Bandingkan dengan flow usul edit yang sudah benar: [suggest_edit_page.dart](mobile/lib/features/suggest_edit/presentation/pages/suggest_edit_page.dart) memanggil `ref.invalidate(wordDetailProvider(widget.wordId))`.

## Perubahan

Semua di `mobile/`, 2 file + 1 test.

### 1. [contribute_page.dart](mobile/lib/features/contribution/presentation/pages/contribute_page.dart)

Helper kecil untuk invalidasi menyeluruh satu kata. Delete cache L1 butuh async (Hive), Riverpod invalidate sinkron. Bentuk paling sederhana: satu fungsi `Future<void>` di level file yang sama dengan handler submit.

```dart
/// Issue #28: setelah usulan kata terkirim, hapus cache detail kata
/// (Riverpod keepAlive + L1 HTTP) supaya buka lagi tidak lihat data basi.
Future<void> _invalidateWordDetail(WidgetRef ref, String wordId, String lemma) async {
  // Kunci provider bisa ULID atau lemma, keduanya di-flush.
  ref.invalidate(wordDetailProvider(wordId));
  ref.invalidate(wordDetailProvider(lemma));

  // L1 cache: endpoint by-id dan by-lemma.
  final store = ref.read(responseCacheStoreProvider);
  await Future.wait([
    store.delete(buildCacheKey(method: 'GET', path: '/api/v1/words/$wordId')),
    store.delete(
      buildCacheKey(
        method: 'GET',
        path: '/api/v1/words/lemma/${Uri.encodeComponent(lemma)}',
      ),
    ),
  ]);
}
```

Impor tambahan: `responseCacheStoreProvider` dari `core/cache/cache_providers.dart` (sudah ada di file, tinggal pakai; `buildCacheKey` juga sudah diimpor).

Pemanggilan, di `_showSuccessDialog` atau tepat setelah sukses submit di `ref.listen` (baris 360): panggil sekali dengan `wordId` dari `SubmitWordResult` dan lemma yang diketik user. Waktu paling aman: saat dialog sukses muncul (sama seperti `logContributeSuccess`), tidak perlu menunggu user memilih aksi dialog.

### 2. [bulk_contribute_page.dart](mobile/lib/features/contribution/presentation/pages/bulk_contribute_page.dart)

Sama polanya, di handler sukses batch (sekitar baris 210): loop baris yang punya `wordId` tidak-null, panggil helper yang sama per kata. Helper dipindah ke file shared kecil `presentation/widgets/` atau file utils contribution supaya tidak duplikat; satu fungsi publik, tanpa abstraksi lain.

### 3. Test: [mobile/test/features/contribution/contribute_page_test.dart](mobile/test/features/contribution/contribute_page_test.dart)

Satu kasus: submit sukses dengan kata yang sebelumnya dibuka (provider terisi), assert `wordDetailProvider` kembali ke `AsyncLoading`/ter-refetch setelah submit, dan entry L1 cache by-id terhapus dari store fake.

## Yang Tidak Diubah

- Tidak ubah `keepAlive` provider (berlaku global, dampaknya ke semua navigasi).
- Tidak ubah TTL `CachePolicy`.
- Tidak sentuh endpoint API.
- Tidak commit, tidak push (rule `no-auto-commit-push`).

## Verifikasi

1. `flutter analyze` di `mobile/`.
2. `flutter test test/features/contribution/` di `mobile/`.
