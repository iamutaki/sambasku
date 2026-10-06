# Mobile - Usul Perubahan Kata Existing (Suggest Edit)

Mengikuti `mobile-base-stack.md`: Clean Architecture 3-lapis + Riverpod.
Kontrak API: `docs/api/17-api-suggest-edit-word.md`.

Dokumen ini menjelaskan fitur mobile untuk **mengusulkan perubahan pada kata
yang sudah tayang**, dengan alur:
1. User membuka detail kata → tekan tombol "Usulkan Perubahan"
2. Form muncul dengan field yang bisa diubah (mirip form edit, tapi tidak
   mengubah kata langsung)
3. Submit:
   - **Kontributor** → antrean `pending` → "Kontribusi Saya"
   - **Verifikator** → auto-apply `approved` (API) → kembali ke detail kata
4. Reviewer (`admin|root|reviewer`) mereview usulan orang lain di hub
   `/review/suggestions` atau di console (approve / reject; correct hanya
   console)

---

## 1. Route & Halaman

### Route baru

```
/suggest-edit/:wordId          → halaman form usul perubahan
```

### Halaman `SuggestEditPage`

- Hanya bisa diakses user yang sudah login (guard: redirect ke `/login`
  kalau belum auth)
- Baca `wordId` dari path parameter
- Fetch detail kata dulu (GET `/api/v1/words/:id`) untuk prefill form
- Tampilkan current state kata sebagai referensi (readonly)

### Struktur halaman

1. **Header**: "Usulkan Perubahan" + back button
2. **Info kata**: lemma, bahasa, status (published) - readonly, card informatif
3. **Form usulan** (fields yang bisa diusulkan; semua opsional kecuali alasan):
   - Lemma (text input)
   - Catatan (textarea)
   - Makna (list, expandable - ubah per makna: kelas, definisi, terjemahan)
   - Kategori (multi-select - tambah/lepas)
   - **Variasi penulisan** - list form existing + tambah form baru /
     tandai hapus (variant_type=alternative)
   - **Relasi** - reuse pola contribute relations sheet, **hanya link kata
     existing** (search + pilih relation_type); aksi hapus untuk relasi
     yang sudah ada. DILARANG Form B inline kata baru.
   - **Gambar** - pick → upload token → usulan `images[].action=add`;
     opsi hapus / set primary pada gambar existing
4. **Alasan usulan** (wajib):
   - Chip / radio `reason_code`:
     - Kesalahan penulisan (`typo`)
     - Definisi kurang tepat (`inaccurate_definition`)
     - Kurang contoh (`missing_example`)
     - Relasi/sinonim kurang (`missing_relation`)
     - Gambar kurang/salah (`image_issue`)
     - Lainnya (`other`)
   - TextField detail:
     - **Wajib** jika Lainnya (min 3 char)
     - Opsional "Detail tambahan" untuk opsi lain
5. **Kirim usulan** (button, disable saat loading)

### Prefill & empty state

- Semua field opsional - user cukup mengisi yang ingin diusulkan
- Kalau tidak ada yang diisi → tampilkan pesan "Mohon mengisi minimal satu
  perubahan yang diusulkan"
- Tampilkan diff preview (current vs proposed) di bawah form sebelum submit -
  widget readonly yang menampilkan perbedaan

---

## 2. State Management (Riverpod)

### Providers

```
features/suggest_edit/
├── domain/
│   ├── entities/suggest_edit_entity.dart
│   ├── failures/suggest_edit_failure.dart
│   └── repositories/suggest_edit_repository.dart   # abstract
├── data/
│   ├── datasources/suggest_edit_remote_datasource.dart  # retrofit
│   ├── models/                                      # DTO freezed
│   └── repositories/suggest_edit_repository_impl.dart
├── presentation/
│   ├── pages/suggest_edit_page.dart
│   ├── models/suggest_edit_state.dart
│   └── providers/
│       ├── suggest_edit_data_providers.dart
│       ├── suggest_edit_domain_providers.dart
│       └── suggest_edit_page_providers.dart        # Notifier
```

### DTO (freezed)

