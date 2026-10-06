# Cache Mobile (kontrak v1 - draft)

Status: **backlog / draft kontrak**. Belum diimplementasi. Angka TTL,
prioritas endpoint, dan detail store boleh direvisi sebelum build.
Induk: [`CACHE.md`](CACHE.md).

Tujuan: mengurangi hit ke API free-tier (rate limit, cold host failover)
dan memberi UX baca kamus saat jaringan jelek, tanpa mengubah kontrak
API.

Pasangan kebijakan web: [`CACHE-WEB.md`](CACHE-WEB.md).
Matriks TTL di Section 3 **wajib sama** di kedua dokumen.

## 1. Non-goals

- Offline-first penuh / sync conflict resolution.
- Menyimpan access/refresh token di layer cache response (tetap
  `flutter_secure_storage` via `AuthTokenStorage`).
- Mengganti failover multi-host (`lib/core/network/failover/`) - failover
  adalah circuit breaker host, **bukan** cache payload.
- ETag / `If-None-Match` / 304 dari API (belum didukung; fase 1 TTL +
  event lokal saja).

## 2. Alur baca (cache-aside + SWR)

Cek storage **dulu**, baru network. Jangan “hit API lalu baru cek cache”.

```text
butuh data
  -> ada entry dan age <= fresh?     -> sajikan cache (0 hit API)
  -> fresh < age <= staleMax?        -> sajikan stale + revalidate background
  -> miss atau age > staleMax?       -> request API sync -> simpan -> sajikan
  -> network gagal + ada stale?      -> sajikan stale (degradasi) + tandai isStale
```

Lapisan di app:

| Layer | Apa | Bertahan cold start? |
| --- | --- | --- |
| L0 | Riverpod `keepAlive` (sudah ada di detail/list/home) | Tidak |
| L1 | Disk `ResponseCacheStore` (kontrak ini) | Ya |

L0 tetap hot path in-session. L1 mengisi cold start dan degradasi
jaringan.

## 3. Empat lapisan invalidation (ambang batas)

Invalidation **bukan satu TTL global**. Empat lapisan:

| Lapisan | Kondisi | Efek ke API |
| --- | --- | --- |
| L1 Fresh | `age <= freshSeconds` | 0 hit |
| L2 SWR | `fresh < age <= staleMax` | 1 hit background; UI pakai stale |
| L3 Hard expiry | `age > staleMax` | 1 hit sync wajib |
| L4 Event | mutasi lokal / logout / bump schema | hapus key; request berikutnya = miss |

### Matriks TTL kanonik

| Kelas | Contoh endpoint | `fresh` | `staleMax` |
| --- | --- | --- | --- |
| Rujukan statis | `/languages`, `/word-classes`, `/dialects` | 24 jam | 7 hari |
| Detail kamus | `/words/:id`, `/words/lemma/:lemma` | 5 menit | 24 jam |
| Feed / list | `/words/latest`, `/words` (page) | 2 menit | 1 jam |
| Word of day | `/words/today` | sampai batas hari lokal (atau max 1 jam) | 24 jam |
| Search | `/words/search` | 1 menit | 30 menit |
| Sosial publik | discussion published list/detail | 1 menit | 30 menit |
| Negative 404 | lemma/id tidak ada | 2 menit | 2 menit (tanpa SWR) |
| User / private | `/auth/me`, inbox, vote pribadi, bookmark server | **jangan persist** | - |
| Mutasi | POST / PATCH / DELETE | n/a | trigger L4 |

Word of day: key sertakan tanggal kalender lokal
(`GET /words/today|date=2026-09-25`) supaya ganti hari = miss alami.

### Aturan L4 (device / session yang sama)

- Setelah sukses kontribusi, vote, komentar, atau edit profil: invalidate
  resource terkait + list terkait (contoh: detail kata X + `latest`).
- Logout / hapus akun: wipe seluruh cache **user-scoped**; public boleh
  tetap.
- Konstanta `cacheSchemaVersion` naik (breaking DTO): wipe entry versi
  lama saat startup.
- Pull-to-refresh di layar: hard miss untuk key layar itu (pola
  `invalidate` Riverpod yang sudah ada di detail kata).

Mutasi server yang mengubah permukaan publik (relevan jika admin
bertindak di device yang sama, atau nanti via epoch fase 2): approve /
reject / correct contribution, admin word edit / takedown, resolve
word-report yang mengubah konten published. Submit kontribusi
`pending_review` biasanya **belum** mengubah cache publik sampai
approve.

### Trade-off eksplisit (PO)

