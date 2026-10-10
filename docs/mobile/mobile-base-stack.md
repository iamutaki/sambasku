# Base Stack Mobile: Kamus Digital Sambas-Indonesia (Flutter)

Dokumen ini jadi acuan tetap untuk semua prompt/fitur mobile selanjutnya,
mengikuti pola yang sudah terbukti di proyek `jnn_mobile` (repo pribadi),
disesuaikan dengan kontrak backend sambasku (`docs/api/api-base-stack.md`).
Setiap prompt fitur baru (auth, pencarian, kontribusi, dst) mengikuti
struktur dan konvensi di sini tanpa dijelaskan ulang.

## Gaya tulisan (wajib)

Tulisan teknis di repo ini (docs, komentar, UI copy) tidak memakai
em/en dash gaya AI.

1. JANGAN pakai em dash (`—`, U+2014) atau en dash (`–`, U+2013).
   Ganti hyphen ASCII biasa (`-`, U+002D).
2. Jangan berlebihan menyambung klausa dengan ` - `; lebih baik titik,
   koma, titik dua, atau kurung.
3. Judul: titik dua atau frasa utuh lebih jelas dari
   `Judul - Subjudul` berulang.
4. Referensi: `path: penjelasan` atau `path - penjelasan` dengan hyphen
   biasa (bukan `—` / `–`).
5. Bullet markdown dan `| --- |` di tabel tetap boleh (itu sintaks).
6. Berlaku juga untuk string UI (toast, label, hint, dialog) - jangan
   copy-paste `—` dari model AI ke kode.

### Nada copywriting UI (wajib)

Copy UI (label, hint, empty state, toast, dialog, alert) memakai bahasa
santai yang memanusiakan, seperti warga Sambas ngobrol. Bukan bahasa
prosedural kaku. Poin:

1. Sapaan ke pengguna: **kamu** (jangan "Anda"). Bentuk posesif ringkas
   boleh: `usulanmu`, `emailmu`, `katamu`.
2. Ajakan dibaca seperti bicara: tambah `ya` atau `aja` di akhir kalimat
   instruksi bila cocok (`Masuk dulu ya sebelum mulai diskusi`,
   `Tulis dulu pertanyaan atau cerita kamu ya`).
3. "Anda bisa..." jadi `Kamu bisa...`. "Masukkan..." jadi `Tulis...`.
   "Jelaskan konteks..." jadi `Ceritakan...`.
4. Sebut manfaat atau hasil, bukan proses sistem:
   - BAD: `Jelaskan pertanyaan atau konteks bahasa yang ingin didiskusikan`
   - GOOD: `Tulis pertanyaan atau cerita kamu di sini. Semakin jelas konteksnya, semakin mudah warga membantu.`
5. Error tetap informatif: sebab + aksi, tetap santai:
   - BAD: `Deskripsi wajib diisi`
   - GOOD: `Tulis dulu pertanyaan atau cerita kamu ya`
6. Kalimat moderat: hanya satu partikel santai (`ya` / `aja`) per kalimat.
   Jangan sampai terdengar menggurui atau berlebihan.
7. Judul halaman, label aksi baku (`Kirim`, `Batal`, `Hapus`, `Coba lagi`,
   `Masuk`), dan status (`Menunggu pengecekan`) tetap netral; yang dibuat
   santai adalah kalimat penjelas, hint, empty state, dan pesan.

Referensi implementasi:
`mobile/lib/features/discussion/presentation/pages/create_discussion_page.dart`,
`mobile/lib/features/onboarding/presentation/pages/onboarding_page.dart`.

## Busy aksi multi-tombol (wajib)

Jika satu layar punya **lebih dari satu aksi submit** (contoh: Masuk
email + Google + Facebook):

1. State pakai `pendingAction` (enum), bukan boolean `isSubmitting` saja.
2. Spinner / "Memproses..." **hanya** di tombol yang diklik.
3. Tombol & input lain: **disabled** (boleh pudar), **tanpa** spinner.
4. Arah simetris: Google loading → Masuk disabled; Masuk loading →
   Google disabled. Widget: `BusyAwareIcon`, `AuthPendingAction`.

Layar satu CTA (lupa password, ganti password) boleh tetap
`isSubmitting` boolean.

### Audit pola lama (jalankan di `mobile/`)

Bukan migrasi DB. Ini query untuk menemukan anti-pola di kode:

```bash
# Tombol sosial yang masih pakai isSubmitting global sebagai isLoading
rg -n 'isLoading:\s*state\.isSubmitting' lib/

# Prefix spinner yang ikut semua aksi (cek manual: multi-CTA?)
rg -n 'prefix:.*isSubmitting' lib/features/

# Referensi benar (pendingAction per aksi)
rg -n 'AuthPendingAction|pendingAction ==' lib/features/auth/
```

Setelah patch login/register: hit pertama harus kosong (atau hanya
layar single-CTA yang sah).

## Format tanggal-waktu UI (wajib)

Semua timestamp yang ditampilkan ke user (komentar, riwayat perubahan,
dsb.) pakai helper `formatDateTime` / `formatDateTimeIso` di
`lib/core/utils/format_datetime.dart`.

| Pola | Contoh | Dipakai untuk |
| --- | --- | --- |
| `d MMM yyyy HH:mm` | `17 Nov 2026 21:00` | Default UI |
| Relatif (`formatRelativeCompact`) | `baru saja`, `5 menit`, `11 jam`, `1 hari`, lalu `21 Sep` (≥7 hari) | Feed, komentar, diskusi, antrean |
| Relatif + "lalu" (`formatRelativeAgo`) | `5 menit lalu`, `2 jam lalu`, `3 hari lalu`, lalu `21 Sep 2026` | Detail diskusi |

Aturan:

1. JANGAN format tanggal inline di widget - selalu lewat helper.
2. Bulan singkat Indonesia: Jan Feb Mar Apr Mei Jun Jul Agu Sep Okt Nov Des.
3. Hari tanpa zero-pad; jam 24 jam zero-pad (`09:05`).
4. Parse ISO API → `toLocal()` dulu (helper sudah mengurus ini).
5. Nilai null/invalid → string kosong (bukan `-`, kecuali copy halaman
   eksplisit minta placeholder).
6. Setelah i18n aktif: helper mengikuti locale UI (`id` / `id_SBS`);
   jangan `DateFormat` Inggris diam-diam. Lihat `MOBILE-I18N.md`.
7. Waktu relatif **dilarang** singkatan Inggris (`m`, `h`, `d`) atau
   singkatan ambigu (`mnt`, `hr`): `1h` dibaca "1 hari", `1d` dibaca
   "1 detik". Tulis kata utuh: `menit`, `jam`, `hari`.

## 1. Tech Stack

