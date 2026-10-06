# Admin UI - Pengajuan Verifikator

Mengikuti `admin-base-stack.md`: feature-based, React + TanStack Router +
AntD, React Query. Kontrak API: `docs/api/20-api-verifier-application.md`.

Halaman antrean + detail untuk admin/root menyetujui atau menolak
pengajuan contributor menjadi reviewer.

---

## 1. Menu dan akses

- Route:
  - `/verifier-applications` list
  - `/verifier-applications/:id` detail
- Sider: item "Pengajuan verifikator" **hanya** `canManageUsers`
  (admin/root), di [`console-layout.tsx`](../../admin/src/shared/layouts/console-layout.tsx).
- Reviewer/editor/contributor tidak melihat menu. API tetap 403.

---

## 2. Halaman list

Header: "Pengajuan verifikator", tombol muat ulang.

Tabs: Menunggu | Disetujui | Ditolak | Semua. Default Menunggu.

Tabel:

| Kolom | Keterangan |
| --- | --- |
| Username | Pemohon; tautan `UserInfoLink` (modal info user, tanpa User ID) |
| HP | `phone` internasional tanpa + |
| Status | Badge pending/approved/rejected |
| Diajukan | `created_at` relatif/formatDateTime |
| Aksi | Detail |

Cursor pagination (tombol muat lagi), pola `useCursorList`.

---

## 3. Halaman detail

Header: "Review pengajuan" + kembali ke list.

Tampilkan:

- Username: tautan `UserInfoLink` (buka modal info user). **Jangan tampilkan
  `user_id`.**
- Nomor HP
- Alamat (teks, whitespace pre-wrap)
- Media sosial: tiap item platform + username + thumbnail screenshot
  (`Image` antd di dalam `Image.PreviewGroup`, klik membuka overlay).
  Bukan tautan URL. Aturan umum: **Preview gambar** di `admin-base-stack.md`.
- Status + waktu `created_at`

### Modal info user (`UserInfoModal`)

Komponen shared di
[`user-info-modal.tsx`](../../admin/src/shared/components/user-info-modal.tsx).
Klik username (pemohon atau reviewer) membuka popup profil publik:

- Username, peran, status verifikator, tanggal bergabung
- Statistik: kontribusi disetujui, verifikasi dilakukan
- **Tanpa User ID, email, atau nomor HP** (PII aplikasi tetap di kartu
  pengajuan, bukan di modal)

Data: `GET /api/v1/users/:username` (`docs/api/19-api-profil-publik.md`).
Hook: `shared/hooks/use-public-profile.ts`.

### Card siapa yang memutuskan

Jika sudah direview (`reviewed_at` terisi), tampilkan Card:

- Judul: "Disetujui oleh" / "Ditolak oleh" (fungsi
  `verifierReviewerCardTitle`)
- Username reviewer (`reviewed_by_username`, tautan modal yang sama)
- Waktu `reviewed_at` lewat `formatDateTime`
- `admin_comment` jika ada (penolakan)

Pending: card ini tidak tampil.

Aksi hanya jika `pending`:

- Setujui: konfirmasi singkat, POST approve (tanpa body)
- Tolak: modal, alasan wajib (`comment`), POST reject

Sukses: toast + invalidate query list/detail. Approve mengubah role
pemohon menjadi reviewer (session pemohon harus login ulang).
