# Base Stack - Web Publik Kamus Digital Sambas-Indonesia (SSR)

Dokumen ini acuan tetap untuk semua prompt/fitur `web/` selanjutnya (halaman
publik, SEO, tema, komponen, deploy) - peran yang sama seperti
`docs/admin/admin-base-stack.md` untuk admin dan `docs/api/api-base-stack.md`
untuk backend. Web publik mengonsumsi API dengan kontrak `docs/api/*`
(envelope response, cursor pagination, error code) sebagai guest TANPA auth.

Target utama produk: **mobile-first** - semua halaman dirancang dan diuji di
layar sempit (320-390px) lebih dulu, baru diperlebar.

## Unggah gambar

Web **tidak** mengambil gambar sama sekali: pilih gambar (Media Explorer
foto stock, kamera, galeri) dan bagikan kartu kata **eksklusif mobile**.
Form kontribusi web (`/kontribusi`) hanya teks; `POST /contributions/words`
dari web tidak mengirim `images[]`. Jangan tambah picker/upload gambar di
web tanpa keputusan produk baru.

Gambar kata yang belum diverifikasi: API publik mengembalikan URL
placeholder `placehold.co` - web menampilkan apa adanya lewat
`displayImageUrl` (host non-jsDelivr tidak di-bungkus wsrv).

## Gaya tulisan (wajib)

**JANGAN pernah memakai em dash atau en dash** (Unicode U+2014 dan
U+2013; sering muncul dari copy AI). Selalu pakai hyphen ASCII biasa
(`-`). Berlaku untuk docs, komentar kode, UI copy, meta SEO, dan
JSON-LD di seluruh `web/`.

Contoh benar: `somet bahasa Sambas - arti & terjemahan`, `A-Z`,
`150-160 karakter`.
Contoh salah: memakai strip panjang gaya tipografi buku di antara kata.

### Nada copywriting UI (wajib)

Copy UI (heading, paragraf penjelas, empty state, meta SEO yang berbicara
ke pengunjung) memakai bahasa santai yang memanusiakan. Web publik dibaca
tamu yang tidak kenal istilah teknis, jadi tulis seperti warga Sambas
ngobrol, bukan bahasa prosedural kaku. Poin:

1. Sapaan ke pengunjung: **kamu** (jangan "Anda"). Posesif ringkas boleh:
   `kata favoritmu`, `buka lagi lewat profilmu`.
2. Kalimat penjelas menyebut manfaat, bukan mekanisme sistem:
   - BAD: `Feed thread Ruang Diskusi yang sudah ditayangkan.`
   - GOOD: `Baca obrolan warga yang sudah tayang, kapan saja.`
3. CTA dan empty state memakai ajakan ringan, boleh tambah `ya` bila cocok
   (`Ingin ikut diskusi? Buka lewat aplikasi SambasKu ya.`).
4. Judul halaman, heading navigasi, dan label tetap ringkas netral;
   yang dibuat santai adalah paragraf penjelas, subtitle, dan empty state.
5. Meta description dan JSON-LD tetap mengikuti pola SEO ringkas yang ada;
   aturan santai ini untuk copy yang dibaca manusia di halaman.
6. Sama seperti mobile: tanpa em/en dash, satu partikel santai per kalimat.

Contoh referensi: `web/app/routes/ruang-diskusi.tsx` (paragraf pembuka dan
kartu CTA), `web/app/application/i18n/locales/id.json`.

Sama seperti aturan di `docs/admin/admin-base-stack.md`.

## 1. Tech Stack

