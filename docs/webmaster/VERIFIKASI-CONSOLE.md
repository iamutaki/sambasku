# Verifikasi Search Console + target keyword "Kamus Sambas"

Panduan operasional agar `https://sambasku.com` terverifikasi di Google
Search Console, dan agar query organik **Kamus Sambas** (plus varian)
diarahkan ke URL kanonik beranda `/id`.

Tidak ada form "daftar keyword" di Google. Yang ada: verifikasi properti,
indeksasi URL yang benar, optimasi on-page, korpus niche, otoritas luar
situs, lalu ukur di Search Console.

Acuan inspeksi teknis: [`01-inspeksi-seo.md`](./01-inspeksi-seo.md).

---

## 0. URL kanonik

| Peran | URL |
| --- | --- |
| Host produksi | `https://sambasku.com` |
| Beranda SEO (target keyword) | `https://sambasku.com/id` |
| Sitemap | `https://sambasku.com/sitemap.xml` |
| robots.txt | `https://sambasku.com/robots.txt` |

`/` 301 ke `/id`. Pakai apex tanpa `www` (www sudah diarahkan ke apex).

---

## 1. Verifikasi Google Search Console

**Status:** properti `sambasku.com` sudah terverifikasi. Tidak perlu meta
`google-site-verification` di kode web, dan tidak ada
`VITE_GOOGLE_SITE_VERIFICATION` di build.

### 1.1 Metode yang dipakai (referensi)

Verifikasi biasanya lewat **DNS TXT** (properti Domain di Cloudflare) atau
metode lain di Search Console. HTML-tag di `<head>` tidak dipakai lagi di
repo ini.

