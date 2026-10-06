# SambasKu Mobile: Prompt Desain Layout

Dokumen ini berisi **prompt meta** (prompt untuk membuat prompt) dan
blok konteks siap tempel. Pakai di ChatGPT, Gemini, Qwen, Claude, atau
alat desain AI lain agar mockup / wireframe / layout screen selaras
dengan aplikasi Flutter `mobile/` (Forui + konvensi repo).

Kontrak implementasi kode: [`mobile/mobile-base-stack.md`](./mobile/mobile-base-stack.md).
Dokumen ini **bukan** ganti base stack; fokusnya hanya desain visual /
struktur layar.

## Cara pakai (ringkas)

1. Salin **Blok konteks tetap** (Section 2) ke chat AI desain.
2. Salin **Prompt meta** (Section 3), isi placeholder `{{...}}`.
3. AI akan mengeluarkan **prompt desain screen** siap tempel ulang
   (ke model yang sama atau ke image/UI generator).
4. Tempel output itu ke model desain; minta wireframe / high-fidelity
   mockup sesuai format di Section 4.

Untuk satu screen cepat tanpa meta: pakai Section 5 (contoh siap pakai).

---

## 1. Ringkas produk (untuk AI)

| Item | Isi |
| --- | --- |
| Nama | **SambasKu** |
| Jenis | Kamus digital **Sambas ↔ Indonesia** (mobile Flutter) |
| Audience | Warga Sambas & pemelajar bahasa; tamu boleh cari tanpa login |
| Nada | Ramah, jelas, lokal; bukan startup SaaS generik |
| Bahasa UI | Indonesia (nanti juga `id_SBS`); copy singkat, tanpa jargon |
| Platform | iPhone + Android; desain **mobile-first**, portrait |
| UI kit di kode | **Forui** (`FScaffold`, `FHeader`, `FTile`/`FTileGroup`, `FButton`, `FBadge`, `FBottomNavigationBar`, ikon Lucide) |
| Spacing | `Gap` kecil (6 / 12 / 14); list **compact**, bukan kartu tebal per baris |
| Tema | Light / dark / system; palet default **Zinc**; user bisa ganti palet Forui |
| Status warna | Success hijau adaptif; warning amber (`Menunggu pengecekan`) |
| Loading | Skeleton yang meniru bentuk konten, bukan spinner tengah layar kosong |
| Tipografi UI | Ikuti Forui; jangan em/en dash di copy (`—` / `–`); pakai hyphen `-` |

### Navigasi shell (4 tab)

| Tab | Path | Isi utama |
| --- | --- | --- |
| Home | `/` | Brand header, kata hari ini, feed kata terbaru, pintu daftar A-Z |
| Eksplorasi | hub explore | Kategori curated (wisata, bahasa & budaya, peta, dll.) |
| Kontribusi | `/action` | Hub aktivitas: usul kata, vote deck, ruang diskusi, dll. |
| Profil | `/profile` | Identitas + menu `FTileGroup` (bookmark, akun, tampilan) |

Bottom nav: Home / Eksplorasi / Kontribusi / Profil. Label Kontribusi
boleh digambarkan sebagai hub aksi komunitas, bukan hanya form kosong.

### Halaman penting di luar tab

Onboarding, login/daftar/verifikasi email, detail kata, daftar A-Z,
form usul kata, antrean review (verifikator), bookmark, notifikasi,
edit profil, hapus akun, laporkan bug, share card kata, profil publik
pengguna, peta Sambas (explore).

### Prinsip layout (wajib di prompt desain)

1. **Compact list**: satu baris = title + subtitle singkat; aksi di suffix
   ikon kecil. Hindari card tebal berulang di list.
2. **Chip untuk pilihan pendek**; tombol penuh hanya untuk aksi
   (Kirim, Simpan, Batal).
3. **Satu pekerjaan per section**; header `FHeader` + title jelas.
4. **Guest-first** di Home: pencarian/baca tanpa memaksa login di hero.
5. **Badge status**: Terverifikasi (hijau) vs Menunggu pengecekan (amber).
6. **Busy aksi**: spinner / "Memproses..." hanya di tombol yang diklik;
   input & tombol lain disabled tanpa loading (lihat `BusyAwareIcon`).