| Layer | Pilihan | Alasan |
| --- | --- | --- |
| Framework | Flutter (stable channel, Dart SDK ^3.x) | Satu kode, Android + iOS |
| Arsitektur | Clean Architecture, feature-first (3 lapis per fitur) | Sama filosofi dengan backend (base-stack Section 2); skala fitur tanpa campur aduk |
| State management | flutter_riverpod + riverpod_annotation (codegen) + flutter_hooks + hooks_riverpod | Provider terurut per lapisan; hooks memangkas boilerplate widget |
| Functional error | fpdart (`Either<Failure, T>`) | Repository/usecase mengembalikan hasil eksplisit, tanpa exception liar |
| Networking | dio + retrofit (codegen) | Datasource deklaratif via anotasi; interceptor untuk auth |
| Model / DTO | freezed + json_serializable | Immutable + fromJson/toJson tergenerate |
| Codegen | build_runner | Satu perintah untuk retrofit/freezed/riverpod/envied |
| Routing | go_router | Declarative, redirect auth, deep-link ready ([15-mobile-deeplink.md](./15-mobile-deeplink.md)) |
| UI kit | forui (+ forui_hooks) + gap | Konsisten dengan jnn_mobile; komponen siap pakai |
| i18n | `flutter_localizations` + `intl` + ARB (`gen-l10n`) | Multi-bahasa UI; kontrak `MOBILE-I18N.md` |
| Loading placeholder | skeletonizer (`Skeletonizer` + `ShimmerEffect`) | Skeleton saat fetch; lihat Section 5c |
| Local storage | shared_preferences (via `AuthTokenStorage`) | Token sesi; sensitif cukup untuk access/refresh + flag isAuth |
| Env compile-time | envied (`.env` + flavor) | Secret tidak masuk repo |
| Flavor | flutter_flavorizr (staging / production) | Dua app berdampingan di satu HP |
| Ikon app | flutter_launcher_icons (per flavor) | Icon + nama dibedakan per flavor |
| Testing | flutter_test (+ widget test per halaman kunci) | Minimal: usecase unit + widget test form |
| Lint | flutter_lints + analysis_options.yaml | Konsistensi antar kontributor |

Firebase/FCM **tidak dipakai fase awal** (kamus belum butuh push).
Catat sebagai upgrade path; jangan dipasang spekulatif.

## 2. Prinsip Arsitektur (3 lapis per fitur)

Arah dependency selalu ke dalam, sama seperti backend:

```text
presentation (pages/notifier/state)
   → domain (entities/failures/repositories interface/usecases/providers)
       → data (datasources retrofit/models DTO/repositories impl/providers)

core/  = lintas fitur (network, router, constants, widgets umum)
shared/ = halaman/util lintas fitur (splash, dev tool)
```

- **domain**: murni Dart. Entity, `Failure` per fitur, interface repository,
  usecase (`call(params)`), plus provider tier domain.
- **data**: retrofit datasource (anotasi `@RestApi`), DTO freezed,
  repository impl yang memetakan `ApiResponse`/DioException ke `Either`,
  plus provider tier data.
- **presentation**: halaman (hook widget), state class `copyWith`,
  `Notifier` riverpod, plus provider tier presentation. List data
  selalu compact (`FTile`/`FTileGroup` - Section 5a).

Komunikasi antar fitur lewat provider yang di-export, bukan import internal
ke file privat fitur lain (kejiran dengan aturan Section 4 backend).

## 3. Struktur Folder

```text
lib/
├── core/
│   ├── constants/env.dart            # envied: API host, ImageKit key
│   ├── models/api_response.dart      # envelope sambasku (Section 6)
│   ├── network/
│   │   ├── sambasku_api_client.dart  # Dio + interceptor (singleton)
│   │   ├── auth_token_storage.dart   # token + isAuth (singleton)
│   │   ├── interceptors/auth_interceptor.dart
│   │   └── network_providers.dart    # dioProvider dsb.
│   ├── router/
│   │   ├── app_router.dart           # agregasi + redirect auth
│   │   └── route_definer.dart        # path + name per route
│   ├── services/                     # device id, dsb (bila perlu)
│   ├── utils/format_datetime.dart    # format tanggal UI (ikut locale)
│   ├── i18n/                         # registry + locale controller (MOBILE-I18N.md)
│   └── widgets/                      # widget generik lintas fitur
│
├── l10n/                             # ARB: app_id.arb, app_id_SBS.arb
│   └── (generated AppLocalizations)
├── shared/
│   ├── widgets/attachment_images_field.dart  # UI lampiran kanonik (§9.2)
│   ├── widgets/thread_message.dart           # UI thread komentar/balasan (§9.3)
│   ├── widgets/user_avatar.dart              # Avatar lingkaran kanonik (§9.3)
│   ├── widgets/small_button.dart             # Tombol kecil area sempit (§9.4)
│   ├── utils/image_sheet_drawer.dart         # sheet Kamera/Galeri
│   ├── splash/            # cek sesi → arahkan login/beranda
│   ├── pages/ widgets/ utils/
│   └── dev_tool/          # network monitor, storage inspector (debug)
│   # CDN: ImageKitUploader di
│   # features/contribution/data/datasources/imagekit_uploader.dart
│
├── features/
│   ├── auth/
│   │   ├── auth_router.dart
│   │   ├── domain/
│   │   │   ├── entities/auth_session.dart
│   │   │   ├── failures/auth_failure.dart
│   │   │   ├── repositories/auth_repository.dart     # abstract interface
│   │   │   ├── usecases/login_use_case.dart
│   │   │   └── providers/auth_domain_providers.dart
│   │   ├── data/
│   │   │   ├── datasources/auth_remote_datasource.dart   # retrofit + .g.dart
│   │   │   ├── models/                                   # DTO freezed + .g/.freezed
│   │   │   ├── repositories/auth_repository_impl.dart
│   │   │   └── providers/auth_data_providers.dart
│   │   └── presentation/
│   │       ├── pages/login_page.dart
│   │       ├── models/auth_login_state.dart
│   │       └── providers/auth_login_providers.dart       # Notifier
│   │
│   ├── dictionary/        # pencarian + detail kata + beranda miss
│   ├── contribution/      # submit kata (login & anonim), kontribusi media
│   ├── profile/           # profil + logout
│   └── ... (fitur baru menyusul, pola sama)
│
├── flavors.dart           # enum Flavor + F (title/nama per flavor)
├── app.dart               # MaterialApp.router + ProviderScope
└── main.dart              # bootstrap: flavor, ApiClient, DeviceId
```

`main.dart` tetap ramping: init flavor, `SambaskuApiClient.instance`,
DeviceIdService, lalu `runApp(ProviderScope(child: App()))`.

## 4. Konvensi Penamaan File

| Tipe | Konvensi | Contoh |
| --- | --- | --- |
| Halaman | `*_page.dart` | `login_page.dart` |
| State halaman | `*_state.dart` (folder models presentation) | `auth_login_state.dart` |
| Provider tier | `<fitur>_data_providers.dart` / `_domain_providers.dart` / `_<halaman>_providers.dart` | `auth_data_providers.dart` |
| Entity | `*.dart` nomina domain | `auth_session.dart` |
| Failure | `<fitur>_failure.dart` | `dictionary_failure.dart` |
| Repository interface | `*_repository.dart` | `auth_repository.dart` |
| Repository impl | `*_repository_impl.dart` | `auth_repository_impl.dart` |
| Usecase | `*_use_case.dart` + `class XUseCase` | `login_use_case.dart` |
| Datasource | `*_remote_datasource.dart` (+ `.g.dart`) | `auth_remote_datasource.dart` |
| DTO | `*_dto.dart` (+ `.g.dart` + `.freezed.dart`) | `login_response_dto.dart` |
| Router per fitur | `<fitur>_router.dart` | `dictionary_router.dart` |
| File codegen | `*.g.dart`, `*.freezed.dart` (TIDAK diedit manual) | |

Folder fitur: `features/<nama_fitur>/` (snake_case, singular: `auth`,
`dictionary`, `contribution`).

## 5. Pola Lengkap Satu Fitur (contoh: auth)

Alur dependency dan bentuk tiap file. Semua fitur meniru pola ini.

**1. Entity + Failure (domain):**

