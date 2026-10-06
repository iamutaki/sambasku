# MONETIZE PLAN - SambasKu

Dokumen sustainability & monetisasi kanonik. Menjawab: **apakah ada
potensi dimonetisasi lewat kemitraan atau sejenisnya?** Ya - dengan
syarat urutan dan batas yang selaras
[`ROADMAP_PLAN.md`](./ROADMAP_PLAN.md).

| Dokumen | Peran |
| ------- | ----- |
| [`ROADMAP_PLAN.md`](./ROADMAP_PLAN.md) | Strategi produk, vertikal, gate |
| **Ini** (`MONETIZE_PLAN.md`) | Jalur uang / kemitraan, paket, harga arah, kapan boleh jual |
| [`PLAN_MOCK.md`](./PLAN_MOCK.md) | Prompt UI/UX + mock data penuh (termasuk permukaan mitra) |
| [`PLAN_STACK_FIX.md`](./PLAN_STACK_FIX.md) | Evidence pack & maturity (prasyarat soft MoU A/B) |
| [`DESC.md`](./DESC.md) | Positioning publik (tetap kamus, jujur) |
| [`backlogs/NEXT.md`](./backlogs/NEXT.md) | Eksekusi engineering near-term |

**Prinsip induk (tidak diganggu dokumen ini):** impact-first. Kamus inti
gratis. Bukan ads-first. Bukan marketplace transaksi penuh di horizon
Q1-Q8.

---

## 1. Jawaban singkat untuk PO / founder

**Ya, potensi monetisasi ada**, terutama lewat **kemitraan & B2B
ringan**, bukan lewat paywall pengguna akhir.

Alasan berdasar roadmap:

1. Produk punya *trust center* (kamus + moderasi + verifier) yang sulit
   diganti portal generik - mitra pemerintah / budaya membayar untuk
   **kanal terpercaya**, bukan untuk "app baru".
2. Shell Explore sudah menunjuk vertikal yang mitra kenal: budaya,
   wisata, peta, event, UMKM, edukasi.
3. Infrastruktur campaign notifikasi + console admin sudah ada - cocok
   untuk **paket distribusi konten resmi**, bukan invent fitur jualan
   dari nol.
4. Pipeline `reference/` → artikel memberi narasi grant/CSR yang kuat
   (pelestarian bahasa & budaya).

**Yang belum:** volume utilisasi Explore & listing organik. Jual terlalu
cepat = spam branding dan merusak kepercayaan. Listing berbayar UMKM
dihapus dari rencana (2026-10-03) agar selaras dengan janji pencantuman
gratis.

---

## 2. Apa yang boleh dijual vs yang tidak

### 2.1 Boleh (selaras roadmap)

| Jalur | Bentuk uang / nilai | Pembeli tipikal |
| ----- | ------------------- | --------------- |
| A. Grant / hibah / CSR | Dana proyek, bukan "iklan" | Lembaga bahasa, CSR BUMN/swasta, yayasan budaya |
| B. Kemitraan Pemkab / Dinas | MoU + fee operasional / sponsorship konten | Pemkab, Dispar, Disdikbud, kominfo daerah |
| C. Paket edukasi B2B | Langganan institusi / paket musim | Sekolah, sanggar, kampus lokal |
| E. Kampanye notifikasi curated | Fee per kampanye (batas frekuensi) | Mitra resmi yang sudah MoU |
| F. Open data / API terbatas (Year 3+) | Lisensi data peneliti / mitra | Kampus, peneliti, lembaga |

### 2.2 Tidak boleh (anti-goal monetisasi)

| Larangan | Alasan |
| -------- | ------ |
| Paywall makna / pencarian kamus inti | Merusak misi & store positioning |
| Interstitial / banner iklan acak | Merusak trust center |
| Komisi order / escrow / marketplace penuh | Di luar kompetensi & support |
| Jual data pribadi pengguna | Etika + regulasi; brand komunitas |
| Sponsored "arti kata" palsu | Korupsi editorial; fatal |
| Kabar berbayar tanpa editor (native ads gelap) | Scope creep portal + distrust |
| Slot berbayar UMKM (klaim/highlight) | Kontradiksi dengan janji pencantuman gratis di profil sponsor |

