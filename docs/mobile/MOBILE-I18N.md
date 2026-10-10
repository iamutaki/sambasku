# MOBILE-I18N - Kontrak Multi-bahasa Aplikasi Flutter

Kontrak dasar i18n untuk `mobile/` (Flutter). **Dokumen ini adalah
kontrak**; implementasi belum dimulai di dokumen ini. Setiap
modul/fitur baru wajib mengikuti pola ini dan
`docs/mobile/mobile-base-stack.md` (Section i18n).

## 1. Tujuan & ruang lingkup

| Termasuk | Tidak termasuk |
| --- | --- |
| String chrome UI (label, tombol, toast, dialog, hint, empty, error UI) | Isi kamus dari API (lemma, makna, contoh) |
| Pilih bahasa **saat first launch** + ubah lewat **Pengaturan** | Menyimpan terjemahan UI di backend |
| Halaman Pengaturan (IA baru: pisah dari Profil) | SEO / hreflang (bukan web) |
| Format tanggal/angka mengikuti locale UI | Auto-translate pipeline |
| Locale persistence (`sk_locale`) | Sync wajib locale ke akun server (V1) |

Prinsip sama dengan web: **UI locale ≠ arah pencarian kamus**
(`search_in`).

## 2. Locale registry (selaras web)

| Kode Flutter / ARB | BCP-47 (selaras web) | Label | Default |
| --- | --- | --- | --- |
| `id` | `id` | Bahasa Indonesia | ya (fallback & template ARB) |
| `id_SBS` | `id-SBS` | Bahasa Sambas | tidak |

Aturan:

1. File ARB memakai **underscore** (`app_id.arb`, `app_id_SBS.arb`) -
   konvensi `flutter gen-l10n`.
2. Saat logging/analytics/user preference, simpan kode Flutter
   (`id`, `id_SBS`). Saat membangun deep link ke web, map ke BCP-47
   hyphen (`id`, `id-SBS`) lewat helper tunggal
   (`localeToWebPath` / `webLocaleToApp`).
3. Locale baru: tambah ARB + daftar di `l10n.yaml` /
   `supportedLocales`. Jangan hardcode daftar di widget.
4. Fallback string: `id` jika key hilang di locale aktif.
5. Setelah user memilih bahasa eksplisit (first launch atau Settings),
   **jangan** override dari locale sistem OS.

## 3. Stack pustaka (keputusan)

| Peran | Pilihan | Alasan |
| --- | --- | --- |
| Official l10n | `flutter_localizations` + `intl` + **ARB** + `flutter gen-l10n` | Standar Flutter, type-safe `AppLocalizations` |
| Konfig | `l10n.yaml` di root `mobile/` | Satu tempat generate |
| Persist locale | `shared_preferences` key `sk_locale` | Selaras nama cookie web |
| Persist first-run bahasa | flag `sk_locale_chosen` (bool) | Beda dari `OnboardingPrefs.done` |
| State | Riverpod `localeControllerProvider` | Ganti locale tanpa restart penuh bila memungkinkan |

Dilarang: `easy_localization` / katalog JSON paralel selain ARB;
string UI hardcoded di `presentation/` setelah gelombang port halaman
itu selesai; mengirim locale UI ke API kecuali endpoint kelak
membutuhkan (saat ini tidak).

## 4. Struktur folder & generate

```text
mobile/
├── l10n.yaml
├── lib/
│   ├── l10n/
│   │   ├── app_id.arb
│   │   ├── app_id_SBS.arb
│   │   └── (generated AppLocalizations)
│   ├── core/
│   │   └── i18n/
│   │       ├── app_locale.dart          # enum/registry + mapping web
│   │       ├── locale_controller.dart
│   │       └── locale_prefs.dart        # sk_locale + sk_locale_chosen
│   ├── features/
│   │   ├── onboarding/                  # existing + langkah pilih bahasa
│   │   ├── profile/                     # tab Profil (identitas + aktivitas)
│   │   └── settings/                    # BARU: Pengaturan aplikasi
│   │       ├── settings_router.dart
│   │       └── presentation/pages/
│   │           ├── settings_page.dart
│   │           └── language_settings_page.dart  # opsional sub-page
│   └── app.dart
```

`l10n.yaml` (kontrak bentuk):

