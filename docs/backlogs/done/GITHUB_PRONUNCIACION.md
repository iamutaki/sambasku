# Backlog - GitHub sebagai Storage Audio Pronunciation (Sambasku API)

Dokumen ini sudah diaudit terhadap repository `sambasku-api` per 2026-09-21.
Semua nama file/path di bawah adalah lokasi NYATA di repository, bukan asumsi.

## Konteks

Fitur penyimpanan file audio pronunciation memakai repository GitHub khusus
sebagai storage provider:

```text
sambasku/audios
```

Repository ini SUDAH terdaftar sebagai submodule `pronunciation/` di
superproject (lihat `.gitmodules`), branch `main`, isi awal: `README.md` +
folder `assets/` kosong.

**Requirement utama: MULTI** - satu kata bisa punya BANYAK file audio
pronunciation (speaker beda, dialek beda, beberapa take).

Kenapa GitHub: gratis, tanpa kartu kredit, tanpa setup bucket, cukup untuk
corpus audio kamus yang ukurannya kecil (ribuan file < 5 MB). Desain storage
tetap provider-agnostic supaya migrasi ke Cloudflare R2/S3 nanti hanya
menambah satu file adapter.

---

## 0. Hasil audit repository (fakta, bukan asumsi)

Gunakan ini sebagai ground truth. Jangan audit ulang dari nol.

### Stack

| Komponen | Nyatanya |
| --- | --- |
| Framework | Hono 4 + `@hono/zod-openapi` (OpenAPI otomatis, Scalar terpasang) |
| ORM | Drizzle ORM (`src/shared/database/drizzle/`, schema per tabel, migrations via drizzle-kit) |
| DB | PostgreSQL (local: Docker, staging/prod: Neon) |
| Auth | JWT via `jose`, middleware `authenticate` + `authorizeRole(...)` |
| Validasi | Zod v4, validator per-module di `presentation/v1/validators/` |
| ID | ULID (`generateId()` dari `@/shared/utils/ulid`, varchar(26)) |
| Runtime | GANDA: Node (`@hono/node-server`, `src/main.ts`) dan Cloudflare Workers (`src/worker.ts`, deploy via wrangler) |
| Test | Vitest, struktur `__tests__/{unit,integration,e2e}` per module |
| Env | `src/shared/config/env.ts` - zod schema, akses `process.env` HANYA di file ini, fail-fast saat boot |

### Struktur module (pola wajib diikuti)

```text
src/modules/<nama>/
  application/
    ports/          # interface storage/service eksternal
    use-cases/
    dto/
  domain/
    repositories/   # interface repository
  infrastructure/   # impl repository + impl storage eksternal
  presentation/v1/  # *.routes.ts, *.controller.ts, validators/
  __tests__/{unit,integration,e2e}
```

### Pronunciation (notasi) SUDAH ADA - jangan buat duplikat

1. Tabel `pronunciations` sudah ada:
   `src/shared/database/drizzle/schema/pronunciations.schema.ts`
   - `id` ULID, `wordId` (wajib), `dialectId` (**nullable**), `notation`
     (default `'ipa'`), `value` (teks notasi, max 500), `audioUrl` (text,
     nullable), `speakerName`, `notes`
   - Approval gate: `status` (default `published`; contributor →
     `pending_review`), `isVerified`, `isCorrected`
   - `createdBy`/`updatedBy`, soft delete (`deletedAt`, `deletedBy`)
   - Unique: `(wordId, dialectId, notation, value)`
2. Endpoint notasi sudah ada: `POST /api/v1/words/:wordId/pronunciations`
   (`src/modules/word/presentation/v1/word-media.routes.ts`)
   - Roles: `admin, editor, contributor, root, reviewer`, rate limit
     30/menit per user
   - Use-case: `src/modules/word/application/use-cases/add-pronunciation.use-case.ts`
     - audit log ke `audit_logs`
   - Hari ini `audio_url` hanyalah string URL bebas dari client (`z.url()`).

### Kenapa tabel `pronunciations` TIDAK bisa menampung multi audio