```dart
class AuthSession {
  const AuthSession({required this.userId, required this.username, required this.role});
  final String userId; final String username; final String role;
}

class AuthFailure {
  const AuthFailure(this.message);      // + subkelas spesifik bila perlu
  final String message;
}
```

**2. Repository interface (domain):** semua method balikan `Either`.

```dart
abstract interface class AuthRepository {
  Future<Either<AuthFailure, AuthSession>> login({
    required String email, required String password,
  });
}
```

**3. Usecase:** satu aksi, `call(params)`, validasi/trim di sini.

```dart
class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<Either<AuthFailure, AuthSession>> call(LoginParams params) =>
      _repository.login(email: params.email.trim(), password: params.password);
}
```

**4. Provider 3 tier (codegen `@riverpod`, `part '*.g.dart'`):**

```dart
// data: auth_data_providers.dart
@riverpod
AuthRemoteDatasource authRemoteDatasource(Ref ref) =>
    AuthRemoteDatasource(ref.watch(dioProvider));

@riverpod
AuthRepository authRepository(Ref ref) =>
    AuthRepositoryImpl(ref.watch(authRemoteDatasourceProvider),
                        ref.watch(authTokenStorageProvider));

// domain: auth_domain_providers.dart
@riverpod
LoginUseCase authLoginUseCase(Ref ref) =>
    LoginUseCase(ref.watch(authRepositoryProvider));
```

**5. State (presentation/models):** copyWith manual dengan `clearX`.
Multi-aksi auth: `pendingAction` + getter `isSubmitting`.

```dart
enum AuthPendingAction { email, google, facebook }

class AuthLoginState {
  const AuthLoginState({this.pendingAction, this.errorMessage, this.session});
  final AuthPendingAction? pendingAction;
  final String? errorMessage;
  final AuthSession? session;
  bool get isSubmitting => pendingAction != null;

  AuthLoginState copyWith({
    AuthPendingAction? pendingAction,
    bool clearPendingAction = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    AuthSession? session,
    bool clearSession = false,
  }) =>
    AuthLoginState(
      pendingAction:
          clearPendingAction ? null : pendingAction ?? this.pendingAction,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      session: clearSession ? null : session ?? this.session,
    );
}
```

**6. Notifier (presentation/providers):**

```dart
@riverpod
class AuthLoginNotifier extends _$AuthLoginNotifier {
  @override
  AuthLoginState build() => const AuthLoginState();

  Future<void> submit({required String email, required String password}) async {
    state = state.copyWith(
      pendingAction: AuthPendingAction.email,
      clearErrorMessage: true,
      clearSession: true,
    );
    final result = await ref.read(authLoginUseCaseProvider)(LoginParams(email: email, password: password));
    result.match(
      (failure) => state = state.copyWith(
        clearPendingAction: true,
        errorMessage: failure.message,
        clearSession: true,
      ),
      (session) => state = state.copyWith(clearPendingAction: true, session: session),
    );
  }
  }
}
```

**7. Halaman:** hook consumer widget, UI forui, skeletonizer saat load.

```dart
class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authLoginNotifierProvider);
    final email = useTextEditingController();
    // ... FButton (forui) disable saat state.isSubmitting, pesan error
  }
}
```

## 5a. List UI: compact by default (WAJIB)

Daftar data di mobile (hasil search, bookmark, komentar, miss, kontribusi,
menu profil, dll.) **selalu compact**. Jangan pakai card tebal per baris
kecuali konten memang butuh ruang (form, media preview, empty/error state).

Aturan:

1. Prefer `FTile` / `FTileGroup` (Forui) - bukan `FCard` + `InkWell` per item.
2. Satu baris: `title` + `subtitle` singkat; aksi sekunder di `suffix`
   (ikon kecil 16-18, bukan tombol penuh).
3. Spacing antar item: `Gap(6)` / `ListView.separated` - hindari padding
   vertikal besar atau `bottom: 8+` di setiap card.
4. Komponen interaktif di konteks list (vote, dll.) pakai `compact: true`.
5. `InkWell` Material hanya kalau sudah ada ancestor `Material` - di pohon
   Forui (`FScaffold`/`FCard`) biasanya tidak ada; itu sebab prefer `FTile`
   (tappable sendiri) atau `GestureDetector`.

Preseden: `home_search_page.dart` (`_WordResultTile`), `profile_page.dart`
(`FTileGroup`), `bookmark_page.dart` (list bookmark).

### 5e. List item terkait aksi/feedback user: ikuti layout feed Home (WAJIB)

Item yang mewakili **aksi user** (vote, komentar, usulan, revisi, review, diskusi,
laporan) - **bukan** data master generik (kata, kategori, tag) - **wajib** mengikuti
tampilan `ActivityFeedTile` (`activity_feed_tile.dart`):

- Avatar kiri + nama peran (Kontributor/Verifikator) + timestamp relatif.
- Body ringkas (max 2 baris, ellipsis).
- Meta baris: tipe aksi + konteks (lemma, kata, thread).
- Footer kompakt: `VoteButtons` upvoteOnly (Saya juga ingin tahu / Sudah pas).
- Divider tipis antar item.

Item master (daftar kata A-Z, hasil search kata, bookmark kata, kategori) **tetap**
pakai `FTile` / `FTileGroup` compact biasa (Section 5a).

## 5b. Pilihan singkat: chip, bukan tombol blok (WAJIB)

Satu nilai dari beberapa label pendek (alasan laporan, jenis entri, filter
provider) ditampilkan sebagai **chip**, bukan deretan `FButton`.

```dart
Wrap(
  spacing: 6,
  runSpacing: 6,
  children: [
    for (final opt in options)
      GestureDetector(
        onTap: () => onChanged(opt.value),
        child: FBadge(
          variant: value == opt.value
              ? FBadgeVariant.primary
              : FBadgeVariant.secondary,
          child: Text(opt.label),
        ),
      ),
  ],
)
```

- Terpilih: `FBadgeVariant.primary`. Tidak terpilih: `secondary`.
- `Wrap` + jarak 6. Chip mengikuti lebar label, tidak membentang satu baris.
- `FButton` tetap untuk aksi (Kirim, Simpan, Batal), bukan untuk memilih opsi.
- Daftar panjang yang butuh judul + subjudul tetap `FTile` / `FTileGroup`
  (misalnya pemilih alasan usul edit). Chip untuk label pendek yang muat
  dibungkus.

Preseden: `_WordTypeChips` di `contribute_page.dart`, provider di
`share_image_explorer_sheet.dart`, alasan di `report_word_sheet.dart`.

## 5c. Loading UI: skeletonizer (WAJIB)

Saat data pertama / ganti item masih fetch, **jangan** spinner penuh di
tengah layar kosong (kecuali overlay aksi singkat seperti submit tombol).
Pakai `skeletonizer` agar kerangka layout tetap terbaca.

Pola kanonik (ikut tema Forui + Material brightness):

```dart
final muted = context.theme.colors.muted;
final isDark = Theme.of(context).brightness == Brightness.dark;
final shimmer = ShimmerEffect(
  baseColor: isDark
      ? muted.withValues(alpha: 0.35)
      : const Color(0xFFE7E7EA),
  highlightColor: isDark
      ? muted.withValues(alpha: 0.55)
      : const Color(0xFFF4F4F5),
  duration: const Duration(milliseconds: 1500),
);

return SkeletonizerConfig(
  data: SkeletonizerConfigData(effect: shimmer),
  child: IgnorePointer(
    child: Skeletonizer(
      enabled: true,
      child: /* layout mirip konten asli, teks dummy */,
    ),
  ),
);
```

