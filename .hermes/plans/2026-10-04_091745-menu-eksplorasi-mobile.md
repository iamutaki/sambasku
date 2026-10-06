# Plan: Menu Eksplorasi Mobile — Kategori Baru Berbasis Data yang Sudah Ada

## Goal

Mengisi 1 kategori "coming soon" di tab Eksplorasi mobile dengan konten nyata berbasis data yang SUDAH tersedia hari ini (tanpa API baru, tanpa repo data baru), plus perbaiki 1 bug data wisata web.

## Current context / asumsi

- Repo: `mobile/` (Flutter, go_router + Riverpod + forui), branch kerja: `staging`. Superroot `sambasku/`.
- Tab Eksplorasi = `mobile/lib/features/explore/domain/explore_category.dart` — 10 kategori, 3 aktif (`wisata-kuliner`, `bahasa-budaya`, `peta-akses`), 7 `comingSoon: true`.
- Kandidat kategori lain yang Tuan minta ("cari yg lainnya") sudah kusaring berdasarkan ketersediaan data NYATA:

| Kategori coming soon | Sumber data hari ini | Layak? |
|---|---|---|
| `sejarah-tokoh` | `places.json` ada 2 situs sejarah (Istana Alwatzikoebillah, dst.) + `kuliner.json` 1 entri ber-sources | BISA, murah |
| `kabar-berita` | Tidak ada (RSS web = feed kamus sendiri, bukan berita daerah) | TIDAK |
| `event-acara` | Tidak ada | TIDAK |
| `bisnis-jasa` | Tidak ada | TIDAK |
| `seni-kerajinan` | Tidak ada | TIDAK |
| `tradisi-adat` | API kategori "Adat & Tradisi" ADA tapi `/api/v1/words` TIDAK mendukung filter category (validator `listWordsQuerySchema` di `api/src/modules/word/presentation/v1/validators/create-word.validator.ts:666` cuma punya q/letter/limit/cursor/word_type/is_verified) | TUNDA (butuh API) |
| `komunitas` | `contributor.json` ADA (peran + since) tapi itu tim proyek, bukan komunitas | TIDAK |

- Data yang SUDAH ada dan belum dimanfaatkan penuh:
  - API `GET /api/v1/words/today` (kata hari ini) — live, terverifikasi.
  - API `GET /api/v1/words?word_type=peribahasa|ungkapan|idiom` — didukung validator HARI INI. Isi sekarang: peribahasa 3, ungkapan 3, idiom 0 (korpus kecil tapi valid, kosong = empty state).
  - `places.json` (root repo `data`, 2 tempat sejarah) + `kuliner.json` (1 entri Bubur Pedas + bahan + sources).
- BUG terkait: web `app/application/use-cases/place.use-case.ts:6` pakai URL `data@main/mobile/explore/places.json` → **404** (file aslinya di root `data@main/places.json`). `/wisata` web pasti error 502 sekarang. (Ditemukan saat riset plan ini.)

## Architecture / proposed approach

Dua deliverable independen, urut dampak:

1. **Mobile — aktifkan kategori `sejarah-tokoh`** jadi halaman daftar tempat bertipe `sejarah` + entri kuliner ber-sumber sejarah, reuse provider `places` yang sudah ada (filter `type == 'sejarah'`), plus sub-bagian "Kuliner & tradisi" dari `kuliner.json`. Perlu datasource `kuliner.json` baru (pola identik `places_remote_datasource.dart`).
2. **Mobile — upgrade `bahasa-budaya`** dari "bridge card" jadi halaman bertab: Peribahasa / Ungkapan (fetch `word_type`), pakai `DictionaryRemoteDatasource.listWords` yang sudah ada. Tab kosong = empty state sopan, bukan error.
3. **Web — hotfix 1 baris** URL places.json (bug 404 di atas), langsung di `staging` web.

YAGNI: kategori tanpa sumber data (`kabar-berita`, `event-acara`, `bisnis-jasa`, `seni-kerajinan`, `komunitas`, `tradisi-adat`) TETAP coming soon. Tidak buat API baru, tidak buat repo data baru.

## Step-by-step tasks

Semua task mobile di repo `/Users/ibnulmutaki/Development/github/sambasku/mobile`, branch `staging` (sesuai konvensi baru: tidak buat branch baru). Commit per task.

### Task 0 (web, hotfix duluan — 2 menit)

File: `web/app/application/use-cases/place.use-case.ts` (repo `web/`, branch `staging`).

Ganti baris 6:
```ts
const PLACES_URL =
  'https://cdn.jsdelivr.net/gh/sambasku/data@main/mobile/explore/places.json';
```
menjadi:
```ts
const PLACES_URL =
  'https://cdn.jsdelivr.net/gh/sambasku/data@main/places.json';
```

