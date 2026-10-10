# QA Review UX - `web/*` (SambasKu Web)

| | |
|---|---|
| **Target** | `web/` - situs publik kamus (React Router 7 SSR + Mantine) |
| **Peran** | QA professional - fokus kenyamanan pengguna (UX, state, aksesibilitas, responsivitas) |
| **Metode** | Pengujian eksploratori live: dev server (proxy ke API staging) + browser nyata (desktop 1280px & mobile 375px), alur utama dilalui end-to-end, screenshot dianalisis visual, console dipantau |
| **Tanggal** | 2026-09-24 |
| **Environment** | localhost:5173 (dev) - data staging (korpus kecil: ~10 kata) |
| **Status** | ✅ Selesai - sesi 1 |

**Alur yang diuji**: Beranda (desktop+mobile, dark+light) → pencarian (kosong / hasil / tidak-ketemu / arah ID→Sambas) → daftar A-Z (+ filter huruf kosong) → detail kata (+ tombol bagikan) → ruang diskusi (empty state) → kontribusi (struktur form) → reset password (validasi) → 404 → drawer mobile → toggle tema.

---

## 1. Ringkasan Eksekutif

Kesan umum: **aplikasi yang sopan dan matang untuk pengguna**. State halaman dirancang dengan sadar - empty state selalu punya jalan keluar, feedback instan di aksi, pesan error berbahasa manusia, konsol bersih (0 error sepanjang sesi). Fondasi aksesibilitas juga ada (`lang=id`, aria-label di tombol ikon, label form lengkap).

Masalah terbesar ada di tiga area: (1) **kualitas data di permukaan** - kata duplikat dan belum terverifikasi muncul di daftar yang menjanjikan konten terverifikasi; (2) **kenyamanan mobile** - touch target di bawah standar 44px pada aksi terpenting; (3) **form yang bisu** - tombol disabled tanpa menjelaskan kenapa. Semuanya fixable dengan effort kecil-menengah.

### Matriks Temuan

| ID | Temuan | Severity | Lokasi/Bukti |
|---|---|---|---|
| UX-01 | Kata duplikat di daftar A-Z: "lading" tampil 2× (status beda, URL sama) | 🟠 Major | `/words`, data staging |
| UX-02 | Copy "sudah terverifikasi dan tayang" vs isi berisi kata "Menunggu pengecekan" | 🟠 Major | `/words` |
| UX-03 | Touch target < 44px: tombol Cari, ikon header, pill arah pencarian (mobile) | 🟠 Major | Beranda mobile |
| UX-04 | Submit disabled tanpa penjelasan - password lemah dibiarkan bingung | 🟠 Major | `/reset-password` (pola umum form) |
| UX-05 | State aktif toggle arah pencarian terlalu samar (dark & light) | 🟡 Minor | Search bar |
| UX-06 | Tooltip "Tema gelap" nyangkut/overlap setelah toggle di mobile; ambigu status-vs-aksi | 🟡 Minor | Header mobile |
| UX-07 | Kontras light mode di bawah ambang: badge hijau, pill tanggal, pill non-aktif, placeholder | 🟡 Minor | Beranda light |
| UX-08 | Hirarki heading tidak konsisten: `/words` & `/search` mulai h2, `/reset-password` h3 - tanpa h1 | 🟡 Minor | Multi-halaman (a11y/SEO) |
| UX-09 | Tombol tutup drawer mobile tanpa nama aksesibel | 🟡 Minor | Mobile drawer |
| UX-10 | Grid alfabet timpang (15+11) & huruf kosong tetap aktif | 🟡 Minor | Beranda + `/words` |
| UX-11 | Definisi WOTD terpotong tanpa affordance "selengkapnya" | 🟡 Minor | Kartu Sorotan |
| UX-12 | Font preload warning: `pjs-latin-var.woff2` preloaded-tak-terpakai | 🟡 Minor | Console (perf+noise) |
| UX-13 | Tidak ada skip-link ke konten utama | 🟡 Minor | Global (keyboard user) |
| UX-14 | "Hapus akun" terkubur di baris copyright 12px | 🔵 Polish | Footer |
| UX-15 | Label "Sorotan Hari Ini" (jamak) untuk satu kartu; dual timeframe "Kata Hari Ini" vs "Baru Pekan Ini" | 🔵 Polish | Beranda |

