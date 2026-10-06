# NEXT - Peta Jalan Fitur Kamus Kolaboratif Sambasku

Dokumen ide fitur berikutnya, diurutkan berdasar **nilai ÷ usaha**
dengan memanfaatkan infrastruktur yang sudah ada (diperbarui
2026-09-21). Gabungan peta produk lintas-stack dan rencana gap mobile.

Fondasi yang sudah solid: auth lengkap (termasuk ubah password),
approval gate kontribusi, vote, komentar pre-moderasi, variasi
penulisan + pencarian lintas varian, audit trail, search-miss panel,
dashboard admin, **Kontribusi Saya / Usulanku**, inbox notifikasi
status usulan, bookmark per akun,
usul edit kata existing, kartu share V1, profil publik.

---

## Sudah tertutup

| Fitur | Kapan | Dokumen |
| ----- | ----- | ------- |
| Halaman Usulanku | 2026-09-21 | API `21-api-my-contributions.md`, mobile `10-mobile-kontribusi-saya.md` |
| Inbox notifikasi status usulan | 2026-09-21 | API `23-api-notifications.md`, mobile `12-mobile-notifications.md` |
| Bookmark per akun | 2026-09-20 | API `16-api-bookmark.md`, mobile `05-mobile-bookmark.md` |
| Usul edit kata existing | 2026-09-21 | API `17-api-suggest-edit-word.md`, mobile `06-mobile-suggest-edit.md`, admin `13-admin-suggest-edit.md` |
| Kartu share V1 | 2026-09-21 | [`done/SHARE.md`](done/SHARE.md), mobile `11-mobile-share-card.md` |
| Vote saya + Komentar saya | 2026-09-22 | [`done/VOTE_COMMENT_ON_PROFILE.md`](done/VOTE_COMMENT_ON_PROFILE.md), API `26`/`27`, mobile `16`/`21` |
| Resolve search-miss ke kata existing | - | API + admin (POST `…/resolve`) |

CTA "Lihat usulan" setelah submit kata baru dan suggest-edit sudah ada.

---

## Prioritas 1 - Tutup loop yang sudah dijanjikan

Kolaborasi mati kalau kontributor tidak tahu nasib usulannya. Tile
Profil yang masih "segera hadir" adalah sinyal backlog paling dekat.

Inbox in-app status usulan sudah ada (2026-09-21). Push notification
masih ditunda sampai inbox terpakai.

### Alur kembali dan state submit

Sisa pekerjaan setelah Usulanku. CTA post-submit sudah ada.

**Pekerjaan:**

- Audit navigasi Profil + form kontribusi agar `push`/`pop` konsisten
- Cegah double-submit saat jaringan lambat
- Retry yang tidak menghapus isian ketika referensi dialek/kelas kata gagal dimuat

### Menu Profil "segera hadir"

Satu tile masih toast. Tutup atau cabut labelnya.

- ~~**Vote saya + Komentar saya**~~ - selesai 2026-09-22
  ([`done/VOTE_COMMENT_ON_PROFILE.md`](done/VOTE_COMMENT_ON_PROFILE.md)).
- **Laporkan Masalah:** kontrak [`REPORT_BUG.md`](REPORT_BUG.md).
  Tombol dari detail kata, komentar, dan Profil; form kategori +
  deskripsi + `word_id`/`comment_id`; antrean admin; konfirmasi ke
  user.

---

## Prioritas 2 - Audio pelafalan penutur asli

Killer feature kamus bahasa daerah. Skema **sudah siap**: kolom
`audio_url` + `speaker_name` di `pronunciations` belum terpakai.

**Pekerjaan:** rekam di mobile (izin mic) → upload CDN (pola token
ImageKit) → player di detail (loading/pause/error) → moderasi admin
sebelum tayang.

**Keputusan:** satu audio utama per kata dulu; variasi penutur belakangan.

---

## Prioritas 3 - Papan kualitas data (work queue kontributor)

Dashboard admin: daftar kata **tanpa** contoh kalimat / pelafalan /
gambar / variasi (satu query `LEFT JOIN ... IS NULL` per kategori).
Mengubah kolaborasi dari "nebak mau isi apa" menjadi daftar kerja
prioritas. Pasangan alami search-miss panel. Estimasi: ± setengah hari.

---

## Medium - retensi pengguna akhir