```yaml
arb-dir: lib/l10n
template-arb-file: app_id.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

`pubspec.yaml` wajib `flutter: generate: true`. Dependencies:
`flutter_localizations` (SDK), `intl` (versi selaras Flutter).

## 5. Konvensi key ARB

1. Key: `lowerCamelCase`. Disarankan awalan area agar mudah dicari
   (selaras semangat prefix web): `settingsLanguageTitle`,
   `onboardingLanguageHeadline`, `profileMenuBookmarks`.
2. Template = `app_id.arb`. Locale lain wajib key 1:1.
3. `@key` description untuk string non-trivial.
4. Placeholder / plural: ICU di ARB.
5. Tanpa em/en dash di nilai string.
6. Nama event analytics tetap `snake_case` Inggris; label UI ber-locale.

```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.settingsLanguageTitle);
```

- Presentation memakai `AppLocalizations.of(context)`.
- Notifier: simpan kode/enum error, map ke l10n di UI.
- `formatDateTime`: ikut locale UI via helper tunggal.

## 6. MaterialApp & routing

- Delegates: `AppLocalizations` + Global Material/Widgets/Cupertino.
- `supportedLocales` dari registry; `locale` dari
  `localeControllerProvider`.
- GoRouter **tanpa** prefix locale di path in-app.
- Route baru (kontrak):

| Path | Nama (contoh) | Keterangan |
| --- | --- | --- |
| `/settings` | `SettingsRouter.root` | Halaman Pengaturan |
| `/settings/language` | `SettingsRouter.language` | Pilih bahasa (boleh inline di Settings tanpa sub-route) |

Deep link ke web: map locale ke BCP-47 via helper (Section 2).

## 7. First launch: wajib pilih bahasa

### 7.1 Tujuan

User **menentukan bahasa antarmuka sebelum** (atau sebagai langkah
pertama) masuk pengalaman kamus. Tidak diam-diam memakai locale OS
sebagai pilihan final tanpa konfirmasi.

### 7.2 Alur (kontrak)

```text
Cold start
  → belum sk_locale_chosen?
       YA → layar / langkah "Pilih bahasa"
              → user pilih id | id_SBS
              → simpan sk_locale + sk_locale_chosen=true
              → lanjut onboarding yang belum selesai (bila ada)
                 atau ke splash/beranda
       TIDAK → pakai sk_locale; hormati onboarding_done seperti sekarang