```dart
@freezed
class CreateSuggestionRequest with _$CreateSuggestionRequest {
  const factory CreateSuggestionRequest({
    required String wordId,
    required ProposedChanges proposedChanges,
    required String reasonCode,
    String? reasonText,
  });
}

@freezed
class ProposedChanges with _$ProposedChanges {
  const factory ProposedChanges({
    String? lemma,
    String? notes,
    List<MeaningChange>? meanings,
    List<String>? categoryIdsToAdd,
    List<String>? categoryIdsToRemove,
    List<RelationChange>? relations,
    List<VariantChange>? variants,
    List<ImageChange>? images,
  });
}

@freezed
class RelationChange with _$RelationChange {
  const factory RelationChange({
    required String action,
    required String relationType,
    required String wordId,
  });
}

@freezed
class VariantChange with _$VariantChange {
  const factory VariantChange({
    required String action,
    required String form,
    @Default('alternative') String variantType,
    String? dialectId,
  });
}

@freezed
class ImageChange with _$ImageChange {
  const factory ImageChange({
    required String action,
    String? imageId,
    String? url,
    String? providerFileId,
    String? altText,
    @Default(false) bool isPrimary,
  });
}

@freezed
class MeaningChange with _$MeaningChange {
  const factory MeaningChange({
    String? meaningId,
    MeaningAction action,         // update | add | delete
    String? wordClassId,
    String? definition,
    List<TranslationChange>? translations,
  });
}

@freezed
class SuggestionResponse with _$SuggestionResponse {
  const factory SuggestionResponse({
    required String suggestionId,
    required String wordId,
    required String wordLemma,
    required String status,
    required String createdAt,
    required String message,
  });
}

@freezed
class ChangeHistoryItem with _$ChangeHistoryItem {
  const factory ChangeHistoryItem({
    required String id,
    required DateTime timestamp,
    required Actor actor,
    required String type,        // direct_edit | suggest_edit
    required List<ChangeRecord> changes,
    SuggestionSource? source,
  });
}
```

### Notifier (presentasi)

```dart
@riverpod
class SuggestEditNotifier extends _$SuggestEditNotifier {
  @override
  SuggestEditState build() => const SuggestEditState();

  Future<void> submit({
    required String wordId,
    required ProposedChanges changes,
    required String reason,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    final result = await ref.read(suggestEditRepositoryProvider).createSuggestion(
      wordId: wordId,
      proposedChanges: changes,
      reason: reason,
    );
    result.match(
      (failure) => state = state.copyWith(
        isSubmitting: false,
        errorMessage: failure.message,
      ),
      (response) => state = state.copyWith(
        isSubmitting: false,
        success: true,
        suggestionId: response.suggestionId,
        message: response.message,
      ),
    );
  }

  Future<void> loadHistory(String wordId) async {
    state = state.copyWith(isLoadingHistory: true);
    final result = await ref.read(suggestEditRepositoryProvider).getChangeHistory(
      wordId: wordId,
    );
    result.match(
      (failure) => state = state.copyWith(
        isLoadingHistory: false,
        historyError: failure.message,
      ),
      (items) => state = state.copyWith(
        isLoadingHistory: false,
        history: items,
      ),
    );
  }
}
```

---

## 3. Repository Interface & Implementasi

### Interface (domain)

```dart
abstract interface class SuggestEditRepository {
  Future<Either<SuggestEditFailure, SuggestionResponse>> createSuggestion({
    required String wordId,
    required ProposedChanges proposedChanges,
    required String reason,
  });

  Future<Either<SuggestEditFailure, List<ChangeHistoryItem>>> getChangeHistory({
    required String wordId,
    int limit = 20,
    String? cursor,
  });
}
```

### Datasource (retrofit)

```dart
@RestApi()
abstract class SuggestEditRemoteDatasource {
  factory SuggestEditRemoteDatasource(Dio dio, {String? baseUrl});

  @POST('/api/v1/words/{wordId}/suggest-edit')
  Future<ApiResponse<SuggestionResponse>> createSuggestion(
    @Path('wordId') String wordId,
    @Body() CreateSuggestionRequest body,
  );

  @GET('/api/v1/words/{wordId}/change-history')
  Future<ApiResponse<List<ChangeHistoryItem>>> getChangeHistory(
    @Path('wordId') String wordId,
    @Queries() Map<String, dynamic> query,
  );
}
```

### Repository impl (data)

```dart
class SuggestEditRepositoryImpl implements SuggestEditRepository {
  final SuggestEditRemoteDatasource _remote;

  SuggestEditRepositoryImpl(this._remote);

  @override
  Future<Either<SuggestEditFailure, SuggestionResponse>> createSuggestion({
    required String wordId,
    required ProposedChanges proposedChanges,
    required String reason,
  }) async {
    final request = CreateSuggestionRequest(
      wordId: wordId,
      proposedChanges: proposedChanges,
      reason: reason,
    );
    return _remote.createSuggestion(wordId, request).then((response) {
      return response.match(
        (data) => Right(data),
        (failure) => Left(SuggestEditFailure.fromApiResponse(failure)),
      );
    });
  }

  @override
  Future<Either<SuggestEditFailure, List<ChangeHistoryItem>>> getChangeHistory({
    required String wordId,
    int limit = 20,
    String? cursor,
  }) async {
    final query = {'limit': limit};
    if (cursor != null) query['cursor'] = cursor;
    return _remote.getChangeHistory(wordId, query).then((response) {
      return response.match(
        (data) => Right(data ?? []),
        (failure) => Left(SuggestEditFailure.fromApiResponse(failure)),
      );
    });
  }
}
```

---

## 4. Endpoint API yang Dikonsumsi

Semua mengikuti `docs/api/17-api-suggest-edit-word.md`.

| Tujuan | Method | Path |
|--------|--------|------|
| Kirim usulan perubahan | POST | `/api/v1/words/:wordId/suggest-edit` |
| Lihat riwayat perubahan kata | GET | `/api/v1/words/:wordId/change-history` |

