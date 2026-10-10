# ROADMAP PLAN - SambasKu

Dokumen strategi produk kanonik (horizon **8 kuartal + Year 3+**).
Diperbarui sebagai kompas growth: dari kamus kolaboratif menuju
**rumah digital bahasa dan budaya hidup Sambas**.

| Dokumen | Peran |
| ------- | ----- |
| **Ini** (`ROADMAP_PLAN.md`) | Strategi produk, urutan vertikal, gate, bisnis |
| [`MONETIZE_PLAN.md`](./MONETIZE_PLAN.md) | Jalur kemitraan / grant / B2B / listing (impact-first) |
| [`PLAN_MOCK.md`](./PLAN_MOCK.md) | Prompt UI/UX + mock data penuh (gambaran produk utuh) |
| [`PLAN_STACK_FIX.md`](./PLAN_STACK_FIX.md) | Maturity keamanan/kualitas + evidence pack mitra |
| [`backlogs/NEXT.md`](./backlogs/NEXT.md) | Slice engineering near-term (nilai ÷ usaha) |
| [`DESC.md`](./DESC.md) | Store listing / positioning publik hari ini |
| [`UI.md`](./UI.md) | Shell navigasi + prinsip desain mobile |
| [`GAMIFIKASI_CONCEPT.md`](./GAMIFIKASI_CONCEPT.md) | Konsep streak / point / badge (belum full ship) |
| [`reference/`](../reference/README.md) | Pipeline editorial: dokumen → artikel → data di apps |

Roadmap **tidak** mengganti `NEXT.md`. Setiap kuartal, PO memecah fase
aktif di sini menjadi item konkrit di backlog.

---

## 1. Ringkasan eksekutif

**North star:** SambasKu adalah tempat orang menemukan, memakai, dan
ikut merawat bahasa Melayu Sambas beserta konteks hidupnya - tradisi,
tempat, kuliner, tokoh, dan komunitas - dalam satu produk yang
terpercaya.

**Thesis growth:** Kamus kolaboratif adalah *trust center*. Tanpa
kepercayaan pada makna, pelafalan, dan moderasi, ekspansi ke wisata
atau UMKM akan terasa seperti portal daerah generik. Dengan kepercayaan
itu, tab Eksplorasi (sudah di-scaffold di mobile) menjadi jalur natural
ke budaya, peta, wisata, event, dan ekonomi lokal ringan - tanpa
meninggalkan identitas kamus.

**Monetisasi:** impact-first. Inti produk tetap gratis. Sustainability
dibangun belakangan lewat kemitraan (Pemkab / Dinas / sekolah) dan grant
budaya - bukan iklan interruptive, bukan marketplace transaksi penuh di
tahun 1-2.

**Geografi:** Sambas-first sebagai brand. Pola teknis boleh reusable;
jangan pecah fokus ke dialek daerah lain sebelum vertikal Explore
Sambas hidup dan unit ekonomi editorial terbukti.

---

## 2. Posisi hari ini (fondasi, bukan asumsiku)

### 2.1 Yang sudah menjadi produk nyata

| Pillar | Bukti |
| ------ | ----- |
| Kamus Sambas ↔ Indonesia | Pencarian 2 arah, detail, A-Z, WOTD, gambar, pelafalan (skema siap) |
| Loop kontribusi | Usul kata, suggest-edit, search-miss, approval gate, Usulanku |
| Kualitas sosial | Vote, vote deck, komentar + blocklist, Ruang Diskusi |
| Kepercayaan & peran | Verifier application, antrean review, audit, console admin |
| Retensi ringan | Bookmark, notifikasi inbox + campaign/push infra, share card |
| Identitas sosial | Profil publik + statistik |
| Shell ekspansi | Tab Eksplorasi: Bahasa & Budaya + Peta & Akses **live**; 8 kategori lain `comingSoon` |

Sumber arah near-term engineering: [`backlogs/NEXT.md`](./backlogs/NEXT.md).

### 2.2 Yang masih scaffolding / ditunda

