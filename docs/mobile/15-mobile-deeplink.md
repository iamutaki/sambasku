# Deep link: Custom scheme + Universal / App Links

Dokumen QA dan kontrak path untuk membuka SambasKu dari tautan luar
(chat, email, browser, share caption).

## URL yang didukung

| HTTPS (Universal / App Link) | Custom scheme | Target di app |
| --- | --- | --- |
| `https://sambasku.com/words/{lemma}` | `sambasku://app/words/{lemma\|id}` | Detail kata |
| `https://sambasku.com/words/{ulid}` | sama | Detail kata (lalu dinormalisasi ke id) |
| `https://sambasku.com/reset-password?token=&email=` | `sambasku://app/reset-password?...` | Reset password |
| `https://sambasku.com/hapus-akun` | `sambasku://app/hapus-akun` | `/delete-account` |
| `https://sambasku.com/users/{username}` | `sambasku://app/users/{username}` | Profil publik |

Staging web: `https://sambasku-web-staging.iamutaki.com` (flavor staging).
Production web: `https://sambasku.com` (flavor production).

## Verifikasi domain

File di web Worker (`web/public/.well-known/`), live di **kedua** host:

- Prod: `https://sambasku.com/.well-known/assetlinks.json`
- Staging: `https://sambasku-web-staging.iamutaki.com/.well-known/assetlinks.json`
- (iOS AASA ditunda) `apple-app-site-association` di host yang sama nanti

Cek cepat:

```bash
curl -s https://sambasku.com/.well-known/assetlinks.json
curl -s https://sambasku-web-staging.iamutaki.com/.well-known/assetlinks.json
```

`Content-Type` harus `application/json`. Jangan redirect 301/302. App Links
hanya verifikasi lewat **HTTPS** (bukan `http://`).

### Android SHA-256 (multi-flavor)

Dua package di `assetlinks.json` (lihat
[`docs/env/android_app_links.md`](../env/android_app_links.md)):

- `com.iamutaki.sambasku` (production)
- `com.iamutaki.sambasku.staging` (staging)

Placeholder `TODO_*` harus diganti sebelum deploy production. Verifikasi:

```bash
adb shell pm get-app-links com.iamutaki.sambasku
adb shell pm get-app-links com.iamutaki.sambasku.staging
```

### iOS Associated Domains (ditunda)

Fokus V1 Android. Entitlements sudah ada di repo; aktifkan QA iOS
menyusul.
## Uji manual

### Android (adb)

```bash
# Custom scheme
adb shell am start -a android.intent.action.VIEW \
  -d "sambasku://app/words/makatn"

# App Link
adb shell am start -a android.intent.action.VIEW \
  -d "https://sambasku.com/words/makatn"

adb shell am start -a android.intent.action.VIEW \
  -d "https://sambasku.com/reset-password?token=TEST&email=a@b.c"

adb shell am start -a android.intent.action.VIEW \
  -d "https://sambasku.com/users/budi"
```

### iOS

1. Tempel URL HTTPS di Notes / Messages, long-press → Open in SambasKu.
2. Atau Safari: ketik URL, pastikan banner "Open in app" muncul setelah
   Associated Domains terverifikasi (bisa butuh reinstall app).

### Email auth

API memakai `WEB_APP_URL` (prod: `https://sambasku.com`) untuk link
reset password dan hapus akun. Bukan host API (`APP_URL`).

### Share caption

Kartu share menyertakan `https://sambasku.com/words/{lemma}` dari
`SAMBASKU_WEB_APP_URL_*` di env mobile.

### Notifikasi

Tap FCM / banner AwesomeNotifications memakai `target_kind` +
`target_id` (fallback `contribution_id`) untuk navigasi.

## File terkait

- Android: `mobile/android/app/src/main/AndroidManifest.xml`
- iOS: `mobile/ios/Runner/Runner.entitlements`, `Info.plist`
- Router: `mobile/lib/core/router/app_router.dart`
- Lemma resolve: `wordDetailProvider` + `GET /api/v1/words/lemma/:lemma`
- Web verification: `web/public/.well-known/`