Aturan:

1. Skeleton meniru **bentuk** konten akhir (list tile, kartu, form field),
   bukan kotak generik + `FCircularProgress` di tengah.
2. Bungkus `IgnorePointer` supaya shimmer tidak bisa di-tap.
3. Warna shimmer: zinc light `#E7E7EA` / `#F4F4F5`; dark = `muted` alpha.
4. Prefetch + `watch` item berikutnya bila ada sesi/halaman beruntun
   (contoh: sesi tinjau) supaya skeleton jarang muncul.
5. `FCircularProgress` tetap OK di tombol busy / overlay upload kecil.
6. **Jangan bungkus `FCircularProgress` dengan `SizedBox` / `ConstrainedBox`
   / `FittedBox` / `Transform.scale` hanya untuk mengecilkan spinner.**
   Constraint luar membuat animasi rotasi tidak stabil (terpotong /
   "melompat"). Pakai param resmi Forui:

   ```dart
   // ❌ animasi tidak stabil
   const SizedBox(height: 12, width: 12, child: FCircularProgress()),

   // ✅ ukuran lewat size variant (xs ≈ 12-14 touch)
   const FCircularProgress(size: .xs),
   // opsi lain: .sm .md (default) .lg .xl
   ```

   `Center(...)` / `Padding(...)` di sekitar spinner tetap boleh; yang
   dilarang adalah memaksa ukuran intrinsik widget.

Preseden:

- List: `review_queue_page.dart` (`_ListSkeleton`),
  `home_search_page.dart` (`_FeedSkeleton`),
  `notification_inbox_page.dart`
- Kartu sesi: `review_session_page.dart` (`_ReviewCardPlaceholder`)
- Field: `contribute_page.dart` (`_SelectFieldSkeleton`)

## 5d. FScaffold + SafeArea (WAJIB)

`FHeader` / `FHeader.nested` **sudah** membungkus dirinya dengan
`SafeArea(bottom: false)`. `FScaffold` menempatkan header dan content
sebagai sibling di `Column`, dan **tidak** memanggil
`MediaQuery.removePadding(removeTop: true)` pada area content.

Akibatnya: `FScaffold` + `header` + `child: SafeArea(...)` = **double top
inset** (status bar dihitung dua kali) - jarak app bar ke konten terlihat
berlebih.

Aturan:

1. `FScaffold` + `header: FHeader` - **jangan** wrap `child` dengan
   `SafeArea` (terutama top). Biarkan content langsung
   (`ListView` / `Center` / dll.).
2. `FScaffold` + `footer` / action bar bawah - pakai
   `SafeArea(top: false)` di footer agar home indicator aman.
3. `FScaffold` **tanpa** header (onboarding, full-bleed) - `SafeArea` di
   `child` OK (butuh top inset).
4. Shell tab (`FBottomNavigationBar`) - tab page pakai `FHeader` sendiri;
   content **tanpa** `SafeArea` top.
5. Bottom sheet / modal - `useSafeArea: true` atau `SafeArea` OK.

Preseden benar: `login_page.dart`, `register_page.dart`,
`word_detail_page.dart`; footer `SafeArea(top: false)` di
`contribute_page.dart`.

## 5e. Elevasi: tanpa shadow dekoratif (WAJIB)

Konsep visual sambasku adalah clean minimalism: permukaan datar, batas
lewat border tipis dan kontras warna (gaya Forui). Shadow mengubah feel
app, jadi jangan ditambahkan sesuka hati.

Aturan:

1. **Dilarang** `BoxShadow` / `elevation > 0` pada card, tile list, tile
   grid (Media Explorer, galeri), thumbnail, tombol, atau section.
2. Pemisah: border dari `context.theme.colors.border`, warna latar
   berbeda (`muted`/`secondary`), atau `Gap`.
3. Widget Material yang punya elevation bawaan (`AppBar`, `Material`,
   `Card`) set `elevation: 0` (preseden: `share_fullscreen.dart`).
4. **Boleh**: shadow bawaan lapisan melayang (sheet, dialog, popover,
   toast dari Forui); elemen desain di dalam gambar kartu bagikan
   (`share_card_canvas.dart`) karena bagian artwork PNG, bukan UI;
   overlay dev tool.
5. Teks di atas foto butuh kontras: pakai chip latar semi-transparan
   (mis. `Colors.black.withValues(alpha: 0.5)`), bukan shadow (preseden:
   kredit di `share_image_explorer_sheet.dart`).
6. Butuh shadow di luar daftar itu: diskusikan dulu.

## 5f. Tombol vote: urutan + copy (WAJIB)

Aturan:

1. **Vote turun di kiri, vote naik di kanan.** Berlaku di semua konteks:
   detail kata, komentar, feed diskusi, detail diskusi, swipe deck
   Kontribusi. Ikon tetap panah `arrowBigDown` / `arrowBigUp` (sudah
   dikenal user, jangan diganti ikon lain).
2. Selalu pakai `VoteButtons` (`features/vote/presentation/widgets/`);
   jangan susun pasangan tombol vote manual. Mode `upvoteOnly` hanya
   tombol naik.
3. Copy netral, bukan vonis: **"Sudah pas"** / **"Perlu dicek ulang"**
   (label swipe, `semanticsLabel`, feed `"{lemma}" sudah pas` /
   `"{lemma}" perlu dicek ulang`, tanpa kata kerja). Label jenis di feed:
   "Penilaian". Jangan "Setuju" / "Kurang setuju" / "Nilai".
4. Swipe tinjau verifikator (`Setujui` / `Tolak`, ikon check/x) bukan
   vote; aturan ini tidak berlaku di sana.

## 5g. Konsistensi UI lintas halaman (WAJIB)

Elemen UI yang fungsinya sama **wajib** tampak dan terletak sama di semua
halaman. Sebelum menambah tombol/kartu/overlay, cek dulu pola existing,
lalu tiru: widget, posisi, ukuran, style. Jangan bikin varian baru.

Pola yang sudah baku:

1. **Tombol mengambang di atas peta**: kolom kiri-atas (`Positioned` left
   12), back paling atas, aksi lain di bawahnya (`SizedBox(height: 8)`
   antar tombol), `IconButton` + style latar `theme.colors.background` +
   elevation 2 (shadow tipis fungsional). Kanan-atas dikosongkan untuk
   kompas MapLibre. Preseden: `pins_page.dart`, `wilayah_page.dart`.
2. **Kartu overlay di atas peta** (panel bawah, kartu tempat): radius 16 +
   border `theme.colors.border` + flat tanpa shadow dekoratif (Section 5e),
   margin 16 dari tepi. Preseden: `_PlaceCard` (`pins_page.dart`),
   `_BottomPanel` (`wilayah_page.dart`).
3. **Toggle tema** di halaman apapun: posisi & widget sama dengan halaman
   lain; ikon sun/moon Lucide 20.
4. Kartu list umum: ikuti Section 5a/5e (border flat, compact). Jangan
   mix radius, border, shadow, atau padding beda untuk kartu setara.

DoD: elemen setara dibandingkan dulu dengan halaman lain (buka 2 file),
posisi/radius/border/padding identik, tanpa varian baru.

Rule: `.cursor/rules/ui-consistency.mdc`.

## 6. Networking: kontrak sambasku

### Envelope standar (wajib dipahami semua fitur)

