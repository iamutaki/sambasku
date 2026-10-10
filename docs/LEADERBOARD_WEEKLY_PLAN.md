# PLAN: Leaderboard Mingguan (mulai Senin, reset tiap minggu)

Dokumen eksekusi untuk sistem papan peringkat mingguan. Meneruskan kontrak
angka di [`api/31-api-leaderboard.md`](./api/31-api-leaderboard.md) (belum
diimplementasi, jadi kontraknya boleh dimutakhirkan sekarang) dan backlog
[`backlogs/GAMIFIKASI.md`](./backlogs/GAMIFIKASI.md).

Prinsip desain: **papan live tidak pernah mengeksekusi query agregat per
request user**. Skor dihitung cron di belakang, hasilnya dipublikasikan sebagai
file JSON statis ke repo GitHub publik, dan client membaca lewat URL CDN tetap.
API tetap ada sebagai fallback dan sumber kebenaran, tetapi jalur panas
beralih ke CDN.

| Dokumen terkait | Peran |
| --- | --- |
| [`api/31-api-leaderboard.md`](./api/31-api-leaderboard.md) | Kontrak skor + endpoint (diupdate oleh plan ini) |
| [`backlogs/GAMIFIKASI.md`](./backlogs/GAMIFIKASI.md) | Urutan kerja V1 + event analitik |
| [`GAMIFIKASI_CONCEPT.md`](./GAMIFIKASI_CONCEPT.md) | Konsep streak / point / badge |
| [`ROADMAP_PLAN.md`](./ROADMAP_PLAN.md) Section 8 | Ambang aktivasi gamifikasi |
| [`api/api-base-stack.md`](./api/api-base-stack.md) | Section 19 ULID, 20 Bruno, 21 audit, 24 subrequest |

---

## 1. Keputusan utama (ringkas)

1. **Siklus**: minggu ISO-8601, Senin 00:00:00 WIB (UTC+7) sampai Senin
   berikutnya 00:00:00 WIB (eksklusif). `week_id` format `2026-W40`.
2. **Skor**: persis kontrak 31: `contributions` (disetujui) + `verifications`
   (keputusan review) = `combined`. Komentar tidak masuk gabungan. Skor selalu
   dihitung ulang dari baris yang ada; **tidak ada kolom poin tersimpan**.
3. **Reset**: bukan penghapusan data. Window query `[week_start, week_end)`
   bergeser tiap Senin, otomatis "mulai dari nol". Snapshot minggu lalu
   dibekukan saat finalize.
4. **Top 30 dicatat ke database**: tabel `leaderboard_weeks` +
   `leaderboard_week_entries` (snapshot final per minggu, maksimal 30 baris).
5. **Distribusi CDN raw**: repo GitHub publik `sambasku/leaderboard`.
   - `current.json` (mutable) disajikan via `raw.githubusercontent.com`,
     `cache-control: max-age=300` (diverifikasi: 5 menit). URL tetap selamanya.
   - `weekly/<week_id>.json` (immutable setelah finalize) disajikan via
     `cdn.jsdelivr.net/gh/...@main`, cache edge 12 jam + browser 7 hari
     (`max-age=604800, s-maxage=43200`, diverifikasi). Aman karena isinya
     tidak pernah berubah.
6. **Pipeline**: hook ke cron Workers yang sudah ada (`* * * * *`, handler
   `scheduled`). Job due ditentukan dari state database (idempotent,
   self-healing), bukan cron expression baru.
7. **API** `GET /api/v1/leaderboard` tetap dibuat (fallback, all-time, dan
   deep query), dengan `Cache-Control` supaya bisa di-cache reverse proxy.
   Client dipandu ke URL CDN lewat field `cdn` di response.

---

## 2. Definisi siklus mingguan

| Hal | Nilai |
| --- | --- |
| Zona waktu | WIB (UTC+7), tanpa DST |
| Awal minggu | Senin 00:00:00 WIB |
| Akhir minggu | Senin berikutnya 00:00:00 WIB (eksklusif) |
| `week_id` | ISO-8601 `YYYY-"W"ww`, contoh `2026-W40` |
| Ekuivalen UTC | Senin 00:00 WIB = Minggu 17:00 UTC |

Aturan:

- Hitungan skor seorang user pada minggu W = semua kejadian yang
  `updated_at` (kontribusi) / `created_at` (review) jatuh di window W.