- Konten API di balik kartu Wisata, UMKM, Event, Kabar, Sejarah, Seni,
  Tradisi, Komunitas (UI ada, data belum)
- Gamifikasi penuh (streak / XP / badge / leaderboard UI) - kontrak
  skor ada; eksekusi tunggu volume kontributor
- Pipeline `reference/` → artikel produksi (semua sample masih unchecked)
- Offline penuh kamus; cache tipis lebih dulu
- Multi-dialek di luar Sambas
- Monetisasi / kemitraan terdokumentasi (belum ada model bisnis di repo)

### 2.3 Implikasi PO

Kita **bukan** memulai dari nol untuk "jadi lebih dari kamus". Shell
Explore dan alur editorial sudah menunjuk arah *living culture hub*.
Pekerjaan strategis adalah mengisi vertikal dengan urutan yang menjaga
kepercayaan kamus, bukan membuka semua kartu sekaligus.

---

## 3. Masalah yang kita selesaikan

1. **Bahasa tergerus tanpa rumah digital** - penutur, anak muda, dan
   diaspora butuh kamus yang hidup (makna + contoh + suara + koreksi
   komunitas), bukan PDF statis.
2. **Budaya terpisah dari kosakata** - tradisi, legenda, kuliner, dan
   tokoh ada di dokumen terpisah; di produk belum terhubung ke lemma.
3. **Discovery tempat lemah** - peta sudah ada sebagai shell; belum
   jadi lapisan tempat (POI) yang bisa dijelajahi dan dikaitkan ke kata.
4. **Partisipasi warga sulit diukur** - kontribusi ada, tetapi reputasi
   dan "kerja berikutnya" (quality queue, gamifikasi) belum menutup
   loop motivasi jangka panjang.
5. **Ekonomi lokal dan edukasi belum punya pintu digital terpercaya** -
   UMKM dan sekolah butuh kanal yang tidak terasa spam, berakar pada
   identitas Sambas.

---

## 4. Personas dan jobs-to-be-done

| Persona | Job utama | Sukses terlihat jika |
| ------- | --------- | -------------------- |
| Penutur / warga Sambas | Cari makna, usul perbaikan, dengar pelafalan | Lookup cepat; usulan selesai ditindak |
| Diaspora | Tetap dekat dengan bahasa & kampung | Share card, artikel budaya, WOTD |
| Pelajar / guru | Belajar kosakata & konteks budaya | Paket materi, kuis, rujukan terverifikasi |
| Wisatawan / kerabat berkunjung | Pahami kata lokal + tempat / kuliner | POI + entri kuliner + frasa berguna |
| Pelaku UMKM | Tampil di direktori lokal terpercaya | Listing jelas, klaim bisnis, tanpa transaksi rumit |
| Verifikator / relawan | Jaga kualitas data | Antrean jelas, badge/reputasi, beban moderasi terkendali |
| Admin / mitra Pemkab | Konten resmi & kampanye | Console + campaign + metrik dampak |

---

## 5. Metrik

### 5.1 North star metric

**Weekly Active Learners & Contributors (WALC):** pengguna unik per
minggu yang melakukan **minimal satu** dari: (a) buka ≥3 detail kata
berbeda, (b) putar pelafalan, (c) aksi kontribusi/verifikasi/bantuan
terjemahan, (d) buka konten Explore non-kamus (artikel / POI / wisata).

Ini menggabungkan *pemakaian kamus* dan *perluasan living culture*,
tanpa mengunci hanya MAU vanity.

### 5.2 Supporting metrics

| Lapisan | Metrik | Catatan |
| ------- | ------ | ------- |
| Kamus | Lemma terverifikasi; % kata dengan contoh / audio / gambar | Kualitas > quantity mentah |
| Komunitas | Kontributor aktif 30 hari; median waktu review; verifier aktif | Kesehatan loop |
| Explore | Sesi Explore / MAU; artikel dibaca; POI dibuka | Bukti ekspansi di luar lookup |
| Retensi | D1 / D7 / D30; streak lanjut (setelah gamifikasi) | Jangan kejar install kosong |
| Distribusi | Share card terkirim; deep link open | Growth organik |
| Bisnis | Kemitraan aktif; pilot sekolah | Sustainability |

