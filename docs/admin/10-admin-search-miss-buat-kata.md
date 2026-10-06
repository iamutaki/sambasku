# Admin UI - Buat Kosakata dari Search Miss

Mengikuti `admin-base-stack.md` (feature-based, React Query, DataTable,
router/guard). Kontrak API yang dikonsumsi:

- Fondasi list/dismiss: `docs/api/03-api-kontribusi-verifikasi.md`
- Provenance submit: `docs/api/12-api-search-miss-contribute.md`
- Form tambah kata: `docs/admin/01-admin-tambah-kata.md` +
  `docs/api/01-api-tambah-kata.md`
- Assist definisi: `docs/api/13-api-kbbi-lemma-definition.md` (urutan
  field makna + KBBI di keputusan 12-api §6-7)

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):

- SUDAH ADA (admin): halaman `/search-misses` (filter arah/fulfilled,
  dismiss soft-delete untuk admin/root/reviewer), form `/words/create`.
- SUDAH ADA (API): list/dismiss search-miss; create word admin;
  lookup lemma-definitions (KBBI).
- YANG BELUM: (sudah diimplementasi - tombol Buat kata → `/words/new`
  + prefill + `search_miss_id`; badge sumber miss di antrean).

---

## Prompt

```text
Perluas panel Search Miss admin supaya verifikator bisa membuat kosakata
langsung dari baris miss (jalur search miss), mengikuti pola create-word
yang sudah ada.

PERILAKU:
1. Kolom Aksi di /search-misses:
   - Tombol "Buat kata" (PlusOutlined) untuk baris BELUM fulfilled dan
     belum dismissed.
   - Tetap ada Dismiss (role gate existing).
2. Klik "Buat kata" → navigate ke /words/create dengan query:
   ?from_miss=<ULID>&term=<encoded>&direction=lemma|translation
   (from_miss WAJIB; term/direction boleh di-derive ulang dari list item
   supaya form bisa prefill tanpa fetch ekstra).
3. CreateWordPage / MeaningFields (urutan makna WAJIB, selaras 12-api §6):
   Terjemahan Indonesia → Kelas kata → Definisi (+ tombol Ambil dari KBBI).
   - Baca query from_miss / term / direction.
   - Prefill:
     * direction=lemma → lemma = term; terjemahan kosong (user isi /
       KBBI).
     * direction=translation → terjemahan pertama = term; lemma kosong
       (user isi kata Sambas); KBBI prefill dari term.
   - KBBI: GET /api/v1/lemma-definitions/lookup (auth); apply mengisi
     definisi + word_class_id + translation_text (lemma KBBI).
   - Saat submit POST /api/v1/admin/words, sertakan
     search_miss_id: from_miss (kontrak 12-api).
   - Banner info di atas form: "Dari search miss: {term} ({label arah})".
   - Setelah sukses: message.success + optional redirect detail kata;
     invalidate queryKey ['search-misses'] (kalau published, miss
     fulfilled di list).
4. Antrean /contributions (DELTA kecil):
   - Kolom atau Tag "Search miss" bila search_miss_id != null
     (tampilkan search_miss_term).
   - Detail review: blok sumber miss (term + direction) bila ada.

FILE (perkiraan):
- src/features/search-miss/presentation/search-misses-page.tsx
  # UBAH: kolom aksi + tombol Buat kata
- src/features/words/presentation/create-word-page.tsx
  # UBAH: baca search params, prefill, banner, body search_miss_id
- src/features/words/presentation/word-form-blocks.tsx
  # UBAH: urutan makna + KBBI picker (MeaningFields)
- src/features/words/domain/create-word.ts (+ buildCreateWordBody)
  # UBAH: field searchMissId opsional di request
- src/features/words/infrastructure/word-api.ts
  # UBAH: kirim search_miss_id bila ada
- src/features/contributions/…  # UBAH tipis: tampilkan sumber miss
- router: pastikan /words/create mempertahankan query string

TIDAK ADA endpoint admin baru selain yang di 12-api (reuse create word)
+ reuse lemma-definitions dari 13-api.

Command verifikasi: pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

---

## Catatan Implementasi

- Jangan duplikasi form create - satu CreateWordPage + query params.
- Role: semua yang boleh buka /words/create boleh "Buat kata"; dismiss
  tetap lebih ketat sesuai gate existing.
- Kalau miss sudah fulfilled saat user submit (race), API soft-check /
  create tetap boleh; list akan menampilkan fulfilled setelah refetch.
- Urutan field makna & KBBI: ikuti keputusan 12-api §6-7 (satu sumber
  kebenaran bersama mobile).
- **Merge lemma (12-api §8)**: beberapa usulan pending untuk lemma sama
  boleh. Saat Setujui / Tayang, jika sudah ada kata published dengan lemma
  sama → makna digabung ke kata yang sudah tayang (toast
  "makna digabung"), sumber soft-deleted. Bukan dua entri tayang.