- Semantics timestamp mengikuti 31: kontribusi dihitung saat
  `status` menjadi `approved`/`corrected` (`contributions.updated_at`),
  verifikasi dihitung saat keputusan dibuat
  (`contribution_reviews.created_at`), maksimal satu per baris review.
  Koreksi yang terjadi setelah minggu berjalan menggeser kontribusi ke
  minggu saat koreksi itu terjadi, sampai snapshot dibekukan saat finalize.
- Excluded user: `anonim`, soft-deleted, `is_active = false` (kontrak 31).
- Seri skor: rank sama, urut `username` asc, rank berikutnya melompat
  (dua orang rank 2, berikutnya rank 4). Kontrak 31 dipertahankan.

---

## 3. Arsitektur distribusi (CDN raw)

### 3.1 Repo target

Repo GitHub publik baru: `sambasku/leaderboard` (pola sama dengan
`sambasku/images` dan `sambasku/audios`). Daftarkan sebagai submodule di
root monorepo seperti submodul media lain. Isi hanya file JSON kecil
(tiap file ~3-6 KB untuk 30 entri).

Layout:

```text
main branch
├── current.json              # mutable: papan minggu berjalan, ditimpa tiap refresh
└── weekly/
    ├── 2026-W39.json          # immutable: hasil final top 30
    └── 2026-W40.json
```

### 3.2 URL dan bukti cache

| File | URL (tetap selamanya) | Cache | Sifat |
| --- | --- | --- | --- |
| `current.json` | `https://raw.githubusercontent.com/sambasku/leaderboard/main/current.json` | `max-age=300` (5 menit) | mutable, ditimpa |
| `weekly/<id>.json` | `https://cdn.jsdelivr.net/gh/sambasku/leaderboard@main/weekly/<id>.json` | edge 12 jam, browser 7 hari | immutable |

Kenapa dipisah host: jsDelivr untuk ref `@main` cache 7 hari (terlalu
stale untuk papan live), sedangkan raw GitHub hanya 5 menit (pas untuk
mutable). Sebaliknya file history tidak pernah berubah, jadi cache
panjang jsDelivr justru menghemat. Kedua host sudah dipakai proyek ini
(jsDelivr via `buildJsDelivrPublicUrl`, raw via provider GitHub), bukan
infra baru.

Client tidak menghitung URL sendiri: response API mengembalikan kedua URL
(di `meta.cdn`), dan app menyimpan satu konstanta basis. Mengganti host
cukup ubah satu tempat.

### 3.3 Alur client

```text
Buka tab "Minggu ini"
  → GET current.json (raw, cache 5 menit)      [tidak menyentuh API sama sekali]

Buka tab "Riwayat"
  → hitung daftar week_id masa lalu secara lokal (matematika ISO week dari
    tanggal hari ini; tidak butuh request)
  → GET weekly/2026-W39.json (jsDelivr)         [cache praktis permanen]
  → 404 = minggu itu belum ada (sebelum fitur aktif) → sembunyikan dari daftar
```

Keputusan: **tidak ada `history.json`**. Daftar minggu diderivasi lokal,
404 ditangani UI. Tidak ada file indeks yang harus dijaga sinkron.

### 3.4 Efek ke beban API

Request papan live dan riwayat tidak pernah mengeksekusi query Turso.
Origin GitHub kepegang paling baru sekali per 5 menit per POP untuk
`current.json`. API hanya dipakai: (a) refresh/revalidate cache app saat
cold start, (b) papan all-time, (c) operasi admin. Ini memindahkan baca
leaderboard dari "1 invokasi Workers + 2-3 query per user" menjadi "nol".

---

## 4. Skema database

Dua tabel baru, mengikuti konvensi (ULID `varchar(26)` PK, soft delete
Section 7 base-stack, nama migration deskriptif).

