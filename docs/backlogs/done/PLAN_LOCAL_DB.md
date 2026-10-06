# PLAN - Local DB Mobile (Cache → SQLite)

Status: **rencana eksekusi / draft**. Bukan kontrak implementasi.
Induk arsitektur: [`SQLITE-LOCAL-MOBILE.md`](SQLITE-LOCAL-MOBILE.md).
Kontrak cache tipis: [`CACHE-MOBILE.md`](CACHE-MOBILE.md).
Induk kebijakan cache: [`CACHE.md`](CACHE.md).
Peta produk: [`NEXT.md`](NEXT.md).

## 1. Tujuan dokumen

Menyatukan dua backlog yang tampak bertentangan menjadi **satu jalur
implementasi** untuk mobile:

| Sumber | Janji |
| --- | --- |
| `CACHE-MOBILE.md` | Kurangi hit API free-tier + degradasi baca saat jaringan jelek, **tanpa** offline-first penuh |
| `SQLITE-LOCAL-MOBILE.md` | Dictionary read **local-first**; API boleh mati, kamus tetap hidup |

Dokumen ini menjawab:

1. Apa yang perlu **disesuaikan** agar keduanya tidak saling bunuh.
2. **Kebutuhan** teknis & produk per fase.
3. **Risiko** utama dan mitigasinya.
4. **Strategi ideal** (urutan, gate, dan apa yang sengaja tidak dikerjakan).

Bukan tujuan dokumen ini: menduplikasi schema release, manifest JSON,
atau pseudocode `ResponseCacheStore` - itu tetap di dokumen induk.

---

## 2. Verdict singkat

```text
Cache respons (TTL/SWR)  ≠  Local SQLite dataset
         │                         │
         │                         └── sumber baca kamus (tujuan akhir)
         └── jembatan + lapisan untuk data dinamis/sosial
```

**Keputusan arah (disarankan):**

1. **Jangka pendek (ROI API):** implementasikan cache tipis **hanya**
   untuk kelas yang **tidak** akan digantikan SQLite segera
   (reference, WOTD, feed singkat, sosial publik) - atau, jika
   tekanan rate-limit sudah kritis, cache juga detail/search sebagai
   **jembatan** dengan masa hidup terbatas.
2. **Jangka menengah-panjang:** dictionary read
   (search / detail / list A-Z / browse) pindah ke **Local SQLite**
   sebagai sumber utama, mengikuti arsitektur release di
   `SQLITE-LOCAL-MOBILE.md`.
3. Setelah SQLite dictionary live, **hapus atau jangan ekspansi**
   `ResponseCacheStore` untuk endpoint kamus; cache tetap relevan
   untuk data yang bukan snapshot publik (auth, inbox, vote pribadi,
   discussion, notifikasi).

Ini selaras `NEXT.md`: mulai dari cache terarah; full pack ditunda -
tetapi **rencana** full pack sudah ada di `SQLITE-LOCAL-*`, jadi cache
tidak boleh dibangun seolah itu adalah solusi akhir dictionary.

`★ Insight ─────────────────────────────────────`
Cache-aside menyimpan **salinan respons HTTP** (key = path/query).
SQLite lokal menyimpan **model domain kamus** (tabel + FTS).
Dua lapisan itu menyelesaikan masalah berbeda: hemat kuota API vs
kemandirian baca offline. Menyatukan keduanya di satu store tanpa
pemisahan kelas data = utang arsitektur.
`─────────────────────────────────────────────────`

---

## 3. Gap & penyesuaian antar dokumen

### 3.1 Konflik eksplisit

