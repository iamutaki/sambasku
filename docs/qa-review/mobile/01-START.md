# QA Review UX - `mobile/*` (SambasKu Mobile)

| | |
|---|---|
| **Target** | `mobile/` - aplikasi Flutter (Android + iOS), flavor staging |
| **Peran** | QA professional - fokus kenyamanan pengguna (UX, state, feedback, navigasi, aksesibilitas) |
| **Metode** | **Pengujian interaktif di perangkat Android fisik** (CPH2743, Android 16, 1080×2372) - launch, navigasi tap, ketik, audio, toggle tema, deep link cold-start, validasi form - 15 screenshot; diperkaya review statis pola UX (retry/toast/skeleton/empty state/Semantics) di 628 file Dart |
| **Tanggal** | 2026-09-24 |
| **Environment** | `com.iamutaki.sambasku.staging` terpasang di device, API staging |
| **Status** | ✅ Selesai - sesi 1 (pendamping: [web](../web/01-START.md)) |

**Alur yang diuji**: cold start → home (WOTD + kata terbaru) → detail kata (definisi, contoh+audio, chip IPA, tombol rekam) → **play audio (state playing)** → Eksplorasi (peta dialek + kategori) → pencarian (ketik live, saran dua arah) → Kontribusi (login wall guest) → Profil (guest) → Masuk (form + **validasi kosong**) → system back → toggle tema light → **deep link cold-start** `sambasku://app/words/Rappeh`.

---

## 1. Ringkasan Eksekutif

Aplikasi mobile ini **lebih matang dari web** dalam disiplin UX-nya - dan itu terlihat langsung di perangkat:

- **Feedback di mana-mana**: validasi form login langsung menampilkan pesan inline ("Email wajib diisi") - bukan tombol disabled yang bisu seperti di web. Pola ini konsisten di kode: 124 panggilan toast, 35 layar dengan tombol "Coba lagi", 23 layar skeleton, 46 empty state.
- **Pencarian lebih pintar dari web**: mengetik "ram" langsung menyarankan hasil **dua arah sekaligus** - "ramah - Terjemahan dari: Rappeh" + "Rappeh - kata Sambas". Di web, arah harus dipilih manual dan salah arah = hasil kosong palsu.
- **Detail kata adalah showcase**: definisi penuh, contoh kalimat + audio dengan state playing jelas (ikon berubah + progres), chip IPA, hingga tombol rekam kontribusi lafal.
- **Deep link cold-start** mendarat langsung ke detail kata tanpa mampir ke home - benar.

Yang perlu dibenahi: **titik masuk pencarian kurang menonjol** (hanya ikon kecil, padahal mencari adalah aksi nomor satu aplikasi kamus), **konsistensi perilaku dengan web** (mobile harus jadi standar, web mengejar), dan **aksesibilitas TalkBack yang tipis** (hanya 12 `Semantics` di seluruh codebase).

### Matriks Temuan

| ID | Temuan | Severity | Bukti |
|---|---|---|---|
| MUX-01 | Titik masuk pencarian hanya ikon kecil di Eksplorasi - aksi primari kamus tidak menonjol; home tanpa search bar | 🟠 Major | Screenshot home & Eksplorasi |
| MUX-02 | Inkonsistensi perilaku vs web: (a) validasi form - mobile inline ✅ / web bisu ❌; (b) pencarian - mobile dua arah otomatis ✅ / web manual+gagal-senyap ❌ | 🟠 Major | Sesi web + mobile |
| MUX-03 | Aksesibilitas TalkBack tipis: hanya 12 `Semantics(` di 628 file - tombol ikon-only (share, rekam, tema) berisiko tak bersuara | 🟠 Major (a11y) | grep codebase |
| MUX-04 | Definisi WOTD terpotong ellipsis tanpa affordance "selengkapnya" (sama seperti web) | 🟡 Minor | Home |
| MUX-05 | Profil tamu menampilkan statistik 0/0/0 - tidak bermakna untuk guest | 🟡 Minor | Profil |
| MUX-06 | Peta dialek memuat tile jaringan di prime area Eksplorasi - konsumsi data + perhatian sebelum konten kata | 🟡 Minor | Eksplorasi |
| MUX-07 | Konsistensi kontras light mode perlu audit menyeluruh (badge abu muda pada kartu) | 🟡 Minor | Profil light |
| MUX-08 | Chip "Populer" pada pencarian tampaknya berbasis seluruh korpus kecil staging - verifikasi relevansi saat korpus tumbuh | 🔵 Polish | Search |

**Tidak ditemukan Blocker.** Cold start cepat, tanpa crash ANR, navigasi back natural, deep link akurat, tema toggle instan.

---

## 2. Temuan Detail