Backend memakai SATU bentuk response (`docs/api/api-base-stack.md` Section
13). Definisikan sekali di `core/models/api_response.dart`:

```dart
@freezed
class ApiResponse<T> with _$ApiResponse<T> {
  const factory ApiResponse.success({
    required bool success,
    required T? data,
    CursorMeta? meta,               // hanya endpoint list
  }) = ApiSuccess<T>;

  const factory ApiResponse.failure({
    required bool success,
    required String errorCode,      // "error_code" di JSON
    required String message,
    List<ApiErrorDetail>? details,
  }) = ApiFailure<T>;
}

@freezed
class CursorMeta with _$CursorMeta {
  const factory CursorMeta({
    required int limit,
    @JsonKey(name: 'next_cursor') String? nextCursor,
    @JsonKey(name: 'has_more') required bool hasMore,
  }) = _CursorMeta;
}
```

Aturan mapping di repository impl:
- `success == true` → `Either.right(entity)` (DTO → entity, BUKAN DTO bocor
  ke presentation)
- `success == false` → `Either.left(XFailure(message))`; `error_code` boleh
  disimpan untuk penanganan spesifik (tabel Section 11)
- `DioException` → map ke Failure generik (offline / timeout / 500)

### Datasource (retrofit)

```dart
@RestApi()
abstract interface class AuthRemoteDatasource {
  factory AuthRemoteDatasource(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) =
      _AuthRemoteDatasource;

  @POST('/api/v1/auth/login')
  Future<ApiResponse<LoginResponseDto>> login(@Body() LoginRequestDto body);

  @GET('/api/v1/words/search')
  Future<ApiResponse<List<WordSummaryDto>>> search(@Queries() Map<String, dynamic> query);
}
```

### Auth: client_type mobile (BEDA dari web)

Refresh token backend memakai **httpOnly cookie untuk web**; mobile TIDAK
bisa membaca cookie httpOnly, jadi backend menyediakan varian body
(lihat `http/auth/login-mobile.bru`):

- Login: `POST /api/v1/auth/login` + field `client_type: 'mobile'`
  → response berisi `refresh_token` di **body**
- Refresh: `POST /api/v1/auth/refresh` body `{ refresh_token, client_type: 'mobile' }`
  (rotasi: token lama mati, simpan yang baru)

### AuthInterceptor (pola jnn_mobile, disesuaikan)

- `onRequest`: sisipkan `Authorization: Bearer <accessToken>`
- `onError` 401: refresh SEKALI via `_refreshFuture` bersama (queue:
  beberapa request 401 bersamaan menunggu satu refresh), lalu retry;
  gagal refresh → clear token + `setIsAuth(false)` (redirect login oleh
  router)
- Timeouts: connect/receive/send 15 detik

### Pagination: cursor-based autoload (WAJIB)

Semua list backend memakai `?limit=&cursor=` + `meta.next_cursor` +
`meta.has_more`. TIDAK ADA page number.

Pola UI: **wajib autoload** via `infinite_scroll_pagination` (`PagedListView` /
`PagedSliverList`). Tombol "Muat lagi" manual **dilarang** untuk list utama
(halaman riwayat, feed, bookmark, notifikasi, vote, kontribusi, komentar,
antrean tinjau). Scroll listener manual (`ScrollController` + listener) **tidak
dipakai lagi** - library mengurus prefetch, retry, error state, dan virtualisasi
otomatis.

State list tetap dikelola Riverpod notifier (`items` + `hasMore` +
`isLoadingMore`); `PagingController` hanya lapisan UI. Jembatannya di
`core/widgets/paged_list_bridge.dart`:

- `createPagingController<T>(loadMore: ...)` di `initState`
  (ConsumerStatefulWidget). `loadMore` memanggil notifier; throw failure agar
  masuk `newPageErrorIndicatorBuilder` (retry tanpa kehilangan scroll).
- `pagingController.value = buildPagingState<T>(items: ..., hasMore: ...)`
  setiap build untuk sinkron snapshot Riverpod ke controller.
- Empty state di dalam `noItemsFoundIndicatorBuilder` harus widget biasa
  berukuran pasti (mis. `SizedBox(height: ...)` + `Center`), bukan `ListView`
  bersarang - `SliverFillRemaining` milik library tidak mendukung intrinsic
  dimension.
- List yang belum migrasi (feed, komentar per kata, search) mengikuti pola
  yang sama saat disentuh.

Skeleton/empty/error state first-load tetap pola existing (`Skeletonizer`,
section 5c).

## 7. Routing

- Tiap fitur punya `<fitur>_router.dart`: konstanta `RouteDefiner(path,
  name)` + `static final List<GoRoute> routes`
- `core/router/app_router.dart` mengagregasi semua, plus `redirect`:
  belum auth & di luar `/login` → login; sudah auth & di `/login` → splash
- Nama route: `'<Fitur>Router.<halaman>'` (mis. `DictionaryRouter.detail`)
- Detail kata butuh parameter id: path `/words/:id`, baca via
  `state.pathParameters['id']`

Route awal sambasku:

| Route | Halaman |
| --- | --- |
| `/login` | Login (email/password + Masuk dengan Google) |
| `/register` | Register (email/password + Daftar dengan Google) |
| `/register` | Register |
| `/` (beranda) | Pencarian + kartu "sedang dicari, belum ada artinya" (search-miss) |
| `/words/:id` | Detail kata (makna, contoh, pelafalan, gambar, relasi) |
| `/contribute` | Form usul kata baru (anonim atau login) |
| `/profile` | Profil, logout |

Form `/contribute`: **definisi** (uraian makna Indonesia) wajib; **padanan**
(satu kata/frasa setara) opsional via checkbox "Belum ada padanan kata
Indonesia" → `is_have_translation=false`, `translations: []`. Checkbox
"Belum tahu definisi" tetap butuh padanan (mutual exclusive: opsi no-padanan
disembunyikan). Aturan lengkap: `docs/api/01-api-tambah-kata.md`.

## 8. Flavor & Environment

- `flavors.dart`: `enum Flavor { staging, production }` + class `F`
  (`F.name`, `F.title`, `F.isStaging`)
- flutter_flavorizr membuat dua target: nama app
  "SambasKu Staging" / "SambasKu"
- Logo per flavor (pola `jnn_mobile`):
  `assets/icons/logo.png` (production) dan
  `assets/icons/logo.staging.png` (pita STG). Path runtime:
  `F.logoAsset`. Widget `BrandLogo` (ikon kotak) dipakai splash /
  onboarding / about. Halaman login memakai `BrandWordmark` dari
  `assets/icons/logo_horizontal.webp` (wordmark landscape; judul
  "SambasKu" tidak diulang karena sudah di aset). Flavor staging
  menampilkan teks kecil "Staging" di bawah wordmark.
- Ikon launcher di-generate `flutter_launcher_icons` dari file yaml
  `flutter_launcher_icons-staging.yaml` /
  `flutter_launcher_icons-production.yaml` (bukan dari Flutter default).
- `core/constants/env.dart` dengan envied membaca `.env` (git-ignored,
  ada `.env.example`):

```text
SAMBASKU_API_HOST_STAGING=https://sambasku-staging.iamutaki.com
SAMBASKU_API_HOST_PRODUCTION=      # diisi saat production rilis
IMAGEKIT_PUBLIC_KEY=public_xxx
IMAGEKIT_URL_ENDPOINT=https://ik.imagekit.io/apinull
```

Pemilihan host per flavor di `env.dart` (switch `F.appFlavor`).
TIDAK ADA host hardcode di datasource.

