# AUDIO_PRONUNCIACION - Player dan rekam pelafalan di detail kata

Catatan kontrak (2026-09-21), **sebelum** ditulis ke `docs/mobile/` dan
`docs/admin/`. Prioritas 2 di [NEXT.md](NEXT.md): audio pelafalan
penutur asli.

**Dependensi keras**: kontrak API sudah dibekukan di
[GITHUB_PRONUNCIACION.md](GITHUB_PRONUNCIACION.md) (tabel `word_audios`,
upload multipart GitHub storage, `audios[]` di word detail). File ini
**tidak mengulang** kontrak itu - file ini kontrak sisi client yang
menumpangnya, plus delta antrean admin.

Estimasi: API sesuai dokumen itu 2-3 hari; sisi client di file ini
**2-2.5 hari** (player 0.5, recorder 1, UI + wiring 0.5).

> Prompt implementasi nanti: tulis
> `docs/mobile/16-mobile-pronunciation-audio.md` (nomor cek ulang
> saat implementasi) + delta `docs/admin/` antrean kontribusi.
> Dokumen API ditulis sebagai bagian kerja GITHUB_PRONUNCIACION.md
> (`NN-api-pronunciation-audio.md`).

---

## Intent

User membuka detail kata:

1. **Jika kata sudah punya audio pelafalan**, tampil section
   **Pelafalan**: daftar rekaman (primary dulu), tiap item bisa
   diputar - speaker, dialek, durasi.
2. User login bisa **menambah rekaman sendiri** langsung dari app:
   izin mic → rekam → dengar pratinjau → isi nama penutur (+ dialek
   opsional) → kirim. Masuk antrean moderasi; tayang setelah
   disetujui.

Menutup requirement NEXT.md: "rekam di mobile (izin mic) → upload →
player di detail (loading/pause/error) → moderasi admin sebelum
tayang".

---

## Situasi sekarang

- Detail kata mobile hanya merender **notasi** pelafalan sebagai satu
  baris teks italic (`word_detail_page.dart`, blok
  `pronunciations.isNotEmpty`). Tidak ada audio.
- `WordDetailDto` punya `pronunciations[]` (notasi + legacy
  `audio_url` nullable yang tidak terpakai), `images[]`; **belum ada
  `audios[]`**.
- Tabel `word_audios` + endpoint upload belum diimplementasikan
  (masih backlog di GITHUB_PRONUNCIACION.md).
- `permission_handler` sudah terpasang (dipakai kamera/notifikasi);
  `record` dan player audio **belum**.
- Pola login gate, snackbar, soft-fail upload sudah ada di alur
  kontribusi kata.

---

## Keputusan (tetap sampai diganti di file ini)

1. **Kontrak API = GITHUB_PRONUNCIACION.md, tidak ada endpoint baru
   di file ini.** Yang dibutuhkan client dari situ: `audios[]` di
   word detail (publik hanya `published`), `POST
   /words/:wordId/pronunciations/audio` multipart, 503
   `PRONUNCIACION_UPLOAD_UNAVAILABLE` saat storage belum dikonfigurasi.
2. **Section Pelafalan render bersyarat** - `audios[]` kosong = tidak
   ada section sama sekali (requirement "jika ada"). Urut: `is_primary`
   dulu, sisanya terbaru dulu.
3. **Player `just_audio`, satu audio aktif pada satu waktu.** Tap
   item lain = stop yang sebelumnya. Tidak preload semua; set AudioSource
   saat item pertama kali diputar. State per item: loading / playing /
   paused / error (tap ulang = retry). Tanpa autoplay, tanpa "play all".
4. **Rekam pakai package `record`**, output default **AAC/m4a** -
   persis MIME wajib `audio/mp4` di kontrak API. Batas rekam UI
   **60 detik** (API clamp sampai 600.000 ms; UI lebih ketat karena
   pelafalan kata pendek). Timer terlihat; auto-stop di 60s.
5. **Wajib pratinjau sebelum kirim**: selesai rekam → putar hasil →
   user pilih Rekam ulang atau Lanjut. Tidak ada kirim buta.
6. **`speaker_name` prefill username** user login (bisa diedit);
   **dialek opsional** (dropdown `dialects` yang sudah dipakai form
   kontribusi); `duration_ms` diisi otomatis dari hasil rekam.
7. **Rekam hanya untuk user login.** Endpoint butuh role contributor
   ke atas. Guest melihat tombol → login gate (pola rumah); player
   section tetap untuk semua orang.
