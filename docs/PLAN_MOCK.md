# PLAN MOCK - Prompt UI/UX + mock data penuh

Dokumen **prompt kanonik** agar AI berperan sebagai UI/UX designer +
content designer, lalu menghasilkan **mockup data lengkap** untuk
seluruh permukaan produk SambasKu (hari ini + roadmap V0-V6 + jalur
monetisasi impact-first).

Tujuan: satu sesi (atau beberapa batch) menghasilkan gambaran utuh
aplikasi - bukan wireframe kosong, melainkan **konten contoh yang
terasa nyata** (lemma, artikel, POI, event, UMKM, paket sekolah,
atribusi mitra) agar PO / desain / engineering bisa melihat produk
sebagai *rumah digital bahasa dan budaya hidup Sambas*.

| Dokumen | Peran |
| ------- | ----- |
| [`ROADMAP_PLAN.md`](./ROADMAP_PLAN.md) | Strategi produk, vertikal, gate, persona |
| [`MONETIZE_PLAN.md`](./MONETIZE_PLAN.md) | Paket kemitraan G1/K1/K2/E1/C1/D1 + anti-goal |
| [`UI.md`](./UI.md) | Shell navigasi + prinsip desain mobile (Forui) |
| [`DESC.md`](./DESC.md) | Positioning store (tetap jujur: kamus dulu) |
| [`GAMIFIKASI_CONCEPT.md`](./GAMIFIKASI_CONCEPT.md) | Streak / point / badge (tampilkan sebagai *future* jika diminta) |
| **Ini** (`PLAN_MOCK.md`) | Prompt + inventaris mock data + checklist kelengkapan |

**Bukan:** kontrak API, spek engineering, atau ganti `UI.md`.
**Ya:** brief desain + dataset fiktif konsisten untuk mockup / prototype.

---

## Cara pakai

1. Salin **Section A** (peran + konteks produk) ke chat AI desain.
2. Salin **Section B** (tugas utama + aturan keluaran).
3. Opsional: minta **satu batch per permukaan** (Section C) agar konteks
   tidak pecah - tapi tetap minta AI menjaga *satu universe data*
   (nama orang, lemma, POI, mitra yang sama di semua layar).
4. Pakai **Section D** sebagai inventaris wajib yang harus diisi AI.
5. Validasi hasil dengan **Section E** (checklist) sebelum dipakai
   Figma / prototype / slide mitra.
6. Untuk desain screen tunggal berulang, kombinasikan dengan blok
   konteks di [`UI.md`](./UI.md) Section 2.

Tips batching (disarankan):

| Batch | Fokus |
| ----- | ----- |
| 1 | Identity system + shell 4 tab + Home + detail kata + A-Z |
| 2 | Kontribusi / vote / diskusi / verifier / notifikasi / profil |
| 3 | Explore: Bahasa & Budaya, Tradisi, Sejarah, Seni (artikel + taut lemma) |
| 4 | Peta + POI + Wisata & Kuliner |
| 5 | Event, Kabar tipis, Komunitas/relawan |
| 6 | UMKM listing + klaim (bukan marketplace, tanpa slot berbayar) |
| 7 | Edukasi sekolah (kuis, wordlist, dashboard guru) |
| 8 | Console admin tipis + permukaan mitra (one-pager dampak, atribusi, campaign) |
| 9 | Gamifikasi *future* (opt-in) + empty/error/guest states global |

Di setiap batch berikutnya, tempel ulang: "Lanjutkan universe data Batch
sebelumnya; jangan ganti nama lemma/POI/user yang sudah ada."

---

## Section A - Peran dan konteks (tempel dulu)

