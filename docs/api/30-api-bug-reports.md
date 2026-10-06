# API Laporan Masalah (Bug Report)

Mengikuti `api-base-stack.md`: Section 3 (struktur folder), 9
(`@hono/zod-openapi`), 11 (`/api/v1/`), 13 (envelope + cursor), 15
(rate limit), 19 (ULID), 21 (audit). Backlog:
[`../backlogs/REPORT_BUG.md`](../backlogs/REPORT_BUG.md).

Tamu dan user login mengirim keterangan (wajib) plus sampai 4 screenshot
opsional. Laporan masuk antrean admin/root. Tidak tampil di Usulanku.
Tidak ada notifikasi resolve di V1.

Env baru: tidak ada. Pakai `IMAGEKIT_*` yang sudah ada.

---

## Keputusan produk

1. Satu form tamu dan login. `user_id` nullable (null = anonim).
2. Keterangan wajib 10-2000 karakter. Gambar nullable, maks 4.
3. `app_version` dan `platform` otomatis dari client, bukan field UI.
4. Token upload publik `GET /api/v1/bug-reports/upload-token` terkunci
   folder `/bug-reports`. Jalur `/admin/images/upload-token` tidak
   diubah.
5. Gambar kolom JSONB `images` (`[{url, provider_file_id}]`), bukan
   tabel anak.
6. Status: `open` → `resolved` | `rejected`. Terminal. Tanpa
   assign/label/priority.
7. Antrean admin: list cursor + resolve. Role admin + root.
8. Rate limit: submit anonim 5/jam per `X-Device-Id` + 20/jam per IP;
   submit login 5/jam per `user_id`; token publik 20/jam per device +
   40/jam per IP. Header absen/invalid (panjang di luar 8-64) jatuh ke
   bucket IP saja (`06-api-x-device-id.md`).
9. Audit: submit `create`, resolve `update`, `entity_type='bug_report'`.
   `user_id` audit null saat anonim.

---

## Tabel `bug_reports`

| Kolom | Tipe | Catatan |
| --- | --- | --- |
| `id` | `varchar(26)` PK | ULID |
| `user_id` | FK users, nullable | null = anonim |
| `device_id` | `varchar(64)` nullable | dari `X-Device-Id` |
| `description` | `text` NOT NULL | 10-2000 |
| `images` | `jsonb` NOT NULL default `[]` | maks 4 `{url, provider_file_id}` |
| `app_version` | `varchar(20)` nullable | |
| `platform` | `varchar(10)` nullable | `android` / `ios` |
| `status` | `varchar(20)` default `open` | `open`, `resolved`, `rejected` |
| `resolution_note` | `text` nullable | diisi admin saat resolve |
| `resolved_by` / `resolved_at` | nullable | FK users / timestamp |
| `created_by` / `updated_by` / `deleted_at` / `deleted_by` / `created_at` / `updated_at` | | `created_by` = `user_id` saat login, null saat anonim |

Index: `(status, id)`, `user_id`, `device_id`.

---

## Endpoint

### `GET /api/v1/bug-reports/upload-token`

Publik. Query `folder` wajib bernilai `/bug-reports`. Nilai lain atau
kosong → 400 `VALIDATION_ERROR` field `folder` (`Folder upload tidak
valid`). ImageKit belum dikonfigurasi → 503 `IMAGE_UPLOAD_UNAVAILABLE`.

Response 200 sama dengan `GET /api/v1/admin/images/upload-token`
(token, signature, expire, public_key, upload_endpoint).

### `POST /api/v1/bug-reports`

Auth opsional. Body:

```json
{
  "description": "Tombol upvote tidak merespons di halaman detail kata",
  "images": [
    { "url": "https://ik.imagekit.io/.../bug-reports/x.jpg", "provider_file_id": "abc123" }
  ],
  "app_version": "0.1.0",
  "platform": "android"
}
```

| Field | Aturan | Pesan |
| --- | --- | --- |
| `description` | wajib, trim 10-2000 | `Keterangan wajib diisi minimal 10 karakter` |
| `images` | opsional, array maks 4; tiap item `url` http(s) + `provider_file_id` | `Lampiran tidak boleh lebih dari 4 gambar` / `Alamat gambar tidak valid` |
| `app_version` | opsional maks 20 | |
| `platform` | opsional `android` \| `ios` | `Platform tidak valid` |

Response 200:

```json
{
  "success": true,
  "data": {
    "id": "01JDBUGREPORT0000000000000",
    "status": "open",
    "submitted_at": "2026-09-21T12:00:00.000Z",
    "is_anonymous": true
  }
}
```

### `GET /api/v1/admin/bug-reports`

Admin + root. Query: `status` (`open`/`resolved`/`rejected`), `limit`
1-50 default 20, `cursor` ULID (terbaru dulu). Item: kolom selain
soft-delete + `username` pelapor (null = anonim).

### `POST /api/v1/admin/bug-reports/:id/resolve`

Body `{ "status": "resolved" | "rejected", "note": string opsional }`.
Id tidak ada / sudah terminal / soft-deleted → 404 `BUG_REPORT_NOT_FOUND`
(`Laporan tidak ditemukan`).

---

## Error code

| error_code | HTTP | Kapan |
| --- | --- | --- |
| `BUG_REPORT_NOT_FOUND` | 404 | resolve pada id yang tidak ada / sudah selesai |
| `VALIDATION_ERROR` | 400 | body/query tidak lolos |
| `RATE_LIMITED` | 429 | bucket penuh; `Retry-After` |
| `IMAGE_UPLOAD_UNAVAILABLE` | 503 | ImageKit belum dikonfigurasi |
| `UNAUTHORIZED` | 401 | Bearer ada tapi invalid (submit); atau admin tanpa token |
| `FORBIDDEN` | 403 | admin endpoint, role bukan admin/root |

---

## Modul

```
api/src/modules/bug-report/
├── domain/entities/bug-report.entity.ts
├── application/use-cases/
│   ├── create-bug-report.use-case.ts
│   ├── list-bug-reports.use-case.ts
│   └── resolve-bug-report.use-case.ts
├── infrastructure/bug-report.repository.impl.ts
└── presentation/v1/
    ├── bug-report.routes.ts
    ├── admin-bug-report.routes.ts
    └── validators/bug-report.validator.ts
```
