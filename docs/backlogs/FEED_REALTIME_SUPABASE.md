# Feed Realtime via Supabase (mobile)

Status: **plan siap eksekusi** (living doc - update di PR yang sama
saat keputusan implementasi berubah).
Dokumen ini mandiri: cukup dibaca di sini untuk memahami masalah,
solusi, arsitektur, dan urutan kerja.

Ruang lingkup: feed aktivitas beranda mobile (tab Home,
`GET /api/v1/activity`, kontrak
[`docs/api/37-api-activity-feed.md`](../api/37-api-activity-feed.md),
fitur [`docs/mobile/23-mobile-activity-feed.md`](../mobile/23-mobile-activity-feed.md)).
Web/console tidak berubah (tetap via API).

## 1. Tujuan

Feed beranda mobile jadi **realtime**: item baru (kata published,
komentar, vote, dll.) muncul di Home **tanpa pull-to-refresh**,
dengan latensi hitungan detik.

Prinsip yang dikunci (permintaan produk):

1. **Feed mobile membaca dari Supabase** (PostgREST + Realtime
   channel), bukan lagi dari API sebagai jalur utama.
2. **Turso (SQLite) tetap source of truth.** Semua write tetap lewat
   API → Turso. Supabase hanya **proyeksi baca** satu arah
   (Turso → Supabase), tidak pernah ditulis dari luar drain worker.
3. **Kalau Supabase bermasalah, semuanya tetap jalan**: mobile
   otomatis fallback ke `GET /api/v1/activity` (jalur lama, tetap
   hidup), dan data tidak pernah hilang karena seluruh histori tetap
   tersimpan di Turso.

## 2. Arsitektur

```text
 mutasi user (mobile/web/console)
        │
        ▼
 API (Hono, 3 tier) ──transaksi──► Turso SQLite  ← source of truth
   │  insert activity_outbox          (tabel sumber + activity_outbox)
   │
   │ waitUntil(fetch drain, debounce 5-10 dtk)
   │ cron tiap 1 menit (sweeper, idempotent)
   ▼
 POST /internal/feed-sync/drain
   │  claim pending → transform (mapper yang sama dgn read path)
   │  → upsert/delete
   ▼
 Supabase Postgres: public.feed_items  ← read model
   │  RLS: SELECT true untuk anon (data publik saja)
   │  publication supabase_realtime
   ▼
 mobile (supabase_flutter)
   ├── halaman 1 + load-more: PostgREST keyset cursor
   ├── channel realtime: INSERT prepend / UPDATE replace / DELETE remove
   └── gagal → fallback API /activity (otomatis) → gagal lagi → L1 Hive
```

Invariant: **Supabase selalu turunan.** Hapus proyek Supabase
sekalipun, feed tetap tersaji dari API + Turso. Ini implementasi
literal dari "di db sqlite tetap simpan supaya suatu hari jika
terjadi masalah kita tetap bisa pakai".

## 3. Komponen

### 3.1 Turso: tabel `activity_outbox` (baru)

Migration drizzle (`api/src/shared/database/drizzle/migrations`,
jalankan `pnpm drizzle-kit migrate` dari CI Node, bukan lewat
Workers).

```sql
create table activity_outbox (
  id          text primary key,      -- ULID
  entity_type text not null,        -- word|comment|vote|discussion|
                                    -- word_image|word_audio|pronunciation|
                                    -- example|search_miss|welcome|user
  entity_id   text not null,
  action      text not null,        -- upsert | delete | user_redact
  status      text not null default 'pending',  -- pending|done|failed
  attempts    integer not null default 0,
  created_at  text not null,
  processed_at text
);
create index idx_outbox_pending on activity_outbox(status, created_at);
```

Aturan penyisipan:

- Outbox row di-insert **dalam transaksi Drizzle yang sama** dengan
  mutasi utama. Ini menjamin tidak ada event hilang (pola
  transactional outbox; libSQL satu DB jadi atomic).