```text
Kamu adalah Senior UI/UX Designer + Content Designer untuk produk
mobile SambasKu. Kamu bukan copywriter iklan generik dan bukan
engineer yang menulis API contract.

MISI PRODUK (north star)
SambasKu adalah rumah digital bahasa dan budaya hidup Melayu Sambas:
orang menemukan, memakai, dan ikut merawat bahasa beserta konteks
hidupnya (tradisi, tempat, kuliner, tokoh, komunitas) dalam satu
produk yang terpercaya. Kamus kolaboratif adalah trust center.
Tanpa kepercayaan pada makna, pelafalan, dan moderasi, ekspansi ke
wisata/UMKM akan terasa seperti portal daerah generik.

THESIS DESAIN
- Kamus = pusat kepercayaan. Status "Terverifikasi" vs "Menunggu
  pengecekan" selalu jelas.
- Explore = perluasan living culture, bukan feed berita.
- Guest-first untuk baca; login untuk ikut membangun.
- Satu pekerjaan per permukaan; Explore bukan dashboard padat.
- Impact-first: inti kamus tetap gratis. Monetisasi lewat kemitraan /
  grant / sekolah / listing ringan - bukan ads interruptive, bukan
  marketplace transaksi penuh.

GEOGRAFI & BRAND
Sambas-first. Copy lokal, bukan portal nasional. Nama merek SambasKu
dan kata Sambas tidak diganti. UI copy bahasa Indonesia, singkat,
ramah, tanpa jargon SaaS. JANGAN pakai em dash (—) atau en dash (–);
selalu hyphen ASCII "-".

AUDIENCE / PERSONA (desain harus melayani semua, tanpa mencampur
pekerjaan di satu layar)
1. Penutur / warga Sambas - lookup cepat, usul perbaikan
2. Diaspora - share card, WOTD, artikel budaya
3. Pelajar / guru - materi, kuis, rujukan terverifikasi
4. Wisatawan / kerabat berkunjung - POI, kuliner, frasa berguna
5. Pelaku UMKM - listing jelas, klaim bisnis, tanpa checkout
6. Verifikator / relawan - antrean jelas, beban terkendali
7. Admin / mitra Pemkab - konten resmi, campaign, metrik dampak

VERTIKAL PRODUK (urutan roadmap - semua harus punya mock data)
V0 Kamus excellence (audio, quality cues, Home discovery, kontribusi)
V1 Budaya hidup (artikel + taut lemma + sumber rujukan)
V2 Peta + POI
V3 Wisata & kuliner
V4 Event curated + komunitas/relawan; Kabar hanya pengumuman mitra tipis
V5 UMKM & jasa (direktori + klaim; TANPA keranjang)
V6 Edukasi (paket sekolah, kuis, dashboard guru sederhana)

ANTI-GOAL (jangan digambarkan sebagai fitur hidup)
- Feed berita generik / timeline harian
- Marketplace order / bayar / ongkir / escrow
- Interstitial / banner iklan acak
- Sponsored "arti kata" palsu
- Social network / chat bebas
- Paywall makna atau hasil pencarian kamus
- Multi-dialek daerah lain sebagai satu app

DESIGN SYSTEM MOBILE (ikuti ketat)
- Flutter + Forui: FScaffold, FHeader, FTile/FTileGroup, FButton,
  FBadge, FBottomNavigationBar, ikon Lucide-style
- Shell 4 tab: Home | Eksplorasi | Kontribusi | Profil
- List compact (bukan kartu tebal berulang); chip untuk pilihan singkat
- Loading = skeleton meniru layout; busy spinner hanya di tombol target
- Tema light/dark; palet default Zinc; success hijau; warning amber
  untuk status menunggu
- Hindari: purple-glow SaaS, glassmorphism berlebihan, emoji di UI,
  hero overlay sticker, dashboard padat

MONETISASI YANG BOLEH MUNCUL DI UI (jelas zona atribusi)
- Atribusi mitra di Tentang / laporan dampak / halaman mitra - BUKAN
  di hasil search kata
- Highlight UMKM terbatas + badge "Bisnis terverifikasi"
- Kampanye notifikasi curated (tampil di inbox; frekuensi jarang)
- Paket sekolah (permukaan guru/murid terpisah, bukan paywall kamus)
- Jangan tampilkan logo sponsor di splash atau di lemma

Kamu akan menghasilkan mock data + spek layar yang konsisten dalam
SATU universe fiktif Sambas (nama tempat, orang, lemma, mitra sama
di semua output).
```

---

## Section B - Tugas utama dan format keluaran

