# API Word Suggestions - Usul Perubahan Kata Existing (Moderasi Admin)

Mengikuti `api-base-stack.md`: Clean Architecture feature-based
(`modules/word-suggestions/` + endpoint change-history di `modules/word/`) -
Section 3 (struktur folder), 9 (`@hono/zod-openapi` + Scalar), 10 (testing),
11 (versioning `/api/v1/`), 13 (envelope & error), 15 (rate limiting),
19 (ULID sebagai ID), 21 (audit trail), **22 (approval gate)**.

Dokumen ini kontrak untuk:
1. **Usul perubahan dari user** - user mengusulkan perubahan pada kata yang
   sudah tayang (lemma, notes, makna, kategori, **relasi link**, **varian
   penulisan**, **gambar**)
2. **Moderasi admin** - verifikator approve / reject (alasan wajib) / correct
   (koreksi suggestion sebelum approve)
3. **Riwayat perubahan** - timeline semua perubahan kata (langsung & dari
   suggestion yang disetujui), tampil di detail kata (via `audit_logs`)

PERLUASAN (vs MVP awal):
- `proposed_changes` + relations (Form A `word_id` saja), variants
  (`alternative`), images (add/remove/set_primary)
- Kategori usulan: `reason_code` (lihat KATEGORI USULAN) + `reason_text`
  opsional

---

## Prompt