```text
leaderboard_weeks
  id            varchar(26) PK
  week_id       text NOT NULL UNIQUE        -- '2026-W40'
  started_at    timestamp NOT NULL          -- Senin 00:00 WIB
  ended_at      timestamp NOT NULL          -- Senin berikutnya 00:00 WIB, eksklusif
  metric        text NOT NULL DEFAULT 'combined'
  finalized_at  timestamp NULL              -- NULL = belum dibekukan
  published_url text NULL                   -- URL jsDelivr weekly/<id>.json
  created_at    timestamp NOT NULL
  updated_at    timestamp NULL
  deleted_at    timestamp NULL
  deleted_by    varchar(26) NULL FK users

leaderboard_week_entries
  id              varchar(26) PK
  week_id         text NOT NULL FK leaderboard_weeks.week_id
  user_id         varchar(26) NOT NULL FK users.id
  rank            integer NOT NULL
  username        text NOT NULL             -- snapshot, tidak ikut rename user
  avatar_url      text NULL                 -- snapshot
  contributions   integer NOT NULL
  verifications   integer NOT NULL
  combined        integer NOT NULL
  is_verifier     integer NOT NULL DEFAULT 0
  created_at      timestamp NOT NULL
  UNIQUE (week_id, user_id)
```

Alasan snapshot `username`/`avatar_url`: file history immutable dan profil
bisa berubah; snapshot menjaga file minggu lalu konsisten selamanya.

Index bantu komputasi (migration terpisah atau sama):

```sql
CREATE INDEX idx_contributions_status_updated ON contributions (status, updated_at);
CREATE INDEX idx_contribution_reviews_reviewer_created ON contribution_reviews (reviewer_id, created_at);
CREATE INDEX idx_leaderboard_entries_week ON leaderboard_week_entries (week_id);
```

Kenapa simpan ke DB padahal JSON ada di git: (a) sumber kebenaran yang
bisa diaudit dan direpublikasi ulang tanpa rekalkulasi ambigu, (b) bahan
badge "top 10 minggu X" dan tampilan console, (c) recovery saat repo CDN
hilang. Biayanya 30 baris per minggu, sepele.

`docs/dbdiagram.dbml` diupdate di PR yang sama.

---

## 5. Pipeline: refresh dan finalize

### 5.1 Hook scheduler

Tidak ada cron expression baru. Handler `scheduled` di `src/worker.ts`
sudah berjalan tiap menit (`crons = ["* * * * *"]`, staging dan produksi).
Tambah satu export di `app.ts`, pola sama dengan `runDueNotificationCampaigns`:

```text
runDueLeaderboardJobs(): Promise<{ refreshed: boolean; finalized: boolean }>
```

Logika due murni dari state DB + jam sekarang (idempotent, self-healing;
kalau satu tick terlewat, tick menit berikutnya mengejar):

1. **Finalize due?** Ada minggu yang `ended_at <= now` tetapi belum ada
   baris `leaderboard_weeks.finalized_at` untuk `week_id` itu → jalankan
   finalize untuk minggu tersebut (bisa > 1 kalau cron lama mati).
2. **Refresh due?** `now - last_modified current.json >= 6 jam` (cek dari
   kolom `updated_at` baris minggu berjalan; jika baris minggu berjalan
   belum ada, buat) → hitung ulang dan publikasikan `current.json`.

Konstanta di domain (bukan env, nilainya bukan konfigurasi operasional):
`TOP_N = 30`, `REFRESH_INTERVAL_HOURS = 6`.

Runtime Node lokal tidak punya scheduler; gunakan endpoint admin di bawah
untuk memicu manual saat dev dan operasi.

### 5.2 Urutan finalize (minggu W berakhir)

Satu invokasi, total ~8 subrequest (jauh di bawah 50, Section 24):

```text
1. Hitung top 30 window [started_at, ended_at)        (2 query agregat, db.batch)
2. INSERT leaderboard_weeks (upsert by week_id)
   + INSERT 30 baris leaderboard_week_entries          (1 batch)
3. Publikasikan weekly/<W>.json ke GitHub              (GET sha + PUT = 2 fetch)
4. Hitung window baru [ended_at, ended_at+7hari)
   dan publikasikan current.json minggu baru           (GET sha + PUT = 2 fetch)
5. UPDATE finalized_at + published_url, tulis audit_logs
   (action 'publish', entity_type 'leaderboard_week', user sistem cron)
```

Idempotensi: semua langkah boleh diulang. Konten file deterministik dari
DB, PUT GitHub menimpa dengan sha terbaru, upsert UNIQUE `(week_id)`.
Kalau invokasi mati di tengah, tick menit berikutnya mengulang tanpa
merusak apa pun. Tidak perlu lock terdistribusi (writer tunggal: cron).