---

## 5. Error Handling

| error_code | Perlakuan UI |
|------------|--------------|
| `WORD_NOT_FOUND` | Tampilkan pesan "Kata tidak ditemukan", kembali ke halaman sebelumnya |
| `WORD_NOT_PUBLISHED` | Pesan "Hanya kata yang tayang bisa diusulkan perubahan" |
| `CANNOT_SUGGEST_OWN_WORD` | Pesan "Tidak bisa mengusulkan perubahan pada kata sendiri" |
| `INVALID_SUGGESTION_CHANGES` | Tampilkan pesan error per field (mis. "Minimal satu perubahan harus diisi") |
| `UNAUTHORIZED` / `TOKEN_EXPIRED` | Redirect ke halaman login |

---

## 6. UX Detail

### Antarmuka form

- Gunakan komponen form dari `forui` (FTextField, FTextArea, FSelect) sesuai
  kontribusi yang sudah ada (`docs/mobile/05-mobile-bookmark.md`).
- Layout: scrollable column, padding 16px, gap 12px antar field.
- Label field: Bahasa Indonesia, jelas dan singkat.

### Diff preview

- Widget readonly yang menampilkan "Perubahan yang akan diaplikasikan":
- Format: list item per perubahan, contoh:
  - "Lemma: `kete'` → `kete'` (tidak berubah)"
  - "Definisi (makna 1): Dari '...lama...' → '...baru...'"
  - "Kategori ditambahkan: [nama kategori]"
- Hanya tampilkan field yang `changed: true` (lihat respons API diff).

### Feedback setelah submit

- **Banner + CTA pre-submit** (role lokal via `isVerifierRole`):
  - Kontributor: banner "Admin mereview sebelum tayang", CTA "Kirim Usulan".
  - Verifikator (`admin|editor|root|reviewer`): banner "langsung diterapkan,
    tanpa antrean", CTA "Simpan perubahan".
- **Toast + navigasi post-submit** dari `data.status` response
  (`POST .../suggest-edit`), bukan tebakan role saja:
  - `approved`: toast "Perubahan langsung diterapkan…", invalidate detail
    kata + change-history, `pop` ke detail (bukan antrean).
  - `pending`: toast antrean (verified vs apply_pending), invalidate
    Usulanku, navigasi ke `/contributions`.
  - Status absen: fallback `isVerifierRole` (kompatibel kontrak lama).
- Kalau gagal: tampilkan pesan error di bawah form, biarkan form tetap
  terisi (user bisa memperbaiki).

### Hub Area Verifikator (`/review`) - 3 modul

Hanya role `canReviewQueue` (`admin|root|reviewer`). `editor` bisa
self-apply saat suggest-edit, tetapi **tidak** melihat hub (selaras
console: antrean approve admin tanpa editor).

| Tile | Route | Isi |
|------|-------|-----|
| Mulai tinjau | `/review/queue` | antrean kontribusi |
| Usulan edit | `/review/suggestions` | `GET /api/v1/admin/word-suggestions?status=pending` |
| Riwayat tinjauan | `/review/history` | riwayat kontribusi milik saya (`mine=true`) |

Dot pending di profil/nav: kontribusi **atau** usulan edit pending (OR).

### Batasan mobile vs console (usulan edit)

- Mobile detail usulan: **Setujui / Tolak** saja. Aksi **Koreksi**
  (`POST .../correct`) tetap console-only.
- Setujui di mobile tanpa `image_decisions` / file sensor: semua gambar
  staging ImageKit di-promote (default API). Sensor/tolak per gambar
  hanya di console (multipart approve).
- Riwayat kontribusi + usulan edit **belum** digabung jadi satu feed
  (fase terpisah).

### Riwayat perubahan di detail kata

- Tambahkan section "Riwayat Perubahan" di halaman detail kata
  (`features/dictionary/presentation/pages/word_detail_page.dart`).
- Muncul di bagian bawah, setelah semua konten kata (makna, contoh, gambar, dll.)
- Header: "Riwayat Perubahan" + button "Lihat Semua" yang menuju halaman
  terpisah jika terlalu banyak.
- Item: timestamp, actor (username), tipe (langsung / usulan), daftar perubahan
  singkat.
- Bisa di-expand untuk melihat detail perubahan.

---

## 7. Testing

- Unit test: repository impl (mock datasource) - verifikasi mapping DTO ↔ entity.
- Widget test: form usul perubahan - test submit dengan field lengkap, test
  validation (kosong → error), test loading state, test error state.

---

## Referensi Terkait

- `docs/api/17-api-suggest-edit-word.md` - kontrak API lengkap
- `docs/mobile/mobile-base-stack.md` - arsitektur & konvensi
- `docs/api/03-api-kontribusi-verifikasi.md` - pola kontribusi (referensii
  alur review)
- `docs/mobile/05-mobile-bookmark.md` - pola form + state management
  (sebagai acuan UX)
