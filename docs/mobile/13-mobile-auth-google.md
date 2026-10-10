# Mobile - Masuk dengan Google

Status **V1 implemented**. Kontrak API:
[`24-api-auth-google.md`](../api/24-api-auth-google.md). Sumber produk:
[`AUTH_GOOGLE.md`](../backlogs/AUTH_GOOGLE.md). Admin tidak diubah.

Extend `lib/features/auth/` (bukan fitur baru). Satu use case untuk
**login dan daftar**.

## Layar

**Login** (`login_page.dart`): setelah tombol Masuk, pemisah "atau",
tombol **Masuk dengan Google**, lalu tautan daftar / tamu.

**Daftar** (`register_page.dart`): setelah tombol Daftar, pemisah
"atau", tombol **Daftar dengan Google** (ajakan eksplisit, bukan label
login), lalu tautan "Sudah punya akun?". Tap Google di sini **langsung
sesi** ke `/` - jangan panggil `RegisterUseCase`, jangan halaman OTP.

Widget bersama: `GoogleAuthButton` + `GoogleAuthDivider`.

Tombol **hanya** dirender jika client ID flavor aktif terisi
(`googleAuthEnabledProvider`) dan belum 503
(`googleUnavailable` di state).

## Alur

1. Tap → `GoogleSignInPort.authenticate()` (`google_sign_in` 7.x:
   `initialize(serverClientId:)` sekali, lalu `authenticate()`).
2. User batal / dismiss sheet → diam (bukan `AuthFailure`, bukan snackbar).
3. ID token kosong → "Tidak bisa masuk dengan Google."
4. `POST /api/v1/auth/google` `{ id_token, client_type: mobile }`.
5. Sukses: `_persistSession` (wajib `refresh_token`) +
   `AuthStatusNotifier.markLoggedIn` + `go('/')`. Jangan invalidate
   `authStatusProvider`.

`pendingAction` (`email` / `google` / `facebook`): selama request
jalan, form + tombol lain **disabled**; spinner / "Memproses..."
**hanya** di tombol aksi yang diklik (pola BusyAwareIcon).

## Mapping error

| Kode | UI |
| ---- | -- |
| `INVALID_GOOGLE_TOKEN` 401 | pesan generik backend |
| `RATE_LIMITED` 429 | toast + Retry-After bila ada di message |
| `GOOGLE_AUTH_UNAVAILABLE` 503 | sembunyikan tombol |
| `GOOGLE_ALREADY_LINKED` 409 | "Akun Google ini sudah terhubung ke pengguna lain." |
| `LAST_AUTH_METHOD` 409 | "Setel password dulu sebelum melepas Google." |
| `GOOGLE_NOT_LINKED` 404 | "Akun Google belum terhubung." |
| Jaringan | `_mapDioError` yang sudah ada |

## Taut / lepas di Profil (2026-09-24)

Setelah login password:

1. `GET /auth/providers` - status Google.
2. Hubungkan: SDK → `POST /auth/google/link` `{ id_token }`.
3. Lepas: `DELETE /auth/google/link` (tolak jika OAuth-only tanpa password).

Setelah terhubung, login boleh email/password **atau** Google.

## Env

```dart
@EnviedField(varName: 'GOOGLE_WEB_CLIENT_ID_STAGING', optional: true)
static const String? googleWebClientIdStaging = _Env.googleWebClientIdStaging;

@EnviedField(varName: 'GOOGLE_WEB_CLIENT_ID_PRODUCTION', optional: true)
static const String? googleWebClientIdProduction =
    _Env.googleWebClientIdProduction;
```

Getter `Env.googleWebClientId` memilih nilai sesuai flavor. Staging
harus **sama** dengan `GOOGLE_CLIENT_ID` API staging; production sama
dengan API production. Kosong / whitespace → tombol tidak ada.

Setelah ubah DTO/datasource/env/riverpod:

```bash
cd mobile && dart run build_runner build --delete-conflicting-outputs
```

## Native (konsol Google)

Bukan blocker tulis kode; wajib sebelum uji perangkat:

- OAuth 2.0 Client ID jenis **Web** → env API + Flutter (`serverClientId`).
  Staging dan production berada di project GCP yang sama (nomor
  `497143924506`). Firebase (`sambasku-staging` / `sambasku-production`)
  project lain; `oauth_client` kosong di `google-services.json` tidak
  dipakai `google_sign_in` 7 selama `serverClientId` terisi.
- Android: client OAuth **Android** di project Web client itu, satu
  client per pasangan package + sertifikat. Credential Manager
  mencocokkan package APK yang terpasang dan sertifikat yang
  menandatanganinya. Tanpa pasangan itu ia mengembalikan `canceled`
  sebelum API dipanggil.
  - Staging GitHub / `flutter run --flavor staging`: package
    `com.iamutaki.sambasku.staging` + SHA-1 **upload keystore** (dan
    SHA-1 debug bila ada yang masih memakai `~/.android/debug.keystore`).
  - `flutter run --flavor production` dengan `android/key.properties`:
    package `com.iamutaki.sambasku` + SHA-1 upload keystore yang sama.
    Sukses di sini tidak membuktikan build Play Store.
  - Play Store (track internal maupun production): package
    `com.iamutaki.sambasku` + SHA-1 **deployment certificate**
    (`deployment_cert.der` dari Download certificates). Bukan SHA
    upload key dan bukan SHA hybrid classical. Client Android
    `…45iu8sq9…` saat ini hanya memuat SHA hybrid classical
    `A1:2A:E5:99:…`. APK yang diunduh Play ditandatangani deployment
    cert `C2:9B:E2:5F:…`. Satu client Android hanya satu SHA, jadi
    tambah client baru; jangan timpa yang lama. Upload key
    `0E:27:BE:FF:…` juga perlu client sendiri supaya build non-debug
    lokal tetap jalan. Perubahan konsol cukup; AAB yang sudah
    terpasang tidak perlu diunggah ulang.
- iOS: `GIDClientID` + URL scheme reversed iOS client ID di `Info.plist`.
  Jangan timpa scheme `sambasku` (reset password).

## File

```
features/auth/
  domain/ports/google_sign_in_port.dart
  domain/usecases/login_with_google_use_case.dart
  data/google_sign_in_adapter.dart
  data/models/google_login_request_dto.dart
  presentation/widgets/google_auth_button.dart
```

Tes: `test/features/auth/login_with_google_use_case_test.dart`
(batal SDK tidak panggil repo), `google_auth_pages_test.dart`
(tombol login/daftar + 409 FAlert), fixture
`test/fixtures/json/auth/login-google.200.mobile.json`.
