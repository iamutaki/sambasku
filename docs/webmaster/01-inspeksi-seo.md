# Inspeksi penemuan konten - `web/*` (SambasKu)

| | |
|---|---|
| **Target** | Situs publik `web/` agar agen AI dan mesin pencari populer bisa menemukan serta membaca isi kamus |
| **Metode** | Curl mentah ke produksi (body + header), lalu disandingkan dengan rute, `robots.txt`, sitemap, meta, dan JSON-LD di sumber. Setiap URL lemma di sitemap dibuka |
| **Tanggal** | 2026-09-26 |
| **Environment** | Produksi `https://sambasku.com` |
| **Status** | Selesai. Termasuk cek relevansi isi sitemap. Kode `web/` tidak diubah |

Mesin pencari yang dijadikan acuan jalur yang sama: Google, Bing (sumber utama DuckDuckGo), dan Yandex. Agen AI dicek lewat `User-agent` yang mereka pakai (`GPTBot`, `ChatGPT-User`) plus berkas `llms.txt`.

---

## 1. Klaim ChatGPT: sitemap tidak ada di robots.txt

Klaim itu tidak cocok dengan produksi hari ini.

`GET https://sambasku.com/robots.txt` menjawab **200**, `Content-Type: text/plain; charset=utf-8`, 66 byte, tanpa `X-Robots-Tag`:

```text
User-agent: *
Allow: /

Sitemap: https://sambasku.com/sitemap.xml
```

Body yang sama kembali untuk `GPTBot`, `ChatGPT-User`, `Googlebot`, `bingbot`, dan `YandexBot`. Sumbernya [web/app/routes/robots[.]txt.ts](../../web/app/routes/robots[.]txt.ts): build produksi menulis baris `Sitemap:` dengan `VITE_APP_URL` (`https://sambasku.com` di [web/.github/workflows/deploy-production.yml](../../web/.github/workflows/deploy-production.yml)).

`https://www.sambasku.com/robots.txt` menjawab **301** ke `https://sambasku.com/robots.txt`. `https://sambasku.com/` menjawab **301** ke `/id`.

`https://sambasku.com/sitemap.xml` hidup (200, `application/xml`, 2203 byte, 27 anak). Isinya **indeks**, bukan daftar halaman:

```text
sitemap-static.xml
sitemap-words/a ... sitemap-words/z
```

Anak statis berisi 64 URL (dua locale). Anak huruf berisi 80 URL kata (40 lemma x `id` dan `id-SBS`). Total 144 URL. Huruf kosong (`a`, `f`, `h`, `j`, `o`, `q`, `v`, `w`, `x`, `y`, `z`) mengembalikan urlset XML valid tanpa `<url>`.

Alasan seorang agen tetap bisa berkata "tidak ada sitemap":

1. Ia membuka `sitemap.xml` dan mencari `<url>`. Di berkas itu yang ada hanya `<sitemap><loc>`. Daftar lemma ada di anak `/sitemap-words/{huruf}`.
2. Ia memakai host lama. `sambasku.iamutaki.com` dan `sambasku-web-staging.iamutaki.com` **tidak punya DNS** dari resolver inspeksi ini (`nodename nor servname provided`). Docs dan [web/README.md](../../web/README.md) masih menulis produksi sebagai `https://sambasku.iamutaki.com`.
3. Build non-produksi memang tidak menulis baris Sitemap (`Disallow: /`, dan `sitemap.xml` 404). Staging tidak bisa di-curl karena hostname-nya tidak resolve, jadi perilaku live staging tidak terbukti di sesi ini. Perilaku itu ada di sumber.

---

## 2. Ringkasan

Jalur penemuan produksi untuk Google, Bing, dan Yandex sudah tersambung: robots mengizinkan semua agen, menunjuk sitemap indeks di host kanonik `sambasku.com`, dan halaman kata merender makna serta terjemahan di HTML awal (tanpa JavaScript) plus JSON-LD `DefinedTerm`.

Yang mengganggu kedua sasaran (AI paham isi, mesin pencari mengenal isi yang benar):

