# API - Moderasi Search Miss (koreksi term + tayang)

Mengikuti `api-base-stack.md` (envelope, OpenAPI, ULID, audit) dan fondasi
search-miss di `03-api-kontribusi-verifikasi.md` + provenance
`12-api-search-miss-contribute.md`.

Dokumen ini kontrak **DELTA**: admin boleh mengoreksi typing user
(`term`) dan mengontrol apakah miss tampil di beranda publik
(`is_visible` / tayang).

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):

- SUDAH ADA: tabel `search_misses`; record otomatis saat search 0 hasil;
  `GET /api/v1/search-misses` (publik); `GET/POST dismiss` admin;
  fulfilment derived; provenance `search_miss_id`.
- YANG BELUM (ditutup kontrak ini): kolom `is_visible`; PATCH koreksi
  term + toggle tayang; filter beranda by visibility.

---

## Keputusan produk (terkunci di kontrak ini)

1. **Gate tayang eksplisit**: miss baru **tidak** otomatis muncul di
   beranda. Kolom `is_visible boolean NOT NULL DEFAULT false`. Hanya
   admin/root yang boleh set `is_visible=true` (tayang) atau `false`
   (sembunyikan tanpa dismiss).
2. **Beranda publik**: `GET /api/v1/search-misses` hanya mengembalikan
   baris `is_visible = true` AND belum fulfilled AND `deleted_at IS NULL`.
   Bentuk item response **tidak** wajib expose `is_visible` ke publik
   (selalu true kalau sampai ke client); admin list **wajib** expose.
3. **Koreksi term**: admin mengubah `term` (typing user yang salah eja /
   typo). Normalisasi server sama dengan `record`:
   `trim + lower + collapse whitespace`, max 255. `term` yang sudah
   dikoreksi dipakai fulfilment match + soft-check provenance
   (`SEARCH_MISS_TERM_MISMATCH` di 12-api).
4. **Unik tetap `(term, direction)`**: kalau term baru bentrok dengan
   miss aktif lain → `409 SEARCH_MISS_TERM_CONFLICT`. Tidak merge
   otomatis (admin pilih dismiss salah satu / pilih term lain).
5. **Default tidak tayang**: kolom `is_visible boolean NOT NULL DEFAULT false`.
   Baris lama saat migrasi juga tetap `false` (tidak di-grandfather).
   Admin harus set `is_visible=true` supaya muncul di beranda mobile.
6. **Dismiss ≠ unpublish**: dismiss = soft-delete (hilang dari panel +
   beranda). `is_visible=false` = masih di panel admin, tidak di beranda.
7. **Upsert `record()`**: insert baru → `is_visible=false`. On conflict
   (term+direction sudah ada) → naikkan `hit_count`, clear dismiss;
   **jangan** reset `is_visible` (keputusan admin tetap).
8. **Role**: endpoint PATCH sama gate dengan panel admin search-miss
   yang ada: `admin` | `root`.

---

## Prompt

