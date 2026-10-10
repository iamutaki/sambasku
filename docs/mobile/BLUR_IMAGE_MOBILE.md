# Mobile - Blocking & blur gambar kata

Mengikuti `mobile-base-stack.md` (Section 9 lampiran gambar) dan kontrak
produk [`../produk/tayang-belum-verifikasi.md`](../produk/tayang-belum-verifikasi.md).
API staging ImageKit:
[`../api/03-api-kontribusi-verifikasi.md`](../api/03-api-kontribusi-verifikasi.md)
(§ gambar - GET publik mengganti URL ImageKit belum diverifikasi).

Status: **siap implementasi** (mobile). Flag kekerasan butuh kontrak API
baru (lihat § Dependensi API).

---

## Tujuan

Dua lapisan proteksi tampilan gambar di detail kata (thumb + preview
penuh), terpisah dari badge **Terverifikasi** pada lemma:

| Kondisi | Perilaku default | Interaksi |
| --- | --- | --- |
| Gambar **belum diverifikasi** (staging ImageKit) | Tampilkan **asset lokal**, bukan URL jaringan/`placehold.co` | Tidak bisa dibuka sebagai foto asli (belum ada URL publik) |
| Gambar **kekerasan** (`content_warning` berisi `kekerasan`) | Foto **diblur** - isi tidak terbaca sekilas | Tap → konfirmasi singkat → unblur (sesi halaman saja) |
| Verified + tanpa peringatan kekerasan | Tampil normal (`CachedNetworkImageWithFallback` + `displayImageUrl`) | Tap → `showImagePreview` seperti sekarang |

Prioritas jika keduanya berlaku: **unverified menang** (asset lokal).
Blur kekerasan hanya relevan setelah URL asli tersedia (sudah verified /
bukan staging yang di-redact).

---

## Latar belakang (apa yang sudah ada)

### API (publik)

`mapPublicWordImageUrl` + `redactStagingImages: true` pada GET detail
publik:

- ImageKit + `is_verified !== true` → `url` diganti
  `https://placehold.co/600x400?text=Menunggu%0ATinjauan`
  (`PENDING_WORD_IMAGE_PLACEHOLDER_URL`).
- `provider_file_id` / `sha` di-null agar file staging tidak bocor.
- Field `is_verified` / `provider` **tidak** dikirim ke klien publik
  (hanya admin / antrean).

Stock (Pexels, …) dan upload verifikator → langsung verified, URL asli.

### Mobile hari ini

- Thumb di
  [`word_detail_page.dart`](../../mobile/lib/features/dictionary/presentation/pages/word_detail_page.dart)
  memuat `primaryImage.url` apa adanya (termasuk `placehold.co`).
- Fallback error jaringan sudah pakai asset lokal
  [`ImagePlaceholder256`](../../mobile/lib/shared/widgets/image_placeholder_256.dart)
  → `assets/images/placeholder_256.png` (+ `placeholder_512.png`).
- Entity `WordImage` hanya `{ id, url, altText, isPrimary }` - belum
  ada signal verified / content warning.

---

## Keputusan produk (mobile)

### 1. Belum diverifikasi → asset lokal

- Jangan hit `placehold.co` (hemat bandwidth, offline-friendly, branding
  Sambasku konsisten).
- Deteksi **pending staging** (pilih satu, urutan preferensi):

  1. **Utama (kontrak baru):** field publik `is_verified: false` pada
     item `images[]` **atau** `url == null` + `pending: true`.
  2. **Interim (tanpa tunggu API):** URL sama dengan konstanta
     `PENDING_WORD_IMAGE_PLACEHOLDER_URL` / host `placehold.co` dengan
     path yang dikenal.

- Widget: `Image.asset('assets/images/placeholder_512.png')` untuk
  thumb ≥72px; `placeholder_256` untuk chip kecil. Opsional overlay
  teks kecil: **Menunggu tinjauan** (Semantics wajib).
- Tap thumb pending: **jangan** buka gallery preview URL palsu; boleh
  snackbar / no-op: *Gambar masih menunggu pemeriksaan tim.*

### 2. Gambar kekerasan → blur by default

- Sinyal dari API per gambar: `content_warnings: string[]` (closed
  enum). V1 hanya `'kekerasan'`.
- Bukan lewat `usage_labels` kata (`seksual`, `diskriminatif`, …) -
  itu register/peringatan makna, bukan sensor visual foto. Kata bisa
  punya label `seksual` tanpa foto kekerasan, dan sebaliknya.
- UI default:

  ```text
  ┌─────────────────┐
  │  [foto diblur]  │
  │   👁 Tampilkan  │  ← overlay tengah
  └─────────────────┘
  ```

  - `ImageFiltered` + `ImageFilter.blur(sigmaX/Y: 24)` (atau setara)
    di atas `CachedNetworkImageWithFallback`.
  - Overlay gelap tipis + label **Konten kekerasan** + aksi **Tampilkan**.
  - Setelah unblur: state lokal `Set<imageId>` di State halaman /
    `StatefulWidget` wrapper - **reset** saat leave detail / ganti
    `wordId`. Tidak dipersist ke SharedPreferences (sengaja ketat).
  - Preview penuh (`showImagePreview`): ikut state unblur; jika masih
    blur, tampilkan layar konfirmasi yang sama sebelum swipe gallery.