1. Dari 40 lemma di sitemap, 31 belum diverifikasi dan tetap boleh diindeks. Contoh: [Samprong](https://sambasku.com/id/words/Samprong). Deskripsi `/id/words` berkata entri sudah diterbitkan serta diverifikasi. Niche-nya tetap kamus Sambas; yang lemah adalah status isinya. Lihat bagian relevansi sitemap.
2. `hreflang` di `/reset-password` menunjuk `/id/reset-password` dan `/id-SBS/reset-password`, dan kedua URL itu 404.
3. `llms.txt` hanya direktori situs. Tidak ada `llms-full.txt`. `<head>` menaut RSS, tidak menaut `llms.txt` atau sitemap. Agen yang hanya membaca HTML beranda tidak diberi peta korpus.
4. Dokumen masih mengarah ke host yang tidak resolve, jadi agen yang mengikuti docs gagal sebelum sampai ke robots.

### Matriks temuan

| ID | Temuan | Severity | Bukti |
|---|---|---|---|
| WM-01 | `robots.txt` produksi memuat `Sitemap:`. Klaim "tidak ada sitemap" tidak cocok dengan host kanonik | Info | `https://sambasku.com/robots.txt` |
| WM-02 | URL di robots adalah sitemap **indeks**. Parser yang hanya membaca `<url>` di berkas itu melihat nol halaman | Minor | `sitemap.xml` vs `sitemap-words/s` (14 `<url>`, 7 lemma `id`) |
| WM-03 | Host lama dan hostname staging tidak resolve, sementara README serta base stack masih menulis URL itu sebagai produksi | Major | DNS `sambasku.iamutaki.com`, `sambasku-web-staging.iamutaki.com`; [web/README.md](../../web/README.md); [docs/web/web-base-stack.md](../web/web-base-stack.md) bagian Env |
| WM-04 | `llms.txt` adalah direktori hub. `llms-full.txt` 404. HTML tidak menaut keduanya maupun sitemap | Minor | `https://sambasku.com/llms.txt`, `<head>` [web/app/root.tsx](../../web/app/root.tsx) |
| WM-05 | Deskripsi JSON-LD kata terpotong di ~158 karakter. Terjemahan masih ada di `alternateName` dan di HTML | Minor | `/id/words/Samprong` |
| WM-06 | `SearchAction` menunjuk `/{locale}/search`, halaman yang selalu `noindex, nofollow` | Minor | JSON-LD beranda; [web/app/routes/search.tsx](../../web/app/routes/search.tsx) |
| WM-07 | `hreflang` dan `og:locale` memakai `id-SBS` / `id_SBS`, bukan tag yang dikenal mesin pencari sebagai bahasa atau wilayah | Minor | Semua halaman indexable yang disampel |
| WM-08 | `/reset-password` boleh diindeks, tetapi `hreflang`-nya menunjuk dua URL 404. Halaman memakai `h3`, bukan `h1` | Major | `https://sambasku.com/reset-password` |
| WM-09 | 31 dari 40 lemma di sitemap belum diverifikasi, tetapi halaman dan URL-nya indexable. Salinan daftar A-Z menjanjikan entri terverifikasi | Major | Seluruh `sitemap-words/{a-z}`; meta `/id/words` |
| WM-15 | Isi URL kata di sitemap sesuai niche kamus Melayu Sambas. Tidak ada URL di luar jenis situs itu | Info | 40/40 lemma `id` menjawab 200, judul `{lemma} bahasa Sambas - arti & terjemahan` |
| WM-10 | `lastmod` sitemap diisi tanggal generate (hari inspeksi `2026-09-26`), bukan tanggal ubah kata | Minor | `sitemap-static.xml`, `sitemap-words/s` |
| WM-11 | 11 huruf tanpa lemma tetap punya halaman indexable ("Belum ada kata...") dan anak sitemap kosong | Minor | `/id/huruf/a`, `sitemap-words/a` (161 byte, urlset kosong) |
| WM-12 | Profil publik dan thread ruang diskusi indexable, tidak masuk sitemap, tanpa JSON-LD. Daftar `/words` juga tanpa JSON-LD | Minor | [users.$username.tsx](../../web/app/routes/users.$username.tsx), [ruang-diskusi.$id.tsx](../../web/app/routes/ruang-diskusi.$id.tsx) |
| WM-13 | Repo tidak memuat meta verifikasi Search Console, Bing, atau Yandex, dan tidak memuat IndexNow | Info | Tidak ada string verifikasi di `web/` |
| WM-14 | `http://sambasku.com/robots.txt` menjawab 200 plus HSTS, bukan 301 ke https | Minor | curl `--max-redirs 0` |

---

## 3. Relevansi isi sitemap

Niche situs: kamus kolaboratif bahasa Melayu Sambas, dengan makna, terjemahan Indonesia, dan (bila ada) contoh kalimat. Bukan toko, blog, atau direktori umum.

Setiap `<loc>` locale `id` di `sitemap-words/a` sampai `z` dibuka persis seperti tertulis di XML. Ada 40 lemma. Semuanya menjawab **200**. Judul mengikuti pola `{lemma} bahasa Sambas - arti & terjemahan | SambasKu`. H1 adalah lemma itu. Pasangan `/id-SBS/words/...` menggandakan lemma yang sama dengan antarmuka Bahasa Sambas.

Tidak ada URL nyasar: sitemap tidak memuat `/search`, `/kontribusi`, `/users`, `/reset-password`, atau path admin.

### Komposisi 144 URL

| Kelompok | URL | Relevan dengan niche? |
|---|---|---|
| Halaman lemma (`/id` + `/id-SBS`) | 80 | Ya. Entri kamus |
| Halaman huruf yang punya kata (15 huruf x 2 locale) | 30 | Ya. Indeks alfabetis |
| Hub: beranda, daftar A-Z, FAQ, ruang diskusi (x 2 locale) | 8 | Ya. Pintu dan penjelasan kamus |
| Huruf tanpa lemma (11 huruf x 2 locale) | 22 | Struktur alfabet, isi kosong ("Belum ada kata...") |
| Privasi dan hapus akun (x 2 locale) | 4 | Halaman situs, bukan entri leksikal. Prioritas sitemap 0.5 dan 0.4 |

### Isi lemma

9 lemma bertanda **Terverifikasi** dan punya definisi yang bisa dibaca sebagai kamus, kecuali satu ungkapan yang definisinya tanda hubung:

| Lemma | Terjemahan yang terlihat |
|---|---|
| cawan | gelas |
| kappa' | lelah |
| Katok | celana dalam |
| Keriah | ketombe (ada contoh kalimat) |
| masok | masuk |
| Pangkeng | ranjang |
| pelam | film |
| tigge' | leher |
| Uwa'-uwa' nagorkan tae'nye | membicarakan kesalahan orang lain |

31 lemma lain bertanda **Menunggu pengecekan**. Sebagian besar definisi di HTML berupa tanda hubung (`-`), sementara baris "Terjemahan Indonesia" tetap terisi dan tetap berada di niche yang sama. Contoh: `capal` diterjemahkan "Sendal", `siok` "dapur", `simari` "kemarin", `Daan keladaan` "tidak terasa", `kacak ugak mapah ujong` berupa ungkapan sikap. `Samprong` dan `Rasbang` belum diverifikasi tetapi definisinya kalimat utuh, bukan tanda hubung.

Lemma lebih dari satu kata (`gek mare'`, `ina' ina'ang sige'`, `na' jape/ na' ngape`) tetap halaman arti, bukan artikel lain. Bentuk headword-nya berantakan (garis miring di tengah lemma), tetapi jenis halamannya tetap kamus.

**Kesimpulan:** sitemap mengenalkan mesin pencari pada jenis situs dan niche yang benar. Yang belum selaras adalah kualitas status: mayoritas URL kata adalah draf, 22 URL huruf tidak berisi lemma, dan 4 URL hukum bukan kosakata. WM-09 dan WM-11.

---

## 4. Detail temuan utama

### WM-03 · Host di dokumen tidak resolve - Major

Produksi yang menjawab hari ini adalah `https://sambasku.com`. `www` diarahkan ke apex.

`sambasku.iamutaki.com` dan `sambasku-web-staging.iamutaki.com` tidak resolve. [web/README.md](../../web/README.md) masih menulis produksi `https://sambasku.iamutaki.com` dengan SEO aktif. [docs/web/web-base-stack.md](../web/web-base-stack.md) bagian Env sama. Contoh hreflang di [docs/web/WEB-I18N.md](../web/WEB-I18N.md) juga memakai host `sambasku.iamutaki.com`.

Agen atau manusia yang menyalin URL dari dokumen itu tidak sampai ke `robots.txt` sama sekali. Itu penjelasan yang paling masuk akal untuk laporan "saya coba akses robots, tidak ada sitemap", bila URL yang dibuka bukan `https://sambasku.com/robots.txt`.

**Rekomendasi:** selaraskan README web, base stack, dan contoh WEB-I18N ke `https://sambasku.com`. Pasang ulang DNS staging bila hostname `sambasku-web-staging.iamutaki.com` masih dipakai deploy ([web/.github/workflows/deploy-staging.yml](../../web/.github/workflows/deploy-staging.yml)).

### WM-08 · hreflang reset password menunjuk 404 - Major

[web/app/routes/reset-password.tsx](../../web/app/routes/reset-password.tsx) memanggil `buildMetaTags` tanpa `noindexAlways`. Di produksi halaman ini dapat canonical dan hreflang.

Live `https://sambasku.com/reset-password`:

- tidak ada `meta robots` (jadi boleh diindeks)
- canonical `https://sambasku.com/reset-password`
- `hreflang="id"` ke `https://sambasku.com/id/reset-password` (**404**)
- `hreflang="id-SBS"` ke `https://sambasku.com/id-SBS/reset-password` (**404**)
- judul terlihat "Atur password baru", heading halaman adalah `h3`

`buildHreflangLinks` selalu menempelkan prefix locale ke path. Rute reset password didaftarkan di luar `/:locale` ([web/app/routes.ts](../../web/app/routes.ts)), jadi padanan ber-locale tidak ada.

**Rekomendasi:** `noindex` untuk `/reset-password` (selaras deeplink, bukan halaman kamus), dan jangan keluarkan hreflang ke path yang tidak terdaftar.

### WM-09 · Entri belum diverifikasi ikut ditemukan mesin pencari - Major

Sitemap kata memakai `listWordsAtoZ` yang sama dengan daftar publik (`GET /words`), tanpa saringan terverifikasi ([web/app/routes/sitemap-words.$letter.ts](../../web/app/routes/sitemap-words.$letter.ts)).

`https://sambasku.com/id/words/Samprong` (ada di `sitemap-words/s`):

- title: `Samprong bahasa Sambas - arti & terjemahan | SambasKu`
- H1: `Samprong`
- teks awal HTML: "Menunggu pengecekan" dan "Kata ini belum diperiksa tim Sambasku"
- makna tetap ada di HTML: "tabung kaca atau plastik yang bertutup..."
- terjemahan di HTML: "Tempat menyimpan kerupuk", "stoples"
- JSON-LD `DefinedTerm` + `BreadcrumbList` ikut terbit

Deskripsi `/id/words`: "Setiap entri memuat makna, terjemahan Indonesia, dan telah diterbitkan serta diverifikasi."

Mesin pencari yang mengikuti sitemap akan memperlakukan draf itu sebagai entri kamus. Agen yang mengutip halaman yang sama akan mengulang definisi yang situs sendiri tandai belum diperiksa.

**Rekomendasi:** sitemap dan sinyal index hanya untuk lemma yang sudah diverifikasi. Selaraskan kalimat deskripsi daftar A-Z dengan isi yang benar-benar diindeks.

### WM-02 dan WM-04 · Apa yang bisa dibaca agen AI - Minor

Crawler yang diizinkan `User-agent: *` dapat membuka halaman kata dan membaca makna di HTML SSR. Sampel `/id/words/Samprong` dan empat lemma huruf T memuat heading makna plus label "Terjemahan Indonesia" di HTML awal. Blok contoh kalimat tidak muncul pada kelima sampel itu (data kosong di entri tersebut). Template detail tetap merender contoh di server bila `meaning.examples` terisi.

`https://sambasku.com/llms.txt` (200, `text/plain`, 1139 byte) mendaftar beranda, daftar A-Z, satu contoh huruf, FAQ, bantuan, kontribusi, RSS, dan sitemap. Tidak ada lemma atau definisi. `https://sambasku.com/llms-full.txt` 404.

`<head>` setiap halaman memuat `rel="alternate" type="application/rss+xml"` ke `/rss.xml` (20 item, judul = lemma, deskripsi = sense). Tidak ada tautan ke `llms.txt` atau sitemap.

RSS adalah jalur kedua yang bagus untuk 20 kata terbaru. Korpus selebihnya hanya ketemu lewat sitemap indeks atau tautan dalam.

**Rekomendasi:** untuk korpus seukuran ini (40 lemma), agen yang tidak mengikuti sitemap index terbantu bila `sitemap.xml` menjadi satu urlset, atau bila `llms.txt` menjelaskan bahwa daftar halaman ada di `/sitemap-words/{a-z}`. Tautan `llms.txt` di `<head>` membuat berkas itu ketemu dari HTML. `llms-full.txt` baru berharga bila memuat makna, bukan salinan direktori.

### WM-07 · Kode bahasa `id-SBS` - Minor

Locale UI `id-SBS` konsisten di URL, `html lang`, hreflang, dan sitemap. `og:locale` beranda adalah `id_ID` dengan alternate `id_SBS`. Halaman `/id-SBS/words/Samprong` berbahasa antarmuka Sambas (`lang="id-SBS"`, judul "Samprong base Sambas - arti & tejemahan") dan makna kata tetap ada di HTML.

Tag `id-SBS` bukan bahasa ISO 639-1 dan `SBS` bukan wilayah ISO 3166-1. Google dan Bing biasanya mengabaikan hreflang yang tidak mereka kenali, lalu memperlakukan URL itu sebagai halaman terpisah. Kedua URL tetap ada di sitemap, jadi halaman Bahasa Sambas tetap bisa dikunjungi. Sinyal "ini padanan bahasa lain dari halaman yang sama" yang lemah.

**Rekomendasi:** catat sebagai keputusan produk. Mengganti kode locale mengubah URL yang sudah terbit; jangan diganti hanya dari inspeksi ini.

---

## 5. Peta rute

`noindex` di produksi hanya bila `noindexAlways` atau build bukan production ([web/app/application/utils/seo.ts](../../web/app/application/utils/seo.ts)). Staging menambah `X-Robots-Tag: noindex, nofollow` di worker. Produksi yang disampel tidak mengirim header itu.

| Rute | Index produksi | Di sitemap | JSON-LD | Catatan live / sumber |
|---|---|---|---|---|
| `/{locale}` | ya | ya | `WebSite`, `Organization`, `SearchAction` | H1 "Kamus Sambas". Canonical `https://sambasku.com/id` |
| `/{locale}/words` | ya | ya | tidak | H1 ada. Deskripsi mengklaim semua entri terverifikasi |
| `/{locale}/words/:lemma` | ya | ya, per huruf | `DefinedTerm`, `BreadcrumbList` | Makna + terjemahan di HTML awal. JSON-LD di body |
| `/{locale}/huruf/:letter` | ya | ya, termasuk huruf kosong | `CollectionPage`, `ItemList` | `/id/huruf/s` berisi item. `/id/huruf/a`: "Belum ada kata yang berawalan huruf A." |
| `/{locale}/faq` | ya | ya | `FAQPage` | 11 pasang tanya-jawab di JSON-LD |
| `/{locale}/ruang-diskusi` | ya | ya | tidak | Daftar |
| `/{locale}/ruang-diskusi/:id` | ya | tidak | tidak | Hanya ketemu dari tautan dalam |
| `/{locale}/privacy-policy`, `/{locale}/hapus-akun` | ya | ya | tidak | |
| `/{locale}/users/:username` | ya | tidak | tidak | |
| `/{locale}/search` | tidak (`noindex, nofollow`) | tidak | tidak | Tanpa canonical. Sasaran `SearchAction` |
| `/{locale}/kontribusi` | tidak | tidak | tidak | Sama, `noindex` terbukti live |
| `/reset-password` | ya | tidak | tidak | hreflang ke 404. Lihat WM-08 |
| `/rss.xml` | feed, bukan HTML | disebut dari `llms.txt` dan `<head>` | | 20 item, locale `id` |
| `/og/words/:lemma` | gambar | tidak | | Di luar pohon locale |

Tidak ada negosiasi `text/markdown`. Isi yang terstruktur untuk mesin adalah HTML SSR plus JSON-LD di halaman yang memilikinya.

---

## 6. Yang sudah berjalan

- Robots produksi mengizinkan perayapan dan menunjuk sitemap di host yang sama dengan canonical.
- `www` pindah ke apex. Akar `/` pindah ke `/id`.
- Sitemap indeks memakai namespace `http://www.sitemaps.org/schemas/sitemap/0.9` plus `xhtml:link` hreflang dan `x-default` ke locale `id`.
- Halaman kamus yang disampel punya satu H1, title, description, canonical, dan `html lang` yang sesuai locale.
- Detail kata menyertakan makna, kelas kata, dan terjemahan di HTML pertama. `DefinedTerm.alternateName` memuat terjemahan Indonesia.
- `/search` dan `/kontribusi` konsisten `noindex` dan absen dari sitemap.
- RSS tertaut dari `<head>` dan terisi.
- `llms.txt` live di URL yang konvensi umum pakai (`/llms.txt`).
- Ke-40 lemma di sitemap adalah entri kamus Melayu Sambas, dan halaman hukum serta form kontribusi tidak menyamar sebagai entri kata.

Verifikasi Search Console / Bing / Yandex tidak ada di repo (WM-13). Token itu boleh hidup di DNS. IndexNow tidak wajib agar URL dikenal selama robots dan sitemap sehat.

---

## 7. Status perbaikan

Dikerjakan di kode (perlu deploy API + web agar live):

1. Host produksi di README web, `web-base-stack`, contoh WEB-I18N, default
   `env.ts`, dan `.env.production.example` memakai `https://sambasku.com`.
   Hostname staging `sambasku-web-staging.iamutaki.com` tetap di workflow;
   record DNS-nya masih harus dipasang di Cloudflare (tidak dari repo).
2. Sitemap hanya lemma `is_verified=true`. Halaman draf 200 + `noindex`,
   tanpa JSON-LD. Deskripsi daftar A-Z tidak mengklaim semua entri sudah
   diverifikasi. `GET /words` mengirim `updated_at` untuk `lastmod`.
3. `/reset-password` memakai `noindexAlways` (tanpa hreflang ke 404).
   Judul halaman `h1`.
4. `/sitemap.xml` satu urlset. Anak lama 301 ke sana. `<head>` menaut
   `/llms.txt`. `llms.txt` menjelaskan sitemap sebagai daftar indexable.
5. `SearchAction` dihapus dari JSON-LD beranda karena `/search` noindex.
6. Worker mengalihkan `http://` ke `https://` untuk apex, `www`, dan host
   staging lewat `CF-Visitor`.
7. Halaman `/{locale}/api-publik`: dokumentasi API baca kamus (cari + detail
   by lemma, ringkas list A-Z dan by id). Ada di footer, sitemap, dan
   `llms.txt`. TOC, JSON-LD TechArticle, contoh encoding lemma, catatan
   429/Retry-After, CORS, dan homonim. Cuplikan curl/JSON memakai
   `@mantine/code-highlight` + highlight.js (bash/json), tombol salin,
   badge method, bagian Konvensi, tautan Scalar `/docs` dan `openapi.json`.
8. `llms-full.txt` dinamis (korpus terverifikasi). Komentar di `robots.txt`.
   Profil `/users/:username` dan thread bantuan `noindex` (tidak di sitemap).
   API baca kata: CORS `*` untuk origin asing + `Cache-Control` publik.
9. Footer web ringkas terpusat: Daftar Kata, Ajukan kata, Tanya, FAQ, API
   publik, Privasi, GitHub, RSS; hapus akun di baris copyright. Tanpa
   tautan `/search` (`noindex`).
10. Locale `id-SBS` tetap dipakai untuk UI; tidak ada kode BCP-47/ISO 639
    resmi khusus Sambas/Pontianak/Singkawang (dialek tercakup `zlm`).
    Subtag `sbs` di IANA = Subiya, bukan Sambas - jangan diganti ke situ.

## 8. Di luar cakupan

Core Web Vitals, akun Search Console, menyunting isi korpus, dan
pemasangan record DNS staging di Cloudflare. Templatenya sudah merender
definisi, terjemahan, dan contoh bila API mengirim data. OpenAPI UI
interaktif tetap di host API (`/docs`), bukan di-embed ulang di web.
