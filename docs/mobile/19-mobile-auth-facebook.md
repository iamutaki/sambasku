# Mobile - Masuk dengan Facebook

Status **V1 implemented**. Kontrak API:
[`29-api-auth-facebook.md`](../api/29-api-auth-facebook.md). Sumber produk:
[`AUTH_FACEBOOK.md`](../backlogs/AUTH_FACEBOOK.md). Admin tidak diubah.

Extend `lib/features/auth/` (bukan fitur baru). Satu use case untuk
**login dan daftar**. Tombol di bawah Google jika keduanya aktif.

## Layar

**Login** (`login_page.dart`): setelah tombol Masuk, pemisah "atau",
tombol Google (jika aktif), lalu **Masuk dengan Facebook**.

**Daftar** (`register_page.dart`): setelah tombol Daftar, pemisah
"atau", **Daftar dengan Facebook** (ajakan eksplisit). Tap Facebook di
sini **langsung sesi** ke `/` - jangan panggil `RegisterUseCase`,
jangan halaman OTP.

Widget: `FacebookAuthButton`. Pemisah reuse `GoogleAuthDivider`.

Tombol **hanya** dirender jika App ID flavor aktif terisi
(`facebookAuthEnabledProvider`) dan belum 503
(`facebookUnavailable` di state).

## Alur

1. Tap → `FacebookSignInPort.authenticate()` (`flutter_facebook_auth`:
   `login(permissions: email, public_profile,
   loginTracking: enabled)` supaya dapat access token Graph klasik,
   bukan Limited Login OIDC).
2. User batal / dismiss sheet → diam (bukan `AuthFailure`, bukan snackbar).
3. Access token kosong → "Tidak bisa masuk dengan Facebook."
4. `POST /api/v1/auth/facebook` `{ access_token, client_type: mobile }`.
5. Sukses: `_persistSession` (wajib `refresh_token`) +
   `AuthStatusNotifier.markLoggedIn` + `go('/')`. Jangan invalidate
   `authStatusProvider`.

`isSubmitting` bersama: selama Facebook berjalan, form email/password
dan tombol Google disabled.

## Mapping error

| Kode | UI |
| ---- | -- |
| `INVALID_FACEBOOK_TOKEN` 401 | pesan generik backend |
| `RATE_LIMITED` 429 | toast + Retry-After bila ada di message |
| `FACEBOOK_AUTH_UNAVAILABLE` 503 | sembunyikan tombol |
| Jaringan | `_mapDioError` yang sudah ada |

## Env

```dart
@EnviedField(varName: 'FACEBOOK_APP_ID_STAGING', optional: true)
static const String? facebookAppIdStaging = _Env.facebookAppIdStaging;

@EnviedField(varName: 'FACEBOOK_APP_ID_PRODUCTION', optional: true)
static const String? facebookAppIdProduction = _Env.facebookAppIdProduction;
```

Getter `Env.facebookAppId` memilih nilai sesuai flavor. Staging harus
**sama** dengan `FACEBOOK_APP_ID` API staging; production sama dengan
API production. Kosong / whitespace → tombol tidak ada. App Secret
**tidak** masuk app.

Setelah ubah DTO/datasource/env/riverpod:

```bash
cd mobile && dart run build_runner build --delete-conflicting-outputs
```

## Native (konsol Meta)

Bukan blocker tulis kode; wajib sebelum uji perangkat. Placeholder `0`
di `strings.xml` / `Info.plist` mencegah SDK crash; ganti dengan App ID
+ Client Token sungguhan:

- Aplikasi Facebook (development + live, atau app terpisah per env)
- Android: `facebook_app_id`, `facebook_client_token`,
  `fb_login_protocol_scheme` di `strings.xml`; meta-data di
  `AndroidManifest.xml`; package/key hash SHA-1 di Meta Console
- iOS: `FacebookAppID`, `FacebookClientToken`, URL scheme `fb{APP_ID}`
  (array terpisah). Jangan timpa scheme `sambasku` (reset password)
  atau scheme Google.
- Permission `email` + `public_profile`. Produksi: App Review Meta.

## File

```
features/auth/
  domain/ports/facebook_sign_in_port.dart
  domain/usecases/login_with_facebook_use_case.dart
  data/facebook_sign_in_adapter.dart
  data/models/facebook_login_request_dto.dart
  presentation/widgets/facebook_auth_button.dart
```

Tes: `test/features/auth/login_with_facebook_use_case_test.dart`
(batal SDK tidak panggil repo), `facebook_auth_pages_test.dart`
(tombol login/daftar + 409 FAlert), fixture
`test/fixtures/json/auth/login-facebook.200.mobile.json`.
