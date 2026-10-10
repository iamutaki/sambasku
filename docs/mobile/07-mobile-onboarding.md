# Mobile - Onboarding first-install

Tiga slide yang hanya muncul saat instalasi pertama
(flag SharedPreferences hilang saat uninstall).

## Flag

- Key: `sambasku_onboarding_done`
- File: `lib/features/onboarding/data/onboarding_prefs.dart`
- Preload di `main.dart` sebelum `runApp` (hindari flicker redirect)

## Slide

1. Welcome: sambutan SambasKu
2. Fitur singkat: cari, usulkan, bookmark
3. Izin notifikasi: **Izinkan** atau **Nanti**

Keduanya menandai onboarding selesai lalu masuk Home.
Izin OS hanya diminta saat tap **Izinkan**.

## Permission

Cold start **tidak** memanggil `requestPermission`.
`NotificationService.init()` hanya channel + listener.
`NotificationService.requestPermissions()` dipanggil dari slide 3.

## Router

`AppRouter._redirect`: jika flag belum true → `/onboarding`.
