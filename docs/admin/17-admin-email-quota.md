# Admin UI Email Quota & Log Email

Mengikuti `admin-base-stack.md`. Kontrak API:
[`../api/40-api-email-quota-log.md`](../api/40-api-email-quota-log.md).

Halaman System > Email Quota: pantau sisa kuota email per-provider, ubah
limit + usage manual, dan tinjau log status kirim (tanpa isi email,
mengacu issue sambasku/console#16).

Status: **rencana disetujui, belum diimplement**. Doc ini acuan review dan
spec implementasi.

Latar belakang: Resend gratis 3.000 email/bulan (limit harian 100). Saat
campaign, kuota bisa habis. API otomatis failover ke provider berikutnya
(Brevo) berdasarkan priority; halaman ini tempat admin mengawalinya.

---

## Menu dan akses

- Route `/system/email`.
- Sider: item **Email Quota** di grup System, sejajar Database, Supabase,
  Abuse (`SYSTEM_ROUTES` di `console/src/shared/layouts/console-layout.tsx`).
- Hanya `admin` dan `root`.

---

## Struktur halaman

### 1. Kartu kuota per provider

Satu kartu per provider (resend, brevo), urut `priority`:

| Elemen | Keterangan |
| --- | --- |
| Nama provider + badge | Aktif (hijau) / Nonaktif (abu) |
| Terpakai bulan ini | `month_used` / `monthly_limit`, progress bar |
| Sisa bulan ini | `month_remaining` |
| Terpakai hari ini | `today_used` / `daily_limit` |
| Usage manual | `manual_monthly_used` (email dari dashboard provider) |
| Priority | Angka urutan failover |

Kartu provider yang akan dipakai berikutnya saat failover diberi tag
"Failover berikutnya".

### 2. Form edit provider

Tombol Edit per kartu membuka form inline (satu kolom, `InputNumber` +
`Switch`):

- `monthly_limit`, `daily_limit` - batas kuota.
- `manual_monthly_used` - untuk req admin yang kirim email manual dari
  dashboard Resend/Brevo: naikkan angka ini supaya tracking akurat.
- `active` - matikan provider (dilewati failover).
- `priority` - urutan failover.

Simpan → `PATCH /admin/system/email/quota/:provider`, invalidate query.

### 3. Tabel log email

Di bawah kartu kuota, tab "Log Email":

| Kolom | Keterangan |
| --- | --- |
| Waktu | `formatDateTime` |
| Provider | resend / brevo |
| Kategori | OTP, Reset password, Hapus akun, Verifikator |
| Tujuan | Email penerima |
| Status | Tag: Terkirim (hijau), Gagal (merah), Lewati kuota (oranye) |
| Error | `error_code`, tooltip pesan |

Filter: status, provider. Pagination cursor ("Muat lagi").

**Sengaja tidak ada kolom isi/subject email** - kebutuhan issue #16 adalah
status, bukan konten (privasi OTP/password).

---

## Playground email test

Tab "Kirim Test" di halaman Email Quota. Form:

- Input tujuan (email penerima).
- Provider: Auto (ikut priority + failover) | daftar dari GET quota
  (sekarang hanya Resend; Brevo muncul otomatis setelah sender + seed
  ditambahkan).
- Tombol kirim → `POST /admin/system/email/test`.
- Hasil: status sukses/gagal + provider yang benar-benar terpakai +
  error code bila gagal.

Kegunaan: verifikasi kredensial provider baru sebelum diaktifkan, dan
cek isi email tanpa menunggu OTP asli. Pengiriman test tetap masuk kuota
dan log (category `test`).

---

## Copy

Indonesia santai, sapa "kamu", tanpa em/en dash (hyphen ASCII). Contoh
state kosong log: "Belum ada email terkirim. Log muncul setelah ada
pengiriman OTP, reset password, atau notifikasi lain."

Error simpan kuota: tampilkan `normalizeError` standar (Antd `message`).

---

## File (rencana)

- `console/src/features/system/email/domain/email-quota.ts`
- `console/src/features/system/email/infrastructure/email-quota-api.ts`
- `console/src/features/system/email/application/use-email-quota.ts`
- `console/src/features/system/email/presentation/system-email-page.tsx`
- Route: `console/src/app/router.tsx` (`/system/email`)
- Sidebar: `console/src/shared/layouts/console-layout.tsx`