### Pemilihan host API oleh user (WAJIB)

Tiga host API (tier failover) tidak pernah disebut ke user dengan istilah
"tier". Label yang dipakai: **Cloudflare**, **Deno Deploy**, **Render**.

- Setting ada di halaman Profil, grup "Tampilan & bantuan", tile **Server**
  (suffix `Otomatis` / nama host + ikon kunci).
- Pindah host = keputusan penting → **bottom sheet** (`showModalBottomSheet`,
  `useRootNavigator: true`) berisi `FTileGroup` + tombol **Uji semua**.
  Jangan `showDialog`/`AlertDialog`, jangan set `shape:`/`clipBehavior:`.
- Uji ping memakai `GET /api/v1/ping` (tanpa auth, tanpa DB; field `data.host`
  membuktikan tier yang melayani), timeout 8 s (`kHealthProbeTimeout`).
- "Otomatis" = `setForcedTier(null)`; memilih host = `setForcedTier(index)`,
  persist di `SharedPreferences` key `preferredApiTier` (`-1` = Otomatis).
- Selama terkunci, cascade failover otomatis **mati** (`advanceTier()` return
  null saat `forcedTierIndex != null`). Konsekuensi ini wajib disebut di sheet.
- Staging hanya punya satu host → `hasFallbacks == false` → tile nonaktif.

Titik masuk kode: `mobile/lib/features/profile/presentation/widgets/api_host_tile.dart`,
`mobile/lib/core/network/failover/api_host_resolver.dart`.

## 9. Upload Gambar

Dua jalur (privasi berbeda):

### 9.0 Gambar kata + avatar (publik - GitHub)

1. Multipart ke API (Bearer):
   - Kata: `POST /api/v1/images?purpose=word` → `{ url, provider, provider_file_id, sha }`
   - Avatar: `POST /api/v1/users/me/avatar` → `{ avatar_url }`
2. URL kanonik = jsDelivr; tampilan resize lewat wsrv.nl (helper klien).
3. Kirim `url` + `provider_file_id` (+ `sha` opsional) di body submit kata.
4. 503 `PUBLIC_IMAGE_UPLOAD_UNAVAILABLE` jika `PUBLIC_IMAGE_GITHUB_*` kosong.

**Alternatif - Media Explorer (stock, tanpa upload):**

1. Sheet sumber gambar (mode Lengkap / usul edit): opsi **Media Explorer**
   di samping Kamera/Galeri → `showShareMediaExplorer` (foto saja).
2. Setelah pilih: kirim `provider` (`pixabay|openverse|unsplash`) + `url` CDN +
   (legacy `pexels|wikimedia` tetap diterima untuk data lama)
   `provider_file_id` = id item + `alt_text` atribusi. **Tanpa**
   `POST /images`.
3. Kontrak API: `docs/api/01-api-tambah-kata.md` (images[] stock).

### 9.1 Laporan bug / bukti verifikator (privat - ImageKit)

Sama seperti web admin (base-stack Section 8 backend + bukti staging):

1. Ambil token:
   - Bukti verifikator (login): `GET /api/v1/admin/images/upload-token`
     (Bearer) → folder `/verifier-applications`
   - Laporan bug (tamu + login): `GET /api/v1/bug-reports/upload-token`
     → folder `/bug-reports`
2. Upload file LANGSUNG ke `upload_endpoint` (multipart): `file`,
   `token`, `signature`, `expire`, `publicKey`, `fileName`, `folder=…`
3. Respons → `fileId` + `url`
4. Kirim `url` + `provider_file_id` di body submit (bukan binary)

**Token upload ImageKit SEKALI PAKAI** (terbukti di staging: request kedua dengan
token sama ditolak). Satu token per file; expire 30 menit.
Implementasi CDN: `features/contribution/data/datasources/imagekit_uploader.dart`
(`ImageKitUploader`) - Dio terpisah tanpa auth interceptor backend
(host ImageKit, bukan API host). Gambar kata memakai
`WordImageUploadService` → `POST /api/v1/images`.

### 9.2 Komponen UI lampiran gambar (wajib)

Semua form yang lampirkan gambar **WAJIB** memakai:

- `shared/widgets/attachment_images_field.dart` (`AttachmentImagesField`)
- `shared/utils/image_sheet_drawer.dart` (`showImageSheetDrawer`)

**Dilarang** di page baru / saat menyentuh ulang form lama:

- `IconButton` Material ad-hoc untuk tambah/hapus thumb
- `ImagePicker.pickMultiImage` langsung di page
- Ukuran thumb / gaya tombol yang berbeda antar fitur

Spesifikasi visual (jangan diubah per fitur):

- Thumb **88×88**, `ClipRRect` radius 8, `Wrap` spacing/runSpacing 8
- Tombol **Tambah**: Forui `FButton` outline + ikon `imagePlus`
- Hapus: badge bulat destructive + `x` (offset pojok)
- Overlay upload: gelap + `FCircularProgress`; error: overlay merah + alert
- Caption: `Kamera/galeri · maks N MB · hingga N`

Behavior:

- Upload **segera** setelah pilih (bukan tunda sampai submit)
- Kompresi post-pick: WebP quality **80**, max **720×720** via
  `flutter_image_compress` (`compressImageForUpload` di
  `shared/utils/compress_image_for_upload.dart`; fallback JPEG bila WebP
  tidak didukung). Konstanta `kPhotoPickMaxWidth` / `kPhotoPickMaxHeight` /
  `kPhotoPickQuality` di `shared/utils/photo_pick_constants.dart`
- Avatar: pick sumber longgar (`kAvatarPickMaxWidth/Height` 1600) → crop
  1:1 → export **720×720** WebP (`crop_profile_photo.dart`)
- File picker (`FilePicker`) ikut di-kompres WebP post-pick
- **Gambar kosakata (kontributor):** upload ImageKit folder `/words`
  (staging). GET publik men-redact URL ImageKit belum diverifikasi
  (`placehold.co` di wire). Mobile **tidak** menampilkan URL itu -
  ganti asset lokal + blur konten kekerasan; lihat
  [`BLUR_IMAGE_MOBILE.md`](BLUR_IMAGE_MOBILE.md). Stock Media Explorer
  langsung verified.
- Token sekali pakai per file (inject lewat callback `upload`)
- `IMAGE_UPLOAD_UNAVAILABLE` → sembunyikan/disable field
- Gate auth (jika wajib): tombol disabled + hint + CTA **Masuk**
  (contoh: usul kata). Jangan diam-diam hilangkan field tanpa penjelasan.

Perbedaan produk (max count, folder/token, guest vs login) lewat
**parameter** widget / inject `upload`, bukan UI beda.

Wrapper fitur kata: `ContributeImagesField` (max 3, ImageKit staging
`/words`). Laporan masalah memakai `AttachmentImagesField` langsung
(max 4, token publik `/bug-reports`).

### 9.3 Komponen UI thread komentar / balasan (wajib)

Semua thread pesan (komentar kata, balasan ruang diskusi, dan
thread serupa) **WAJIB** memakai:

- `shared/widgets/thread_message.dart`
  - `ThreadMessageRow` - baris pesan (avatar + peran + divider + body)
  - `ThreadComposer` - field + Kirim
  - `ThreadLoginPrompt` - prompt masuk
- `shared/widgets/user_avatar.dart` - avatar lingkaran kanonik

Referensi layout kanonik: sheet komentar di detail kata
(`WordCommentsSection` → komponen shared di atas).