Unique `(wordId, dialectId, notation, value)` berarti dua rekaman dengan
notasi sama + dialek sama oleh dua speaker berbeda akan TIDAK BISA masuk
(collide). Menambah kolom audio di tabel itu = maksimal 1 audio per notasi
dan melanggar requirement MULTI. Karena itu audio file hidup di tabel baru
(Section 4) yang meniru pola `word_images`.

### Pola storage eksternal SUDAH ADA di module image - tiru polanya

`src/modules/image/`:

```text
application/ports/image-storage.port.ts        # ImageStoragePort + providerName
application/use-cases/create-upload-credentials.use-case.ts
infrastructure/imagekit-storage.service.ts     # satu-satunya impl hari ini
infrastructure/image-storage.factory.ts        # pilih impl dari env, fail-fast
presentation/v1/image.routes.ts                # /api/v1/admin/images/upload-token
```

- Tabel `word_images` menyimpan `provider` + `provider_file_id` + `url`
  (unique `(provider, provider_file_id)`) - pola kolom yang SAMA dipakai
  untuk tabel audio baru.
- Tanpa kredensial → endpoint balas **503** `IMAGE_UPLOAD_UNAVAILABLE`
  (bukan crash).
- Pemilihan provider via env selector: `IMAGE_PROVIDER=imagekit`,
  kredensial per-provider `IMAGEKIT_*`.

### Pola env selector yang sudah dipakai project

`IMAGE_PROVIDER` (image), `KBBI_PROVIDER` (lemma), kredensial per-vendor.
Fitur ini mengikuti pola yang sama - lihat Section Env.

### PERBEDAAN PENTING dengan image - jangan samakan flow-nya

Image memakai **direct upload** (backend hanya menandatangani kredensial,
client upload langsung ke ImageKit CDN). GitHub TIDAK BISA memakai pola ini
karena token tidak boleh bocor ke client. Jadi pronunciation memakai
**backend-mediated upload**: client → multipart ke API → API upload ke
GitHub Contents API. Port-nya beda bentuk dari `ImageStoragePort`
(butuh `upload(bytes)`, bukan `createUploadCredentials()`).

---

## 1. Keputusan desain (koreksi dari draf awal)

| Draf awal (salah) | Keputusan final (klop dengan repo) |
| --- | --- |
| Buat tabel `pronunciations` baru | **Jangan.** Tabel notasi sudah ada. Audio file = tabel baru `word_audios` meniru `word_images` (Section 4) |
| 1 kata 1 audio (kolom `audio_url` di notasi) | **1 kata MULTI audio** - banyak baris `word_audios` per kata; `is_primary` menandai rekaman utama |
| `POST /api/v1/pronunciations` standalone, multipart `word_id`, `dialect_id`, `audio` | `POST /api/v1/words/:wordId/pronunciations/audio` multipart, SATU LANGKAH: upload file + insert baris audio sekaligus (Section 7). Endpoint notasi existing tidak disentuh |
| `dialect_id` wajib | `dialectId` **nullable** di schema - validasi opsional, ikuti schema |
| Storage abstraction generik `FileStorage` | Port spesifik `PronunciationStoragePort` di module word, bentuknya `upload/delete` - meniru `ImageStoragePort`, bukan interface generik spekulatif |
| `contributor_id` dari client | `createdBy` dari auth context (`Actor.userId`) - sudah berjalan di repo |
| Status langsung published | Ikuti approval gate existing: contributor → `pending_review` via `resolveChildPublication` (pola `word_images`) |

### Kenapa tabel baru, bukan kolom di `pronunciations`

- Requirement multi: unique constraint tabel lama membatasi 1 baris per
  kombinasi (dialect, notation, value) - dua rekaman notasi sama = collide.
- Audio adalah entitas sendiri: punya speaker, durasi, status review,
  primary flag, soft delete - menumpuknya sebagai kolom di baris notasi
  membuat query & review antrean jadi rumit.
- `word_images` sudah membuktikan pola "media per kata = tabel sendiri";
  audio tinggal meniru. Konsisten = murah.
- `audio_url` di tabel `pronunciations` TETAP dipertahankan apa adanya
  (legacy/URL manual) - tidak dimigrasi, tidak dihapus.