7. **Jangan** purple-glow SaaS generik, dashboard padat, atau hero
   overlay sticker. Aplikasi kamus: tenang, terbaca, konten kata
   jadi pusat.
8. Safe area + bottom nav: konten tidak tertutup; keyboard tidak
   "mendorong" nav aneh (footer tetap).

---

## 2. Blok konteks tetap (tempel dulu)

Salin blok di bawah utuh ke awal percakapan desain:

```text
Kamu membantu mendesain UI aplikasi mobile SambasKu.

Produk: kamus digital bahasa Sambas ↔ Indonesia (Flutter + Forui).
Audience: warga dan pemelajar; tamu boleh mencari tanpa login.
Nada: ramah, lokal, jelas. Copy UI bahasa Indonesia, singkat.
Jangan pakai em dash atau en dash; pakai hyphen ASCII "-".

Design system (ikuti ketat):
- Komponen: FScaffold, FHeader, FTile/FTileGroup, FButton, FBadge,
  FBottomNavigationBar, ikon Lucide-style.
- List selalu compact (bukan kartu tebal per item).
- Pilihan singkat = chip/badge; aksi utama = FButton.
- Loading = skeleton meniru layout, bukan spinner di layar kosong.
- Busy aksi: spinner hanya di tombol target; aksi lain disabled.
- Tema: light/dark; palet default Zinc (abu netral). Success hijau,
  warning amber untuk "Menunggu pengecekan".
- Shell 4 tab: Home | Eksplorasi | Kontribusi | Profil.
- Spacing rapat (Gap 6-14). Mobile portrait, iPhone 15 / Pixel class.

Hindari: purple gradient SaaS, glassmorphism berlebihan, emoji di UI,
card grid padat di hero, overlay badge mengambang di atas media.

Keluaran yang diinginkan darimu: deskripsi layout terstruktur +
wireframe ASCII atau spek komponen per zona (header / body / footer),
siap digambar ulang sebagai mockup. Jika diminta gambar, deskripsikan
prompt image terpisah yang konsisten dengan spek ini.
```

---

## 3. Prompt meta: generate prompt desain screen

Tempel setelah blok konteks. Ganti semua `{{...}}`.

```text
Tugasmu: buat SATU prompt desain UI yang siap saya tempel ke model
desain/image (ChatGPT, Gemini, Qwen, dll.) untuk screen berikut.

## Input screen
- Nama screen: {{NAMA_SCREEN}}
- Tab / rute: {{TAB_ATAU_ROUTE}}  (contoh: Home `/`, atau push `/words/:id`)
- Tujuan user: {{TUJUAN_USER}}
- State yang digambar: {{STATE}}  (contoh: loaded / empty / loading skeleton / error / guest / logged-in)
- Konten wajib tampil: {{ELEMEN_WAJIB}}
- Konten jangan tampil: {{ELEMEN_LARANGAN}}
- Referensi visual opsional: {{REFERENSI}}  (kosongkan jika tidak ada)
- Format output yang saya mau dari model desain nanti:
  {{FORMAT}}  (pilih: "wireframe annotated" | "high-fidelity mockup" | "keduanya")

## Aturan penulisan prompt yang kamu hasilkan
1. Prompt harus self-contained: cukup dibaca sendiri tanpa dokumen ini.
2. Sertakan ringkas: produk SambasKu, Forui/mobile, 4-tab shell bila
   relevan, compact list, Zinc light/dark sesuai state.
3. Jelaskan hierarki visual atas→bawah (status bar → header → konten →
   bottom nav bila tab root).
4. Sebutkan teks UI contoh nyata berbahasa Indonesia (label, empty
   state, CTA) - bukan lorem ipsum.
5. Sebutkan zona interaktif (tap tile, chip, primary button).
6. Larang pola yang dilarang di design system.
7. Jika FORMAT = high-fidelity atau keduanya: tambahkan paragraf
   "Image generation notes" (rasio 9:16, device frame opsional,
   flat UI Forui-like, no watermark).
8. Panjang prompt akhir: 180-350 kata. Bahasa prompt: {{BAHASA_PROMPT}}
   (id atau en). Copy di dalam UI tetap Indonesia.
9. Jangan tulis kode Flutter. Fokus layout & visual.
10. Akhiri dengan checklist 5 butir "Definition of done visual" agar
    saya bisa menilai mockup.

Keluarkan HANYA prompt siap tempel (tanpa pembuka/penutup meta).
```

