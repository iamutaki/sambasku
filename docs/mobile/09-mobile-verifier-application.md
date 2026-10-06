# Mobile - Pengajuan Jadi Verifikator

Mengikuti `mobile-base-stack.md`: Section 2 (3 lapis per fitur), 5 (pola
fitur lengkap), 6 (networking retrofit + envelope), 10 (testing), 11
(mapping error_code). Kontrak API: `docs/api/20-api-verifier-application.md`.

Contributor membuka tile di tab Profil, mengisi HP + alamat textarea +
min. 1 sosial, lalu kirim. Halaman status-first dari GET `/me`:
NONE (form), PENDING (layar ditinjau, tanpa form), REJECTED (copy
beda + form kirim ulang), APPROVED (sukses + CTA masuk ulang).
Screenshot sosial lewat kamera/galeri + upload-token (bukan
selfie/avatar akun).

Pada state form (NONE / REJECTED), ringkasan peran + CTA
"Pelajari peran verifikator" membuka `/verifier-application/about`
(halaman statis penjelasan peran).

---

## Prompt

```text
Buatkan fitur pengajuan jadi reviewer di mobile, pola 3 lapis +
presentation (Section 2 & 5 mobile-base-stack).

LOKASI: lib/features/verifier_application/ (fitur baru)

STRUKTUR:
├── domain/
│   ├── entities/verifier_application.dart
│   ├── entities/social_link.dart
│   ├── failures/verifier_application_failure.dart
│   ├── repositories/verifier_application_repository.dart
│   ├── providers/verifier_application_domain_providers.dart
│   └── usecases/
│       ├── get_my_verifier_application_use_case.dart
│       ├── submit_verifier_application_use_case.dart
│       └── resubmit_verifier_application_use_case.dart
├── data/
│   ├── models/verifier_application_dto.dart  (freezed)
│   ├── models/submit_verifier_application_request_dto.dart
│   ├── datasources/verifier_application_remote_datasource.dart
│   ├── repositories/verifier_application_repository_impl.dart
│   └── providers/verifier_application_data_providers.dart
├── presentation/
│   ├── providers/verifier_application_providers.dart
│   └── pages/
│       ├── verifier_application_page.dart
│       └── verifier_role_page.dart
└── verifier_application_router.dart
    # /verifier-application
    # /verifier-application/about

UBAH:
- profile_page.dart group Akun: tile "Jadi verifikator" HANYA jika
  status.role == 'contributor'. onPress -> context.push('/verifier-application')
- profile_page.dart tile Keluar: setelah logout sukses → context.go('/login')
- app_router.dart: ...VerifierApplicationRouter.routes

PERILAKU:
1. GET /api/v1/verifier-applications/me (auth) setiap buka halaman.
   404 VERIFIER_APPLICATION_NOT_FOUND (NONE) -> form kosong + FAlert
   ringkas tentang peran + CTA "Pelajari peran verifikator"
   (push /verifier-application/about).
   pending -> layar status saja: "Pengajuan sedang ditinjau" (tanpa
     form, tanpa tombol kirim).
   rejected + admin_comment non-kosong (needsRevision) -> FAlert
     "Perlu perbaikan" + isi catatan admin + form editable + "Kirim ulang"
     (+ CTA pelajari peran seperti NONE).
   rejected tanpa admin_comment -> FAlert "Pengajuan ditolak" /
     "Data kurang lengkap. Perbaiki lalu kirim ulang." + form + "Kirim ulang"
     (+ CTA pelajari peran seperti NONE).
   approved -> layar sukses (tanpa form) + CTA "Masuk ulang"
     (logout lalu context.go('/login')). Tile Profil tetap hanya
     contributor (JWT lama) sampai login ulang.
2. Form:
   - HP: sama register (prefix +62 lock, digitsOnly, kirim digit nasional).
     Wajib.
   - Alamat: FTextField multiline (minLines 3, maxLines 6), teks bebas,
     min 10 max 500. Hint: "Alamat lengkap tempat tinggal/domisili".
   - Sosial: tiap akun vertikal. Tile platform membuka bottomsheet enum;
     FTextField "Nama / username" (bukan URL); slot screenshot 1 gambar
     (kamera atau galeri via showImageSheetDrawer). Direct-upload
     GET upload-token folder=/verifier-applications, token sekali pakai.
     Submit hanya jika setiap item punya username min 2 + screenshot
     selesai upload. Min 1, max 5. Platform: instagram, facebook,
     tiktok, youtube, x, website.
3. Submit pertama: POST. Sudah rejected: PATCH.
4. Mapping error_code:
   APPLICATION_ALREADY_EXISTS, ALREADY_VERIFIER, PHONE_ALREADY_EXISTS,
   VERIFIER_APPLICATION_NOT_REJECTED, RATE_LIMITED, VALIDATION_ERROR,
   IMAGE_UPLOAD_UNAVAILABLE.
   Pesan envelope tampil apa adanya (Bahasa Indonesia).
5. Sukses POST/PATCH: toast saja; JANGAN pop. Status jadi pending di
   halaman yang sama.

TESTING:
- Entity: needsRevision vs isHardRejected dari admin_comment
- DTO fromJson fixture docs/json/verifier-applications (200 + 404)
- flutter analyze bersih
```

## Catatan implementasi (status-first)

API tetap `pending | rejected | approved`. Di mobile, view-state:

| View | Sumber | UI |
|------|--------|-----|
| NONE | 404 / null | Ringkas peran + CTA about + form |
| PENDING | status pending | Alert ditinjau saja |
| REJECTED (perbaikan) | rejected + comment | Alert + CTA about + form |
| REJECTED (kurang) | rejected tanpa comment | Alert + CTA about + form |
| APPROVED | status approved | Sukses + CTA Masuk ulang |

Entity helper: `needsRevision`, `isHardRejected`.

Tidak ada perubahan API status enum.