### 5.3 Analytics

Firebase Analytics (GA4) sudah menjadi jalur produk di mobile base
stack. Setiap vertikal baru wajib punya event bernama jelas
(contoh: `explore_article_open`, `poi_open`, `umkm_listing_view`)
sebelum dianggap "shipped" untuk keputusan gate.

---

## 6. Prinsip produk

1. **Kamus adalah kepercayaan.** Fitur baru tidak boleh merusak akurasi,
   moderasi, atau kejelasan status "terverifikasi" vs "menunggu".
2. **Curated dulu, UGC belakangan** pada vertikal non-kamus. Artikel
   budaya dan POI awal dari editorial / mitra; baru buka usulan warga
   setelah alat moderasi siap.
3. **Satu identitas Sambas.** Copy lokal, bukan portal nasional generik.
   Hindari feed berita tanpa editor.
4. **Guest-first untuk baca; login untuk ikut membangun.** Selaras UI
   hari ini.
5. **Satu pekerjaan per permukaan.** Explore bukan dashboard padat;
   tiap kategori punya tujuan tunggal.
6. **Gate sebelum scope creep.** Vertikal berikutnya hanya dibuka jika
   gate kuartal terpenuhi (Section 11).
7. **Anti-goal eksplisit** lebih penting daripada daftar fitur panjang
   (Section 7.8).

---

## 7. Peta vertikal (urutan ekspansi)

Urutan = prioritas produk. Bukan semua dikerjakan paralel.

### V0 - Kamus excellence (selalu hidup)

Fondasi yang terus diperkeras setiap kuartal.

- Audio pelafalan penutur asli (prioritas NEXT)
- Papan kualitas data admin (kata tanpa contoh / audio / gambar)
- Discovery Home (WOTD, kata baru, bukan hanya search-miss)
- Cache offline tipis; normalisasi pencarian dialek
- Polish loop kontribusi (anti double-submit, navigasi, draft)

Tanpa V0 yang sehat, V1+ hanya dekorasi.

### V1 - Budaya hidup (artikel + taut lemma)

Mengaktifkan kategori Tradisi & Adat, Sejarah & Tokoh, Seni & Kerajinan,
dan memperdalam Bahasa & Budaya.

- Pipeline `reference/` → artikel terkurasi di apps
- Setiap artikel menaut **lemma kamus** terkait (kosakata dalam konteks)
- Sumber rujukan terlihat (bukan konten anonym tanpa atribusi)

### V2 - Peta + POI

Memperkaya Peta & Akses yang sudah live (MapLibre).

- Entity Place / POI (nama, koordinat, kategori, deskripsi singkat)
- Pin wisata, kuliner, situs budaya; tap → detail + lemma terkait
- Belum perlu navigasi turn-by-turn; fokus discovery

### V3 - Wisata & kuliner

Mengisi kartu Wisata & Kuliner.

- Destinasi dan makanan khas sebagai konten first-class
- Frasa / kosakata berguna untuk pengunjung
- Paket "akhir pekan di Sambas" ringan (editorial), bukan OTA

### V4 - Komunitas & event

Mengisi Event & Acara + Komunitas & Relawan.

- Kalender curated (festival, pameran, kegiatan warga)
- Pintu relawan / verifier sebagai jalur peran, bukan social network
- **Kabar & Berita:** sangat tipis - hanya pengumuman curated / mitra;
  bukan timeline berita harian

### V5 - UMKM & jasa

Mengisi Bisnis & Jasa.

- Direktori listing (nama, kategori, lokasi, kontak, jam)
- Klaim bisnis oleh pemilik (verifikasi manual / mitra)
- Tanpa slot berbayar; **tanpa** keranjang belanja / escrow di fase ini

### V6 - Edukasi

- Paket kosakata untuk sekolah / sanggar
- Kuis singkat berbasis lemma terverifikasi
- Dashboard guru sederhana (kelas, progres) pada pilot terbatas

