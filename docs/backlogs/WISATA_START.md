# WISATA_START - Katalog Place untuk Wisata & Kuliner

Backlog eksekusi part wisata. Setelah implementasi selesai, dokumen ini
diperbarui (status, catatan penyimpangan) - tidak dihapus.

Dokumen terkait:

- [`docs/ROADMAP_PLAN.md`](../ROADMAP_PLAN.md) - V2 Peta + POI, V3 Wisata & Kuliner
- [`docs/PLAN_MOCK.md`](../PLAN_MOCK.md) - kontrak skema Place (Section F)
- [`docs/backlogs/BEGAYAU.md`](./BEGAYAU.md) - F0 butuh katalog Place hidup
- Mobile Explore scaffold: `mobile/lib/features/explore/`

---

## Keputusan (tetap sampai diganti di file ini)

1. **Satu dataset Place.** Wisata + kuliner + nanti budaya/akses/UMKM
   berlokasi = satu koleksi `places.json`, dibedakan `category`. Kontrak
   dari `PLAN_MOCK.md` Section F (`Place { category: wisata|kuliner|... }`).
2. **Sumber data: CDN statis, tanpa backend.** JSON di repo `data`
   (`data/mobile/explore/places.json`), disajikan jsDelivr, dibaca mobile
   lewat pola `card_images` yang sudah live (`CachedJsonClient`, SWR
   24 jam, soft-fail null). Konten update tanpa rilis app.
3. **Wisata bertipe.** Field `type` untuk `category: wisata`:
   `sejarah | alam | budaya | pantai | belanja`. Kuliner `type: null`.
4. **Relasi generik sejak v1.** Field `related[]`
   (`kind: place|word|article|event|umkm`):
   - sekarang terisi `word` (lemma kamus) dan `place` ("Dekat sini");
   - `article/event/umkm` parser di-skip dulu, hidup otomatis saat
     V1/V4/V5 ship tanpa refactor data lama;
   - `relatedWordIds` tetap ada sebagai shortcut lemma.
5. **Event bukan Place.** V4 nanti jadi `events.json` sendiri (punya
   tanggal + venue). Relasi dua arah via `related[]`:
   `event.related = [{kind: "place", id: ...}]` (venue),
   `place.related = [{kind: "event", id: ...}]` (acara di sini).
6. **Favorit count Place ditunda.** Bookmark eksisting hanya untuk kata
   (`user_id + word_id`, schema DB v1 terkunci). Count favorit butuh
   modul API `place` baru - dibangun bareng Begayau F0 / kemitraan
   Dinas (roadmap Q3+). UI detail menyiapkan slot, tidak tampil angka.
7. **Kabar & Berita bukan koleksi konten.** README org: "SambasKu bukan
   situs berita daerah"; roadmap: "Bukan portal berita". Pengumuman
   mitra nanti lewat inbox `notification-campaign` yang sudah ada,
   bukan file JSON baru.
8. **Koleksi indukan Eksplorasi akhirnya 3** (+1): `places.json`,
   `articles.json` (4 kategori budaya, dibedakan `category`),
   `events.json` (V4), `listings.json` (UMKM, V5, skema di lampiran
   bawah). Semua satu pola CDN + parser per koleksi.
9. **Gambar Place ditunda** tapi slot siap: `images[]`
   (`{url, isMain}`) di parser, kosong di seed awal. File di repo
   `images` (konvensi `<ulid>.<ext>`), URL jsDelivr.

---

## Skema places.json (v1)

Lokasi: `data/mobile/explore/places.json` di repo `data` (branch main).