**Tidak ditemukan Blocker.** Tidak ada crash, error konsol, dead link, atau layout yang pecah di seluruh alur yang diuji.

---

## 2. Temuan Detail

### UX-01 · Kata duplikat di daftar A-Z - 🟠 Major (data quality di permukaan)

**Repro**: Buka `/words`.
**Aktual**: Grup "L" memuat **"lading" dua kali** - satu berbadge "Menunggu pengecekan", satu "Terverifikasi", keduanya menaut ke `/words/lading` (URL identik → pengguna tidak tahu dua entri ini kata yang sama atau beda; klik keduanya mendarat di halaman yang sama).
**Dampak**: Kebingungan langsung di halaman katalog inti produk; menurunkan kepercayaan terhadap data kamus.
**Ekspektasi**: Satu lemma = satu kartu (gabungkan varian status, tampilkan status tertinggi); atau tandai jelas "entri duplikat sedang digabung".
**Saran**: Ini gejala data (dua row kata dengan lemma sama, satu verified satu belum) - pertimbangkan juga dedup di API (`listWordsAtoZ`), karena konsol admin punya fitur merge duplicate yang tampaknya belum dijalankan untuk kasus ini.

### UX-02 · Copy menjanjikan hal yang tidak dipenuhi - 🟠 Major

**Repro**: `/words` - subjudul: *"Katalog kosakata Kamus Sambas yang sudah terverifikasi dan tayang."*
**Aktual**: Daftar menampilkan kata berlabel "Menunggu pengecekan" (lading, tarai).
**Dampak**: Ekspektasi pengguna patah; kata belum terverifikasi dianggap sudah dicek.
**Ekspektasi**: Sinkronkan salah satu: (a) copy jadi "…yang sudah tayang" (tanpa klaim verifikasi), atau (b) filter default hanya terverifikasi + toggle "tampilkan yang belum dicek". Opsi (b) lebih jujur sekaligus memberi konteks kontribusi.

### UX-03 · Touch target di bawah standar pada aksi utama - 🟠 Major (mobile)

**Repro**: Beranda di viewport 375px.
**Aktual** (dari analisis visual): tombol **Cari** ±32-34px tingginya, ikon tema/hamburger ±32px berdempetan, pill "Sambas → Indonesia"/"Indonesia → Sambas" ±30-34px dengan gap kecil.
**Standar**: 44px (iOS HIG) / 48dp (Material).
**Dampak**: Aksi primari (mencari) rawan salah-tap; kesalahan memilih arah pencarian menghasilkan "tidak ditemukan" yang menyesatkan.
**Ekspektasi**: Minimal 44×44px untuk semua kontrol interaktif di mobile; beri jarak ≥8px antar target bersebelahan.

### UX-04 · Form yang bisu: disabled tanpa penjelasan - 🟠 Major

**Repro**: `/reset-password` → isi "Kode" valid + password `lemah`.
**Aktual**: Tombol "Simpan password" tetap disabled, **tidak ada pesan apa pun** menjelaskan kenapa. Satu-satunya petunjuk aturan ("Minimal 8 karakter, huruf + angka") ada di placeholder - yang **hilang begitu pengguna mengetik**.
**Dampak**: Pengguna menebak-tebak; pada flow pemulihan akun (user sudah stres) ini penyiksa kecil yang klasik.
**Ekspektasi**: Checklist requirement live di bawah field (✓ 8 karakter, ✓ huruf, ✓ angka) atau pesan error inline saat field dirty; pola ini kemungkinan berlaku juga di form kontribusi - audit semua form dengan pola `disabled={!canSubmit}`.

### UX-05 · State aktif arah pencarian samar - 🟡 Minor

**Repro**: Beranda/search, bandingkan pill aktif vs tidak (dark & light).
**Aktual**: Aktif hanya dibedakan outline tipis + sedikit terang; di light mode semakin samar (hitam-di-putih vs abu-di-abu).
**Dampak**: Pengguna bisa mencari dengan arah salah → hasil kosong palsu (dikonfirmasi saat uji: "ram" di arah Sambas→Indonesia tidak menemukan apa pun, padahal "ramah" ada sebagai terjemahan).
**Ekspektasi**: Pill aktif terisi (filled) dengan warna aksen; pertimbangkan juga pencarian lintas-arah otomatis (fallback: "Tidak ada kata Sambas 'ram'. Maksud Anda terjemahan? Tampilkan hasil Indonesia→Sambas untuk 'ram'").