### 7.8 Later / anti-goal (sengaja tidak dikerjakan dulu)

| Anti-goal | Alasan |
| --------- | ------ |
| Feed berita generik tanpa editor | Merusak brand; beban moderasi meledak |
| Marketplace transaksi penuh (order, bayar, ongkir) | Di luar kompetensi; regulasi & support berat |
| Iklan interruptive / interstitial | Merusak kepercayaan kamus komunitas |
| Multi-dialek daerah lain sebagai satu app | Dilusi brand SambasKu; tunggu pola + ekonomi editorial |
| Social network / chat bebas | Translation help + komentar sudah menutup kebutuhan skala kini |
| Offline full pack sebelum cache tipis stabil | Berat; urutan di NEXT / PLAN_LOCAL_DB |
| Gamifikasi penuh sebelum volume kontributor nyata | Metrik kosong; lihat Section 8 |

---

## 8. Flywheel komunitas

```text
Lookup & Explore berguna
        ↓
Usul / vote / bantu terjemah / lengkapi data
        ↓
Review verifier + status jelas (inbox)
        ↓
Reputasi profil (+ badge saat volume cukup)
        ↓
Konten kamus & budaya makin kaya
        ↓
Lebih banyak pengguna & mitra
```

### Kapan gamifikasi / leaderboard diaktifkan

Selaras [`GAMIFIKASI_CONCEPT.md`](./GAMIFIKASI_CONCEPT.md) dan penundaan
di `NEXT.md`:

**Ambang minimum (contoh operasional):**

- ≥ 50 kontributor unik dengan ≥1 usulan terverifikasi dalam 90 hari, **atau**
- ≥ 200 aksi kontribusi/verifikasi/ruang diskusi per bulan selama
  2 bulan berturut-turut

Baru setelah itu: streak (aksi nyata saja), point dari vote pada karya
yang lolos, badge bertema budaya Melayu Sambas, leaderboard opt-in.

Sebelum ambang: statistik pribadi + profil publik cukup.

### Peran verifier

Verifier adalah aset produk, bukan biaya tersembunyi. Roadmap menjaga:

- Antrean kerja jelas (termasuk quality board)
- Jalur apply + onboarding singkat
- Badge / pengakuan publik setelah gamifikasi hidup
- Batas beban (SLA review) agar tidak burnout

---

## 9. Model bisnis bertahap (impact-first)

| Fase | Sumber sustainability | Syarat |
| ---- | --------------------- | ------ |
| Sekarang - Q4 | Operasional lean; fokus dampak & retensi | Produk dipercaya |
| Grant / CSR / lembaga bahasa | Hibah pelestarian budaya & literasi | Narasi dampak + metrik WALC |
| Kemitraan Pemkab / Dinas Pariwisata | Konten resmi, event, POI, kampanye notifikasi | MoU + peran editor mitra |
| Pilot sekolah (B2B ringan) | Paket edukasi berbayar institusi | V6 MVP + 1-2 sekolah uji |
| Open data / API terbatas (Year 3+) | Lisensi data untuk peneliti / mitra | Kebijakan lisensi jelas |

**Tidak dilakukan di horizon ini:** paywall kamus inti, ads penuh layar,
komisi transaksi marketplace.

Keputusan bisnis tiap tahun ditulis ulang di Section 10 setelah review
kuartalan (metrik + pipeline kemitraan nyata, bukan asumsi slide deck).

---

## 10. Roadmap waktu

Horizon dimulai dari **kuartal berikutnya setelah dokumen ini diadopsi**
(bukan tanggal kalender kaku). Sesuaikan label Q1..Q8 di review PO.

### Q1 - Q2: Perkeras kamus + pipeline editorial

**Produk**

- Selesaikan prioritas NEXT yang menutup loop: audio penutur, quality
  board, polish submit, discovery Home
- Cache tipis mobile/web sesuai backlog cache
- 10-20 artikel budaya MVP dari `reference/` (Tradisi / Sejarah /
  Kuliner terpilih), siap masuk apps

**Komunitas**

