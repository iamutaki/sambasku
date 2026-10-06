# Mobile - Search Miss di Beranda → Kontribusi

Mengikuti `mobile-base-stack.md` (3 lapis + presentation, retrofit,
Riverpod, envelope). Kontrak API:

- List publik: `docs/api/03-api-kontribusi-verifikasi.md` § search-miss
- Provenance: `docs/api/12-api-search-miss-contribute.md`
- Assist definisi: `docs/api/13-api-kbbi-lemma-definition.md`

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):

- SUDAH ADA (API): `GET /api/v1/search-misses` item memakai field
  **`direction`** (bukan `search_in`); hanya miss `is_visible=true`
  (moderasi admin - lihat `14-api-search-miss-moderation.md`);
  `POST /contributions/words`; `GET /lemma-definitions/lookup` (auth).
- **Kontrak tampil beranda**: mobile HANYA consume endpoint publik di
  atas. Jangan panggil `/admin/search-misses`. Jangan tampilkan miss
  yang belum diizinkan tayang - server sudah memfilter; client cukup
  render `data[]` apa adanya.
- SUDAH ADA (mobile, sebagian): fitur `features/search_miss` (DTO/
  repo/use case); banner `_SearchMissBanner` di `HomeSearchPage`;
  `ContributePage(initialLemma, initialSearchIn)`; route
  `/contribute?lemma=&search_in=`; form makna urutan
  Terjemahan → Kelas kata (bottom sheet) → Definisi (+ KBBI).
- BUG/GAP (sudah diperbaiki): DTO memetakan `@JsonKey(name: 'direction')`;
  submit membawa `search_miss_id` via query `miss_id`. Empty-state
  "Usul Kata Ini" dari query pencarian sendiri tetap boleh tanpa miss id.

---

## Prompt

```text
Rapikan jalur search-miss di mobile: beranda menampilkan miss, tap
kartu → form kontribusi ter-prefill, submit membawa search_miss_id.

PERBAIKAN MAPPING (WAJIB dulu):
1. SearchMissDto + SearchMiss entity: ganti JsonKey 'search_in' →
   'direction' (atau @JsonKey(name: 'direction') dengan field Dart
   searchIn / direction konsisten). Regenerasi freezed/json.
2. Repository: pastikan entity.searchIn (atau direction) terisi dari
   response direction.
3. Tambah field isFulfilled opsional di DTO jika ingin mirror API;
   list publik selalu false - boleh diabaikan.

ROUTER / FORM:
4. ContributionRouter: baca query miss_id (atau search_miss_id):
   /contribute?lemma=&search_in=&miss_id=<ULID>
5. ContributePage: terima initialSearchMissId; initPrefill tetap;
   CreateWordRequestDto + repository submitAnon menambahkan
   @JsonKey(name: 'search_miss_id') String? searchMissId.
6. _BannerCard: push query menyertakan miss_id: item.id selain
   lemma + search_in (map direction → search_in di query UI).
7. Urutan field makna (WAJIB, 12-api §6) - sudah / pertahankan:
   Terjemahan Indonesia → Kelas kata (bottom sheet) → Definisi + KBBI.
   Prefill search_in=translation → isi terjemahan = lemma query;
   search_in=lemma → isi lemma Sambas. KBBI auth: lookup 13-api;
   apply → definisi + kelas kata + terjemahan (lemma KBBI).

UX BERANDA (pertahankan pola banner horizontal):
8. Kartu "Sedang Dicari Warga Lain" tetap; CTA "Ayo Kontribusi".
9. Gagal load miss → banner disembunyikan (sudah); jangan blokir search.
10. Setelah submit sukses dari jalur miss: pop back + invalidate
    provider list miss (refetch); toast sukses existing.

TESTING:
- test DTO: fixture JSON dengan "direction" (bukan search_in) → parse OK
- test use case / repo mapping
- widget/golden opsional - tidak wajib
Fixture: selaraskan test/fixtures dengan docs/json/search-miss/

Command verifikasi: flutter analyze && flutter test
```

---

## Catatan Implementasi

- Nama di **API wire** = `direction`; nama di **query go_router UI** boleh
  tetap `search_in` agar ContributePage lama tidak pecah - mapping hanya
  di boundary (DTO ↔ entity ↔ query).
- Soft-check server (12-api): pastikan prefill lemma/translation sesuai
  direction sebelum submit supaya tidak kena SEARCH_MISS_TERM_MISMATCH.
- Jangan panggil endpoint admin dari mobile.
- Empty-state search (query user sendiri 0 hasil) tetap boleh usul tanpa
  `miss_id`; pencatatan miss tetap di backend saat search - kartu akan
  muncul untuk user lain setelah hit tercatat.
- Urutan field makna & KBBI: ikuti keputusan 12-api §6-7 (satu sumber
  kebenaran bersama admin).