Verifikasi:
```bash
cd /Users/ibnulmutaki/Development/github/sambasku/web
curl -s -o /dev/null -w '%{http_code}\n' https://cdn.jsdelivr.net/gh/sambasku/data@main/places.json   # 200
npm test    # expect: pass 81, fail 0
git add app/application/use-cases/place.use-case.ts
git commit -m "fix(wisata): URL places.json 404 - pindah ke root repo data"
git push origin staging
```

### Task 1 — Mobile: model + datasource `kuliner.json` (TDD, merah dulu)

File baru: `mobile/lib/features/explore/data/models/kuliner_dto.dart`
File baru: `mobile/lib/features/explore/data/datasources/kuliner_remote_datasource.dart`
File test baru: `mobile/test/features/explore/kuliner_dto_test.dart`

Shape `kuliner.json` (sudah diverifikasi live):
```json
{ "version": 1, "license": "CC BY-SA 4.0", "kuliner": [
  { "id": "bubur-pedas-sambas", "slug": "bubur-pedas-sambas", "name": "Bubur Pedas Sambas",
    "description": "...", "images": [...], "ingredients": [...], "sources": [...] } ] }
```

Test dulu (pola ikuti `mobile/test/features/explore/place_dto_test.dart`):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sambasku/features/explore/data/models/kuliner_dto.dart';

void main() {
  test('parse entri lengkap', () {
    final dto = KulinerDto.fromJson({
      'id': 'bubur-pedas-sambas',
      'slug': 'bubur-pedas-sambas',
      'name': 'Bubur Pedas Sambas',
      'description': 'Bubur kental beras.',
      'images': <Map<String, dynamic>>[],
      'ingredients': <Map<String, dynamic>>[],
      'sources': <Map<String, dynamic>>[],
    });
    expect(dto, isNotNull);
    expect(dto!.name, 'Bubur Pedas Sambas');
  });

  test('field wajib absen → null (skip item)', () {
    expect(KulinerDto.fromJson({'name': 'tanpa id'}), isNull);
  });

  test('kuliner list wrapper', () {
    final list = KulinerListDto.fromJson({
      'version': 1,
      'kuliner': [
        {'id': 'a', 'slug': 'a', 'name': 'A', 'description': 'd'},
      ],
    });
    expect(list.items, hasLength(1));
  });
}
```

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/mobile
flutter test test/features/explore/kuliner_dto_test.dart
# EXPECT FAIL: Error: Couldn't read file ... kuliner_dto.dart (belum ada) — ini fase RED
```

Lalu implement minimal `kuliner_dto.dart` (defensif per field wajib, pola `place_dto.dart`: `fromJson` return `KulinerDto?`, null = skip):
- `id`, `slug`, `name`, `description` (wajib string non-kosong)
- `images: List<PlaceImage>` (reuse dari `place_dto.dart`)
- `ingredients: List<String>` (toleran: string atau `{name}`)
- `sources: List<PlaceSource>` (reuse)

Datasource (copy `places_remote_datasource.dart`, ganti URL + parse):
```dart
const kKulinerUrl =
    'https://cdn.jsdelivr.net/gh/sambasku/data@main/kuliner.json';
```

```bash
flutter test test/features/explore/kuliner_dto_test.dart
# EXPECT PASS: All tests passed!
git add lib/features/explore/data/models/kuliner_dto.dart \
        lib/features/explore/data/datasources/kuliner_remote_datasource.dart \
        test/features/explore/kuliner_dto_test.dart
git commit -m "feat(explore): model + datasource kuliner.json (sejarah-tokoh)"
```

### Task 2 — Mobile: repository + provider kuliner

File baru: `mobile/lib/features/explore/data/repositories/kuliner_repository_impl.dart`
File baru: `mobile/lib/features/explore/presentation/providers/kuliner_providers.dart` (+ jalankan codegen)
File baru: `mobile/test/features/explore/kuliner_repository_test.dart` (soft-fail: JSON rusak → null)

Copy pola `places_repository_impl.dart` + `places_providers.dart` persis (cache envelope `cachedJsonClientProvider`, `referenceStatic` fresh 24 jam + SWR).

```bash
dart run build_runner build --delete-conflicting-outputs   # generate .g.dart
flutter test test/features/explore/kuliner_repository_test.dart   # PASS
git add -A && git commit -m "feat(explore): repository + provider kuliner"
```

### Task 3 — Mobile: aktifkan kategori `sejarah-tokoh`

File: `mobile/lib/features/explore/domain/explore_category.dart` — tambah `comingSoon: false` di entri `sejarah-tokoh`.

