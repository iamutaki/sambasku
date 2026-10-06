# Mobile Laporan Masalah

Mengikuti `mobile-base-stack.md`. Kontrak API:
[`../api/30-api-bug-reports.md`](../api/30-api-bug-reports.md).
Backlog: [`../backlogs/REPORT_BUG.md`](../backlogs/REPORT_BUG.md).

Tile Profil "Laporkan Masalah" membuka form. Tamu dan login melihat
form identik. Tidak ada halaman riwayat laporan di V1.

---

## Entry

- Route `/report-bug` (di luar tab shell, seperti Ubah Password).
- Tile Profil "Laporkan Masalah" tampil untuk tamu **dan** login
  (ganti toast "segera hadir").
- Banner tamu: "Laporan kamu dikirim sebagai Anonim". Tanpa CTA login.

---

## Form

- `description`: multiline, wajib, counter 10-2000. Kirim disabled
  jika < 10 karakter atau sedang kirim.
- Lampiran: `AttachmentImagesField` (lihat `mobile-base-stack.md`
  §9.1) - maks 4, sheet Kamera/Galeri, kompresi picker
  (`maxWidth`/`imageQuality`), upload segera per file. Hapus per
  item sebelum kirim.
- Versi (`package_info_plus`) dan platform (`android`/`ios`) dikirim
  otomatis, tidak ada field UI.

---

## Upload dan submit

1. Saat pilih gambar: `GET /api/v1/bug-reports/upload-token?folder=/bug-reports`
   lalu upload langsung ke ImageKit folder `/bug-reports` (satu token
   per file). Slot menampilkan progress/error.
2. `POST /api/v1/bug-reports` dengan description + slot siap
   (`{url, provider_file_id}`) + `app_version` + `platform`. Header
   `X-Device-Id` dari interceptor.
3. Soft-fail:
   - Token 503 `IMAGE_UPLOAD_UNAVAILABLE` → bagian lampiran
     disembunyikan, tawarkan kirim teks tanpa lampiran.
   - Slot error (semua gagal) + teks ada → tawarkan kirim tanpa gambar.
   - Offline → tahan di form, jangan hapus isian.
4. Sukses → toast terima kasih + `pop` ke Profil.

---

## Modul

```
mobile/lib/features/report_bug/
├── domain/bug_report_models.dart
├── data/
│   ├── bug_report_repository.dart
│   └── report_image_upload_service.dart
└── presentation/report_bug_page.dart
```