| Topik | CACHE-MOBILE | SQLITE-LOCAL-MOBILE | Penyesuaian |
| --- | --- | --- | --- |
| Offline-first | Non-goal | Goal utama | Cache = fase jembatan; SQLite = target dictionary |
| Storage | File JSON / blob; Hive/Isar/sqflite **tidak wajib** | SQLite + FTS5 wajib | Jangan investasikan store kamus di SharedPreferences/Hive jika SQLite menyusul < 1-2 siklus |
| Freshness | TTL `fresh` / `staleMax` + L4 event | Release version + metadata check | Dictionary: freshness = `release_version`. Dinamis: tetap TTL |
| Invalidation mutasi | L4 setelah kontribusi/vote di device yang sama | Publish baru baru terlihat setelah **Release** | UX harus menjelaskan: usulan `pending_review` ≠ muncul di lokal sampai release (atau overlay API untuk “milik saya”) |
| Search offline | Hanya query yang pernah di-cache | FTS penuh di seluruh korpus | Hanya SQLite yang memenuhi “cari kata belum pernah dibuka” |
| API sebagai read path | Masih sumber kebenaran + cache | Bukan sumber utama dictionary | Repository dictionary: ganti remote → local; API jadi fallback opsional lalu dilepas |
| `NEXT.md` YAGNI | “Offline full pack - tunda” | Spesifikasi penuh | PLAN ini mengangkat full pack dari YAGNI ke **roadmap bertahap**, tetap di belakang cache tipis untuk win segera |

### 3.2 Yang tetap sama (jangan diubah)

- Token auth tetap di `flutter_secure_storage`, bukan di cache/DB publik.
- Failover multi-host (`lib/core/network/failover/`) = circuit breaker
  host, **bukan** cache payload dan **bukan** pengganti SQLite.
- Data sensitif (users, sessions, submissions privat, audit) **tidak**
  masuk public dataset / disk cache publik.
- Hanya status `published` yang masuk snapshot publik.
- Clean Architecture feature-first: UI/Notifier tidak menghitung TTL
  atau memilih file DB; repository (atau datasource lokal) yang
  mengorkestrasi.

### 3.3 Penyesuaian kontrak CACHE bila SQLite masuk backlog aktif

Usulkan revisi kecil di `CACHE-MOBILE.md` / `CACHE.md` saat PLAN ini
disepakati:

1. Section Non-goals: ubah nada “bukan offline-first” menjadi
   “fase 1 bukan offline-first; dictionary offline mengikuti
   `SQLITE-LOCAL-MOBILE` / `PLAN_LOCAL_DB`”.
2. Matriks TTL: tandai kelas **Detail kamus / Feed / Search** sebagai
   `transitional` - boleh di-cache sampai Local DB Phase 1 mobile
   selesai, lalu di-decommission.
3. Prioritas resource §6: naikkan reference + WOTD; **turunkan**
   urgensi search/detail jika Phase SQLite sudah dijadwalkan di
   kuartal yang sama (hindari double-write).
4. Storage §5: izinkan satu store SQLite kecil **khusus metadata
   cache index** nanti; jangan campur tabel kamus dengan entry
   `ResponseCacheStore`.

### 3.4 Penyesuaian arsitektur SQLITE untuk realitas produk sekarang

`SQLITE-LOCAL-MOBILE.md` diasumsikan ideal end-state. Untuk SambasKu
hari ini, kunci penyesuaian berikut:

| Asumsi ideal | Realitas | Penyesuaian |
| --- | --- | --- |
| Bundled initial DB | APK size & update store | Gate ukuran: jika gzip > ~8-12 MB, pertimbangkan download-on-first-run + progress, tetap simpan fallback “tanpa kamus” yang jelas |
| Console Release tombol tunggal | Console/admin masih fokus moderasi | Phase builder bisa CLI / GitHub Actions dulu; Console UI Release = Phase belakangan |
| Hapus dependency read API | Web + deep link + klien lama masih butuh API | API read **tetap** untuk compatibility; mobile saja yang local-first dulu |
| Offline queue kontribusi | Belum ada; `NEXT` melarang queue diam-diam untuk submit/vote | Queue = Phase terpisah setelah dictionary lokal stabil; jangan bundling dengan Phase 1 |
| Differential patch | Disebut opsional | Tetap YAGNI sampai ukuran DB memaksa |
| Epoch / ETag (CACHE fase 2) | Belum ada | Release `version` di metadata **menggantikan** epoch untuk kelas dictionary; epoch opsional hanya untuk feed/sosial yang tidak masuk snapshot |

---

