# API - Kontribusi dari Search Miss (jalur provenance)

Mengikuti `api-base-stack.md` (envelope, OpenAPI, ULID, audit, approval
gate Section 22) dan fondasi search-miss di
`03-api-kontribusi-verifikasi.md` (pencatatan miss, list publik/admin,
dismiss, fulfilment derived).

Dokumen ini kontrak **DELTA** untuk menutup celah: kontribusi kata yang
berasal dari kartu search-miss harus tertelusur sebagai jalur search miss
(`search_miss_id`), bukan hanya prefill lemma di client.

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):

- SUDAH ADA: tabel `search_misses`; `GET /api/v1/search-misses` (publik);
  `GET/POST dismiss` admin; pencatatan otomatis saat search 0 hasil;
  `POST /api/v1/contributions/words` (anon); create-word admin/login
  dengan approval gate; fulfilment derived (JOIN words published).
- YANG BELUM: (tidak ada - delta provenance 12-api sudah diimplementasi:
  `search_miss_id` di contributions + body create; soft-check term;
  antrean expose sumber miss; fulfilment translation derived).
  Opsional ketat hide beranda saat ada usulan pending: TIDAK diadopsi
  (keputusan §3: beberapa pending boleh).

---

## Keputusan produk (terkunci di kontrak ini)

1. **Provenance wajib untuk jalur miss**: client yang membuka form dari
   kartu miss MENGIRIM `search_miss_id`. Prefill lemma/terjemahan saja
   TIDAK cukup sebagai "jalur search miss".
2. **Field arah tetap `direction`** di API (`lemma` | `translation`).
   Client mobile memetakan ke `search_in` di UI/router - jangan ganti
   nama field response API.
3. **Fulfilment tetap derived** setelah kata **published** (bukan saat
   submit pending). Miss tetap muncul di beranda selama belum ada kata
   published yang menjawab (lihat aturan match di bawah). Beberapa usulan
   pending untuk miss yang sama BOLEH (anti race: verifikator pilih).
4. **Match fulfilment**:
   - `direction=lemma`: EXISTS word `status='published'` AND
     `lower(trim(lemma)) = term`
   - `direction=translation`: EXISTS published word yang punya
     translation text `lower(trim(value)) = term` (satu JOIN ke
     translations) - ganti "manual sampai diverifikasi" di komentar lama
5. **Admin create dari miss**: `POST /api/v1/admin/words` juga menerima
   `search_miss_id` opsional (role verifikator → biasanya langsung
   published → miss fulfilled segera).
6. **Urutan field makna (admin + mobile)**: pada blok makna/form
   kontribusi, urutan UX wajib:
   **Terjemahan Indonesia → Kelas kata → Definisi** (+ aksi Ambil dari
   KBBI di definisi). Prefill dari miss `direction=translation` mengisi
   terjemahan dulu supaya KBBI mudah di-trigger.
7. **Assist KBBI (opsional, auth)**: tombol Ambil dari KBBI memanggil
   `GET /api/v1/lemma-definitions/lookup` (kontrak
   `13-api-kbbi-lemma-definition.md`). Prefill query dari teks
   terjemahan Indonesia. Apply suggestion mengisi **definisi + kelas
   kata + terjemahan (lemma KBBI)** - user tetap review sebelum submit.
   Lookup **tidak** menulis DB; provenance miss tetap lewat
   `search_miss_id` di body create.
8. **Satu lemma published per bahasa**: beberapa kontribusi pending untuk
   lemma sama (mis. user A dan B sama-sama benar untuk "bandong") BOLEH.
   Saat approve/publish, jika sudah ada kata **published** dengan
   `lower(trim(lemma))` sama di bahasa yang sama → **merge makna**
   (`meanings[]` dipindah ke kata yang sudah tayang, order_index
   dilanjutkan) lalu sumber soft-deleted. Bukan dua entri published.
   Response review/publish boleh menyertakan `merged_into_word_id`.

---

## Prompt