Jika properti hilang / perlu properti baru: ulang di
[Google Search Console](https://search.google.com/search-console) dengan
DNS TXT (disarankan) atau HTML file di `web/public/` + deploy. Jangan
commit token ke git.

### 1.2 Setelah terverifikasi (wajib operasional)

1. **Sitemaps** → pastikan `https://sambasku.com/sitemap.xml` sudah
   di-submit dan tanpa error kritis.
2. **URL Inspection** → uji `https://sambasku.com/id` → Request indexing
   bila belum terindeks.
3. Staging (`*-staging*`) tetap `noindex` di kode; jangan diperlakukan
   sebagai properti produksi.

### 1.3 Bing / Yandex (opsional)

- [Bing Webmaster](https://www.bing.com/webmasters): import dari Google
  atau verifikasi DNS sendiri.
- Yandex Webmaster: opsional untuk pasar lokal.

---

## 2. Optimasi on-page target "Kamus Sambas"

URL target: **`/id`** (beranda).

| Elemen | Target | Status di kode |
| --- | --- | --- |
| `<title>` | Memuat "Kamus Sambas" + manfaat singkat + `| SambasKu` | `seo_homeTitle` di `id.json` / `id-SBS.json` |
| Meta description | 1-2 kalimat, frasa + manfaat | `seo_homeDescription` |
| `h1` | "Kamus Sambas" | `home_title` |
| Konten | Apa itu kamus, cara pakai, contoh lemma | Blok tentang di `home.tsx` |
| Internal link | Words, huruf A-Z, FAQ, breadcrumb → beranda | Crumb `word_homeCrumb` = "Kamus Sambas"; FAQ/footer ke `/` |

Aturan copy: frasa muncul wajar di judul, heading, dan paragraf pertama.
Jangan stuffing.

Setelah deploy, cek live:

```bash
curl -fsS https://sambasku.com/id | head -n 80
```

Cari `Kamus Sambas` di `<title>`, `meta name="description"`, dan `<h1>`.

---

## 3. Korpus niche (sinyal "ini memang kamus Sambas")

Yang sudah di kode (lihat juga WM-09 / WM-11 di inspeksi):

- Sitemap hanya lemma `is_verified=true`
- Halaman draf: `200` + `noindex`, tanpa JSON-LD `DefinedTerm`
- Halaman terverifikasi: makna di HTML SSR + JSON-LD `DefinedTerm`
- Daftar A-Z / huruf: gloss `sense` di HTML kartu; browse default
  `is_verified=true`; huruf kosong `noindex`
- `llms-full.txt` = korpus terverifikasi

Yang tetap kerja manusia / admin:

1. Verifikasi lemma bermakna di console (kurangi draf tipis).
2. Isi definisi, terjemahan, contoh; hindari definisi hanya `-`.
3. Pantau ukuran sitemap (jumlah `<url>` lemma) naik seiring korpus sehat.

---

## 4. Otoritas di luar situs

Tidak diotomatisasi di repo. Checklist operasional:

| Saluran | Aksi |
| --- | --- |
| Google Play | Listing memakai judul/deskripsi "Kamus Sambas" ([`docs/DESC.md`](../DESC.md)) |
| App Store (bila ada) | Samakan frasa merek + kamus |
| Media lokal / budaya / pendidikan | Artikel atau tautan ke `https://sambasku.com/id` |
| Wikipedia / wiki terkait | Hanya jika memenuhi notabilitas; tautan natural, bukan spam |
| GitHub `sambasku` | README + situs mengarah ke host kanonik |
| Media sosial | Discovery; bukan sinyal ranking langsung |

Profil Play sudah memuat "Kamus Sambas" di judul ID. Pastikan listing
live selaras dengan `docs/DESC.md`.

---

## 5. Ukur di Search Console (jangan tebak)

Setelah data Performance tersedia (biasanya beberapa hari):

### Query yang dipantau

- `kamus sambas`
- `kamus bahasa sambas`
- `kamus melayu sambas`
- `arti kata sambas`
- `sambasku`

### Metrik

| Metrik | Arti praktis |
| --- | --- |
| Impressions | Berapa sering URL muncul di SERP |
| Clicks / CTR | Daya tarik title + description |
| Average position | Peringkat rata-rata |
| Pages | URL mana yang dapat impression untuk query itu |

### Loop perbaikan

1. Filter query `kamus sambas` (dan varian).
2. Lihat halaman yang muncul: idealnya `/id` mendominasi.
3. Jika posisi **5-15** dengan impression cukup: perbaiki title/description
   dulu (CTR), baru konten.
4. Jika `/words/...` atau halaman lain yang "salah" mendominasi query
   merek: perkuat sinyal beranda (title, h1, internal link) dan pastikan
   canonical beranda benar.
5. Catat tanggal perubahan copy di changelog singkat di bawah agar bisa
   dibaca terhadap grafik Performance.

### Changelog copy SEO (isi manual)

| Tanggal | Perubahan | URL |
| --- | --- | --- |
| (isi saat deploy) | Title/description/h1 + blok tentang beranda | `/id` |
| (isi saat deploy) | Gloss `sense` di WordCard; huruf/words verified; huruf kosong noindex | `/id/words`, `/id/huruf/*` |

---

## 6. Checklist go-live singkat

- [x] Properti Search Console terverifikasi
- [ ] Sitemap submitted dan tanpa error kritis
- [ ] `https://sambasku.com/id` terindeks (URL Inspection)
- [ ] Title / description / h1 live memuat "Kamus Sambas"
- [ ] Blok tentang + contoh lemma + tautan A-Z/FAQ ada di HTML (view-source)
- [ ] Daftar A-Z / huruf menampilkan gloss `sense` di HTML
- [ ] Sitemap hanya lemma terverifikasi; huruf kosong noindex
- [ ] Listing Play menyebut Kamus Sambas
- [ ] Setelah 2-4 minggu: cek Performance untuk query di §5

---

## 7. Referensi kode

| Area | Lokasi |
| --- | --- |
| Meta + JSON-LD beranda | `web/app/routes/home.tsx`, `web/app/application/utils/seo.ts` |
| String SEO / home | `web/app/application/i18n/locales/id.json`, `id-SBS.json` |
| Gloss daftar A-Z | `web/app/presentation/components/word/word-card.tsx` (`sense`) |
| Huruf / words verified | `web/app/routes/huruf.$letter.tsx`, `web/app/routes/words.tsx` |
| Sitemap verified-only | `web/app/routes/sitemap[.]xml.ts` |
| noindex draf | `web/app/routes/words.$lemma.tsx` |
| Listing store | `docs/DESC.md`, `docs/DESC-EN.md` |
