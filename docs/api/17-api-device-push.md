# API - Device tokens & push FCM

Pendaftaran FCM token per perangkat (multi-device) dan kirim push
saat kontribusi disetujui admin.

## Endpoints

| Method | Path | Auth | Keterangan |
|--------|------|------|------------|
| POST | `/api/v1/device/register` | login | Upsert `{ udid, fcm_token }` |
| PATCH | `/api/v1/device/revoke` | login | Soft-delete device ini |

Login body **tidak** membawa FCM - client register setelah auth.

## Multi-device & rotasi

- Satu baris = satu `udid` (unique).
- Satu `user_id` boleh banyak baris aktif.
- Rotasi FCM: register ulang dengan `udid` sama + token baru.
- Unique partial aktif pada `fcm_token` - token yang sama di udid lain
  di-soft-delete dulu agar tidak double-push.

## Logout

- Logout app: `PATCH /revoke` lalu clear sesi lokal.
- `POST /api/v1/auth/logout-all` (atau endpoint logout-all yang ada):
  revoke **semua** refresh token **dan** soft-delete semua `device_tokens`
  aktif user.

## Push saat approve kontribusi

Setelah `POST /api/v1/admin/contributions/:id/approve` sukses:

- API fan-out FCM ke semua token aktif `contributorUserId`
- Title: `Kontribusi disetujui`
- Data: `type=contribution_approved`, `contribution_id`, `entity_type`, `entity_id`
- Best-effort (gagal push tidak gagalkan approve)
- Tanpa `FIREBASE_PROJECT_ID` + `FIREBASE_CLIENT_EMAIL` +
  `FIREBASE_PRIVATE_KEY` → push di-skip (no-op)

Admin FE tidak perlu diubah - tetap memanggil endpoint approve yang sama.

Inbox in-app (bukan push): `23-api-notifications.md`. Baris inbox
ditulis juga saat reject/correct. Push FCM tetap hanya approve dulu.

## Env

Lihat `api/.env.example` (`FIREBASE_*`).