```text
Buatkan modul "word-suggestions" (usul perubahan kata existing) untuk backend
Kamus Digital Sambas-Indonesia, mengikuti struktur clean architecture
feature-based yang sudah ditetapkan di api-base-stack.md.

STACK:
- Hono (Node.js runtime) - route pakai OpenAPIHono dari @hono/zod-openapi
- Drizzle ORM + PostgreSQL
- Zod untuk validasi request/response + generate OpenAPI spec
- Migration: Drizzle Kit

LOKASI MODUL:
- modules/word-suggestions/ - usul perubahan + review (baru)
- modules/word/presentation/v1/word-history.routes.ts - endpoint riwayat
  perubahan (menempel di modul word karena entity-nya milik word)

STRUKTUR FILE YANG PERLU DIBUAT:

modules/word-suggestions/
├── domain/
│   ├── entities/
│   │   └── word-suggestion.entity.ts     # WordSuggestion, SuggestionStatus
│   └── repositories/
│       └── word-suggestion.repository.ts # interface (contract)
├── application/
│   ├── use-cases/
│   │   ├── create-suggestion.use-case.ts
│   │   ├── list-suggestions.use-case.ts
│   │   ├── get-suggestion-detail.use-case.ts
│   │   ├── approve-suggestion.use-case.ts
│   │   ├── reject-suggestion.use-case.ts
│   │   └── correct-suggestion.use-case.ts
│   ├── dto/
│   │   └── create-suggestion.dto.ts
│   └── ports/
│       └── .gitkeep
├── infrastructure/
│   └── word-suggestion.repository.impl.ts
├── presentation/
│   └── v1/
│       ├── word-suggestions.routes.ts       # OpenAPIHono + createRoute
│       ├── word-suggestions.controller.ts
│       ├── word-history.routes.ts          # (di-modul word)
│       └── validators/
│           └── suggestion.validator.ts
└── __tests__/
    ├── unit/
    ├── integration/
    └── e2e/

TABEL DATABASE TERKAIT:

PERUBAHAN SKEMA (WAJIB - ikuti alur Section 7):
1. BARU tabel word_edit_suggestions:
   id varchar(26) PK [ULID, Section 19]
   user_id varchar(26) NOT NULL [ref: > users.id]
   word_id varchar(26) NOT NULL [ref: > words.id]
   proposed_changes json NOT NULL
   reason text NOT NULL
     // teks tampilan (dari reason_code label + optional reason_text)
   reason_code varchar(40) NOT NULL
     // typo | inaccurate_definition | missing_example |
     // missing_relation | image_issue | other
   status varchar(30) NOT NULL DEFAULT 'pending'
     // pending | approved | rejected | corrected
   reviewed_by varchar(26) [ref: > users.id]
   reviewed_at timestamp
   review_comment text
   created_at timestamp NOT NULL
   updated_at timestamp
   deleted_at timestamp
   deleted_by varchar(26) [ref: > users.id]
   Indexes {
     (word_id, status)
     (user_id, created_at)
     (status, created_at)
     (reason_code)
   }

2. TAMBAH kolom di audit_logs:
   source_contribution_id varchar(26) [ref: > word_edit_suggestions.id]
   // nullable - link ke suggestion yang mendasari perubahan

3. Migrasi lanjutan (setelah 0020):
   ALTER word_edit_suggestions ADD reason_code varchar(40) NOT NULL
   DEFAULT 'other' (backfill lama → other); index reason_code
   pnpm drizzle-kit generate --name=suggestion-reason-code
   → REVIEW SQL
   pnpm drizzle-kit migrate
4. Commit schema + migration SQL dalam satu PR

STRUKTUR proposed_changes (JSON):
{
  "lemma": "kete'",                    // optional - string
  "notes": "Catatan perbaikan...",     // optional - string
  "meanings": [                        // optional - array perubahan makna
    {
      "meaning_id": "01H...",          // optional - jika ada: update; jika null: add
      "action": "update" | "add" | "delete",
      "word_class_id": "01H...",       // optional
      "definition": "Definisi baru",   // optional
      "translations": [                // optional
        { "language_id": "01H...", "translation_text": "...", "translation_type": "..." }
      ]
      // "examples" DITOLAK (400). Contoh kalimat lewat
      // POST /api/v1/meanings/:meaningId/examples.
    }
  ],
  "category_ids_to_add": ["01H..."],   // optional
  "category_ids_to_remove": ["01H..."], // optional

  // --- PERLUASAN ---
  "relations": [                       // optional - Form A link saja (TANPA word inline)
    {
      "action": "add" | "remove",
      "relation_type": "synonym" | "antonym" | "has_component" | "derived_from",
      "word_id": "01H..."              // wajib - kata existing ≠ kata target
    }
  ],
  "variants": [                        // optional - ejaan alternatif (docs/api/11)
    {
      "action": "add" | "remove",
      "form": "ketex",
      "variant_type": "alternative",   // default alternative untuk usul-edit
      "dialect_id": null               // optional ULID
    }
  ],
  "images": [                          // optional - setelah client upload token
    {
      "action": "add",
      "url": "https://ik.imagekit.io/…",  // atau URL stock
      "provider": "imagekit",            // imagekit | pexels|pixabay|…
      "provider_file_id": "...",
      "alt_text": "...",               // optional
      "is_primary": false
    },
    { "action": "remove", "image_id": "01H..." },
    { "action": "set_primary", "image_id": "01H..." }
  ]
}

Aturan:
- Tidak boleh kosong - minimal SATU field diisi (termasuk relations/variants/images)
- meanings[]: maksimal 10 entri
- meanings[].action='delete' wajib ada meaning_id
- meanings[].action='add' wajib definition + minimal 1 translation
- meanings[].action='update' minimal satu field di luar meaning_id
- relations[]: maksimal 10; hanya Form A (word_id); word_id harus exist & ≠ :id;
  remove wajib relasi existing; DILARANG field `word` (inline Form B)
- variants[]: maksimal 10; add: form ≠ lemma induk, dedup form+dialect;
  remove: match form (+ dialect jika ada); variant_type default 'alternative'
- images[]: maksimal 5 perubahan per usulan; add wajib url + provider_file_id;
  provider boleh `imagekit` (staging) atau stock (pexels dkk). ImageKit
  masuk kata dengan `is_verified: false` sampai approve mempromosikan ke
  GitHub. Stock langsung terverifikasi.
  remove/set_primary wajib image_id milik kata; max 1 is_primary=true di batch add

KATEGORI USULAN (reason_code) - app memilih kategori dulu, form mengikuti:

| reason_code        | Label UI           | Isi proposed_changes yang diterima |
|--------------------|--------------------|-------------------------------------|
| change_meaning     | Ubah makna         | 1 meanings update: definition dan/atau translations (tanpa word_class_id) |
| change_word_class  | Ubah kelas kata    | 1 meanings update: word_class_id saja |
| add_meaning        | Tambah makna       | 1 meanings add |
| add_photo          | Tambah foto        | images add saja |
| change_photo       | Ubah foto          | images; wajib ada remove atau set_primary (add boleh sebagai pengganti) |
| synonym / antonym  | Sinonim / Antonim  | relations dengan relation_type sama dengan kategori |
| spelling_variant   | Variasi penulisan  | variants |
| lemma_notes        | Lainnya            | lemma dan/atau notes |

Tambah contoh bukan kategori usulan: app memanggil
`POST /api/v1/meanings/:meaningId/examples`.

Bagian di luar kolom kanan ditolak 400 `VALIDATION_ERROR`. `reason_text`
opsional untuk semua kategori.

Kode lama (`typo`, `inaccurate_definition`, `missing_example`,
`missing_relation`, `image_issue`, `other`) tetap diterima untuk app versi
lama, tanpa cek bentuk. `other` tetap wajib `reason_text` min 3.

ATURAN KATEGORI:

- Kunci pending: satu usulan pending per kata per kategori (409
  `SUGGESTION_ALREADY_PENDING`, pesan menyebut kategorinya). Kode lama
  mengunci dan dikunci semua kategori.
- Tayang dulu (apply_pending) hanya untuk kontributor pada kata belum
  terverifikasi DAN perubahan yang bisa dikembalikan penuh saat ditolak
  (update makna, lemma/notes, tambah foto). Tambah makna, sinonim, antonim,
  variasi, hapus/utama foto menunggu antrean dulu.
- Tolak usulan tayang dulu hanya mengembalikan field yang disentuh usulan
  itu; usulan kategori lain yang tayang bersamaan tidak ikut hilang, dan
  status verifikasi kata tidak diubah.
- Padanan (translations pada update makna): kata belum terverifikasi -
  padanan bahasa yang sama diganti; kata terverifikasi - padanan ditambah.
- ID basi: meaning_id, image_id, relasi/variasi yang dihapus harus milik
  kata saat ini (409 `SUGGESTION_STALE_DATA`, app memuat ulang detail).
- Update makna yang isinya sama persis ditolak 400 `SUGGESTION_NO_CHANGES`.
- Foto yang dihapus tidak boleh sekaligus set_primary. Jika foto utama
  dihapus, foto tersisa paling lama menjadi utama.
- Blocklist komentar menyaring notes, definisi, padanan, dan reason_text
  (whole-word jadi `***`). Field yang hilang lebih dari separuh ditolak 400
  "Teks mengandung kata yang tidak pantas". Lemma dan variasi tidak disaring;
  kata berlabel kasar/tabu/seksual/diskriminatif tidak disaring sama sekali.
  Aturan yang sama berlaku di POST examples (source/target sentence).

Persistensi:
- `reason_code` disimpan apa adanya
- `reason` (text) = label UI; jika reason_text ada →
  `"${label}: ${reason_text}"` (untuk other wajib ada text)

---

========================================================================
ENDPOINT USULAN PERUBAHAN (AUTHENTICATED USER)
========================================================================

1. POST /api/v1/words/:id/suggest-edit
   Middleware: authenticate + authorizeRole('admin','editor','contributor',
   'root','reviewer') + rateLimit 10/jam per user_id

   Path param: :id = ULID kata

   Body:
   {
     "proposed_changes": { ... },      // JSON sesuai struktur di atas
     "reason_code": "change_meaning",  // wajib - kategori di atas
     "reason_text": "opsional detail"  // max 500; wajib min 3 hanya untuk kode lama other
   }

   // BACK-COMPAT (opsional, deprecated): body lama {"reason": "..."}
   // di-map ke reason_code='other' + reason_text=reason jika reason_code absen.

   Use case: CreateSuggestionUseCase
   a. Validasi: kata ada & published, proposed_changes tidak kosong &
      valid, user bukan pembuat kata sendiri, reason_code valid
   b. Insert word_edit_suggestions:
      - Kontributor (bukan isVerifierRole): status='pending'
        * Kata belum verified: apply_pending (changes tayang, antrean tetap)
        * Kata verified: pending saja (isi tayang belum berubah)
      - Verifikator (admin|editor|root|reviewer via isVerifierRole):
        self-apply (lihat "Catatan self-apply verifikator" di bawah)
   c. Audit trail: action 'create' (kontributor) atau 'approve'
      (verifikator self-apply), entity_type 'word_suggestion'

   Response sukses (201):
   { "success": true,
     "data": {
       "suggestion_id": "01H...",
       "word_id": "01H...",
       "word_lemma": "kete'",
       "status": "pending" | "approved",
       "created_at": "2026-01-01T00:00:00Z",
       "message": "Usul perubahan berhasil dikirim. Terima kasih!"
                   // atau "Perubahan langsung diterapkan." (verifikator)
     } }

   Error codes baru: WORD_NOT_FOUND (404), WORD_NOT_PUBLISHED (400),
   CANNOT_SUGGEST_OWN_WORD (403), INVALID_SUGGESTION_CHANGES (400),
   SUGGESTION_ALREADY_PENDING (409)

   ---
   Catatan self-apply verifikator (edge case):
   - `applyChangesToWord(..., 'approve')` mensyaratkan baris masih
     `status=pending`, jadi alur insert: pending → apply (set approved +
     reviewed_by/at) → set kata `is_verified=true` + `verified_by` actor.
   - Bukan transaksi DB tunggal (apply menyentuh banyak tabel lewat helper
     global). Jika promote gambar / apply / verify gagal setelah insert:
     baris usulan di-soft-delete (`deleted_at`) supaya tidak muncul di
     antrean pending sebagai orphan.
   - Gambar ImageKit tanpa `image_decisions`: default promote semua
     (sama endpoint approve admin tanpa decisions).

========================================================================
ENDPOINT RIWAYAT PERUBAHAN (PUBLIC - tidak perlu auth)
========================================================================

2. GET /api/v1/words/:id/change-history
   Middleware: rateLimit 100/min per IP (baca-only)
   Path param: :id = ULID kata

   Query: ?limit=20 (1-100, default 20) &cursor=<ULID>

   Use case: GetChangeHistoryUseCase
   - Ambil audit_logs WHERE entity_type='word' AND entity_id=:id
   - Gabung dengan users untuk nama actor
   - Gabung dengan word_edit_suggestions untuk source suggestion
   - Cursor pagination

   Response sukses (200):
   { "success": true,
     "data": [
       {
         "id": "01H...",                  // audit_log id
         "timestamp": "2026-01-01T00:00:00Z",
         "actor": { "user_id": "01H...", "username": "admin_sambas", "display_name": "Admin Sambas" },
         "type": "direct_edit",           // direct_edit | suggest_edit
         "changes": [
           { "entity": "word", "field": "lemma",
             "old_value": "kete'", "new_value": "kete'",
             "display_old": "kete'", "display_new": "kete'" }
         ],
         "source": null | {              // bila type=suggest_edit
           "suggestion_id": "01H...",
           "suggested_by": { "user_id": "01H...", "username": "kontributor", "display_name": "Ayu" },
           "reason": "Perbaikan typo",
           "reviewer": { "user_id": "01H...", "username": "admin", "display_name": "Admin" } | null,
           "review_comment": "Setuju!" | null
         }
       }
     ],
     "meta": { "limit": 20, "next_cursor": "01H...|null", "has_more": true }

========================================================================
ANTREAN REVIEW USULAN (ADMIN) - 4 ENDPOINT
========================================================================

Middleware SEMUA endpoint: authenticate + authorizeRole('admin','root','reviewer')
+ rateLimit 100/min per user_id

3. GET /api/v1/admin/word-suggestions
   Query: ?status=pending|approved|rejected|corrected &limit=20 &cursor=<ULID>
   Urutan: ORDER BY id DESC

   Use case: ListSuggestionsUseCase
   - JOIN users untuk username kontributor
   - JOIN words untuk lemma kata

   Response sukses (200):
   { "success": true,
     "data": [
       {
         "id": "01H...",
         "word_id": "01H...",
         "word_lemma": "kete'",
         "contributor_id": "01H...",
         "contributor_username": "kontributor_ayu",
         "reason": "Kesalahan penulisan",
         "reason_code": "typo",
         "status": "pending",
         "created_at": "2026-01-01T00:00:00Z",
         "summary_changes": {
           "lemma": "kete'",
           "notes": null,
           "meanings_count": 1,
           "categories_added": 0,
           "categories_removed": 0,
           "relations_count": 1,
           "variants_count": 1,
           "images_count": 0
         }
       }
     ],
     "meta": { "limit": 20, "next_cursor": "01H...|null", "has_more": true }

4. GET /api/v1/admin/word-suggestions/:id
   Path param: :id = ULID suggestion

   Response sukses (200):
   { "success": true,
     "data": {
       "suggestion": {
         "id": "01H...", "word_id": "01H...", "word_lemma": "kete'",
         "contributor_id": "01H...", "contributor_username": "kontributor_ayu",
         "reason": "Kesalahan penulisan",
         "reason_code": "typo",
         "proposed_changes": { ... },      // FULL JSON
         "status": "pending",
         "created_at": "2026-01-01T00:00:00Z"
       },
       "current_word": {                   // snapshot kata SEBELUM perubahan
         "lemma": "kete'", "notes": null,
         "meanings": [ { id, word_class: {code, name}, definition, translations } ],
         "category_ids": ["01H..."],
         "relations": [ { relation_type, word_id, lemma } ],
         "variants": [ { form, variant_type, dialect_id } ],
         "images": [ { id, url, is_primary, alt_text } ]
       },
       "diff": {
         "lemma": { "current": "kete'", "proposed": "kete'", "changed": false },
         "notes": { "current": null, "proposed": "Catatan baru", "changed": true },
         "meanings": [
           { "meaning_id": "01H...", "changes": [
             { "field": "definition", "current": "Definisi lama", "proposed": "Definisi baru", "changed": true }
           ]}
         ],
         "categories": { "added": ["01H..."], "removed": [] },
         "relations": {
           "added": [ { "relation_type": "synonym", "word_id": "01H...", "lemma": "..." } ],
           "removed": []
         },
         "variants": {
           "added": [ { "form": "ketex", "variant_type": "alternative" } ],
           "removed": []
         },
         "images": {
           "added": [ {
             "url": "...",
             "is_primary": false,
             "provider": "imagekit",
             "provider_file_id": "file_…"
           } ],
           "removed": [ { "image_id": "01H..." } ],
           "set_primary": [ { "image_id": "01H..." } ]
         }
       }
     } }

5. POST /api/v1/admin/word-suggestions/:id/approve
   Body JSON: {
     "comment": "...",                 // opsional
     "image_decisions": [              // opsional, foto ImageKit add
       { "key": "0", "decision": "approve" },
       { "key": "file_…", "decision": "reject" }
     ]
   }
   ATAU multipart/form-data:
     - comment (opsional)
     - image_decisions (JSON string; key = indeks add atau provider_file_id)
     - file_<key> (blob hasil sensor, opsional)

   Alur foto saat approve:
   - ImageKit + approve → promote GitHub (bytes sensor bila ada) →
     hapus staging → insert/update sebagai github + is_verified true
   - ImageKit + reject / "Jangan tayangkan" → hapus staging; tidak
     diterapkan (atau soft-delete bila sudah apply_pending ke kata)
   - Stock: ikut apply kecuali ditolak di image_decisions
   - Usulan baseline (kata belum verified, changes sudah apply_pending):
     promote/soft-delete baris staging di word_images, lalu set kata
     is_verified true

   Use case: ApproveSuggestionUseCase
   a. Validasi: suggestion ditemukan, status='pending'
   b. SATU TRANSAKSI:
      - Siapkan foto (promote/sensor/reject) lalu terapkan
        proposed_changes ke kata
      - Sinonim dua arah ikut aturan create-word bila relation_type=synonym
      - Set status='approved', reviewed_by, reviewed_at, review_comment
      - Insert audit_logs (old_data/new_data sertakan ringkasan field baru,
        bukan hanya lemma/notes); source_contribution_id = suggestion id
   c. Error codes: SUGGESTION_NOT_FOUND (404),
      SUGGESTION_ALREADY_REVIEWED (409)

   Response sukses (200):
   { "success": true,
     "data": {
       "suggestion_id": "01H...",
       "word_id": "01H...",
       "word_lemma": "kete'",
       "status": "approved",
       "changes_applied": 3,
       "message": "Usulan telah disetujui dan diterapkan."
     } }

6. POST /api/v1/admin/word-suggestions/:id/reject
   Body: { "comment": "alasan penolakan" }   // WAJIB

   Use case: RejectSuggestionUseCase
   a. Validasi: suggestion ditemukan, status='pending', comment wajib
   b. Hapus semua file ImageKit di proposed_changes.images (action=add)
      yang belum / sudah diterapkan; jika baseline apply_pending:
      soft-delete baris staging terkait + restore baseline kata
   c. Set status='rejected', reviewed_by, reviewed_at, review_comment
   d. Audit: action 'reject'

   Response sukses (200):
   { "success": true,
     "data": { "suggestion_id": "01H...", "status": "rejected" } }

7. POST /api/v1/admin/word-suggestions/:id/correct
   Body:
   {
     "entity_type": "word_suggestion",     // wajib 'word_suggestion'
     "publish": true,                       // default true
     "corrected_changes": { ... },         // JSON - proposed_changes yang telah
                                            // dikoreksi admin
     "comment": "..."                       // opsional
   }

   Use case: CorrectSuggestionUseCase
   a. Validasi: suggestion ditemukan, status='pending', entity_type cocok
   b. SATU TRANSAKSI:
      - Snapshot proposed_changes asli → audit old_data
      - Replace proposed_changes dengan corrected_changes
      - Jika publish=true:
        * Terapkan corrected_changes ke kata
        * status='corrected'
      - Jika publish=false:
        * status='pending' (masih menunggu)
        * Audit: action 'correct', new_data { status: 'pending' }
   c. Response 200:
      - publish=true: { ..., "status": "corrected", "applied": true }
      - publish=false: { ..., "status": "pending", "applied": false }

========================================================================
KONTRAK LINTAS (WAJIB)
========================================================================

- Semua response envelope standar Section 13; list pakai meta cursor
- Route WAJIB createRoute() + app.openapi() (Section 9)
- Enum status di schema RESPONSE wajib 4 nilai
- Error code BARU (daftarkan di ERROR_CODES.md): WORD_NOT_PUBLISHED,
  CANNOT_SUGGEST_OWN_WORD, SUGGESTION_NOT_FOUND, SUGGESTION_ALREADY_REVIEWED,
  INVALID_SUGGESTION_CHANGES
- Audit trail: setiap approve/reject/correct melempar audit entry
- Race double-review: cek suggestion.status DI DALAM transaksi
- Testing: unit per use case, integration untuk repository, e2e per endpoint

---

## Catatan Implementasi

- Use case **tidak boleh** import Drizzle/transaction API langsung -
  atomicity diekspresikan di kontrak repository.
- Modul word-suggestions berkomunikasi dengan modul word lewat interface
  WordRepository yang sudah ada.
- `main.ts` me-register:
  `app.route('/api/v1/admin/word-suggestions', wordSuggestionRoutes)`
  dan `app.route('/api/v1/words/:id/change-history', ...)` (di modul word)

## Referensi Terkait

- `api-base-stack.md` - Section 22 (approval gate), 21 (audit), 13 (envelope)
- `03-api-kontribusi-verifikasi.md` - pola review approve/reject/correct
- `01-api-tambah-kata.md` - modul word (WordRepository interface)
- `04-api-sinonim-inline.md` - Form A link (usul-edit HANYA Form A)
- `11-api-variasi-penulisan.md` - variant_type alternative
- `docs/dbdiagram.dbml` - update dengan tabel word_edit_suggestions +
  kolom audit_logs.source_contribution_id + reason_code
- `ERROR_CODES.md` - katalog error code
- `docs/json/word-suggestions/` - sample response
- `docs/mobile/06-mobile-suggest-edit.md` - UI mobile
- `docs/admin/13-admin-suggest-edit.md` - UI admin