### MUX-01 · Pencarian - aksi primari yang bersembunyi - 🟠 Major

**Repro**: Buka app → Beranda.
**Aktual**: Home menampilkan WOTD + kata terbaru **tanpa search bar**. Untuk mencari: tab Eksplorasi → ikon kaca pembesar kecil di pojok kanan atas (±48dp, satu-satunya jalan). Di web, search bar besar jadi hero home.
**Dampak**: Untuk aplikasi kamus, "cari kata" adalah pekerjaan #1 pengguna - menambahinya 2 langkah + ikon kecil menurunkan kenyamanan inti produk, apalagi bagi pengguna baru.
**Ekspektasi**: Search bar langsung di Beranda (di atas WOTD, cukup tappable → buka layar Cari Kata yang sudah bagus). Alternatif murah: kolom "cari" semi-aktif (tampil seperti field, tap → pindah ke layar search) - pola standar aplikasi kamus/komunikasi.

### MUX-02 · Perilaku berbeda dengan web untuk fitur yang sama - 🟠 Major (konsistensi lintas platform)

Dua kasus teramati langsung dalam dua sesi QA berturut-turut:

1. **Validasi form**: submit kosong di mobile → pesan inline merah per field ✅. Password lemah di web → tombol disabled diam-diam ❌ (temuan UX-04 web).
2. **Pencarian**: mobile "ram" → saran **lemma + terjemahan sekaligus** dengan label pembeda ("Terjemahan dari: Rappeh") ✅. Web "ram" arah Sambas→Indonesia → "belum ditemukan" padahal "ramah" ada ❌ (akar temuan UX-05 web).

**Dampak**: Pengguna lintas platform (web → app, share link → app) mendapat pengalaman berbeda untuk kebutuhan yang sama; versi yang lebih lemah (web) terasa turun kualitas.
**Ekspektasi**: Anggap perilaku mobile sebagai **standar produk** dan samakan web: (a) form web pakai validasi inline, (b) search web fallback arah otomatis + saran dua arah. Catat di design system bahwa "cari = dua arah, selalu".

### MUX-03 · Aksesibilitas TalkBack tipis - 🟠 Major (a11y)

**Bukti**: `grep "Semantics(" lib/` → **12 hasil** untuk 628 file. Banyak kontrol interaktif ikon-only (share di detail kata, tombol rekam lafal, toggle tema, play audio) berpotensi diberitahukan TalkBack tanpa nama/i salah nama ("tombol" kosong).
**Ekspektasi**: Audit semua `IconButton`/gestur: bungkus dengan `Semantics(label: ..., button: true)` atau pakai `Tooltip` (Flutter otomatis mengekspos tooltip ke a11y). Prioritas: layar detail kata (audio, rekam, share), bottom nav, toggle tema. Tambahkan juga `excludeSemantics` pada dekorasi.

### MUX-04 · Definisi WOTD terpotong tanpa jalan keluar - 🟡 Minor

Sama seperti web (UX-11): kartu "Kata Hari Ini" memotong definisi dengan ellipsis; satu-satunya jalan ke teks penuh adalah tap kartu. Kartu memang elemen klik - tambahkan indikasi visual (chevron) agar terpotong terasa disengaja, atau izinkan 4 baris penuh. **Catatan**: di detail kata definisi tampil UTUH - masalahnya hanya di kartu ringkas.

### MUX-05 · Statistik 0/0/0 untuk tamu - 🟡 Minor

**Aktual**: Profil tanpa login menampilkan baris "0 Kontribusi · 0 Verifikasi · 0 Komentar" - angka kosong yang tidak menyampaikan apa pun.
**Ekspektasi**: Untuk guest, ganti baris statistik dengan ringkasan nilai ("Ikut melestarikan 200+ kata bahasa Sambas") atau sembunyikan; statistik muncul setelah login.

### MUX-06 · Peta dialek: tile jaringan di prime area - 🟡 Minor

**Aktual**: Eksplorasi menaruh peta interaktif (memuat tile dari jaringan) paling atas, di atas chip kategori dan daftar kata.
**Dampak**: (a) konsumsi data pengguna untuk tile yang belum pasti dilihat; (b) konten kata (tujuan utama tab) terdorong ke bawah; (c) di jaringan lambat area ini jadi lubang abu.
**Ekspektasi**: Pertimbangkan peta tertutup/pekat (preview + tombol "Buka Peta") atau letakkan setelah konten kata; lazy-load tile saat pertama kali dibuka.

### MUX-07 · Kontras light mode - 🟡 Minor (verifikasi lanjutan)

Profil light mode terlihat bersih; badge abu ("STAGING", label statistik) dan teks sekunder borderline terhadap WCAG AA. Jalankan pemeriksa kontras menyeluruh saat tema light aktif (mobile tidak punya tool seinstan Lighthouse web - gunakan screenshot + kalkulator kontras, atau flutter a11y assessables).