### Contoh isi placeholder

| Placeholder | Contoh |
| --- | --- |
| `{{NAMA_SCREEN}}` | Home - feed kata terbaru |
| `{{TAB_ATAU_ROUTE}}` | Tab Home `/` |
| `{{TUJUAN_USER}}` | Melihat kata hari ini dan scroll lemma baru |
| `{{STATE}}` | Logged-out, data loaded, light Zinc |
| `{{ELEMEN_WAJIB}}` | FHeader "SambasKu", kartu kata hari ini, list compact lemma+glos, search entry |
| `{{ELEMEN_LARANGAN}}` | Form login di hero, stats dashboard, banner promo |
| `{{REFERENSI}}` | (kosong) |
| `{{FORMAT}}` | keduanya |
| `{{BAHASA_PROMPT}}` | id |

---

## 4. Format yang diminta dari model desain (setelah prompt jadi)

Minta model desain mengembalikan, dalam urutan ini:

1. **Ringkas layar** (1-2 kalimat)
2. **Wireframe ASCII** atau daftar zona (Header / Body sections / Footer)
3. **Komponen per zona** (nama Forui-like + copy contoh)
4. **State variants** singkat (empty / loading skeleton / error) jika relevan
5. **Prompt gambar** (jika high-fidelity): satu paragraf, rasio 9:16
6. **DoD visual** (5 checklist)

---

## 5. Contoh prompt siap tempel (tanpa jalankan meta)

### 5a. Home (feed)

```text
Desain layar mobile portrait aplikasi SambasKu, kamus digital
Sambas-Indonesia. UI kit Forui-like, tema Zinc light, list compact.

Shell: bottom navigation 4 tab (Home aktif, Eksplorasi, Kontribusi,
Profil). Header: judul "SambasKu" + ikon toggle tema di kanan.

Body atas ke bawah:
1) Kartu "Kata hari ini" - lemma Sambas besar, glos Indonesia singkat,
   badge Terverifikasi (hijau), tanpa overlay sticker.
2) Pintu "Daftar kata A-Z" sebagai baris ringkas / search field
   non-fokus yang mengarah ke pencarian.
3) Section "Terbaru" - list tile compact: lemma, subtitle glos 1 baris,
   chevron; jarak antar item rapat.

Jangan: login wall, purple gradient, kartu tebal bertumpuk, emoji.
Copy Indonesia. Keluarkan wireframe annotated + catatan mockup 9:16.
```

### 5b. Detail kata

```text
Desain layar detail kata SambasKu (push di atas shell, ada back).
Forui, Zinc light. Fokus keterbacaan kamus.

Header: lemma + aksi (bookmark, share, more).
Body:
- Meta: jenis kata, badge Terverifikasi atau Menunggu pengecekan (amber).
- Blok makna / glos utama.
- Pelafalan (ikon play) bila ada.
- Gambar kata (opsional) full-bleed dalam konten, bukan kartu mengambang.
- Contoh kalimat.
- Section komentar ringkas / CTA "Lihat komentar".
- Section terkait (sinonim) sebagai tile compact.

Jangan dashboard, jangan paywall. Wireframe + spek zona. Copy ID.
```

### 5c. Profil (logged-in)

```text
Desain tab Profil SambasKu. FHeader "Profil", suffix notifikasi + tema.
Identity group di atas: avatar, nama tampilan, username, role chip
(Kontributor). Lalu FTileGroup berlabel:

- Saya: Notifikasi, Kontribusi Saya, Bookmark, Vote, Komentar,
  Laporkan Masalah
- Akun: Edit profil, Akun terhubung, Ubah sandi, Hapus akun
- Tampilan: Mode tema, Palet warna
- Lainnya: Tentang, Keluar

Semua baris compact title+subtitle+chevron. Gap antar group 14.
Zinc light, Forui. Jangan kartu profil Instagram-style besar.
Wireframe annotated.
```

