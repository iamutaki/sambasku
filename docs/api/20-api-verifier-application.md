# API Pengajuan Jadi Verifikator (Reviewer)

Mengikuti `api-base-stack.md`: Section 3 (struktur folder), 9
(`@hono/zod-openapi` + Scalar), 10 (testing), 11 (versioning `/api/v1/`),
13 (envelope & error), 15 (rate limiting), 19 (ULID), 21 (audit).

Contributor mengajukan jadi reviewer dari aplikasi mobile. Admin/root
menyetujui atau menolak. Approve: `users.role = reviewer` + inbox +
push FCM (+ email selamat). Reject: user memperbaiki dengan catatan
admin; inbox + FCM. Tanpa selfie/avatar.

---

## Keputusan produk

- 1 user = 1 baris (`UNIQUE user_id`). Reject bukan baris baru: PATCH
  menimpa data, status kembali `pending`.
- POST/PATCH hanya `contributor`. GET me semua role yang login.
- Review hanya `admin` dan `root` (bukan reviewer).
- HP wajib, normalisasi sama register (`normalizePhone`: digit
  internasional tanpa `+`, contoh `62812…` / `6012…`; nasional ID
  `08…`/`8…` tetap diterima). Submit menulis ulang `users.phone`.
  Unique: 409 `PHONE_ALREADY_EXISTS`. OTP tidak di v1.
- Alamat wajib: satu field teks bebas, trim, min 10, max 500.
- Sosial min 1, max 5: `{ platform, username, screenshot }`. Platform:
  `instagram | facebook | tiktok | youtube | x | website`. Username:
  nama atau handle (buang `@` di depan), trim, min 2, max 80.
  Screenshot wajib: `{ url, provider_file_id }` hasil direct-upload
  (folder `/verifier-applications`). Tidak ada field URL profil.
  `website`: username = nama situs/akun.
- Tanpa selfie, tanpa `users.avatar_url`.
- Phone, address, social_links **tidak** pernah di response profil
  publik (`19-api-profil-publik.md`).
- Approve atomik di satu transaksi: `SELECT … FOR UPDATE` pengajuan
  lalu user. Bukan `pending` → 409 `APPLICATION_ALREADY_REVIEWED`.
  Role pemohon bukan `contributor` → 403 `ALREADY_VERIFIER`
  ("Pemohon bukan lagi kontributor") tanpa mengubah baris (hindari
  menurunkan editor/admin). Sukses: status `approved` +
  `users.role = reviewer` dalam tx yang sama. Di luar tx: revoke
  refresh token, audit, inbox (`verifier_application_approved`), FCM
  (payload `data` menyertakan `title`/`body`). JWT lama tetap
  `contributor` sampai login ulang.
- POST/PATCH menulis pengajuan + `users.phone` dalam satu transaksi.
  Unique Postgres `23505`: `user_id` → 409 `APPLICATION_ALREADY_EXISTS`;
  `users.phone` → 409 `PHONE_ALREADY_EXISTS` (bukan 500; baris tidak
  tertinggal `pending` tanpa HP).
- Reject: `comment` wajib. CAS `WHERE status = pending`. Role tidak
  berubah. Inbox (`verifier_application_rejected`) + FCM; body
  menyertakan cuplikan `comment`.

---

## Prompt