### MUX-08 · Chip "Populer" - 🔵 Polish

Saran populer di layar pencarian (Rappeh, Tongkeng, somet, cobe, lading) kemungkinan besar = seluruh korpus staging. Verifikasi definisi "populer" (berdasarkan apa?) dan pastikan tetap relevan/bervariasi saat korpus ratusan kata.

---

## 3. Yang Lolos dengan Baik ✅

| # | Pemeriksaan | Bukti |
|---|---|---|
| P-01 | Cold start cepat: splash → home ±5 detik tanpa login gate; pengguna tamu langsung bisa pakai | Screenshot 01→03 |
| P-02 | Audio player state jelas: play → ikon pause + progres hitung; durasi tertera (0:06) | Detail kata |
| P-03 | Validasi form inline langsung ("Email wajib diisi", "Kata sandi wajib diisi") | Login kosong |
| P-04 | Pencarian live saat mengetik + **saran dua arah dengan disambiguasi** ("Terjemahan dari: …") + anti-stale (debounce + request-id guard di kode) | Search "ram" |
| P-05 | Login wall bernilai: penjelasan manfaat + jalur anonim tetap ada ("Ajukan tanpa akun") | Tab Kontribusi |
| P-06 | Tombol Facebook **otomatis disembunyikan** saat provider nonaktif - tidak ada tombol mati | Login |
| P-07 | Deep link cold-start `sambasku://app/words/Rappeh` mendarat **langsung** ke detail kata | Screenshot 15 |
| P-08 | System back natural: detail → tab sebelumnya (shell dipertahankan) | keyevent 4 |
| P-09 | Theme toggle instan dark↔light tanpa flicker; light mode bersih | Screenshot 14 |
| P-10 | Banner "v0.1.0 • STAGING" benar-benar staging-only (`F.isStaging` + `hideDevChrome`) - tak akan muncul di produksi | `version_banner.dart:18` |
| P-11 | Disiplin state luas: 35 layar "Coba lagi", 23 skeletonizer, 46 empty state, 124 toast - kegagalan jarang berujung layar mati | grep |
| P-12 | Izin notifikasi diminta di onboarding (bukan cold start) | Dokumentasi arsitektur + kode |
| P-13 | Foto kontribusi: kompresi otomatis 720px/WebP-80 (hemat data upload), avatar 1600px pra-crop agar crop 1:1 tetap tajam | `photo_pick_constants.dart` + `compress_image_for_upload.dart` |
| P-14 | Kata belum terverifikasi berbadge jelas ("MENUNGGU PENGECEKAN" amber) berdampingan dengan "TERVERIFIKASI" hijau | Home |

## 4. Keterbatasan Sesi

- **Sesi tamu**: login/register/OTP, kontribusi authenticated (form kata + rekam audio + photo pick), komentar, bookmark, inbox notifikasi **belum dijalankan** - butuh akun uji staging; form kosong saja yang divalidasi.
- iOS (iPhone "Ibnul" terhubung wireless) tidak diuji - perilaku dynamic type, safe-area, dan Universal Links Apple-side belum diverifikasi.
- TalkBack/VoiceOver tidak diaktifkan saat sesi - MUX-03 berbasis audit kode, bukan pengukuran layar pembaca.
- Onboarding tidak terekam (device sudah melewati onboarding); alur izin notifikasi diamati dari kode.

## 5. Prioritas Perbaikan

1. **Sprint ini (MUX-01, MUX-02)**: search bar di Beranda (murah, dampak besar); adopsi standar validasi inline + search dua arah ke web (satu keputusan design system).
2. **Sprint ini (MUX-03)**: sweep `Semantics` untuk tombol ikon-only prioritas (detail kata, bottom nav, tema) + aktifkan TalkBack di device uji.
3. **Berikutnya (MUX-04…MUX-07)**: affordance kartu WOTD, statistik guest, penempatan peta, audit kontras light.
4. **Backlog (MUX-08)**: definisi metric "Populer".

## 6. Retest Checklist

- [ ] Beranda menampilkan search bar tappable; jumlah langkah ke layar pencarian = 1.
- [ ] Web: form kosong/invalid menampilkan pesan inline (paritas mobile).
- [ ] Web: pencarian "ram" tanpa memilih arah menampilkan saran dua arah (paritas mobile).
- [ ] TalkBack aktif: tombol share/rekam/tema di detail kata mengumumkan nama aksinya.
- [ ] Guest: baris statistik 0/0/0 tidak lagi tampil.
- [ ] Eksplorasi: peta tidak memuat tile sebelum dilihat/dibuka.
