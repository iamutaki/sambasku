# Wilayah: Peta Kecamatan dan Desa

Pengguna Sambas belum punya cara untuk menjelajahi wilayah Kabupaten Sambas dari
dalam app. Yang ada hari ini: daftar wisata dan kuliner (places.json,
cuisines.json) yang datanya berorientasi tempat, bukan wilayah. Warga tidak
bisa menjawab pertanyaan dasar seperti "aja ada di Kecamatan Sajad?" atau "desa
aja masuk kecamatan mana?" tanpa buka Google Maps.

Fitur Wilayah mengisi kategori "Wilayah" di tab Eksplorasi: peta Sambas dengan
polygon 19 kecamatan yang bisa diketuk. Ketuk satu area, panel bawah menampilkan
nama kecamatan, jumlah desa, dan tombol "Lihat desa" untuk membuka daftar
desa di dalamnya. Polygon di-bundle sebagai asset app (offline aman), daftar
wilayah dan desa di-fetch dari CDN repo data dengan pola cache yang sama
seperti places.json.

## Metrik Sukses

- Kategori Wilayah dibuka pada minimal 10% sesi Eksplorasi dalam 30 hari
  pertama setelah rilis (Firebase Analytics, event existing
  `explore_category_open` dengan kategori `wilayah`).
- Minimal 30% sesi yang membuka Wilayah melakukan minimal satu ketukan
  kecamatan (interaksi peta berfungsi).
- Daftar desa termuat pada minimal 90% ketukan kecamatan (failure = CDN
  error; dipantau lewat tingkat null provider `regions`).

## Scope

- Halaman `WilayahPage` di fitur explore mobile: peta MapLibre dengan layer
  fill polygon 19 kecamatan, ketuk area untuk memilih, panel bawah dengan
  nama + jumlah desa + tombol lihat daftar desa.
- Data baru di repo `data/`: `regions.json` (19 kecamatan + 195 desa, id dan
  centroid) dan `regions.geojson` (polygon kecamatan, disederhanakan ke
  sekitar 21 KB).
- Asset `assets/data/regions.geojson` di mobile (dari file di atas), supaya
  peta area tetap tampil tanpa internet.
- Aktifkan kategori `wilayah` di Eksplorasi (hapus coming soon).

## Anti-Goal

- Bukan polygon per desa (berat, tidak perlu untuk iterasi ini; desa cukup
  daftar teks).
- Bukan pencarian kecamatan/desa, statistik BPS (penduduk, luas), atau berita
  per wilayah.
- Bukan halaman detail per kecamatan (panel bawah saja di iterasi ini).
- Bukan paritas web/console; keduanya menyusul setelah pola mobile stabil.
- Bukan penghitungan konten (wisata/kuliner) per kecamatan; menunggu kolom
  `regionId` di places/cuisines data.

## Kontrak API / Data Model

Tidak ada endpoint API baru. Sumber data statis via CDN repo `data`, pola
sama dengan `places.json`:

- `GET https://cdn.jsdelivr.net/gh/sambasku/data@main/regions.json`
  - `regions: [{id, name, type: "kecamatan"|"desa", parentId?, lat?, lng?, code?}]`
  - `id` kecamatan = slug; `id` desa = `<slug-kecamatan>/<slug-desa>`;
    `parentId` desa = slug kecamatan induknya; `lat`/`lng` hanya kecamatan;
    `code` (opsional) = kode BPS 10-digit, hanya di desa.
- `assets/data/regions.geojson` (mobile): FeatureCollection, per feature
  `properties: {id, name, type: "kecamatan"}`, geometry Polygon atau
  MultiPolygon (ring tersederhanakan).

Error code: tidak ada (read-only statis). Kontrak aplikasi: gagal fetch
regions.json = null (soft-fail), UI menampilkan empty state dan tombol muat
ulang; asset geojson korup = peta tetap jalan tanpa polygon.

## Keamanan

- Tanpa auth: data publik, read-only, tidak ada input user ke trust boundary
  (satu-satunya interaksi adalah tap koordinat yang dihitung lokal).
- Rate limit: tidak relevan (CDN statis; pola cache referenceStatic 24 jam +
  SWR sudah menahan frekuensi fetch).
- Validasi: parse DTO defensif - field wajib absen berarti item di-skip, satu
  entri rusak tidak mematikan daftar (pola `place_dto.dart`).
- Data sensitif: tidak ada; hanya nama wilayah dan koordinat centroid.

## Lintas Platform

| Platform | Status | Catatan |
|----------|--------|---------|
| Mobile | Iterasi ini | Seluruh scope di atas. |
| Web | Menyusul | Reuse `regions.json` + `regions.geojson` dari CDN; belum ada. |
| Console | Tidak direncanakan | Tidak ada moderasi data wilayah (statis). |

Copywriting mengikuti AGENTS.md Section 22: bahasa Indonesia santai, sapaan
"kamu", tanpa em/en dash (contoh: "Ketuk salah satu area kecamatan untuk
melihat desa di dalamnya."). i18n: string UI saat ini hardcode bahasa
Indonesia, konsisten dengan halaman explore existing.

## Prompt Pengembangan

Sudah dieksekusi di iterasi ini (branch `staging` repo `mobile`):

1. `regions_dto.dart` + `regions_remote_datasource.dart` + repository +
   provider (codegen) - pola identik places; test di
   `test/features/explore/regions_dto_test.dart` dan
   `regions_repository_test.dart`.
2. `region_geometry.dart` - parse ring + ray casting; test
   `region_geometry_test.dart` memverifikasi 19 polygon dan centroid.
3. `wilayah_page.dart` - peta + panel; wiring di
   `explore_category_page.dart` dan `explore_category.dart`.
4. Verifikasi: `dart analyze` bersih, `flutter test test/features/explore/`
   43/43 hijau.

Prompt lanjutan (web/console): ikuti pola halaman wisata web, render geojson
dengan MapLibre web, kontrak data sama persis.

## Referensi

- `docs/USER_BUSINESS_ANALYST.md` - metodologi dan DoR gate.
- `docs/mobile/mobile-base-stack.md` - base stack mobile.
- `data/regions.json`, `data/regions.geojson` - sumber data (geoBoundaries
  gbHumanitarian IDN ADM3, CC BY 3.0 IGO; DPMD Sambas artikel 36; BPS 2025).
- `mobile/lib/features/explore/data/models/regions_dto.dart` - DTO.
- `mobile/lib/features/explore/presentation/pages/wilayah_page.dart` -
  halaman.
