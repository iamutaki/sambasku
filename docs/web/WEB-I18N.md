# WEB-I18N - Kontrak Multi-bahasa Situs Publik

Kontrak dasar i18n untuk `web/` (React Router 7 SSR + Cloudflare
Workers). **Dokumen ini adalah kontrak**, bukan panduan implementasi
lengkap. Implementasi dikerjakan gelombang per gelombang; tiap PR
fitur/modul baru wajib mengikuti pola di sini dan
`docs/web/web-base-stack.md` (Section i18n).

Target pertama produk multi-bahasa: **web publik** (SEO-sensitive).
Mobile dan console mengikuti kontrak masing-masing setelah fondasi web
stabil.

## 1. Tujuan & ruang lingkup

| Termasuk | Tidak termasuk |
| --- | --- |
| String chrome UI (nav, tombol, empty state, error UI, FAQ copy, CTA) | Isi kamus dari API (lemma, makna, contoh, audio) - data CMS |
| Meta SEO (title/description template), breadcrumb label, JSON-LD teks | Menerjemahkan konten kata lewat katalog i18n |
| Locale di URL, hreflang, sitemap multi-locale, `og:locale` | Menyimpan terjemahan UI di database API |
| Language switcher + persistensi preferensi | Auto-translate / machine translation pipeline |

Prinsip: **UI locale ≠ arah pencarian kamus**. Locale mengatur bahasa
antarmuka. Arah Sambas↔Indonesia tetap fitur kamus (`search_in`),
bukan locale.

## 2. Locale registry (sumber kebenaran)

Satu registry di kode (mis. `app/application/i18n/locales.ts`). Locale
baru = tambah baris di registry + file katalog. Jangan hardcode daftar
locale di komponen.

| Kode kanonik (BCP-47) | Label UI | Default | SEO index | Catatan |
| --- | --- | --- | --- | --- |
| `id` | Bahasa Indonesia | ya | ya (prod) | Pasar SEO utama |
| `id-SBS` | Bahasa Sambas | tidak | ya (prod) | UI chrome berbahasa Sambas |

Aturan kode:

1. **Kanonik di web/URL/header**: BCP-47 dengan **hyphen** (`id`,
   `id-SBS`). Case-sensitive di path: selalu bentuk di tabel.
2. **Open Graph `og:locale`**: underscore + region bila ada
   (`id_ID` untuk `id`). Untuk `id-SBS` pakai `id_SBS` (custom tag) +
   `og:locale:alternate` ke `id_ID`.
3. **Alias yang ditolak** di URL: `id_SBS`, `idsbs`, `ID`, `id-sbs`
   (huruf kecil pada subtag region). Redirect 301 ke bentuk kanonik.
4. Locale masa depan (contoh `en`, `ms`) ditambah ke registry tanpa
   mengubah pola routing/katalog. Set `seoIndex` per locale.

Default locale: **`id`**. Fallback terjemahan hilang: selalu `id`
(jangan blank / key mentah di produksi).

## 3. Strategi URL (wajib SEO)

### 3.1 Path prefix

Semua rute publik ter-index memakai prefix locale:

```text
/{locale}/                  → beranda
/{locale}/words             → daftar A-Z
/{locale}/words/:id         → detail kata (lemma atau id)
/{locale}/huruf/:letter     → landing per huruf a-z (indexable; uppercase 301)
/{locale}/search?q=...      → pencarian (tetap noindex)
/{locale}/faq               → FAQ
/{locale}/kontribusi        → form kontribusi (bila ada)
```

Contoh:

- `https://sambasku.com/id/words/somet`
- `https://sambasku.com/id-SBS/words/somet`

### 3.2 Redirect & alias

| Permintaan | Respons |
| --- | --- |
| `/` (tanpa locale) | `302` (dev/staging) / `301` (prod) → `/{defaultLocale}` |
| `/words/...` (legacy tanpa prefix) | `301` → `/{defaultLocale}/words/...` |
| Locale tidak dikenal | `404` atau redirect ke default (pilih **404** agar typo tidak
  merusak sinyal SEO) |
| `/search` tanpa locale | `301` → `/{defaultLocale}/search` (+ query string) |

Deep link mobile (`/reset-password`, dsb.) yang bukan halaman SEO:
tetap boleh tanpa prefix **atau** terima kedua bentuk; dokumentasikan
di routes saat implementasi. Jangan index halaman auth/deeplink.

### 3.3 Canonical, hreflang, x-default

Setiap halaman indexable (prod) wajib:

1. **Canonical** self: URL lengkap termasuk prefix locale saat ini.
2. **`link rel="alternate" hreflang="{locale}"`** untuk setiap locale
   `seoIndex=true` yang punya padanan path yang sama.
