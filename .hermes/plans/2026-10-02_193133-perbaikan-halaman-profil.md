# Plan - Perbaikan Halaman Profil (tab Profil + Profil Publik)

## Goal

Naikkan kualitas dua halaman profil mobile: benahi error state yang tersamar,
konsistensi warna token tema, duplikasi avatar, loading skeleton, dan buka
akses riwayat aktivitas per kategori yang selama ini tidak bisa dijangkau
user.

## Current context / assumptions

Dua halaman terkait, dua fitur berbeda (JANGAN digabung):

- Tab Profil (settings): `mobile/lib/features/profile/presentation/pages/profile_page.dart` (517 lines). `HookConsumerWidget`, `FHeader` + identitas kecil (avatar 34px) + menu `FTileGroup`. Test: `mobile/test/features/profile/profile_page_test.dart` (321 lines, 3 testWidgets).
- Profil publik: `mobile/lib/features/user_profile/presentation/pages/public_profile_page.dart` (686 lines). Route `/users/:username`, avatar 80px + bio + 3 stat chip + aktivitas terbaru (merge max 20, tanpa cursor). Test: `mobile/test/features/user_profile/` (DTO + mapper saja, belum ada page test).

Temuan audit (dasar setiap task):

1. **Error state tersamar sebagai loading.** `profile_page.dart:69-71` - `authStatus.when(error: (_, _) => const Center(child: FCircularProgress()))`. Kalau restore sesi gagal, user melihat spinner selamanya. Sama polanya di `public_profile_page.dart` (`async.when(error: (_, _) => const SizedBox.shrink())` - dead branch, tapi menyesatkan pembaca).
2. **Warna hardcoded.** `profile_page.dart:295` (`_ReviewQueueTile` dot pending `Color(0xFFF59E0B)`) melanggar aturan repo: warna UI dari token tema. Extension sudah tersedia: `lib/core/theme/f_colors_x.dart` (`context.theme.colors.warning`, brightness-aware amber-500/400).
3. **Duplikasi avatar.** `_ProfileAvatar` (profile_page.dart:433-470) dan `_Avatar` (public_profile_page.dart:516-600) adalah dua implementasi hampir identik (network + nested errorBuilder + initials fallback). Padahal `lib/shared/widgets/cached_network_image_with_fallback.dart` sudah ada dan tidak dipakai keduanya.
4. **Dead code + aktivitas tak terjangkau.** `lib/features/user_profile/presentation/widgets/activity_category_sheet.dart` (186 lines, pagination per kind SUDAH jalan) tidak di-import siapa pun. Stat chip tidak bisa ditap. User tidak punya cara melihat riwayat aktivitas lebih dari 20 item merge.
5. **Loading full-screen spinner.** Profil publik `loading: () => Center(child: FCircularProgress())` - halaman kosong lalu pop-in. `skeletonizer: ^2.1.3` sudah di `pubspec.yaml` dan dipakai di codebase (contoh: `_Avatar` saat upload).

Kontrak yang dipakai: `GET /api/v1/users/:username` (docs/api/19-api-profil-publik.md), `GET /api/v1/users/:username/activity?kind=&limit=&cursor=` (sudah ada `publicActivityByKindProvider` di `user_profile_providers.dart`). Copy UI mengikuti nada docs/mobile/mobile-base-stack.md "Nada copywriting UI" (sapaan kamu, max satu partikel santai per kalimat, hyphen ASCII bukan em dash).

Branch kerja: `fix/tab-freeze` (mobile). Nama package: `sambasku_mobile`.

## Architecture / proposed approach

Tidak ada perubahan arsitektur. Semua task menyentuh lapisan presentation
plus satu ekstraksi widget shared; repository/provider/use case tidak berubah
kecuali membaca provider yang sudah ada (`publicActivityByKindProvider`).
Urutan task disusun dari risk paling kecil (satu-liner token warna) ke yang
paling besar (wire sheet aktivitas), tiap task commit terpisah.

## Step-by-step tasks

### Task 1 - Token tema untuk dot pending (1 commit, tanpa test baru)

Dot pending `_ReviewQueueTile` hardcoded amber. Ganti dengan token.

`mobile/lib/features/profile/presentation/pages/profile_page.dart`:

- Tambah import `../../../../core/theme/f_colors_x.dart` (sudah ada di file, baris 12 - tidak perlu tambah).
- Ganti di `_ReviewQueueTile`:

```dart
// SEBELUM (baris ~295)
color: Color(0xFFF59E0B),
// SESUDAH
color: context.theme.colors.warning,
```