Commit message repo leaderboard: `leaderboard: finalize 2026-W40` dan
`leaderboard: refresh 2026-W40 2026-09-29T12:00:00Z`.

### 5.3 Bentuk file JSON

Bukan envelope API (`success`/`data`) karena ini file statis, bukan
response endpoint:

```json
{
  "week_id": "2026-W40",
  "starts_at": "2026-09-28T00:00:00+07:00",
  "ends_at": "2026-10-05T00:00:00+07:00",
  "finalized": false,
  "generated_at": "2026-09-29T12:00:00Z",
  "entries": [
    {
      "rank": 1,
      "username": "rina",
      "avatar_url": null,
      "contributions": 8,
      "verifications": 4,
      "combined": 12,
      "is_verifier": true
    }
  ]
}
```

`weekly/<id>.json` bentuk sama dengan `"finalized": true`. Minggu kosong
tetap dipublikasikan (`entries: []`) supaya kontinuitas week_id utuh dan
UI tidak butuh kasus khusus.

---

## 6. Modul API: `modules/leaderboard/`

Struktur mengikuti base-stack Section 3 (feature-based):

```text
modules/leaderboard/
├── domain/
│   ├── entities/leaderboard-week.entity.ts
│   └── utils/iso-week.ts            # week math WIB: weekId(date), window(weekId), lastMonday, ISO week dari id
├── application/
│   ├── ports/leaderboard-storage.port.ts     # publishCurrent / publishWeekly
│   ├── use-cases/
│   │   ├── compute-live-leaderboard.use-case.ts   # window berjalan
│   │   ├── finalize-leaderboard-week.use-case.ts  # snapshot + publish + audit
│   └── dto/leaderboard.dto.ts
├── infrastructure/
│   ├── leaderboard.repository.impl.ts        # query agregat Drizzle + snapshot
│   ├── github-leaderboard-storage.service.ts # pola public-image: Contents API PUT
│   └── leaderboard-storage.factory.ts
└── presentation/v1/
    ├── leaderboard.routes.ts
    ├── leaderboard.controller.ts
    └── validators/leaderboard.validator.ts
```

Reuse langsung: `parseGithubRepoUrl`, `bytesToBase64`,
`buildJsDelivrPublicUrl` dari `modules/word/application/utils/github-repo-url.ts`;
pola retry + error mapping dari `github-public-image-storage.service.ts`.
URL `current.json` dibangun dari owner/repo env, host raw; URL weekly
memakai `buildJsDelivrPublicUrl`.

### 6.1 Endpoint publik

`GET /api/v1/leaderboard` (publik, tanpa autentikasi, rate 100/menit per
IP sesuai tabel Section 15):

| Query | Nilai |
| --- | --- |
| `period` | `week` (default, minggu BERJALAN dengan window Senin tetap, bukan rolling 7 hari) atau `all` |
| `week_id` | opsional, hanya untuk `period=week` masa lalu: baca snapshot DB. Masa depan → 404 `LEADERBOARD_WEEK_NOT_FOUND` |
| `metric` | `combined` (default). `contributions`/`verifications` hanya untuk `period=all` live (snapshot mingguan hanya combined) |

Response (envelope standar):

```json
{
  "success": true,
  "data": [ { "rank": 1, "username": "rina", "avatar_url": null,
              "contributions": 8, "verifications": 4, "combined": 12,
              "is_verifier": true } ],
  "meta": {
    "week_id": "2026-W40",
    "resets_at": "2026-10-05T00:00:00+07:00",
    "cdn": {
      "current": "https://raw.githubusercontent.com/sambasku/leaderboard/main/current.json",
      "weekly": "https://cdn.jsdelivr.net/gh/sambasku/leaderboard@main/weekly/2026-W40.json"
    }
  }
}
```

Header `Cache-Control: public, max-age=300` di endpoint ini supaya
reverse proxy ikut membantu.

Perubahan kontrak 31 yang dibawa plan ini (31 diupdate di PR yang sama,
statusnya memang belum diimplementasi):

- `period=week` berganti makna: dari "rolling 7 hari" menjadi "minggu
  kalender Senin WIB", plus parameter `week_id`.
- Response menambah `meta.week_id`, `meta.resets_at`, `meta.cdn`, dan
  field skor rinci per entri.
- Endpoint ini menjadi jalur sekunder; jalur utama client adalah CDN.

### 6.2 Endpoint admin (operasional)

