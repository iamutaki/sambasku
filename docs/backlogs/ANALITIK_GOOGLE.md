# ANALITIK GOOGLE - Trafik Web (GA4 + Search Console) di console

Dokumen backlog. Integrasi **Google Analytics 4** dan **Google Search
Console** ke modul **Analitik** console. GA4 dan Search Console cuma
data provider di belakang sistem, bukan menu.

## Status

| Item | Status |
| --- | --- |
| Fase 0 - sub menu Analitik + scrollbar sidebar tipis | Selesai |
| Fase 1 - UI Trafik Web (tab, rentang tanggal, state) + fake provider | Selesai |
| Fase 2 - `Ga4Provider` (Analytics Data API) | Selesai (belum diuji dengan kredensial) |
| Fase 3 - `SearchConsoleProvider` (Search Console API) | Selesai (belum diuji dengan kredensial) |
| Fase 4 - cache TTL, pemetaan error, Bruno | Selesai |
| Fase 5 - unit test provider/use case/route/console | Selesai; uji integrasi staging belum |

## Keputusan

- Sidebar: `Analitik` jadi grup berisi:
  - `Ringkasan` - halaman operasional existing (`/dashboard`), tidak diubah.
  - `Trafik Web` - `/dashboard/traffic`, satu halaman dengan tab
    `Ikhtisar`, `Pengunjung`, `Perilaku`, `Pencarian`, `Sumber Trafik`.
- Tab ringkasan GA4 + GSC dinamai `Ikhtisar` supaya tidak bentrok dengan
  sub menu `Ringkasan`. Grup Kamus sudah punya menu `Pencarian`
  (search misses), jadi tab GA/GSC tidak dijadikan item sidebar.
- Koneksi Google: **service account** lewat env di API. JWT RS256
  ditandatangani manual dengan Web Crypto (pola yang sama dengan FCM),
  tanpa dependency baru. Tombol "Hubungkan" di console cuma menampilkan
  panduan setup.
- Akses: hanya `root` dan `admin`. Reviewer tidak melihat Trafik Web.

## Arsitektur

```text
Console (tab Trafik Web)
  -> GET /api/v1/admin/web-analytics/{section}?range=&start=&end=
    -> GetWebAnalyticsUseCase (TTL cache in-memory per section+range)
      -> VisitorAnalyticsProvider  (Ga4Provider | FakeProvider)
      -> SearchAnalyticsProvider   (SearchConsoleProvider | FakeProvider)
        -> getGoogleServiceAccountToken(scope)
          -> Google API
```

- `section`: `overview | visitors | behavior | search | sources`.
- Response per provider: `{ status: 'ok' | 'empty' | 'not_configured' |
  'error', error_code?, data? }`. Satu provider gagal tidak menjatuhkan
  provider lain (`Promise.allSettled`).
- Response Google dinormalisasi di provider; UI tidak pernah melihat
  struktur mentah Google.
- `InternalAnalyticsProvider` (data internal SambasKu: kata paling
  sering dibuka, wisata populer, kontribusi, dll.) bisa ditambah
  sebagai provider baru tanpa mengubah kontrak UI. **Belum dibuat.**

## Setup kredensial

1. Buat service account di Google Cloud, aktifkan **Google Analytics
   Data API** dan **Google Search Console API**.
2. Buat key JSON, isi env API:
   - `GOOGLE_ANALYTICS_SA_EMAIL` = `client_email`
   - `GOOGLE_ANALYTICS_SA_PRIVATE_KEY` = `private_key` (boleh `\n`)
   - `GA4_PROPERTY_ID` = angka property GA4 (bukan `G-XXXX`)
   - `SEARCH_CONSOLE_SITE_URL` = `sc-domain:sambasku.com` atau
     `https://sambasku.com/`
3. GA4: Admin > Property access management > tambah email service
   account sebagai **Viewer**.
4. Search Console: Settings > Users and permissions > tambah email
   service account (Restricted cukup).
5. Opsional: `GA4_CACHE_TTL_SECONDS` (default 1800),
   `SEARCH_CONSOLE_CACHE_TTL_SECONDS` (default 21600).
6. Lokal tanpa kredensial: `WEB_ANALYTICS_FAKE=true` (diabaikan di
   production) untuk melihat UI dengan data palsu.

Credential tidak pernah dikirim ke console/frontend.

## Error per provider