- `upsert` = item feed perlu dibuat/diperbarui di proyeksi.
- `delete` = item feed perlu dihapus (kata unpublish/soft-delete,
  komentar dihapus, vote dicabut, miss disembunyikan).
- `user_redact` = akun dihapus → actor di semua item feednya
  diredact (privacy, tidak boleh stale).

Titik sisip (daftar kanonik sumber = `ActivityRepositoryImpl` di
`api/src/modules/activity/infrastructure/activity.repository.impl.ts`;
modul mutasi terkait di `api/src/modules/`):

| entity_type | Aksi API | action |
| --- | --- | --- |
| `word` | verifikasi approve (status → published) | upsert |
| `word` | unpublish / soft-delete | delete |
| `comment` | create (published) / delete | upsert / delete |
| `vote` | cast / remove | upsert / delete |
| `discussion` | create / delete | upsert / delete |
| `word_image` `word_audio` `pronunciation` `example` | kontribusi approved | upsert |
| `search_miss` | miss jadi visible | upsert |
| `welcome` | akun terverifikasi pertama kali | upsert |
| `user` | delete account | user_redact |

### 3.2 Supabase: tabel `public.feed_items` (read model)

Kolom = persis wire `ActivityItem` API 37 (sudah redact + snippet),
plus `actor_user_id` untuk redaction massal. **Tidak ada kolom
privat di tabel ini** (syarat RLS anon read).

```sql
create table public.feed_items (
  id                 text primary key,  -- '{kind}:{entityId}', sama dgn API
  kind               text not null,
  created_at         timestamptz not null,
  actor_user_id      text,              -- ULID; untuk user_redact massal
  actor_username     text,
  actor_display_name text,
  actor_avatar_url   text,
  body               text not null,
  subtitle           text,
  target_type        text,
  target_id          text,
  synced_at          timestamptz not null default now()
);
create index idx_feed_items_order on public.feed_items(created_at desc, id desc);
create index idx_feed_items_actor on public.feed_items(actor_user_id);

alter table public.feed_items enable row level security;
create policy "feed_public_read" on public.feed_items
  for select to anon, authenticated using (true);

alter publication supabase_realtime add table public.feed_items;
```

- RLS: hanya `SELECT`. Tidak ada policy INSERT/UPDATE/DELETE untuk
  anon/service dari luar; drain menulis pakai **service role key**
  (secret di server API, tidak pernah ke klien).
- Urutan & kursor: `(created_at desc, id desc)` identik dengan
  keyset API (`merge-activity.ts`), jadi behavior pagination sama.
- Perilaku beda (keputusan produk, disengaja): jalur Supabase
  **tanpa cap 4 per kind**. Cap tetap di jalur API fallback. Feed
  realtime memang menampilkan aktivitas apa adanya; burst komentar
  wajar terlihat.

### 3.3 API: modul `feed-sync` (drain)

Lokasi: `api/src/modules/feed-sync/` (pola 3 lapis standar).

1. **Refactor mapper dulu**: ekstrak mapping row → `ActivityItem`
   dari `ActivityRepositoryImpl` (per sumber: word, comment, vote,
   discussion, kontribusi ×4, search_miss, welcome) menjadi fungsi
   murni `buildFeedItem(entityType, row)` di
   `modules/activity/domain/`. Read path lama dan sync path memakai
   fungsi yang sama → **semantik identik, redaction identik**
   (akun terhapus, filter `FEED_EXCLUDED_USAGE_LABELS`, snippet
   120, `publicAccountName`).
2. **Endpoint internal**: `POST /internal/feed-sync/drain`
   (proteksi header secret `FEED_SYNC_SECRET`, sama pola secret
   lain di wrangler.toml). Logika at-least-once + idempotent:
   - `select` pending `limit 100` (order created_at)
   - per baris: transform → upsert (PostgREST
     `POST /rest/v1/feed_items?on_conflict=id`,
     `Prefer: resolution=merge-duplicates`, batch array) atau
     delete (`DELETE /rest/v1/feed_items?id=eq.…` / filter
     `actor_user_id` untuk `user_redact`)
   - sukses → `update status='done' where id=? and status='pending'`
   - exception → `attempts++`; `attempts >= 5` → `status='failed'`
     (dead letter; `GET /internal/feed-sync/status` memantau jumlah
     pending/failed; endpoint reset manual failed → pending).
   - Dua tier cron menyala bersamaan aman: upsert idempotent by id;
     salah satu yang menang `update ... where status='pending'`.