- `POST /api/v1/admin/leaderboard/refresh` → paksa publikasi ulang
  `current.json` (pemulihan setelah koreksi data).
- `POST /api/v1/admin/leaderboard/finalize` dengan body `week_id` opsional
  (default: minggu terakhir yang belum final) → eksekusi finalize manual,
  juga dipakai untuk dev di runtime Node.

Role admin/root, rate longgar sesuai Section 15. Keduanya memanggil use
case yang sama dengan cron.

---

## 7. Environment dan setup

| Env | Contoh | Catatan |
| --- | --- | --- |
| `LEADERBOARD_GITHUB_URL` | `https://github.com/sambasku/leaderboard` | `[vars]` wrangler, non-secret |
| `LEADERBOARD_GITHUB_TOKEN` | fine-grained PAT | `wrangler secret put`, scope Contents read/write repo leaderboard saja |

Kosong = fitur mati dengan rapi (publikasi dilewati, log `warn`, DB tetap
finalized; pola "fitur mati tanpa crash" seperti `GOOGLE_CLIENT_ID`).
Setup repo sekali: buat repo publik kosong, token fine-grained, isi env
staging lalu produksi. Submodule `leaderboard/` didaftarkan di monorepo.

---

## 8. Privasi, keamanan, dan aturan produk

- Data yang dipublikasikan hanya data yang SUDAH publik di profil publik
  (username, avatar, flag peran, statistik agregat). Tanpa email, tanpa
  ID internal user di file JSON (username cukup untuk deep link profil).
- Karena statistik profil memang publik, V1 leaderboard **tanpa opt-in**
  (paritas eksposur dengan `19-api-profil-publik.md`). Kalau nanti ada
  permintaan privasi, tambahkan flag opt-out dan filter di compute; itu
  perubahan kecil yang tidak perlu ditebak sekarang.
- Token GitHub scope satu repo, tidak bisa menulis repo lain.
- Anti-pola GAMIFIKASI dijaga: komentar tidak masuk `combined`, vote tidak
  diskor, tidak ada XP buatan.
- ROADMAP Section 8 menyarankan menunggu ambang volume kontributor. Plan
  ini memisahkan **infrastruktur** (boleh jalan duluan, biayanya cron dan
  file kecil) dari **aktivasi UI** (menyusul keputusan PO saat ambang
  terpenuhi; gate = merge slice mobile, bukan flag runtime).

---

## 9. Client (mobile V1, web menyusul)

Sesuai urutan kerja `backlogs/GAMIFIKASI.md`:

1. Layar "Papan Peringkat", entry dari Profil.
2. Tab "Minggu ini" → `current.json`; tab "Riwayat" → daftar week_id
   lokal + `weekly/<id>.json`, 404 disembunyikan.
3. Header menampilkan countdown `resets_at` (dari field file).
4. Tampilkan breakdown kecil (kontribusi / verifikasi), bukan angka tunggal.
5. Offline-friendly: cache respons di disk, tampilkan `generated_at`
   sebagai penanda kesegaran.

Event analitik ditambahkan ke tabel Section 14
`docs/mobile/mobile-base-stack.md` di PR yang sama:

| Event | Kapan | Params |
| --- | --- | --- |
| `leaderboard_view` | buka papan | `period`, `source` (`cdn` / `api`) |
| `leaderboard_history_open` | buka tab riwayat | `week_id` |

Web menyusul pola yang sama (fetch CDN + SW cache); tidak memblokir V1.

---

## 10. Testing

Mengikuti Section 10 base-stack:

- **Unit (wajib PR)**: `iso-week.ts` adalah satu-satunya matematika rumit:
  Senin 00:00 WIB di batas tahun (minggu 53 / minggu 1), `2026-01-01`
  jatuh minggu berapa, `window()` monoton 7 hari, dan round-trip
  `weekId(date)`. Satu file test menutup semuanya.
- **Unit**: finalize use case dengan repository mock: urutan langkah,
  idempotensi (panggil dua kali, publish terjadi dua kali dengan konten
  identik, DB tidak dobel).
- **Integration**: query agregat window di `file:./test.db` terhadap data
  seed: kontribusi approved di dalam vs di luar window, excluded user.
- **E2E**: `GET /api/v1/leaderboard` happy path + 404 `week_id` masa
  depan; admin refresh dengan storage mock.
