# QA Review UX - `console/*` (SambasKu Admin Console)

| | |
|---|---|
| **Target** | `console/` - Admin Console (SPA React 19 + Ant Design 6 + TanStack Router/Query) |
| **Peran** | QA professional - fokus kenyamanan pengguna (UX, state, feedback, aksesibilitas) |
| **Metode** | Pengujian interaktif via browser: login (validasi kosong + kredensial salah + sukses), Dashboard, Kata (+ tab Duplikasi), Antrean Review (+ workspace detail + **eksekusi aksi Setujui**), Audit Log - dengan analisis visual screenshot; dilengkapi pengetahuan struktur dari audit sebelumnya |
| **Tanggal** | 2026-09-24 |
| **Environment** | Dev server `localhost:5174` → **API staging** (instance dev yang sedang berjalan; sesi QA berakhir tanpa mutasi data staging - satu-satunya aksi tulis terblokir 401, lihat CUX-01). Akun: `admin` (role admin). |
| **Status** | ✅ Selesai - sesi 1, penutup seri (pendamping: [web](../web/01-START.md) · [mobile](../mobile/01-START.md)) |

**Catatan metode**: sesi ini awalnya dirancang menguji API lokal (proxy `localhost:3000`), namun port 5174 sudah dipakai instance dev yang berjalan (proxy default → staging) sehingga seluruh pengujian terjadi di atas **data staging yang realistis** - lebih representatif; kecelakaan yang beruntung. Instance tambahan sudah dibersihkan; data staging **tidak berubah**.

---

## 1. Ringkasan Eksekutif

Console admin ini punya **fondasi pola kerja yang sangat bagus**: antrean review master-detail dengan pintasan keyboard (A setujui · R tolak · J/K navigasi) dan janji "lanjut otomatis ke usulan berikutnya"; tab Duplikasi dengan alur gabung pilih-survivor (menjawab langsung akar masalah duplikat yang ditemukan di QA web); audit log dengan filter matang. Form login menampilkan validasi inline dan pesan kredensial salah yang jelas.

Namun ada **satu temuan kritis yang menunjukkan bahaya nyata alat admin**: klik **Setujui** saat access token kedaluwarsa (idle >15 menit) menghasilkan **kegagalan senyap** - request 401 di jaringan, tidak ada toast error, tidak ada redirect, daftar tak berubah. Administrator bisa *meyakini* sudah menyetujui sesuatu yang tidak pernah terjadi. Ditambah dashboard yang hierarkinya terbalik (KPI nyaris tak terlihat, ~55% ruang kosong) dan tombol aksi tabel tanpa nama aksesibel.

### Matriks Temuan

| ID | Temuan | Severity | Bukti |
|---|---|---|---|
| CUX-01 | **Mutasi gagal senyap saat token kedaluwarsa** - Setujui → 401 → tanpa toast/redirect perubahan apa pun | 🔴 Critical (bugs UX alat admin) | Klik Setujui, console 401, status staging tetap `pending`, UI tanpa reaksi |
| CUX-02 | Hierarki Dashboard terbalik: KPI strip kecil inline, WOTD dominan, ~55% area kosong, label "Mutasi 7h 96" ambigu, kotak oranye tanpa legenda | 🟠 Major | Analisis screenshot dashboard |
| CUX-03 | Tombol aksi tabel ikon-only tanpa nama aksesibel (eye/edit/delete); nama ikon ikut ke nama aksesibel menu ("book Kamus") | 🟠 Major (a11y) | Snapshot halaman Kata + sidebar |
| CUX-04 | Semua halaman berjudul `h4` tanpa `h1` | 🟡 Minor | Semua snapshot |
| CUX-05 | Sidebar tanpa badge jumlah antrean (padahal tab "Duplikasi (2)" di halaman Kata sudah punya - pola bagusnya sudah ada) | 🟡 Minor | Sidebar vs tab |
| CUX-06 | Kapitalisasi menu tak seragam: "Pengajuan verifikator" vs "Laporan Masalah" | 🟡 Minor | Sidebar |
| CUX-07 | Kebisingan console: probe refresh tamu 401 (2× per load) + 3 warning deprecation antd (`Space direction`, `Alert message`, `Drawer width`) | 🟡 Minor | Console log |
| CUX-08 | Tombol "Muat ulang" permanen di header tiap halaman - pola "diperbarui pukul HH:MM" + auto-refresh lebih bermakna | 🟡 Minor | Semua halaman |
| CUX-09 | Toggle inline Tayang/Terverifikasi di tabel Kata: cepat, tapi perlu verifikasi adanya konfirmasi/undo - salah ketuk = konten langsung hilang tayang | 🟡 Minor (perlu verifikasi) | Halaman Kata |