**Dilarang** di page baru / saat menyentuh ulang thread lama:

- `_ReplyRow` / `_CommentRow` / composer Row ad-hoc per fitur
- `IconButton` trash ukuran beda, badge layout beda, meta tanggal
  di baris terpisah dari username
- Composer horizontal (field + Kirim sebaris) yang menyimpang dari
  pola kolom kanonik

Spesifikasi visual (jangan diubah per fitur):

- Header penulis (wajib):
  ```
  [Avatar] Display Name
           Kontributor | Verifikator (+ badge)
  --------------------------
  body…
  ```
- Avatar: `UserAvatar` 36px (`shared/widgets/user_avatar.dart`);
  data dari `avatar_url` wire
- Display name: `typography.sm` + `FontWeight.w700`; linkable →
  `primary`
- Peran: selalu satu dari `Kontributor` / `Verifikator`
  (`is_verifier`); verifikator pakai `VerifiedBadgeIcon` + success
- Tanggal + meta ekstra (`Disematkan`, status hapus) di bawah peran
  (font 11, muted) - **bukan** baris meta `username · tanggal` lama
- Body: `typography.sm`, `height: 1.35`; redacted → italic + muted
- Pemisah tipis (`Divider`) antara header dan body
- Hapus: InkWell + ikon `trash` 14px (bukan `IconButton` Material besar)
- Composer: `FTextField` multi-baris (1-3) + `FButton` Kirim
  **align kanan** di bawah field; label submitting `Mengirim...`
- Login: teks muted + `FButton` outline **Masuk**
- Highlight opsional (`highlighted: true`) untuk pin - border primary
  alpha 0.35 + padding 10; teks `Disematkan` lewat `metaParts`
  (bukan `FBadge`); peran verifikator **hanya** lewat `isVerifier`,
  jangan dobel di `metaParts`

Perbedaan produk (vote footer, pin highlight, copy hint composer)
lewat **parameter** widget / `footer`, bukan UI beda.

### 9.4 Tombol kecil area sempit (kanonik)

Forui tidak punya varian "small button" tingkat komponen; `FButton` hanya
punya `FButtonSizeVariant.sm`/`xs` per-instance. Supaya ukuran dan gaya
tidak beda-beda antar fitur, semua tombol kecil di area compact (header
kartu, baris aksi, meta row) **WAJIB** memakai:

- `shared/widgets/small_button.dart` (`SmallButton`) - pembungkus
  `FButton` `FButtonSizeVariant.xs` + default `outline`.

```dart
SmallButton(
  label: 'Edit',
  onPress: () => context.push('/edit-profile'),
  // opsional: variant: FButtonVariant.primary, prefixIcon: FLucideIcons.pen
)
```

**Dilarang** di page baru / saat menyentuh ulang area lama:

- `FButton(size: FButtonSizeVariant.xs, ...)` manual berulang di page
  (ukuran/padding bisa melenceng antar fitur)
- `IconButton` Material ad-hoc untuk aksi berlabel
- Tinggi/padding tombol custom sendiri

Catatan: chip pilihan tetap ikut Section 5b (`FBadge`), bukan
`SmallButton`. Referensi pemakaian: header profil publik
(`public_profile_page.dart` tombol Edit).

## 10. Strategi Testing

| Level | Target | Alat |
| --- | --- | --- |
| Unit | usecase (mock repository interface) + mapper DTO→entity | flutter_test |
| Widget | form kunci (login, contribute): state submitting/error/sukses | flutter_test + ProviderScope override |
| Integration (opsional) | repository impl vs API staging | dio asli + staging host |

Aturan: tiap usecase baru wajib unit test; tiap halaman form minimal 1
widget test (sukses + gagal). Jalankan `flutter test` di CI.

## 11. Mapping error_code → Perlakuan UI

| error_code (backend) | HTTP | Perlakuan mobile |
| --- | --- | --- |
| `VALIDATION_ERROR` | 400 | Tampilkan `details[].field` inline per field form; ringkas toast "Periksa kembali isian..." boleh |
| `INVALID_CREDENTIALS` / `UNAUTHORIZED` / `TOKEN_EXPIRED` | 401 | Form-level: `showAppErrorSheet`; interceptor handle refresh |
| `FORBIDDEN` | 403 | Sembunyikan aksi khusus role; pesan tanpa hak via sheet bila dari submit |
| `*_NOT_FOUND` | 404 | Empty state halaman (bukan sheet) |
| `EMAIL_ALREADY_EXISTS` dll (field-bound) | 409 | Inline di field terkait |
| Envelope form-level (409/4xx/5xx pesan `errorMessage` notifier) | * | `showAppErrorSheet` - jangan `FAlert` sticky di form |
| `RATE_LIMITED` | 429 | `showFToast` "coba lagi nanti" (+ `Retry-After` bila ada) |
| `IMAGE_UPLOAD_UNAVAILABLE` | 503 | Sembunyikan fitur upload gambar |
| `INTERNAL_ERROR` | 500 | Sheet pesan generik + retry |

### Kanal feedback (wajib seragam)

| Situasi | Widget / API |
| --- | --- |
| Error form-level setelah submit (OTP salah, login gagal, usulan gagal, dll.) | `showAppErrorSheet` di `mobile/lib/shared/utils/error_bottom_sheet.dart` via `ref.listen` + `clearError` saat sheet ditutup |
| `RATE_LIMITED`, sukses singkat, batal social sign-in | `showFToast` |
| Validasi per-field | Inline di field |
| Load gagal / empty list-halaman | `FAlert` atau empty state di body (bukan sheet) |

Jangan menempelkan `FAlert` destructive di bawah field OTP/form submit: itu menggeser layout. Sheet menjaga posisi tombol tetap.

Katalog lengkap: `api/ERROR_CODES.md` (satu sumber kebenaran; jangan
menduplikasi daftar di mobile, cukup perlakuan umum per kelompok).

## 12. Urutan Fitur Mobile (roadmap)

1. **Bootstrap**: scaffold proyek + flavor + env + core (network, router,
   token storage) + splash + login/register (`00-api-auth.md`)
2. **Dictionary**: beranda + pencarian 2 arah (`search_in`) + infinite
   scroll cursor + detail kata
3. **Beranda miss**: kartu "sedang dicari" (`GET /search-misses`) + CTA
   kontribusi
4. **Kontribusi anonim**: form usul kata (`POST /contributions/words`)
   + status pending review di UI
5. **Kontribusi login**: media (pelafalan/gambar/contoh) pada kata
   existing + upload gambar ImageKit
6. **Profil**: info user, logout (revoke refresh)
7. **Google sign-in** (`docs/mobile/13-mobile-auth-google.md`; API
   `24-api-auth-google.md`) - tombol di login dan daftar
8. **Facebook sign-in** (`docs/mobile/19-mobile-auth-facebook.md`; API
   `29-api-auth-facebook.md`) - tombol di bawah Google

## 13. i18n (multi-bahasa) - wajib untuk modul baru

Kontrak penuh: [`docs/mobile/MOBILE-I18N.md`](./MOBILE-I18N.md).
Selaras kode locale dengan web (`id` ↔ `id`, `id_SBS` ↔ `id-SBS`).