```text
Perluas search-miss supaya admin bisa koreksi term + kontrol tayang,
mengikuti api-base-stack + 03-api + 12-api.

PERUBAHAN SKEMA (WAJIB - Section 7):
1. Tabel search_misses: TAMBAH
   is_visible boolean NOT NULL DEFAULT false
2. Migrasi SQL:
   - ADD COLUMN is_visible boolean NOT NULL DEFAULT false
   - (Tidak UPDATE grandfather - existing ikut default false)
   Nama migrasi: search-miss-visibility (0015_…)
   Commit schema TS + SQL + journal satu PR.

ENTITY / REPO:
- SearchMiss: tambah isVisible: boolean
- SearchMissListFilter: tambah visible?: boolean (admin only)
- list(scope=public): AND is_visible = true (selain NOT fulfilled)
- list(scope=admin): expose isVisible; filter visible opsional
- update(id, { term?, isVisible? }): partial; return entity | null
  - term dinormalisasi; kosong setelah normalize → ValidationError
  - unique violation → ConflictError SEARCH_MISS_TERM_CONFLICT
- record() insert: andalkan DEFAULT false; onConflictDoUpdate
  JANGAN set is_visible

ENDPOINT BARU:
PATCH /api/v1/admin/search-misses/:id
  Auth: admin | root
  Params: id ULID 26
  Body (minimal satu field):
    {
      "term"?: string,          // 1-255 setelah trim client; server normalize
      "is_visible"?: boolean
    }
  200 envelope data = item search-miss (bentuk admin list):
    {
      "id", "term", "direction", "hit_count", "last_searched_at",
      "is_fulfilled", "is_visible", "created_at"
    }
  400 VALIDATION_ERROR (body kosong / term kosong setelah normalize)
  401 / 403 seperti endpoint admin lain
  404 SEARCH_MISS_NOT_FOUND
  409 SEARCH_MISS_TERM_CONFLICT

DELTA LIST:
- GET /api/v1/admin/search-misses
  - query opsional: visible=true|false
  - tiap item + "is_visible": boolean
- GET /api/v1/search-misses (publik)
  - filter is_visible=true; bentuk item lama boleh tanpa is_visible
    ATAU sertakan is_visible:true (konsisten OK)

AUDIT:
  action 'update', entityType 'search_miss',
  oldData/newData ringkas { term?, is_visible? }

ERROR_CODES.md:
  SEARCH_MISS_TERM_CONFLICT (409)

TESTING:
- unit: update term sukses; term conflict; body kosong; not found;
  visible toggle
- e2e: search kosong → TIDAK di beranda sampai PATCH is_visible=true;
  koreksi term → beranda pakai term baru; admin list punya is_visible
- Bruno: http/search-miss/update-search-miss.bru
- docs/json: update-search-miss.200.json + update admin-list sample

Command verifikasi (api): pnpm typecheck && pnpm test && pnpm lint
```

---

## Delta #88: skip per user (panel kartu verifikator)

Endpoint `POST /api/v1/admin/search-misses/:id/skip` — "pass" satu kartu
di panel mobile (gate sama: `authenticate + authorizeRole('admin','root','reviewer')`).

- **Skip = per user, bukan moderasi**: miss tidak berubah status; hanya
  user ini yang tidak melihatnya lagi di panel. Verifikator lain tetap
  melihat miss yang sama.
- **Penyimpanan**: tabel generik `user_skips`
  (`user_id, target_type='search_miss', target_id=miss.id`,
  unique(user, target)) — TANPA migrasi baru. On conflict → update
  `created_at` (idempotent).
- **Exclude di list admin**: `GET /api/v1/admin/search-misses` otomatis
  menyembunyikan miss yang sudah di-skip oleh user yang sedang request
  (`NOT EXISTS ... user_skips` + `target_type='search_miss'`).
  Verifikator lain tidak terpengaruh.
- **Soft-delete tidak menghapus skip**: baris skip lama tetap berlaku
  saat miss hidup lagi.
- 200 `data: null`; 404 `SEARCH_MISS_NOT_FOUND` (miss sudah di-dismiss);
  401/403 seperti endpoint admin lain.
- Unit: `skip-search-miss.use-case.test.ts`; e2e: skip per-user
  (hilang dari panel A, tetap terlihat oleh reviewer B).

---

## Catatan Implementasi

- Jangan soft-delete saat unpublish (`is_visible=false`).
- Prefill create-word / mobile dari miss memakai `term` terkini
  (setelah koreksi) - client list admin/publik sudah dapat term baru.
- OpenAPI: schema item admin + body PATCH; tags Search Misses / Admin.
- Docs UI: `docs/admin/11-admin-search-miss-koreksi-tayang.md`.
- Mobile beranda: **tidak** perlu field baru; cukup konsumsi list publik
  yang sudah ter-filter (lihat catatan di `04-mobile-search-miss-beranda.md`).