```text
Perluas jalur kontribusi kata agar bisa terikat ke search_miss, mengikuti
api-base-stack + fondasi 03-api-kontribusi-verifikasi.md.

PERUBAHAN SKEMA (WAJIB - Section 7):
1. Tabel contributions: TAMBAH
   search_miss_id varchar(26) NULL
     REFERENCES search_misses(id)
   + index contributions_search_miss_idx (search_miss_id)
   Nullable: kontribusi biasa tanpa miss tetap valid.
2. pnpm drizzle-kit generate --name=contribution-search-miss
   → REVIEW SQL → migrate. Commit schema + SQL satu PR.

PERUBAHAN BODY SUBMIT:
A. POST /api/v1/contributions/words  (publik/anon - sudah ada)
B. POST /api/v1/admin/words           (auth admin path - sudah ada)
C. (Jika ada) POST create-word auth contributor yang reuse createWordSchema

Tambah field OPSIONAL di createWordBodySchema / anon schema:
  "search_miss_id": z.string().length(26).optional()

Validasi use-case (SEBELUM insert word):
a. Jika search_miss_id absen → perilaku lama (tidak berubah).
b. Jika hadir:
   - Load miss by id, deleted_at IS NULL; tidak ada → 404 SEARCH_MISS_NOT_FOUND
   - (Tidak wajib cek is_fulfilled: user boleh usul meski sudah ada draft
     orang lain; fulfilment hanya published.)
c. Insert word + baris contributions seperti biasa, SET
   contributions.search_miss_id = input.
d. Prefill lemma/translation TIDAK dipaksa server dari miss.term -
   client yang prefill; server hanya menyimpan provenance.
   (Opsional soft-check: kalau direction=lemma dan lemma body
   lower(trim) != miss.term → 400 SEARCH_MISS_TERM_MISMATCH details
   [{field:"lemma"}]. PONTAIL: implementasikan soft-check ini - mencegah
   spoof provenance.)

RESPONSE CREATE (201): tambah di data (opsional null):
  "search_miss_id": string | null

ANTREAN REVIEW - DELTA list/detail:
GET /api/v1/admin/contributions dan GET .../:id
  Item contribution tambah:
  "search_miss_id": string | null
  "search_miss_term": string | null   // join saat list/detail
  "search_miss_direction": "lemma"|"translation"|null
Supaya verifikator tahu usulan datang dari jalur miss.

LIST PUBLIK GET /api/v1/search-misses:
  Tidak berubah bentuk item { id, term, direction, hit_count,
  last_searched_at, is_fulfilled, created_at }.
  Fulfilment translation: update query derived (JOIN translations).

ERROR CODE BARU (ERROR_CODES.md):
  SEARCH_MISS_TERM_MISMATCH (400)

TESTING:
- unit: create-word / create-anon dengan search_miss_id valid, 404, mismatch
- e2e: submit anon + miss id → contributions.search_miss_id terisi;
  approve → miss is_fulfilled true di admin list
- Bruno: http/search-miss/contribute-from-miss.bru
- docs/json: sample create response + contribution list item dengan miss

Command verifikasi (api): pnpm typecheck && pnpm test && pnpm lint
```

---

## Catatan Implementasi

- Jangan soft-delete miss saat submit pending - miss hilang dari beranda
  HANYA saat fulfilled (published) atau admin dismiss.
- Soft-check lemma/term: bandingkan normalized lower(trim); untuk
  `direction=translation`, soft-check terhadap **teks terjemahan pertama**
  di meanings[0].translations (bukan lemma).
- Audit trail create-word: sertakan `search_miss_id` di new_data ringkas
  bila ada (Section 21).
- OpenAPI: field baru di request + response schema; tags tetap Words /
  Contributions / Search Misses sesuai route.

### Client UI (admin + mobile) - wajib selaras

| Aspek | Aturan |
| ----- | ------ |
| Urutan field makna | Terjemahan Indonesia → Kelas kata → Definisi (+ KBBI) |
| Prefill `direction=lemma` | Lemma = term; terjemahan/kelas/definisi user isi (KBBI bantu) |
| Prefill `direction=translation` | Terjemahan = term; lemma Sambas user isi; KBBI dari term |
| KBBI | Auth; endpoint `13-api`; autofill definisi + kelas + terjemahan |
| Docs UI | `docs/admin/10-admin-search-miss-buat-kata.md`, `docs/mobile/04-mobile-search-miss-beranda.md` |
