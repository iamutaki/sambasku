# API - Lookup Definisi Lemma (KBBI / third-party)

Mengikuti `api-base-stack.md`: Clean Architecture feature-based, Section 3
(struktur folder), 8 (port provider eksternal), 9 (`@hono/zod-openapi` +
Scalar), 10 (testing), 11 (versioning `/api/v1/`), 13 (envelope & error),
15 (rate limiting).

Dokumen ini **kontrak dulu** (request/response + keputusan produk).
Implementasi backend/UI mengikuti kontrak ini; raw response provider
**tidak** bocor ke client.

---

## Tujuan

Backend mengambil definisi lemma dari provider kamus luar (awal: KBBI),
lalu **menstandarisasi** ke bentuk kita. Client (mobile + admin) hanya
konsumsi bentuk standar - tombol "Ambil dari KBBI" mengisi field
`definition` (dan opsional hint kelas kata) di form makna.

Ini **lookup saja**: tidak menulis ke tabel `words` / `meanings`.
Persistensi tetap lewat create/update word yang sudah ada.

---

## Flow

```
[Mobile / Admin UI]
        │  GET /api/v1/lemma-definitions/lookup?lemma=makan
        ▼
[Our API - presentation → use case]
        │  LemmaDefinitionProviderPort.lookup(normalizedLemma)
        ▼
[Infrastructure adapter - KBBI / scraper / HTTP client]
        │  raw provider payload
        ▼
[Mapper - standardize → LemmaDefinitionLookupResult]
        │
        ▼
[Envelope { success, data }]  →  UI pilih sense → isi field definition
```

---

## Keputusan produk (terkunci di kontrak ini)

1. **Provider di belakang port**: application hanya tahu
   `LemmaDefinitionProviderPort`. Ganti scraper / API resmi / fallback =
   ganti satu impl di `infrastructure/`. Field `provider` di response
   memberitahu sumber (`kbbi`), bukan menyalin skema vendor.
2. **Tidak persist otomatis**: response hanya untuk prefill form. User
   tetap review & submit lewat create/update word.
3. **Lookup miss = 200 + `found: false`**: bukan 404. UI sama pola
   "kosong" seperti search tanpa hasil (tombol tetap hidup, pesan
   ramah). 404 dipakai hanya untuk route/resource internal kita.
4. **Response dual-shape**:
   - `entries[]` - struktur penuh (homonim + sense + contoh) untuk
     admin / picker lanjutan.
   - `suggestions[]` - daftar datar siap pilih; **ini yang dipakai
     mobile** untuk isi field definisi (satu tap ≈ satu string).
5. **Kelas kata = hint, bukan ULID**: response membawa `word_class_code`
   / `word_class_label` dari provider. Mapping ke `word_classes.id`
   (ULID kita) dilakukan di client (match `code` / `name`) atau
   dibiarkan kosong - server lookup **tidak** wajib join DB kelas kata
   (hindari coupling seed data ke provider).
6. **Query = lemma bahasa Indonesia** (atau ejaan yang dikenali
   provider). Normalisasi server: trim + collapse whitespace +
   lowercase untuk cache key; response tetap menampilkan lemma
   kanonik dari provider di `entries[].lemma`.
7. **Auth wajib**: endpoint butuh login (role apa pun yang boleh
   berkontribusi / admin). Lookup mahal (outbound + rate provider) -
   jangan publik tanpa autentikasi.
8. **Rate limit ketat** + cache opsional in-memory/KV per lemma
   ternormalisasi (TTL pendek, mis. 1 jam) supaya tombol spam di mobile
   tidak menghajar provider.

---

## Provider v1: kbbi.raf555.dev

