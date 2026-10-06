# Mobile - Kartu Share Kosakata

Mengikuti `mobile-base-stack.md`: Section 2 (lapis fitur), 6 (networking
Dio + envelope). Kontrak API:
[`../api/22-api-share-backgrounds.md`](../api/22-api-share-backgrounds.md).
Backlog: [`../backlogs/SHARE.md`](../backlogs/SHARE.md),
[`../backlogs/SHARE_VIDEO.md`](../backlogs/SHARE_VIDEO.md).

Status (2026-09-21): V1.3 - Media Explorer (Gambar | Video) + 8 gaya.

---

## Tujuan

Satu tile Bagikan. User mengatur gaya / editor / latar (foto atau
video) → PNG (foto) atau MP4 (video) → native share sheet + caption.

Bukan mode atau halaman kedua.

---

## Titik masuk

1. **`FTileGroup`** di detail kata, tepat di atas Komentar:
   - Bagikan kartu
   - Usulkan perubahan
2. **Ikon header** `share2` - shortcut sekunder (sama sheet)

File:
[`word_detail_page.dart`](../../mobile/lib/features/dictionary/presentation/pages/word_detail_page.dart)
(`_WordActionTileGroup` + `openWordShareSheet`).

Sheet: preview besar di atas, kontrol + editor selalu terbuka, aksi
`FButton` Forui.

---

## Modul

```
mobile/lib/features/share/
├── domain/share_models.dart
├── data/share_background_repository.dart
└── presentation/
    ├── share_sheet.dart
    ├── share_card_renderer.dart
    └── widgets/share_card_canvas.dart
    └── widgets/share_video_layer.dart
```

Dependensi: `share_plus`, `google_fonts`, `image_picker`,
`path_provider`, `video_player`, `gal`.

Kunci Pixabay / Unsplash **tidak** di APK. Openverse anonim.

---

## Gaya vs sumber latar

**Gaya:** Penuh · Editorial · Poster · Bingkai · Sisi · Kaca · Kutipan · Kartu
(Poster memaksa tanpa latar. Slider overlay untuk Penuh, Kaca, Kutipan.)

**Latar (satu strip):**

| Sumber | Cara |
| --- | --- |
| Tanpa latar | gradien template |
| Explorer | **Media Explorer** di samping Tanpa latar. Tab Gambar \| Video; chip provider di dalam tab (Gambar: Pixabay default, Openverse, Unsplash; Video: Pixabay) |
| Galeri | foto atau video perangkat |
| Kamera | foto saja |
| Gambar kata | `detail.images` (ImageKit), foto |
| Pixabay foto | foto stok (`provider=pixabay&media=photo`) |
| Pixabay video | video stok (`provider=pixabay&media=video`) |
| Openverse | foto stok (`provider=openverse&media=photo`) |
| Unsplash | foto stok (`provider=unsplash&media=photo`) |

Default: Pixabay. Openverse dan Unsplash hanya lewat Media Explorer.
Pexels / Wikimedia tidak lagi tersedia di explorer (safe-search).
Query: padanan + kategori.

Client **wajib** cek `kind` sebelum `Image.network(url)`. Video pakai
`preview_url` di thumb dan `url` MP4 di player.

---

## Preview dan Bagikan

- Foto / gradien: `RepaintBoundary` → PNG (V1).
- Video: `video_player` muted loop di bawah overlay teks. Jangan
  screenshot kartu utuh (`toImage` tidak menangkap texture).
- Bagikan video: overlay PNG transparan + mux native MP4 ≤ 15 dtk,
  tanpa audio. Gagal encode → PNG dari `preview_url`.
- Simpan: foto `Gal.putImageBytes`, video `Gal.putVideo` setelah
  `requestGalleryWriteAccess` (`Gal.requestAccess`, lalu
  `photosAddOnly` / `photos` jika masih ditolak). Dialog yang ada
  jika user menolak. Bagikan tetap native share sheet.
- Variasi penulisan (`WordDetail.variants`, skip lemma) satu baris
  di bawah lemma di semua gaya, ikut caption dan copyText.
- Mux video crop cover ke ukuran overlay (rasio kartu 9:16 atau
  1:1), lalu overlay 1:1. Teks kartu tidak lagi menempel ke frame
  asli 16:9.

Caption tidak berubah.

---

## Editor

- Slider ukuran lemma (0.8-1.4) dan tubuh (0.8-1.3)
- Overlay strength (Penuh, Kaca, Kutipan)
- Warna teks / pasangan font / gradasi preset + polos via pemilih HSV/hex
- Toggle: kelas kata, padanan, definisi, contoh, watermark
- Geser teks di fullscreen
- Geser crop foto/video (semua gaya kecuali Poster): chip Latar di editor posisi

---

## Hardening

- API `degraded: true` / items kosong → toast + fallback tanpa latar
- Chip Video tetap ada jika Pexels/Pixabay `available: false`
- Shuffle page kosong → keep batch sebelumnya + toast
- Error load video → gradien + toast, Bagikan masih PNG
- Precache foto sebelum `toImage`

---

## Uji manual

1. Tile **Bagikan kartu** (satu-satunya) membuka sheet
2. Unsplash foto → Bagikan PNG
3. Pexels foto → Bagikan PNG
4. Pexels video → preview loop → Bagikan MP4 (iOS + Android)
5. Pixabay foto → Bagikan PNG
6. Pixabay video → preview loop → Bagikan MP4
7. Openverse foto → Bagikan PNG
8. Wikimedia foto → Bagikan PNG
9. Wikimedia video → preview loop → Bagikan MP4
10. Galeri video → sama
11. Matikan kunci Unsplash/Pexels/Pixabay → degraded, Bagikan tetap jalan
12. Poster: tanpa latar
13. Gaya Sisi / Kaca / Kutipan / Kartu di preview 9:16 dan 1:1
14. Simpan video: minta izin tambah galeri, file masuk Photos
15. Lemma dengan variasi: baris `makatn / makatan` di kartu + caption
16. Simpan video 16:9 ke kartu 9:16: definisi tetap di dalam padding

Bruno: `http/share/`.