## 4. Klasifikasi data (sumber kebenaran per kelas)

Ini adalah inti strategi agar Cache dan SQLite tidak tumpang tindih
salah.

| Kelas data | Contoh | Sumber baca target | Cache TTL? | Masuk public SQLite? |
| --- | --- | --- | --- | --- |
| Rujukan statis | languages, word-classes, dialects | SQLite (ikut release) **atau** cache TTL panjang sampai SQLite | Ya (jembatan) | Ya |
| Detail / search / list kamus | `/words/:id`, lemma, search, list A-Z | **Local SQLite + FTS** | Jembatan saja | Ya (`published`) |
| Word of day | `/words/today` | API (+ cache hari lokal) - atau materialisasi harian di metadata release | Ya | Opsional (bisa dihitung lokal dari seed tanggal bila ada di DB) |
| Feed terbaru | `/words/latest` | API + cache pendek **atau** query lokal `ORDER BY published_at` setelah kolom ada di snapshot | Ya (jembatan) | Ya jika field waktu publish diekspor |
| Sosial publik | discussion | API + cache TTL | Ya | Tidak (konten dinamis / moderasi berbeda) |
| User / private | `/auth/me`, inbox, vote, bookmark | API only | **Jangan persist** | Tidak |
| Mutasi | POST/PATCH/DELETE | API (+ failover) | n/a; L4 / jangan andalkan SQLite | Tidak |

```text
                    ┌─────────────────────────┐
                    │     Flutter Mobile      │
                    └───────────┬─────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              ▼                 ▼                 ▼
        Dictionary         Semi-dinamik        Private /
        (SQLite)           (API + Cache)       Mutasi (API)
              │                 │                 │
     search/detail/list    WOTD, feed,       auth, inbox,
     reference (akhir)     discussion  vote, submit
```

---

## 5. Strategi implementasi ideal

### 5.1 Prinsip urutan

```text
Ukur nyeri API ──► Cache tipis (kelas aman)
                         │
                         ▼
              Dataset builder + 1 release manual
                         │
                         ▼
              Mobile Local SQLite (read path)
                         │
                         ▼
              Metadata + background update
                         │
                         ▼
              Decommission cache kamus
                         │
                         ▼
              Console Release + audit (opsional lebih awal jika admin siap)
```

**Jangan** parallel-full: ResponseCacheStore lengkap untuk semua
endpoint kamus **dan** pipeline release SQLite di sprint yang sama.
Pilih salah satu jalur dictionary; parallel hanya untuk kelas yang
tidak overlap (cache sosial + builder dataset).

### 5.2 Fase A - Cache tipis (jembatan / dinamis)

Tujuan: win `CACHE.md` V1 tanpa mengunci arsitektur salah.

**Scope masuk:**

1. `ResponseCacheStore` (kontrak §5 CACHE-MOBILE).
2. Decorator di repository **reference** dulu (ROI form kontribusi).
3. WOTD + share backgrounds.
4. Opsional: detail kata by id/lemma **hanya jika** rate-limit sudah
   menyakitkan dan Phase B belum start dalam ~1 bulan.
5. Translation-help published (tetap di cache selamanya menurut
   klasifikasi §4).

**Scope keluar:**

- Search full-cardinality tanpa batas last-N.
- Persist auth / inbox / vote.
- Interceptor Dio global yang men-cache semua GET.

**Gate keluar A → B:**

- [ ] Matriks TTL dikunci PO (angka boleh beda dari draft).
- [ ] Checklist §8 CACHE-MOBILE terpenuhi untuk kelas yang di-ship.
- [ ] Keputusan tertulis: apakah detail/search ikut A atau menunggu B.

### 5.3 Fase B - Public dataset + Local SQLite read (inti PLAN)

Tujuan: dictionary search/detail/list **tidak membutuhkan API**.

Urutan kerja (disederhanakan dari Phase 1-2-6 SQLITE-LOCAL-MOBILE,
digabung agar mobile punya data sebelum UI Release mewah):