```text
Buatkan modul pengajuan jadi reviewer, mengikuti pola modul 4 lapis
(Section 3). Migration tabel baru verifier_applications.

LOKASI MODUL BARU: modules/verifier-application/

STRUKTUR:
modules/verifier-application/
├── domain/
│   ├── entities/verifier-application.entity.ts
│   └── repositories/verifier-application.repository.ts
├── application/use-cases/
│   ├── create-verifier-application.use-case.ts
│   ├── get-my-verifier-application.use-case.ts
│   ├── resubmit-verifier-application.use-case.ts
│   ├── list-verifier-applications.use-case.ts
│   ├── get-verifier-application-detail.use-case.ts
│   ├── approve-verifier-application.use-case.ts
│   └── reject-verifier-application.use-case.ts
├── infrastructure/verifier-application.repository.impl.ts
└── presentation/v1/
    ├── verifier-application.controller.ts
    ├── verifier-application.routes.ts
    ├── admin-verifier-application.routes.ts
    └── validators/verifier-application.validator.ts

TABEL verifier_applications:
- id ULID PK
- user_id varchar(26) UNIQUE FK users
- phone varchar(20) NOT NULL
- address text NOT NULL
- social_links jsonb NOT NULL (array {platform, username, screenshot{url, provider_file_id}})
- status varchar: pending | approved | rejected default pending
- admin_comment text nullable
- reviewed_by varchar(26) FK users nullable
- reviewed_at timestamp nullable
- created_at, updated_at

Tidak ada kolom baru di users.

ENDPOINT USER (authenticate):
POST   /api/v1/verifier-applications          30/menit per user
GET    /api/v1/verifier-applications/me
PATCH  /api/v1/verifier-applications/me       30/menit per user

Body POST/PATCH:
{
  "phone": "81234567890",
  "address": "Jl. ...",
  "social_links": [{
    "platform": "instagram",
    "username": "budi",
    "screenshot": {
      "url": "https://ik.imagekit.io/test/verifier-applications/budi.jpg",
      "provider_file_id": "file_va_budi"
    }
  }]
}

phone: wajib, normalizePhone (sama register). Digit internasional
  tanpa '+' (62812… / 6012…) atau nasional ID. Kosong/invalid = 400.
address: trim, min 10, max 500.
social_links: min 1 max 5. platform enum. username trim min 2 max 80
  (buang @ depan). screenshot.url URL valid, provider_file_id wajib.

POST 409 APPLICATION_ALREADY_EXISTS jika sudah ada baris.
POST 403 ALREADY_VERIFIER jika role bukan contributor.
GET me 404 VERIFIER_APPLICATION_NOT_FOUND jika belum apply.
PATCH hanya jika status rejected; selain itu 409
VERIFIER_APPLICATION_NOT_REJECTED. PATCH: status -> pending,
kosongkan reviewed_by/reviewed_at/admin_comment.

ENDPOINT ADMIN (authenticate + authorizeRole admin, root; 500/menit):
GET  /api/v1/admin/verifier-applications?status=&limit=&cursor=
GET  /api/v1/admin/verifier-applications/:id
POST /api/v1/admin/verifier-applications/:id/approve
POST /api/v1/admin/verifier-applications/:id/reject  body { comment } wajib

Approve: satu tx FOR UPDATE (pending + role contributor) lalu
  role reviewer + status approved. Di luar tx: revoke refresh, audit,
  inbox + FCM judul "Selamat, Anda jadi verifikator"
  body "Pengajuan Anda disetujui. Silakan keluar lalu masuk kembali agar peran Verifikator aktif di aplikasi."
  Pemohon bukan contributor -> 403 ALREADY_VERIFIER.
Reject: comment wajib, CAS pending, inbox + FCM
  judul "Pengajuan verifikator ditolak"
  body "Pengajuan ditolak: {cuplikan comment}" (fallback tanpa comment
  kosong: "Pengajuan ditolak. Buka profil untuk memperbaiki.").
Non-pending -> 409 APPLICATION_ALREADY_REVIEWED.

ERROR_CODES.md:
VERIFIER_APPLICATION_NOT_FOUND 404
VERIFIER_APPLICATION_NOT_REJECTED 409
ALREADY_VERIFIER 403
APPLICATION_ALREADY_EXISTS 409
APPLICATION_ALREADY_REVIEWED 409

Fixture: docs/json/verifier-applications/
Bruno: http/verifier-applications/

TES:
- Unit: create bukan contributor -> 403; resubmit hanya rejected;
  reject tanpa comment -> 400 (validator); approve atomik + notify;
  approve bukan contributor -> 403; approve setelah reject -> 409;
  unique phone (repo 23505) -> 409
- E2E: apply -> list admin -> reject -> PATCH -> approve -> role reviewer
```

---

## Response user (`data`)

```json
{
  "id": "01JDVA00000000000000000000",
  "status": "pending",
  "phone": "6281234567890",
  "address": "Jl. Merdeka No. 1, Sambas",
  "social_links": [
    {
      "platform": "instagram",
      "username": "budi",
      "screenshot": {
        "url": "https://ik.imagekit.io/test/verifier-applications/budi.jpg",
        "provider_file_id": "file_va_budi"
      }
    }
  ],
  "admin_comment": null,
  "reviewed_at": null,
  "created_at": "2026-09-21T00:00:00.000Z",
  "updated_at": "2026-09-21T00:00:00.000Z"
}
```

Envelope: `{ success: true, data }`. List admin: `data[]` + `meta`
`{ limit, next_cursor, has_more }`.

Item list admin menambah `user_id`, `username`. Detail admin sama
plus field lengkap di atas + `reviewed_by` + `reviewed_by_username`
(JOIN `users` pada `reviewed_by`; null jika belum direview atau akun
reviewer hilang). UI admin **tidak menampilkan** `user_id` /
`reviewed_by`; identitas di layar = username (modal profil publik).

Approve `data`: `{ id, status: "approved", role: "reviewer" }`.
Reject `data`: `{ id, status: "rejected" }`.

---

## Notifikasi WhatsApp (Kapso)

Selain inbox + FCM + email, keputusan approve/reject mengirim pesan
WhatsApp ke `verifier_applications.phone` pemohon. Kontrak lengkap:
[`40-api-admin-whatsapp.md`](40-api-admin-whatsapp.md).

- Hanya jalan bila `wa.verifier_enabled=true` (app settings), template
  per event `enabled`, dan pemohon punya `phone`. Gagal kirim hanya
  di-log (`wa_message_logs`) - tidak mengubah respons approve/reject.
- Channel `template` (Meta-approved, business-initiated).
- Approve → event `verifier_application_approved`, params:
  `displayName`, `benefits` (daftar manfaat verifikator), `ctaUrl`
  (link grup WA diskusi + silaturahmi).
- Reject → event `verifier_application_rejected`, params:
  `displayName`, `reasonRejected` (`admin_comment` penuh, bukan
  cuplikan 180 char seperti body FCM), `ctaUrl`.
- Kuota per provider dicek sebelum kirim; habis → log `failed`,
  keputusan tetap tersimpan. Koreksi manual quota admin lewat
  `PATCH /api/v1/admin/wa/usage`.
