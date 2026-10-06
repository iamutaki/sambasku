# API Variasi Penulisan - Ejaan Alternatif Kata & Pencarian Lintas Varian

Mengikuti `api-base-stack.md`: Section 7 (schema), 9 (`@hono/zod-openapi`),
10 (testing), 13 (envelope & error), 15 (rate limiting). Dokumen ini
menegakkan kontrak "variasi penulisan" (ejaan alternatif): satu kosa
kata Sambas sering ditulis berbeda oleh penutur - mis. **ketek** juga
ditulis *ketex, kettek, kete'*. User yang mencari dengan salah satu
ejaan itu HARUS tetap menemukan entri induknya.

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):

- SUDAH ADA: tabel `word_variants` (form, variant_type
  `inflection|derivation|alternative|reduplication`, affix_type/value,
  dialect_id, notes, soft delete; unique `(word_id, form, dialect_id)`),
  `POST /api/v1/admin/words` + update menerima `variants[]` (max 20,
  validator di create-word.validator.ts), `GET /words/:id` mengembalikan
  `variants[]`, UI form admin lengkap (01 + 05), semantik garis
  pemisah variants vs entri mandiri (01).
- Yang BELUM (dokumen ini kontrak-kan):
  1. Pencarian `GET /words/search` HANYA match `words.lemma` - q
     "ketex" tidak menemukan entri "ketek" padahal tercatat sebagai
     variasinya (malah tercatat sebagai search miss - salah sasaran).
  2. Tidak ada validasi khusus tipe `alternative`: affix masih boleh
     terisi (tidak masuk akal untuk ejaan alternatif), `form` boleh
     sama persis dengan lemma induk, duplikat antar-item lolos.
  3. Unique constraint `(word_id, form, dialect_id)` tidak menutup
     duplikat saat `dialect_id` NULL (Postgres: NULL ≠ NULL) -
     dedup harus di level aplikasi.

KEPUTUSAN PRODUK (2026-09-19):

- Variasi penulisan = `variant_type: 'alternative'` pada `word_variants`
  - TANPA afiks (afiks milik inflection/derivation), TANPA makna
  sendiri. Contoh: ketek → ketex, kettek, kete'.
- Variasi TIDAK pernah menjadi entri `words` sendiri dan TIDAK punya
  halaman detail sendiri - semua mengarah ke entri induk (garis
  pemisah 01-api-tambah-kata.md tetap berlaku).
- Pencarian arah `lemma` match `lemma OR variants.form` - hasil tetap
  SATU baris per kata induk (dedup), bukan per varian.
- Q yang cocok dengan variasi TIDAK boleh tercatat sebagai search miss.
- TIDAK ADA tabel/migration baru - semua di atas schema existing.

---

## Prompt