### UX-06 · Tooltip tema nyangkut & ambigu - 🟡 Minor

**Repro**: Mobile → tap "Ganti tema".
**Aktual**: Tooltip "Tema gelap" muncul overlap area hero dan tampak tidak langsung hilang; teksnya ambigu (status sekarang atau aksi berikutnya?).
**Ekspektasi**: Tooltip hilang otomatis; untuk toggle di mobile lebih baik tanpa tooltip sama sekali (state sudah terlihat dari ikon), atau ubah `aria-label` dinamis ("Aktifkan tema gelap"/"Aktifkan tema terang") tanpa tooltip visual.

### UX-07 · Kontras light mode - 🟡 Minor

**Temuan** (dari analisis visual, perlu verifikasi angka): badge "BARU PEKAN INI" (hijau muda di pill hijau pucat, teks ±10-11px) hampir pasti gagal WCAG AA; pill tanggal biru muda, pill non-aktif, dan placeholder abu muda borderline.
**Ekspektasi**: Audit kontras (axe/Lighthouse ≥ 4.5:1 untuk teks kecil); naikkan saturasi/gelapkan teks badge dan pill.

### UX-08 · Hirarki heading tidak konsisten - 🟡 Minor (a11y + SEO)

**Temuan**: `/ruang-diskusi`, `/kontribusi`, `/words/Rappeh`, `/` → ada `h1` ✅. Tapi `/words` dan `/search` langsung `h2`, `/reset-password` langsung `h3`.
**Dampak**: Pengguna screen reader kehilangan anchor struktur per halaman; crawler kehilangan konteks.
**Ekspektasi**: Setiap halaman tepat satu `h1` (judul utama), lalu turun berurutan.

### UX-09 · Tombol tutup drawer tanpa nama - 🟡 Minor (a11y)

**Temuan**: Setelah drawer mobile terbuka, tombol close ter-render sebagai `button` tanpa nama aksesibel (ikon saja).
**Ekspektasi**: `aria-label="Tutup menu"`. (Tombol "Buka menu navigasi" dan "Ganti tema" sudah benar - tinggal yang ini tertinggal.)

### UX-10 · Grid alfabet timpang + huruf kosong aktif - 🟡 Minor

**Temuan**: 26 huruf break 15+11 → baris kedua timpang dengan dead zone kanan; huruf Q/X/Z (kemungkinan tanpa entri di kamus daerah) tetap bisa diklik → halaman kosong (state-nya bagus, tapi tetap perjalanan buntu).
**Ekspektasi**: Grid seimbang (13×2 atau flex-justify); saat korpus masih kecil, disable huruf tanpa entri (butuh data jumlah per huruf - endpoint `/words?limit=0` meta atau precompute).

### UX-11 · Definisi WOTD terpotong tanpa jalan keluar - 🟡 Minor

**Aktual**: Definisi kartu Sorotan terpotong ellipsis; satu-satunya jalan ke teks penuh adalah tombol "Pelajari Kata Ini".
**Ekspektasi**: Ellipsis terasa "putus" - opsi: izinkan 3-4 baris penuh (kartu memang untuk menarik klik), atau tambah "… selengkapnya" yang menaut ke detail.

### UX-12 · Font preload tidak terpakai - 🟡 Minor (perf + noise)

**Bukti console**: `The resource /fonts/pjs-latin-var.woff2 was preloaded using link preload but not used within a few seconds` (berulang).
**Dampak**: Preload sia-sia (bandwidth + prioritas) - konsisten dengan catatan audit Lighthouse sebelumnya (font-swap bottleneck).
**Ekspektasi**: Pastikan URL preload identik persis dengan yang dipakai CSS (`@font-face`) dan `font-display: swap`; jika font varian tidak selalu terpakai (hanya bobot tertentu), hapus preload atau preload subset yang benar.

### UX-13 · Tanpa skip-link - 🟡 Minor (a11y)

**Temuan**: Tidak ada "Lompat ke konten" untuk pengguna keyboard - header (logo + 4 link + badge) harus di-Tab satu-satu setiap halaman.
**Ekspektasi**: `<a href="#main" class="skip-link">` visually-hidden hingga fokus.

### UX-14 · "Hapus akun" terkubur - 🔵 Polish

