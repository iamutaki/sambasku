# Admin API - WhatsApp (Kapso)

Mengikuti `api-base-stack.md`. Fitur WA: notifikasi verifikator via Kapso
(proxy Meta WhatsApp Cloud API), flag + template + link CTA configurable,
tracking quota, log kirim generik, test send dari console.

Menu console: `System > WhatsApp` (admin/root) -
[`docs/admin/18-admin-whatsapp.md`](../admin/18-admin-whatsapp.md).
Hook notifikasi verifikator: Section "Notifikasi WhatsApp" di
[`20-api-verifier-application.md`](20-api-verifier-application.md).

---

## 1. Konfigurasi

Env (semua opsional, kosong = kirim no-op, endpoint admin tetap jalan):

| Env | Keterangan |
| --- | --- |
| `KAPSO_API_KEY` | API key Kapso |
| `KAPSO_BASE_URL` | Default `https://api.kapso.io/meta/whatsapp` |
| `KAPSO_PHONE_NUMBER_ID` | ID nomor WhatsApp pengirim |

App settings (console, tanpa redeploy):

| Key | Default | Keterangan |
| --- | --- | --- |
| `wa.verifier_enabled` | `false` | Flag global kirim WA verifikator |
| `wa.group_cta_url` | link grup Pojok SambasKu | CTA gabung grup WA |

    20|## 2. Tabel

- `wa_message_templates`: template per `event_key` (`enabled`, `meta_template_name`,
  `meta_template_language`, `body` dengan placeholder `{{param}}`, `params` JSON
  `[{name, description}]`; urutan params = urutan positional Meta).
  Seed: `verifier_application_approved`, `verifier_application_rejected`.
- `wa_message_logs`: log semua kirim (`provider`, `event_key`, `to_phone`,
  `channel` template/text, `status` sent/failed, `error_message`).
- `wa_usage`: quota per provider (`used_count`, `limit_count` default 2000,
  `warn_threshold_percent`, `period_start`). Reset otomatis tiap tanggal 1
  00:00:01 WIB (cron menit + lazy reset di repository).

## 3. Alur kirim

1. Admin approve/reject pengajuan verifikator.
2. Bila `wa.verifier_enabled` aktif dan template `enabled`: render param
   (`displayName`, `benefits`/`reasonRejected`, `ctaUrl`) ke positional params,
   kirim sebagai Meta template.
3. Quota dicek per provider: `used_count >= limit_count` → pindah provider
   (urutan `WA_PROVIDERS`), habis semua → log `failed`.
4. Sebelum kirim: nomor wajib format internasional (`isValidWaPhone`);
   parameter template wajib terisi dan total <= 1024 char (batas Meta) -
   pelanggaran → skip tanpa buang quota, log `failed`.
5. Sukses → `used_count` +1 (atomic SQL, aman concurrent) + log `sent`.
   Gagal kirim tidak membatalkan keputusan approve/reject.

## 4. Endpoint admin (`/api/v1/admin/wa`, bearer, admin/root)

    60|### GET /templates
List template. Response `data.templates[]`: `id`, `event_key`, `enabled`,
`meta_template_name`, `meta_template_language`, `body`, `params[]`,
`updated_at`, `updated_by`.

### PATCH /templates/:id
Body (semua opsional): `enabled`, `meta_template_name` (max 512),
`meta_template_language` (max 10), `body` (max 1024, batas Meta).
Placeholder di `body` wajib terdaftar di `params` - pelanggaran → 400
`VALIDATION_ERROR`. 404 `WA_TEMPLATE_NOT_FOUND`.

### GET /usage
Response `data.usage`: `provider`, `used_count`, `limit_count`,
`warn_threshold_percent`, `percent`, `level` (`ok` | `warn` | `exhausted`),
`period_start`, `updated_at`. 404 `WA_PROVIDER_NOT_FOUND` bila baris wa_usage
belum ada.

### PATCH /usage
Koreksi manual (kirim dari dashboard Kapso tidak lewat API ini). Body semua
opsional: `used_count` (>=0), `limit_count` (>=1), `warn_threshold_percent`
(0-100). Response sama GET. Tercatat di audit log. 404
`WA_PROVIDER_NOT_FOUND` bila baris wa_usage belum ada.

    90|### GET /logs?cursor&limit
Cursor pagination (terbaru dulu). Response `data.logs[]`: `id`, `provider`,
`event_key`, `to_phone`, `template_name`, `channel`, `status`,
`error_message`, `created_at`; `data.next_cursor`.

### POST /test-send
Body: `phone` (internasional tanpa `+`, regex server-side), `template_id`.
Kirim **raw** `body` template tanpa render parameter - tetap masuk quota +
log. Rate limit khusus 5/menit (kirim beneran, makan quota).
Response: `sent` (boolean), `reason` (null bila sukses), `usage`.
400 `VALIDATION_ERROR` nomor invalid; 404 `WA_TEMPLATE_NOT_FOUND`.

## 5. Hook verifikator

- Approve → WA `verifier_application_approved`: params `displayName`,
  `benefits` (daftar manfaat), `ctaUrl`.
- Reject → WA `verifier_application_rejected`: params `displayName`,
  `reasonRejected` (admin_comment penuh), `ctaUrl`.
- Jalur hanya jalan bila `wa.verifier_enabled=true`, pemohon punya `phone`,
  dan template aktif. Gagal kirim hanya di-log.