3. **Trigger latensi rendah**:
   - Setelah transaksi mutasi feed-visible commit, handler memanggil
     `ctx.waitUntil(fetch(drainUrl))` **debounce global 5-10 detik**
     (stamp terakhir di memory module; cukup satu flag per isolate).
     Latensi efektif item baru: hitungan detik.
   - **Cron sweeper tiap 1 menit** menutup yang lolos dari waitUntil
     (isolate mati, deploy, retry). Workers: `[triggers] crons` +
     handler `scheduled` di `worker.ts`. Deno Deploy: `Deno.cron`.
     Render: tanpa cron, cukup jadi tier fallback HTTP.
4. **Backfill sekali jalan**: script `api/src/scripts/` baca via
   repository list* per sumber (mis. 200/sumber terbaru) → upsert
   ke `feed_items`. Jalankan di staging lalu production setelah
   worker hijau.

### 3.4 Mobile: `features/activity` (supabase_flutter)

Dependency baru: `supabase_flutter` (satu paket: PostgREST client +
realtime channel + reconnect exponential backoff builtin; menulis
websocket sendiri = lebih banyak kode untuk hasil sama).

Env (envied, per flavor, `.env.example` diperbarui):

```text
SUPABASE_URL_STAGING= / SUPABASE_URL_PRODUCTION=
SUPABASE_ANON_KEY_STAGING= / SUPABASE_ANON_KEY_PRODUCTION=
FEED_SUPABASE_ENABLED=true|false        # kill switch per flavor
```

File baru / berubah (pola 3 lapis fitur activity):

| File | Peran |
| --- | --- |
| `core/services/supabase_client.dart` | init di bootstrap `main.dart` per flavor (`Supabase.initialize`) |
| `features/activity/data/activity_supabase_datasource.dart` | PostgREST: halaman 1 `order=created_at.desc,id.desc&limit=20`; load-more keyset `or=(created_at.lt.<iso>,and(created_at.eq.<iso>,id.lt.<lastId>))` |
| `features/activity/data/activity_feed_repository.dart` | strategy: flag on → coba Supabase (timeout 8 dtk) → gagal → jalur API lama utuh (L1 cache-nya ikut) |
| `features/activity/presentation/providers/activity_feed_providers.dart` | subscribe channel `feed_items`: INSERT prepend (dedupe by id + tetap lewat filter duplikat WOTD `_isWordOfDayDuplicate`), UPDATE replace by id, DELETE remove by id |

Perilaku:

- **Fallback otomatis, tanpa UI khusus**: Supabase error/network →
  repository diam-diam pakai API. User tidak melihat perbedaan
  (paling tidak realtime sampai koneksi pulih; channel reconnect
  sendiri).
- **L1 Hive tetap** (`CacheClass.feedList`, `CachedJsonClient`):
  hasil halaman 1 Supabase diserialisasi ke **key + bentuk envelope
  yang sama** dengan API, jadi cold start instan, offline, dan
  Network Monitor badge HIT/STALE tetap berfungsi tanpa perubahan.
  Feed **tidak** masuk L2 SQLite dataset kamus
  ([`MOBILE_LOCAL_STRATEGI.md`](./MOBILE_LOCAL_STRATEGI.md)) - feed
  adalah data dinamis, L1 sudah cukup.
- **Pull-to-refresh**: force fresh dari Supabase (lewati L1), makna
  `forceRefresh` tidak berubah.
- Kill switch: `FEED_SUPABASE_ENABLED=false` + rebuild → kembali
  ke jalur API murni. (Remote config tidak dibangun sekarang;
  tambah hanya kalau pembatalan tanpa rilis jadi kebutuhan nyata.)