| Kondisi | Kode |
| --- | --- |
| Env belum di-set | `GA4_NOT_CONFIGURED` / `SEARCH_CONSOLE_NOT_CONFIGURED` |
| 401/403 dari Google | `*_PERMISSION_DENIED` |
| 429 | `*_RATE_LIMITED` |
| 5xx / respons aneh | `*_UPSTREAM_ERROR` |
| Gagal jaringan | `*_NETWORK_ERROR` |
| Request valid, data kosong | status `empty` (bukan error) |

## Base prompt (dirapikan)

### Prinsip utama

- Jangan buat menu baru "Google Analytics", "GA4", atau "Search
  Console". Satu pusat analitik SambasKu, provider di belakang.
- Pertahankan modul Analitik existing, jangan redesign besar. Reuse
  component, layout, state management, routing, API layer, design system.

### Tujuan tiap tab

- **Ikhtisar**: GA4 (active users, users, sessions, page views, event
  count) + GSC (clicks, impressions, CTR, average position). KPI cards,
  perubahan vs periode sebelumnya, chart tren, top pages, top queries.
  Jangan tampilkan semua data sekaligus.
- **Pengunjung** (GA4): active users, total users, sessions, new users,
  page views, device category, country. Urutan: KPI, tren pengguna,
  device, country. Pakai tabel kalau lebih mudah dibaca.
- **Perilaku** (GA4): top pages, page views, landing pages, events,
  event count, engagement.
- **Pencarian** (GSC): clicks, impressions, CTR, average position, chart
  performa per tanggal (clicks + impressions), top queries, top pages
  dari pencarian. Label tab "Pencarian", sumber sebagai metadata kecil
  ("Google Search Console · 28 hari terakhir").
- **Sumber Trafik** (GA4): Organic Search, Direct, Social, Referral,
  Other dalam persen. Visual sederhana.

### Rentang tanggal

- 7 hari, 28 hari, 90 hari, custom. Default 28 hari terakhir.
- Pembanding: periode yang sama panjang tepat sebelumnya.
- Perubahan ditampilkan `naik 12.5%` / `turun 4.2%` dengan konteks
  baik/buruk yang jelas (posisi rata-rata: turun = bagus).

### UI/UX

- Ikuti design system console (Ant Design). Clean, minimal, tidak
  terlalu banyak card dan warna, chart sederhana, tabel untuk detail.
- Prioritas visual: KPI penting, tren, ranking/tabel, detail.

### State

Bedakan: loading (skeleton sesuai layout), empty, not configured
(dengan tombol "Hubungkan"), error (pesan jelas + "Coba lagi", tanpa
stack trace), success. Error API bukan data kosong.

### Arsitektur dan keamanan

- Jangan panggil Google API dari UI. UI -> API service -> provider ->
  Google API.
- DTO ternormalisasi: overview, trend, page, query, traffic source.
- GA4 Data API: `activeUsers, totalUsers, newUsers, sessions,
  screenPageViews, eventCount, engagementRate`; dimensi `date,
  pagePath, landingPage, eventName, deviceCategory, country,
  sessionDefaultChannelGroup`. Ambil seperlunya, pakai limit.
- Search Console API: `query, page, date` + `clicks, impressions, ctr,
  position`. Bisa filter tanggal, page, query.
- Credential (private key, token) hanya di server, lewat env.
  `.env.example` pakai placeholder.
- Akses hanya untuk admin yang berwenang (sistem auth existing).

### Caching

Jangan hit Google tiap pindah tab. Prioritas cache: Search Console
(paling lama) > GA4 historis > GA4 realtime (tidak dipakai). Cache
in-memory per isolate cukup untuk sekarang.

### Performance

Hindari request berulang, fetch seluruh dataset, chart yang tidak
perlu, request per component, dan waterfall. Request paralel bila bisa,
limit untuk tabel.

### Testing

- Provider: sukses, kosong, error API, error autentikasi.
- Service: agregasi, normalisasi, rentang tanggal, periode pembanding.
- UI: loading, empty, error, success, disconnected (lewat pure
  function karena vitest console berjalan di env node).
- Tidak butuh kredensial production; pakai mock/fake provider.

### Larangan

Menu khusus GA4/Search Console, expose credential, commit credential,
Google API call di UI, arsitektur baru kalau yang lama cukup, refactor
besar yang tidak terkait, dependency untuk hal sederhana, chart
dekorasi, ambil semua data Google, anggap data kosong sebagai error.

## Lanjutan (belum)

- Uji integrasi dengan kredensial staging.
- `InternalAnalyticsProvider` (pencarian kata, kata populer, wisata
  populer, kontribusi) saat dibutuhkan.
- Cache lintas isolate (KV) kalau API jalan multi-instance dan kuota
  Google mulai mepet.
