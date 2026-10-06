# 23 - Mobile feed lintas aktivitas (beranda)

Kontrak API: [`docs/api/37-api-activity-feed.md`](../api/37-api-activity-feed.md).

## Ringkasan

Tab Home menampilkan section **Aktivitas terbaru** dari
`GET /api/v1/activity` (bukan lagi `GET /words/latest`).

- Tamu + login boleh baca.
- Tanpa realtime: buka ulang / pull-to-refresh.
- Baris: **foto profil** (atau lingkaran ikon user bila belum ada foto) +
  badge jenis kecil di kanan bawah avatar (warna tema adaptif) + nama +
  body + waktu relatif + label jenis singkat (Kata / Komentar / Nilai / …).
- Kata Hari Ini tetap kartu terpisah; item `kind=word` dengan id sama
  disembunyikan dari list supaya tidak dobel.

## Navigasi tap

| target.type | Tujuan |
|-------------|--------|
| `word` | `/words/:id` |
| `discussion` | `/discussions/:id` |
| `search_miss` | `/contribute?lemma=…&miss_id=…` |

Nama aktor yang linkable → profil publik.

## Tampilan baris feed

Dua keputusan render di `ActivityFeedTile` (satu widget dipakai feed beranda + daftar aktivitas profil publik):

- **Lemma tanpa kutip, cukup bold.** API masih mengutip lemma di body (`"kumis" sudah pas`, `Mencari "x" - belum ada di kamus.`) sebagai penanda struktur. Mobile membuang kutipnya saat render lewat `splitQuotedLemma()` (`feed_activity_item.dart`): span yang terdeteksi lemma di-emit tanpa tanda kutip dan diberi `FontWeight.w700`. Alasan: banyak kosakata Sambas memakai `'` di tengah/akhir kata, tambahan `"` membuat feed riuh. Kutip di payload tetap dipakai untuk parsing (mis. `_searchMissTerm` membaca `Mencari "([^"]+)"` dari body mentah), jadi jangan ubah copy API.
- **`@username` kecil di bawah nama aktor.** Nama aktor (`displayName` atau fallback username) ditampilkan bold; `@username` di baris tersendiri di bawahnya, style `typography.xs` warna `mutedForeground`. Hanya muncul kalau `canOpenProfile` (akun `Warga`/dihapus tidak punya username yang bisa ditautkan). Tap pada nama maupun `@username` membuka profil publik. Berlaku otomatis untuk feed beranda dan daftar aktivitas profil publik karena widget sama.

## Menyembunyikan karya sendiri

Feed beranda tidak menampilkan activity milik user yang sedang login.(App kirim
`?exclude_self=true`; penyaringan terjadi di API, lihat
[`37-api-activity-feed.md`](../api/37-api-activity-feed.md).)

- **Login** → `exclude_self=true` dikirim, baris milik sendiri dibuang server.
- **Tamu** → flag tidak dikirim sama sekali, feed publik penuh.
- Kalau `isAuth` sudah true tapi `userId` masih null (prefs belum terisi, sync
  `GET /users/me` gagal), app **tidak** mengirim flag → semua tetap tampil.
  Lebih aman: saat tidak yakin siapa dirinya, jangan disembunyikan.
- Auth tidak di-read manual di repository. `AuthInterceptor` sudah menempelkan
  Bearer di setiap request selama token ada di storage.
- Notifier memuat ulang feed saat identitas berubah (login/logout), kalau tidak
  halaman tamu yang sudah ter-cache masih tampil setelah login. Penjacunya hanya
  `isAuth` + `userId` — ganti avatar/display name tidak memuat ulang feed.
- Karya sendiri tidak hilang dari app: Kontribusi Saya, Komentar Saya, Nilai Saya,
  dan tab Aktivitas tetap menampilkannya.

## Kode

- Entity / mapper: `mobile/lib/features/activity/domain/entities/`,
  `data/map_feed_activity.dart`
- Repo: `mobile/lib/features/activity/data/activity_feed_repository.dart`
  (cache L1 `feedList`)
- Provider: `mobile/lib/features/activity/presentation/providers/activity_feed_providers.dart`
- UI: `mobile/lib/features/dictionary/presentation/pages/home_search_page.dart`
  (`_ActivityFeedRow`)
- Tile: `mobile/lib/features/activity/presentation/widgets/activity_feed_tile.dart`
  (dipakai feed beranda + daftar aktivitas profil publik)

## Cache

Pull-to-refresh menghapus prefix `GET|/api/v1/activity` + invalidate
WOTD, lalu `load(forceRefresh: true)`.

Cache key (`buildCacheKey`) sengaja tidak memuat `Authorization`, tapi **memuat
query** — jadi feed login (`…|exclude_self=true&limit=20`) dan feed tamu
(`…|limit=20`) punya entri terpisah dan tidak saling menimpa.

## Wording dua permukaan (aturan event, #86)

Feed beranda = aktor sebagai subjek + body + label + CTA
(`Nama · Menambah foto · "lawang" [Foto]`). Timeline profil publik =
kalimat aksi berimbuhan tanpa subjek (`Menambahkan foto kata lawang`),
diproduksi `listPublicByActor` di API; `suggestion_applied` di profil
berframing pencapaian (`Usulan perubahan diterima`). `search_miss`
hanya tampil di beranda (tanpa aktor). Profil sendiri tidak menampilkan
CTA. Kind wire `contribution` (usul kata baru, `contribution_submitted`)
dirender seperti `suggestion`: label chip "Usulan kata baru", body
`Mengusulkan kata baru · "lemma"`, CTA buka detail kata. Kontrak wording
lengkap: `docs/api/37-api-activity-feed.md` dan
`docs/api/19-api-profil-publik.md`.

## Di luar scope

- Ably / listen realtime
- Feed Analitik admin
