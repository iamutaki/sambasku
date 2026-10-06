# Mobile Local Strategy

Status: **kontrak strategi** (living doc - update di PR yang sama
saat keputusan implementasi berubah).
Dokumen ini **mandiri**: cukup dibaca di sini untuk memahami masalah,
solusi, arsitektur, kriteria, dan urutan kerja. Tidak mensyaratkan
membaca backlog lain.

Ruang lingkup: aplikasi Flutter di `mobile/`.
Pasangan web (OPFS / SQLite WASM) di luar dokumen ini.

**Keputusan L1 (Fase A):** durable store = **`hive_ce`**
(+ `hive_ce_flutter`). Lihat §5.4.1.

**Keputusan L2 (dikunci 2026-09-28; eksekusi kode dipisah DS lalu B):**

| Topik | Keputusan | Lihat |
| --- | --- | --- |
| Install awal | Download-on-first-run (bukan bundle APK) | §5.6, §17 |
| Kelola update | Halaman dari tab Profil | §5.6 |
| Baca kamus | **API + L1** saat online; **SQLite L2 hanya saat fail / offline** (bukan hybrid, bukan local-primary) | §3.2, §16.2 |
| Hosting artifact | **Repo publik** [`sambasku/database`](https://github.com/sambasku/database) + GitHub Release assets | §18 |
| Populate repo | **Ya di Fase DS** (rilis pertama dari export CLI) | §18.3 |
| Stack baca/tulis L2 | Tools §17 | §17 |
| Urutan kerja | **Fase DS** (dataset/pipeline) **sebelum** **Fase B** (mobile SQLite) | §8, §19 |

**Status implementasi (2026-09-28):**

| Fase | Status |
| --- | --- |
| A Cache L1 (inti) | **Selesai di kode** - lihat §8 / §10 |
| A sisa | L4 mutasi UI, share backgrounds (opsional) |
| **DS** Public dataset + pipeline + Release v1 | **Hampir hijau** - Release v1 ada; push schema/active + re-export staging |
| B Mobile SQLite consume (unduh, **fail/offline fallback**, Profil) | **Ditunda** sampai DS hijau |
| C-E updater ops / Console / cabut L1 kamus | **Belum** (cabut L1 kamus **tidak** jadi tujuan; L1 tetap jalur online) |

Fase A yang sudah masuk `mobile/`: scaffold `core/cache`, reference
kontribusi, WOTD, feed `latest`, **detail kata** (`words/:id` + lemma),
discussion published, pull-to-refresh hard miss, logout wipe
user-scoped, Response Cache explorer + badge HIT/STALE/DEGRADED di
Network Monitor.

---

## 1. Jawaban singkat

**Ya.** Kombinasi **cache respons lokal** + **SQLite dataset kamus**
adalah **hardening klien** terhadap keterbatasan **free-tier** backend,
bukan pengganti failover host dan bukan upgrade paket hosting.

| Masalah free-tier | Apa yang membantu | Apa yang tidak cukup |
| --- | --- | --- |
| Rate limit API (~100/menit per IP/device pada endpoint publik) | Kurangi hit: cache + baca dari SQLite | Failover ke host lain (429 tidak boleh pindah host) |
| Kuota subrequest Cloudflare Workers (Free: 50/invocation) | Lebih sedikit request baca kamus dari klien | Host cadangan di akun Cloudflare yang sama tetap berbagi tekanan edge |
| Cold start Render (~15 menit idle, bangun sampai ~60 dtk) | Kamus tidak menunggu host hangat | Failover hanya memindahkan request; tetap butuh network |
| API / CDN / internet mati | SQLite yang sudah terpasang tetap bisa search/detail | Cache HTTP hanya untuk data yang pernah di-fetch |
| Cold start app (kill process) | Disk cache + SQLite bertahan | Riverpod `keepAlive` hilang |

Prinsip produk:

```text
Server menerbitkan (API + dataset release cadangan).
Klien online: baca kamus dari API (+ cache L1).
Klien offline / API gagal: baca dari SQLite yang sudah terpasang.
Operasi dinamis tetap ke API (dengan failover host).
```

---

## 2. Masalah yang diselesaikan

### 2.1 Konteks infrastruktur SambasKu (hari ini)

Mobile berbicara ke API lewat Dio + Retrofit, dengan **circuit breaker
tiga tier** di `lib/core/network/failover/`:

| Tier | Host (konsep) | Catatan free-tier |
| --- | --- | --- |
| 1 | Cloudflare Worker | Subrequest terbatas; kapasitas penuh → 503 `UPSTREAM_CAPACITY` |
| 2 | Deno Deploy (via edge) | Bukan solusi kuota request harian yang sama; tetap butuh network |
| 3 | Render free | Cold start lama; diletakkan terakhir |

Failover **hanya** memindahkan request ke host lain saat timeout /
502-504 / kapasitas upstream. Failover **bukan**:

- cache payload respons,
- database kamus offline,
- cara menghindari 429 `RATE_LIMITED`.

Tanpa lapisan lokal, setiap buka detail, search, list, dan form
kontribusi (refetch languages / dialects / word-classes) menekan kuota
yang sama.

### 2.2 Gejala yang ingin hilang

1. User sering kena 429 saat browsing / search beruntun.
2. Form kontribusi gagal load referensi karena refetch berulang.
3. Setelah cold host atau API down, app terasa "kamus rusak" padahal
   data published sudah pernah ada.
4. Airplane mode: tidak bisa cari lemma yang belum pernah dibuka
   (cache tipis tidak cukup; butuh SQLite penuh).

### 2.3 Bukan tujuan strategi ini

- Mengganti paket hosting / menghapus free-tier.
- Offline-first untuk **semua** fitur (auth, submit, vote, inbox).
- Menyimpan access/refresh token di cache atau SQLite publik (tetap
  `flutter_secure_storage` via `AuthTokenStorage`).
- Antrean offline diam-diam untuk POST submit/vote (risiko ganda /
  konflik; backlog terpisah).
- ETag / 304 dari API (fase lanjut, bukan syarat V1).
- Differential patch dataset (full replace dulu).

---

## 3. Dua lapisan lokal (jangan disatukan)

Kedua lapisan menyelesaikan nyeri berbeda. **Jangan** jadikan file
cache HTTP sebagai "database kamus", dan **jangan** taruh token/PII
di SQLite publik.

```text
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Mobile                          │
│                                                             │
│  L0  Riverpod keepAlive          (in-session, hilang kill)  │
│  L1  ResponseCacheStore          (hive_ce, TTL / SWR)       │
│      → jalur normal baca kamus saat online                  │
│  L2  Local SQLite + FTS          (dataset release;          │
│      **hanya** bila device offline / API gagal total)       │
│  Ln  API + failover hosts        (sumber kebenaran online)  │
└─────────────────────────────────────────────────────────────┘
```

| Lapisan | Isi | Freshness | Bertahan cold start? | Peran vs free-tier |
| --- | --- | --- | --- | --- |
| L0 | Object di memori provider | Selama sesi | Tidak | Hemat refetch in-session |
| L1 | JSON/blob per key HTTP di **hive_ce** | `fresh` / `staleMax` + event | Ya | Kurangi hit API saat browsing online |
| L2 | Tabel kamus + FTS5 | `release_version` | Ya | **Cadangan** saat offline / API unreachable (bukan primary) |
| API | Server | Real-time | n/a | Sumber kebenaran online; mutasi, privat, sync |

### 3.1 Kapan pakai L1 (cache respons)

- Reference yang sering di-refetch (languages, dialects, word-classes).
- Word of the day, feed singkat, discussion published.
- **Detail kata** (`words/:id`, lemma) - tulis saat masuk detail;
  baca ulang dalam TTL = HIT tanpa request.
- Search (opsional / TTL pendek) bila diaktifkan nanti.

### 3.2 Kapan pakai L2 (SQLite) - **fail / offline saja**

SQLite **bukan** hybrid local-primary. Baca L2 **hanya** jika salah
satu kondisi ini benar:

1. Device **offline** / kehilangan internet (airplane, no signal).
2. API **tidak bisa dihubungi** setelah failover habis: timeout,
   502-504 beruntun, kapasitas edge habis (`UPSTREAM_CAPACITY`),
   free-tier Cloudflare / host lain menolak sampai klien anggap
   "unreachable" (bukan sekadar 404 lemma).

Saat kondisi di atas: search / detail / list A-Z dari korpus lokal
yang sudah diunduh. Saat online + API hidup: **selalu API (+ L1)**,
abaikan SQLite untuk jalur baca normal.

### 3.3 Kapan tetap API saja

- Auth, refresh token, `/auth/me`.
- Inbox, bookmark, vote pribadi, profil privat.
- Semua POST / PATCH / DELETE.
- Admin / review queues.
- Semua baca kamus saat **online + API OK** (L1 boleh HIT).

---

## 4. Klasifikasi data (sumber kebenaran)

| Kelas | Contoh | Baca target | Persist disk? |
| --- | --- | --- | --- |
| Kamus published | search, detail, list A-Z | **API + L1** online; **SQLite L2** hanya fail/offline | Ya (L1 TTL + dataset) |
| Rujukan statis | languages, dialects, word-classes | **cache L1**; L2 opsional di release untuk offline | Ya |
| Semi-dinamik publik | WOTD, latest feed, discussion | **API + cache L1** | Ya (TTL pendek) |
| Privat / sesi | me, inbox, vote, bookmark | **API only** | Tidak (kecuali token secure storage) |
| Mutasi | submit, edit, review | **API + failover** | Tidak di cache |

Aturan bisnis snapshot publik:

- Hanya status `published` yang boleh masuk SQLite release.
- `pending_review` / `draft` / `rejected` tidak masuk dataset.
- Users, email, password hash, sessions, tokens, audit, catatan
  moderasi internal **tidak pernah** masuk dataset publik.

---

## 5. Arsitektur di struktur proyek mobile

Mengikuti Clean Architecture feature-first (`mobile/`):

```text
presentation → domain → data
core/   = lintas fitur (network, cache store, sqlite open, failover)
shared/ = splash, dev tool
features/<fitur>/ = domain + data + presentation
```

UI / Notifier **tidak** menghitung TTL, tidak memilih file DB, tidak
memanggil Dio langsung untuk kamus.

### 5.1 Alur dependency (target)

```text
presentation (Notifier / Riverpod)
  → domain (usecase + repository interface)
    → data:
         repository impl
           ├── ResponseCacheStore          (L1 hive_ce - jalur online)
           ├── DictionaryRemoteDatasource  (Retrofit - sumber online)
           ├── DictionaryLocalDatasource   (SQLite L2 - **hanya**
           │                                bila offline / API fail)
           └── remote lain (auth, vote, …) tanpa cache disk
```

### 5.2 Penempatan folder (usulan konkret)

```text
mobile/lib/
├── core/
│   ├── network/
│   │   ├── failover/                 # sudah ada (circuit breaker host)
│   │   ├── sambasku_api_client.dart
│   │   └── …
│   ├── cache/                        # BARU (L1) - hive_ce
│   │   ├── response_cache_store.dart       # abstract
│   │   ├── response_cache_store_impl.dart  # Hive boxes (index + body)
│   │   ├── cache_entry.dart
│   │   ├── cache_policy.dart               # fresh / staleMax per kelas
│   │   └── cache_key.dart                  # METHOD|path|query normalisasi
│   ├── local_db/                     # BARU (L2)
│   │   ├── dictionary_database.dart        # open / path / version meta
│   │   ├── dictionary_db_updater.dart      # download, verify, atomic swap
│   │   ├── dictionary_db_metadata.dart     # release/schema lokal
│   │   └── schema/                         # versi schema yang didukung app
│   └── …
├── features/
│   ├── dictionary/
│   │   ├── domain/
│   │   │   ├── repositories/dictionary_repository.dart   # tetap interface
│   │   │   └── …
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── dictionary_remote_datasource.dart     # sudah ada
│   │   │   │   └── dictionary_local_datasource.dart      # BARU SQLite
│   │   │   ├── repositories/dictionary_repository_impl.dart
│   │   │   └── …
│   │   └── presentation/ …
│   ├── contribution/   # reference: lewat cache L1 dulu, nanti L2
│   ├── discussion/  # tetap API + L1
│   └── …
```

Konvensi penamaan mengikuti pola existing: `*_repository.dart`,
`*_repository_impl.dart`, `*_remote_datasource.dart`,
`*_local_datasource.dart`, provider per tier (`*_data_providers.dart`).

### 5.3 Repository dictionary (strategi baca)

```text
getWord / search / list
        │
        ▼
┌───────────────────┐
│ connectivity +    │  online + API OK → remote (+ L1)
│ API health        │  offline / API fail → SQLite L2
└─────────┬─────────┘
          │
    ┌─────┴─────┐
    ▼           ▼
  Remote      SQLite L2
  (+ L1)      (cadangan fail/offline saja)
```

Target produksi: **online = API + L1**; **fail/offline = L2**.
Tidak ada Hybrid A / silent `localThenRemote` saat online.
Telemetry: tandai sumber `remote` | `l1` | `l2_offline` | `l2_api_fail`.

### 5.4 Alur cache-aside + SWR (L1)

```text
butuh data (kelas L1)
  → age <= fresh?           → sajikan cache (0 hit API)
  → fresh < age <= staleMax → sajikan stale + revalidate background
  → miss atau age > staleMax → request API sync → simpan → sajikan
  → network gagal + ada stale → sajikan stale + tandai isStale
```

Aturan tulis:

- 2xx → `put` dengan `cachedAt = now`.
- 4xx aplikasi (selain 404 negative-cache) → **jangan** timpa entry bagus.
- 404 detail/lemma → boleh negative cache singkat.
- 429 / infra failure → **jangan** `put`; pakai stale lama bila ada.

Key: `METHOD|path|normalizedQuery` (tanpa host tier, tanpa token).
Hard cap total cache ~32-50 MB; `evictToBudget` (LRU) saat `put`.

### 5.4.1 Stack L1 (keputusan dikunci)

**Durable store Fase A: `hive_ce` (+ `hive_ce_flutter` untuk init path).**

Bukan File+index manual, bukan `dio_cache_interceptor`, bukan SQLite
(SQLite dipesan untuk L2 dataset release).

| Aspek | Keputusan |
| --- | --- |
| Kenapa Hive | Durabilitas + API KV stabil; kurangi risiko bug index/LRU custom; tidak bentrok mental model L2 |
| Deps | `hive_ce`, `hive_ce_flutter` di `mobile/pubspec.yaml` |
| Boxes | `response_cache_index` (meta: cachedAt, size, lastAccess, scope, schemaVersion); `response_cache_body` (key → JSON string / bytes) |
| Policy TTL/SWR | Tetap di app: `cache_policy.dart` + matriks §5.5 |
| Wiring | Repository layer memanggil `ResponseCacheStore` - **bukan** interceptor Dio global |
| Bukan untuk | Token / PII (`flutter_secure_storage`); korpus kamus (L2 SQLite) |
| Init | Buka box setelah path Hive siap (startup app), inject via Riverpod |

Hygiene dokumen: setiap PR Fase A yang mengubah kontrak L1 (TTL, key,
scope wipe, dep, box schema) **wajib** meng-update file ini di PR yang
sama. Dokumen ini living contract, bukan artefak sekali tulis.

### 5.5 Matriks TTL L1 (kanonik)

| Kelas | Contoh | `fresh` | `staleMax` | Nasib jangka panjang |
| --- | --- | --- | --- | --- |
| Rujukan statis | languages, word-classes, dialects | 24 jam | 7 hari | Tetap L1; L2 boleh ikut release untuk offline |
| Detail kamus | words/:id, lemma | 5 menit | 24 jam | **Tetap L1** (jalur online); L2 = fail/offline |
| Feed / list | words/latest, words page | 2 menit | 1 jam | Tetap API + L1 |
| Word of day | words/today | sampai ganti hari lokal (atau max 1 jam) | 24 jam | API + L1 |
| Search | words/search | 1 menit | 30 menit | Tetap API + L1 online; FTS L2 = fail/offline |
| Sosial publik | discussion | 1 menit | 30 menit | Tetap L1 |
| Negative 404 | lemma/id tidak ada | 2 menit | 2 menit (tanpa SWR) | Tetap L1; L2 miss ≠ "tidak ada di dunia" saat online |
| User / private | me, inbox, vote, bookmark | jangan persist | - | API only |

Invalidation event (L4) di device yang sama:

- Setelah sukses kontribusi / vote / komentar / edit profil: hapus key
  terkait + list terkait.
- Logout / hapus akun: wipe cache **user-scoped**; publik boleh tetap.
- `cacheSchemaVersion` naik: wipe entry versi lama saat startup.
- Pull-to-refresh layar dinamis: hard miss key layar itu.

### 5.6 SQLite dataset + release (L2)

Tiga dunia data yang berbeda:

```text
Production DB (privat)
      │  export published + sanitize (allowlist field)
      ▼
Public SQLite artifact (immutable per version)
      │  download / bundle
      ▼
Flutter Local SQLite (cadangan fail / offline)
```

Artifact release (konsep):

```text
vN/
├── database.sqlite.gz
├── manifest.json
└── SHA256SUMS
```

Manifest minimal:

```json
{
  "release_version": 43,
  "schema_version": 3,
  "min_app_version": "1.8.0",
  "database": {
    "file": "database.sqlite.gz",
    "size": 6328172,
    "sha256": "..."
  },
  "released_at": "2026-09-25T04:00:00Z"
}
```

Update mobile (background, tidak blokir startup):

```text
Open local SQLite → UI siap
        │ background
        ▼
Fetch manifest
        │
   version baru + kompatibel?
        │ ya
        ▼
Download → database.new → sha256 → integrity_check
        → schema check → smoke query → atomic replace
        │ gagal di langkah mana pun
        ▼
Hapus .new; tetap pakai DB lama
```

Initial install (**keputusan dikunci**): **download-on-first-run**,
bukan bundle APK. Progress + copy error yang jelas; jangan blokir splash
tanpa batas waktu / escape. Setelah terpasang, cek update dari halaman
kelola dataset (entry di tab Profil). Artifact diunduh dari repo publik
§18 (HTTPS), bukan dari API production dengan token DB.

---

## 6. Pemisahan dari failover

```text
                    Request dinamis / fallback
                              │
                              ▼
                 FailoverInterceptor (host tier)
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
           Worker           Deno           Render
```

| Mekanisme | Lapisan | Menghemat kuota baca kamus? | Offline search lemma baru? |
| --- | --- | --- | --- |
| Failover host | Network | Tidak (tetap 1 request) | Tidak |
| Response cache L1 | hive_ce (HTTP JSON) | Ya (jika fresh/stale) | Tidak (hanya yang pernah di-fetch) |
| SQLite L2 | Dataset | Ya **saat** fail/offline (0 request) | **Ya** (korpus terpasang) |

Ketiganya **komplementer**. Strategi lokal ini mengasumsikan failover
tetap hidup untuk mutasi dan data dinamis.

---

## 7. Arsitektur end-state (satu gambar)

```text
                         Admin / pipeline
                               │
                        Release dataset
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
              Artifact + manifest    (API production tetap privat)
                    │
                    ▼
              Static host / CDN
                    │
                    ▼
 ┌──────────────────────────────────────────────────────┐
 │                 Flutter Mobile                       │
 │                                                      │
 │   Dictionary online ──► API (+ cache L1) + failover  │
 │   Dictionary fail/  ──► Local SQLite (L2) + FTS      │
 │     offline                                          │
 │   Semi-dinamik      ──► API (+ cache L1) + failover  │
 │   Privat/mutasi     ──► API + failover (+ secure)    │
 └──────────────────────────────────────────────────────┘
```

Janji end-state:

```text
API mati / unreachable → kamus (L2) tetap hidup (korpus terpasang)
CDN mati (unduh update) → kamus versi lama tetap hidup sebagai cadangan
Internet mati           → kamus yang sudah terpasang tetap hidup
Online + API OK         → selalu API + L1 (SQLite tidak dipakai baca)
429 browsing online     → L1 mengurangi hit; L2 tidak menggantikan API
```

---

## 8. Urutan implementasi (strategi ideal)

Jangan parallel penuh: bangun cache kamus lengkap **dan** pipeline
SQLite di sprint yang sama untuk endpoint yang sama.

```text
Fase A   Cache L1 (kelas aman / dinamis + detail) → SELESAI (inti)
Fase DS  Public dataset + pipeline + Release v1   → FOKUS SEKARANG
Fase B   Mobile SQLite consume (fail/offline)     → setelah DS hijau
Fase C   Metadata update otomatis / latar         → belum
Fase D   Release ops Console                      → belum
Fase E   (opsional) perhalus L1 / L2 UX copy      → belum
```

**Fase DS** = fase **tersendiri sebelum B** (bukan sub-langkah B).
Progress DS diukur di repo `database/` + script export `api/`, tanpa
Flutter kamus lokal. **Fase B** baru mulai setelah gate DS hijau.

**Mengapa DS sebelum B (keputusan dikunci):** pipeline dan kontrak
schema harus matang & teruji di luar app. Mobile hanya **mengonsumsi**
artifact yang sudah valid (manifest, sha256, FTS smoke). Kalau schema
masih bergoyang sambil UI dibangun, dual-work dan dual-truth.

Gate DS → B:

- [ ] Dokumen schema publik `schema_version = 1` final (allowlist + FTS).
- [ ] `dataset:export` hijau (integrity + tes kolom terlarang).
- [ ] Repo publik hidup + **Release v1** unduhable lewat URL stabil.
- [ ] Smoke manual: unduh gzip → buka di sqlite CLI → search lemma hit.
- [ ] Item kritis di `database/schema/QUESTIONS.md` terjawab.

Baru setelah itu Fase B fokus ke `core/local_db`, datasource
fail/offline, first-run, halaman Profil.

### Fase A - Cache tipis

Masuk:

1. [x] Tambah `hive_ce` + `hive_ce_flutter`; scaffold `core/cache` + kontrak
   `ResponseCacheStore` di atas Hive boxes (§5.4.1); buka box di startup.
2. [x] Decorator/repository reference (ROI form kontribusi).
3. [x] WOTD. Share backgrounds: **belum** di-L1.
4. [x] Translation-help published.
5. [x] Detail kata di L1 (`words/:id` + lemma; pull-to-refresh hard miss).

Selesai tambahan (di luar daftar awal):

- [x] Dev tool Response Cache explorer (`ResponseCacheInspector`).
- [x] Network Monitor merekam sajian L1 + badge HIT / STALE / DEGRADED
  + tooltip awam.

Keluar (tetap dihormati): interceptor global yang men-cache semua GET;
persist auth/inbox; menyimpan L1 di SQLite yang sama dengan dataset
release.

### Fase DS - Public dataset + pipeline (sebelum mobile SQLite)

Tujuan: artifact dan kontrak schema **siap dikonsumsi**. Tidak ada
pekerjaan Flutter kamus lokal di fase ini.

1. [ ] Rancangan schema publik `schema_version = 1` (DDL + allowlist
   field + blocklist + aturan FTS) - lihat `database/schema/v1.md` +
   kunci `database/schema/QUESTIONS.md`.
2. [ ] Script export `published` → SQLite + FTS + validate + sha256 +
   manifest (tools §17).
3. [ ] Tes otomatis: kolom terlarang tidak ada; integrity_check; smoke
   FTS lemma/variant/translation.
4. [x] Repo publik [`sambasku/database`](https://github.com/sambasku/database)
   + README + scaffold schema (docs DS).
5. [ ] **Release v1** (GitHub Release assets) + pointer `active.json`.
6. [ ] Catat URL stabil di README dataset (kontrak untuk Fase B).

Keluar DS (bukan bagian fase ini): UI Flutter unduh dataset, first-run
mobile, wiring fail/offline → itu **Fase B**.

### Fase B - Mobile SQLite consume

Tujuan: HP mengunduh artifact DS sebagai **cadangan**; baca L2 **hanya**
saat offline / API unreachable (§16.2). Online tetap API + L1.

1. [ ] `core/local_db` + updater (download, verify, atomic swap).
2. [ ] Download-on-first-run + halaman kelola dari Profil.
3. [ ] `DictionaryLocalDatasource` + wiring **fail/offline only** (§16.2).
4. [ ] Deteksi offline + API-unreachable (setelah failover habis);
   jangan query L2 saat online+API OK.
5. [ ] Tes airplane + API down: search/detail dari L2; online: 0 baca L2.

Prasyarat: **Fase DS hijau** (gate di atas).

### Fase C - Update dataset (ops otomatis / latar)

- [ ] Cek manifest berkala di background (opsional); diagnostics versi
  di About / dev tool. **Manual check dari Profil sudah ada sejak B.**

### Fase D - Operasional release (Console)

- [ ] Preview diff, tombol Release di Console, audit, rollback pointer
  `active`, idempotency "no content change". Build/export tetap sama
  seperti Fase DS; yang ditambah = otorisasi + UX admin.

### Fase E - Perhalus (opsional)

- [ ] Copy UX sumber data (`Dari server` / `Cadangan offline vN`).
- [ ] L1 tetap untuk detail/search/feed online - **jangan cabut** sebagai
  syarat end-state.

---

## 9. Kebutuhan wajib (requirements)

### Produk / UX

| ID | Requirement | Status |
| --- | --- | --- |
| P1 | Setelah dataset terpasang, search & detail jalan di **airplane / API down** | Belum (L2) |
| P2 | Startup online tidak menunggu unduh L2; L2 siap di latar / Profil | Belum (L2) |
| P3 | Copy UX membedakan "stale cache L1" vs "cadangan dataset vN" | Belum (L2); L1 punya badge HIT/STALE/DEGRADED di Network Monitor |
| P4 | Submit kontribusi tidak menjanjikan muncul di L2 sampai release + update device | Belum (L2) |
| P5 | Pull-to-refresh online = hard miss L1; di mode L2 = "cek update dataset" (bukan refetch per lemma) | **L1 ya** (feed / TH / detail); jalur L2 belum |
| P6 | Saat online + API OK, baca kamus **tidak** menyentuh SQLite | Belum (L2 wiring) |

### Teknis

| ID | Requirement | Status |
| --- | --- | --- |
| T1 | Token tidak masuk key/value L1 atau tabel L2 | **L1 ya**; L2 belum |
| T2 | Atomic DB replace; gagal verify = keep old | Belum (L2) |
| T3 | `schema_version` + `min_app_version`; tolak artifact tidak kompatibel | Belum (L2); L1 punya `cacheSchemaVersion` wipe |
| T4 | Hard cap disk L1; eviction L1 tidak menghapus file DB L2 | **L1 ya** (`evictToBudget`); L2 belum |
| T5 | Key cache tanpa host tier / Authorization / device id | **Ya** (`buildCacheKey`) |
| T6 | Export allowlist; test otomatis "kolom terlarang tidak ada" | Belum (L2) |
| T7 | Observability dev: hit/miss/swr/degraded (L1) dan local_hit / update_ok|fail (L2) | **L1 ya** (Network Monitor); L2 belum |
| T8 | L1 persist via **`hive_ce`**; hard cap + `evictToBudget` tetap; token tidak masuk box L1 | **Ya** |

---

## 10. Kriteria penerimaan (Definition of Done)

### Fase A (cache)

- [x] `hive_ce` terpasang; box L1 terbuka setelah cold start.
- [x] Reference form kontribusi: cold start menyajikan L1 bila ada.
- [x] Pull-to-refresh hard miss untuk key layar itu (feed `latest`,
  discussion, **detail kata**).
- [x] Logout wipe user-scoped; publik tetap bila ada.
- [x] Budget eviction diimplementasi (`evictToBudget` saat `put`); uji
  manual/dev lewat Response Cache explorer.
- [x] 429 / 5xx tidak menimpa entry bagus (fetch gagal → tidak `put`;
  sajikan stale bila ada = DEGRADED).
- [x] Token auth tetap di `flutter_secure_storage` (bukan L1); logout
  wipe scope user.
- [x] Detail kata di L1 (`words/:id` + lemma).

Sisa Fase A (bukan blocker mulai DS / B):

- [ ] L4 invalidate setelah sukses kontribusi / vote / komentar / edit
  profil (map key tertulis).
- [ ] Share backgrounds di L1 (opsional).

### Fase DS (public dataset + pipeline)

- [ ] Schema v1 terdokumentasi + tes allowlist hijau.
- [ ] Export menghasilkan artifact valid (integrity + FTS smoke).
- [ ] Repo publik + Release v1 + URL manifest stabil.
- [ ] QUESTIONS kritis di `database/schema/QUESTIONS.md` terjawab.

### Fase B (mobile SQLite consume)

- [ ] Airplane / API unreachable: search lemma (termasuk belum pernah
  dibuka online) hit dari L2 bila korpus terpasang.
- [ ] Detail by id dan by lemma dari L2 **hanya** di jalur fail/offline.
- [ ] List A-Z dari L2 di jalur fail/offline.
- [ ] Online + API OK: repository **tidak** query L2 untuk baca kamus.
- [ ] First-run / Profil bisa install/update dari Release DS (§18).
- [ ] Badge/copy sumber: `Cadangan offline (dataset vN)` vs L1 HIT.

### Fase C (update)

- [ ] Manifest lebih baru + kompatibel → download background.
- [ ] Checksum / integrity / schema gagal → DB lama utuh.
- [ ] Metadata check gagal (offline) → app tetap normal.

### Fase D (release ops)

- [ ] Hanya admin terotorisasi yang memicu release.
- [ ] Release gagal tidak mengubah `active_release` lama.
- [ ] Rollback metadata mengarahkan klien ke artifact sebelumnya.
- [ ] Audit: siapa, kapan, jumlah lemma, versi.

### Hardening free-tier (metrik sukses produk)

- [ ] Proporsi request mobile ke endpoint kamus turun signifikan setelah
      L1 detail + (opsional) L2 fail/offline diukur di staging.
- [ ] Skenario "semua API tier down" + L2 terpasang: kamus tetap usable.
- [ ] Skenario online normal: 0 query SQLite pada path search/detail.

---

## 11. Risiko dan mitigasi

| Risiko | Mitigasi |
| --- | --- |
| Investasi ganda L1 kamus + L2 | Disengaja: L1 = online hemat-kuota; L2 = cadangan fail/offline |
| Dual source of truth lemma | Online selalu API; L2 hanya saat fail/offline + badge sumber |
| APK membengkak | Gate ukuran gzip; opsi download first-run; media tetap URL remote di V1 |
| Schema drift artifact vs app | `schema_version` + min app; smoke test di pipeline |
| Data sensitif bocor ke artifact | Allowlist + tes kolom terlarang |
| Admin jarang release | Preview "N perubahan"; SLA internal (mis. mingguan); online tetap segar via API |
| Search lokal ≠ search API | Matriks parity sebelum B; copy "cadangan offline" bila beda |
| User mengira failover = offline kamus | Dokumentasi in-app / About: versi dataset terpisah dari status host |

---

## 12. Keputusan yang harus dikunci sebelum coding besar

| # | Pertanyaan | Status |
| --- | --- | --- |
| 1 | Fase A dulu vs langsung B | **Dikunci:** A inti selesai; lanjut B |
| 2 | Bundle vs download initial | **Dikunci:** download-on-first-run (§5.6) |
| 3 | Field FTS | **Dikunci:** lemma + variants + translation |
| 4 | WOTD | **Dikunci:** tetap API + L1 |
| 5 | Latest feed | **Dikunci §16.1:** API + L1 |
| 6 | Hosting artifact + URL stabil | **Dikunci §18:** satu repo publik + Release assets |
| 7 | Default baca kamus production | **Dikunci §16.2:** API + L1 online; L2 hanya fail/offline |
| 8 | Local miss vs remote | **Dikunci §16.2:** **bukan** hybrid; online selalu remote(+L1) |
| 9 | Allowlist tabel | **Dikunci §16.3** |

---

## 13. Anti-pola

1. SharedPreferences untuk payload detail kata / korpus.
2. Menjadikan L1 sebagai database kamus (cardinality search, tanpa FTS).
3. Menyalin production DB mentah ke asset / repo publik.
4. Blokir splash sampai download dataset selesai tanpa timeout/escape.
5. Mencampur tabel kamus dan entry HTTP cache tanpa modul terpisah.
6. Membaca SQLite L2 saat online + API OK (hybrid / local-primary).
7. Menganggap invalidate L4 di satu HP = seluruh user sudah sync
   (tetap butuh release untuk korpus cadangan).
8. Offline queue submit dalam sprint yang sama dengan first local DB
   tanpa desain konflik.
9. Tag GitHub berisi dump production / akun / `TURSO_TOKEN` / api_token
   sebagai "release" atau "backup publik".
10. Mobile (atau web publik) konek langsung ke Turso dengan token.
11. Silent hybrid / `localThenRemote` otomatis (dual truth + tekanan
    free-tier saat online).

---

## 14. Checklist eksekusi cepat

### Fokus sekarang = Fase DS

- [x] Kunci keputusan §12 (lihat tabel dikunci).
- [x] Kunci §16 (feed, **fail/offline L2**, allowlist) + §17 tools + §18 repo/rilis.
- [x] Fase DS dipisah formal sebelum B (§8 / §19).
- [x] Kunci item di `database/schema/QUESTIONS.md`.
- [x] Finalisasi `database/schema/v1.md` (DDL).
- [x] Scaffold export script di `database/scripts/` (`pnpm dataset:export`)
- [x] Tes validate forbidden cols (unit di `database/`)
- [ ] Push `database/` (README, schema, scripts, active.json) + pastikan Release v1 hidup.
- [ ] Re-export dari staging/prod **dengan** kata published (word_count > 0).
- [ ] Update dokumen ini di PR yang sama jika kontrak berubah lagi.
- [ ] Smoke: unduh gzip Release → gunzip → `sqlite3` FTS hit.

### Setelah DS hijau = Fase B (jangan mulai lebih awal)

- [ ] `core/local_db` + fail/offline wiring + first-run / Profil.
- [ ] Test: airplane + cold start + first-run download + update gagal keep-old.
- [ ] Catat versi dataset di About / halaman kelola.

---

## 15. Ringkasan satu paragraf

Free-tier memaksa kita hemat request dan tahan saat host dingin atau
mati. **Failover host** menjaga request dinamis tetap punya cadangan.
**Cache L1** (termasuk detail kata) memotong hit berulang saat online.
**SQLite L2** adalah cadangan: search/detail/list dari dataset lokal
**hanya** bila device offline atau API unreachable (free-tier habis /
host down). Bukan hybrid local-primary. Ketiganya dipakai bersama dengan
batas kelas data yang jelas, di dalam Clean Architecture feature-first
yang sudah dipakai `mobile/lib`.

---

## 16. Celah ambiguitas (keputusan kanonik)

Bagian ini menutup celah yang sering membingungkan: **feed dari web**,
**local miss vs remote hit**, **apa yang masuk release**, dan masalah
turunan lain.

### 16.1 Input dari web muncul di feed: ada cache-nya?

Ya, **feed punya cache L1**, bukan SQLite L2 (Fase B awal).

Alur nyata:

```text
User/web submit kata
      │
      ▼
Production DB (pending_review / published sesuai role)
      │  setelah published
      ▼
GET /words/latest  ←── feed beranda mobile/web
      │
      ├── Mobile: API + ResponseCacheStore (L1)
      │     fresh ~2 menit, staleMax ~1 jam
      │     pull-to-refresh = hard miss
      │
      └── SQLite L2: BELUM otomatis berisi lemma itu
            sampai Admin Release dataset baru
            dan device mengunduh/install
```

Implikasi:

| Permukaan | Sumber | Cache? | Kapan kata baru dari web terlihat? |
| --- | --- | --- | --- |
| Feed `latest` | API | **Ya (L1)** | Hampir segera (TTL pendek / refresh) |
| Search / detail online | API | **Ya (L1 detail)** | Segera (TTL / pull-to-refresh) |
| Search / detail fail/offline | SQLite L2 | n/a (dataset) | Hanya isi release yang sudah diunduh |
| Translation-help feed | API | **Ya (L1)** | TTL pendek (bukan bagian dataset kamus) |

Jadi: "ada di feed" **tidak** berarti "sudah di SQLite lokal". Online
user selalu dapat detail via API + L1. L2 hanya cadangan bila jaringan /
API gagal.

Keputusan kanonik feed:

- **Tetap API + L1** (feed tidak diganti L2).
- Tap item feed online → detail lewat API + L1 (bukan query L2 dulu).

### 16.2 Kapan SQLite dipakai? Fail / offline saja (bukan hybrid)

**Keputusan kanonik (dikunci 2026-09-28):** tidak ada Hybrid A /
silent hybrid / local-primary. SQLite L2 adalah **cadangan**.

```text
Online + API OK     → API (+ L1). Jangan baca L2.
Offline             → L2 (bila dataset terpasang); else empty + ajakan online
API unreachable*    → L2 (cadangan); L1 stale boleh dipakai dulu bila ada
* setelah failover host habis / timeout / kapasitas edge, bukan 404 lemma
```

#### Alur baca kamus (search / detail / list)

```text
Request baca kamus
      │
      ▼
Ada koneksi + API reachable?
  │
  ├─ YA → Remote (+ L1 getOrFetch). Selesai.
  │
  └─ TIDAK → Dataset L2 siap?
                │
                ├─ YA → query SQLite + badge "Cadangan offline (vN)"
                └─ TIDAK → empty / error jaringan (ajakan coba lagi /
                           unduh kamus saat online)
```

#### Yang tidak boleh

- Hybrid local-primary: query L2 dulu lalu remote tiap miss saat online.
- Silent `localThenRemote` otomatis.
- Rewrite file L2 dari partial remote rows.
- Menganggap L2 miss saat **offline** = "kata tidak ada di dunia"
  tanpa copy bahwa korpus mungkin belum di-update.
- Memakai L2 untuk menghemat 429 saat user **masih online** (itu tugas
  L1 + rate-limit UX, bukan dual-read SQLite).

Search-miss recording (analitik admin): hanya jalur **remote** search.

#### Kenapa fail/offline-only (bukan Hybrid A)

- Satu sumber kebenaran online: API (L1 hanya cache TTL).
- Tidak ada dual-truth tersembunyi saat browsing normal.
- Free-tier: L1 mengurangi hit; L2 melindungi saat API/edge benar-benar
  tidak bisa dihubungi (bukan menggantikan API tiap hari).
- Airplane mode / free-tier habis tetap punya korpus published yang
  sudah diunduh.

### 16.3 Mekanisme release: tabel apa yang masuk?

Release = **export sanitasi korpus kamus published**, bukan backup, bukan
dump Turso, bukan tag repo berisi akun.

#### Bukan ini (tolak keras)

| Ide | Masalah |
| --- | --- |
| Backup akun + tag di GitHub repo database | PII / kredensial berisiko publik; bukan dataset kamus |
| Mobile/web pakai `TURSO_TOKEN` / api_token langsung ke Turso | Token di klien = siapa saja bisa baca/tulis production |
| `SELECT *` / file copy production.db | Users, token, audit, submissions ikut bocor |
| Menyamakan "Release" dengan "Backup" | Target beda: publik vs disaster recovery privat |

Backup production (termasuk akun) = jalur **privat terenkripsi** (storage
internal), dipicu admin terpisah. Mobile **tidak pernah** memegang token
DB.

#### Allowlist tabel → masuk artifact publik

Hanya baris yang terkait entri `words.status = 'published'` dan
`deleted_at IS NULL` (plus referensi yang dibutuhkan).

| Tabel production | Masuk release? | Catatan field |
| --- | --- | --- |
| `languages` | Ya | Semua kolom publik |
| `dialects` | Ya | Publik |
| `word_classes` | Ya | Publik |
| `categories` | Ya | Publik |
| `words` | Ya (filter published) | **Strip**: `verified_by`, `created_by`, `updated_by`, `deleted_by`, `taken_down_*`, `takedown_*` (atau biarkan null-only). Simpan: id, language_id, lemma, word_type, usage_labels, notes (bila publik), is_verified, verified_at (untuk feed lokal nanti), timestamps publik yang dibutuhkan |
| `meanings` | Ya (via word published) | Publik |
| `meaning_translations` | Ya | Publik |
| `examples` | Ya | Publik |
| `word_variants` | Ya | Publik (penting untuk FTS) |
| `word_categories` | Ya | Publik |
| `lexical_relations` | Ya (kedua sisi published) | Publik |
| `pronunciations` | Ya | URL audio + speaker_name publik; tanpa PII internal |
| `word_images` | Ya | URL publik + metadata non-sensitif |
| `word_audios` | Ya | URL publik |
| FTS virtual table | Ya (dibangun saat export) | Bukan copy dari production |

#### Blocklist → tidak pernah masuk artifact publik

| Tabel / data | Alasan |
| --- | --- |
| `users` (penuh) | Email, phone, password_hash, role internal |
| `auth_identities`, `refresh_tokens`, OTP, password reset, account deletion tokens | Kredensial sesi |
| `contributions`, `contribution_reviews`, `word_edit_suggestions` | Alur moderasi, bukan korpus tayang |
| `search_misses` | Operasional admin |
| `audit_logs` | Internal |
| `votes`, `comments`, `bookmarks` | Dinamis / privat / semi-privat |
| `device_tokens`, `notifications`, campaign* | Privat / ops |
| `verifier_applications`, `bug_reports`, `word_reports` | Moderasi |
| `discussions` (+ replies) | Sosial dinamis → tetap API + L1 |
| `word_import_sessions` | Ops admin |
| `comment_blocklist_words` | Kebijakan moderasi internal |

#### Atribusi kontributor tanpa tabel `users`

Jangan ekspor `users`. Jika UI butuh "disusun oleh":

- **Denormalisasi saat export**: kolom `contributor_display_name` /
  `contributor_avatar_url` (nullable) pada baris `words` / meanings, dari
  snapshot saat release, **atau**
- Kosongkan atribusi di L2; profil publik tetap lewat API saat online.

#### Ringkas pipeline release (bukan Turso dari HP)

```text
Admin trigger (Console / CI)
      │
      ▼
API admin (authz) baca Production via server credential
      │
      ▼
Export allowlist + filter published + sanitize
      │
      ▼
Build SQLite + FTS → gzip → sha256 → manifest
      │
      ▼
Publish artifact imutabel (mis. GitHub Release asset / CDN)
      │
      ▼
Mobile unduh lewat HTTPS publik (tanpa DB token)
```

### 16.4 Permasalahan turunan lain (temuan)

| # | Celah | Dampak | Keputusan / mitigasi |
| --- | --- | --- | --- |
| 1 | Feed L1 lebih baru daripada korpus L2 | Saat fail/offline, tap item feed bisa miss di L2 | Online: detail selalu API+L1 (§16.2). Offline: empty + copy "cadangan vN mungkin belum memuat kata baru" |
| 2 | Takedown setelah release | Device lama masih tampilkan kata (hanya di jalur L2) | Release berikutnya wajib exclude; SLA release setelah takedown sensitif; opsional tombstone list di metadata nanti |
| 3 | Media (gambar/audio) tetap URL remote | "Offline kamus" ≠ offline media | V1: teks/arti offline; media butuh CDN. Bundle media = backlog terpisah |
| 4 | Vote/komentar count di detail | Angka di snapshot cepat basi | Detail sosial (count, thread) tetap API; L2 hanya lema/arti/contoh |
| 5 | Web publish vs mobile dataset | Dua freshness model antar platform | Diterima; dokumentasikan; web bisa tetap API-first sampai SQLITE-WEB |
| 6 | Parity search API vs FTS | Hasil beda di mode cadangan | Matriks parity sebelum B; copy "cadangan offline" bila beda |
| 7 | `created_by` di production | Butuh FK users; bocor bila ikut export | Strip FK user; denormalisasi nama saja |
| 8 | Relasi leksikal ke kata belum published | Baris dangling di L2 | Export hanya bila **kedua** ujung published |
| 9 | Concurrent download update | Dua file `.new` bentrok | Satu mutex updater; ignore check ganda |
| 10 | Admin jarang Release | Cadangan L2 semakin basi saat API down | Preview "N published sejak vN"; target SLA; online tetap segar via API |
| 11 | Menafsirkan backup akun sebagai release | Insiden keamanan | Pisah tombol/docs: Backup privat ≠ Release publik (§16.3) |
| 12 | Negative cache L1 vs L2 miss | 404 di-cache padahal kata baru di-publish | Negative TTL pendek; setelah update L2, clear negative keys terkait |
| 13 | WOTD vs korpus lokal | Hari diganti di server, L2 tidak tahu | WOTD tetap API+L1; L2 tidak menggantikan WOTD online |
| 14 | Multi-device user | Device A update dataset, B belum | Normal; versi dataset per device di About |
| 15 | Free-tier CDN artifact | Download DB besar gagal/mahal | Kompresi; resume; jangan unduh ulang bila sha sama |

### 16.5 Diagram satu layar (web → feed → search)

```text
        WEB / API submit
              │
              ▼
        Production DB ──────────────► Backup privat (akun + semua)
              │                         (bukan ke HP, bukan repo publik)
              │ published
              ├──────────────────► GET /words/latest ──► Mobile feed (API+L1)
              │
              ▼
         Release (allowlist)
              │
              ▼
         Artifact vN (CDN)
              │
              ▼
         Mobile SQLite L2 ──► search / detail / list A-Z
              │
              └── miss + online ──► CTA "Cari di server" / "Update kamus"
```

### 16.6 Jawaban singkat tiga pertanyaan

1. **Feed dari input web: ada cache?**  
   Ya: **L1** pada `latest` (TTL pendek). Tidak otomatis masuk SQLite
   sampai release.

2. **Search lokal kosong tapi remote ada?**  
   Saat **online**: selalu API (+ L1) - L2 tidak ditanya. Saat
   **fail/offline**: hasil L2 mengikuti release yang terpasang; kata
   baru di server belum tentu ada sampai user update dataset (§16.2).
   Bukan Hybrid A / silent fallback.

3. **Release = tabel apa? Backup akun + Turso token?**  
   Bukan. Release = allowlist korpus published (§16.3). Backup akun =
   privat terpisah. Mobile tidak memakai api_token / Turso token;
   hanya unduh artifact HTTPS dari repo publik (§18).

---

## 17. Tools & library (stack L2)

Tidak menambah store baru untuk korpus selain SQLite file release.
L1 tetap `hive_ce` (kelas dinamis saja).

### 17.1 Export / build artifact (di monorepo `api/`, privat)

| Peran | Pilihan | Catatan |
| --- | --- | --- |
| Baca production | `@libsql/client` (SQL allowlist) | Kredensial hanya di `.env` / CI secrets; **tidak** masuk git |
| Tulis file SQLite publik + FTS5 | `@libsql/client` `file:` | Artifact terpisah dari DB production; FTS dibangun di sini |
| Kompresi | `zlib` / gzip bawaan Node | Output `database.sqlite.gz` |
| Checksum | `crypto.createHash('sha256')` | Isi `SHA256SUMS` + field manifest |
| Entrypoint | `database/scripts/export-published-dataset.ts` | npm script `pnpm dataset:export` di repo `database/` |

Bukan: commit production.db, dump Turso mentah, atau generate di HP.

### 17.2 Mobile baca + unduh (di `mobile/`)

| Peran | Pilihan | Catatan |
| --- | --- | --- |
| Buka / query SQLite + FTS5 | `sqflite` | Path file lokal setelah install; query read-only untuk kamus |
| Path file | `path_provider` (sudah ada) | Dir app documents / databases |
| Unduh HTTPS | `dio` (sudah ada) | Manifest + `.gz`; tanpa Authorization DB |
| SHA-256 verify | `crypto` (Dart) | Bandingkan ke manifest sebelum swap |
| Gunzip | `archive` atau `gzip` / `dart:io` | Tulis ke `database.new` lalu atomic rename |
| State / DI | Riverpod (sudah ada) | `core/local_db` + datasource dictionary |

Bukan: `hive_ce` untuk korpus, SharedPreferences untuk detail kata,
koneksi Turso dari klien.

### 17.3 Ops rilis (Fase DS = CLI/Actions; Fase D = Console)

| Peran | Pilihan | Catatan |
| --- | --- | --- |
| Simpan artifact imutabel | **GitHub Releases** di repo publik §18 | Asset per tag `vN` |
| Pointer "yang aktif" | File `metadata/active.json` di branch `main` **atau** URL `.../releases/latest/download/manifest.json` | Mobile butuh URL stabil |
| Otomasi build | GitHub Actions di **monorepo** (secrets privat) → upload ke repo publik | Jangan taruh `TURSO_TOKEN` di repo publik |
| Console tombol Release | Fase D | Memicu workflow yang sama |

---

## 18. Repo publik transparan + mekanisme rilis

### 18.1 Satu sumber publik (keputusan dikunci)

**Satu repository GitHub publik** khusus dataset kamus:
[`sambasku/database`](https://github.com/sambasku/database) (submodule
`database/` di monorepo). Bukan backup akun, bukan dump Turso.

Tujuan transparan:

- Siapa saja bisa lihat **schema publik**, README, riwayat rilis, checksum.
- Siapa saja bisa unduh artifact HTTPS (mobile juga).
- Tidak ada token DB, users, atau dump production di situ.

Isi repo (ringan, boleh di-commit) - lihat `database/README.md`:

```text
database/
├── README.md
├── LICENSE
├── logo.png
├── package.json              # pnpm dataset:export
├── scripts/                  # export + validate (standalone)
├── schema/
│   ├── v1.md
│   └── QUESTIONS.md
├── metadata/
│   └── active.json           # pointer rilis aktif
└── …
```

Nama lama usulan `sambasku-dataset` **diganti** ke repo yang sudah ada:
`sambasku/database`.

Isi **tidak** di-commit ke git (terlalu besar / immutable per versi):

```text
GitHub Release tag vN
  ├── database.sqlite.gz
  ├── manifest.json
  └── SHA256SUMS
```

### 18.2 Source of truth vs salinan publik

```text
Production DB (privat, Turso)     ← kebenaran tulis / moderasi
        │
        │  export allowlist (CI/CLI, credential privat)
        ▼
GitHub Release di sambasku/database  ← kebenaran baca publik (imutabel per vN)
        │
        │  HTTPS download
        ▼
SQLite di HP                        ← replica lokal
```

GitHub **bukan** sumber untuk mengisi production. Arah panah satu arah.

### 18.3 Apakah Fase DS mengisi (populate) repo itu?

**Ya.** Tanpa rilis pertama, Fase B (download-on-first-run) tidak punya
target.

Lingkup populate di **Fase DS** (bukan menunggu mobile):

1. Buat / lengkapi repo publik + README + `schema/v1.md` (kontrak allowlist).
   (scaffold README/schema sudah mulai di submodule `database/`)
2. Jalankan export CLI terhadap DB yang disepakati (staging dulu, lalu
   production bila siap).
3. Buat **GitHub Release** pertama (`v1` / `release_version: 1`) berisi
   tiga asset di atas.
4. Set pointer aktif (`active.json` dan/atau andalkan
   `releases/latest/download/...`).
5. Catat URL stabil di README - kontrak konsumsi untuk Fase B.

Yang **belum** wajib di DS/B: tombol Console, preview diff, audit UI,
rollback mewah (itu Fase D). Rollback darurat = ubah pointer aktif ke
Release lama (tag sebelumnya tetap hidup).

### 18.4 Mekanisme rilis (alur kanonik)

```text
Trigger (Fase DS: CLI / workflow_dispatch di sambasku/database)
      │
      ▼
Job di repo database (scripts/)
  - pakai DATABASE_URL + AUTH_TOKEN (secrets / .env lokal)
  - export allowlist → SQLite + FTS
  - integrity_check + smoke + sha256 + gzip
  - tulis manifest.json
      │
      ▼
Publish GitHub Release di sambasku/database
  - create GitHub Release tag vN (immutable)
  - upload database.sqlite.gz, manifest.json, SHA256SUMS
  - update metadata/active.json → release_version N + URL asset
      │
      ▼
Mobile
  - first-run / tombol Profil "Periksa pembaruan"
  - GET active/latest manifest
  - jika N lebih baru + schema/min_app kompatibel → unduh → verify → swap
  - gagal → keep DB lama
```

URL stabil (pilih satu di implementasi; dokumentasikan di README dataset):

```text
# Opsi A - latest assets GitHub
https://github.com/sambasku/database/releases/latest/download/manifest.json

# Opsi B - pointer di main (mudah rollback tanpa menghapus Release)
https://raw.githubusercontent.com/sambasku/database/main/metadata/active.json
```

**Rekomendasi kontrak:** Opsi B untuk `active` (rollback = commit pointer),
asset file tetap dari Release URL di dalam JSON (CDN GitHub). Mobile
hanya percaya sha256 di manifest, bukan nama file saja.

### 18.5 Perubahan schema nanti (aman?)

Ya, dengan gate yang sama:

| Event | Perilaku |
| --- | --- |
| Data baru published, schema sama | Release vN+1; HP unduh saat cek update |
| Schema publik naik (breaking) | Naikkan `schema_version` + `min_app_version`; app lama **tolak** install, tetap di DB lama |
| Verify/download gagal | Hapus `.new`; DB lama utuh |
| Takedown sensitif | Release berikutnya exclude baris; SLA admin |

Bukan migrasi ALTER di device: tiap rilis = **full replace** file SQLite
yang sudah diverifikasi.

### 18.6 Ringkas jawaban tiga pertanyaan arsitektur

1. **Tools?** Export: `@libsql/client` baca sumber + tulis SQLite/FTS + gzip/sha256
   di `database/scripts/`. Mobile: `sqflite` + Dio + crypto + gunzip.
   Rilis: GitHub Releases + Actions (secrets di repo `database`).
2. **Satu repo publik?** Ya
   ([`sambasku/database`](https://github.com/sambasku/database));
   transparan untuk schema + scripts + riwayat rilis + checksum; artifact di
   Release assets.
3. **Populate di Fase DS?** Ya - rilis pertama wajib sebelum mobile
   consume (Fase B).
4. **Mekanisme rilis?** Export di `database/scripts` → Release imutabel →
   pointer `active` → mobile unduh/verify/swap. Console = Fase D di atas
   pipeline yang sama.

---

## 19. Fase DS - persiapan schema & pipeline (sebelum B)

**Fase DS adalah fase formal sebelum B.** Buat rancangan schema dulu,
matangkan pipeline, baru Fase B (mobile SQLite).

Mobile tidak boleh menjadi tempat "menemukan" bahwa allowlist kurang
kolom atau FTS salah. DS menghasilkan kontrak yang bisa diuji dengan
sqlite CLI / script tanpa Flutter.

### 19.1 Deliverable rancangan schema v1 (awal DS)

Dokumen tunggal (usulan path):

- Repo publik: [`database/schema/v1.md`](../../database/schema/v1.md)
  (+ [`QUESTIONS.md`](../../database/schema/QUESTIONS.md))
- Mirror strategi: bagian ini + §16.3

Isi wajib:

| Bagian | Isi |
| --- | --- |
| `schema_version` | `1` (integer; naik hanya jika breaking) |
| DDL per tabel | Nama kolom, tipe SQLite, nullability, PK/FK logis |
| Allowlist field | Kolom yang diekspor (bukan `SELECT *`) |
| Blocklist | Kolom/tabel terlarang + tes otomatis |
| Filter baris | `published` + `deleted_at IS NULL` (+ child status) |
| FTS5 | Nama virtual table, kolom (lemma, variants, translation), tokenizer |
| Meta | Tabel/key `release_meta` di dalam file DB |
| Parity baca | Mapping ke kebutuhan mobile: search / detail / list A-Z |
| Contoh baris | 1-2 lemma fiktif atau dari staging (tanpa PII) |

### 19.2 Deliverable pipeline hijau (akhir DS / gate ke B)

```text
dataset:export  →  artifact lokal
       →  validate (integrity, forbidden columns, FTS smoke)
       →  GitHub Release v1 + active.json
       →  URL stabil terdokumentasi
```

Baru gate terbuka untuk Fase B: mobile fokus unduh, verifikasi, query
fail/offline, UX Profil - **bukan** merancang ulang schema di tengah UI.

### 19.3 Apa yang sengaja ditunda setelah schema matang

- Perubahan breaking schema → `schema_version` 2 + app baru (bukan
  patch diam-diam di v1).
- Feed dari L2, WOTD lokal, media offline, Console Release UI.
- Seluruh implementasi Flutter `core/local_db` / fail-offline wiring
  (itu Fase B).