- Accessibility: Semantics `button` + hint *Gambar disensor. Ketuk untuk
  menampilkan.*

### 3. Share card / Media Explorer

- Kartu bagikan: jika sumber = gambar kata yang pending → pakai asset
  lokal / gradien template, bukan `placehold.co`.
- Gambar kekerasan yang belum di-unblur di detail: **jangan** masuk
  strip “Gambar kata” sebagai thumb tajam; boleh exclude atau tampil
  blur + tidak auto-pilih sebagai latar.

---

## Model data (mobile)

Perluas rantai dictionary (pola fitur existing):

```text
WordImageDto          # +isVerified?, +contentWarnings
WordImage (entity)    # +isVerified, +contentWarnings
mapper di dictionary_repository_impl
```

```dart
class WordImage {
  const WordImage({
    required this.id,
    required this.url,
    this.altText,
    required this.isPrimary,
    this.isVerified = true, // default aman untuk payload lama
    this.contentWarnings = const [],
  });

  final String id;
  final String url;
  final String? altText;
  final bool isPrimary;
  final bool isVerified;
  final List<String> contentWarnings;

  bool get isPendingReview => !isVerified;
  bool get hasViolenceWarning => contentWarnings.contains('kekerasan');
}
```

Parsing: field absen → default `isVerified: true`,
`contentWarnings: []` (kompatibel response lama yang hanya kirim
placeholder URL tanpa flag).

Helper UI (shared, dipakai detail + preview + share):

```text
mobile/lib/shared/widgets/word_image_view.dart   # BARU
  WordImageView({
    required WordImage image,
    BoxFit fit,
    VoidCallback? onRevealViolence, // optional hook analytics
  })
```

Logic ringkas:

```text
if (image.isPendingReview || isKnownPendingPlaceholderUrl(image.url))
  → Image.asset(placeholder)
else if (image.hasViolenceWarning && !revealed)
  → Stack(blurred network image, reveal CTA)
else
  → CachedNetworkImageWithFallback(displayImageUrl(...))
```

---

## Titik integrasi UI

| Lokasi | Perubahan |
| --- | --- |
| `word_detail_page.dart` thumb 72×72 | Ganti `CachedNetworkImageWithFallback` → `WordImageView` |
| `showImagePreview` | Terima list `WordImage` (atau flag per URL), hormati pending/blur |
| `review_entity_preview.dart` | Verifikator melihat URL asli (endpoint admin) - **tidak** blur/pending asset; tetap network |
| Share “Gambar kata” | Filter / blur sesuai §3 |

Review antrean (`redactStagingImages: false`) tetap URL ImageKit asli -
jangan terapkan asset lokal di layar moderator.

---

## Dependensi API (perlu disepakati / PR terpisah)

Agar mobile tidak bergantung pada string-match `placehold.co`:

1. **Publik `images[]`:** sertakan `is_verified: boolean` (atau
   `pending: true` saat redact). Tetap boleh redact `url` → placeholder
   **atau** kirim `url: null` + flag; mobile lebih suka flag eksplisit.
2. **Peringatan visual:** kolom / field `content_warnings` pada
   `word_images` (JSON array / tabel pivot). V1 enum: `kekerasan`.
   Diisi saat create/update media (kontributor centang) atau saat
   review (verifikator). GET publik mengirim array (boleh kosong).
3. Admin detail & antrean: URL asli + flags lengkap (sudah
   `is_verified` hari ini).

Tanpa (2), blur kekerasan **belum bisa** diimplementasi end-to-end;
mobile tetap bisa ship lapisan (1) unverified → asset lokal dulu.

Dokumen API lanjutan (usulan nama): `docs/api/33-api-word-image-warnings.md`
- di luar scope file ini.

---

## Yang tidak masuk V1

- Persist preferensi “selalu tampilkan konten kekerasan”.
- Blur otomatis dari `usage_labels` kata (`seksual`, dll.).
- Moderasi AI / deteksi kekerasan otomatis di upload.
- Menghapus `placehold.co` di API (web masih boleh memakai sampai
  ada flag; mobile ignore URL itu).
- Mengubah alur promote ImageKit → GitHub.

---

## Test plan (mobile)

- [ ] Detail kata dengan gambar ImageKit pending: thumb = asset lokal,
      tidak ada request ke `placehold.co` / ImageKit staging.
- [ ] Tap thumb pending: tidak membuka preview URL palsu.
- [ ] Setelah approve (URL GitHub + verified): thumb network normal.
- [ ] Gambar verified + `content_warnings: ["kekerasan"]`: blur default,
      tap → unblur; kembali ke detail lain lalu balik → blur lagi.
- [ ] Gambar verified tanpa warning: tidak ada overlay blur.
- [ ] Payload tanpa field baru (regression): tetap parse; placeholder
      URL → tetap dipetakan ke asset via deteksi interim.
- [ ] Layar review admin: URL staging terlihat tajam (bukan asset lokal).

---

## Urutan kerja disarankan

1. Helper `isKnownPendingPlaceholderUrl` + `WordImageView` (pending →
   asset) + wire `word_detail_page` - **bisa merge tanpa API baru**.
2. Perluas DTO/entity `isVerified` / `contentWarnings` (default aman).
3. Overlay blur + state reveal + preview.
4. PR API flags publik + `content_warnings` (bila belum ada).
5. Hapus deteksi interim `placehold.co` setelah flag `is_verified`
   stabil di produksi.
