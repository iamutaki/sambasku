# Admin UI - WhatsApp (System > WhatsApp)

Mengikuti `admin-base-stack.md`: feature-based, React + TanStack Router +
AntD, React Query.

Fitur: test kirim WA, kelola template pesan WA, tracking quota Kapso +
log kirim. Bagian notifikasi WA pada approve/reject pengajuan verifikator
ada di [`14-admin-verifier-application.md`](14-admin-verifier-application.md).
Kontrak API: [`docs/api/40-api-admin-whatsapp.md`](../api/40-api-admin-whatsapp.md).

---

## 1. Menu dan akses

- Route: `/system/whatsapp` di
  [`system-whatsapp-page.tsx`](../../admin/src/features/wa/presentation/system-whatsapp-page.tsx).
- Sider: grup System, item "WhatsApp" **hanya** `canManageUsers`
  (admin/root), di [`console-layout.tsx`](../../admin/src/shared/layouts/console-layout.tsx).
- Reviewer/editor/contributor: halaman menampilkan peringatan akses; API
  tetap 403.

---

## 2. Tab Test

Card "Kirim pesan uji (raw isi template)":

- Input nomor HP tujuan - format internasional tanpa `+`
  (`6281234567890`), validasi regex client + server.
- Dropdown template (dari `GET /admin/wa/templates`).
- Tombol Kirim → `POST /admin/wa/test-send`.
- Sukses: toast + sisa quota (`limit_count - used_count`). Gagal: toast
  dengan `reason` dari API.
- Isi dikirim **mentah**: placeholder `{{param}}` tidak dirender - tujuan
  tes sampai tidaknya pesan, bukan bentuk final. Tetap masuk hitungan
  quota dan log.

---

## 3. Tab Template

Card "Template pesan WA" - tabel dari `GET /admin/wa/templates`:

| Kolom | Keterangan |
| --- | --- |
| Event | Label manusiawi (`verifier_application_approved` → "Verifikator disetujui") |
| Template Meta | `meta_template_name` yang harus sama dengan template approved di WABA |
| Bahasa | `meta_template_language`, default `id` |
| Parameter | Chip `{{nama}}` + tooltip deskripsi dari kolom `params` |
| Aktif | Switch - `PATCH /admin/wa/templates/:id` `{ enabled }` |
| Aksi | Edit - modal |

Modal edit:

- Chip parameter di atas form (pengingat placeholder yang boleh dipakai).
- Textarea isi pesan (`body`) - placeholder `{{param}}` mengikuti chip.
- Field `meta_template_name` + `meta_template_language`.
- Placeholder di body yang tidak terdaftar di `params` ditolak API
  (400 `VALIDATION_ERROR`) - mencegah typo parameter.

---

## 4. Tab Quota & Log

### Card Quota provider

- `GET /admin/wa/usage`.
- Progress bar `used_count/limit_count` + persen.
- Warna/label: hijau "Aman" (< threshold), oranye "Mendekati limit"
  (>= `warn_threshold_percent`, default 80), merah "Quota habis"
  (>= `limit_count`).
- Catatan periode: reset otomatis tiap tanggal 1 00:00:01 WIB (cron +
  lazy reset); `period_start` ditampilkan.

### Card Koreksi manual

Form inline (`PATCH /admin/wa/usage`):

- Terpakai (`used_count`), Limit (`limit_count`), Ambang warna (%).
- Kolom kosong = tidak diubah (API menerima partial body).
- Dipakai untuk sinkron pemakaian yang naik langsung dari dashboard
  Kapso - kirim itu tidak lewat API SambasKu. Perubahan tercatat di
  audit log.

### Card Log kirim terakhir

`GET /admin/wa/logs?limit=20` - tabel: Waktu (`formatDateTime`), Event
(label manusiawi), Tujuan, Channel (`template`/`text`), Status badge
(Terkirim/Gagal), Error. `next_cursor` ditampilkan sebagai teks untuk
pemuatan lanjutan (ponytail: tombol "muat lagi" menyusul kalau log
sudah panjang).

---

## 5. Konfigurasi terkait (bukan halaman ini)

- Flag global `wa.verifier_enabled` + CTA `wa.group_cta_url`:
  app settings via halaman Legal (pola `useLegalSettings`), lihat
  `docs/api/40-api-admin-whatsapp.md` Section 1.
- Env `KAPSO_API_KEY` / `KAPSO_BASE_URL` / `KAPSO_PHONE_NUMBER_ID`:
  wrangler secrets/vars, bukan UI. Kosong = kirim no-op, halaman tetap
  bisa membuka template/usage/log.