---

## 2. Temuan Detail

### CUX-01 · Mutasi gagal senyap saat sesi kedaluwarsa - 🔴 Critical

**Repro** (terdokumentasi dari sesi nyata):
1. Login sebagai admin, biarkan tab idle **> 15 menit** (TTL access token).
2. Buka Antrean Review → pilih usulan → klik **Setujui**.

**Aktual**:
- Network: `POST /api/v1/admin/contributions/{id}/approve` → **401 Unauthorized**.
- UI: **tidak ada toast, tidak ada pesan error, tidak ada redirect ke login, daftar tidak berubah** - tombol terasa "tidak melakukan apa-apa".
- Verifikasi silang ke API: status usulan tetap `pending` (mutasi tidak pernah terjadi). Interceptor refresh-401 yang seharusnya memulihkan sesi tampaknya tidak menuntaskan retry pada jalur mutasi ini.

**Dampak**: Administrator **meyakini usulan sudah disetujui** (atau bingung kenapa tombol mati) dan berpindah - antrean sebenarnya tak tersentuh. Untuk alat yang pekerjaan intinya adalah moderasi, kegagalan senyap = kehilangan kepercayaan pada alat itu sendiri.

**Ekspektasi**:
1. Jalur refresh-401 harus menuntaskan: refresh sukses → **replay mutasi** (single-flight sudah ada) → hasil terlihat.
2. Bila refresh gagal (sesi benar-benar mati): toast jelas ("Sesi berakhir, silakan masuk lagi") + redirect `/login` + **kembali ke item yang sedang ditinjau setelah login ulang**.
3. Regression test: idle > TTL → klik tiap tombol mutasi (Setujui/Tolak/Koreksi/toggle/ hapus) → pastikan feedback selalu ada.

### CUX-02 · Dashboard: hierarki terbalik + ruang kosong - 🟠 Major

**Aktual** (analisis screenshot):
- Statistik inti (Kata 17 · Kontribusi 33 · Pengguna 8 · Mutasi 96) dirender sebagai **teks inline kecil dengan pemisah titik** - elemen paling penting halaman justru paling tidak terlihat.
- Label **"Mutasi 7h 96"** ambigu (label+kualifikasi+nilai menyatu tanpa pemisah; "7h" hanya ada di satu stat).
- Ada **kotak oranye mengelilingi "Kontribusi 33"** tanpa legenda - terlihat seperti focus ring nyasar / rusak, padahal mungkin penanda antrean menunggu.
- Kartu Kata Hari Ini (konten editorial publik) mendominasi; ~**55% area utama kosong** di bawah strip statistik.
- Judul "Dashboard" triplegt: breadcrumb + judul halaman + chip pengguna.

**Ekspektasi**:
1. Baris 4 stat card (angka besar ±32px + delta mingguan + klik → drill-down ke halaman terkait).
2. Isi area kosong dengan yang dibuka admin: antrean moderasi menunggu (verifikator + laporan + review kontribusi) dengan aksi cepat, aktivitas terbaru (5 entri audit), ringkasan "butuh perhatian".
3. Kotak oranye: beri legenda ("menunggu tindakan") atau ganti pola; label stat → `Mutasi (7 hari): 96`.