| Item | Aturan |
| --- | --- |
| Locale V1 | `id` (default), `id_SBS` via ARB + `gen-l10n` |
| First launch | Wajib pilih bahasa (`sk_locale_chosen`) sebelum/onboarding langkah 0 |
| Pengaturan | Halaman `/settings`: bahasa, tampilan, tentang, laporkan masalah |
| Profil | Identitas + aktivitas + akun; pintu "Pengaturan" (bukan semua preferensi) |
| URL in-app | Tanpa prefix locale; locale = state + prefs |
| Deep link web | Map ke BCP-47 hyphen lewat helper tunggal |
| String UI | `AppLocalizations` / `l10n.*` setelah port fitur |
| Data API | Lemma/makna bukan string l10n |

Urutan: scaffold i18n → first-run bahasa → Settings shell → port
halaman. Detail gelombang di `MOBILE-I18N.md` Section 12. **Belum
dieksekusi** sampai prompt implementasi.

## 14. Referensi Terkait

- `docs/backlogs/CACHE.md` - backlog cache response API (draft;
  belum diimplementasi)
- `docs/mobile/MOBILE-I18N.md` - kontrak multi-bahasa Flutter
- `docs/web/WEB-I18N.md` - kanonik locale + mapping deep link web
- `docs/mobile/01-mobile-ulid-device-id.md` - device id ULID + header
  X-Device-Id (rate limit anonim per-device, kontrak di
  `docs/api/06-api-x-device-id.md`)
- `docs/mobile/20-mobile-report-bug.md` - form Laporan Masalah (tamu +
  login), token upload publik `/bug-reports`

- `docs/api/api-base-stack.md`: kontrak backend (envelope Section 13,
  pagination, error, auth mobile varian)
- `docs/api/00-api-auth.md`: endpoint auth (termasuk client_type mobile)
- `docs/backlogs/AUTH_GOOGLE.md` + `docs/api/24-api-auth-google.md` +
  `docs/mobile/13-mobile-auth-google.md`: masuk dengan Google (V1)
- `docs/backlogs/AUTH_FACEBOOK.md` + `docs/api/29-api-auth-facebook.md` +
  `docs/mobile/19-mobile-auth-facebook.md`: masuk dengan Facebook (V1)
- `docs/api/01-api-tambah-kata.md`, `03-api-kontribusi-verifikasi.md`
- `api/ERROR_CODES.md`: katalog error code
- `docs/json/`: sample response semua endpoint (mock untuk unit/widget
  test; JANGAN hardcode bentuk response di luar file ini)
- repo `http/`: koleksi Bruno (perilaku endpoint hidup, contoh chaining)
- repo referensi pola: `jnn_mobile` (iamutaki): sumber konvensi asli
  dokumen ini

## 15. Analytics (Firebase)

Product analytics memakai **Firebase Analytics (GA4)** saja (free tier,
tanpa biaya event standar). FCM sudah ada untuk push; Crashlytics tidak
wajib. Jangan pasang PostHog / Amplitude / custom event API spekulatif.

### Stack

| Item | Pilihan |
| --- | --- |
| Package | `firebase_core` (sudah) + `firebase_analytics` |
| Abstraksi | `AnalyticsService` di `lib/core/services/analytics_service.dart` |
| Screen | `AnalyticsRouteObserver` di GoRouter (`observers`) |
| Flavor | `user_property` `app_flavor` = `staging` \| `production` |

Page / notifier **tidak** memanggil `FirebaseAnalytics` langsung.
Semua lewat `AnalyticsService.instance` (atau provider jika perlu).

### Aturan event (wajib)

1. Nama: `snake_case`, pendek, tanpa PII (no email; `word_id` / `lemma`
   publik boleh).
2. **Setiap fitur mobile baru atau perubahan perilaku user-facing WAJIB
   memasang analitik di PR yang sama.** Checklist selesai fitur:
   - Panggil `AnalyticsService` di titik aksi sukses (dan gagal bila
     relevan untuk funnel).
   - Tambah / perbarui baris di tabel event di bawah.
   - Konstanta nama event di
     `lib/core/services/analytics_service.dart` (`AnalyticsEvents`).
   - Jangan anggap UI selesai jika event belum ada.
3. Staging dan production: analytics on. Uji di Firebase DebugView.
4. Jangan log isi form kontribusi / isi komentar mentah.
5. Page / notifier **tidak** memanggil `FirebaseAnalytics` langsung.
   Selalu lewat `AnalyticsService.instance`.

### Definisi selesai (Definition of Done) fitur mobile

Sebelum merge, verifikasi:

- [ ] Event baru tercantum di tabel Section 15
- [ ] `AnalyticsEvents` + pemanggilan di kode ada
- [ ] Tidak ada PII di params
- [ ] Screen baru tercakup `screen_view` (nama route GoRouter)

### Tabel event kanonik

| Event | Kapan | Params kunci | Gelombang |
| --- | --- | --- | --- |
| `screen_view` | tiap route utama | `screen_name` | P0 |
| `search_submit` | submit cari | `query_len`, `search_in`, `has_results` | P0 |
| `wotd_tap` | ketuk kata hari ini | `word_id` | P0 |
| `word_open` | buka detail | `word_id`, `source` | P0 |
| `audio_play` | putar lafal | `word_id`, `has_audio` | P0 |
| `contribute_start` | buka / mulai form usul | `guest`, `from` | P0 |
| `contribute_submit` | tekan kirim | `guest` | P0 |
| `contribute_success` | usul diterima API | `guest`, `word_id` | P0 |
| `contribute_fail` | usol gagal | `guest`, `error_code` | P0 |
| `explore_category_tap` | tap kartu kategori | `category_id`, `coming_soon` | P0 |
| `map_open` | buka peta | `entry`, `mode` (`live`/`poster`) | P0 |
| `map_fallback_shown` | hero/fullscreen → poster | `reason` | P0 |
| `poi_open` | buka detail Place (wisata/kuliner) | `slug`, `category`, `entry` (`list`/`pin`) | P0 |
| `vote_cast` | upvote/downvote | `target_type`, `direction` | P0 |
| `bookmark_toggle` | simpan/hapus | `word_id`, `action` | P0 |
| `share_start` / `share_complete` | share card | `word_id` | P0 |
| `auth_login_success` / `auth_register_success` | auth sukses | `method` | P0 |
| `auth_login_fail` | login gagal | `method`, `error_code` | A |
| `auth_logout` | logout | - | A |
| `search_miss_tap` | pilih miss di tab Kontribusi | `miss_id` | A |
| `comment_submit` | kirim komentar | `word_id` | A |
| `inbox_open` / `notification_item_tap` | inbox | `type` (item) | A |
| `suggest_edit_submit` | kirim usul edit | `word_id` | A |
| `audio_record_start` / `audio_record_submit` | rekam lafal | `word_id` | B |
| `report_word_submit` | laporkan entri | `word_id` | B |
| `report_bug_submit` | laporan masalah | `has_word`, `has_comment` | B |
| `onboarding_complete` | selesai onboarding | - | B |
| `theme_change` | ganti tema | `mode` | B |
| `review_approve` / `review_reject` / `review_correct` | moderasi | `contribution_id` | saat sentuh |
| `verifier_apply_submit` | ajukan verifikator | - | saat sentuh |
| `leaderboard_view` / `profile_stats_view` | gamifikasi V1 | lihat `GAMIFIKASI.md` | G |

Baseline behaviour app sekarang: ~42 event bernama (1 `screen_view` +
aksi). P0 memasang gelombang must-have; sisanya menyusul per fase.

### Referensi backlog

- Gamifikasi / leaderboard: `docs/backlogs/GAMIFIKASI.md`
- Kontrak skor: `docs/api/31-api-leaderboard.md`
