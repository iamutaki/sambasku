# API Word - Graph Relasi Kata (Related Graph, Multi-Hop)

Mengikuti `api-base-stack.md`: Clean Architecture feature-based
(`modules/word/`) - Section 3 (struktur folder), 9
(`@hono/zod-openapi`), 10 (testing), 11 (versioning `/api/v1/`), 13
(envelope & error), 15 (rate limiting), 19 (ULID), 24 (budget
subrequest Workers).

Dokumen ini **memperluas** `04-api-sinonim-inline.md` dan response
`GET /api/v1/words/:id`. Fokus: baca relasi `lexical_relations` lebih
dari 1 lompat (saat ini `related_words`/`appears_in` hanya 1 hop) untuk
mendukung **visualisasi peta kata interaktif di web**. API mengembalikan
`{ nodes, edges }`; rendering graph urusan klien web.

Status DoR: **READY** (8/8) - keputusan produk sudah dikunci di Section
"Keputusan Produk". Kontrak API, batasan subrequest, dan arah
visualisasi sudah final.

---

## Masalah User

Pengguna yang mencari "kata terkait" cuma dapat tetangga langsung. Sinonim
dari sinonim, antonim dari lawan kata, atau rantai `derived_from` tidak
pernah muncul. Di UI detail, ini terasa seperti kamus "datar". Pengguna
tidak punya jalan masuk ke kluster makna yang lebih luas tanpa buka satu
per satu halaman kata.

Metrik sukses:
- % sesi detail yang membuka setidaknya 1 kata dari graph (deep-link
  lintas node) naik dari baseline.
- Penurunan search-miss untuk lemma yang sebenarnya terhubung lewat 2-5
  hop tapi tidak muncul di `related_words` 1 hop.
- Peta kata dibuka di setidaknya 20% sesi detail (target awal, bisa
  disesuaikan setelah instrumentasi).

---

## Keputusan Produk (dikunci)

1. **Tujuan = visualisasi peta kata interaktif** di web (peta node-edge
   yang bisa di-pan/zoom, klik node untuk pindah kata). Mobile menyusul,
   prioritas rendah.
2. **Satu graph gabungan.** Semua `relation_type` digabung jadi satu
   peta; tiap edge tetap membawa `relation_type` sehingga klien bisa
   mewarnai/legenda per tipe. Tidak ada graph per-tipe terpisah.
3. **Depth maksimum 5.** Default tetap 2 (responsif); user bisa naikkan
   sampai 5 (peta lebih luas, response lebih besar). Batas keras 5.
4. **Turso remote mendukung `WITH RECURSIVE`.** Traversal satu query
   recursive CTE. BFS `IN (...)` hanya fallback darurat.

---

## Scope (yang dibangun di iterasi ini)

- Endpoint baca: `GET /api/v1/words/:id/graph` yang mengembalikan node
  dan edge hingga `depth` tertentu dari satu kata awal.
- Traversal lewat `lexical_relations` dua arah (`source_word_id` dan
  `target_word_id`, seperti `related_words` + `appears_in` digabung).
- Filter status: hanya node `published` yang tampil di response publik
  (sama seperti query `findDetailById` saat ini).
- Param `depth` (default 2, maks 5) dan `relation_types` (opsional,
  subset dari enum `relationTypeSchema`) untuk filter peta.
- Cap jumlah node (default 50, maks 200) supaya response dan beban DB
  tetap terkendali walau depth 5.
- Endpoint mendukung **visualisasi peta kata interaktif di web** (klien
  render `{ nodes, edges }`; API tidak mengirim gambar).

## Anti-Goal (tidak dibangun)

- Tidak ada gambar/PNG/SVG graph dari server. Server kirim data
  `{ nodes, edges }`; layout force-directed, pan/zoom, legenda = kerja
  klien web.
- Tidak ada tabel/materialized adjacency baru. Traversal pakai query
  langsung ke `lexical_relations` yang sudah ada.
- Tidak ada penulisan/modifikasi relasi. Endpoint read-only.
- Tidak ada deteksi komponen terhubung (connected component) global.
  Hanya subgraph berakar di 1 kata.
- Tidak ada ranking/peringkat edge (bobot relasi), dan tidak ada edge
  berbobot `derived_from` khusus di luar yang sudah tersimpan.
- Tidak ada graph per-tipe relasi terpisah (keputusan: satu graph).
- Tidak mengubah `relation_type` enum yang ada.

---

## Kontrak API

### Endpoint

```
GET /api/v1/words/:id/graph
```

Query param:

| Nama            | Tipe            | Default | Batas        | Keterangan |
| --------------- | --------------- | ------- | ------------ | ---------- |
| `depth`         | integer         | 2       | 1..5         | Jarak lompat maksimum dari node awal. |
| `relation_types`| string (csv)    | semua   | subset enum  | Filter tipe relasi, mis. `synonym,antonym`. |
| `include_pending` | boolean      | false   | -            | Ikut sertakan node `pending_review` (hanya untuk peran editor/admin). |
| `limit`         | integer         | 50      | 1..200       | Cap jumlah node di response. |

Auth: publik (tanpa `include_pending`). `include_pending=true` wajib
peran `editor`/`admin`/`root`/`reviewer` (Section 22 approval gate).

### Response 200 (envelope `success: true`, `data` di bawah)

```json
{
  "root_word_id": "01HXYZAA...",
  "depth": 2,
  "relation_types": ["synonym", "antonym", "has_component", "derived_from"],
  "truncated": false,
  "nodes": [
    {
      "word_id": "01HXYZAA...",
      "lemma": "makatn",
      "word_type": "word",
      "status": "published",
      "distance": 0
    },
    {
      "word_id": "01HXYZBA...",
      "lemma": "ngamakn",
      "word_type": "word",
      "status": "published",
      "distance": 1
    }
  ],
  "edges": [
    {
      "source_word_id": "01HXYZAA...",
      "target_word_id": "01HXYZBA...",
      "relation_type": "synonym",
      "distance": 1
    }
  ]
}
```

- `nodes` unik per `word_id`. `distance` = hop terdekat dari root.
- `edges` unik per pasangan arah + `relation_type`. Inverse tidak
  disimpan ganda (sesuai `04`), tapi traversal dua arah akan tetap
  menangkap edge masuk dan keluar.
- `truncated: true` bila jumlah node tembus `limit`; edge yang menunjuk
  node terbuang tidak disertakan.

### Error

- `404` - `word_id` tidak ada / soft-deleted (pakai error code existing
  `WORD_NOT_FOUND`).
- `400` - `depth` di luar 1..5, `limit` di luar 1..200, atau
  `relation_types` mengandung nilai di luar enum (VALIDATION_ERROR, field
  `query.<nama>`).
- `401`/`403` - `include_pending=true` tanpa peran cukup (AUTH_REQUIRED /
  FORBIDDEN).

Tidak ada error code baru. Semua pakai yang sudah ada di `ERROR_CODES.md`.

---

## Data Model

Tidak ada migration baru. Pakai `lexical_relations` yang sudah ada
(`docs/dbdiagram.dbml` baris ~453). Traversal = baca tabel ini berulang
sampai `depth` atau cap node.

Batasan kritis (Section 24 budget subrequest Workers):
- Di Workers, **tiap `await db.*` = 1 subrequest**. Akun Free = 50.
- Traversal berbasis N query sequential (1 query per hop) habis di
  depth >= 3. **Wajib** selesaikan traversal dalam **satu round-trip**
  lewat recursive CTE (`WITH RECURSIVE`). Turso remote dikonfirmasi
  mendukung.
- Target: < 5 subrequest total untuk depth 5 + cap node 200 (recursive
  CTE menempuh `depth` sebagai parameter kolom, bukan loop query).
- Guard wajib: cap node diterapkan DI DALAM CTE (batasi baris hasil),
  bukan setelahnya, supaya fan-out node populer tidak meledak.
- Fallback darurat bila recursive CTE bermasalah di runtime tertentu =
  BFS `IN (...)` per level, tetapi hanya boleh jalan bila `depth <= 3`
  dan `limit <= 200` (di atas itu tolak `VALIDATION_ERROR` daripada
  kehabisan subrequest).

---

## Keamanan

- Endpoint read-only, tidak ubah state.
- Validasi `relation_types` di trust boundary pakai Zod (subset enum).
- `include_pending` butuh role check (Section 22). Tanpa itu, node
  non-published tidak bocor ke publik.
- Rate limit mengikuti Section 15 (endpoint baca standar).

---

## Lintas Platform

| Platform | Status | Catatan |
| -------- | ------ | ------- |
| API      | dibangun | endpoint ini. |
| Web      | dibangun (iterasi ini) | render `nodes/edges` jadi peta kata interaktif (force-directed, pan/zoom, legenda warna per `relation_type`). |
| Mobile   | menyusul | Flutter: graph widget opsional; prioritas rendah, mulai dari tampilan list "kata terkait" dulu. |
| Console  | tidak   | admin pakai `include_pending` untuk moderasi kluster. |

Paritas: response `{ nodes, edges }` identik di semua klien. Web merender
peta; mobile tahap awal cukup membedakan tipe relasi lewat list berwarna.