8. **Contributor → `pending_review`, tidak langsung tayang.** Sukses
   kirim = snackbar "Terima kasih, rekaman menunggu tinjauan" (bukan
   muncul di daftar). Status lanjutan dilihat lewat **Usulanku**
   (baris kontribusi `word_audio`, pola `word_images`).
9. **Soft-fail 503**: tombol Rekam disembunyikan + toast sekali;
   section player dan notasi tetap jalan. Audio lama tetap bisa
   diputar walau upload baru mati.
10. **Legacy `pronunciations.audio_url` diabaikan** mobile V1.
    Baris notasi IPA tetap dirender sebagai teks seperti sekarang -
    tidak digabung ke section audio.

Ditolak untuk V1:

| Opsi | Alasan |
| ---- | ------ |
| Pilih file audio dari galeri (`file_picker`) | Sumber audio tak terkontrol (kualitas/hak); rekam in-app adalah inti fitur "penutur asli". Delta kalau diminta |
| Tampilkan audio pending milik sendiri di detail publik | Perlu filter per-user di endpoint publik; Usulanku sudah menutup kebutuhan status |
| Waveform / trim / edit rekaman | Pelafalan kata pendek; rekam ulang lebih murah dari editor |
| `audioplayers` | Dua pilihan sama-sama mampu; `just_audio` API-nya lebih ringkas untuk satu-item-sekali-play |
| Autoplay saat detail dibuka | Berisik dan memakan data |
| Play count / statistik | Belum ada yang membacanya |

---

## Alur

```mermaid
flowchart TD
  Detail[WordDetailPage] --> Audios{audios[] ada?}
  Audios -->|kosong| NoSection[tidak render section]
  Audios -->|ada| List[Section Pelafalan: item primary dulu]
  List --> Play[tap play → just_audio, satu aktif]
  Detail --> Btn[Tombol Rekam pelafalan]
  Btn --> Guest{login?}
  Guest -->|tamu| Gate[Login gate] --> Perm
  Guest -->|login| Perm[Izin mic Permission.microphone]
  Perm --> Rec[Rekam max 60 dtk, AAC/m4a, timer]
  Rec --> Prev[Pratinjau: putar / rekam ulang]
  Prev --> Form[nama penutur prefill username + dialek opsional]
  Form --> Up[POST multipart /words/:id/pronunciations/audio]
  Up --> Pend[status pending_review + snackbar]
  Pend --> Queue[Antrean admin: entity word_audio]
  Queue -->|approve| Pub[published → muncul di audios[]]
  Queue -->|reject| Rej[rejected + alasan di Usulanku]
```

---

## Kontrak mobile

### Model (delta)

```dart
WordAudioDto {
  String id;
  String url;
  String? dialectId;
  String? speakerName;
  int? durationMs;
  @JsonKey(name: 'is_primary') @Default(false) bool isPrimary;
}

// WordDetailDto:
@JsonKey(name: 'audios') @Default([]) List<WordAudioDto> audios,
```

Client lama terhadap response tanpa `audios`: default `[]` aman
(kompatibel turun).

### Section Pelafalan (display)

- Letak: di bawah baris notasi IPA, sebelum Makna.
- Item `AudioPlayerTile`: tombol play/pause (ikon state), nama
  penutur (`Anonim` jika null), chip dialek (nama dialek, lookup
  lokal; tanpa chip jika null), durasi `0:07`.
- Satu instance `AudioPlayer` per halaman; ganti item = stop +
  set source baru. Buffering lama (> ~5 dtk) → tetap di state
  loading dengan indikator; error → ikon error, tap = retry, item
  lain tidak ikut gagal.
- Offline / URL mati: toast error item itu saja, jangan crash page.

### Rekam (sheet `RecordPronunciationSheet`)

State mesin: `idle → requestingPermission → recording → preview →
submitting → done`.

1. **Izin**: `Permission.microphone`. Permanently denied → dialog
   "buka Pengaturan" (pola kamera yang ada).
2. **Rekam**: `record` start (AAC/m4a), timer naik, tombol Stop,
   auto-stop 60 dtk.
3. **Pratinjau**: putar hasil via player yang sama + tombol Rekam
   ulang (buang file lama) / Lanjut.
4. **Form**: `speaker_name` (prefill username, wajib non-kosong,
   maks 255), dialek dropdown opsional.
5. **Kirim**: Dio `FormData` - file `audio`, `speaker_name`,
   `dialect_id`?, `duration_ms`. Response 201 → snackbar menunggu
   review + tutup sheet.