```text
TUGAS
Buatkan inventaris mockup data LENGKAP + spek UI untuk seluruh
feature SambasKu (hari ini + roadmap V0-V6 + permukaan kemitraan
ringan), agar kami mendapat gambaran produk utuh.

Untuk SETIAP permukaan di inventaris (Section D dokumen PLAN_MOCK):
1. Nama layar / state (termasuk empty, loading, error, guest, logged-in)
2. Tujuan pengguna (1 kalimat) + persona utama
3. Hierarchy layout (zona: header / body / footer / bottom nav)
4. Komponen Forui yang dipakai (FHeader, FTile, FBadge, dll.)
5. Copy UI nyata (Bahasa Indonesia, hyphen "-", tanpa em/en dash)
6. MOCK DATA konkret (bukan "lorem"; isi Sambas yang masuk akal)
7. Navigasi masuk/keluar (dari tab mana, deep link ke mana)
8. Analytics event nama (contoh: explore_article_open, poi_open,
   umkm_listing_view) - satu baris per aksi penting
9. Catatan trust: apa yang curated vs UGC vs menunggu verifikasi

ATURAN MOCK DATA
- Buat SATU universe: minimal 24 lemma kamus, 12 artikel budaya,
  30 POI, 8 destinasi wisata, 10 kuliner, 12 event, 15 UMKM,
  6 profil user (termasuk 2 verifier, 1 guru, 1 pemilik UMKM),
  1 mitra Dinas fiktif, 1 CSR fiktif, 2 sekolah pilot.
- Setiap artikel WAJIB menaut minimal 2 lemma terkait.
- Setiap POI wisata/kuliner/budaya WAJIB bisa ditaut ke 1+ lemma
  atau 1+ artikel.
- Status konten campur: terverifikasi, menunggu, ditolak (untuk
  layar admin/verifier) - proporsi realistis, jangan semua hijau.
- Nama tempat pakai geografi Sambas yang masuk akal (contoh arah:
  Sambas kota, Selakau, Pemangkat, Paloh, Teluk Keramat, Jawai,
  Sajingan - boleh fiktif detail pin, tapi nuansa lokal).
- Lemma contoh campur Sambas ↔ Indonesia (makna, kelas kata, contoh
  kalimat, frasa pengunjung, ada/ tidak ada audio & gambar).
- Untuk gamifikasi: sediakan dataset "future opt-in" terpisah
  (streak, badge bertema Melayu Sambas, leaderboard opt-in) dan
  tandai jelas BELUM default-on.
- Untuk monetisasi: mock paket G1, K1, K2, E1, C1 (isi singkat
  + zona UI tempat atribusi muncul). Paket D1 Year 3+ cukup disebut
  di lampiran, jangan dibuatkan layar user akhir.

FORMAT KELUARAN (wajib urut)
1. Universe summary (1 halaman): brand voice, persona map, data counts
2. Design tokens ringkas (warna status, spacing, tipografi UI)
3. App map / IA (pohon navigasi 4 tab + stack di luar tab)
4. Shared components library (list item kata, kartu artikel, pin POI,
   badge status, tile hub kontribusi, tile listing UMKM)
5. Screen-by-screen spek + mock JSON-like blocks
6. Cross-link matrix: lemma ↔ artikel ↔ place ↔ event ↔ UMKM
7. Partner / monetisasi surfaces (bukan iklan): atribusi,
   campaign inbox, one-pager dampak (boleh format dokumen, bukan app)
8. Global states: empty, offline tipis, error, permission lokasi, guest gate
9. Open questions desain (maks 10) yang perlu keputusan PO

Jika output terlalu panjang: kerjakan per batch sesuai tabel batching
di PLAN_MOCK, tapi jaga universe ID yang sama (pakai slug stabil:
word_id, article_slug, place_slug, umkm_slug, user_handle).

Kualitas > dekorasi. Kami lebih butuh data lengkap dan alur jelas
daripada ilustrasi generik.
```

---

## Section C - Prompt batch (opsional, tempel per sesi)

### C1 - Shell + kamus (V0)

```text
Batch 1 - Shell + Kamus excellence (V0).
Lanjutkan aturan Section A+B. Fokus hanya:
- 4 tab shell (label, ikon Lucide, badge notifikasi)
- Home: brand header, search guest-first, WOTD, kata baru, pintu A-Z
- Hasil search 2 arah + empty search-miss (pintu usul kata)
- Detail kata: makna, kelas, contoh, audio, gambar, vote, bookmark,
  share card, taut "terkait di Explore" (boleh 1-2 chip menuju artikel)
- Daftar A-Z
- Cache offline tipis: indikator "tersedia offline" pada subset lemma
Mock: 24 lemma dengan variasi kelengkapan audio/gambar/contoh.
Sertakan state: loading skeleton, error jaringan, guest vs login.
```

### C2 - Komunitas & kepercayaan