Implementasi pertama memakai [KBBI API raf555](https://kbbi.raf555.dev/swagger/doc.json).

| Aspek | Nilai |
| ----- | ----- |
| Base URL | `RAF555_BASE_URL` (default `https://kbbi.raf555.dev`); pilih vendor lewat `KBBI_PROVIDER=raf555` |
| Lookup | `GET {base}/api/v1/entry/{lemma}` |
| Not found hulu | HTTP 404 → response kita `found: false` |
| Mapping | `kbbi.Lemma.entries[]` → `entries[]`; tiap `definitions[]` → sense; label `kind=Kelas Kata` → `word_class_*`; label lain → `notes`; `usageExamples` → `examples` (placeholder `--` diganti lemma) |
| Non-goals hulu | `_search`, `_random`, `_wotd` tidak dipakai di v1 |

Matikan outbound: `KBBI_PROVIDER=none` **atau** `RAF555_BASE_URL=` (string kosong) → 503
`LEMMA_DEFINITION_PROVIDER_UNAVAILABLE`.

---

## Endpoint

```
GET /api/v1/lemma-definitions/lookup?lemma={string}&provider={raf555?}
```

| Aspek | Nilai |
| ----- | ----- |
| Middleware | `authenticate` (JWT). Role: user login (contributor / editor / admin / user biasa yang boleh isi form kontribusi) |
| Rate limit | 20 request / menit / `user_id` (lebih ketat dari CRUD biasa - Section 15) |
| Query | `lemma` wajib, string non-empty, max 100 char (huruf/angka/spasi/tanda hubung/apostrof; Zod refine). `provider` opsional - whitelist (`raf555`); default = env `KBBI_PROVIDER` |
| Side effect | Outbound ke provider; **tidak** mutasi DB katalog kata |
| Audit | Tidak wajib audit_logs (bukan mutasi konten). Opsional log metrik `provider` + latency di observability saja |

### Contoh request

```http
GET /api/v1/lemma-definitions/lookup?lemma=makan
Authorization: Bearer <access_token>

GET /api/v1/lemma-definitions/lookup?lemma=makan&provider=raf555
Authorization: Bearer <access_token>
```

Provider tidak dikenal → `400 VALIDATION_ERROR` (`details[].field = "provider"`).
Tidak ada provider aktif (env `none` / URL kosong) → `503 LEMMA_DEFINITION_PROVIDER_UNAVAILABLE`.

---

## Response ideal (sukses - ditemukan)

Envelope standar Section 13:

```json
{
  "success": true,
  "data": {
    "query": "makan",
    "normalized_query": "makan",
    "found": true,
    "provider": "raf555",
    "fetched_at": "2026-09-19T16:20:00.000Z",
    "cache_hit": false,
    "entries": [
      {
        "lemma": "makan",
        "homonym_index": 1,
        "senses": [
          {
            "sense_index": 1,
            "word_class_code": "v",
            "word_class_label": "Verba",
            "definition": "memasukkan makanan ke dalam mulut serta mengunyah dan menelannya",
            "examples": [
              "anak itu sedang makan nasi"
            ],
            "notes": null
          },
          {
            "sense_index": 2,
            "word_class_code": "v",
            "word_class_label": "Verba",
            "definition": "menghabiskan (biaya, waktu, dan sebagainya)",
            "examples": [],
            "notes": null
          }
        ]
      }
    ],
    "suggestions": [
      {
        "id": "1:1",
        "lemma": "makan",
        "homonym_index": 1,
        "sense_index": 1,
        "word_class_code": "v",
        "word_class_label": "Verba",
        "definition": "memasukkan makanan ke dalam mulut serta mengunyah dan menelannya",
        "preview": "memasukkan makanan ke dalam mulut serta mengunyah dan menelannya"
      },
      {
        "id": "1:2",
        "lemma": "makan",
        "homonym_index": 1,
        "sense_index": 2,
        "word_class_code": "v",
        "word_class_label": "Verba",
        "definition": "menghabiskan (biaya, waktu, dan sebagainya)",
        "preview": "menghabiskan (biaya, waktu, dan sebagainya)"
      }
    ]
  }
}
```

### Semantik field `data`

| Field | Tipe | Keterangan |
| ----- | ---- | ---------- |
| `query` | string | Lemma mentah dari query string (setelah trim ringan) |
| `normalized_query` | string | Bentuk yang dipakai cache / panggil provider |
| `found` | boolean | `true` jika ada ≥1 sense yang bisa ditawarkan |
| `provider` | string | Id vendor yang melayani (`raf555`, …) - dari query atau default env |
| `fetched_at` | ISO-8601 | Waktu hasil (dari cache atau live) |
| `cache_hit` | boolean | `true` jika dilayani dari cache internal |
| `entries` | array | Homonim + sense terstruktur |
| `suggestions` | array | Flatten `entries` → satu item per sense; urut = urutan tampil UI |

### `entries[]`

| Field | Tipe | Keterangan |
| ----- | ---- | ---------- |
| `lemma` | string | Lemma kanonik dari provider (boleh beda ejaan dari query) |
| `homonym_index` | number | 1-based; 1 jika provider tidak bedakan homonim |
| `senses` | array | Daftar makna |

### `entries[].senses[]`

| Field | Tipe | Keterangan |
| ----- | ---- | ---------- |
| `sense_index` | number | 1-based dalam homonim tersebut |
| `word_class_code` | string \| null | Kode pendek provider (`v`, `n`, `a`, `adv`, …) - hint match ke `word_classes.code` |
| `word_class_label` | string \| null | Label manusiawi (`Verba`, `Nomina`, …) |
| `definition` | string | Teks definisi bersih (tanpa nomor sense / kelas kata di awalan) |
| `examples` | string[] | Contoh kalimat dari provider; `[]` jika tidak ada |
| `notes` | string \| null | Info tambahan (mis. gaya bahasa, bidang) jika ada; else null |

### `suggestions[]` (kontrak UI utama)

Dirancang supaya mobile cukup:

1. render list `suggestions`
2. user pilih satu
3. set `definition = suggestion.definition`
4. (opsional) map `word_class_code` → `word_class_id` lokal

| Field | Tipe | Keterangan |
| ----- | ---- | ---------- |
| `id` | string | Stabil dalam satu response: `"{homonym_index}:{sense_index}"` - key React/Flutter list |
| `lemma` | string | Copy dari entry |
| `homonym_index` / `sense_index` | number | Trace ke `entries` |
| `word_class_code` / `word_class_label` | string \| null | Sama seperti sense |
| `definition` | string | **Nilai yang di-paste ke field definisi** |
| `preview` | string | Sama dengan `definition` untuk v1 (cadangan truncate di UI nanti tanpa ubah API) |

`suggestions` **selalu** derived dari `entries` (bukan sumber kebenaran kedua di mapper). Kalau `found=false`, keduanya `[]`.

---

## Response ideal (sukses - tidak ditemukan)

```json
{
  "success": true,
  "data": {
    "query": "xyzabc",
    "normalized_query": "xyzabc",
    "found": false,
    "provider": "raf555",
    "fetched_at": "2026-09-19T16:21:00.000Z",
    "cache_hit": false,
    "entries": [],
    "suggestions": []
  }
}
```

HTTP **200**. UI menampilkan "Definisi tidak ditemukan di KBBI".

---

## Error

| HTTP | error_code | Kapan |
| ---- | ---------- | ----- |
| 400 | `VALIDATION_ERROR` | `lemma` kosong / terlalu panjang / karakter ilegal (`details[].field = "lemma"`) |
| 401 | `UNAUTHORIZED` | Tanpa / token invalid |
| 429 | `RATE_LIMITED` | Melewati batas per user |
| 502 | `LEMMA_DEFINITION_PROVIDER_ERROR` | Provider merespons error / HTML tak terparse / timeout setelah retry singkat |
| 503 | `LEMMA_DEFINITION_PROVIDER_UNAVAILABLE` | Provider belum dikonfigurasi (env kosong) atau circuit open |

Contoh gagal provider:

```json
{
  "success": false,
  "error_code": "LEMMA_DEFINITION_PROVIDER_ERROR",
  "message": "Gagal mengambil definisi dari penyedia kamus",
  "details": null
}
```

Jangan kirim stack / raw HTML / body vendor ke client.

---

## Aturan mapping dari provider → bentuk kita

Mapper (application atau infrastructure helper) wajib:

1. **Strip prefix noise** dari teks sense: nomor (`1.`, `1)`), kode kelas
   (`v`, `n`), bullet - supaya `definition` tinggal kalimat makna.
2. **Pisah kelas kata** ke `word_class_*`, jangan digabung di string
   definisi.
3. **Homonim**: jika provider punya entri ganda untuk ejaan sama,
   isi `homonym_index` berurutan; sense reset per homonim.
4. **Contoh**: kumpulkan ke `examples[]`; jika provider menempel contoh
   di definisi dengan pola jelas, boleh dipisah (best-effort); kalau
   ragu biarkan di definisi - jangan rusak makna.
5. **Kosongkan field** dengan `null` / `[]`, jangan omit kunci yang ada
   di kontrak Zod response (OpenAPI tetap stabil).
6. **Jangan** forward field vendor asing (`raw_html`, `uri`, cookie, dll)
   kecuali suatu hari ditambah field opsional eksplisit di kontrak ini.

---

## Kontrak konsumsi UI

### Mobile (tombol isi definisi)

1. User ketik / punya teks lemma Indonesia (mis. dari field terjemahan
   atau input lookup).
2. Tap "Ambil definisi (KBBI)" → panggil endpoint.
3. Jika `found`:
   - **1 suggestion**: boleh langsung isi `definition` + toast
     "Diisi dari KBBI" (masih bisa diedit).
   - **>1 suggestion**: bottom sheet / dialog pilih satu → isi field.
4. Jika `!found`: snackbar / empty state, field tidak diubah.
5. Jika 502/503: pesan gagal jaringan/provider; field tidak diubah.
6. Jangan panggil endpoint di setiap keystroke - hanya on-demand
   (debounce tombol / disable selama loading).

### Admin

Sama endpoint. Picker boleh menampilkan `entries` (grup per homonim)
atau `suggestions` datar. Prefill `meanings[].definition` di form
create/edit word; mapping kelas kata ke dropdown `word_class_id` jika
`code` cocok.

---

## Modul backend (outline implementasi - bukan wajib di PR kontrak)

```
modules/lemma-definition/
├── domain/                          # (opsional tipis - tipe hasil lookup)
├── application/
│   ├── ports/
│   │   └── lemma-definition-provider.port.ts
│   ├── dto/
│   │   └── lemma-definition-lookup.dto.ts
│   └── use-cases/
│       └── lookup-lemma-definition.use-case.ts
├── infrastructure/
│   ├── kbbi-lemma-definition.provider.ts   # implements port
│   └── lemma-definition.mapper.ts          # raw → DTO standar
├── presentation/
│   └── v1/
│       ├── lemma-definition.routes.ts
│       ├── lemma-definition.controller.ts
│       └── validators/
│           └── lookup-lemma-definition.validator.ts
└── __tests__/
    ├── unit/
    │   ├── lookup-lemma-definition.use-case.test.ts
    │   └── lemma-definition.mapper.test.ts   # wajib: strip nomor/kelas
    └── e2e/
        └── v1/
            └── lookup-lemma-definition.e2e.test.ts  # mock port
```

Port (sketsa):

```ts
export interface LemmaDefinitionProviderPort {
  readonly providerName: string; // 'kbbi'
  lookup(normalizedLemma: string): Promise<ProviderLookupRaw | null>;
}
```

`null` / empty → use case mengembalikan `found: false`.
Throw typed error → 502/503.

Env (contoh): `KBBI_PROVIDER=raf555`, `RAF555_BASE_URL`,
`LEMMA_DEFINITION_CACHE_TTL_SECONDS`.

Update `ERROR_CODES.md` saat implementasi:
`LEMMA_DEFINITION_PROVIDER_ERROR`,
`LEMMA_DEFINITION_PROVIDER_UNAVAILABLE`.

Bruno: `http/lemma-definition/lookup.bru`.

---

## Prompt (siap pakai saat implementasi)

```text
Implementasikan modul lookup definisi lemma sesuai kontrak
docs/api/13-api-kbbi-lemma-definition.md dan api-base-stack.md
(Section 8 port, 9 OpenAPI, 11 /api/v1, 13 envelope, 15 rate limit).

ENDPOINT:
  GET /api/v1/lemma-definitions/lookup?lemma=
  - authenticate
  - rateLimit 20/menit per user_id
  - response schema Zod = bentuk data di kontrak (entries + suggestions)
  - found=false → 200 + entries/suggestions kosong
  - provider gagal → 502 LEMMA_DEFINITION_PROVIDER_ERROR
  - provider belum dikonfigurasi → 503 LEMMA_DEFINITION_PROVIDER_UNAVAILABLE

PORT:
  LemmaDefinitionProviderPort di application/ports/
  Impl v1: Raf555KbbiProvider → GET {RAF555_BASE_URL}/api/v1/entry/{lemma}
    (KBBI_PROVIDER=raf555; spec https://kbbi.raf555.dev/swagger/doc.json)
  Mapper wajib menghasilkan definition bersih + suggestions derived
  dari labels kind="Kelas Kata" + usageExamples

TEST:
  unit mapper (multi-sense, homonim, referencedLemma, prakategorial kosong)
  unit use-case (found false, cache_hit)
  unit provider (mock fetch: 200/404/500)
  e2e opsional dengan mock port (jangan hit provider asli di CI)

Tidak ada migration DB. Tidak menulis words/meanings.
Update ERROR_CODES.md + Bruno collection http/lemma-definition/.
```

---

## Non-goals (sengaja di luar kontrak ini)

- Menyimpan riwayat lookup user ke DB
- Auto-create / auto-update entri `words` dari hasil KBBI
- Menyamakan 1:1 seluruh metadata KBBI (etimologi, rujukan, audio)
- Endpoint publik tanpa auth
- Streaming / WebSocket lookup

Perluasan nanti (boleh revisi kontrak): `provider` query multi-sumber,
`lang` selain id, atau `include_raw` debug-only di admin.
