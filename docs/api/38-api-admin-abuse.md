# API Admin Abuse - Monitoring Ledger Abuse UGC

Sisi baca + aksi admin untuk ledger abuse yang ditulis policy otomatis:

- `ugc_abuse_events` - akun login (komentar, diskusi, kontribusi kamus).
  Policy: `api/src/shared/moderation/record-abuse-signal.use-case.ts`.
- `ugc_anon_abuse_events` + `ugc_anon_mutes` - tamu per IP / `X-Device-Id`.
  Policy: `api/src/shared/moderation/record-anon-abuse-signal.use-case.ts`
  (lihat juga `03-api-kontribusi-verifikasi.md`).

Modul: `api/src/modules/abuse/`. Semua endpoint **hanya role `admin` dan
`root`**, rate limit 500 req/menit (kategori admin). Dipakai halaman
Console `/abuse` (tab Akun & Anonim) dan drawer riwayat abuse di `/users`.

Riwayat per user tetap di `GET /api/v1/admin/users/:id/abuse-events`
(`09-api-comment.md`).

---

## Sinyal

| Sinyal | Bobot | Sumber |
|---|---|---|
| `input_rejected` | 1 | Teks ditolak cek kualitas (akun & anon) |
| `heavy_censor` | 1 | Sensor berat (akun) |
| `rate_lockout` | 2 | Kena rate limit UGC (akun & anon) |
| `comment_takedown` | 3 | Komentar di-takedown moderator (akun) |
| `contribution_spam_reject` | 3 | Kontribusi ditolak sebagai spam (akun) |
| `policy_mute` / `policy_pause` / `policy_deactivate` | 0 | Jejak aksi policy otomatis |
| `admin_lift` | negatif | Admin cabut mute (lihat di bawah) |

## Cabut mute = reset skor

Policy menghitung ulang skor rolling (24 jam, 7 hari, 30 hari) di setiap
sinyal baru. Hapus mute saja tidak cukup: satu sinyal berikutnya langsung
memicu mute lagi. Karena itu cabut mute juga mencatat event `admin_lift`
berbobot `-skor30d` sehingga ketiga jendela turun ke <= 0.

Batas yang diketahui: saat event positif lama keluar dari jendela 30 hari,
skor bisa sementara negatif (lebih longgar). Upgrade: policy hanya hitung
event setelah `admin_lift` terakhir.

Cabut mute akun **tidak** mengubah `can_contribute` / `is_active`; pakai
`PATCH /admin/contribution-access/:id` dan `PATCH /admin/users/:id/active`.

---

## Endpoint

### `GET /api/v1/admin/abuse/user-events`

Feed event akun, terbaru dulu (`id` DESC, cursor = `id` terakhir).

Query: `signal?`, `user_name?` (partial, case-insensitive), `limit` (1-100,
default 20), `cursor?`.

```json
{
  "success": true,
  "data": [
    {
      "id": "01J...",
      "user_id": "01J...",
      "username": "budi",
      "user_can_contribute": true,
      "user_muted_until": "2026-09-29T07:00:00.000Z",
      "signal": "input_rejected",
      "weight": 1,
      "entity_type": "comment",
      "entity_id": null,
      "meta": null,
      "created_at": "2026-09-29T06:00:00.000Z"
    }
  ],
  "meta": { "limit": 20, "next_cursor": null, "has_more": false }
}
```

`user_can_contribute` / `user_muted_until` = status user **saat ini**
(LEFT JOIN `users`), bukan saat event terjadi.

### `GET /api/v1/admin/abuse/anon-events`

Feed event tamu, terbaru dulu.

Query: `subject_kind?` (`ip` | `device`), `subject_key?` (exact), `signal?`,
`limit`, `cursor?`.

Item: `id`, `subject_kind`, `subject_key`, `signal`, `weight`,
`entity_type`, `entity_id`, `meta`, `created_at`.

### `GET /api/v1/admin/abuse/anon-mutes`

Mute IP/device yang masih aktif (`muted_until > sekarang`), maksimal 100
baris, urut berakhir paling lama dulu. Tanpa paging.

Item: `subject_kind`, `subject_key`, `muted_until`, `updated_at`.

### `POST /api/v1/admin/abuse/anon-mutes/lift`

Body (kunci di body karena IPv6 berisi `:`):

```json
{ "subject_kind": "ip", "subject_key": "203.0.113.9" }
```

200: `{ subject_kind, subject_key, removed, previous_score_30d }`.
`removed=false` bila memang tidak sedang di-mute (tetap reset skor).
Audit: `lift_anon_mute`, `entity_type=anon_subject`,
`entity_id=<kind>:<key>`.

400 `VALIDATION_ERROR`: `subject_kind` bukan `ip`/`device` atau
`subject_key` kosong.

### `POST /api/v1/admin/abuse/users/:id/lift-mute`

Kosongkan `contribute_muted_until` + reset skor.

200: `{ id, contribute_muted_until: null, previous_score_30d }`.
Audit: `lift_contribute_mute`, `entity_type=user`.

404 `USER_NOT_FOUND`: user tidak ada / sudah dihapus.

---

## Bruno

`http/abuse/`: `list-user-events.bru`, `list-anon-events.bru`,
`list-anon-mutes.bru`, `lift-anon-mute.bru`, `lift-user-mute.bru`.