---

## 3. Peta pembeli (siapa bayar untuk apa)

### 3.1 Pemerintah daerah & dinas

| Kebutuhan mitra | Yang SambasKu jual | Vertikal roadmap |
| --------------- | ------------------ | ---------------- |
| Literasi bahasa daerah | Modul kamus + kampanye kosakata | V0 + campaign |
| Promosi wisata & kuliner | POI, artikel, highlight destinasi | V2, V3 |
| Kalender budaya / event | Event curated + notifikasi | V4 |
| Identitas daerah digital | Branding konten resmi di Explore | V1-V4 |

**Bentuk kontrak tipikal:** MoU 6-12 bulan + biaya operasional konten
(bukan "beli unduhan"). Mitra dapat peran **editor terbatas** di
console (konten mereka), bukan akses root.

**Prasyarat soft teknis:** sebelum MoU konten resmi, siapkan evidence
pack dari [`PLAN_STACK_FIX.md`](./PLAN_STACK_FIX.md) (Security Overview,
status remediasi, penanganan data). Bukan sertifikat ISO; cukup bukti
yang bisa diaudit.

### 3.2 Lembaga bahasa / pendidikan / hibah

| Kebutuhan | Paket |
| --------- | ----- |
| Pelestarian leksikon | Sponsor quality board + audio penutur + laporan lemma baru |
| Penelitian / open knowledge | Akses dataset terbatas + atribusi (Year 3+) |
| Program sekolah | V6 paket kelas (lihat 3.4) |

### 3.3 CSR perusahaan

Cocok jika CSR punya tema: literasi, budaya lokal, UMKM, pariwisata
berkelanjutan. SambasKu menjual **dampak terukur** (WALC, lemma
terverifikasi, artikel, POI, jangkauan kampanye) - bukan logo di splash
screen.

### 3.4 Sekolah / sanggar / kampus (B2B)

Setelah V6 pilot (roadmap Q5-Q6):

- Paket kosakata kurikulum singkat
- Kuis berbasis lemma terverifikasi
- Laporan progres kelas (sederhana)
- Workshop guru 1x per musim (opsional, jasa)

Harga: **per institusi / semester**, bukan per murid dulu (operasional
lebih ringan).

### 3.5 UMKM & jasa lokal

Pelaku UMKM tetap bisa masuk direktori V5 secara gratis. Tidak ada
paket berbayar untuk klaim atau highlight.

Bukan: keranjang, ongkir, chat in-app wajib.

### 3.6 Diaspora & pengguna akhir

**Tidak ada monetisasi agresif.** Donasi sukarela / "dukung pemeliharaan"
boleh dipertimbangkan Year 3+ jika komunitas meminta; bukan prioritas
Q1-Q8.

---

## 4. Paket produk kemitraan (katalog arah)

Nama paket boleh berubah; inti nilai jangan.

### Paket G1 - Dampak bahasa (grant / CSR)

**Isi:** laporan bulanan lemma baru + audio + kontributor; 1-2 kampanye
notifikasi edukatif per kuartal; atribusi mitra di halaman Tentang /
laporan dampak (bukan di hasil pencarian kata).

**Syarat jual:** baseline metrik komunitas tercatat (gate Q2 roadmap).

**Arah harga (indikatif, bukan komitmen):** setara biaya operasional
konten + infrastruktur 3-6 bulan. Negosiasi per proposal hibah.

### Paket K1 - Destinasi & budaya (Dinas / Dispar)

**Isi:** N POI resmi + M artikel wisata/budaya + 1 kalender musim event
+ 1-2 push kampanye (via fitur campaign yang sudah ada).

**Syarat jual:** V1-V2 live; uji kemitraan konten Q3-Q4 selesai atau
berjalan.

**Arah harga:** fee setup + retainer bulanan editorial (mitra atau tim
SambasKu yang menulis).

### Paket K2 - Literasi dinas pendidikan / kominfo