| Layer         | Pilihan                                                       | Alasan                                                                    |
| ------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Framework     | React 19 + React Router v7 (framework mode, `ssr: true`)      | Edge SSR: HTML utuh + meta + JSON-LD untuk crawler sebelum hydration      |
| Bahasa        | TypeScript (strict)                                           | Kontrak API dijaga dari domain sampai halaman                             |
| Build         | Vite 6 + `@react-router/dev` + `@cloudflare/vite-plugin`      | Build Worker SSR + aset statis sekali jalan; dev server jalan di workerd  |
| Deploy        | Cloudflare Workers (static assets)                            | SSR butuh Worker, BUKAN Pages; `wrangler deploy` dari config hasil build  |
| UI Library    | **Mantine v9** (`@mantine/core` + `@mantine/hooks`)           | UI kit standar lengkap agar tampilan seragam, bukan komponen custom       |
| Icons         | `lucide-react`                                                | SEMUA tombol wajib berikon (lihat Section 6)                              |
| HTTP client   | `fetch` polos via `apiClient`                                 | Berjalan sama di Edge worker & browser; tanpa axios                       |
| i18n          | `i18next` + `react-i18next` + JSON katalog                    | Multi-bahasa SSR + SEO locale path (`WEB-I18N.md`)                        |
| Fonts         | Plus Jakarta Sans (Google Fonts)                              | Identitas tipografi konsisten dengan mobile                               |

Versi terkunci di `web/package.json`. Upgrade minor aman; upgrade mayor
(React Router 8, Mantine 10) harus dibahas dulu.

## 2. Clean Architecture (empat lapisan)

```text
Presentation (routes/*, presentation/components/*, Mantine)
       ↓
Application (use-cases/*, utils/formatters, utils/seo)
       ↓
Domain (entities/* - tipe murni, tanpa React/Mantine)
       ↑
Infrastructure (api/api-client.ts fetch + envelope, config/env.ts)
```

Aturan keras:

- **Halaman/route TIDAK pernah `fetch` langsung** - selalu lewat use case
  (`word.use-case.ts`) yang memanggil `apiClient`.
- `env.ts` adalah **satu-satunya** pembaca `import.meta.env` di seluruh app
  (termasuk flag `isProd` untuk gating SEO).
- Domain tidak mengimpor React/Mantine - murni TypeScript.
- Import lintas lapisan pakai alias `@/` (path alias ke `app/`), JANGAN
  `../../` relatif.
- `apiClient` otomatis membuka envelope `{ success, data, meta }` dan
  melempar `AppError` / `NotFoundError` / `RateLimitError` (membaca header
  `Retry-After`). Halaman menangkap error dari sini saja.

## 3. Struktur Folder

```text
web/
├── app/
│   ├── root.tsx                    # Layout: MantineProvider + AppShell + ColorSchemeScript + ErrorBoundary
│   ├── entry.server.tsx            # renderToReadableStream (Web Streams untuk workerd)
│   ├── worker.ts                   # Worker entry: createRequestHandler + SECURITY_HEADERS + noindex staging
│   ├── routes.ts                   # pendaftaran route (bukan file-based)
│   ├── routes/
│   │   ├── home.tsx                # /            hero + Kata Hari Ini + A-Z + CTA
│   │   ├── search.tsx              # /search      ?q=&search_in=&word_type=&cursor= (noindex)
│   │   ├── words.tsx               # /words       A-Z grouping + cursor + saring
│   │   ├── words.$id.tsx           # /words/:id   detail + JSON-LD DefinedTerm (prod only)
│   │   ├── reset-password.tsx      # /reset-password (deeplink mobile)
│   │   ├── sitemap[.]xml.ts        # /sitemap.xml dinamis (prod only, staging 404)
│   │   └── robots[.]txt.ts         # /robots.txt dinamis (prod allow, staging disallow)
│   ├── domain/entities/            # word.entity, api.entity (envelope/cursor)
│   ├── application/
│   │   ├── use-cases/              # word.use-case, auth.use-case
│   │   ├── i18n/                   # registry + katalog JSON (WEB-I18N.md)
│   │   └── utils/                  # formatters, seo (ber-locale)
│   ├── infrastructure/
│   │   ├── api/api-client.ts       # fetch + envelope unwrapper + error mapping
│   │   └── config/env.ts           # import.meta.env + mode + isProd
│   └── presentation/
│       ├── styles/app.css          # @import '@mantine/core/styles.css' + font feature
│       ├── components/
│       │   ├── layout/             # header.tsx (logo + Burger/Drawer mobile), footer.tsx
│       │   ├── word/               # search-bar, word-card, word-card-skeleton,
│       │   │                       # word-of-the-day-card, word-type-badge,
│       │   │                       # pronunciation-player
│       │   ├── theme-toggle.tsx    # useMantineColorScheme light/dark
│       │   └── route-progress-bar.tsx  # bar tipis saat navigasi (useNavigation)
│       └── (TIDAK ADA folder ui/)  # pakai @mantine/core langsung
├── public/
│   ├── logo.png                    # logo resmi 512px (dari mobile/logo_prod.png)
│   ├── apple-touch-icon.png        # 180px
│   └── _headers                    # security headers untuk ASET statis
├── wrangler.jsonc                  # main -> app/worker.ts (SOURCE, bukan output)
├── react-router.config.ts          # ssr + buildDirectory "dist" + v8_viteEnvironmentApi
├── vite.config.ts                  # cloudflare({viteEnvironment:{name:'ssr'}}) + proxy /api
└── .github/workflows/deploy-staging.yml
```