- Ukur kontributor aktif & waktu review sebagai baseline gate
- Verifier onboarding singkat (checklist, bukan kursus panjang)

**Bisnis**

- One-pager dampak untuk calon mitra / grant (pakai metrik Section 5)
- Listing UMKM tidak dijual (keputusan 2026-10-03)

**Gate keluar Q2:** audio flow production-ready; ≥10 artikel siap tayang;
baseline metrik komunitas tercatat.

### Q3 - Q4: Budaya live + POI di peta

**Produk**

- V1 live di Explore (artikel + taut lemma)
- V2: POI awal (wisata/budaya/kuliner) di peta yang sudah ada
- i18n mobile `id` / `id_SBS` mulai dieksekusi jika belum (kontrak sudah ada)

**Komunitas**

- Evaluasi ambang gamifikasi; jika terpenuhi → streak + badge tipis
- Jika belum → tahan leaderboard; perkuat quality queue saja

**Bisnis**

- Uji 1 kemitraan konten (Dinas / komunitas budaya / kampus lokal)

**Gate keluar Q4:** Explore non-kamus ≥ X% dari sesi aktif (tetapkan X
di review; target awal 15%); ≥30 POI berkualitas; kemitraan ujicoba
berjalan atau post-mortem jelas.

### Q5 - Q6: Wisata/kuliner + event curated + edukasi pilot

**Produk**

- V3 Wisata & Kuliner sebagai kategori penuh
- V4 Event curated (kalender); Kabar hanya pengumuman mitra
- V6 pilot: paket kosakata + kuis untuk 1-2 sekolah / sanggar

**Komunitas**

- Relawan event / dokumentasi budaya (bukan chat sosial)
- Gamifikasi lengkap hanya jika ambang Section 8 sudah lewat

**Bisnis**

- Perpanjang kemitraan pariwisata/budaya
- Proposal paket sekolah (harga institusi sederhana)

**Gate keluar Q6:** retensi D30 tidak turun setelah ekspansi Explore;
pilot edukasi selesai dengan feedback guru; event calendar terisi
minimal satu musim budaya.

### Q7 - Q8: Playbook sustainability + direktori UMKM

**Produk**

- V5 Direktori UMKM + klaim bisnis + moderasi
- Hardening: roles editor konten, audit listing, analytics per vertikal

**Komunitas**

- Jalur "kontributor bisnis" terpisah dari kontributor kamus (izin &
  tanggung jawab beda)

**Bisnis**

- Tulis playbook sustainability (grant + kemitraan + sekolah)
- Evaluasi: apakah pola platform layak diangkat ke produk saudara
  daerah lain di Year 3+ (keputusan go / no-go)

**Gate keluar Q8:** ≥N listing aktif (N ditetapkan dari kapasitas
moderasi); unit ekonomi editorial tidak kolaps.

### Year 3+ (arah, bukan komitmen spek)

- Deep edukasi (kelas, progres, sertifikat ringan)
- Fitur diaspora (koleksi pribadi, reminder bahasa, komunitas jarak jauh)
- Open data / API publik terbatas dengan lisensi
- Pola white-label / produk saudara untuk daerah lain **hanya jika**
  Q8 go-decision positif
- Evaluasi ulang anti-goal (marketplace, multi-dialek in-app) dengan
  data, bukan hype

---

## 11. Gate dan kill criteria

Sebelum membuka vertikal berikutnya, PO meninjau:

| Dari → Ke | Harus benar | Kill / tunda jika |
| --------- | ----------- | ----------------- |
| V0 → V1 | Loop kontribusi stabil; artikel MVP siap | Review backlog menumpuk; kualitas lemma buruk |
| V1 → V2 | Artikel dibaca (bukan hanya published); taut lemma dipakai | Artikel tanpa engagement 60 hari |
| V2 → V3 | POI akurat; peta tidak kosong | Data lokasi salah / tidak terawat |
| V3 → V4 | Wisata/kuliner dipakai di sesi Explore | Konten wisata jadi sampah SEO |
| V4 → V5 | Event curated jalan 1 musim; moderasi kuat | Tim tenggelam di "kabar" |
| → multi-daerah | Playbook Q8 go | Brand Sambas masih lemah di luar Sambas |