---

## 2. Persiapan (checklist sebelum koding)

- [ ] **Repo pronunciation harus PUBLIC** - raw URL & CDN hanya bisa
      diakses tanpa token jika repo public. Audio pronunciation memang
      konten publik (diputar semua user), jadi ini OK.
- [ ] **Fine-grained PAT** (bukan classic): scope HANYA repository
      `sambasku/audios`, permission HANYA `Contents: Read and write`.
      Set expiry (mis. 90 hari) + reminder rotasi.
- [ ] Distribusikan `PRONUNCIACION_GITHUB_TOKEN` ke TIGA tempat:
  - [ ] local: `.env` (jangan commit)
  - [ ] CI/deploy: GitHub Actions secrets repo `sambasku-api`
  - [ ] Workers: `wrangler secret put PRONUNCIACION_GITHUB_TOKEN`
        (staging & production)
- [ ] Hapus folder `assets/` kosong di repo pronunciation ATAU jadikan base
      path audio di bawahnya (keputusan Section 3: pakai `assets/audio/`).
- [ ] Konfirmasi format rekaman Flutter (package `record` default-nya
      **AAC/m4a**, BUKAN mp3) - daftar MIME di Section 5 harus cocok dengan
      kemampuan client, jangan asal salin dari draf.
- [ ] Pastikan `wrangler.toml` / config Workers tidak menolak body ±6 MB
      (limit Workers 100 MB - aman, cukup diverifikasi sekali).

---

## 3. Struktur file di repo pronunciation

```text
assets/audio/
  <dialect-code>/
    <lemma-slug>/
      <ulid>.<ext>
```

Contoh:

```text
assets/audio/sambas/kong/01J8ZQ….m4a
assets/audio/sambas/kong/01J8ZR….m4a   ← take ke-2 kata yang sama, tetap aman
assets/audio/tungkal/kong/01J8ZS….m4a
```

- `<dialect-code>`: kolom `dialects.code`; tanpa dialect → `umum`.
- `<lemma-slug>`: slugify(`words.lemma`) - kosmetik/human-browsable saja.
- `<ulid>`: ID file baru PER UPLOAD → **collision mustahil**, multi take
  per kata otomatis ke-path berbeda, file baru tidak pernah menimpa file
  lama, tidak perlu SHA check sebelum PUT.
- JANGAN pakai filename client (sanitasi ribet + bisa traversal). Ekstensi
  ditentukan dari MIME yang tervalidasi, bukan dari filename.

---

## 4. Database migration (Drizzle)

Tabel BARU `word_audios` - klon struktural `word_images`
(`src/shared/database/drizzle/schema/word-images.schema.ts`), disesuaikan
untuk audio + multi:

```text
word_audios
--------------------------------------------
id              varchar(26) PK, ULID
word_id         varchar(26) NOT NULL → words.id
dialect_id      varchar(26) NULL → dialects.id
provider        varchar(30)  NOT NULL DEFAULT 'github'   -- 'r2'|'s3' nanti
provider_file_id varchar(500) NOT NULL   -- storage path, mis.
                                                   assets/audio/sambas/kong/01J8….m4a
sha             varchar(40)              -- blob sha GitHub (untuk DELETE)
url             varchar(1000) NOT NULL   -- URL publik final
mime_type       varchar(100) NOT NULL
file_size       integer      NOT NULL    -- bytes
duration_ms     integer                   -- opsional dari client, clamp 1..600_000
speaker_name    varchar(255)
is_primary      boolean      NOT NULL DEFAULT false
status          varchar(30)  NOT NULL DEFAULT 'published'
is_verified     boolean      NOT NULL DEFAULT false
is_corrected    boolean      NOT NULL DEFAULT false
created_by      varchar(26)  → users.id
created_at      timestamp    NOT NULL DEFAULT now()
deleted_at      timestamp
--------------------------------------------
UNIQUE (provider, provider_file_id)      -- sama seperti word_images
INDEX  (word_id)
```

- Schema file baru: `word-audios.schema.ts` + export di `schema/index.ts`.
- Migration via drizzle-kit, ikuti numbering yang ada di
  `src/shared/database/drizzle/migrations/`.