```text
Tegakkan kontrak variasi penulisan pada modul word backend Kamus
Digital Sambas-Indonesia. TIGA titik perubahan: (1) validator
create/update word, (2) repository search, (3) response search.
TIDAK ADA perubahan schema/migration.

LOKASI: modules/word/ (extend existing)

STRUKTUR FILE YANG PERLU DIUBAH:

modules/word/presentation/v1/validators/create-word.validator.ts
  # UBAH: refinement tambahan pada variants[] item:
  # a. variant_type 'alternative' → affix_type & affix_value WAJIB
  #    kosong (VALIDATION_ERROR path affix_type: "Ejaan alternatif
  #    tidak memakai afiks - gunakan tipe inflection/derivation").
  # b. form (trim + lowercase untuk perbandingan) !== lemma (sama-sama
  #    dinormalisasi) → VALIDATION_ERROR path form: "Bentuk sama
  #    persis dengan lemma - tidak perlu dicatat sebagai variasi".
  # c. Dedup antar-item: kombinasi (form lowercase, dialect_id) unik
  #    dalam satu request → VALIDATION_ERROR path variants.
  # Refinement b & c berlaku untuk SEMUA variant_type (bukan hanya
  # alternative) - lemma-sama & duplikat tidak bermakna di tipe mana
  # pun. Terapkan di level schema root (butuh akses lemma + seluruh
  # array), cermin pola refine confirm_password register.
modules/word/presentation/v1/validators/update-word.validator.ts
  # UBAH: refinement SAMA PERSIS (body update = bentuk create, 05).
modules/word/infrastructure/word.repository.impl.ts
  # UBAH searchWords (search_in=lemma): kondisi q menjadi
  #   (ilike words.lemma OR EXISTS (
  #      SELECT 1 FROM word_variants v
  #      WHERE v.word_id = words.id
  #        AND v.deleted_at IS NULL
  #        AND ilike v.form %q% ))
  # - tetap published + belum soft-delete, cursor + limit tidak berubah.
  # - HASIL TETAP SATU BARIS PER KATA (EXISTS, bukan JOIN yang
  #   menduplikasi) - cursor words.id desc aman tanpa DISTINCT ON.
  # searchByTranslation TIDAK berubah.
modules/word/presentation/v1/word.controller.ts (+ response schema)
  # UBAH: item hasil search lemma membawa field opsional
  # matched_variant (string|null): form variasi yang cocok dengan q
  # (preseden: field matched_variant ~ matched_translation di reverse
  # search, 01). q match lemma → matched_variant
  # null; q match hanya variasi → matched_variant terisi supaya UI
  # bisa menampilkan "ketex → ketek".
  # Implementasi: setelah page terbentuk, SELECT form dari word_variants
  # WHERE word_id IN (...) AND form ILIKE %q% AND deleted_at IS NULL -
  # satu query tambahan untuk ≤ limit baris (bukan N+1).

ENDPOINT YANG TERDAMPAK (perilaku, TIDAK ADA endpoint baru):

1. POST /api/v1/admin/words - body variants[] kini divalidasi lebih
   ketat (a/b/c di atas). Contoh variasi penulisan yang BENAR:
   { "variants": [
       { "form": "ketex",  "variant_type": "alternative" },
       { "form": "kettek", "variant_type": "alternative" },
       { "form": "kete'",  "variant_type": "alternative",
         "notes": "ejaan rakyat, apostrof pengganti konsonan akhir" } ] }
   Contoh yang DITOLAK (400 VALIDATION_ERROR):
   - { "form": "ketek", "variant_type": "alternative" }
     → sama dengan lemma induk
   - { "form": "ketex", "variant_type": "alternative",
       "affix_type": "suffix", "affix_value": "-x" }
     → alternative tidak memakai afiks
2. PUT /api/v1/admin/words/:id - validasi sama; semantik full-replace
   variants TIDAK berubah (05): prefill GET :id → UI kirim ulang semua.
3. GET /api/v1/words/search?q=ketex&search_in=lemma
   → 200, item lemma "ketek" dengan matched_variant "ketex".
   Response item: { id, lemma, language_id, language_code, word_type,
   is_verified, status, matched_variant? }
4. GET /api/v1/words/:id - TIDAK berubah (variants[] sudah ada).
5. POST /api/v1/contributions/words (anonim, 06-x-device-id) - TIDAK
   ADA perubahan endpoint: `anonWordSchema = createWordBodySchema.omit(
   { status: true })` MEWARISI seluruh field termasuk variants[], jadi
   refinement (a/b/c) otomatis berlaku. Kontribusi anonim membuat
   entri words + children langsung ber-status pending_review (approval
   gate Section 22) - baris word_variants ikut dibuat dan statusnya
   disinkronkan reviewer saat approve/reject (setWordChildrenStatus).
   Konsekuensi kontrak: refinement variants TIDAK BOLEH dipindah keluar
   dari createWordBodySchema (mis. ke controller admin) - anon route
   bergantung padanya.

KEPUTUSAN SEMANTIK:
- q "kete" (prefix dari kete') match via ilike %q% pada form variasi -
  perilaku sama seperti ilike pada lemma, tidak ada exact-match khusus.
- match variasi hanya di arah search_in=lemma; arah translation tidak
  menyentuh word_variants.
- Search miss (06-x-device-id): q yang menghasilkan ≥1 hasil via
  variasi BUKAN miss - sudah otomatis benar begitu search match variasi
  (miss tercatat hanya saat 0 hasil); tidak ada perubahan kode miss.
- Performance: EXISTS + ilike tanpa index sama karakternya dengan
  ilike lemma saat ini (seq scan saat data besar) - index pg_trgm
  menyusul lewat migration terpisah BILA query melambat (catatan
  performa 01 tetap berlaku, tambahkan `word_variants.form` ke daftar
  kandidat pg_trgm).

KEAMANAN & CATATAN:
- Endpoint role gate & rate limit TIDAK berubah (create/edit:
  30/menit per user_id; search publik 100/menit per IP).
- q tetap di-escapeLike sebelum interpolation (XSS/injection pattern).
- Duplikat lintas kata berbeda DIBOLEHKAN (mis. dua entri dialek
  berbeda sama-sama punya variasi "ketex") - unique hanya per kata.

TESTING:
- Unit validator: alternative + affix → 400; form = lemma → 400;
  duplikat (form, dialect) dalam satu body → 400; kombinasi valid
  (3 variasi ketek) → lolos.
- E2E search: seed kata "ketek" + variasi ketex/kettek →
  GET search?q=ketex → 200 item lemma "ketek" matched_variant "ketex";
  GET search?q=ketek → match lemma, matched_variant null;
  GET search?q=tidakadavarian → 0 hasil.
- E2E create: body dengan variasi valid → 201 (variants tersimpan,
  verifikasi GET :id); body variasi = lemma → 400.
- Regression: search q yang match translation tidak berubah
  (matched_variant tidak muncul di arah translation).
```

