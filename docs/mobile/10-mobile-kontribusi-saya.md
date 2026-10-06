# Mobile - Kontribusi Saya

Mengikuti `mobile-base-stack.md`: Section 2 (3 lapis per fitur), 5 (pola
fitur lengkap), 6 (networking envelope + cursor pagination), 10
(testing), 11 (mapping error_code). Kontrak API:
`21-api-my-contributions.md`.

Tile Profil "Kontribusi Saya" membuka daftar + detail usulan milik
user login (usul kata baru dan usul perubahan). Bukan notifikasi push.

Selesai diimplementasikan: fitur `features/my_contributions/`, route
`/contributions` dan `/contributions/:kind/:id`, CTA "Lihat usulan"
setelah submit kata baru dan suggest-edit.

---

## Struktur

```text
lib/features/my_contributions/
├── domain/
│   ├── entities/my_submission.dart
│   ├── entities/my_submission_page.dart
│   ├── failures/my_contribution_failure.dart  # extends Error
│   ├── repositories/my_contribution_repository.dart
│   ├── providers/my_contribution_domain_providers.dart
│   └── usecases/my_contribution_use_cases.dart
├── data/
│   ├── repositories/my_contribution_repository_impl.dart
│   └── providers/my_contribution_data_providers.dart
├── presentation/
│   ├── models/my_contributions_state.dart
│   ├── providers/my_contributions_providers.dart
│   └── pages/  list + detail
└── my_contributions_router.dart
```

Data layer pakai Dio langsung (tanpa retrofit/freezed) karena payload
ringkas dan tidak dibagikan ke modul lain.

## Perilaku

1. `MyContributionsListController` (keepAlive): guest = state kosong
   (halaman menampilkan Masuk, sama seperti bookmark). Login = halaman
   pertama limit 20. `loadMore` guard `hasMore && nextCursor`. Invalidate
   di login/logout (`AuthStatusNotifier`).
2. List: `FTileGroup`. Judul = lemma. Subtitle = jenis · status ·
   tanggal. Ditolak + ada `review_comment`: cuplikan di subtitle.
   Status: Menunggu / Disetujui / Ditolak / Dikoreksi. Pull-to-refresh,
   skeleton, kosong "Belum ada usulan", error + coba lagi.
3. Detail display-only. Tombol **Buka kata** jika `word_id` ada dan
   status bukan pending. GET detail kata 404 `WORD_NOT_FOUND` -> tombol
   disembunyikan (entri mungkin belum terbit).
4. Ownership 404 dari API (`CONTRIBUTION_NOT_FOUND` /
   `SUGGESTION_NOT_FOUND`) tampil "Usulan tidak ditemukan" tanpa retry
   (id orang lain atau sudah hilang).
5. CTA: dialog sukses usul kata punya **Lihat usulan** di samping Ke
   beranda. Suggest-edit: toast tetap, pop form, lalu push list.

## Testing

- Mapper DTO + label jenis/status + cuplikan ditolak + ownership
  `isNotFound` di `test/features/my_contributions/`
- `flutter analyze` bersih