### CUX-03 · Aksesibilitas: tombol tanpa nama + nama ikon bocor - 🟠 Major (a11y)

**Aktual**:
- Tombol aksi per baris tabel Kata (lihat/edit/hapus) murni ikon **tanpa `aria-label`** - screen reader mengumumkan "tombol" kosong; tiga tombol identik berturut-turut.
- Nama ikon AntD ikut menjadi bagian nama aksesibel item menu/sidebar ("book Kamus", "translation Kata") dan tombol ("check Setujui") - berisik untuk pembaca layar.

**Ekspektasi**: `aria-label` deskriptif untuk semua tombol ikon ("Lihat kata X", "Hapus kata X" - sertakan konteks baris!); ikon dekoratif `aria-hidden`.

### CUX-04 · Tanpa `h1` - 🟡 Minor

Semua judul halaman konsol `h4` (AntD Card title). Setiap halaman sebaiknya punya satu `h1` (bisa visually-hidden) demi struktur pembaca layar + SEO halaman konsol (lebih ringan, tapi konsistensi tetap murah).

### CUX-05 · Sidebar tanpa badge jumlah - 🟡 Minor

"Pengajuan verifikator", "Laporan Masalah", dan "Review" adalah item yang hidup dari jumlah antrean - tanpa badge, admin harus membuka tiap halaman untuk tahu ada pekerjaan menunggu. Pola yang tepat **sudah ada di produk**: tab "Duplikasi (2)" di halaman Kata. Seragamkan: badge merah jumlah `pending` di item menu terkait (data dari dashboard stats yang sudah ada).

### CUX-06 · Kapitalisasi menu tak seragam - 🟡 Minor

"Pengajuan verifikator" (sentence case) berdampingan dengan "Laporan Masalah" (title case). Pilih satu konvensi (title case disarankan mengikuti mayoritas).

### CUX-07 · Kebisingan console - 🟡 Minor

- Probe sesi tamu (`/auth/refresh` 401) tercatat sebagai **error console 2×** per kunjungan - ditangani senyap secara UX, tapi error merah di console menakuti developer dan mencemari error-reporting. Pertimbangkan `tryRefresh` tanpa log network error (POST tetap terlihat, tapi tidak perlu dianggap error aplikasi).
- 3 warning deprecation antd (`Space direction`, `Alert message`, `Drawer width`) - upgrade API kecil, hilangkan noise sebelum antd major berikutnya.

### CUX-08 · "Muat ulang" di mana-mana - 🟡 Minor

Tombol reload permanen di header semua halaman memberi kesan data tidak bisa dipercaya segar. Ganti dengan stempel "Diperbarui HH:MM" + refresh otomatis saat window fokus kembali (TanStack Query `refetchOnWindowFocus`).

### CUX-09 · Toggle inline berisiko - 🟡 Minor (perlu verifikasi lanjutan)

Tabel Kata memasang **switch Tayang/Terverifikasi langsung di baris** - cepat untuk editor, tapi satu ketukan salah = konten hilang dari publik tanpa konfirmasi (belum diverifikasi apakah ada Popconfirm/undo - **tidak dieksekusi** sesi ini karena berdampak data staging). Verifikasi: (a) ada konfirmasi atau tidak, (b) apakah tersedia undo, (c) apakah aksi tercatat di audit log (seharusnya ya).

---

## 3. Yang Lolos dengan Baik ✅

