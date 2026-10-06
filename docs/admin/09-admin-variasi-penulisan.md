# Admin - Variasi Penulisan pada Form Kata & Pencarian Lintas Varian

Penyesuaian UI admin terhadap kontrak variasi penulisan
(`docs/api/11-api-variasi-penulisan.md`): form tambah/edit kata
memperlakukan tipe `alternative` sebagai "Ejaan Alternatif" first-class
(dengan contoh ketek → ketex, kettek, kete'), validasi client mirror
server, dan dropdown pencarian kata menampilkan kecocokan via variasi
("ketex → ketek").

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):

- SUDAH ADA: section variants lengkap di word-form-blocks (Form.List:
  form, tipe varian, afiks, dialek, notes; `VARIANT_TYPE_LABELS`),
  halaman detail kata menampilkan `variants[]`, `word-search-select`
  (antd Select + cursor "Muat lagi"), endpoint create/edit menerima
  variants[], prefill edit.
- Yang BELUM (tergantung implementasi API docs 11): validasi mirror di
  form (form ≠ lemma, dedup, alternative tanpa afiks), UX tipe
  alternative (label + helper + sembunyikan afiks), `matched_variant`
  di dropdown pencarian.

KEPUTUSAN PRODUK (2026-09-19):

- Tipe `alternative` dipromosikan sebagai JALUR UTAMA form: item baru
  default `alternative` berlabel "Ejaan Alternatif"; field afiks
  disembunyikan/dimatikan untuk tipe ini (mirror validasi server -
  400 kalau dikirim). Tipe lain (inflection/derivation/reduplication)
  tetap tersedia lewat Select yang sama untuk editor lanjutan.
- Validasi client MIRROR server persis (pesan sama): form ≠ lemma
  (trim + case-insensitive), dedup (form, dialek) antar-item, maks 20.
  Server tetap sumber kebenaran (400 VALIDATION_ERROR dipetakan inline).

---

## Prompt

```text
Sesuaikan form kata admin (tambah + edit) dan dropdown pencarian kata
dengan kontrak variasi penulisan docs/api/11. UI variants sebagian besar
SUDAH ADA - fokus pada poin penyesuaian berikut.

KONTEKS:
- Server (docs 11): alternative tanpa afiks; form ≠ lemma; dedup
  (form, dialect_id); max 20; search lemma match variasi + field
  matched_variant di item hasil.

STRUKTUR:
1. domain/create-word.ts - UBAH: VARIANT_TYPE_LABELS.alternative =
   'Ejaan Alternatif' (konsekuensi: label ini ikut terpakai di detail
   kata - memang diinginkan).
2. presentation/word-form-blocks.tsx (section variants) - UBAH:
   a. Item baru default variant_type 'alternative'.
   b. Bila tipe item = 'alternative': field affix_type/affix_value
      TIDAK dirender (bukan sekadar disabled - jangan kirim), dan
      tampilkan placeholder/helper form: "mis. ketex, kettek, kete'".
   c. Validasi antar-item di level section (bukan per-field):
      - form (trim+lowercase) === lemma form utama → error inline item
        "Bentuk sama persis dengan lemma - tidak perlu dicatat sebagai
        variasi".
      - duplikat (form lowercase + dialect_id) antar-item → error di
        item kedua "Variasi duplikat".
      - melebihi 20 item → tombol tambah disabled + pesan.
3. presentation/create-word-page.tsx + edit-word-page.tsx - UBAH:
   mapping error 400 VALIDATION_ERROR path variants / variants.N.form
   dari server sudah lewat ApiError.fieldErrors() → form.setFields;
   pastikan name path Form.List cocok (['variants', N, 'form']) supaya
   error server tampil inline pada item yang benar.
4. presentation/word-search-select.tsx - UBAH (setelah API 11 jalan):
   item hasil search membawa matched_variant (string|null). Label opsi:
   - null → `${lemma} (${language_code})` (seperti sekarang).
   - terisi → `${lemma} (${language_code}) - cocok varian: "${matched}"`
     atau badge kecil; tujuannya verifikator paham kenapa kata muncul
     untuk q yang bukan lemmanya.
5. presentation/word-detail-page.tsx - UBAH ringan: variasi tipe
   'alternative' diberi Tag warna berbeda (mis. blue) + judul section
   "Variasi Penulisan" bila SEMUA item alternative, "Bentuk Turunan"
   bila campur (label lama tetap relevan untuk morfologi).

TIDAK ADA: endpoint baru, perubahan hook query, halaman baru.

Command verifikasi: pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

## Catatan Implementasi

- Section form yang tadinya diduplikasi inline di create-word-page +
  edit-word-page diekstrak menjadi `WordVariantsField` + `VariantRow`
  di word-form-blocks.tsx (satu sumber; row-level `Form.useWatch`
  menyembunyikan/membersihkan afiks saat tipe 'alternative').
- Validasi antar-item (dedup, ≠ lemma) via validator Form.Item yang
  membaca `form.getFieldValue('variants')` - mirror pesan server.
- `matched_variant` mengalir otomatis: `WordListItem` (dipakai
  langsung sebagai tipe wire) ditambah field opsional; dropdown
  menampilkan `ketek (smb) - cocok varian: "ketex"`.
- Detail: `alternative` dirender Tag biru; judul section adaptif
  ("Variasi Penulisan" bila semua alternative).
- Verifikasi: typecheck + lint (total warning tetap 20 = baseline) +
  91 test + build sukses.

## Referensi Terkait

- `docs/api/11-api-variasi-penulisan.md` - kontrak API (validasi,
  matched_variant, materialisasi kontribusi anonim).
- `docs/admin/01-admin-tambah-kata.md`, `02-edit-kata.md` - form kata
  (semantik prefill + full-replace).
- `docs/admin/04-detail-kata.md` - halaman detail.
- `docs/admin/admin-base-stack.md` - Section 12 (error handling),
  17 (responsive).
- `docs/mobile/03-mobile-variasi-penulisan.md` - sisi mobile (usul
  kata).