```text
Batch 2 - Kontribusi, kualitas sosial, verifier, profil, notifikasi.
Fokus:
- Hub Kontribusi: usul kata, suggest-edit, vote deck, ruang diskusi,
  terjemahan bantuan (jika ada di produk)
- Form usul + Usulanku (status menunggu / diterima / ditolak)
- Antrean review verifier + quality board (kata tanpa contoh/audio/gambar)
- Komentar + blocklist (tampilkan perilaku: kata tersaring)
- Notifikasi inbox + 1 contoh campaign curated mitra (bukan spam)
- Profil sendiri + profil publik + statistik
- Bookmark, edit profil, hapus akun, laporkan bug (ringkas)
Mock user: 6 profil konsisten. Jangan buat chat sosial bebas.
```

### C3 - Explore budaya (V1)

```text
Batch 3 - Explore Budaya hidup (V1).
Fokus kategori: Bahasa & Budaya, Tradisi & Adat, Sejarah & Tokoh,
Seni & Kerajinan.
- Hub Eksplorasi: kategori hidup vs comingSoon (jangan nyalakan semua)
- List artikel compact + detail artikel (sumber rujukan terlihat)
- Setiap artikel taut ≥2 lemma; chip lemma → detail kata
- Empty curated (belum ada artikel) vs list penuh
Mock: 12 artikel. Cantumkan atribusi editorial (bukan anonym).
```

### C4 - Peta, wisata, kuliner (V2-V3)

```text
Batch 4 - Peta + POI + Wisata & Kuliner (V2-V3).
Fokus:
- Peta & Akses (MapLibre-style): pin kategori wisata/kuliner/budaya
- Detail POI: nama, deskripsi singkat, koordinat teks, lemma terkait,
  artikel terkait; BELUM turn-by-turn
- Kategori Wisata & Kuliner: destinasi + makanan khas first-class
- Frasa berguna untuk pengunjung (taut ke lemma)
- Paket editorial "Akhir pekan di Sambas" (bukan OTA)
Mock: 30 POI, 8 destinasi, 10 kuliner. Sertakan permission lokasi denied.
```

### C5 - Event, kabar tipis, komunitas (V4)

```text
Batch 5 - Event curated + Kabar tipis + Komunitas/relawan (V4).
Fokus:
- Kalender event (festival, pameran, kegiatan warga) - curated
- Detail event + deep link dari notifikasi
- Kabar & Berita: HANYA pengumuman mitra/curated (maks sedikit item);
  jangan desain timeline berita harian
- Pintu relawan / apply verifier (jalur peran, bukan social network)
Mock: 12 event satu musim budaya. Tunjukkan batas frekuensi kabar.
```

### C6 - UMKM (V5)

```text
Batch 6 - UMKM & jasa (V5) impact-first.
Fokus:
- Direktori listing: nama, kategori, lokasi, kontak, jam
- Klaim bisnis (alur pemilik) + badge terverifikasi
- Pin di peta untuk listing terklaim
LARANGAN UI: keranjang, checkout, ongkir, chat wajib, escrow, slot berbayar
Mock: 15 UMKM (listing dasar gratis).
Pisahkan peran "kontributor bisnis" dari "kontributor kamus".
```

### C7 - Edukasi (V6)

```text
Batch 7 - Edukasi pilot sekolah (V6).
Fokus:
- Paket kosakata / wordlist kelas
- Kuis singkat berbasis lemma terverifikasi
- Dashboard guru sederhana (kelas, progres) - tipis
- Onboarding workshop 1 sesi (boleh 1 screen info)
Mock: 2 sekolah pilot, 1 guru, 1 kelas, progres murid ringkas.
Jangan paywall kamus inti untuk murid di luar paket institusi.
```

### C8 - Mitra & monetisasi surfaces

```text
Batch 8 - Permukaan kemitraan (bukan ads).
Fokus UI/app + artefak singkat:
- Halaman Tentang / Dampak: atribusi mitra G1/CSR (zona jelas)
- Console admin tipis: role editor mitra (hanya konten mereka),
  campaign composer, moderasi klaim UMKM, quality board
- Inbox: 1 kampanye C1 curated + opt-out jelas
- One-pager dampak (outline 1 halaman) untuk pitch: WALC, lemma,
  kontributor, artikel/POI, studi kasus
LARANGAN: logo di splash, interstitial, sponsored arti kata,
native ads gelap di Kabar.
Mock paket: G1, K1, K2, E1, C1 (ringkas isi + syarat jual).
```

### C9 - Future gamifikasi + states global