| Step | Kerja | Output |
| --- | --- | --- |
| B0 | Kunci schema publik (tabel + field allowlist) | Dokumen schema + migration version = 1 |
| B1 | Script export `published` → SQLite + FTS5 + validate + sha256 | Artifact `database.sqlite.gz` + `manifest.json` |
| B2 | Bundle atau first-run install di mobile | DB terbuka saat cold start |
| B3 | `DictionaryLocalDatasource` + FTS search + get by id/lemma + list A-Z | Repository bisa baca lokal |
| B4 | Repository strategy: **local primary**; remote hanya fallback eksplisit (feature flag) lalu off | Acceptance: offline search OK |
| B5 | Background metadata check + atomic replace (Phase 4-5 SQLITE) | Update tanpa app store release |

**Penyesuaian terhadap Phase list di SQLITE-LOCAL-MOBILE:**

- Phase 3 Console Release UI **boleh menyusul** B1 (CLI/Actions dulu).
- Phase 7 offline queue **jangan** masuk B.
- Phase 6 “remove read API dependency” di mobile = B4; di API/web =
  backlog terpisah (`SQLITE-LOCAL-WEB.md`).

**Gate keluar B:**

- [ ] Acceptance criteria §52 SQLITE-LOCAL-MOBILE bagian Local-first +
      Security (subset mobile) hijau.
- [ ] App size / first-run UX disepakati (bundle vs download).
- [ ] Deep link `/words/:lemma` dan share card tetap bekerja dari DB
      lokal (atau hybrid jelas).

### 5.4 Fase C - Release operasional

- Console preview diff + tombol Release + audit.
- Rollback metadata `active_release`.
- Idempotency “no changes”.
- Mobile: tampilkan versi dataset di About/Diagnostics (bantu support).

### 5.5 Fase D - Pembersihan & koeksistensi tetap

- Hapus path cache untuk detail/search/list kamus.
- Pertahankan cache untuk sosial + (jika WOTD masih API).
- Dokumentasikan di `docs/mobile/` (promosi dari backlog) setelah
  stabil di produksi.
- Web local SQLite (`SQLITE-LOCAL-WEB.md`) = jalur paralel, **bukan**
  blocker mobile; reuse builder artifact yang sama.

### 5.6 Strategi repository mobile (pola kode)

Target lapisan data dictionary:

```text
presentation (Notifier / Riverpod)
  → domain (usecase + DictionaryRepository)
    → data:
         DictionaryRepositoryImpl
           → DictionaryLocalDatasource   // SQLite (primary)
           → DictionaryRemoteDatasource  // Retrofit (fallback / sync)
           → ResponseCacheStore          // hanya kelas non-SQLite
```

Aturan:

- Satu interface domain; ganti impl di provider, bukan di UI.
- Jangan biarkan Notifier memanggil Dio langsung untuk kamus.
- Feature flag `dictionaryReadSource = local | remote | localThenRemote`
  selama migrasi; default akhir = `local`.

`★ Insight ─────────────────────────────────────`
Pola “local primary, remote fallback” berbahaya jika fallback
diam-diam mengisi UI dengan data beda schema. Lebih aman: flag
eksplisit + telemetry hit local/remote, dan matikan remote read
begitu B4 hijau di build production.
`─────────────────────────────────────────────────`

---

## 6. Kebutuhan (requirements) yang harus dipenuhi

### 6.1 Produk / UX

| ID | Kebutuhan |
| --- | --- |
| P1 | Cold start offline: search & detail kata dari DB lokal setelah install/update dataset berhasil |
| P2 | Startup tidak diblokir metadata/CDN (buka DB lama dulu) |
| P3 | Indikator jelas bila menampilkan data stale (cache) vs dataset version N (SQLite) - jangan samakan copy UX |
| P4 | Kontribusi sukses tidak menjanjikan “langsung muncul di kamus lokal”; muncul setelah publish **dan** release (kecuali overlay “usulan saya” dari API) |
| P5 | Pull-to-refresh pada layar dinamis = hard miss cache; pada layar kamus lokal = optional “cek update dataset” (bukan refetch per-lemma) |

### 6.2 Teknis mobile

