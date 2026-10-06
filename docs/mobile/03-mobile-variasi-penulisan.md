# Mobile - Variasi Penulisan pada Kontribusi Kata

Form usul kata (contribute) mendapat section opsional "Variasi
Penulisan": ejaan alternatif dari lemma yang diusulkan - mis. usul
**ketek** dengan variasi *ketex, kettek, kete'*. Penelusur yang
mengetik salah satu ejaan itu tetap menemukan kata induknya
(kontrak pencarian di `docs/api/11-api-variasi-penulisan.md`).

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):

- SUDAH ADA: fitur contribution mobile lengkap (3-layer, form
  contribute_page dengan mapping antarmuka datar → `meanings[]` di
  `ContributionRepositoryImpl`, DTO `CreateWordRequestDto`, error
  mapping VALIDATION_ERROR per field), endpoint
  `POST /api/v1/contributions/words` yang MENERIMA `variants[]`
  (anonWordSchema mewarisi createWordBodySchema), komponen Forui
  (FTextField, FLabel/FAlert, chips belum ada - pakai pola existing).
- Yang BELUM: field/UI variasi di form mobile, DTO `variants[]`,
  validasi client-side, label section.

KEPUTUSAN PRODUK (2026-09-19):

- Kontributor HANYA mengisi ejaan alternatif (teks) - TANPA UI tipe
  varian/afiks/dialek. Semua item dikirim sebagai
  `variant_type: 'alternative'`. Morfologi terstruktur (afiks dsb.)
  adalah ranah editor/admin di panel web, bukan form usul.
- Section opsional; tanpa variasi, body TIDAK mengirim field
  `variants` (undefined ≠ array kosong - sama pola dengan `notes`).
- Batas client: maksimal 10 variasi (server 20 - beri ruang koreksi
  verifikator).

NON-GOAL (eksplisit):

- TIDAK ada UI tipe varian/afiks/dialek/notes per variasi.
- TIDAK menampilkan variasi di halaman detail kata mobile pada
  iterasi ini (menyusul terpisah).

---

## Prompt

```text
Tambahkan section "Variasi Penulisan (opsional)" pada form usul kata
mobile. Ikuti pola fitur contribution existing (3-layer, HookConsumerWidget
/ ConsumerStatefulWidget, Forui, mapping antarmuka datar → DTO di
repository).

KONTEKS:
- Endpoint POST /api/v1/contributions/words menerima variants[]:
  [{ "form": "ketex", "variant_type": "alternative" }, ...] (docs 11).
- Validasi server: form ≠ lemma (case-insensitive), dedup
  (form, dialect), alternative tanpa afiks, max 20 - client memvalidasi
  dulang yang sama supaya user tidak menunggu 400.

STRUKTUR:
1. data/models/create_word_variant_dto.dart - BARU (freezed + codegen):
   CreateWordVariantDto { form: String, @JsonKey(name:'variant_type')
   @Default('alternative') String variantType }.
2. data/models/create_word_request_dto.dart - UBAH: field baru
   `@JsonKey(name: 'variants', includeIfNull: false)
   List<CreateWordVariantDto>? variants` (null = tidak dikirim).
3. domain: tambah field `List<String> spellingVariants` pada
   model/params antarmuka form (teks polos; transform ke DTO di
   repositoryImpl - preseden mapping meanings).
4. data/repositories/contribution_repository_impl.dart - UBAH:
   spellingVariants → variants DTO (map form: trim, variantType
   'alternative'); null/kosong → field tidak dikirim.
5. presentation/pages/contribute_page.dart - UBAH: section baru
   di bawah makna (sebelum catatan):
   - Label "Variasi Penulisan (opsional)" + helper text: "Ejaan lain
     untuk kata ini, mis. ketex, kettek, kete' untuk 'ketek'. Dipisah
     koma."
   - SATU FTextField multiline (paling sederhana dan akrab kontributor):
     user mengetik dipisah koma → parse split(',') map trim filter
     kosong. (Chips input menyusul bila dirasa perlu - jangan bangun
     sekarang.)
   - Validasi inline (list error di bawah field, pola _buildInlineError):
     item sama dengan lemma (case-insensitive) → error; duplikat item
     (case-insensitive) → error; lebih dari 10 → error. Semua pesan
     Indonesia, sebutkan item bermasalah.
   - Saat submit sukses/awal form reset: field ikut ter-reset.
6. Error mapping: VALIDATION_ERROR details field path `variants` /
   `variants.N.form` dari server → tampilkan sebagai error global
   section (FAlert) - tidak perlu mapping per-item.

TIDAK ADA: perubahan endpoint, router, provider baru (notifier cukup
operasikan field form existing), UI tipe varian/afiks.

Command verifikasi: dart run build_runner build --delete-conflicting-outputs
&& flutter analyze
```

## Catatan Implementasi

- `spellingVariants: List<String>` mengalir: page → notifier → use case
  (trim + buang kosong + dedup case-insensitive + buang yang sama
  dengan lemma - mirror backend) → repository map ke
  `CreateWordVariantDto(form, variant_type: 'alternative')`.
- DTO memakai `includeIfNull: false` (pola `notes`) - tanpa variasi,
  field tidak dikirim.
- UI: satu FTextField multiline dipisah koma + helper + error live
  (`_variantErrors`) yang juga menahan submit. Tidak ada chips input.
- `flutter analyze` bersih; 41/41 test lulus (fake repo test use case
  ditambah parameter `spellingVariants`).

## Referensi Terkait

- `docs/api/11-api-variasi-penulisan.md` - kontrak API variasi
  penulisan (validasi, pencarian lintas varian).
- `docs/api/01-api-tambah-kata.md` - semantik word_variants.
- `docs/api/03-api-kontribusi-verifikasi.md` - alur approval kontribusi
  (variants ikut status anak saat approve/reject).
- `docs/mobile/mobile-base-stack.md` - Section 5 (pola fitur lengkap),
  pola form + error.