Copywriting: semua string UI (judul panel "Kata terkait", pesan empty
"Belum ada kata terhubung") ikut `AGENTS.md` Section 22 (kamu, tanpa
em/en dash).

---

## Prompt Pengembangan (siap tempel)

```text
TAMBAHKAN endpoint read-only GET /api/v1/words/:id/graph di modul word
(modules/word/), ikuti clean architecture feature-based api-base-stack.md.

STACK (tidak berubah): Hono + OpenAPIHono (Section 9), Drizzle ORM +
Turso, Zod (Section 13 envelope/error), ULID (Section 19).

LOKASI MODUL: modules/word/ (perluas, bukan folder baru)

------------------------------------------------------------------------
1. KONTRAK (lihat 39-api-word-related-graph.md)
------------------------------------------------------------------------
- Query: depth (1..5, default 2), relation_types (csv subset enum),
  include_pending (boolean, default false), limit (1..200, default 50).
- Response 200: { root_word_id, depth, relation_types[], truncated,
  nodes[{word_id, lemma, word_type, status, distance}],
  edges[{source_word_id, target_word_id, relation_type, distance}] }.
- Error: 404 WORD_NOT_FOUND, 400 VALIDATION_ERROR (query.*),
  401/403 bila include_pending tanpa role. Tidak ada error code baru.

------------------------------------------------------------------------
2. TRAVERSAL (WAJIB hemat subrequest - Section 24)
------------------------------------------------------------------------
- Selesaikan traversal dalam SATU query pakai WITH RECURSIVE di Turso
  (dikonfirmasi didukung), dibatasi depth <= 5 dan jumlah node <= limit
  (default 50, maks 200). Cap node diterapkan di dalam CTE.
- Baca dua arah: edge keluar (source_word_id = node) DAN edge masuk
  (target_word_id = node), gabung jadi edges unik.
- Filter status: default hanya node published (sama seperti
  findDetailById). include_pending=true hanya untuk editor/admin/root/
  reviewer.
- Set truncated=true bila cap node tercapai; buang edge ke node terbuang.
- Fallback BFS IN(...) per level hanya bila depth <= 3 dan limit <= 200.

------------------------------------------------------------------------
3. REPOSITORY + USE CASE
------------------------------------------------------------------------
- word.repository.ts: tambah method findRelatedGraph(id, { depth,
  relationTypes, includePending, limit }) -> { nodes, edges, truncated }.
- Use case: validasi query (Zod), panggil repository, map ke response
  schema. Tidak ada mutasi.
- Unit test: depth 1 = sama dengan related_words+appears_in saat ini;
  depth 2 menjangkau tetangga tetangga; dedup node/edge; cap limit +
  truncated; filter relation_types.
- Integration test: transitive relation lewat 2 hop muncul; node
  pending_review tidak tampil tanpa include_pending.
- E2E: GET /words/:id/graph -> 200 shape benar; depth invalid -> 400;
  include_pending tanpa auth -> 403.

------------------------------------------------------------------------
4. DELIVERABLES
------------------------------------------------------------------------
- http/word/get-word-graph.bru (+ test 200 shape, 400, 403).
- docs/json/word/get-word-graph.200.json (contoh response).
- Update 04-api-sinonim-inline.md (referensi) dan ERROR_CODES.md bila
  perlu (tidak ada code baru).
```

---

## Keputusan Produk (terkunci)

Semua pertanyaan penggantung awal sudah diputus 2026-10-04:

1. **Tujuan graph:** visualisasi peta kata interaktif di web. Rendering
   (force-directed, pan/zoom, legenda per `relation_type`) = kerja klien
   web, bukan API.
2. **Definisi "terhubung":** satu graph gabungan, semua `relation_type`
   digabung; tiap edge tetap membawa tipe untuk pewarnaan/legenda klien.
3. **Depth:** default 2, batas keras 5.
4. **Query:** recursive CTE (`WITH RECURSIVE`) di Turso, dikonfirmasi
   didukung. BFS `IN (...)` hanya fallback darurat terbatas.

Tidak ada pertanyaan terbuka. Status READY.

---

## Referensi

- `04-api-sinonim-inline.md` - kontrak relasi & model inherit (dasar
  `lexical_relations`).
- `docs/dbdiagram.dbml` baris ~453 - skema `lexical_relations`.
- `api-base-stack.md` Section 13 (envelope/error), 15 (rate limit), 19
  (ULID), 22 (approval gate), 24 (budget subrequest Workers).
- `ERROR_CODES.md` - `WORD_NOT_FOUND`, `VALIDATION_ERROR`,
  `AUTH_REQUIRED`, `FORBIDDEN` (semua sudah ada).
- `docs/api/api-base-stack.md` - pola prompt clean architecture.