3. **`hreflang="x-default"`** → URL locale default (`id`) untuk path
   yang sama.
4. Jangan menunjuk hreflang ke staging; staging tetap noindex total
   (lihat base stack Section SEO).

Contoh untuk `/id/words/somet`:

```html
<link rel="canonical" href="https://sambasku.com/id/words/somet" />
<link rel="alternate" hreflang="id" href="https://sambasku.com/id/words/somet" />
<link rel="alternate" hreflang="id-SBS" href="https://sambasku.com/id-SBS/words/somet" />
<link rel="alternate" hreflang="x-default" href="https://sambasku.com/id/words/somet" />
```

### 3.4 Sitemap & robots

- `sitemap.xml` (prod): satu urlset. Sertakan URL locale untuk rute
  statis + halaman huruf yang punya lemma terverifikasi + setiap lemma
  terverifikasi × locale indexable. `lastmod` lemma dari `updated_at`.
  Lemma yang belum diverifikasi tetap bisa dibuka, dengan `noindex`.
- Prefer entri dengan `xhtml:link rel="alternate" hreflang=...`
  (satu cluster per lemma/path), atau daftar URL flat + pastikan
  halaman punya hreflang (minimum wajib hreflang di HTML).
- `robots.txt`: tidak berubah prinsip (prod allow + sitemap; staging
  disallow). Path sitemap tetap `/sitemap.xml` (bukan per-locale).

### 3.5 Meta, OG, JSON-LD

- `buildMetaTags` / helper SEO menerima `locale` + `path` yang sudah
  ber-prefix. Canonical & `og:url` = URL ber-locale.
- `og:locale` + `og:locale:alternate` sesuai Section 2.
- JSON-LD (`WebSite`, `DefinedTerm`, `BreadcrumbList`, `FAQPage`):
  field `url` / `@id` / `item` memakai URL ber-locale. Teks
  `name`/`description` yang bukan data API diambil dari katalog
  namespace `seo` / `faq`.
- Template SEO (contoh detail kata) tetap pola
  `{lemma} ...` lewat interpolasi katalog, bukan string hardcoded.

### 3.6 SSR (non-negotiable)

HTML awal **harus** sudah berbahasa locale aktif (title, deskripsi,
nav, H1 chrome, FAQ). Jangan ganti bahasa hanya di `useEffect` setelah
hydrate. Crawler harus melihat konten locale yang benar tanpa JS.

## 4. Stack pustaka (keputusan)

| Peran | Pilihan | Alasan |
| --- | --- | --- |
| Runtime i18n | `i18next` + `react-i18next` | Standar industri, SSR-ready, namespace, interpolasi |
| Katalog | JSON per locale per namespace di `app/application/i18n/locales/` | Mudah di-diff, mudah di-port string, tanpa build step khusus |
| Deteksi locale | Dari **URL path** (sumber utama SSR) | SEO & share URL deterministik |
| Persist preferensi | `localStorage` / cookie non-httpOnly `sk_locale` (opsional) | Hanya untuk default di `/` sebelum redirect; URL tetap sumber kebenaran setelah masuk |

Dilarang: menyimpan seluruh kamus string di DB; menyalin string UI ke
API envelope; memakai library kedua di samping i18next untuk chrome
yang sama.

## 5. Struktur folder

```text
web/app/application/i18n/
├── locales.ts                 # registry: kode, label, default, seoIndex, ogLocale
├── i18n-instance.ts           # createInstance + getFixedT (shared SSR/client)
├── i18n.client.ts             # singleton browser + changeLanguage
├── resources.ts               # import satu JSON per locale
├── format.ts                  # tanggal/angka per locale (bila perlu)
└── locales/
    ├── id.json                # SEMUA string UI (key ber-prefix)
    └── id-SBS.json            # key 1:1 dengan id.json
```

Satu file per locale. Key memakai **prefix area** supaya mudah dicari
dan di-diff (bukan banyak file namespace):

| Prefix | Isi |
| --- | --- |
| `common_` | Merek, aksi umum, empty generik |
| `nav_` | Header, footer, drawer, language switcher |
| `home_` | Hero, CTA, section titles beranda |
| `search_` | Placeholder, filter, empty search |
| `word_` | Detail/list chrome + template SEO kata |
| `faq_` | FAQ page + items[] |
| `seo_` | Template title/description halaman |
| `errors_` | Error boundary / fallback |

Contoh key: `home_title`, `faq_items`, `seo_homeDescription`,
`nav_words`. Pemakaian: `t('home_title')` (satu namespace
`translation`).

## 6. Konvensi key & string

1. Key: `{area}_{camelCase}` - contoh `word_relatedTitle`,
   `home_ctaButton`.