## Catatan Implementasi

- Zod: aturan item (alternative tanpa afiks) + dedup antar-item pusat di
  `wordVariantsField` (dipakai createWordBodySchema DAN inlineWordSchema
  Form B) - otomatis mewarisi ke semua pintu. Aturan root (variasi ≠
  lemma) TIDAK BISA tinggal di createWordBodySchema karena turunannya
  memakai `.omit()` (refine memutus .omit) - diekspor sebagai
  `variantRootRefine` dan diterapkan eksplisit di 4 schema turunan:
  createWordSchema, updateWordSchema, anonWordSchema (route file),
  correctWordSchema (contribution validator).
- Search: `ilike lemma OR EXISTS (word_variants ...)` - EXISTS bukan
  JOIN, hasil tetap satu baris per kata (cursor words.id desc aman).
  `matched_variant` diisi pasca-fetch (satu SELECT IN untuk ≤ limit
  baris), HANYA untuk item yang lemma-nya tidak cocok dengan q
  (penentu JS lowercase-includes, setara ilike untuk alfabet Latin).
- Testing: 42 file / 268 test (+7 unit validator, +4 e2e). E2E
  membuktikan: cari "ketex" → ketek + matched_variant; cari "ketek" →
  tanpa matched_variant; prefix "kete" cocok; variasi=lemma/afiks/
  duplikat → 400; pintu anonim menerima variasi (perlu seed user
  sistem Anonim di test - FK).

## Referensi Terkait

- `docs/api/01-api-tambah-kata.md` - semantik word_variants lengkap
  (garis pemisah variants vs entri mandiri), kontrak search + cursor,
  catatan performa pg_trgm.
- `docs/api/05-api-edit-kata.md` - semantik full-replace update +
  prefill.
- `docs/api/06-api-x-device-id.md` - search miss (q match variasi
  bukan miss).
- `docs/api/api-base-stack.md` - Section 13 (envelope), 15 (rate
  limit).
- `docs/admin/` - form tambah/edit kata (section variasi sudah ada;
  label "ejaan alternatif" mengikuti kontrak ini saat implementasi).