```json
{
  "version": 1,
  "places": [
    {
      "id": "01JC0Z3M9QWERTYUIOPASDFGHJ",
      "slug": "masjid-sultan-syarif-abdulrahman",
      "name": "Masjid Sultan Syarif Abdulrahman",
      "category": "wisata",
      "type": "sejarah",
      "lat": 1.3621, "lng": 109.3172,
      "shortDescription": "Masjid bersejarah pusat kota Sambas.",
      "images": [],
      "hours": null, "contact": null,
      "relatedWordIds": [],
      "related": [ { "kind": "place", "id": "01JC0ZAAAAQWERTYUIOPASDFGHJ" } ]
    },
    {
      "id": "01JC0ZBBBBQWERTYUIOPASDFGHJ",
      "slug": "gula-kelapa-ponco",
      "name": "Gula Kelapa Ponco",
      "category": "kuliner",
      "type": null,
      "lat": 1.3601, "lng": 109.3122,
      "shortDescription": "Gula kelapa asli khas Sambas.",
      "images": [], "hours": null, "contact": null,
      "relatedWordIds": [], "related": []
    }
  ]
}
```

Aturan:

- `id` ULID (Crockford base32, 26 karakter) - PK siap pakai saat
  konten naik ke DB; migrasi JSON → tabel tidak perlu memikirkan
  ulang identitas. `related[].id` menunjuk `id` target (place = ULID,
  word = id kata di API).
- `slug` unik, khusus URL routing; `category`: `wisata | kuliner` (v1).
- `type` hanya untuk wisata; kuliner `null`.
- `related[].kind` tidak dikenal = di-skip parser, bukan gagal semua.
- `images[]` opsional, kosong di seed awal. Entry:
  `{ "url": "<jsDelivr>", "isMain": true }` - tepat satu `isMain: true`
  per Place (tanpa true = elemen pertama dianggap main; lebih dari satu
  = true pertama yang menang). Main = cover list/peta; sisanya carousel
  detail. Kosong = placeholder. File ditaruh di repo `images`
  (`assets/places/<ulid>.<ext>`, konvensi repo images: nama file ULID
  immutable, jpg/png/webp, max 5 MB), URL jsDelivr absolute, client
  bungkus `wsrv.nl` via `displayImageUrl`. Ganti gambar = file ULID
  baru (jangan rename file lama, URL CDN akan putus). Pattern ini juga
  selaras dengan `is_primary` gambar kata yang sudah ada di API.
- Contoh dengan gambar (main + carousel, satu foto open data dengan
  kredit, satu foto sendiri):

```json
"images": [
  {
    "url": "https://cdn.jsdelivr.net/gh/sambasku/images@main/assets/places/01JC0ZIMG1QWERTYUIOPASDFGHJ.webp",
    "isMain": true,
    "attribution": {
      "name": "Ada Lovelace",
      "provider": "openverse",
      "url": "https://www.flickr.com/photos/ada/1",
      "license": "CC BY 2.0",
      "license_url": "https://creativecommons.org/licenses/by/2.0/",
      "source": "flickr"
    }
  },
  {
    "url": "https://cdn.jsdelivr.net/gh/sambasku/images@main/assets/places/01JC0ZIMG2QWERTYUIOPASDFGHJ.webp",
    "isMain": false
  }
]
```

- **Atribusi data (wajib bila dari sumber terbuka).** Field `sources[]`
  di level Place - pola `support_*` yang sudah ada di kamus:

```json
"sources": [
  {
    "name": "Dinas Pariwisata Kabupaten Sambas",
    "type": "web",
    "address": "https://sambaskab.go.id/pariwisata/destinasi",
    "license": "CC BY 4.0",
    "licenseUrl": "https://creativecommons.org/licenses/by/4.0/"
  }
]
```

  - `type`: `web | book | article | other` (sama dengan support_type
    import session). `license`/`licenseUrl` opsional, diisi bila
    sumbernya open data berlisensi (CC BY dll). Aturan lengkap gerbang
    lisensi: bagian "Open data gate" bawah.
  - Per aturan lisensi CC: kredit tampil di UI. Detail Place punya
    section "Sumber" (nama sumber + link); teks ringkas
    "Sumber: {name}" di bawah deskripsi bila license CC terisi.
    Bila foto/data dimodifikasi dan lisensinya mensyaratkan catatan
    perubahan, UI menambahkan "diubah" (flag `modified: true` di
    entry; lihat Open data gate).
  - **Atribusi foto wajib tampil di gambar.** Ekosistem open source =
    setiap foto open data harus berkredit. Entry `images[]` pakai
    field `attribution` yang **sama persis** dengan model
    `ImageAttribution` mobile (`core/models/image_attribution.dart`):
    `{name, provider, url?, license?, licenseUrl?, source?}` - JSON
    pakai snake_case (`license_url`) supaya parser `fromJson` existing
    bisa dipakai langsung. Render: widget `ImageCredit`
    (`shared/widgets/image_credit.dart`) yang sudah ada - overlay di
    carousel detail (pola `image_preview.dart`: chip putih di pojok)
    dan caption kecil di bawah cover list. Unsplash otomatis ber-UTM,
    CC tampil dengan link lisensi. Tanpa `attribution` = foto
    milik sendiri / tidak perlu kredit.
  - `sources: []` = konten internal/editorial (tidak wajib menampilkan
    apa pun).
  - Saat naik ke DB: kolom `sources` JSON di tabel places, satu pola
    dengan `attribution` gambar.
- Item JSON rusak = skip item itu (bukan gagal semua koleksi).
- Koordinat rentang Sambas (lat 1.2-1.6, lng 108.9-109.6).
- Seed awal: 8 destinasi + 10 kuliner. Geografi nyata Sambas (kota
  Sambas, Pemangkat, Selakau, Paloh, Teluk Keramat); nama usaha fiktif
  sampai konten resmi ada. `relatedWordIds` hanya ID kata published.
  Seed nyata wajib ikut aturan "Open data gate": tempat usaha pribadi
  tanpa kontak pribadi, nama lewat tinjauan lokal, sumber eksternal
  lolos gerbang lisensi (checklist 6 poin di bagian itu).

---

## Implementasi mobile (pola persis `card_images`)

Folder: `mobile/lib/features/explore/`

- `domain/entities/place.dart` - `PlaceCategory {wisata, kuliner}`,
  `PlaceType` (nullable), `RelatedKind {word, place}` (unknown skip),
  `PlaceRelated {kind, id}`, `Place {...}`.
- `data/models/place_dto.dart` - parse defensif per aturan atas.
- `data/datasources/places_remote_datasource.dart` - fetch
  `https://cdn.jsdelivr.net/gh/sambasku/data@main/mobile/explore/places.json`,
  timeout 5s.
- `data/repositories/places_repository_impl.dart` - `CachedJsonClient`,
  `CacheClass.referenceStatic`, cache key `/cdn/mobile/explore/places.json`,
  error apa pun → null.
- `presentation/providers/places_providers.dart` - `@riverpod Future<List<Place>?> places` + datasource/repository, build_runner.
- `presentation/pages/place_list_page.dart` - filter chip kategori
  (Semua/Wisata/Kuliner); Wisata aktif → baris kedua type. Skeleton
  loading; gagal = FAlert + coba lagi; kosong = empty state.
- `presentation/pages/place_detail_page.dart` - **carousel `images[]`
  (`PageView` + indicator; entry `isMain: true` = cover; entry
  ber-`attribution` = overlay `ImageCredit`)**, badge
  kategori + type, deskripsi, jam/kontak, chip lemma, "Dekat sini"
  (related place), "Lihat di peta", section "Sumber" bila
  `sources[]` terisi (kredit lisensi CC wajib tampil). Slot favorit:
  belum tampil.
- `presentation/widgets/sambas_map_pins.dart` - bungkus `SambasMapView`,
  sukses → `addSymbols` + `onSymbolTapped` → detail; gagal → peta polos
  (poster fallback tetap).
