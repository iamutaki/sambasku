# Admin UI Laporan Masalah

Mengikuti `admin-base-stack.md`. Kontrak API:
[`../api/30-api-bug-reports.md`](../api/30-api-bug-reports.md).

Antrean baca-satu-arah: admin/root membaca laporan, lalu menandai
selesai atau ditolak. Tidak ada assignee, prioritas, atau balasan
ke pelapor di V1.

---

## Menu dan akses

- Route `/bug-reports`.
- Sider: item **Laporan Masalah** sejajar **Audit Log** (bukan di
  grup Kamus). Hanya `admin` dan `root` (`canManageUsers`).
- Reviewer/editor/contributor tidak melihat menu. API 403.

---

## Halaman list

Header: "Laporan Masalah", tombol muat ulang.

Tabs: Terbuka | Selesai | Ditolak | Semua. Default Terbuka.

Tabel:

| Kolom | Keterangan |
| --- | --- |
| Keterangan | Plain text (bukan HTML), dipotong |
| Status | Chip open/resolved/rejected |
| Pelapor | Username atau "Anonim"; username pakai `UserInfoLink` |
| Platform | `android`/`ios` + versi, atau `-` |
| Lampiran | Thumbnail `Image` antd; klik membuka overlay preview (`Image.PreviewGroup` bila lebih dari satu). Bukan tautan tab baru. Lihat **Preview gambar** di `admin-base-stack.md` |
| Waktu | `formatDateTime` |
| Aksi | Selesaikan / Tolak (hanya status `open`) |

Kolom kosong bukan error: banyak laporan tanpa gambar atau versi.

Cursor pagination (tombol muat lagi), pola `useCursorList`.

Dialog resolve: status + note opsional →
`POST /admin/bug-reports/:id/resolve`.