### 3.5 Keamanan & privasi

- `feed_items` berisi **hanya field publik** hasil mapper yang
  sudah menerapkan redaction akun terhapus, filter usage-label,
  dan snippet. Review diff kolom sebelum enable publication.
- Anon key memang hidup di app (public by design); risikonya
  setara `GET /activity` publik hari ini. Service role key tidak
  pernah menyentuh klien.
- `actor_user_id` = ULID publik (bukan PII); wajib ada agar
  `user_redact` bisa memperbarui semua baris aktor terkait.
- Endpoint drain: secret header, tidak ikut OpenAPI publik, tanpa
  CORS browser.

## 4. Fallback berlapis ("kalau terjadi masalah")

| Masalah | Efek ke user | Pemulihan |
| --- | --- | --- |
| Supabase PostgREST down | Halaman 1/load-more otomatis via API | Channel reconnect; tanpa aksi |
| Realtime putus | Feed diam (tidak ada item baru), baca tetap jalan | supabase_flutter auto-reconnect backoff |
| Sync worker lag / outbox menumpuk | Item baru telat muncul (worst case cron 60 dtk) | Cron sweeper + `status` endpoint; data tidak hilang |
| Supabase ditutup / dikuburkan total | Set flag off; jalur API + Turso tetap utuh | Histori penuh ada di Turso; hapus worker + tabel |
| API down tapi Supabase hidup | Feed tetap realtime dari proyeksi | Read path tidak menyentuh API; mutasi memang butuh API |
| Offline di device | L1 Hive menampilkan halaman terakhir | Sudah ada hari ini |

## 5. Monitoring & analytics

- API drain: log tiap siklus `pending=<n> done=<n> failed=<n>`;
  `GET /internal/feed-sync/status` → `{pending, failed, oldest_pending_ms}`.
  Alarm manual: pending > 100 atau oldest > 5 menit.
- Supabase dashboard: realtime concurrent connections (free tier
  200) dan messages/bulan (2M). Kalau lewat, upgrade Pro (murah
  dibangun sendiri).
- Analytics mobile (wajib per base-stack Section 15, di PR yang
  sama; tambah baris ke tabel Section 15):

| Event | Kapan | Params |
| --- | --- | --- |
| `feed_load` | halaman 1 selesai | `source` (`supabase` / `api_fallback`) |
| `feed_realtime_apply` | event realtime diterapkan | `event` (`insert` / `update` / `delete`), `kind` |

## 6. Risiko & batasan

| Risiko | Mitigasi |
| --- | --- |
| Out-of-order sync (event lama datang belakangan) | Idempotent upsert by id; sort tetap `created_at desc`; cursor tidak pakai seq |
| Perbedaan semantik cap per-kind (API capped, Supabase tidak) | Keputusan produk disengaja; catat di 37-api doc |
| Burst spam vote/komentar membanjiri feed | Cap dijalankan di sisi lain: rate limit mutasi tetap di API; opsi kemudian: cap prepend di notifier (mis. maks 5 insert/kind per sesi tampil) |
| Free tier Supabase quota | Monitor §5; proyeksi kecil (baris feed ringan) |
| Battery (websocket hidup seumur app) | Satu channel saja, subscribe saat app aktif; FCM push sudah jadi jalur notifikasi berat |
| Kebocoran kolom privat ke tabel proyeksi | Tabel hanya kolom §3.2; mapper API yang sudah redact; review sebelum publication |

## 7. Alternatif yang ditolak (dan kenapa)

| Alternatif | Kenapa ditolak |
| --- | --- |
| Dual-write ke Supabase di handler mutasi | Gagal Supabase = mutasi utama gagal/tertunda; coupling latency; outbox memisahkan keduanya |
| Replikasi 7 tabel sumber ke Supabase + merge via view/klien | Duplikasi logika merge + redaction di dua tempat (risiko privasi); query view berat; 7 channel realtime |
| Polling / ETag halaman 1 tiap N detik | Bukan realtime sejati; boros; tetap terasa "harus refresh" |
| Ably / Pusher (pernah disebut di 23-mobile) | Layanan + biaya tambahan; Supabase realtime sudah termasuk dalam pilihan stack |
| Feed local-primary (SQLite device sumber utama) | Bertentangan dengan MOBILE_LOCAL_STRATEGI (L2 hanya kamus, fail/offline saja); feed dinamis butuh mutasi server |