```text
Batch 9 - Gamifikasi future + states global.
Fokus:
- Statistik pribadi (default sekarang) vs streak/XP/badge/leaderboard
  opt-in (tandai FUTURE - hanya setelah ambang komunitas)
- Badge bertema budaya Melayu Sambas (nama + kriteria singkat)
- Leaderboard opt-in (bukan paksa publik)
- Global: empty, offline cache tipis, error, maintenance, force update
  ringkas, guest gate saat aksi tulis
Jaga konsistensi universe dari batch sebelumnya.
```

---

## Section D - Inventaris permukaan wajib

AI harus mengisi spek + mock untuk item berikut (centang saat review).

### D1 - Shell & akun

- [ ] Bottom nav 4 tab + badge unread
- [ ] Onboarding
- [ ] Login / daftar / verifikasi email / lupa password
- [ ] Guest gate (aksi yang memaksa login)
- [ ] Profil sendiri, edit profil, hapus akun
- [ ] Profil publik pengguna
- [ ] Pengaturan tampilan (tema / palet)
- [ ] Laporkan bug

### D2 - Kamus (V0)

- [ ] Home (WOTD, kata baru, search, A-Z entry)
- [ ] Search results 2 arah + search-miss
- [ ] Detail kata (makna, contoh, audio, gambar, status)
- [ ] Share card kata
- [ ] Bookmark list
- [ ] A-Z index
- [ ] Indikator cache offline tipis

### D3 - Kontribusi & kepercayaan

- [ ] Hub Kontribusi
- [ ] Form usul kata / suggest-edit
- [ ] Usulanku (daftar status)
- [ ] Vote + vote deck
- [ ] Ruang Diskusi + komentar (blocklist behavior)
- [ ] Apply verifier + onboarding singkat
- [ ] Antrean review verifier
- [ ] Quality board (lemma kurang contoh/audio/gambar)
- [ ] Notifikasi inbox
- [ ] Campaign push curated (tampilan inbox)

### D4 - Explore (V1-V5)

- [ ] Hub Eksplorasi (kategori live vs comingSoon)
- [ ] Bahasa & Budaya - list + detail artikel
- [ ] Tradisi & Adat
- [ ] Sejarah & Tokoh
- [ ] Seni & Kerajinan
- [ ] Peta & Akses + detail POI
- [ ] Wisata & Kuliner + frasa pengunjung + paket akhir pekan
- [ ] Event & Acara (kalender + detail)
- [ ] Kabar & Berita (tipis, curated only)
- [ ] Komunitas & Relawan (pintu peran)
- [ ] Bisnis & Jasa (direktori + detail listing)
- [ ] Klaim bisnis + badge terverifikasi

### D5 - Edukasi (V6)

- [ ] Daftar paket / wordlist
- [ ] Alur kuis
- [ ] Dashboard guru (kelas + progres)
- [ ] Empty pilot / akses institusi

### D6 - Gamifikasi (future)

- [ ] Statistik pribadi (ship-now)
- [ ] Streak / point / badge / leaderboard opt-in (future flag)

### D7 - Admin / mitra (tipis untuk gambaran)

- [ ] Console: moderasi usulan & listing
- [ ] Console: editor mitra terbatas
- [ ] Console: composer kampanye C1
- [ ] Halaman Tentang / Dampak + atribusi
- [ ] Outline one-pager dampak (dokumen)

### D8 - Dataset counts (minimum)

| Entitas | Minimum |
| ------- | ------- |
| Lemma kamus | 24 |
| Artikel budaya | 12 |
| POI | 30 |
| Destinasi wisata | 8 |
| Entri kuliner | 10 |
| Event | 12 |
| UMKM | 15 |
| User contoh | 6 |
| Sekolah pilot | 2 |
| Mitra (dinas/CSR) | 2 |
| Cross-link lemma↔artikel↔place | matrix lengkap |

---

## Section E - Checklist kualitas hasil AI

Sebelum memakai output untuk Figma / prototype / pitch:

- [ ] Satu universe: slug/nama tidak bentrok antar batch
- [ ] Tidak ada em/en dash di copy
- [ ] Status Terverifikasi / Menunggu konsisten di kamus & UGC
- [ ] Artikel punya sumber + taut lemma
- [ ] POI punya kategori + taut konten
- [ ] Kabar tidak berubah jadi timeline berita
- [ ] UMKM tanpa checkout/keranjang
- [ ] Atribusi mitra tidak muncul di hasil search kata
- [ ] Highlight UMKM proporsi kecil (terasa eksklusif, bukan spam)
- [ ] Guest bisa baca kamus/explore curated; aksi tulis kena gate
- [ ] Setiap layar punya empty + error + loading
- [ ] Anti-goal tidak digambar sebagai fitur aktif
- [ ] Event analytics disebut untuk permukaan Explore/UMKM/POI
- [ ] Nada lokal Sambas; bukan portal wisata nasional generik