- Tabel `pronunciations` TIDAK diubah sama sekali.
- `is_primary`: audio PERTAMA untuk kata itu otomatis `true` (satu baris
  logika di use-case), sisanya `false`. Ganti primary nanti = urusan
  admin/reviewer, bukan endpoint upload.
  (ponytail: tanpa endpoint set-primary di fase ini; tambah kalau perlu.)

---

## 5. Validasi file audio

Multipart fields:

```text
audio       : file (wajib)
dialect_id  : ULID 26 char (opsional, nullable di schema)
speaker_name: string opsional max 255
duration_ms : integer opsional
```

Aturan:

- **Body limit**: pasang `bodyLimit` dari `hono/body-limit` HANYA di route
  upload (±6 MB) - jangan global. Cek juga `content-length` sebelum parse.
- MIME diterima (final: sesuai kemampuan Flutter `record` - lihat checklist):

```text
audio/mpeg   (.mp3)
audio/mp4    (.m4a)   ← kemungkinan default Flutter, WAJIB ada
audio/wav    (.wav)
audio/ogg    (.ogg)
audio/webm   (.webm)
```

- Ekstensi diturunkan dari MIME (map di server), bukan dari filename.
- Tolak: file kosong (0 byte), size > 5 MB, MIME tidak ada di daftar,
  filename mengandung `../`/null byte.
- Ekstensi & MIME harus konsisten (`.mp3` + `audio/mpeg`, dst).
- Magic-byte check ringan hanya jika murah (mp3 = `ID3`/`0xFFFB`,
  m4a = `ftyp` di offset 4); jangan install library audio parser.

---

## 6. Storage port & adapter

Module: tambahkan di dalam `src/modules/word/` (pronunciation sudah tinggal
di situ - jangan buat module baru hanya untuk storage).

```text
src/modules/word/application/ports/pronunciation-storage.port.ts
src/modules/word/infrastructure/github-pronunciation-storage.service.ts
src/modules/word/infrastructure/pronunciation-storage.factory.ts
```

Port (bentuk disesuaikan kebutuhan, jangan generik-lebih):

```ts
export interface PronunciationStoragePort {
  readonly providerName: string; // 'github' - disimpan ke provider column
  upload(input: {
    path: string;          // 'assets/audio/sambas/kong/01J8….m4a'
    content: Uint8Array;
    mimeType: string;
  }): Promise<{ path: string; url: string; sha: string; size: number }>;
  delete(path: string, sha: string): Promise<void>;
}
```

Factory = salinan pola `image-storage.factory.ts`:

```ts
export function createPronunciationStorage(): PronunciationStoragePort {
  switch ((env.PRONUNCIACION_PROVIDER ?? 'github').toLowerCase()) {
    case 'github': return new GitHubPronunciationStorageService();
    default: throw new Error(/* unknown provider - fail fast */);
  }
}
```

Provider baru (R2/S3) nanti = 1 file impl + 1 case. Bisnis logic hanya
melihat port.

---

## 7. Endpoint & flow

### Upload - satu langkah, langsung multi-capable

```text
POST /api/v1/words/:wordId/pronunciations/audio
Content-Type: multipart/form-data
```

- Roles + rate limit: sama persis dengan `mediaMiddleware` word-media
  (admin/editor/contributor/root/reviewer, 30/menit).
- Routes: tambah di `word-media.routes.ts` - ikuti pola `createRoute` +
  zod-openapi yang ada di file itu.
- Tanpa kredensial GitHub → **503** `PRONUNCIACION_UPLOAD_UNAVAILABLE`
  (pola `IMAGE_UPLOAD_UNAVAILABLE`).
- Bisa dipanggil BERULANG per kata → tiap panggilan = 1 baris `word_audios`
  baru (multi take/multi speaker/multi dialek).

Flow:

```text
authenticate + authorizeRole
  → word exists? (404 WORD_NOT_FOUND)
  → dialect exists? jika dikirim (404 DIALECT_NOT_FOUND)
  → bodyLimit + parse multipart
  → validasi MIME/size/magic byte (400)
  → path = assets/audio/<dialect|umum>/<slug(lemma)>/<ulid>.<ext>
  → storage.upload() → { path, url, sha, size }
  → insert word_audios (status via resolveChildPublication,
    is_primary = audio pertama untuk word ini)
  → record audit log (entityType 'word_audio', action 'create')
  → 201 { id, word_id, dialect_id, url, speaker_name, is_primary, status, … }
```

### Read & delete

- Word detail response: sertakan `audios[]` (public: hanya `published`;
  admin/reviewer: semua) - masing-masing punya `url`, `dialect_id`,
  `speaker_name`, `is_primary`, `duration_ms`.
- `DELETE /api/v1/words/:wordId/pronunciations/audio/:audioId`
  (admin/editor/root): soft-delete baris + best-effort
  `storage.delete(path, sha)`. Gagal delete GitHub → log warning, lanjut
  (file yatim tidak berbahaya - path unik).

### Failure handling (upload ≠ DB transaction)

```text
GitHub upload GAGAL     → 502/503 ke client, tidak ada baris DB. Aman.
Insert DB GAGAL setelah upload sukses → file yatim di GitHub. Tidak
                        menimpa apa pun (path ULID unik). Acceptable.
Soft-delete audio       → best-effort GitHub delete via sha; gagal = warning.
```

Tidak perlu saga/queue/compensation penuh - corpus kecil, file yatim murah.
(ponytail: file yatim acceptable; GC script hanya jika repo membengkak.)

---

## 8. GitHub adapter - implementasi Contents API

`GitHubPronunciationStorageService`:

- Parse `owner`/`repo` SEKALI di constructor dari
  `env.PRONUNCIACION_GITHUB_URL`
  (mis. `https://github.com/sambasku/audios` → owner
  `sambasku`, repo `audios`).
- Branch = konstanta `BRANCH = 'main'` di adapter - BUKAN env. Satu repo,
  satu branch untuk staging & prod sekaligus (keputusan sadar: file test
  staging bercampur prod, tapi path ULID unik per upload jadi tidak pernah
  menimpa data prod; murah dibersihkan kalau perlu).
- `PUT /repos/{owner}/{repo}/contents/{path}` dengan body:

```json
{
  "message": "feat(pronunciation): add <lemma>",
  "content": "<base64>",
  "branch": "main"
}
```

- base64 dari `Uint8Array`. Di Node: `Buffer.from(x).toString('base64')`.
  Di Workers: `btoa(String.fromCharCode(...chunk))` per chunk (jangan spread
  array besar - loop per 8KB).
- Response `content.sha` → disimpan ke kolom `sha` (dipakai DELETE).
- `DELETE /repos/.../contents/{path}` dengan `{ message, sha }` (branch
  ikut konstanta BRANCH).
- URL publik yang dikembalikan (diturunkan dari URL repo + konstanta
  BRANCH, bukan hardcode):
  `https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}`
  - raw.github men-cache ±5 menit - tidak masalah karena path immutable.
  - Alternatif CDN (opsional, tanpa kode tambahan di client):
    `https://cdn.jsdelivr.net/gh/{owner}/{repo}@{branch}/{path}` - putuskan
    SATU, jadikan konstanta di adapter, simpan `path` di DB (bukan full URL
    CDN) supaya basis URL bisa diganti nanti.
- Header: `Authorization: Bearer <token>`, `Accept: application/vnd.github+json`,
  `X-GitHub-Api-Version: 2022-11-28`, `User-Agent` wajib ada.
- Timeout ±15s (AbortSignal). Retry: maksimal 1x untuk 5xx/network, tidak
  untuk 4xx. Tidak perlu library retry.
- Rate limit 5.000/jam (authenticated) - jauh lebih dari cukup; upload sudah
  dibatasi 30/menit per user oleh middleware.
- 409/422 (`sha` tidak cocok / path ada) → seharusnya mustahil (ULID);
  kalau terjadi, balas 500 + log - jangan retry blind.
- Gunakan `fetch` global (jalan di Node 20 dan Workers). JANGAN git CLI,
  JANGAN octokit (dependency baru untuk 2 endpoint = tidak perlu).