### 5d. Form usul kata (kontribusi)

```text
Desain form "Usulkan kata" SambasKu. FScaffold + FHeader back.
Field: lemma Sambas, glos/arti Indonesia, jenis kata sebagai chip
(bukan deretan tombol blok), contoh opsional, lampiran gambar
(thumbnail grid kecil + tambah).
Primary FButton "Kirim" di bawah; hint tamu jika guest:
"Dikirim sebagai tamu. Kata belum tayang sampai diperiksa."
Compact, Gap 12, Zinc light. Skeleton hanya jika select remote loading.
Wireframe + empty validation state singkat.
```

---

## 6. Prompt meta: batch banyak screen

```text
Buatkan daftar prompt desain (satu prompt per screen) untuk aplikasi
mobile SambasKu, mengikuti design system Forui/compact/Zinc yang sudah
saya berikan di konteks.

Daftar screen:
{{LIST_SCREEN_PISAH_BARIS}}

Untuk setiap screen:
- Judul markdown `### {nama}`
- Lalu prompt siap tempel (180-300 kata) self-contained
- State default: loaded + light Zinc kecuali saya sebutkan lain

Urutkan sesuai journey: onboarding → home → detail → kontribusi → profil.
Jangan gabungkan beberapa screen dalam satu prompt.
```

---

## 7. Variasi mode output

| Mode | Instruksi tambahan di akhir prompt desain |
| --- | --- |
| Wireframe saja | `Output: ASCII wireframe + bullet spek. Jangan generate image.` |
| High-fidelity | `Output: satu prompt image 9:16 + spek zona teks.` |
| Design critique | `Bandingkan mockup saya (terlampir) ke aturan compact Forui; daftar 5 perbaikan prioritas.` |
| Dark mode | Tambah: `Tema Zinc dark; kontras teks cukup; warning amber tetap terbaca.` |
| Guest vs login | Minta dua kolom zona yang berbeda (CTA login di profil, bukan di home hero). |

---

## 8. Checklist review mockup (manusia)

Centang sebelum implementasi Flutter:

- [ ] Portrait mobile, hierarki header → konten → (bottom nav jika tab)
- [ ] List compact; tidak ada card stack di list panjang
- [ ] Chip untuk pilihan pendek; FButton hanya aksi
- [ ] Copy Indonesia tanpa em/en dash
- [ ] Status Terverifikasi / Menunggu pengecekan konsisten warna
- [ ] Loading digambarkan sebagai skeleton bentuk konten
- [ ] Home tidak memaksa login di hero
- [ ] Tidak terlihat seperti dashboard SaaS ungu generik

---

## 9. Referensi repo

| Dokumen / path | Untuk apa |
| --- | --- |
| [`mobile/mobile-base-stack.md`](./mobile/mobile-base-stack.md) | Konvensi UI kode (5a-5c), stack, routing |
| [`mobile/MOBILE-I18N.md`](./mobile/MOBILE-I18N.md) | Locale & string UI |
| [`produk/tayang-belum-verifikasi.md`](./produk/tayang-belum-verifikasi.md) | Label status publikasi / verifikasi |
| `mobile/lib/core/router/app_router.dart` | Shell 4 tab nyata |
| `mobile/lib/core/theme/forui_palettes.dart` | Palet Forui (default `zinc`) |
| `mobile/lib/features/*/presentation/pages/` | Preseden layout per fitur |

Perbarui dokumen ini jika shell tab, aturan list, atau default palette
berubah di kode.

## 10. Proto HTML (review visual)

Static full mock (bukan Flutter): [`proto/mobile/CURSOR-PROTO/`](./proto/mobile/CURSOR-PROTO/).
Buka `index.html` di browser untuk galeri layar Zinc / Forui-like.