- Wiring: `wisata-kuliner` → PlaceListPage, `comingSoon: false`,
  `peta-akses` → SambasMapPins, route `/explore/place/:slug` (URL pakai
  slug yang readable; identitas data tetap `id`)
  (push penuh, root navigator).
- Analytics: `logPoiOpen({slug, category, entry})`, entry `list | map`.
- Copy: Indonesia santai, sapaan kamu, max satu partikel, hyphen ASCII
  saja (tanpa em/en dash).

---

## Urutan kerja

1. Seed `places.json` di repo `data` + validasi koordinat/slug.
2. Lapisan data mobile (DTO → datasource → repository → provider).
3. UI (list → detail → pin peta) + wiring kategori + router.
4. Analytics + test + build_runner + `flutter analyze` + `flutter test`.

---

## Verifikasi

- Test `place_dto_test.dart`: parse valid, type wisata vs kuliner null,
  related unknown kind di-skip, item rusak di-skip, field opsional,
  `sources[]` + `images[].attribution` ter-parse.
- Test `explore_category_wisata_test.dart`: tap kartu Wisata & Kuliner
  membuka list (tanpa "Segera hadir").
- Sanity `places.json`: koordinat di rentang Sambas, `id` ULID valid
  dan unik, slug unik, `related[].id` menunjuk id/slug yang ada.

---

## Lampiran: Bisnis & Jasa (V5) - deskripsi produk

Posisi: **bukan toko, kartu nama digital yang bisa dipercaya** di dalam
ekosistem kamus. Kontrak: `PLAN_MOCK.md` C6 + `UmkmListing` Section F.

Isi listing (`listings.json`, pola CDN sama):

```json
{
  "slug": "anyaman-melayu-selakau",
  "businessName": "Anyaman Melayu Selakau",
  "category": "kerajinan",
  "description": "Kerajinan anyaman dari pengrajin Selakau.",
  "placeSlug": null,
  "contact": "wa.me/6281200000000",
  "hours": null,
  "claimStatus": "unclaimed",
  "highlight": "none",
  "lat": null, "lng": null,
  "related": [
    { "kind": "word", "id": "<lemma anyaman>" },
    { "kind": "place", "id": "pasar-terapung-selakau" }
  ]
}
```

Aturan produk:

- **Status klaim jujur**: `unclaimed` (usulan warga) → `pending` →
  `verified` (pemilik klaim; badge terverifikasi). Konsisten dengan
  status kamus "Menunggu pengecekan".
- **Highlight musiman terbatas** (`none | weekly | monthly`), kuota
  terlihat, tidak pernah memalsukan urutan organik (juga aturan
  Begayau F3).
- **Pin peta hanya listing terklaim.**
- **CTA satu-satunya: hubungi** (tel/WhatsApp, `url_launcher` sudah
  ada). Larangan eksplisit C6: keranjang, checkout, ongkir, chat
  wajib, escrow.
- **Relasi** via `related[]` yang sama dengan Place - parser mobile
  satu pola.
- Naik dari backlog saat gate V4→V5 roadmap terpuaskan (event curated
  jalan 1 musim; moderasi kuat).

---

## Lampiran: Kesan & Pesan (bukan rating bintang)

**Prinsip:** bintang 1-5 ala Google adalah anti-goal yang sudah
tercatat (`BEGAYAU.md`: "merusak trust"; rating rendah menghukum UMKM
kecil dan menumbuhkan kesan negatif). Yang dibangun: **kesan dan
pesan** - teks pengalaman berkunjung, tanpa angka, tanpa peringkat.

Bukan sistem penilaian; sistem **berbagi cerita**. Tidak ada
"2.3 dari 5", tidak ada sorting berdasarkan skor, tidak ada badge
buruk. Place tetap tampil setara.

Keputusan tetap (sampai diganti):