**Kill criteria global:** jika WALC stagnan 2 kuartal **dan** kontributor
aktif turun, hentikan ekspansi vertikal baru; kembali ke V0 + retensi.

---

## 12. Implikasi teknis tinggi (bukan kontrak API)

Detail endpoint ditulis dokumen follow-up di `docs/api/` saat fase aktif.
Di tingkat roadmap, siapkan arah berikut:

| Kebutuhan | Arah |
| --------- | ---- |
| Konten Explore | CMS / tabel artikel + status publish; editor role di console |
| Place / POI | Entity geo (lat/lng, kategori, slug); taut ke word_id / article_id |
| Graph ringan | Relasi word ↔ article ↔ place (bukan knowledge-graph berat) |
| Moderasi | Perluas pola approval kamus ke listing & POI usulan |
| Media | Teruskan pola CDN (images/audios) + ImageKit di mana sudah ada |
| Analytics | Event per vertikal di GA4 sebelum keputusan gate |
| i18n | `id` + `id_SBS` sesuai kontrak mobile/web i18n |
| Offline | Cache tipis dulu; full pack belakangan |

Jangan menyalakan semua kategori Explore ke API kosong. Lebih baik
sedikit kategori hidup dengan konten padat.

---

## 13. Risiko dan mitigasi

| Risiko | Mitigasi |
| ------ | -------- |
| Scope creep jadi portal daerah | Anti-goal + gate kuartalan; Kabar tetap tipis |
| Kualitas UGC runtuh | Curated-first; UGC hanya setelah tool moderasi |
| Verifier burnout | Quality board prioritas; batasi antrean; badge/pengakuan |
| Kemitraan lambat / politik | Produk tetap berguna tanpa mitra; grant sebagai paralel |
| Dilusi brand kamus | Store listing tetap jujur soal kamus; Explore sebagai perluasan |
| Engineering tersebar | `NEXT.md` hanya ambil slice fase aktif roadmap |
| Monetisasi terlalu cepat | Melarang paywall kamus & ads interruptive di horizon ini |

---

## 14. Cara memakai dokumen ini

1. **PO (tiap kuartal):** review metrik Section 5, status gate Section 11,
   sesuaikan label Q aktif, catat keputusan di changelog singkat di bawah.
2. **Engineering:** jangan implement vertikal di luar fase aktif tanpa
   lolos gate. Pecah pekerjaan ke [`backlogs/NEXT.md`](./backlogs/NEXT.md)
   + kontrak API.
3. **Editorial:** isi [`reference/`](../reference/README.md) → artikel;
   centang item yang sudah masuk produksi.
4. **Desain:** ikuti [`UI.md`](./UI.md); kategori Explore yang belum
   fase aktif boleh tetap `comingSoon`.
5. **Bisnis / kemitraan:** pakai Section 9-10 sebagai arah; detail paket
   & kapan boleh invoice di [`MONETIZE_PLAN.md`](./MONETIZE_PLAN.md).
   Jangan janjikan marketplace atau multi-daerah sebelum gate.

### Changelog keputusan

| Tanggal | Keputusan |
| ------- | --------- |
| 2026-09-28 | Adopsi awal: north star living culture; impact-first; Sambas-first; urutan V0→V6 seperti di atas |

---

## 15. Ringkas satu halaman (untuk tempel brief)

- **Apa:** Rumah digital bahasa + budaya hidup Sambas; kamus = kepercayaan.
- **Bukan:** Portal berita, marketplace, atau iklan-first.
- **Urutan:** Kamus excellence → artikel budaya → POI → wisata/kuliner →
  event/relawan → UMKM → edukasi.
- **Komunitas:** Kontribusi + verifier dulu; gamifikasi setelah volume nyata.
- **Uang:** Grant/kemitraan/sekolah/listing ringan - setelah utilisasi.
- **Disiplin:** Gate kuartalan; `NEXT.md` untuk eksekusi; anti-goal dijaga.