- **Tab Kontribusi: menu search-miss + deck nilai kata:** list
  “sering dicari” pindah ke halaman/menu di bawah Usul kata baru;
  area bawah = stack swipe vote (kata terbit yang user belum vote,
  wording Masuk akal / Kurang pas). Kontrak:
  [`KONTRIBUSI_VOTE_DECK.md`](KONTRIBUSI_VOTE_DECK.md), API
  [`../api/34-api-vote-deck.md`](../api/34-api-vote-deck.md), mobile
  [`../mobile/22-mobile-kontribusi-vote-deck.md`](../mobile/22-mobile-kontribusi-vote-deck.md).
- **Discovery di Home + Word of the Day:** saat query kosong, Home
  sekarang = search-miss (duplikat tab Kontribusi). API pilih satu
  kata terbit per hari (seed tanggal) atau acak; chip “kata baru
  minggu ini”; tampil di beranda tanpa mengganggu pencarian. Kartu
  share V1 sudah ada.
- **Cache offline tipis:** batas = detail kata + reference + feed
  singkat, bukan seluruh database. Spesifikasi backlog:
  [`CACHE.md`](CACHE.md) (+ [`CACHE-MOBILE.md`](CACHE-MOBILE.md),
  [`CACHE-WEB.md`](CACHE-WEB.md)). Penyimpanan lokal terstruktur (bukan
  `SharedPreferences` untuk data kamus besar). TTL + SWR + indikator
  stale/offline. Jangan queue diam-diam untuk submit/vote. Uji cold
  start tanpa jaringan. Web: perbaiki HTML edge SWR ber-locale dulu.
- **Normalisasi pencarian dialek:** apostrof/tanda hubung/huruf pada
  `q` sebelum ILIKE; tampilkan query asli; pesan jika hasil lewat
  variasi penulisan. Contoh uji: `kete'`, `kete’`, `ketek`.
- **Polish form kontribusi:** draft lokal auto-save, progress stepper
  (lemma → arti/KBBI → gambar → kirim). UX, bukan fitur baru.

## Medium - buka kolaborasi lebih lebar

- **Impor massal CSV/Excel:** cara mengisi konten cepat dari kamus
  cetak/wordlist sebelum komunitas terbentuk. Pipeline Action:
  [`CSV_IMPORT_WITH_ACTION.md`](CSV_IMPORT_WITH_ACTION.md) (worker +
  Turso + webhook; impor browser existing tetap untuk batch kecil).
- **Auth growth:** register email + Google sign-in V1 selesai
  ([`AUTH_GOOGLE.md`](AUTH_GOOGLE.md)). Berikutnya Facebook
  ([`AUTH_FACEBOOK.md`](AUTH_FACEBOOK.md)). Di luar itu: Apple/GitHub,
  taut/lepas akun, tombol Google/Facebook admin.

---

## Tunda dulu (YAGNI)

- Gamifikasi penuh (badge/level) dan **leaderboard** - tunggu volume
  kontributor nyata. Statistik pribadi cukup dulu. Spesifikasi backlog:
  [`GAMIFIKASI.md`](GAMIFIKASI.md). Kontrak skor:
  [`docs/api/31-api-leaderboard.md`](../api/31-api-leaderboard.md).
- Push notification - setelah inbox in-app (sudah ada) terpakai dan
  kontrak event stabil. FCM approve kontribusi sudah jalan.
- Deteksi auto-brigading ber-ML - tooling manual di moderasi vote
  sudah cukup untuk skala sekarang.
- Dukungan multi-bahasa baru - infra generik, fokus konten Sambas dulu.
- Threaded discussion ala Wiktionary - komentar + vote sudah menutup
  kebutuhan diskusi di skala saat ini.
- Offline full dictionary pack - berat; mulai dari cache terarah.
- Rename `ActivityPage` / bersihkan komentar “placeholder”.

---

## Usulan eksekusi kuartal ini

1. Alur kembali + anti double-submit
2. Audio pelafalan penutur asli
3. Papan kualitas data admin

Discovery di Home tetap kandidat jika ingin app terasa kamus lebih dulu.

Milestone kasar: **A** akuntabilitas (inbox notifikasi ✅, sisa navigasi
submit) → **B** pemakaian berulang (cache; vote/komentar saya ✅) → **C**
keunggulan kamus (audio, normalisasi, WOTD) → **D** laporan masalah.

---

## Standar selesai untuk setiap fitur

- Kontrak API + `error_code` terdokumentasi sebelum UI dianggap selesai.
- Loading, empty, error, retry, dan state unauthorized yang sesuai.
- Aksi pengubah data aman dari double tap; refresh tidak menghapus
  state penting.
- Unit test use case/model + widget test alur utama; uji login, tamu,
  jaringan lambat/tanpa jaringan, tema terang/gelap bila relevan.
- Setelah fitur mobile selesai: perbarui `docs/api/` dan `http/`.