1. **Tanpa rating, tanpa rata-rata, tanpa bintang.** Field skor tidak
   pernah ada di skema. Sorting listing tetap organik (nama/jarak),
   TIDAK berdasarkan jumlah kesan.
2. **Teks terbatas & dimoderasi.** Max ~500 karakter, 1 kesan per user
   per Place (edit/hapus milik sendiri), lewat pipeline UGC yang
   sudah ada: `assert-ugc-text-quality` + abuse strike +
   `comment-blocklist-words`. Status: `pending_review` →
   `published` / `rejected` (pola kontribusi kamus).
3. **Tampil setelah moderasi.** Tamu bisa baca kesan published;
   menulis harus login (pola guest-first yang sama).
4. **Tanpa foto/attachment di v1.** Teks saja. Foto menyusul bila
   moderasi visual siap (sensor/blur seperti diskusi).
5. **Kesannya tentang pengalaman, bukan vonis.** Copy UI memandu:
   "Bagikan kesan kamu setelah berkunjung" - bukan "Seberapa bagus
   tempat ini?".
6. **Moderasi adil untuk UMKM kecil**: pemilik Place terklaim (V5)
   bisa melaporkan kesan yang melanggar (menuduh, SARA, spam) ke
   antrean review yang sama - bukan hapus langsung.

Skema (saat API place dibangun):

```text
place_impressions:
  id            varchar(26) ULID
  place_id      varchar(26) → places.id
  user_id       varchar(26) → users.id
  body          text (10-500, moderasi UGC)
  status        pending_review | published | rejected
  created_at, updated_at
```

Urutan naik: setelah modul API `place` ada (bareng favorit count -
sama-sama butuh backend). Mobile: UI di PlaceDetailPage (list kesan
published + form), pola komentar kata yang sudah ada.

---

## Lampiran: Video Place (jauh, slot disiapkan)

Kemungkinan video di Place disiapkan sebagai slot skema saja sekarang:

- `images[]` sengaja array objek (bukan array URL string) - naik ke
  `media[]` nanti cukup tambah `kind: image | video` + `durationSec?`
  tanpa refactor parser lama. Entry lama (`kind` absen) default image.
- Video = beban baru: hosting (repo `images` hanya gambar), transcode
  wsrv tidak melayani video, moderasi visual jauh lebih berat. Tidak
  ada pekerjaan video sebelum sumber konten video resmi ada (Dinas /
  mitra). Keputusan hosting saat itu (R2 / YouTube embed).

---

## Lampiran: Checkpoint (jauh - prasyarat lokasi foreground)

Ide: user menandai "pernah singgah di Place ini" (checkpoint) sebagai
jejak perjalanan pribadi. Tidak dibangun sekarang; catatan desainnya:

- **Prasyarat mutlak:** izin lokasi **foreground only** aktif oleh
  user. Tidak pernah ada background tracking / geofence selalu-on -
  selaras anti-goal Begayau ("wajib GPS background = privasi").