`_ReviewQueueTile` sudah `ConsumerWidget` dengan `context` tersedia. Karena
`context.theme` butuh import extension `f_colors_x.dart` yang memanggil
`FTheme` - sudah ter-import via `forui.dart`.

Verifikasi:

```bash
cd mobile && dart analyze lib/features/profile
# expect: No issues found!
flutter test test/features/profile/profile_page_test.dart
# expect: All tests passed!
git add lib/features/profile/presentation/pages/profile_page.dart
git commit -m "style(profile): dot pending verifikator pakai token warning tema"
```

### Task 2 - Error state tab Profil jujur (TDD)

Ganti spinner infinite saat `authStatusProvider` error dengan pesan + aksi.

RED - tambah test di `mobile/test/features/profile/profile_page_test.dart`
(ikuti fixture `_FakeAuthRepository` yang sudah ada di file):

```dart
testWidgets('error restore sesi - pesan + tombol coba lagi, bukan spinner', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStatusProvider.overrideWith(() => _ThrowingAuthStatus()),
        // override storage/network lain sama seperti test 'tamu' existing
      ],
      child: const FTheme(child: MaterialApp(home: ProfilePage())),
    ),
  );
  await tester.pump();
  expect(find.byType(FCircularProgress), findsNothing);
  expect(find.text('Gagal memuat profil'), findsOneWidget);
  expect(find.text('Coba lagi'), findsOneWidget);
});

class _ThrowingAuthStatus extends AuthStatusNotifier {
  @override
  Future<AuthStatusState> build() async => throw const AuthFailure('offline');
}
```

Sesuaikan detail override dengan helper yang sudah dipakai test 'tamu' di
file yang sama (baca dulu baris 190-260 sebelum menulis).

Run - expect GAGAL compile/gagal assertion (state error belum ada di UI):

```bash
flutter test test/features/profile/profile_page_test.dart --plain-name 'error restore sesi'
```

GREEN - ubah `profile_page.dart` build:

```dart
Expanded(
  child: authStatus.when(
    loading: () => const Center(child: FCircularProgress()),
    error: (err, _) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Gagal memuat profil',
            style: context.theme.typography.md
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(8),
          FButton(
            variant: FButtonVariant.outline,
            onPress: () =>
                ref.invalidate(authStatusProvider),
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
    data: (status) => RefreshIndicator(
      // ... isi existing tidak berubah
    ),
  ),
),
```

Catatan: kalau `AuthStatusNotifier.build` di kode nyata tidak pernah throw
(melainkan menelan error jadi `isAuth: false`), maka task ini berubah bentuk:
verifikasi dulu dengan baca `auth_status_providers.dart` bagian restore.
Kalau restore memang menelan error, SKIP task ini dan catat temuan di PR
description - jangan membuat error path yang mustahil terjadi (YAGNI).

Verifikasi + commit:

```bash
flutter test test/features/profile/profile_page_test.dart
# expect: All tests passed! (test baru + 3 lama)
git add lib/features/profile/presentation/pages/profile_page.dart test/features/profile/profile_page_test.dart
git commit -m "fix(profile): error state restore sesi tampil jujur + coba lagi"
```

### Task 3 - Ekstrak avatar shared (DRY, refactor murni)

Satu widget untuk semua avatar lingkaran (tab Profil, profil publik).

1. Baca `mobile/lib/shared/widgets/cached_network_image_with_fallback.dart`
   dulu - pahami API-nya (URL, fallback widget, size).
2. Buat `mobile/lib/shared/widgets/circle_avatar_network.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../core/utils/display_image_url.dart';
import 'cached_network_image_with_fallback.dart';

/// Avatar lingkaran: optimasi wsrv.nl -> CachedNetworkImageWithFallback
/// -> inisial nama. Satu implementasi untuk tab Profil & profil publik.
class CircleAvatarNetwork extends StatelessWidget {
  const CircleAvatarNetwork({
    super.key,
    required this.name,
    required this.size,
    this.imageUrl,
  });

  final String? name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final display = displayImageUrl(imageUrl, width: 256) ?? imageUrl;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImageWithFallback(
          url: display,
          fallback: _InitialsFace(name: name, size: size),
        ),
      ),
    );
  }
}
```

Sesuaikan nama parameter `CachedNetworkImageWithFallback` dengan API
sebenarnya (baca filenya; JANGAN menebak). Pindahkan logic `_initials`
(copot dari `_InitialsOrIcon` profile_page.dart:507-516) ke helper shared,
mis. `lib/core/utils/name_initials.dart`:

```dart
/// Inisial nama untuk avatar: 2 kata -> huruf pertama masing-masing.
String? nameInitials(String? name) {
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  final word = parts.first;
  if (word.length >= 2) return word.substring(0, 2).toUpperCase();
  return word.toUpperCase();
}
```

3. Ganti badan `_ProfileAvatar` (profile_page.dart) dan `_Avatar`
   (public_profile_page.dart) untuk memakai `CircleAvatarNetwork`,
   simpan perilaku khusus di lapisan luar:
   - `_Avatar` masih pegang `uploading` (Skeletonizer bone) dan
     `showEditBadge` (Stack + badge kamera) - itu wrapper, bukan avatar face.
   - `_InitialsOrIcon` (tanpa nama -> icon userRound) dipertahankan sebagai
     `fallback` argumen.

4. Test yang membuktikan tidak ada regresi: test existing tab profil +
   tambah satu test DTO-level untuk `nameInitials` di
   `mobile/test/core/name_initials_test.dart`:

```dart
test('dua kata, satu kata, kosong', () {
  expect(nameInitials('Ibnul Mutaki'), 'IM');
  expect(nameInitials('Kapsaloy'), 'KA');
  expect(nameInitials('  '), isNull);
});
```

Verifikasi:

```bash
flutter test test/features/profile/ test/features/user_profile/ test/core/name_initials_test.dart
# expect: All tests passed!
git add lib/shared/widgets/circle_avatar_network.dart lib/core/utils/name_initials.dart \
  lib/features/profile/presentation/pages/profile_page.dart \
  lib/features/user_profile/presentation/pages/public_profile_page.dart \
  test/core/name_initials_test.dart
git commit -m "refactor(profile): konsolidasi avatar ke CircleAvatarNetwork + nameInitials"
```

### Task 4 - Skeleton loading profil publik (TDD ringan)

Ganti `Center(child: FCircularProgress())` di `public_profile_page.dart`
(`async.when(loading: ...)`) dengan skeleton layout mirip bentuk final
(avatar circle 80 + 2 baris teks + 3 chip) memakai `skeletonizer`.

RED - test baru `mobile/test/features/user_profile/public_profile_page_test.dart`
(override `publicProfileProvider` ke `AsyncLoading()` dan
`publicActivityProvider` ke `AsyncLoading()`; override
`authStatusProvider` dengan fake tamu; ikuti pola ProviderScope dari
profile_page_test.dart):

```dart
testWidgets('loading - skeleton tampil, tanpa spinner', (tester) async {
  await tester.pumpWidget(_wrap(publicProfile: const AsyncLoading()));
  await tester.pump();
  expect(find.byType(Skeletonizer), findsOneWidget);
  expect(find.byType(FCircularProgress), findsNothing);
});
```

GREEN - di `public_profile_page.dart`:

```dart
loading: () => const _ProfileSkeleton(),

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        children: [
          Row(children: [
            const Bone.circle(size: 80),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Bone.text(width: 140),
                  Gap(6),
                  Bone.text(width: 90),
                ],
              ),
            ),
          ]),
          const Gap(20),
          Row(children: [
            for (var i = 0; i < 3; i++) ...[
              const Expanded(child: Bone(borderRadius: BorderRadius.all(Radius.circular(10)), height: 64)),
              if (i < 2) const Gap(8),
            ],
          ]),
          const Gap(24),
          const Bone.text(width: 120),
          const Gap(8),
          ...List.generate(3, (_) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Bone.text(width: double.infinity),
          )),
        ],
      ),
    );
  }
}
```

Verifikasi:

```bash
flutter test test/features/user_profile/public_profile_page_test.dart
# expect: All tests passed!
git add lib/features/user_profile/presentation/pages/public_profile_page.dart \
  test/features/user_profile/public_profile_page_test.dart
git commit -m "style(user_profile): skeleton loading profil publik (skeletonizer)"
```

### Task 5 - Buka riwayat aktivitas per kategori (wire dead code, TDD)

Aktifkan `ActivityCategorySheet` yang sudah jalan tapi tidak pernah
dipanggil. Entry point: tap stat chip di profil publik (Kontribusi /
Verifikasi / Komentar) + tambah kind `vote` jadi chip keempat? TIDAK -
`PublicProfile` tidak punya field vote count, jadi cukup 3 chip existing
(YAGNI; vote masuk di aktivitas merge).

Ubah `_StatChip` jadi interaktif:

```dart
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        // ... isi Container existing persis sama
      ),
    );
  }
}
```