## 4. Tema Light/Dark & Anti-FOUC

- `MantineProvider defaultColorScheme="auto"` + `<ColorSchemeScript />` di
  `<head>` + `{...mantineHtmlProps}` di `<html>` (wajib, cegah hydration
  warning). TIDAK ADA script tema custom.
- Toggle: `theme-toggle.tsx` pakai `useMantineColorScheme()` +
  `useComputedColorScheme('light')` - persistensi otomatis via localStorage
  Mantine.
- Warna/komponen STANDAR Mantine (default blue). Tidak ada design token
  custom kecuali `fontFamily` Plus Jakarta Sans di `createTheme` (root.tsx).
- Font dibuat preconnect + stylesheet Google Fonts lewat `links` root.

## 5. i18n (multi-bahasa) - wajib untuk modul baru

Kontrak penuh: [`docs/web/WEB-I18N.md`](./WEB-I18N.md). Ringkas untuk
setiap prompt/fitur `web/`:

| Item | Aturan |
| --- | --- |
| Locale V1 | `id` (default, SEO utama), `id-SBS` (Bahasa Sambas); registry tunggal |
| URL | Selalu prefix `/{locale}/...`; legacy tanpa prefix → 301 ke `id` (prod) |
| SEO | Canonical + hreflang (+ `x-default` → `id`) + sitemap multi-locale; SSR berbahasa locale aktif |
| Katalog | Satu JSON per locale (`locales/id.json`) + key prefix `home_` / `faq_` / … |
| String UI | TIDAK hardcode di komponen setelah halaman di-port; pakai `t('ns:key')` |
| Data API | Lemma/makna/contoh **bukan** string i18n |

Urutan eksekusi: scaffold → SEO shell → port halaman. Implementasi
mengikuti gelombang di `WEB-I18N.md`; jangan campur pola lain
(paraglide, hardcode map, dsb.).

Saat menambah route/komponen baru **sebelum** gelombang port selesai:
letakkan literal di katalog `id` (+ key mirror `id-SBS`) dari awal bila
menyentuh chrome UI, agar tidak menambah utang string.

## 6. Aturan UI Wajib (Mantine + Lucide)

1. **Komponen Mantine standar** - `Button`, `Badge`, `Card`, `TextInput`,
   `PasswordInput`, `SegmentedControl`, `Drawer`, `Skeleton`, `ThemeIcon`,
   `Blockquote`, `Paper`. JANGAN bikin wrapper custom / Tailwind-like.
2. **Semua `Button` wajib ikon Lucide** via `leftSection`/`rightSection`.
   `ActionIcon` untuk tombol ikon-saja (`aria-label` wajib).
3. **Navigasi internal SPA**: komponen polymorphic `component={Link}` +
   `to="..."` (Anchor/Button/Card/Badge/ActionIcon semua mendukung) - JANGAN
   `<a href>` untuk route internal (full reload).
4. **Mobile-first**:
  - Header: nav desktop `visibleFrom="xs"`, Burger + Drawer
     `hiddenFrom="xs"` - menu WAJIB bisa dibuka di HP.
  - `Group` berisi teks panjang selalu `wrap`; hindari `nowrap` di label.
  - Verifikasi di 320/375/390/768px: tidak ada scroll horizontal.
