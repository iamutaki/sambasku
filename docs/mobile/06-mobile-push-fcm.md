# Mobile - Push FCM & device token

Mengikuti pola jnn_mobile, dengan foreground via **awesome_notifications**.

## Alur

1. Bootstrap (`main.dart`): Firebase → permission → AwesomeNotifications → getToken → `DeviceRegistrationService.start`
2. Login / cold-start auth → `POST /api/v1/device/register` `{ udid, fcm_token }`
3. `onTokenRefresh` → register ulang (udid sama)
4. Foreground FCM → AwesomeNotifications channel `sambasku_notifications`
5. Logout / session mati → `PATCH /api/v1/device/revoke` lalu clearTokens

## Event pertama: kontribusi disetujui

Saat admin approve di panel, API mengirim push ke kontributor
(`type=contribution_approved`). Mobile menampilkan notifikasi sistem /
in-app (foreground). Navigasi tap masih TODO di FCM; inbox in-app
(`12-mobile-notifications.md`) sudah membuka detail usulan.

## Env API

Set `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`
di API agar push tidak di-skip.
