# Mobile - Profil Publik + Atribusi Verifikator

Mengikuti `mobile-base-stack.md`: Section 2 (3 lapis per fitur), 5 (pola
fitur lengkap), 6 (networking retrofit + envelope), 10 (testing), 11
(mapping error_code). Kontrak API: `19-api-profil-publik.md`.

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):
- SUDAH ADA (API): `GET /api/v1/users/:username` (publik, 100/menit/IP),
  `verified_by` object + `verified_at` di `GET /api/v1/words/:id`.
- SUDAH ADA (mobile): tab Profil (pengaturan akun sendiri), detail kata
  dengan badge check `isVerified`, komentar dengan `username`, go_router
  root navigator, pola 3+1 lapis.
- Yang belum: halaman profil orang lain, chip verifikator di detail
  kata, tap username komentar.

Selesai diimplementasikan: fitur `user_profile` terpisah dari tab
Profil. Route `/users/:username`. Chip di detail kata dan username
komentar membuka halaman ini.

---

## Prompt

```text
Buatkan fitur profil publik di mobile mengikuti pola 3 lapis +
presentation (Section 2 & 5 mobile-base-stack).

LOKASI: lib/features/user_profile/ (fitur baru, JANGAN campur dengan
tab ProfilePage)

STRUKTUR:
├── domain/
│   ├── entities/public_profile.dart
│   ├── failures/user_profile_failure.dart  # extends Error
│   ├── repositories/user_profile_repository.dart
│   ├── providers/user_profile_domain_providers.dart
│   └── usecases/get_public_profile_use_case.dart
├── data/
│   ├── models/public_profile_dto.dart  (freezed)
│   ├── datasources/user_profile_remote_datasource.dart  # retrofit
│   ├── repositories/user_profile_repository_impl.dart
│   └── providers/user_profile_data_providers.dart
├── presentation/
│   ├── providers/user_profile_providers.dart  # family username
│   └── pages/public_profile_page.dart
└── user_profile_router.dart  # /users/:username + open(context, username)

PERILAKU:
1. GET /api/v1/users/{username} tanpa auth. Path encode:
   UserProfileRouter.open memakai Uri.encodeComponent; go_router
   men-decode path parameter.
2. Halaman: username judul, badge verifikator dari is_verifier (bukan
   hitung ulang role di client), role label (reuse ProfilePage.roleLabels),
   joined_at via formatDateTimeIso, dua angka stats. 404 USER_NOT_FOUND
   pesan "Pengguna tidak ditemukan" + retry. Rate limit 429.
3. WordDetailDto + WordDetail: field verifiedBy
   (json_key verified_by) { username, role } | null; selfVerified
   (json_key self_verified, default false).
4. word_detail_page: ikon badgeCheck (isVerified) dan teks atribusi
   sama-sama tap → showModalBottomSheet (Material, pola
   image_sheet_drawer). Copy: selfVerified → "Dibuat dan diverifikasi
   oleh {username}"; selain itu → "Diverifikasi oleh {username}" +
   verified_at via formatDateTimeIso. Tombol Lihat profil →
   UserProfileRouter.open. Jika isVerified tapi verifiedBy == null:
   sheet tetap, copy "Verifikator tidak diketahui" (tanpa tombol profil).
5. word_comments_section: tap username jika tidak null. "Pengguna
   terhapus" tidak navigasi.

TESTING:
- DTO fromJson fixture docs/json/users (200 + 404)
- WordDetailDto verified_by null vs object
- flutter analyze bersih
```