Pemanggilan (di `_ProfileBody`, bungkus showModalBottomSheet; ingat aturan
repo: sheet butuh ancestor `Material` - `ActivityCategorySheet` sudah
memakai Scaffold/sheet forui di dalamnya, jika analisis komplain tambahkan
`Material(color: theme.colors.background)` sebagai root sheet builder):

```dart
_StatChip(
  label: 'Kontribusi',
  value: '${profile.contributionsApproved}',
  onTap: () => _showCategory(
    context, profile, 'contribution',
  ),
),
// verificationsDone -> 'verification', commentsPublished -> 'comment'

void _showCategory(
  BuildContext context,
  PublicProfile profile,
  String kind,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: ActivityCategorySheet(
        username: profile.username,
        kind: kind,
        profile: profile,
      ),
    ),
  );
}
```

Import tambah di `public_profile_page.dart`:

```dart
import '../widgets/activity_category_sheet.dart';
```

RED - test di `public_profile_page_test.dart` (dari Task 4), override
`publicActivityByKindProvider` family:

```dart
testWidgets('tap stat chip Kontribusi - buka sheet kategori', (tester) async {
  await tester.pumpWidget(_wrap(
    publicProfile: AsyncData(profileFixture), // kontribusiApproved > 0
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kontribusi'));
  await tester.pumpAndSettle();
  expect(find.byType(ActivityCategorySheet), findsOneWidget);
});
```

Perhatikan: `publicActivityByKindProvider` dipanggil di dalam sheet saat
init - override dengan data kosong supaya `pumpAndSettle` selesai.

Verifikasi:

```bash
flutter test test/features/user_profile/
# expect: All tests passed!
git add lib/features/user_profile/presentation/pages/public_profile_page.dart \
  test/features/user_profile/public_profile_page_test.dart
git commit -m "feat(user_profile): stat chip membuka riwayat aktivitas per kategori"
```

## Tests / validation

Tiap task sudah bawa siklusnya masing-masing. Gerbang akhir:

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
flutter analyze --no-pub
# expect: jumlah issue TIDAK bertambah dari baseline (cek dulu baseline sebelum mulai)
flutter test
# expect: All tests passed! (baseline 401 + test baru)
```

Manual di device/emulator (butuh mata, tidak tergantikan test):

- Tab Profil: matikan koneksi + restart app -> lihat perilaku restore (Task 2; kalau restore menelan error, tidak ada perubahan visual, itu hasil yang sah).
- Profil publik: buka /users/{handle} -> skeleton -> konten; tap tiap stat chip -> sheet terbuka, scroll pagination jalan; tap item -> detail kata.

## Risks, tradeoffs, open questions

- **Task 2 bisa hangus** kalau `AuthStatusNotifier` memang tidak pernah
  error (menelan error jadi state tamu). Verifikasi dulu sebelum menulis
  test; kalau menelan error, keputusan desain baru: apakah restore yang
  gagal harus tampil sebagai pesan di tab Profil, atau cukup diam menjadi
  tamu. Diskusikan, jangan asal tambah error UI.
- **Sheet butuh Material ancestor** (aturan repo terdokumentasi). Kalau
  `ActivityCategorySheet` crash saat dibuka dengan
  `No Material widget found`, bungkus builder dengan
  `Material(color: ...)`. Jangan hapus guard lain.
- **`CachedNetworkImageWithFallback` belum dibaca isinya** saat plan ini
  ditulis. Task 3 WAJIB baca dulu; kalau API-nya tidak cocok (mis. tidak
  menerima fallback widget), fallback plan: ekstrak face avatar ke widget
  shared baru tetap dengan `Image.network` + errorBuilder, tapi SATU
  implementasi saja (hapus dua duplikat lama).
- **Tidak menyentuh API** - semua data yang dibutuhkan sheet sudah di-support
  endpoint (`kind`, `limit`, `cursor` ada di datasource). Kalau ternyata
  pagination per kind gagal saat uji manual, cek `publicActivityByKindProvider`
  dulu sebelum curiga API.
- **Sengaja TIDAK masuk plan** (jangan scope creep): badge achievement
  gamifikasi (docs/GAMIFIKASI_CONCEPT.md - konsep belum final), status
  begayau di profil (docs/backlogs/BEGAYAU.md - fitur terpisah), share
  profil publik (butuh keputusan bentuk share card), edit bio langsung dari
  profil publik (sudah ada /edit-profile).
- **Dead code lain di sheet lama**: setelah Task 5,
  `activity_category_sheet.dart` hidup. Kalau Task 5 dibatalkan, file itu
  harus dihapus, bukan dibiarkan mati.