---

## 9. Env

Permintaan config → env final (mengikuti pola selector + kredensial
per-provider yang sudah dipakai project: `IMAGE_PROVIDER` + `IMAGEKIT_*`):

| Diminta | Env final | Isi |
| --- | --- | --- |
| `PRONUNCIACION_PROVIDER` | `PRONUNCIACION_PROVIDER` | selector: `github` (satu-satunya hari ini) |
| `PRONUNCIACION_GITHUB` | `PRONUNCIACION_GITHUB_TOKEN` | fine-grained PAT |
| `PRONUNCIACION_URL` (repository) | `PRONUNCIACION_GITHUB_URL` | URL repo, sumber parse owner/repo |

Branch TIDAK di-env - konstanta `main` di adapter (satu repo & satu branch
dipakai staging & prod bersama; lihat Section 8).

Semua prefixed `PRONUNCIACION_` supaya tidak bentrok dengan kebutuhan
GitHub lain di masa depan (mis. OAuth login) yang mungkin memakai `GITHUB_*`.

### Skenario perubahan - env = nilai, bukan struktur

| Skenario | Yang diubah | Dampak data |
| --- | --- | --- |
| Pindah repo GitHub lain / ganti owner | value `PRONUNCIACION_GITHUB_URL` saja | Baris lama aman - kolom `url` menyimpan URL lengkap per baris; upload baru otomatis pakai base URL baru. File lama tetap di repo lama (memindahkan file = migrasi data terpisah, bukan urusan env) |
| Ganti provider (R2/S3) | `PRONUNCIACION_PROVIDER=r2` + group baru `PRONUNCIACION_R2_*` | Baris lama tetap terbaca (`url` per baris); hanya adapter baru yang menulis ke provider baru |

Alternatif penamaan yang DITOLAK (jangan dikerjakan ulang):

- Satu env JSON blob (`PRONUNCIACION_STORAGE={"provider":…}`): satu
  secret untuk semua, tapi melanggar pola flat + zod per-key yang dipakai
  seluruh repo, quoting JSON di `wrangler secret put` rawan salah, dan
  `.env.example` jadi tidak terbaca.
- Auto-detect provider tanpa selector (pilih dari group mana yang terisi):
  ambigu kalau dua group terisi; factory fail-fast repo ini memakai
  selector eksplisit (`IMAGE_PROVIDER`) supaya salah konfig terdeteksi
  saat boot, bukan runtime.
- Prefix generik `STORAGE_*`: baru relevan kalau media lain (gambar) ikut
  pindah ke storage yang sama. Hari ini hanya pronunciation → YAGNI.

`src/shared/config/env.ts`:

```ts
// Audio pronunciation storage - pola sama IMAGE_PROVIDER.
// Tanpa kredensial: endpoint upload audio balas 503
// PRONUNCIACION_UPLOAD_UNAVAILABLE.
PRONUNCIACION_PROVIDER: z.string().optional(), // 'github' (satu-satunya hari ini)
PRONUNCIACION_GITHUB_TOKEN: z.string().optional(),
PRONUNCIACION_GITHUB_URL: z.url().optional(),
```

`.env.example` - tambah blok dengan komentar penjelas seperti blok image:

```env
# Audio pronunciation storage - dipilih lewat sini (default: github).
# Token: fine-grained PAT, scope HANYA repo sambasku/audios,
# permission Contents RW. Workers: wrangler secret put
# PRONUNCIACION_GITHUB_TOKEN.
PRONUNCIACION_PROVIDER=github
PRONUNCIACION_GITHUB_TOKEN=
PRONUNCIACION_GITHUB_URL=https://github.com/sambasku/audios
```

Secret asli tidak pernah masuk git. Di Workers lewat wrangler secret,
bukan wrangler.toml.

---

## 10. Testing (Vitest, struktur per-module)

Unit (mock `PronunciationStoragePort`):

- validator: mp3 valid / m4a valid / MIME ditolak / >5 MB / 0 byte /
  ekstensi-MIME mismatch / `../` di filename
- use-case upload: word tidak ada (404), dialect tidak ada (404),
  provider belum dikonfigurasi (503), upload storage gagal → 502