5. **Loading state** (feedback semua aksi):
  - Global: `RouteProgressBar` (root) - aktif saat `useNavigation().state
     !== 'idle'`.
  - List (search/words): `WordListSkeleton` saat `navigation.state ===
     'loading'` di route tersebut.
  - Detail (klik kata terkait): skeleton halaman agar data lama tidak
     tampil sesaat.
  - Aksi form/tombol: prop `loading`/`disabled` Mantine.
6. **Logo resmi**: aset tunggal dari `mobile/logo_prod.png` - dipakai di
   header (`/logo.png`), footer, favicon, apple-touch-icon, dan fallback
   `og:image` (seo.ts). Jangan pakai ikon buku/emoji sebagai logo.
7. Teks UI lewat katalog i18n (`WEB-I18N.md`); ukuran `size="sm"` default
   untuk konten.
8. **Tanpa shadow dekoratif** - konsep visual clean minimalism: permukaan
   datar, batas lewat border tipis dan kontras warna. Shadow mengubah feel
   app, jadi jangan ditambahkan sesuka hati.
  - `Card`/`Paper`: `withBorder` + `shadow="none"` (preseden:
     `word-card.tsx`, `words.$lemma.tsx`).
  - **Dilarang** `boxShadow` / `shadow="xs".."xl"` pada card, item list,
     tile grid, thumbnail, tombol, atau section.
  - **Boleh**: shadow bawaan lapisan melayang (`Menu`, `Popover`,
     dropdown autocomplete, `Modal`, `Drawer`); ring fokus/selected tanpa
     blur.
  - Butuh shadow di luar daftar itu: diskusikan dulu.
9. **Konsistensi UI lintas halaman (WAJIB)** - elemen yang fungsinya sama
   wajib tampak dan terletak sama. Sebelum menambah tombol/kartu/overlay,
   cek pola existing lalu tiru (komponen, posisi, ukuran, style). Contoh:
   toggle tema selalu di lokasi yang sama di semua halaman; kartu overlay
   di atas peta/gambar selalu radius 16 + `withBorder` + `shadow="none"`
   + margin 16. Jangan bikin varian baru dari komponen yang sudah ada
   polanya. Rule: `.cursor/rules/ui-consistency.mdc`.

## 7. SEO (hanya produksi)

**Prinsip: SEO aktif HANYA di build produksi** (`vite build`, mode
`production`). Staging dan dev noindex total supaya tidak terlisting di
search engine. Gating lewat `env.isProd` (mode build), konsumsi di:

| Aspek         | Produksi                                                       | Staging/Dev                                |
| ------------- | -----------------------------------------------                | ----------------------------------------   |
| robots.txt    | `Allow: /` + referensi `/sitemap.xml`                          | `Disallow: /` (route dinamis)              |
| sitemap.xml   | Rute statis (`/`, `/words`, `/faq`) + **semua** lemma published (paginate cursor, max 50×100) | HTTP 404                                   |
| JSON-LD       | Home: `WebSite` + `Organization` + `SearchAction`; `/faq`: `FAQPage`; detail kata: `DefinedTerm` + `BreadcrumbList` | tidak dirender                             |
| meta robots   | canonical self-referencing                                     | `noindex, nofollow`                        |
| Header HTTP   | -                                                             | `X-Robots-Tag: noindex, nofollow` (worker) |
| /search       | `noindex, nofollow` juga (thin content, panduan search engine) | sama                                       |

Aturan tambahan:

- Setiap route export `meta()` yang memanggil `buildMetaTags()` (title,
  description, OpenGraph, Twitter Card, canonical/robots, **hreflang**
  per locale). Path & canonical **termasuk** prefix `/{locale}` (lihat
  `WEB-I18N.md`). og:image fallback ke `/logo.png`. Description
  homepage/~words ~150-160 karakter agar snippet SERP lebih lengkap
  (tanpa keyword stuffing).
- Homepage (prod) menyuntik JSON-LD `@graph`: `WebSite` (nama "Kamus Sambas",
  `SearchAction` → `/{locale}/search?q={search_term_string}`) + `Organization`
  (merek `VITE_APP_NAME`, logo `/favicon-192.png`, `sameAs` Play Store +
  GitHub). **Sitelinks Google tidak dijamin** - schema + nav ke halaman
  indexable (`/{locale}/`, `/{locale}/words`, `/{locale}/faq`) hanya
  membuat eligible.
