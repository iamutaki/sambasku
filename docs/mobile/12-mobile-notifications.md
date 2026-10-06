# Mobile - Inbox Notifikasi Status Usulan

Mengikuti `mobile-base-stack.md`: Section 2 (3 lapis per fitur), 5 (pola
fitur lengkap), 6 (networking envelope + cursor pagination), 10
(testing), 11 (mapping error_code). Kontrak API:
`23-api-notifications.md`. Push FCM tetap di `06-mobile-push-fcm.md`.

Tile Profil "Notifikasi" + lonceng di header Profil membuka daftar inbox
milik user login. Tap item menandai dibaca lalu membuka detail Kontribusi
Saya. Bukan pengganti push.

Selesai diimplementasikan: fitur `features/notification/`, route
`/notifications`, badge unread di header dan tile Profil.

---

## Struktur

```text
lib/features/notification/
├── domain/
│   ├── entities/inbox_notification.dart
│   ├── entities/inbox_notification_page.dart
│   ├── failures/notification_failure.dart
│   ├── repositories/notification_repository.dart
│   ├── providers/notification_domain_providers.dart
│   └── usecases/notification_use_cases.dart
├── data/
│   ├── repositories/notification_repository_impl.dart
│   └── providers/notification_data_providers.dart
├── presentation/
│   ├── models/notification_inbox_state.dart
│   ├── providers/notification_providers.dart
│   └── pages/notification_inbox_page.dart
└── notification_router.dart
```

Data layer pakai Dio langsung (tanpa retrofit/freezed) karena payload
ringkas, preseden `my_contributions`.

## Perilaku

1. `NotificationInboxListController` dan
   `UnreadNotificationCountController` (keepAlive): guest = kosong / 0.
   Login = halaman pertama limit 20. Invalidate di login/logout.
2. List: `FTileGroup`. Judul = title API. Subtitle = label status ·
   tanggal · body. Belum dibaca ditandai dot merah di prefix; judul
   belum dibaca lebih tegas, yang sudah dibaca lebih redup. Ikon lonceng
   sama di kiri. Bila ada gambar, thumbnail 40px di kanan, sebelum chevron.
   Pull-to-refresh, skeleton, kosong "Belum ada notifikasi", error + coba lagi.
3. Tap: optimistic mark-read lokal + navigasi segera; `POST .../:id/read`
   di latar (jangan tunggu jaringan sebelum buka target). `campaign`
   membuka `/notifications/:id` (judul, tanggal, body, gambar bila ada).
   Tombol Buka di footer menjalankan CTA. Selain itu, helper yang sama
   dengan FCM (`notification_navigation.dart`):
   - `action_kind` / `action_value` diutamakan (dari API)
   - `word` (termasuk `word_comment` / `word_vote`) → `/words/:id?focus=activity`
   - `discussion` → detail diskusi
   - `url` → browser eksternal (`url_launcher`, hanya `https://`)
   - selain itu → `/contributions/:kind/:id`
4. Ownership 404 `NOTIFICATION_NOT_FOUND` tampil pesan API.

Label type:
- `word_comment` → **Komentar**
- `word_vote` → **Vote**
- `campaign` → **Pengumuman**

## Testing

- Mapper DTO + label type + `isNotFound` di
  `test/features/notification/`
- `flutter analyze` bersih
