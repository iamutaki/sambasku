# API - Notification Campaign (admin)

Broadcast push FCM + inbox in-app ke semua device aktif (FCM topic) atau
pengguna terpilih. Hanya role `admin` / `root`.

Lihat juga: `17-api-device-push.md` (token), `23-api-notifications.md` (inbox).

## Konsep

| Entitas | Keterangan |
|---------|------------|
| Template | Salinan reusable (title/body/image/deep link) |
| Campaign | Snapshot copy + audience + status pengiriman |
| Recipient | Baris per user (hanya audience `selected`) |

Audience `all` = user dengan **device token aktif**, dikirim via FCM topic
`sambasku_campaigns` (1 request) + tulis inbox chunked. Audience `selected`
= fan-out per user (inbox + FCM token).

Status: `draft` → `scheduled` | `sending` → `completed` | `failed` |
`cancelled`.

Cron Workers `* * * * *` memanggil `runDueNotificationCampaigns` untuk
jadwal due + lanjut chunk.

## Templates

Prefix: `/api/v1/admin/notification-templates`

| Method | Path | Keterangan |
|--------|------|------------|
| GET | `/` | List cursor |
| POST | `/` | Buat |
| GET | `/:id` | Detail |
| PATCH | `/:id` | Ubah |
| DELETE | `/:id` | Soft-delete |

Body create:

```json
{
  "name": "Update kamus",
  "title": "Kata baru minggu ini",
  "body": "Cek entri Sambas terbaru di SambasKu.",
  "image_url": null,
  "deep_link_kind": "none",
  "deep_link_value": null
}
```

`image_url`: opsional, HTTPS URL publik (upload via `POST /api/v1/images?purpose=campaign`
atau tempel URL). Snapshot ke campaign saat draft.

`deep_link_kind`: `none` | `word` | `contribution` | `suggestion` | `url`.

## Campaigns

Prefix: `/api/v1/admin/notification-campaigns`

| Method | Path | Keterangan |
|--------|------|------------|
| GET | `/` | List (`status` opsional) |
| POST | `/` | Buat draft |
| POST | `/estimate` | Estimasi user/device |
| GET | `/:id` | Detail + stats + sample failures |
| POST | `/:id/send` | Kirim sekarang / jadwalkan jika `send_at` masa depan |
| POST | `/:id/cancel` | Batalkan draft/scheduled |
| POST | `/:id/retry` | Ulangi penerima gagal (selected saja) |

Body create (selected):

```json
{
  "template_id": "01H…",
  "audience_type": "selected",
  "user_ids": ["01H…", "01H…"],
  "send_at": null
}
```

Body create (all):

```json
{
  "title": "Pengumuman",
  "body": "Isi…",
  "image_url": "https://cdn.jsdelivr.net/gh/sambasku/images@main/assets/campaigns/01H….webp",
  "audience_type": "all",
  "deep_link_kind": "none"
}
```

Alur: buat draft → buka detail → **Kirim sekarang** (confirm).
Jika `send_at` di masa depan saat send → status `scheduled`.

## Payload FCM campaign

```json
{
  "type": "campaign",
  "campaign_id": "01H…",
  "target_kind": "campaign",
  "target_id": "01H…",
  "image_url": "https://cdn.jsdelivr.net/gh/…/x.webp",
  "deep_link_kind": "word",
  "deep_link_value": "01H…"
}
```

FCM juga mengisi `notification.image` + `android.notification.image` bila
`image_url` ada (tray Android). Inbox type/target: `campaign` / `campaign` /
`campaign_id` (+ `image_url` bila ada).
## Audit

Aksi `create`/`update`/`delete` template; `send`/`schedule`/`cancel` campaign
pada `entity_type` `notification_template` | `notification_campaign`.