Tanpa sinyal server (epoch / push), device lain melihat data baru paling
lambat setelah jendela `fresh` (atau `staleMax` jika revalidate gagal).
Ini diterima untuk free-tier fase 1.

Fase 2 (catat saja, jangan kerjakan sekarang): `GET /api/v1/cache-epoch`
atau header `X-Content-Epoch` monoton saat publish / takedown. Klien
bandingkan epoch tersimpan lalu wipe kelas `detail` / `list` bila
berubah. Lebih murah daripada ETag per-resource. API publik hari ini
juga tidak mengekspos `updated_at` di detail kata.

## 4. Penempatan di arsitektur

Clean Architecture feature-first (`docs/mobile/mobile-base-stack.md`):

```text
presentation (Notifier)
  -> domain (usecase / repository interface)
    -> data:
         repository impl
           -> ResponseCacheStore (L1)
           -> remote datasource (Retrofit / Dio)
```

Prefer **decorator di repository** mulai fitur dictionary + reference.
Banyak call site raw `dio.get` bisa ikut belakangan lewat interceptor
opsional; jangan pasang interceptor global yang men-cache POST/auth
secara tidak sengaja.

UI / Notifier **tidak** menghitung TTL sendiri.

## 5. Kontrak store

```dart
// Pseudocode kontrak - nama tipe boleh disesuaikan saat implementasi
class CacheEntry {
  final String key;
  final int schemaVersion;
  final DateTime cachedAt;
  final String bodyJson; // payload data (atau envelope utuh - pilih satu, konsisten)
  final int? httpStatus; // untuk negative cache 404
}

abstract class ResponseCacheStore {
  Future<CacheEntry?> get(String key);
  Future<void> put(CacheEntry entry);
  Future<void> delete(String key);
  Future<void> deleteByPrefix(String prefix);
  Future<void> evictToBudget(); // LRU by cachedAt / lastAccess
}
```

### Keying

- Format logis: `METHOD|path|normalizedQuery` (tanpa host tier).
- Normalisasi: sort query keys, lowercase lemma, trim, buang param kosong.
- Jangan masukkan Authorization, device id, atau token ke key atau value.
- User-scoped (jika suatu saat diizinkan): prefix `u:{userId}|...` dan
  default **off** untuk persist.

### Storage

- `path_provider` + file JSON per key (atau blob + index LRU).
- **Jangan** SharedPreferences untuk payload besar (detail kata).
- Hive / Isar / sqflite **tidak wajib** fase 1.
- Hard cap total **~32-50 MB**; `evictToBudget` saat `put` menembus
  anggaran.

### Aturan tulis

- Sukses 2xx: `put` dengan `cachedAt = now`.
- 4xx aplikasi (selain 404 yang di-negative-cache): **jangan** timpa
  entry bagus dengan body error.
- 404 detail/lemma: boleh `put` negative singkat (lihat matriks).
- 429 / infra failure: jangan `put`; biarkan stale lama tetap dipakai
  untuk degradasi.

## 6. Prioritas resource (implementasi nanti)

1. `/languages`, `/word-classes`, `/dialects` (ROI tertinggi; form
   kontribusi sering refetch).
2. Word detail by id / lemma.
3. `/words/today` + share backgrounds.
4. `/words/latest`.
5. `/words/search` (last-N query saja; jaga cardinality key).
6. Translation-help published list/detail.

Hindari persist: auth flows, inbox, my-*, vote state pribadi, antrean
admin/review.

## 7. Observability

Dev tool (opsional): hitung `hit` / `miss` / `swr` / `degraded` per sesi
agar PO bisa lihat penghematan sebelum/sesudah. Jangan kirim metric ini
ke analytics produksi tanpa keputusan terpisah.

## 8. Checklist sebelum implementasi

- [ ] Angka matriks Section 3 masih disepakati PO (revisi boleh).
- [ ] `cacheSchemaVersion` dan lokasi folder cache disepakati.
- [ ] Map L4 per aksi UI (kontribusi sukses -> key mana) tertulis di PR.
- [ ] Test: cold start menyajikan L1; pull-to-refresh hard miss; logout
      wipe user-scoped; budget eviction tidak merusak key hot.

## 9. Referensi

- Induk backlog: [`CACHE.md`](CACHE.md)
- [`../mobile/mobile-base-stack.md`](../mobile/mobile-base-stack.md) - stack Flutter
- [`CACHE-WEB.md`](CACHE-WEB.md) - pasangan kebijakan web
- [`../api/api-base-stack.md`](../api/api-base-stack.md) Section 15 (rate
  limit), Section 24 (Workers subrequest)
- Failover host: kode `mobile/lib/core/network/failover/`
