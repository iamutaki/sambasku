# Mobile - Notification Campaign

Melengkapi `06-mobile-push-fcm.md` dan `12-mobile-notifications.md`.

## Topic FCM

Setelah `POST /device/register` sukses, client subscribe topic
`sambasku_campaigns`. Saat revoke/logout → unsubscribe.

Topic dipakai API untuk audience campaign `all` (satu kiriman FCM).

## Payload

`type=campaign` (+ opsional `deep_link_kind` / `deep_link_value` /
`image_url`).

Navigasi push FCM (`notification_navigation.dart`):

- `word` → `/words/:id`
- `contribution` / `suggestion` → detail Kontribusi Saya
- selain itu → inbox notifikasi

Foreground: bila `image_url` ada → AwesomeNotifications `BigPicture`.
Background Android: FCM `notification.image` (tanpa NSE iOS di fase ini).

## Inbox

Baris type `campaign` menampilkan label **Pengumuman**. Thumbnail, bila
ada, duduk di kanan baris (bukan mengganti ikon kiri). Tap menandai
dibaca lalu membuka detail (judul,
tanggal, body, gambar bila ada). Tombol **Buka** di footer menjalankan
deeplink `action_*`. Tap push FCM tetap loncat ke target.