# API - Latar Kartu Share (Pixabay + Openverse + Unsplash)

Mengikuti `api-base-stack.md`: Section 8 (port provider eksternal), 9
(OpenAPI), 11 (`/api/v1/`), 13 (envelope), 15 (rate limit), 20 (Bruno).

Backlog: [`../backlogs/SHARE.md`](../backlogs/SHARE.md),
[`../backlogs/SHARE_VIDEO.md`](../backlogs/SHARE_VIDEO.md).
Env: [`../env/unsplash.md`](../env/unsplash.md),
[`../env/pixabay.md`](../env/pixabay.md) (lokal, gitignored).
Openverse anonim.

**Pexels dan Wikimedia dihapus** dari Media Explorer (tidak punya flag
safe-search yang andal). Gambar kata lama dengan provider tersebut tetap
valid di allowlist stock.

---

## Tujuan

Mobile / console butuh foto **dan** video latar untuk kartu share /
gambar kata. Kunci vendor **tidak** boleh di client. API mem-proxy
Pixabay (foto + video), Openverse dan Unsplash (foto), cache 24 jam,
mengembalikan URL + atribusi.

Ini **lookup saja**: tidak menulis DB, tidak generate PNG/MP4/OG.

---

## Flow

```
[Mobile / Console Media Explorer]
        │  GET /api/v1/share/backgrounds
        │    ?q=&page=&sort=&provider=&limit=&media=&orientation=
        ▼
[ListShareBackgroundsUseCase]
        │  denylist q? → 400
        │  cache hit? → items
        │  else provider.search(...)
        ▼
[Pixabay | Openverse | Unsplash]
        ▼
[Envelope { success, data: { provider, query, page, cache_hit,
  degraded, media, items[] } }]
```

Query dari client: **padanan + kategori** (bukan lemma Sambas).
Contoh lemma `makatn` → `q=makan makanan`.

---

## Keputusan produk

1. **Publik** (tanpa auth). Rate 30/menit per IP.
2. **Tanpa key / gagal upstream → 200 + `items: []` + `degraded: true`**,
   bukan 5xx. Openverse selalu terdaftar (tanpa kunci vendor).
3. Cache in-memory per
   `v2:{provider}:{media}:{sort}:{q|popular}:{page}:{limit}:{orientation|any}`,
   TTL default 86400 dtk.
4. `limit` 1-30 (default 3).
5. Default: **Pixabay**. Provider lain lewat Media Explorer.
6. `unsplash` / `openverse` + `media=video` → 400, field `media`.
7. Atribusi wajib: `photographer`, `username`, `attribution_url`.
   `unsplash_url` tetap sebagai alias (backward-compat).
8. **Safe search always-on** (tanpa toggle UI):
   - Pixabay: `safesearch=true`; popular → `editors_choice=true`
   - Unsplash: `content_filter=high` (search + popular via search)
   - Openverse: `mature=false` saja (jangan kirim `unstable__include_sensitive_results`
     bersama `mature`, upstream membalas 400), `license=cc0,pdm,by`,
     plus drop hasil mature/sensitive dan lisensi di luar allowlist.
     BY-SA dikeluarkan (kartu share = karya turunan, ikut wajib BY-SA),
     BY-NC dikeluarkan (bentrok donasi/monetisasi).
   - Query denylist singkat (EN/ID) → 400 field `q`

---

## Endpoint

```
GET  /api/v1/share/backgrounds
GET  /api/v1/share/background-providers
POST /api/v1/share/backgrounds/unsplash/download
```

### Query backgrounds

| Query | Aturan |
| ----- | ------ |
| `q` | wajib jika `sort=relevant`; trim 1-120; opsional jika `popular` |
| `page` | int ≥ 1, default `1` |
| `sort` | `relevant` (default) atau `popular` |
| `provider` | `pixabay` (default), `openverse`, `unsplash` |
| `limit` | 1-30, default `3` |
| `media` | `photo` (default) atau `video` |
| `orientation` | opsional: `portrait` / `landscape` / `square` |

### 200 sukses (foto)

```json
{
  "success": true,
  "data": {
    "provider": "pixabay",
    "query": "makan makanan",
    "page": 1,
    "cache_hit": false,
    "degraded": false,
    "media": "photo",
    "items": [
      {
        "id": "pixabay-photo-1",
        "kind": "photo",
        "provider": "pixabay",
        "url": "https://cdn.pixabay.com/photo/...",
        "preview_url": "https://cdn.pixabay.com/photo/...",
        "width": 1080,
        "height": 1620,
        "duration_seconds": 0,
        "mime_type": "image/jpeg",
        "photographer": "Ada Lovelace",
        "username": "ada",
        "attribution_url": "https://pixabay.com/photos/...",
        "unsplash_url": "https://pixabay.com/photos/..."
      }
    ]
  }
}
```

### Field tambahan Openverse (Creative Commons)

Item `provider: "openverse"` membawa field opsional:

| Field | Contoh |
| ----- | ------ |
| `license` | `CC BY 2.0`, `CC0 1.0`, `Public Domain Mark 1.0` |
| `license_url` | `https://creativecommons.org/licenses/by/2.0/` |
| `source` | `flickr` (sumber asli; Openverse hanya agregator) |

`attribution_url` = halaman sumber asli (`foreign_landing_url`).
Kredit CC wajib di UI dan ikut tercetak di PNG kartu share
(watermark dikunci menyala), mis. `Foto: Ada (CC BY 2.0, diubah) / Flickr`.
"diubah" hanya untuk CC BY (foto dipotong / ditimpa teks).

### 200 sukses (video Pixabay)

`kind` = `video`. `url` = MP4. `preview_url` = poster. `duration_seconds`
≥ 1. `mime_type` = `video/mp4`. `unsplash_url` = alias `attribution_url`.

`items` boleh kosong. `degraded: true` = provider belum dikonfigurasi
atau upstream gagal.

### 400

`VALIDATION_ERROR` - `q` kosong (saat relevant) / terlalu panjang /
query diblok / `page` invalid / `media=video` pada Unsplash atau Openverse
(`Provider ini tidak mendukung video.`).

### 429

`RATE_LIMITED` - 30/menit.

### GET `/background-providers`

```json
{
  "success": true,
  "data": {
    "providers": [
      { "id": "pixabay", "label": "Pixabay", "available": true, "media": ["photo", "video"] },
      { "id": "openverse", "label": "Openverse", "available": true, "media": ["photo"] },
      { "id": "unsplash", "label": "Unsplash", "available": true, "media": ["photo"] }
    ]
  }
}
```

`available: false` jika kunci belum di-set (Pixabay/Unsplash).
Openverse `available: true` tanpa kunci.

### POST `/backgrounds/unsplash/download`

Wajib menurut Unsplash API Guidelines (Triggering Downloads): client
memanggil ini saat user **memilih** foto Unsplash di Media Explorer.
API mem-proxy `GET https://api.unsplash.com/photos/{id}/download` dengan
Access Key (kunci tidak pernah ke client).

Body: `{ "id": "<id item Unsplash>" }` - regex `^[A-Za-z0-9_-]{1,64}$`.

```json
{ "success": true, "data": { "tracked": true } }
```

`tracked: false` = kunci belum di-set atau upstream gagal (tetap 200).
400 `VALIDATION_ERROR` field `id`. Rate limit sama (30/menit).

### Atribusi Unsplash di client

Saat foto Unsplash tampil (Media Explorer, sheet Bagikan), client wajib
menampilkan "Foto oleh {photographer} di Unsplash" dengan link UTM:

- `https://unsplash.com/@{username}?utm_source=sambasku&utm_medium=referral`
- `https://unsplash.com/?utm_source=sambasku&utm_medium=referral`

Gambar Unsplash di-hotlink langsung dari `images.unsplash.com` (bukan
proxy wsrv.nl).

---

## Env

| Var | Wajib | Default |
| --- | ----- | ------- |
| `UNSPLASH_ACCESS_KEY` | tidak | kosong → Unsplash degraded |
| `PIXABAY_API_KEY` | tidak | kosong → Pixabay degraded |
| `SHARE_BACKGROUNDS_CACHE_TTL_SECONDS` | tidak | `86400` |

Staging (`--env staging`) dan produksi (tanpa `--env`, Worker `sambasku-api`). Unsplash hanya Access Key, bukan Secret Key.

```bash
npx wrangler secret put UNSPLASH_ACCESS_KEY --env staging
npx wrangler secret put PIXABAY_API_KEY --env staging
npx wrangler secret put UNSPLASH_ACCESS_KEY
npx wrangler secret put PIXABAY_API_KEY
```

Pixabay: query `key=` ke `https://pixabay.com/api/` (foto) dan
`https://pixabay.com/api/videos/` (video). `safesearch=true`. Video
difilter 3-20 detik.
Openverse: `GET https://api.openverse.org/v1/images/` (anonim) + license CC.
Unsplash: `GET /search/photos` + `content_filter=high`.

---

## Modul

```
api/src/modules/share/
├── application/ports/share-background-provider.port.ts
├── application/use-cases/list-share-backgrounds.use-case.ts
├── application/utils/share-query-denylist.ts
├── infrastructure/unsplash-background.provider.ts
├── infrastructure/pixabay-background.provider.ts
├── infrastructure/openverse-background.provider.ts
├── infrastructure/share-background.factory.ts
└── presentation/v1/share.routes.ts (+ controller, validator)
```

Mount: `app.route('/api/v1/share', createShareRoutes(...))` di `app.ts`.

---

## Deliverable terkait

- Bruno: `http/share/`
- Sample: `docs/json/share/`
- Mobile: [`../mobile/11-mobile-share-card.md`](../mobile/11-mobile-share-card.md)
- ERROR_CODES: `SHARE_BACKGROUND_PROVIDER_ERROR` (502 internal),
  `SHARE_BACKGROUND_PROVIDER_UNAVAILABLE` (503 internal)