---

## Section F - Skema mock data (kontrak ringan untuk AI)

Pakai bentuk JSON-like di output. Field boleh ditambah; yang di bawah
wajib ada agar cross-link jalan.

```text
Word {
  id, lemma_sambas, lemma_id, word_class, gloss,
  example_sentence, has_audio, has_image,
  status: verified|pending|rejected,
  related_article_slugs[], related_place_slugs[]
}

Article {
  slug, title, category: bahasa_budaya|tradisi|sejarah|seni|kuliner,
  excerpt, body_summary, source_attribution,
  related_word_ids[], cover_image_label,
  status: published|draft
}

Place {
  slug, name, category: wisata|kuliner|budaya|akses|umkm,
  lat, lng, short_description,
  related_word_ids[], related_article_slugs[],
  hours?, contact?
}

Event {
  slug, title, start_date, end_date, place_slug?,
  summary, is_partner_announcement: false
}

Announcement {  // Kabar tipis
  slug, title, body, partner_name, published_at
}

UmkmListing {
  slug, business_name, category, place_slug?,
  claim_status: unclaimed|pending|verified,
  contact, hours
}

User {
  handle, display_name, role: user|verifier|teacher|business|admin_partner,
  stats: { contributions, verifications, bookmarks },
  school_id?
}

PartnerPackageMock {
  code: G1|K1|K2|E1|C1,
  buyer_type, includes[], ui_surfaces[], attribution_zone,
  not_allowed_surfaces[]
}
```

---

## Section G - Prompt satu tempelan (all-in, jika model kuat)

Jika model punya konteks panjang, tempel **Section A + Section B** lalu
lanjutan ini:

```text
Kerjakan SEMUA batch C1-C9 dalam satu jawaban terstruktur, dengan
universe data tunggal dan inventaris Section D terpenuhi. Mulai dari
Universe summary + App map, lalu screen-by-screen. Akhiri dengan
cross-link matrix dan open questions. Jika mendekati batas panjang,
selesaikan dulu dataset + IA + komponen bersama, lalu lanjut spek
layar per batch dengan heading jelas tanpa mengulang aturan.
```

---

## Section H - Contoh cuplikan universe (seed, boleh diganti AI)

Seed agar AI tidak mulai dari nol generik. AI boleh ekspansi, jangan
hapus nuansa lokal.

```text
Lemma seed: kecap (ucap), ngucap, kedayan (arah makna lokal sesuai
riset singkat AI - tandai jika unsure), sambal, bubur pedas,
pengantin, pantun, tarik suara, kedai kopi, perahu.
(AI: lengkapi 24 lemma utuh dengan makna + contoh; koreksi jika
seed kurang tepat secara bahasa - utamakan konsistensi internal.)

Artikel seed titles:
- Bubur pedas dalam kenduri Sambas
- Pantun muda di majlis
- Jejak bandar lama di tepi sungai
- Kerajinan anyaman untuk hantaran

POI seed:
- Alun-alur / titik akses sungai (fiktif pin)
- Warung bubur pedas "Mak Rohani" (fiktif)
- Situs budaya / masjid bersejarah (nama generik lokal, bukan klaim palsu)

Mitra seed:
- Dinas Pariwisata Kabupaten Sambas (fiktif MoU uji)
- CSR "Literasi Nusantara" (fiktif) untuk paket G1

Sekolah seed:
- SMAN Pilot Sambas
- Sanggar Bahasa Selakau
```

Catatan etika mock: jangan meniru bisnis/orang nyata secara menyesatkan;
pakai nama fiktif yang terasa lokal. Jangan klaim endorsement pejabat.

---

## Section I - Changelog

| Tanggal | Keputusan |
| ------- | --------- |
| 2026-09-28 | Adopsi awal prompt UI/UX + inventaris mock penuh dari ROADMAP + MONETIZE |
```

Saya juga akan menambahkan referensi silang di tabel dokumen terkait pada roadmap dan monetize agar `PLAN_MOCK.md` mudah ditemukan.