- MULTI: upload ke-2 untuk kata yang sama → 2 baris, tidak error unique;
  audio pertama `is_primary=true`, kedua `false`
- path generator: dialect code, fallback `umum`, slug lemma, ekstensi dari
  MIME, ULID unik antar 2 generate
- parser `PRONUNCIACION_GITHUB_URL` → owner/repo benar

Integration:

- insert/select `word_audios` via repository; unique `(provider,
  provider_file_id)` mencegah duplikat path

E2E (ikuti pola `word-media.e2e.test.ts`, auth + roles):

- unauthenticated → 401
- role tidak diizinkan → 403
- upload sukses (storage di-mock) → 201 + shape response
- upload dua kali berturut → 201 dua kali (multi)
- rate limit terpicu → 429
- delete audio → 204/200, storage.delete dipanggil (mock spy)

TIDAK ada test yang memanggil GitHub sungguhan. Adapter GitHub dites
manual sekali via script kecil `src/scripts/` (pola `seed.ts`) saat setup,
bukan di suite CI.

---

## 11. Dokumentasi

- OpenAPI: otomatis via `createRoute` zod-openapi - pastikan multipart
  terdokumentasi benar (cek Scalar di `/api-reference`).
- Buat dokumen fitur bernomor di submodule `docs/`: lanjutkan numbering
  `docs/api/NN-api-pronunciation-audio.md` (lihat nomor terakhir yang ada).
  Isi: alur upload 1 langkah, multi-audio per kata, format, limit,
  error codes, contoh cURL.
- Setelah implementasi jalan: pindahkan file backlog ini ke
  `docs/backlogs/done/`.

---

## 12. Jangan over-engineer (tetap berlaku)

TIDAK dibuat: microservice, queue, Redis, event bus, CDN tambahan,
octokit, library audio parser, garbage collector file, abstract
`FileStorage` generik untuk semua tipe file, refactor module word,
endpoint set-primary (tambah hanya jika reviewer benar-benar butuh).

Batas kesadaran sederhana (ponytail): file yatim acceptable; GC script
hanya jika repo membengkak. Slug lemma kosmetik; jika ribet, `<wordId>`
saja sudah cukup uniquely. `is_primary` otomatis audio pertama; tidak
ada primary-switching endpoint di fase ini.

---

## 13. Definition of Done

```bash
npm run typecheck && npm run lint   # jika lint script ada; jika tidak, skip
npm run test
npx drizzle-kit generate            # migration baru ter-commit
```

- [ ] Diff hanya menyentuh: module word (port/infra/routes/use-case),
      schema + migration `word_audios`, env.ts, .env.example, docs,
      dokumen API baru.
- [ ] Tidak ada token/secret di source.
- [ ] Endpoint 503 saat `PRONUNCIACION_GITHUB_TOKEN` kosong (bukan crash
      saat boot - env-nya optional).
- [ ] Upload manual sukses sekali ke repo pronunciation (via script dev).
- [ ] Ringkasan: implemented / files changed / API / env / tests / follow-up.

---

## Ringkasan untuk implementer (TL;DR)

1. Baca Section 0 - itu hasil audit, jangan audit ulang.
2. Tabel notasi & endpoint pronunciation SUDAH ADA dan TIDAK diubah.
   Fitur ini = tabel baru `word_audios` (klon `word_images`) + endpoint
   upload multipart.
3. MULTI by design: tiap upload = 1 baris audio baru per kata; ULID di
   path menjamin tidak pernah tabrakan; audio pertama otomatis primary.
4. Port + adapter + factory meniru module image; upload lewat GitHub
   Contents API, bukan git CLI.
5. Env: `PRONUNCIACION_PROVIDER` + `PRONUNCIACION_GITHUB_TOKEN` +
   `PRONUNCIACION_GITHUB_URL` (repo). Branch = konstanta `main` di adapter,
   dipakai bersama staging & prod. Token tersebar ke .env / Actions
   secrets / wrangler secret. Repo pronunciation harus public.
6. MIME wajib termasuk `audio/mp4` (m4a) - default rekaman Flutter.