- Halaman `/{locale}/faq` (indexable): konten misi/tujuan dari katalog
  `faq` (bukan literal hardcoded setelah port) + JSON-LD `FAQPage` (prod).
  Jangan buat FAQ kosong hanya demi schema.
- Detail kata: title/description lewat template katalog `seo` +
  `buildWordSeoCopy()` agar match query seperti `{lemma} bahasa sambas`.
  JSON-LD `@graph`: `DefinedTerm` (`url` kanonis
  `/{locale}/words/{lemma}`, `alternateName`) + `BreadcrumbList`
  (Beranda → Daftar Kata A-Z → lemma) dengan URL ber-locale. Escaping
  `<` → `\u003c` wajib. Lead SSR + breadcrumb UI di bawah H1 memuat
  frasa dari katalog. `og:locale` mengikuti locale aktif (`id_ID` /
  `id_SBS`) + `og:locale:alternate`; Twitter `summary_large_image` bila
  halaman punya gambar kata.
- SSR harus tetap mengandung teks konten **dan** chrome ber-locale di
  HTML awal - jangan memindah render penting atau ganti bahasa hanya di
  client-only (`useEffect` fetch / post-hydrate i18n).
- Keyword aplikasi hidup di title/description katalog `seo` - JANGAN
  meta keywords stuffing.
- Sitemap prod: URL × locale indexable; pasangan hreflang di HTML wajib.

## 8. Security

- `public/_headers`: CSP, HSTS, X-Frame-Options, dll - **hanya untuk aset
  statis** (Workers static assets).
- Respons SSR (HTML, sitemap, robots) di-append `SECURITY_HEADERS` di
  `worker.ts` (nilai identik `_headers`) karena `_headers` tidak menyentuh
  respons Worker.
- CSP `connect-src` mengizinkan `https://sambasku.iamutaki.com` +
  staging. Domain API baru harus ditambahkan di kedua tempat.
- Tidak ada secret di bundle - `VITE_*` hanya nilai publik.

## 9. Env & Environment

`env.ts` memilih default per-runtime: server (Edge) memakai URL API absolut,
browser memakai `/api/v1` (dev: proxy Vite same-origin ke staging, bebas
CORS; prod: reverse proxy).

| Mode        | File                | `VITE_APP_URL`                               | SEO   |
| ----------- | ------------------- | -------------------------------------------- | ----- |
| development | `.env.development`  | `http://localhost:5173`                      | off   |
| staging     | `.env.staging`      | `https://sambasku-web-staging.iamutaki.com`  | off   |
| production  | `.env.production`   | `https://sambasku.iamutaki.com`              | on    |

`wrangler.jsonc` TIDAK memakai `vars` runtime - semua nilai di-inline saat
build dari file env.

## 10. Build, Deploy & CI

| Command              | Fungsi                                                                |
| -------------------- | --------------------------------------------------------------------- |
| `pnpm dev`           | Dev server SSR di workerd (port 5173, proxy `/api` ke staging)        |
| `pnpm typecheck`     | `react-router typegen && tsc -b`                                      |
| `pnpm lint`          | ESLint (0 warning)                                                    |
| `pnpm build`         | Build produksi - `dist/client` (aset) + `dist/server` (Worker config) |
| `pnpm build:staging` | Sama, mode staging (`.env.staging` ter-inline, noindex)               |

Deploy (bukan Pages): `wrangler deploy --config dist/server/wrangler.json
--name sambasku-web-staging` (staging) atau tanpa `--name` untuk produksi
(`sambasku-web`). CI: `.github/workflows/deploy-staging.yml` di submodule
`web/` (trigger push branch `staging`).

Custom domain: Worker `sambasku-web-staging` di-binding sekali ke
`sambasku-web-staging.iamutaki.com` (Cloudflare dashboard - Workers &
Pages - sambasku-web-staging - Settings - Domains & Routes, atau tambahkan
`"routes": [{"pattern": "sambasku-web-staging.iamutaki.com",
"custom_domain": true}]` di `wrangler.jsonc`).

### Gotcha konfigurasi (jangan diulang)