| ID | Kebutuhan |
| --- | --- |
| M1 | Schema version + release version tersimpan lokal |
| M2 | Atomic install: `database.new` → verify → swap; gagal = keep old |
| M3 | FTS5 (atau setara) untuk lemma + variasi yang diekspor |
| M4 | Hard cap disk: dataset + cache dinamis; eviction cache tidak menghapus DB kamus |
| M5 | Tidak ada token/PII di key/value cache atau tabel publik |
| M6 | Kompatibel min_app_version di manifest; tolak DB baru jika app terlalu lama |

### 6.3 Teknis pipeline / backend

| ID | Kebutuhan |
| --- | --- |
| S1 | Export allowlist field (bukan `SELECT *` production) |
| S2 | Hanya `published` (+ `deleted_at` bersih sesuai aturan produk) |
| S3 | Validate: FK, integrity_check, count sanity, FTS smoke |
| S4 | Artifact immutable + sha256; publish aktif terpisah dari build |
| S5 | Authz admin untuk trigger release; audit log di production DB |

### 6.4 Observability

| ID | Kebutuhan |
| --- | --- |
| O1 | Dev: hit/miss/swr/degraded untuk cache (CACHE §7) |
| O2 | Dev: local_hit / remote_fallback / update_success|fail untuk SQLite |
| O3 | Jangan kirim metric ke analytics produksi tanpa keputusan terpisah |

---

## 7. Risiko & mitigasi

| Risiko | Dampak | Mitigasi |
| --- | --- | --- |
| **Double investment** cache kamus + SQLite bersamaan | Waktu terbuang, dua sumber kebenaran | Fase A batasi kelas; kunci jadwal B sebelum ekspansi cache detail/search |
| **Stale semantics bingung** (TTL vs release) | User lihat arti lama, kira sudah sync | Copy UX beda; About menampilkan `release_version`; L4 tidak dipakai untuk “refresh seluruh kamus” |
| **APK membengkak** | Install drop, review store | Gate ukuran; kompresi; opsi download first-run; jangan bundle media audio/gambar penuh di SQLite awal |
| **Schema drift** app vs artifact | Crash query / data hilang | `schema_version` + min_app_version; tolak install; smoke test di pipeline |
| **Release berisi data sensitif** | Insiden privasi | Allowlist + review checklist security §52; test otomatis “kolom terlarang tidak ada” |
| **Update corrupt / partial download** | Kamus rusak | Atomic replace + checksum + integrity_check; never delete old sebelum verify |
| **Admin jarang Release** | Lokal ketinggalan jauh dari production published | Preview “N perubahan sejak release”; reminder; SLA internal (mis. release mingguan) |
| **Search lokal ≠ search API** | Ranking/variasi/miss-recording beda | Dokumentasikan parity matrix; search-miss tetap API-only saat online; FTS rules disepakati di B0 |
| **Web masih remote-only** | Perilaku beda platform | Diterima sementara; artifact yang sama untuk `SQLITE-LOCAL-WEB` nanti |
| **Offline queue prematur** | Submit ganda / konflik | Tetap out of scope sampai dictionary lokal stabil; ikuti larangan NEXT |
| **Failover host dianggap “offline OK”** | Salah diagnosis | Pisahkan metrik: host failover ≠ payload availability ≠ local DB |

---

## 8. Keputusan yang harus dikunci sebelum coding besar

Checklist PO + engineer (bukan semua harus dijawab hari ini, tapi
sebelum Fase B):

1. **Urutan:** Apakah Fase A (cache) ship dulu di produksi, atau langsung
   B karena tekanan offline-product lebih besar dari rate-limit?
2. **Bundle vs download** initial dataset dan ambang ukuran.
3. **Parity search:** field yang di-FTS (lemma, variants, translation
   sense, examples?).
4. **WOTD:** tetap API, atau hitung lokal dari DB + seed tanggal?
5. **Latest feed:** query lokal vs API+cache.
6. **Media (gambar/audio):** URL remote di snapshot vs bundle - default
   **URL saja** (DB kecil); offline media = backlog terpisah.