2. **Key identik** di semua locale JSON. Hanya **nilai** yang berbeda.
3. Interpolasi: `{{var}}` (i18next default). Contoh:
   `"word_seoTitleTemplate": "{{lemma}} bahasa Sambas - arti & terjemahan"`.
4. Plural / count: pakai fitur plural i18next bila perlu
   (`key_one` / `key_other`), jangan `count + " kata"` manual.
5. Jangan gabung kalimat di kode (`t('a') + ' ' + t('b')`) bila bisa
   satu string utuh (urutan kata beda antar bahasa).
6. Tetap **tanpa em/en dash** di nilai katalog (aturan gaya base stack).
7. Konten dari API ditampilkan mentah; bungkus label UI saja lewat `t()`.
8. Locale baru = salin `id.json` → `{locale}.json`, lalu terjemahkan nilai.

### Port string (checklist per halaman)

Saat mengerjakan gelombang port:

1. Inventarisasi literal di route/komponen → daftar key ber-prefix.
2. Tambah key ke `locales/id.json` dulu (sumber).
3. Salin key ke `locales/id-SBS.json` (terjemahan; boleh sementara = `id`
   dengan TODO review penutur bila belum siap).
4. Ganti literal di komponen dengan `t('area_key')`.
5. Pastikan `meta()` / JSON-LD memakai key `seo_*` / `faq_*`.
6. Verifikasi SSR: `curl` HTML mengandung teks locale aktif.
## 7. Routing & loader (pola)

- Prefix `/:locale` di pohon route (layout locale). Validasi
  `locale` terhadap registry di `loader` layout; invalid → 404.
- `loader` me-resolve locale → init/pass ke i18n + return
  `locale` ke komponen via root data.
- Link internal **wajib** mempertahankan locale aktif
  (helper `localePath(locale, '/words')` → `/id/words`).
  Dilarang hardcode `/words` tanpa locale setelah migrasi.
- Language switcher: ganti hanya segmen locale, pertahankan path +
  query; navigasi SPA lewat `Link` / `navigate`.

## 8. Deteksi bahasa (urutan)

Untuk request ke `/` atau saat memilih default:

1. Path locale (jika ada) - menang.
2. Cookie/localStorage `sk_locale` bila valid di registry.
3. `Accept-Language` (opsional, best-effort) hanya untuk memilih
   redirect dari `/`.
4. Default `id`.

Setelah user berada di URL ber-prefix, **jangan** override locale dari
`Accept-Language` (URL adalah kontrak share/SEO).

## 9. Aksesibilitas & UX switcher

- Switcher di header (desktop) + drawer (mobile): daftar dari registry.
- Tampilkan label bahasa dalam bahasa itu sendiri bila memungkinkan
  ("Bahasa Indonesia", "Bahasa Sambas").
- `lang` pada `<html lang="{bcp47}">` mengikuti locale aktif (SSR).
- Jangan reload penuh kecuali diperlukan; prefer client navigation.

## 10. Testing & Definition of Done (fondasi)

Gelombang **scaffold** selesai bila:

- [ ] Registry + dua katalog bootstrap (`id`, `id-SBS`) ada
- [ ] Route ber-prefix; legacy path 301 ke default locale (prod)
- [ ] `<html lang>` + meta/hreflang benar di SSR
- [ ] Switcher mengubah URL dengan benar
- [ ] Staging tetap noindex; sitemap prod memuat URL multi-locale
- [ ] `pnpm typecheck` / `lint` / `build` hijau

Gelombang **port halaman X** selesai bila checklist Section 6 terpenuhi
untuk halaman itu + tidak ada literal UI baru di file yang disentuh.

## 11. Urutan eksekusi (disarankan)

1. **W0 - Scaffold**: registry, i18n init SSR/client, layout
   `/:locale`, redirect legacy, switcher, katalog kosong/minimal.
2. **W1 - SEO shell**: `seo` + `nav` + `common`; hreflang; sitemap
   multi-locale; `buildMetaTags` ber-locale.
3. **W2 - Halaman inti**: `home`, `word`, `search`, `faq`.
4. **W3 - Sisa chrome**: kontribusi, error boundary, empty states.
5. **W4 - Review id-SBS**: sunting katalog Sambas bersama penutur.

Implementasi kode **belum** dimulai di kontrak ini; ikuti gelombang di
atas saat eksekusi.

## 12. Referensi

- `docs/web/web-base-stack.md` - Section i18n + SEO
- `docs/mobile/MOBILE-I18N.md` - kontrak Flutter (port belakangan)
- `docs/admin/CONSOLE-I18N.md` - kontrak konsol admin
- Google Search Central: localized versions / hreflang
