# Cache Web (kontrak v1 - draft)

Status: **backlog / draft kontrak**. Belum diimplementasi. Angka TTL,
prioritas endpoint, dan detail lapisan boleh direvisi sebelum build.
Induk: [`CACHE.md`](CACHE.md).

Tujuan: mengurangi hit Worker -> API pada free-tier (Cloudflare Workers
subrequest budget, Render cold start, rate limit publik) tanpa merusak
SSR/SEO.

Pasangan kebijakan mobile: [`CACHE-MOBILE.md`](CACHE-MOBILE.md).
Matriks TTL di Section 3 **wajib sama** di kedua dokumen.

## 1. Non-goals

- Browser `localStorage` sebagai inti penghematan API untuk first-hit
  SSR / crawler (itu Layer C, secondary).
- Cache HTML panjang di browser (asset hash deploy akan 404). Respons ke
  browser tetap `Cache-Control: no-cache` untuk HTML SSR.
- ETag / 304 dari origin API (belum didukung; fase 1 TTL + SWR).
- Cache mutation (POST kontribusi, auth delete/reset).

## 2. Tiga lapisan cache

| Layer | Apa | Di mana | Mengurangi hit API? | Status |
| --- | --- | --- | --- | --- |
| **A** | HTML / XML SSR SWR | `caches.default` di [`web/app/worker.ts`](../../web/app/worker.ts) | Ya (skip render + loader fetch) | Ada partial; **P0 perbaiki locale** |
| **B** | JSON GET API | Cache API / wrapper di sekitar `apiClient` | Ya (SSR tetap, API skip) | Belum; target utama setelah A hidup |
| **C** | Browser storage | localStorage / IndexedDB | Lemah untuk first-hit SSR | Opsional; reference / recently viewed |

Untuk free-tier, investasi utama = **A lalu B**. C tidak menggantikan B.

Alur baca Layer B (sama filosofi mobile):

```text
loader butuh JSON
  -> ada entry dan age <= fresh?  -> pakai cache (0 hit API)
  -> fresh < age <= staleMax?     -> pakai stale + revalidate (waitUntil)
  -> miss atau hard expired?      -> fetch API sync -> put -> pakai
```

## 3. Empat lapisan invalidation (ambang batas)

| Lapisan | Kondisi | Efek ke API |
| --- | --- | --- |
| L1 Fresh | `age <= freshSeconds` | 0 hit |
| L2 SWR | `fresh < age <= staleMax` | 1 hit background |
| L3 Hard expiry | `age > staleMax` | 1 hit sync wajib |
| L4 Event | bump schema / (fase 2) content epoch | hapus atau bypass key |

### Matriks TTL kanonik (JSON Layer B + kebijakan bersama)

| Kelas | Contoh endpoint | `fresh` | `staleMax` |
| --- | --- | --- | --- |
| Rujukan statis | `/languages`, `/word-classes`, `/dialects` | 24 jam | 7 hari |
| Detail kamus | `/words/:id`, `/words/lemma/:lemma` | 5 menit | 24 jam |
| Feed / list | `/words/latest`, `/words` (page) | 2 menit | 1 jam |
| Word of day | `/words/today` | sampai batas hari (atau max 1 jam) | 24 jam |
| Search | `/words/search` | 1 menit | 30 menit |
| Sosial publik | discussion published | 1 menit | 30 menit |
| Negative 404 | lemma/id tidak ada | 2 menit | 2 menit (tanpa SWR) |
| User / private | profil yang butuh sesi, mutasi | jangan cache | - |

### Layer A (HTML) - TTL yang sudah ada di worker

Selaras kode `worker.ts` hari ini (boleh diselaraskan lagi saat revisi):

| Path (setelah strip locale) | Fresh | Stale max |
| --- | --- | --- |
| `/` (beranda) | 60 detik | 24 jam |
| `/words/:lemma` | 60 detik | 24 jam |
| `/sitemap.xml` | 24 jam | 24 jam |

HTML fresh 60 detik lebih ketat dari JSON detail 5 menit: Layer A
melindungi traffic beranda/crawler; Layer B melindungi subrequest API
di route yang HTML-nya bypass.

### Trade-off multi-visitor

Tanpa content epoch server, visitor lain bisa melihat HTML/JSON stale
sampai jendela fresh (atau sampai SWR selesai). Diterima fase 1.
Fase 2: epoch / purge Cache API saat publish (catat di docs API, jangan
kerjakan sekarang).

## 4. Layer A - HTML edge SWR (P0)

Kode ada di `web/app/worker.ts`. Masalah produksi yang harus disebut di
kontrak implementasi:

1. **Locale:** route nyata `/{locale}/...`. `isCacheable` harus memakai
   `stripLocalePrefix` (lihat `web/app/application/i18n/locales.ts`)
   supaya `/id` dan `/id/words/capal` masuk cache, bukan hanya `/` dan
   `/words/...`.
2. **Cache key:** origin + **pathname saja** (buang query string) +
   `__build=<CF_VERSION_METADATA.id>`. Query unik = cache flooding
   (pentest W-03 / B-03).
3. **Sitemap:** key tanpa query; sadari satu build sitemap bisa hingga
   ~10 subrequest API (batas free-tier Workers).
4. **Ke browser:** tetap `Cache-Control: no-cache`, jangan expose
   `x-cached-at` ke klien; `x-cache: hit|swr|miss|bypass` boleh untuk
   debug.
5. **Tidak cacheable HTML:** list `/words` berfilter, `/search`, form
   kontribusi, auth pages, HEAD (atau cache HEAD terpisah jika nanti
   ditambah).

## 5. Layer B - JSON API edge cache

### Penempatan

Wrapper di sekitar [`web/app/infrastructure/api/api-client.ts`](../../web/app/infrastructure/api/api-client.ts)
untuk **GET idempotent publik** saja. Use-case tetap memanggil
`apiClient`; caching transparan di infrastructure.

Jangan cache di route loader secara ad-hoc per halaman (duplikasi TTL).

### Keying

- Logical key: `GET|/api/v1/...|normalizedQuery` **tanpa host tier**,
  supaya failover Deno/Render tidak memaksa miss sia-sia.
- Normalisasi query: sort keys, buang param kosong / tracking.
- Value: body JSON (envelope atau `data` saja - pilih satu, konsisten)
  + metadata `cachedAt` (header internal `x-cached-at` di entry Cache
  API, tidak wajib ke browser).

### SWR

Pola sama HTML: jika stale, sajikan cached response dan
`ctx.waitUntil(revalidateAndPut)`. Di jalur browser (bukan Worker),
background revalidate cukup fire-and-forget tanpa memblokir UI, atau
skip SWR dan treat sebagai soft miss - pilih satu di PR implementasi
dan dokumentasikan.

### Prioritas JSON (implementasi nanti)

1. `/languages`, `/word-classes`, `/dialects` (hari ini 3 hit tiap buka
   `/kontribusi`).
2. `/words/today`.
3. `/words/lemma/:lemma` (dan `/words/:id` bila dipakai).
4. Translation-help published list/detail.
5. Opsional: halaman pertama `/words` tanpa filter berat.

Hindari: `/words/search` dengan cardinality tinggi (atau batasi last-N /
TTL sangat pendek), profil user dinamis, semua POST.

### Negative 404

Lemma acak / crawl abuse: negative-cache singkat (2 menit) agar tidak
menghantam API berulang. Jangan SWR negative entry.

### Rate limit

429 dari API: **jangan** failover ke tier lain untuk menembus limit
(sudah aturan `apiClient`). Jangan `put` body 429 sebagai sukses.

## 6. Layer C - browser storage (secondary)

Boleh untuk:

- Reference kecil (languages / word-classes / dialects) agar navigasi
  klien ulang tidak menunggu edge.
- Recently viewed lemmas (UX saja).

Jangan mengandalkan C untuk SEO atau first paint SSR. Jangan simpan
PII / token (web publik hampir tanpa auth token; tetap waspada).

## 7. Checklist sebelum implementasi

- [ ] P0 Layer A: locale matcher + key tanpa query diverifikasi di staging
      (`x-cache: hit` pada `/id` dan `/id/words/<lemma>`).
- [ ] Matriks Section 3 masih disepakati PO.
- [ ] Layer B hanya membungkus GET publik; tes failover tetap jalan.
- [ ] Sitemap tidak bisa di-flood lewat query unik.
- [ ] Pentest regression: tidak mengembalikan `x-cached-at` ke browser
      pada HTML.

## 8. Referensi

- Induk backlog: [`CACHE.md`](CACHE.md)
- [`../web/web-base-stack.md`](../web/web-base-stack.md) - stack SSR
- [`CACHE-MOBILE.md`](CACHE-MOBILE.md) - pasangan mobile
- [`../api/api-base-stack.md`](../api/api-base-stack.md) Section 15, 24
- [`../pentest/web/02-BLACK.md`](../pentest/web/02-BLACK.md) - B-02 locale
  cache mati, B-03 sitemap query
- Kode: `web/app/worker.ts`, `web/app/infrastructure/api/api-client.ts`