- **Bukan fitur baru yang berdiri sendiri**: checkpoint adalah
  perluasan alur Begayau F2 (nearby suggest, GPS sekali di foreground)
  → tombol "Tandai sudah singgah" di kartu konteks. Satu begayau
  aktif + checkpoint = jejak riwayat pribadi di profil (F2 "jejak
  pribadi, bukan feed publik").
- **Privasi**: checkpoint = data pribadi (private by default), tidak
  ada feed publik "orang lain sudah ke sini". Agregat hitungan boleh
  (pola Begayau `aggregate_only`).
- **Skema saat saatnya tiba** (pra-desain, boleh berubah):
  `place_checkpoints { id, user_id, place_id, visited_at, source:
  manual | foreground_suggest }` - unik `(user_id, place_id)`.
- Urutan: Begayau F1 (katalog Place hidup) → F2 (nearby suggest
  foreground) → checkpoint bila adopsi F2 sehat. Diputus di file
  BEGAYAU.md, bukan di sini.

---

## Open data gate - aturan wajib sebelum sumber eksternal pertama

Prinsip: SambasKu berdiri di ekosistem open source dan memakai data
terbuka. Aturan ini memastikan pemuatan data eksternal tidak membuat
data SambasKu bermasalah lisensi, tidak menyakiti pemilik usaha kecil,
dan tetap jujur ke pengguna. Berlaku sejak seed pertama yang menyentuh
sumber di luar tim.

### 1. Gerbang lisensi sumber (hard rule)

Sumber data/foto eksternal hanya boleh masuk bila lisensinya jelas dan
masuk salah satu kolam:

| Kolam | Contoh lisensi | Boleh dipakai untuk | Catatan |
| ----- | -------------- | ------------------- | ------- |
| Atribusi | CC BY 4.0, CC BY 2.0 (foto Openverse) | Semua, termasuk modifikasi | Kredit + link lisensi wajib tampil |
| Atribusi + share-alike | CC BY-SA, ODbL | Semua, TAPI karya turunan (data Place hasil pengolahan) wajib dilisensikan sama | Data SambasKu "menular" lisensinya - satu sumber BY-SA membuat places.json BY-SA. Putuskan sengaja, catat di bawah |
| Domain publik / CC0 | PDM, CC0 | Semua, tanpa kewajiban | Ideal |

Ditolak di gerbang (tidak dipakai):

- **ND (NoDerivs)** - kita selalu memodifikasi (memotong, menerjemahkan,
  menaut lemma). Tidak kompatibel.
- **NC (NonCommercial)** - ambigu di produk yang punya highlight UMKM
  berbayar (V5). Ditolak, kecuali blok datanya dipakai di bagian yang
  100% gratis dan tidak menyentuh permukaan monetisasi. Keraguan =
  tolak.
- **"Data terbuka" tanpa lisensi eksplisit** - situs pariwisata
  pemerintah daerah tidak otomatis public domain. Tanpa izin/putusan
  resmi (MoU, surat, lisensi di situs), bukan sumber yang boleh
  disalin. Boleh jadi rujukan riset (baca, tulis ulang dengan kata
  sendiri), tidak boleh disalin mentah.

### 2. Kewajiban atribusi per lisensi

- **Foto** (CC BY, dll): kredit tampil di gambar via `ImageCredit` -
  sudah dirancang di atas. Termasuk **catatan perubahan** bila
  lisensinya mensyaratkan (CC BY-SA): tambah flag `modified: true`
  di entry `images[]` bila foto dipotong/diedit; UI menambahkan
  "diubah" pada kredit.
- **Dataset** (CC BY / ODbL): kredit per Place di `sources[]` boleh
  kurang kalau sumbernya banyak dan beragam; minimum yang sah =
  halaman "Sumber data" (bisa di dalam app / README repo `data`) yang
  mencantumkan: nama sumber, lisensi, link, tanggal ambil, dan catatan
  "data telah dimodifikasi/diterjemahkan". `sources[]` per Place
  tetap dipakai bila satu Place datang dominan dari satu sumber.
- **BY-SA / ODbL**: selain atribusi, file turunannya wajib
  dilisensikan sama. Implikasi nyata: repo `data` (dan nanti tabel
  places) mencantumkan lisensi campuran. Ditangani lewat poin 4.

### 3. Kejujuran sumber & rantai upstream

- Foto hanya lewat jalur yang sudah ada (Media Explorer allowlist:
  pixabay/openverse/unsplash) atau upload milik sendiri. **Tidak ada
  scraping gambar sendiri dari web** - rantai upstream (mis. akun
  Flickr yang salah pasang lisensi) adalah risiko yang tidak bisa
  kita periksa satu-satu; allowlist vendor memindahkan tanggung jawab
  itu ke provider.
- `sources[].type` + `license` diisi jujur. `sources: []` hanya untuk
  konten murni internal. Tidak boleh mengosongkan sumber demi tampilan
  bersih.
- Permintaan pencabutan (takedown) dari pemilik sumber: file diubah di
  repo `data` dalam 1x24 jam (cache jsDelivr ±12 jam + SWR 24 jam
  berarti app masih menyimpan salinan lama sampai ±1,5 hari - itu
  batas teknis, disebut jujur ke pemohon).

### 4. Lisensi repo `data` sendiri

Repo `data` publik = dataset juga terbuka. Keputusan:

- File hasil kerja sendiri (JSON struktur, config card) mengikuti
  lisensi repo.
- Bila ada sumber BY-SA/ODbL masuk: lisensi file yang memuatnya
  dicatat di header JSON (`"license": "CC BY-SA 4.0 (turunan OSM)"`
  atau field serupa) dan README repo `data` mencantumkan daftar
  lisensi per file. Tanpa itu, klaim lisensi tunggal akan palsu.
- Default rekomendasi: **CC BY-SA 4.0** untuk places.json bila sumber
  eksternal pertama memang share-alike (OSM); **CC BY 4.0** bila semua
  sumber atribusi-saja.

### 5. Data tempat & orang nyata (berbeda dari mock)

Seed berisi tempat nyata - bukan lagi mock fiktif. Aturan:

- **Tempat publik** (masjid bersejarah, pantai, alun-alun): aman
  dipublish; nama + koordinat kasar boleh.
- **Tempat usaha pribadi** (warung, toko): masuk katalog boleh, tapi
  **tanpa kontak pribadi** (no. HP, akun pribadi) sebelum klaim
  pemilik (alur V5). Yang tampil: nama usaha, lokasi kasar, jam bila
  publik.
- **Penamaan sensitif**: nama resmi vs lokal vs nama yang bermuatan
  sejarah konflik - melewati tinjauan lokal (sama seperti lemma kamus)
  sebelum publish.
- Koordinat presisi tinggi milik usaha kecil dianggap data kontak
  non-publik sampai terklaim: simpan pembulatan (±3 desimal) di JSON
  publik bila belum klaim.

### 6. Checklist satu menit per sumber baru

Sebelum menambah sumber eksternal ke seed, jawab di commit/PR:

- [ ] Lisensinya apa, terlihat jelas di sumbernya? (kalau cari 5 menit
      tidak ketemu = tolak)
- [ ] Share-alike? Kalau ya, file mana yang tertular?
- [ ] Kredit apa yang wajib tampil, dan di mana?
- [ ] Datanya tentang orang/usaha pribadi? Kalau ya, kontak
      disembunyikan sampai klaim?
- [ ] Nama tempat sudah lewat tinjauan lokal?

---

## Sengaja tidak dikerjakan sekarang

| Tunda | Naik lagi saat |
| ----- | -------------- |
| Favorit count Place | Modul API `place` / Begayau F0 / kemitraan Dinas |
| Gambar Place | Konten visual siap (`images[]` sudah di parser) |
| `related kind: article/event/umkm` | V1 artikel / V4 event / V5 UMKM ship |
| Paket editorial "Akhir pekan di Sambas", frasa pengunjung | V3 lanjutan |
| Review bintang 1-5, turn-by-turn | Anti-goal; kesan-pesan teks jadi penggantinya (lampiran) |
| Video Place | Slot `media[]` disiapkan; kerja saat konten video resmi ada |
| Checkpoint lokasi | Setelah Begayau F2 (foreground suggest) sehat; desain di lampiran |
| Kabar & berita sebagai konten | Anti-goal; pengumuman via notification-campaign |
| Sumber eksternal ND/NC/tanpa-lisensi | Anti-goal permanen; gerbang lisensi di Open data gate |
| Scraping gambar di luar Media Explorer | Risiko rantai upstream; aturan Open data gate poin 3 |