- `wrangler.jsonc` `main` menunjuk **source** `./app/worker.ts` (plugin
  Cloudflare v1.x memvalidasi keberadaan file saat config load - menunjuk
  output build = deadlock).
- `react-router.config.ts` wajib `buildDirectory: "dist"` + `future.
  v8_viteEnvironmentApi: true` agar RR7 membaca outDir environment `ssr`
  milik plugin Cloudflare.
- `vite.config.ts` wajib `optimizeDeps.include` untuk react/react-dom/
  react-router/@mantine/core/@mantine/hooks/lucide-react - tanpa ini
  optimizer menjalankan dua pass dan browser memuat DUA copy React
  ("Invalid hook call").
- TS config wajib `rootDirs: [".", "./.react-router/types"]` (resolve
  `./+types/*` typegen) + `types: ["vite/client", ...]`.

## 11. Analytics (GA4)

Product analytics web memakai **Google Analytics 4 (gtag)** saja. Jangan
pasang PostHog / Amplitude / custom event API spekulatif. Nama event
diselaraskan dengan mobile (`docs/mobile/mobile-base-stack.md` Section 15)
untuk funnel lintas platform.

### Stack

| Item | Pilihan |
| --- | --- |
| Tag | gtag.js + Measurement ID `VITE_GA_MEASUREMENT_ID` |
| Abstraksi | `app/infrastructure/analytics/analytics.ts` (`trackEvent`, `trackPageView`) |
| Bootstrap SPA | `GoogleAnalytics` di `app/root.tsx` (page_view tiap navigasi) |
| Environment | **Produksi saja** (`env.isProd` + ID non-kosong). Staging/dev no-op |

Komponen / route **tidak** memanggil `window.gtag` langsung. Semua lewat
`trackEvent` / `trackPageView`.

### Aturan event (wajib)

1. Nama: `snake_case`, pendek, tanpa PII (no email; `word_id` / `lemma`
   publik boleh).
2. **Setiap fitur web baru atau perubahan perilaku user-facing WAJIB
   memasang analitik di PR yang sama** (lihat DoD di bawah).
3. Jangan log isi form kontribusi / isi komentar mentah.
4. Uji di GA4 **Realtime** atau **DebugView** (`?ga_debug=1` di URL
   produksi setelah deploy).

### Wajib update event tiap perubahan halaman / fitur

Setiap kali ada **halaman baru**, **ubah alur UI**, atau **tambah fitur
interaktif** di `web/`, PR yang sama **wajib** mengirim event ke GA4 dan
mencatatnya di dokumen ini. Jangan anggap UI selesai jika analitik belum
ada.

Trigger yang mewajibkan update:

| Perubahan | Yang harus dilakukan |
| --- | --- |
| Route / halaman baru | Pastikan `page_view` SPA tetap jalan; tambah event interaksi utama halaman (buka, submit, tap CTA) |
| Fitur / aksi user baru (cari, share, form, toggle, ...) | Tambah `trackEvent(...)` di call site sukses (dan gagal bila relevan untuk funnel) |
| Ubah nama/params event yang sudah ada | Update `AnalyticsEvents` + baris di tabel di bawah + call site |
| Hapus / nonaktifkan fitur | Hapus atau tandai event terkait di tabel agar tidak orphan |

Langkah PR (urut):

1. Tentukan nama event (`snake_case`) + params (tanpa PII).
2. Tambah konstanta di `AnalyticsEvents`
   (`app/infrastructure/analytics/analytics.ts`).
3. Panggil `trackEvent` / pastikan `page_view` di titik aksi (bukan di
   komponen presentasi generik tanpa konteks).
4. **Catat baris baru/ubah di tabel event kanonik Section 11** di file
   ini - tabel adalah sumber kebenaran untuk review.
5. Centang DoD analytics di bawah sebelum merge.

Tanpa langkah 2-4, fitur dianggap **belum selesai**.

### Tabel event kanonik (P0 web)