Aksi penting (regulasi/kepercayaan) hidup sebagai link 12px di baris copyright. Pindahkan ke grup link footer utama di samping "Privasi".

### UX-15 · Mikro-copy Sorotan - 🔵 Polish

"Sorotan Hari Ini" (jamak) untuk satu kartu; header kartu menampilkan dua timeframe berbeda ("Kata Hari Ini" + "Baru Pekan Ini"). Sederhanakan: "Kata Hari Ini" sebagai judul section, badge "Baru pekan ini" cukup.

---

## 3. Yang Lolos dengan Baik ✅

| # | Pemeriksaan | Bukti |
|---|---|---|
| P-01 | Empty state selalu dengan pemulihan: search miss → CTA "Ajukan Kata Ini" (pre-filled `?q=`); filter kosong → tombol "Hapus Saringan" | `/search?q=ram`, `/words?q=Q` |
| P-02 | Feedback instan: Bagikan → "Tautan Disalin" + warna berubah | `/words/Rappeh` |
| P-03 | 404 benar: status HTTP 404 + pesan manusiawi + CTA beranda | `/halaman-tidak-ada-xyz` |
| P-04 | Placeholder adaptif arah pencarian ("Cari kosakata Sambas…" ↔ "Cari dari bahasa Indonesia (mis. makan, kue)…") | Search |
| P-05 | Form kontribusi matang: label lengkap, KBBI lookup assist, label penggunaan (Kasar/Tabu/…), tambah makna | `/kontribusi` |
| P-06 | Aria-label benar di tombol ikon utama ("Ganti tema", "Buka menu navigasi", "Bersihkan pencarian", toggle visibility password) | Global |
| P-07 | `lang="id"` di html | Global |
| P-08 | Konsol bersih: 0 error sepanjang sesi (hanya devtools info + warning font UX-12) | Semua halaman |
| P-09 | Dark mode cohesive (monokrom + satu aksen); light mode estetik - tidak ada komponen "nyasar" tema | Visual |
| P-10 | Badge Play keluar dari header mobile (tidak memakan ruang navigasi) | 375px |
| P-11 | Radiogroup asli (bukan div custom) untuk arah & filter - semantik a11y benar | Search |
| P-12 | Breadcrumb + "Kembali ke Daftar" konsisten di detail kata | `/words/Rappeh` |

## 4. Keterbatasan Sesi

- Data staging kecil (±10 kata): pagination/cursor "Muat lagi", audio player, kata terkait, variasi, dan contoh kalimat **belum teruji** (butuh kata berisi lengkap).
- Submit kontribusi & reset password **tidak dieksekusi** (menghindari sampah di antrean/endpoint staging) - validasi sisi klien saja yang direview.
- Navigasi keyboard penuh (urutan Tab, focus-visible di semua komponen) dan screen reader belum disurvei menyeluruh - UX-09/13 adalah temuan sampel.
- Kinerja produksi (TTFB saat API tidak sehat pernah terukur 17-24 dtk - lihat laporan pentest web W-04) tidak diuji ulang sesi ini; sesi dev semua halaman merespons wajar.

## 5. Prioritas Perbaikan

1. **Segera (UX-01, UX-02)**: dedup daftar kata + sinkron copy - masalah kepercayaan data di halaman inti.
2. **Sprint ini (UX-03, UX-04, UX-05)**: touch target 44px, feedback form live, state aktif arah pencarian - tiga perbaikan yang langsung terasa di setiap sesi pengguna.
3. **Berikutnya (UX-06…UX-13)**: tooltip tema, audit kontras light mode, konsistensi h1, aria-label tutup drawer, grid alfabet, potongan definisi, preload font, skip-link.
4. **Backlog polish (UX-14, UX-15)**.

## 6. Retest Checklist

- [ ] `/words`: "lading" tampil sekali; copy halaman konsisten dengan isi.
- [ ] Beranda 375px: semua kontrol interaktif ≥44px (ukur di DevTools).
- [ ] `/reset-password`: password `lemah` → pesan inline menjelaskan syarat.
- [ ] Pill arah pencarian aktif terlihat jelas tanpa perlu membandingkan (screenshot A/B).
- [ ] Toggle tema mobile: tidak ada tooltip tersisa; console bebas warning preload font.
- [ ] Setiap halaman punya tepat satu `h1`.
- [ ] `axe DevTools` → 0 violation kontras & nama aksesibel di light mode.
