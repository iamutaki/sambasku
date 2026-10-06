# Plan: WOTD Card Background dengan wotd_cover.png

## Goal

Tambahkan gambar `assets/images/wotd_cover.png` sebagai background dekoratif di `WordOfDayCard` (mobile), resize + compress ke WebP optimal, dan pastikan teks tetap terbaca baik di light/dark mode.

## Current Context / Assumptions

- File asli: `mobile/assets/images/wotd_cover.png` (1920×1080 PNG, ~2.6 MB).
- Widget target: `lib/features/dictionary/presentation/widgets/word_of_day_card.dart` (`_WordOfDayBody` + `_WordOfDaySkeleton`).
- Teks di card: putih/cream di area kiri atas (lemma, arti, label) → overlay di atas background.
- Theme: pakai `context.theme.colors` (Forui). Light/dark ditentukan `Theme.of(context).brightness`.
- Tools tersedia: `magick` (ImageMagick), `cwebp` (WebP encoder).
- pubspec sudah daftarkan `assets/images/`.
- Gambar analisis: kiri atas relatif tenang (awan abu gelap), kanan atas sibuk (matahari). Cocok teks kiri atas + scrim gelap kiri.

## Architecture / Proposed Approach

1. **Proses gambar sekali** (build-time / CI, bukan runtime): resize ke lebar layar max ~400px, compress WebP quality 75, simpan ke `assets/images/wotd_cover.webp` (commit ke repo). Hapus PNG asli biar bundle kecil.
2. **Widget**: bungkus `Material` dengan `BoxDecoration` pakai `DecorationImage` (asset WebP, `fit: BoxFit.cover`). Tambah `DecovatedBox`/`Container` dengan gradient scrim kiri (`LinearGradient` begin `Alignment.centerLeft`, end `Alignment.centerRight`, colors `[Colors.black54, Colors.transparent]`) di atas gambar, di bawah konten teks.
3. **Skeleton**: sama pakai background + scrim, biar konsisten visual saat loading.

## Step-by-step Tasks

### Task 1 - Optimasi gambar (CLI, sekali jalan)

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/mobile
# Resize max width 400, keep aspect, WebP q75, strip metadata
magick assets/images/wotd_cover.png -resize '400x' -quality 75 -strip assets/images/wotd_cover.webp
# Verifikasi ukuran
ls -lh assets/images/wotd_cover.webp
# Expected: ~400px width, file < 80 KB
# Hapus PNG asli (sudah tidak dipakai)
rm assets/images/wotd_cover.png
```

### Task 2 - Update widget body (`_WordOfDayBody`)

File: `lib/features/dictionary/presentation/widgets/word_of_day_card.dart`

Ganti `Material` → `Stack` (bg + scrim + content). Pattern copy-paste:

```dart
// --- GANTI SELURUH return Padding(...) DI _WordOfDayBody ---
return Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Material(
    color: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: accent.withValues(alpha: 0.35)),
    ),
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        // 1. Background image
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/images/wotd_cover.webp'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        // 2. Scrim gelap kiri (biar teks putih terbaca)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
        ),
        // 3. Konten asli (sudah ada, pindah ke sini)
        InkWell(
          onTap: () { /* existing onTap */ },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(color: accent, child: const SizedBox(width: 4)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [ /* existing children */ ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);
```

Pastikan import tambah: `import 'dart:ui';` (untuk `Alignment`, `LinearGradient`).

### Task 3 - Update skeleton (`_WordOfDaySkeleton`)

Sama: bungkus `Material` → `Stack` dengan background + scrim identik, lalu `Skeletonizer` di atasnya.

```dart
// --- GANTI SELURUH return Padding(...) DI _WordOfDaySkeleton ---
return Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: SkeletonizerConfig(
    data: SkeletonizerConfigData(effect: shimmer),
    child: IgnorePointer(
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Background image
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: const AssetImage('assets/images/wotd_cover.webp'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            // Scrim
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
            // Skeleton content
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 10, 8),
              child: Skeletonizer(
                enabled: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kata hari ini'),
                    Gap(6),
                    Text('lemma contoh'),
                    Gap(2),
                    Text('arti pertama satu baris'),
                    Gap(4),
                    Text('Ditampilkan hari ini, berganti setiap hari'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
```

### Task 4 - Verifikasi build & visual

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/mobile
flutter analyze --no-pub
flutter test test/features/dictionary/ 2>&1 | tail -10
# Expected: analyze bersih, test pass (jika ada test widget WOTD)
# Manual: flutter run --debug (cek device/emulator light & dark)
```

### Task 5 - Commit (split mobile only)

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/mobile
git add assets/images/wotd_cover.webp
git rm assets/images/wotd_cover.png
git add lib/features/dictionary/presentation/widgets/word_of_day_card.dart
git commit -m "feat(dictionary): wotd card background with optimized WebP + scrim (light/dark)"
```

## Tests / Validation

- `flutter analyze --no-pub` → no new errors.
- `flutter test test/features/dictionary/` → existing tests pass.
- Manual device: light mode teks putih terbaca; dark mode teks putih tetap terbaca (scrim handle kontras).
- Bundle size check: `flutter build apk --analyze-size` → `wotd_cover.webp` < 100 KB di assets.

## Risks, Tradeoffs, Open Questions

1. **Asset path**: `AssetImage('assets/images/wotd_cover.webp')` butuh pubspec sudah include `assets/images/` (sudah). Kalau nanti folder berubah, path perlu update.
2. **Scrim alpha**: `0.45`/`0.55` diambil dari analisis visual. Bisa perlu tuning kalau Tuan lihat di device terlalu gelap/terang. Parameter mudah diubah.
3. **Orientasi**: background `BoxFit.cover` memotong vertikal/horizontal tergantung aspect card. Card saat ini `IntrinsicHeight` + `Row` → tinggi variabel. Gambar landscape (1920×1080) di card portrait akan crop atas/bawah. Alternatif: `BoxFit.fitWidth` + `alignment: Alignment.topCenter` kalau mau lihat full width. Pilihan default: `cover` + `center` (standar).
4. **Performance**: `DecorationImage` di `Stack` + `Positioned.fill` = 1 draw call per frame, OK untuk 1 card di home. Tidak pakai `CachedNetworkImage` karena asset lokal.
5. **Accessibility**: teks putih di atas scrim gelap → kontras AA/AAA terpenuhi. Jika user override font size besar, teks bisa overflow ke area tanpa scrim (kanan). Mitigasi: `maxLines` + `overflow: ellipsis` sudah ada.
6. **Dark mode scrim**: `Colors.black.withValues(alpha: 0.45)` works di light & dark karena scrim gelap di atas gambar cerah. Di dark mode card background `theme.colors.secondary` sudah gelap, tapi gambar tetap terlihat lewat scrim semi-transparan. Kalau Tuan mau beda scrim per mode, tambah `isDark ? 0.35 : 0.45`.
7. **CI/CD**: langkah Task 1 manual. Bisa diotomatisasi nanti di `github-pages` atau CI script. Di plan ini di-commit manual sekali.