| Event | Kapan | Params kunci |
| --- | --- | --- |
| `page_view` | tiap navigasi SPA | `page_path`, `page_title`, `page_location` |
| `search_submit` | hasil `/search` dengan `q` | `query_len`, `search_in`, `has_results` |
| `wotd_tap` | ketuk kata hari ini | `word_id` |
| `word_open` | buka detail kata | `word_id`, `source` (`direct`/`search`/`wotd`/`letter`/`list`/`related`) |
| `audio_play` | putar lafal | `word_id`, `has_audio` |
| `contribute_start` | buka form `/kontribusi` | `guest`, `from` |
| `contribute_submit` | tekan kirim | `guest` |
| `contribute_success` | usul diterima API | `guest` |
| `contribute_fail` | usul gagal | `guest`, `error_code` |
| `letter_browse` | buka indeks `/huruf/:letter` | `letter` |
| `theme_change` | ganti tema | `mode` |
| `locale_change` | ganti bahasa UI | `from`, `to` |
| `discussion_view` | buka feed/detail Ruang Diskusi | `view`, `discussion_id` (detail), `sort` (feed) |

Event mobile-only (map, vote deck, bookmark app, notifikasi, onboarding,
moderasi) **tidak** di web sampai fiturnya ada.

### Definition of Done fitur web (analytics)

- [ ] Event baru tercantum di tabel Section 11
- [ ] Konstanta di `AnalyticsEvents` + pemanggilan `trackEvent` ada
- [ ] Tidak ada PII di params
- [ ] Halaman SPA baru tercakup `page_view` (otomatis lewat `GoogleAnalytics`)

### Checklist Console GA4 (manual, setelah deploy)

- [ ] Realtime / DebugView menampilkan hit dari `https://sambasku.com`
- [ ] Events muncul di Admin → Data display → Events
- [ ] Custom definitions didaftarkan bila laporan perlu filter param
      (`source`, `search_in`, `letter`, ...)
- [ ] **Annotations** ditambah manual untuk milestone rilis (bukan dari
      kode/CI) - mis. "GA4 events P0 web live"
- [ ] Key events (opsional): `search_submit`, `contribute_success`

## 12. Checklist Verifikasi Fitur Baru

- [ ] `pnpm typecheck`, `pnpm lint`, `pnpm build` hijau
- [ ] SSR berisi konten: `curl -s localhost:5173/<route> | grep <teks>` -
      termasuk title/og/canonical bila halaman SEO-sensitive
- [ ] SEO gating: staging/dev menyajikan `robots: noindex`, sitemap 404,
      robots.txt disallow (uji `curl localhost:5173/robots.txt`)
- [ ] Hydration bersih (console browser tanpa "Invalid hook call" /
      hydration warning)
- [ ] Light & dark mode rapi (toggle di header), tanpa FOUC saat refresh
- [ ] Mobile 375px: menu Burger jalan, tidak ada scroll horizontal
- [ ] Ada loading feedback (progress bar / skeleton / tombol loading)
- [ ] Semua tombol berikon Lucide; navigasi internal pakai `component={Link}`
- [ ] i18n: string chrome lewat katalog; link internal mempertahankan
      `/{locale}`; meta/hreflang benar bila halaman indexable (lihat
      `WEB-I18N.md`)
- [ ] Analytics: tiap halaman/fitur baru atau ubah alur UI - update
      `AnalyticsEvents` + `trackEvent` + baris di tabel Section 11
      (lihat "Wajib update event tiap perubahan halaman / fitur")

## 13. Referensi Terkait

- `docs/backlogs/CACHE.md` - backlog cache HTML edge + JSON API (draft;
  belum diimplementasi)
- `docs/web/WEB-I18N.md` - kontrak multi-bahasa + SEO locale
- Bagikan kartu kata **eksklusif mobile** (tidak ada di web):
  `docs/mobile/11-mobile-share-card.md`
- `docs/api/api-base-stack.md` - envelope response + cursor pagination
- `docs/api/18-api-list-words.md` + `docs/web/01-web-list-words.md` -
  kontrak halaman `/words`
- `docs/api/28-api-word-of-the-day.md` - kontrak `/words/today`
- `docs/api/12-api-search-miss-contribute.md` - pencarian utama & search miss
- `docs/api/29-api-pronunciation-audio.md` - audio lafal
- `docs/mobile/mobile-base-stack.md` Section 15 - event kanonik mobile
- `mobile/logo_prod.png` - sumber aset logo resmi