```

Integrasi dengan onboarding existing
(`OnboardingPrefs` / `sambasku_onboarding_done`):

1. **Keputusan V1:** langkah pilih bahasa adalah **langkah 0 / slide
   pertama** di alur first-install (sebelum welcome/fitur/izin
   notifikasi), ATAU layar terpisah yang dijalankan **sebelum**
   `OnboardingPage` jika `!sk_locale_chosen`.
2. Flag `sk_locale_chosen` **terpisah** dari `onboarding_done`:
   - Reset onboarding di dev tool tidak wajib menghapus bahasa (kecuali
     aksi "Reset bahasa" eksplisit).
   - Uninstall menghapus keduanya (SharedPreferences hilang) → first
     launch ulang termasuk pilih bahasa.
3. UI langkah bahasa:
   - Judul + singkat penjelasan (bahasa antarmuka, bukan arah kamus).
   - Daftar dari registry (label bahasa itu sendiri).
   - Satu pilihan wajib sebelum "Lanjut" / tap item = pilih + lanjut.
   - Default highlight: `id` (boleh), tetapi user harus konfirmasi
     (tap Lanjut atau pilih eksplisit) supaya `sk_locale_chosen` terset.
4. Analytics (saat implementasi): event mis. `locale_chosen` dengan
   param `locale`, `source=first_launch` (nama final di
   `AnalyticsEvents`).

### 7.3 Yang tidak boleh

- Auto-set `sk_locale_chosen` hanya dari `Accept-Language` / OS tanpa UI.
- Melewati layar bahasa jika flag belum true (kecuali flavor/test
  override yang didokumentasikan).

## 8. Pengaturan vs Profil (IA)

Profil tab saat ini memuat terlalu banyak grup (Saya, Akun, Tampilan,
Tentang, …) sehingga area scroll memanjang. Kontrak memisahkan
**identitas & aktivitas** (Profil) dari **preferensi aplikasi**
(Pengaturan).

### 8.1 Profil tab (tetap ringkas)

Fokus: "siapa saya" + "aktivitas saya" + akun sensitif.

| Tetap di Profil | Keterangan |
| --- | --- |
| Identity tile (avatar, nama, role) | Entry ke profil publik / edit |
| Grup **Saya**: Notifikasi inbox, Kontribusi, Bookmark, Vote, Komentar | Aktivitas user |
| Grup **Akun** (login): Edit profil, Akun Terhubung, Ubah Password, Hapus akun, Jadi verifikator, Antrean review | Manajemen akun & peran |
| Guest: Masuk / Daftar | Auth entry |
| Keluar (logout) | Di bagian bawah Profil |

Satu pintu ke Settings:

| Tile baru di Profil | Tujuan |
| --- | --- |
| **Pengaturan** (ikon gear) | `context.push('/settings')` - subtitle singkat mis. "Bahasa, tampilan, tentang" |

Header Profil: boleh tetap ada pintasan notifikasi; **toggle tema di
header boleh dipindah sepenuhnya ke Settings** (kontrak: hilangkan
duplikasi - pilih satu. V1 disarankan tema hanya di Settings).

### 8.2 Halaman Pengaturan (`/settings`) - BARU

Pindahkan / kumpulkan preferensi non-identitas ke sini.

| Grup Settings | Isi |
| --- | --- |
| **Bahasa** | Tile "Bahasa aplikasi" → nilai saat ini (Indonesia / Sambas) → buka picker / sub-page |
| **Tampilan** | Mode tema (system/light/dark) + palet (pindah dari Profil) |
| **Dukungan** | Laporkan Masalah (pindah dari grup Saya / guest list di Profil) |
| **Tentang** | Tentang SambasKu (pindah dari Profil) |

Aturan:

1. Guest dan user login **sama-sama** melihat Settings (bahasa &
   tampilan tidak butuh auth).
2. "Laporkan Masalah" cukup satu tempat (Settings); jangan dobel di
   Profil kecuali CTA kontekstual di tempat lain.
3. Jangan pindahkan Kontribusi / Bookmark / Vote / Komentar ke Settings
   (itu aktivitas, bukan preferensi).
4. List UI tetap compact (`FTile` / `FTileGroup` - base stack §5a).

### 8.3 Picker bahasa di Settings

- Sumber daftar: registry locale (Section 2).
- Simpan `sk_locale`; set `sk_locale_chosen=true` jika belum.
- Update `localeControllerProvider` → rebuild `MaterialApp`.
- Analytics: `locale_chosen` / `locale_change` dengan
  `source=settings`.
- Copy UI menjelaskan: mengubah bahasa antarmuka; arah pencarian kamus
  tidak ikut berubah otomatis.

## 9. Language picker UX (ringkas)

| Titik masuk | Wajib V1 |
| --- | --- |
| First launch (Section 7) | ya |
| Settings → Bahasa aplikasi (Section 8) | ya |
| Profil langsung (sheet bahasa) | tidak - cukup tile Pengaturan |
| Ikuti OS setelah pilihan user | tidak |

## 10. Port string (gelombang)

1. Inventarisasi literal → key ARB (awalan area disarankan).
2. `app_id.arb` lalu `app_id_SBS.arb`.
3. `flutter gen-l10n`.
4. Ganti literal dengan `l10n.*`.
5. Widget test dengan `AppLocale.toLocale()`.

`id_SBS`: satu helper `AppLocale.toLocale()` sebagai satu-satunya cara
membangun `Locale` untuk `supportedLocales`.

## 11. Testing & Definition of Done

### Scaffold i18n + first-run + Settings

- [ ] ARB `id` & `id_SBS` bootstrap + registry + prefs
  (`sk_locale`, `sk_locale_chosen`)
- [ ] First launch menampilkan pilih bahasa sebelum/onboarding langkah 0
- [ ] `/settings` ada; bahasa + tampilan + tentang (+ laporkan masalah)
  hidup di Settings
- [ ] Profil tidak lagi memuat grup Tampilan / Tentang (sudah pindah);
      ada tile Pengaturan
- [ ] Ganti bahasa di Settings langsung mengubah chrome UI
- [ ] Mapping deep link web ↔ app locale di helper
- [ ] `flutter analyze` / smoke test hijau

### Port fitur

Tidak ada literal UI baru di halaman yang disentuh + key ada di kedua
ARB.

## 12. Urutan eksekusi (disarankan - belum dijalankan)

1. **M0 - Scaffold i18n**: ARB, gen-l10n, registry, prefs, controller.
2. **M0b - First-run bahasa**: flag + UI langkah 0 / pre-onboarding.
3. **M0c - Settings shell**: route `/settings`, pindahkan Tampilan +
   Tentang + Laporkan Masalah; tile Pengaturan di Profil; picker
   bahasa.
4. **M1 - Port shell**: nav, profil ringkas, settings, errors.
5. **M2 - Dictionary** chrome.
6. **M3 - Auth + kontribusi + sisa**.
7. **M4 - Review id_SBS** dengan penutur.

String baru boleh masuk `app_id.arb` dulu; `id_SBS` boleh salin
sementara dari `id` sampai review penutur.

## 13. Referensi

- `docs/web/WEB-I18N.md` - kanonik locale + mapping deep link web
- `docs/admin/CONSOLE-I18N.md` - konsol admin
- `docs/mobile/mobile-base-stack.md` - Section i18n + list UI compact
- Onboarding existing: `features/onboarding/` + `OnboardingPrefs`
- Profil existing: `features/profile/presentation/pages/profile_page.dart`
  (acuan menu yang dipindah)