**Isi:** kampanye kosakata mingguan, materi share card resmi, pelatihan
verifier guru/relawan.

**Syarat:** V0 audio + share card stabil; verifier onboarding siap.

### Paket E1 - Sekolah (B2B)

**Isi:** akses paket kuis + wordlist kelas + dashboard guru tipis +
dukungan onboarding 1 sesi.

**Syarat:** pilot Q5-Q6 selesai dengan feedback positif.

**Arah harga:** per sekolah / semester (murah dulu untuk adopsi), naik
setelah bukti retensi kelas.

### Paket C1 - Kampanye notifikasi mitra

**Isi:** 1 kampanye terkurasi (judul, body, deep link ke artikel/POI/
event resmi).

**Batas:** frekuensi ketat (contoh maks 2/bulan total mitra) agar tidak
jadi spam push. Hanya mitra MoU.

**Syarat:** inbox + device push sudah terpakai sehat; opt-out jelas.

### Paket D1 - Data / API (Year 3+)

**Isi:** dump leksikon terverifikasi atau API read-only terbatas +
lisensi.

**Syarat:** kebijakan lisensi + rate limit + larangan resell tanpa
atribusi.

---

## 5. Kapan boleh mulai jual (selaras gate roadmap)

| Kapan | Boleh | Belum boleh |
| ----- | ----- | ----------- |
| Sekarang - Q2 | One-pager dampak; pipeline grant; percakapan mitra tanpa invoice listing | Slot berbayar UMKM; ads |
| Q3 - Q4 | Uji 1 kemitraan konten (barter/fee kecil OK) | Skala sales UMKM |
| Q5 - Q6 | Perpanjang kemitraan wisata/budaya; proposal E1 sekolah | Marketplace |
| Q7 - Q8 | Playbook sustainability | Paywall kamus; slot berbayar UMKM |
| Year 3+ | D1 data/API; evaluasi donasi; multi-daerah hanya jika go-decision Q8 | Iklan interruptive |

**Aturan emas:** jangan menjual permukaan yang belum dipakai organik.
Mitra membeli jangkauan yang sudah ada, atau membiayai pembangunan
konten yang publik tetap bisa akses gratis.

---

## 6. Unit ekonomi sederhana (cara berpikir, bukan spreadsheet palsu)

### 6.1 Biaya yang harus ditutup

- Infrastruktur (API, DB, CDN audio/gambar, push)
- Waktu editorial & moderasi (bottleneck nyata)
- Verifier / relawan (bukan "gratis abadi" tanpa pengakuan)
- Legal sederhana (MoU, privasi, lisensi konten mitra)

### 6.2 Urutan menutup biaya (prioritas)

1. **Grant / CSR / lembaga** - paling selaras misi; cashflow proyek
2. **Retainer kemitraan dinas** - stabil jika MoU tahunan
3. **Sekolah B2B** - scalable lambat, reputasi tinggi
4. **Kampanye C1** - tambahan, jangan jadi ketergantungan (batas frekuensi)
5. **Data/API** - later; jangan cannibalize trust

### 6.3 Indikator sehat monetisasi

| Sehat | Tidak sehat |
| ----- | ----------- |
| Mitra bayar untuk konten/jangkauan yang pengguna anggap berguna | Pengguna mengeluh "app jadi iklan" |
| Listing highlight ≤ proporsi kecil dari feed/peta | Highlight memenuhi peta |
| Grant memperkaya lemma/audio/artikel publik | Grant hanya logo, produk stagnan |
| Sekolah memakai kuis berulang | Sekolah beli sekali lalu churn |

---

## 7. Narasi penjualan (pitch 30 detik)

> SambasKu sudah menjadi kamus kolaboratif Melayu Sambas yang dipercaya
> warga. Kami membuka kemitraan agar dinas, sekolah, dan pelaku lokal
> bisa menayangkan budaya, tempat, dan edukasi di kanal yang sama -
> tanpa mengubah kamus menjadi portal iklan. Mitra membiayai konten dan
> distribusi resmi; masyarakat tetap dapat akses inti gratis.