7. **Hosting artifact:** GitHub Release + CDN mana; URL metadata stabil.
8. **Siapa trigger release:** hanya root/admin; frekuensi target.
9. **Feature flag remote read:** kapan default `local` di production.
10. **Revisi TTL CACHE** untuk kelas `transitional`.

---

## 9. Kriteria sukses per fase

### Fase A (Cache)

- Form kontribusi jarang refetch reference saat online stabil.
- Cold start masih menampilkan detail yang pernah dibuka (jika detail
  di-cache) atau reference.
- Logout wipe user-scoped; budget eviction tidak merusak key panas.
- Tidak ada regresi auth/token.

### Fase B (Local SQLite dictionary)

- Mode airplane: search lemma yang **belum pernah** dibuka tetap
  menghasilkan hit dari DB (ini pembeda vs cache).
- Detail by id/lemma dari DB.
- List A-Z dari DB (menggantikan ketergantungan `GET /words` untuk
  browse).
- Update gagal tidak merusak DB lama.
- Zero dependency external untuk baca dataset yang sudah terpasang
  (prinsip §6 SQLITE-LOCAL-MOBILE).

### Fase C (Release ops)

- Admin bisa publish snapshot baru tanpa app release.
- Rollback metadata mengembalikan klien ke artifact lama.
- Audit + preview diff tersedia.

---

## 10. Anti-pola (jangan dilakukan)

1. Menjadikan `ResponseCacheStore` sebagai “database kamus” (cardinality
   search tinggi, tidak ada FTS, TTL palsu sebagai sync).
2. Menyalin production DB ke repo publik / asset mobile.
3. Menghapus API read dictionary sebelum mobile local hijau di
   production.
4. Memblokir splash screen untuk download dataset.
5. Mencampur tabel kamus publik dengan cache entry HTTP di satu schema
   tanpa prefix/module jelas.
6. Menganggap L4 invalidate di satu device = seluruh fleet sync
   (tetap butuh Release / epoch).
7. Mengerjakan offline contribution queue dalam sprint yang sama dengan
   first local DB tanpa desain konflik.

---

## 11. Mapping ke dokumen induk

| Topik | Sumber kanonik | Peran PLAN ini |
| --- | --- | --- |
| Alur cache-aside + matriks TTL | `CACHE-MOBILE.md` | Fase A + kelas dinamis jangka panjang |
| Release, manifest, atomic update, zero-dependency | `SQLITE-LOCAL-MOBILE.md` | Fase B-C |
| Kebijakan lintas klien + anti-pola cache | `CACHE.md` | Revisi status setelah keputusan §8 |
| Prioritas produk “cache dulu, full pack tunda” | `NEXT.md` | Diangkat jadi roadmap bertahap di sini |
| Web OPFS/WASM | `SQLITE-LOCAL-WEB.md` | Di luar scope mobile; reuse artifact |

---

## 12. Ringkasan strategi satu paragraf

Kerjakan **cache tipis** hanya untuk memotong nyeri API dan menopang
kelas data yang memang dinamis; kerjakan **public SQLite + release**
sebagai sumber baca kamus yang sesungguhnya; **jangan** biarkan keduanya
bersaing sebagai dual source of truth untuk lemma yang sama; setelah
SQLite dictionary live, cabut cache kamus dan biarkan API + failover
hanya untuk dunia dinamis/privat - sehingga janji arsitektur “API boleh
mati, kamus tetap hidup” tercapai tanpa mengorbankan win jangka pendek
di free-tier.

---

## 13. Next actions (saat eksekusi dimulai)

1. Review PO: kunci keputusan §8.1 (A dulu vs B dulu) dan §8.2 (ukuran).
2. Patch kecil `CACHE-MOBILE.md` §1/§3 menandai kelas transitional
   (opsional, bersamaan PR pertama).
3. Spike B0: schema publik + estimasi ukuran dari production
   `published` count.
4. Spike mobile: buka SQLite bundled 1 tabel + FTS di path dictionary
   (tanpa potong remote dulu).
5. Baru commit ke implementasi penuh sesuai fase yang dipilih.