File: `mobile/lib/features/explore/presentation/pages/explore_category_page.dart` — di `build()`, tambah cabang:
```dart
final isSejarahTokoh = categoryId == 'sejarah-tokoh';
// ...
child: isPetaAkses
    ? const _PetaAksesMap()
    : isSejarahTokoh
        ? const SejarahTokohPage()
        : isBahasaBudaya ? ... // urutan cabang eksisting dipertahankan
```

File baru: `mobile/lib/features/explore/presentation/pages/sejarah_tokoh_page.dart`
- Bagian 1 "Situs sejarah": `ref.watch(placesProvider)` filter `p.type == PlaceType.sejarah`, render pakai komponen row `place_ui.dart` yang sudah ada (konsisten visual).
- Bagian 2 "Kuliner tradisional": `ref.watch(kulinerProvider)` — card nama + deskripsi + link sumber.
- Empty state masing-masing: teks "Belum ada data, nanti ditambahkan ya" (pola teks di `place_list_page.dart`).

Verifikasi:
```bash
flutter analyze   # expect: No issues found!
flutter test test/features/explore/   # semua PASS
git add -A && git commit -m "feat(explore): aktifkan kategori Sejarah & Tokoh (situs sejarah + kuliner tradisional)"
```

### Task 4 — Mobile: upgrade `bahasa-budaya` jadi halaman Peribahasa/Ungkapan

File: `mobile/lib/features/explore/presentation/pages/explore_category_page.dart` — ganti `_BahasaBudayaBridge` dengan halaman bertab.

File baru: `mobile/lib/features/explore/presentation/pages/bahasa_budaya_page.dart`
- 2 tab: "Peribahasa" (`word_type=peribahasa`), "Ungkapan" (`word_type=ungkapan`).
- Fetch: `ref.watch(dictionaryRemoteDatasourceProvider)` → `listWords({'word_type': ..., 'limit': 50})` (datasource sudah ada di `lib/features/dictionary/`, TANPA perubahan API).
- Row: lemma + sense (potong `[umum] ` prefix) → tap push `DictionaryRouter.detail` path yang sudah ada.
- Header tetap "Kamus hidup Sambas" + tombol "Buka daftar kata A-Z" di bawah (pertahankan bridge lama sebagai footer).
- Korpus kosong (0 item): teks "Belum ada peribahasa terverifikasi. Ikut menyumbang di kontribusi." + tombol ke `/kontribusi`.

```bash
flutter analyze
flutter test
git add -A && git commit -m "feat(explore): bahasa-budaya jadi daftar peribahasa & ungkapan (API word_type)"
```

### Task 5 — Push + verifikasi CI

```bash
cd mobile && git push origin staging
cd ../web && git push origin staging   # kalau task 0 belum
gh pr list --repo sambasku/mobile --state open   # pastikan tak ada PR liar
```

Sesuai workflow: push langsung ke `staging` (Tuan review di staging, bukan PR — konvensi Okt 2026).

## Tests / validation

- Task 1: TDD penuh — test merah (file belum ada) → implement → hijau.
- Task 2: test repository soft-fail (body bukan map / list kosong → null, tidak throw).
- Task 3-4: `flutter analyze` bersih + `flutter test` semua hijau + smoke manual (lihat Risk #3).
- Task 0: `npm test` web 81/81 (test wisata yang ada tetap hijau karena mock, bukan fetch live).

## Risks, tradeoffs, and open questions

1. **Korpus kecil** (peribahasa 3, ungkapan 3): halaman terlihat sepi. Mitigasi: empty state + CTA kontribusi. Tradeoff diterima — konten tumbuh via kontribusi.
2. **`sejarah-tokoh` isi campuran** (situs + kuliner): nama kategori "Sejarah & Tokoh" tapi konten kuliner? Alasan: kuliner Bubur Pedas punya narasi sejarah + sources. Kalau dirasa lempang, ganti judul jadi "Sejarah & Warisan". Keputusan di Tuan.
3. **`word_type` di query list** — validator API menerima tapi apakah repository API benar-benar memfilter (bukan di-validate lalu diabaikan)? Sudah kuverifikasi via curl: `?word_type=peribahasa` balas 3 peribahasa (bukan semua kata) → filter AKTIF.
4. **Tidak ada widget test untuk halaman baru** — halaman full UI; test fokus di DTO/repository (logika). UI diverifikasi smoke manual.
5. **`tradisi-adat`**: paling layak berikutnya tapi butuh API filter `category_id` di `/words` (issue API terpisah). Tidak masuk plan ini (YAGNI, tunggu minta).
6. Tradisi robohnya struktur: Task 3-4 menyentuh `explore_category_page.dart` yang sama — kerjakan berurutan, commit terpisah.