- Smoke staging Workers pasca-deploy (Section 24: lokal Node tidak
  menegakkan budget subrequest): `bruno run http/leaderboard/` dan cek
  file repo staging.

---

## 11. Sinkronisasi dokumen dan koleksi (checklist PR)

| Artefak | Aksi |
| --- | --- |
| `docs/dbdiagram.dbml` | Tambah 2 tabel + index |
| `docs/api/31-api-leaderboard.md` | Update semantik `week` + `week_id` + `meta.cdn` |
| `api/src/.../ERROR_CODES.md` | `LEADERBOARD_WEEK_NOT_FOUND` (404), `LEADERBOARD_STORAGE_UNAVAILABLE` (503) |
| `http/leaderboard/*.bru` | `get-leaderboard-week.bru`, `get-leaderboard-all.bru`, `get-leaderboard-history.bru`, `admin-refresh.bru`, `admin-finalize.bru` (konvensi Section 20) |
| `docs/json/leaderboard/` | Contoh response API + isi current.json / weekly file |
| `docs/mobile/mobile-base-stack.md` | Tabel event Section 14 |
| `backlogs/GAMIFIKASI.md` | Tandai V1 leaderboard dieksekusi via plan ini |
| `.gitmodules` | Submodule `leaderboard/` |

---

## 12. Urutan PR (slice)

1. **Fondasi**: migration 2 tabel + index, dbml, `iso-week.ts` + unit test.
2. **Modul leaderboard**: repository agregat, use case compute/finalize,
   storage port + impl GitHub, env. Admin endpoints + Bruno + json samples.
3. **Endpoint publik + cron**: `GET /api/v1/leaderboard`, hook
   `runDueLeaderboardJobs()` di `worker.ts`, ERROR_CODES, update dokumen 31.
4. **Repo + deploy**: buat repo `sambasku/leaderboard`, submodule, secrets
   staging, deploy staging, verifikasi siklus refresh + finalize staged
   (minggu dummy bisa diuji dengan admin finalize `week_id` manual).
5. **Mobile UI + analitik** (gate aktivasi PO): layar + event, DebugView
   staging.
6. **Produksi**: secrets produksi, deploy, observe minggu pertama penuh
   (refresh + finalize + file history).

Opsional (bukan penghalang): backfill minggu historis sejak data mulai
ada (loop finalize per `week_id` lama, query-nya sama) supaya tab Riwayat
tidak kosong saat rilis.

---

## 13. Risiko dan mitigasi

| Risiko | Mitigasi |
| --- | --- |
| Cron Workers terlewat saat finalize | Due-check dari DB tiap menit, self-healing; finalize manual via admin endpoint |
| GitHub Contents API down saat publish | Retry 1x (pola public-image); gagal = `finalized_at` tetap NULL, tick berikutnya ulang; API tetap bisa melayani live |
| raw GitHub 5 menit stale | Acceptable by design; `generated_at` ditampilkan; admin refresh untuk paksa |
| Konten weekly file berubah setelah publish | Dilarang by contract; koreksi hanya lewat republikasi manual dengan audit |
| Username berubah | Snapshot membekukan username saat finalize; file lama konsisten |
| Volume kontributor masih di bawah ambang ROADMAP | Infra jalan duluan (biaya sepele), aktivasi UI menunggu gate PO |
| Abuse scraping API fallback | Rate limit 100/menit + `max-age=300`; jalur utama memang CDN |

---

## 14. Ringkasan satu halaman

- Minggu ISO Senin 00:00 WIB, `week_id` `2026-W40`, reset otomatis lewat
  window query, bukan penghapusan.
- Skor = kontribusi disetujui + verifikasi selesai (kontrak 31), tanpa
  kolom poin; komentar dan vote tidak dihitung.
- Cron per menit (yang sudah ada) menjalankan refresh tiap 6 jam dan
  finalize Senin 00:00 WIB, idempotent dari state DB.
- Finalize: simpan top 30 ke `leaderboard_weeks` + entries, publikasikan
  `weekly/<id>.json` (jsDelivr, immutable) dan reset `current.json`
  (raw GitHub, cache 5 menit, URL tetap).
- Client: live selalu hit URL CDN tetap; riwayat hit URL per minggu;
  API hanya fallback. Turso tidak tersentuh oleh trafik leaderboard.