| # | Pemeriksaan | Bukti |
|---|---|---|
| P-01 | Login: validasi inline ("Email wajib diisi"), error kredensial jelas ("Email atau password salah"), input dipertahankan setelah gagal | Sesi login |
| P-02 | Workspace review lengkap: seluruh data usulan (makna, register, contoh + atribusi "Penutur Asli"), catatan opsional, tiga aksi (Tolak/Koreksi/Setujui) | Detail usulan kamok |
| P-03 | **Pintasan keyboard** "A setujui · R tolak · J/K pindah antrean" - kenyamanan power-user yang jarang ada | Panel review |
| P-04 | Alert edukatif di workspace: "Satu kata tayang per bahasa - Setujui akan menggabungkan makna…" (mencegah kebingungan duplikat di sumbernya) | Panel review |
| P-05 | **Tab Duplikasi (2) + alur gabung pilih-survivor** (radio entri, Detail, Gabungkan) - tool yang tepat sudah ada; duplikat "lading" di web = antrean merge belum dijalankan, bukan tooling kurang | Halaman Kata |
| P-06 | Audit Log: filter rentang tanggal + pelaku + aksi, tombol Reset **disabled saat tanpa filter** (state-aware), diff perubahan expandable ("+4 field lainnya") | /audit-logs |
| P-07 | Empty state berilustrasi ("Pilih usulan di kiri untuk meninjau", "Tidak ada data") - bukan layar kosong | Review + tabel |
| P-08 | Umpan balik sukses login: alert "Selamat datang, admin" + chip peran di header | Dashboard |
| P-09 | Breadcrumb konsisten (Konsol / …) di semua halaman terkunjung | Global |
| P-10 | Menu sidebar difilter per role (dari audit sebelumnya) - contributor tidak melihat menu admin | Kode + audit |
| P-11 | Sesi restore senyap untuk tamu (tanpa flash error, langsung /login) | Boot |

## 4. Keterbatasan Sesi

- **Aksi destruktif/tulis lain tidak dieksekusi** (Tolak, Koreksi, toggle Tayang, hapus kata, impor massal, campaign, ubah role) - data staging milik bersama; CUX-09 khususnya butuh sesi dedikatif di API lokal.
- **CUX-01 berdasarkan satu kejadian nyata** - perlu reproduksi terkontrol (idle persis >15 menit, variasi tombol) untuk memastikan cakupan (semua mutasi? hanya approve? kondisi race refresh?).
- Tampilan responsif (tablet/mobile), role reviewer & contributor, dan halaman Notifikasi/Laporan/Pengguna/Bantuan belum dikunjungi (menu terverifikasi ada).
- i18n console belum diuji (satu bahasa).

## 5. Prioritas Perbaikan

1. **Segera (CUX-01)**: reproduksi → perbaiki jalur refresh/replay mutasi + feedback wajib pada semua kegagalan mutasi. Ini satu-satunya temuan yang membuat alat tidak bisa dipercaya.
2. **Sprint ini (CUX-02, CUX-03)**: redesign ringan dashboard (stat cards + antrean butuh-perhatian); sweep `aria-label` tombol ikon + bersihkan nama ikon dari aksesibilitas menu.
3. **Berikutnya (CUX-04…CUX-08)**: h1 per halaman, badge antrean sidebar, kapitalisasi, bersih-bersih deprecation antd, pola "diperbarui pukul".
4. **Verifikasi (CUX-09)**: sesi khusus di API lokal untuk uji konfirmasi/undo toggle inline + paritas audit log.

## 6. Retest Checklist

- [ ] Idle 20 menit → klik Setujui → mutasi **terjadi** (replay sukses) ATAU toast "Sesi berakhir" + redirect + kembali ke item setelah login.
- [ ] Semua tombol aksi baris tabel punya `aria-label` unik per baris.
- [ ] Dashboard: 4 stat card angka besar, klik → halaman terkait; area kosong terisi antrean butuh-perhatian.
- [ ] Badge jumlah pending di menu Review/Pengajuan verifikator/Laporan Masalah.
- [ ] Console bebas error 401-refresh tamu + 3 warning deprecation antd.
- [ ] `axe DevTools` di halaman Kata & Review → 0 violation nama aksesibel.