One-pager dampak (wajib sebelum invoice besar) memuat:

- WALC / MAU arah (dari roadmap Section 5)
- Lemma terverifikasi; % lengkap (contoh/audio)
- Kontributor & verifier aktif
- Artikel / POI / event (setelah vertikal live)
- Studi kasus 1 kampanye atau 1 pilot sekolah (jika ada)

---

## 8. Operasional kemitraan (ringkas)

| Peran | Tanggung jawab |
| ----- | -------------- |
| PO / founder | Pipeline mitra, harga, go/no-go vs anti-goal |
| Editorial | MoU scope konten; kualitas artikel/POI mitra |
| Engineering | Role editor mitra; campaign; analytics event bisnis |
| Moderasi | Klaim UMKM; tolak spam; SLA |

**Kontrak minimal:** ruang lingkup konten, frekuensi kampanye, atribusi,
kepemilikan konten, penarikan materi, larangan mengubah makna kamus,
klausul privasi.

**Pisahkan peran:** "kontributor kamus" ≠ "kontributor bisnis" (sudah
disebut di roadmap Q7-Q8).

---

## 9. Risiko monetisasi & mitigasi

| Risiko | Mitigasi |
| ------ | -------- |
| Dipersepsi jual kepercayaan | Anti-goal ketat; atribusi mitra di zona jelas |
| Dinas lambat bayar / politik | Produk tetap berguna tanpa mitra; grant paralel |
| Spam UMKM | Moderasi klaim gratis; kill switch kategori |
| Ketergantungan satu sponsor | Diversifikasi G1/K1/E1; jangan 1 logo menguasai UI |
| Tim editorial kolaps | Jangan ambil MoU lebih besar dari kapasitas Section 11 roadmap |
| Drift ke marketplace | Tolak fitur order/bayar di review spek |

---

## 10. Checklist keputusan "boleh invoice?"

Centang semua sebelum menagih jalur terkait:

- [ ] Vertikal produk yang dijual sudah live atau terjadwal di fase aktif roadmap
- [ ] Gate utilisasi terkait terpenuhi (atau eksplisit *pilot berbayar terbatas* tertulis)
- [ ] Tidak menyentuh paywall kamus / arti kata / hasil search
- [ ] Frekuensi kampanye & zona atribusi disepakati tertulis
- [ ] Kapasitas moderasi/editorial cukup untuk durasi kontrak
- [ ] Metrik sukses mitra = metrik yang juga baik untuk pengguna
- [ ] Ada klausul keluar jika kualitas/spam merusak brand

---

## 11. Ringkas: potensi nyata per jalur

| Jalur | Potensi (Q1-Q8) | Keyakinan | Catatan |
| ----- | --------------- | --------- | ------- |
| Grant / CSR / lembaga bahasa | Tinggi | Tinggi | Paling cocok misi + cashflow awal |
| Kemitraan Pemkab / Dinas | Tinggi | Sedang | Politik & siklus anggaran; mulai 1 uji |
| Sekolah B2B | Sedang-tinggi | Sedang | Butuh V6 + bukti pilot |
| Kampanye notifikasi | Sedang | Sedang | Lampu kuning spam; hard cap |
| Open data / API | Rendah (awal) | - | Year 3+ |
| Ads / marketplace / paywall / slot UMKM | Ditolak | - | Anti-goal |

**Kesimpulan:** monetisasi lewat **kemitraan dan sejenisnya bukan hanya
mungkin - itu jalur utama yang sehat** untuk SambasKu. Syaratnya tetap
sama dengan roadmap: perkeras kamus dulu, isi Explore dengan konten
bermutu, jual hanya setelah ada jangkauan atau ada pekerjaan konten
yang mitra biayai secara transparan.

---

## 12. Changelog

| Tanggal | Keputusan |
| ------- | --------- |
| 2026-09-28 | Adopsi awal katalog G1/K1/K2/E1/U1/C1/D1; larangan ads & marketplace; selaras ROADMAP_PLAN |
| 2026-10-03 | U1/listing berbayar UMKM dihapus; direktori UMKM tetap gratis |