6. **Gagal kirim**: tetap di state form (jangan suruh rekam ulang);
   429 `RATE_LIMITED` → toast "Terlalu banyak, coba lagi nanti";
   error jaringan → tombol Coba lagi.
7. **503** `PRONUNCIACION_UPLOAD_UNAVAILABLE` (dicek saat sheet
   dibuka pertama atau saat gagal): tombol Rekam disembunyikan +
   toast sekali - player section tidak terpengaruh.

### Konfigurasi platform

- iOS `Info.plist`: `NSMicrophoneUsageDescription` + kalimat
  Indonesia ("Rekam pelafalan kata untuk dikirim ke SambasKu").
- Android `AndroidManifest.xml`: `<uses-permission
  android:name="android.permission.RECORD_AUDIO"/>`.

### Dependensi baru (mobile)

- `record` (rekam AAC/m4a)
- `just_audio` (putar)

`permission_handler`, `dio`, `shared_preferences` (username) sudah ada.

### Modul (delta)

```
mobile/lib/features/dictionary/
├── data/models/word_audio_dto.dart          # BARU
└── presentation/
    ├── widgets/
    │   ├── pronunciation_section.dart       # BARU: list + tombol rekam
    │   ├── audio_player_tile.dart           # BARU
    │   └── record_pronunciation_sheet.dart  # BARU
    └── providers/audio_player_controller.dart  # BARU: 1 player per page

mobile/lib/features/contribution/
└── data/ (endpoint upload multipart + DTO)  # atau repository dictionary,
                                             # ikut tempat retrofit word ada
```

---

## Kontrak admin (delta web)

Antrean kontribusi (`03-api-kontribusi-verifikasi.md`, pola render
`word_images`):

- Item `word_audio`: mini player (tag `<audio>` native cukup),
  speaker, dialek, durasi, ukuran file, kata induk.
- Aksi approve/reject/correct tetap tombol generik antrean -
  tanpa alur khusus. Reject wajib alasan (aturan antrean).
- Tidak ada editor audio di admin. Salah isi = reject + user rekam
  ulang.

---

## Kompatibilitas

- `audios[]` field baru di word detail: client lama abaikan, client
  baru default `[]` saat field belum ada (API belum deploy juga aman).
- Baris notasi IPA di detail tidak berubah - section audio murni
  tambahan.
- Endpoint upload baru total - tidak menimpa `POST
  /words/:wordId/pronunciations` (notasi).

---

## Yang sengaja tidak masuk

- Pilih file audio dari galeri / share audio masuk
- Waveform, trim, edit
- Play all / autoplay / playlist
- Variasi penutur "resmi" (badge verified speaker)
- Notifikasi push saat rekaman disetujui (delta modul notification)
- Download / cache offline audio
- Set-primary dari sisi client (keputusan GITHUB_PRONUNCIACION:
  audio pertama otomatis primary; ganti primary urusan admin)
- Migrasi atau render legacy `pronunciations.audio_url`

---

## Urutan kerja setelah file ini disetujui

1. Implementasikan API sesuai GITHUB_PRONUNCIACION.md lengkap
   (tabel, storage, upload, `audios[]` di detail) + dokumen API-nya.
2. Tulis `docs/mobile/16-mobile-pronunciation-audio.md`.
3. Mobile: model + section player (bisa diuji dengan baris seed
   manual).
4. Mobile: sheet rekam + upload + izin mic.
5. Admin: render antrean `word_audio`.
6. Bruno untuk endpoint upload + word detail audios (bagian kerja
   API).

Jangan mulai kode mobile sebelum langkah 1 jalan di staging.

---

## Checklist kontrak (centang saat disalin ke docs/mobile + docs/admin)

- [ ] `audios[]` di word detail response (publik = published saja)
- [ ] Section render bersyarat kosong, primary dulu
- [ ] Player satu-aktif, state per item, error per item
- [ ] Rekam m4a max 60 dtk, wajib pratinjau, rekam ulang
- [ ] `speaker_name` prefill username, dialek opsional, `duration_ms` otomatis
- [ ] Guest → login gate; 503 → sembunyikan tombol rekam
- [ ] Kontribusi masuk Usulanku (`word_audio`), snackbar menunggu review
- [ ] Izin mic dua platform + kalimat Indonesia
- [ ] Antrean admin render + approve/reject generik
- [ ] Setelah ship: pindah file ini dan GITHUB_PRONUNCIACION.md ke `docs/backlogs/done/`