## 8. Urutan kerja

| Fase | Isi | Selesai bila |
| --- | --- | --- |
| F0 | Setup proyek Supabase staging + production; schema `feed_items`, RLS, publication; keys masuk `.env` / wrangler secrets | `select` anon dari staging berhasil |
| F1 | Migration `activity_outbox` + sisip insert di semua titik mutasi §3.1 (sama transaksi) | Staging: aksi menghasilkan baris outbox; jalur read API tidak berubah |
| F2 | Refactor mapper murni + modul `feed-sync` (drain, waitUntil debounce, cron, status) + backfill | Comment baru di staging muncul di `feed_items` < 10 dtk |
| F3 | Mobile: supabase_flutter, datasource, fallback, realtime prepend, L1 format sama, analytics | Staging app: item baru muncul di Home tanpa refresh; airplane-mode → fallback API + L1 |
| F4 | QA (Network Monitor, DebugView, UAT) → production; monitoring aktif | Production hijau; tabel Section 15 + doc update di PR sama |

Estimasi kasar: F0 0,5 hari; F1 1 hari; F2 1-2 hari; F3 1-2 hari;
F4 0,5-1 hari.

### Definition of Done

- [ ] Semua mutasi §3.1 menulis outbox dalam transaksi (test
      integrasi staging)
- [ ] Mapper murni dipakai dua jalur (read API + sync); unit test
      paritas output
- [ ] Drain idempotent: dobel eksekusi tidak mengubah hasil
- [ ] RLS: anon hanya SELECT; tidak ada kolom privat (review diff)
- [ ] Mobile fallback: Supabase diblokir → feed tetap tampil via
      API (widget test + uji manual)
- [ ] Realtime: INSERT/UPDATE/DELETE benar diterapkan (dedupe id,
      filter WOTD)
- [ ] L1 cache tetap berfungsi (cold start, offline, Network
      Monitor badge)
- [ ] Analytics `feed_load` + `feed_realtime_apply` + baris tabel
      Section 15
- [ ] Kill switch teruji (flag off → jalur API murni)
- [ ] Doc update di PR sama: 23-mobile (catatan realtime),
      37-api (catatan proyeksi), tabel status
      MOBILE_LOCAL_STRATEGI, dokumen ini

## 9. Testing

| Lapisan | Target |
| --- | --- |
| API unit | mapper murni per sumber; transform outbox → feed item; claim/mark done |
| API integrasi staging | transaksi mutasi menghasilkan outbox; drain → baris `feed_items`; retry → failed setelah 5 |
| Mobile unit | builder filter kursor PostgREST; fallback repository (datasource mock throw) |
| Mobile widget | prepend realtime + dedupe id + filter duplikat WOTD; skeleton/error state tak berubah |
| Manual E2E | komentar via console staging → muncul di Home mobile < 10 dtk tanpa refresh |

## 10. Referensi

- Kontrak API feed: `docs/api/37-api-activity-feed.md`
- Fitur mobile: `docs/mobile/23-mobile-activity-feed.md`
- Merge/cursor: `api/src/modules/activity/domain/merge-activity.ts`
- Sumber feed: `api/src/modules/activity/infrastructure/activity.repository.impl.ts`
- Cache L1 mobile: `mobile/lib/core/cache/` (`MOBILE_LOCAL_STRATEGI.md` §8)
- Konvensi repo/API: `docs/api/api-base-stack.md`; mobile:
  `docs/mobile/mobile-base-stack.md`
- Env & secrets: `api/wrangler.toml` (komentar setup secrets),
  `mobile/lib/core/constants/env.dart`
