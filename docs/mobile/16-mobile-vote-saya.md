# Mobile Vote Saya

Mengikuti `mobile-base-stack.md`. Kontrak API:
[`../api/26-api-my-votes.md`](../api/26-api-my-votes.md).

Tile Profil "Vote" membuka daftar vote milik user login. Bukan feed
orang lain. Tidak ada unvote dari daftar ini.

---

## Entry

- Route `/votes` (di luar tab shell, `parentNavigatorKey` root, seperti
  Bookmark).
- Tile Profil "Vote" hanya saat login: `context.push('/votes')`.
- Tamu yang buka route langsung melihat prompt "Masuk dulu untuk
  melihat vote kamu" + tombol Masuk.

---

## Daftar

`GET /api/v1/votes/history?limit=20&cursor=`. Tanpa chip filter di V1
(`target_type` / `value` disiapkan API, UI menyusul).

- Judul = `word.lemma`, atau "Kata sudah dihapus" jika `word` null.
- Subtitle = `{Upvote|Downvote} · {Kata|Arti|Contoh|Pelafalan|Gambar|Komentar} · {tanggal}`.
- Chevron dan tap ke `/words/{word.id}` hanya jika `word != null`.
- Pull-to-refresh, skeleton, kosong "Belum ada vote", error + coba lagi.
- `loadMore` hanya jika `hasMore` dan `nextCursor` ada.

Controller keepAlive. Login/logout memuat ulang lewat watch status
auth. Setelah toggle vote di detail kata sukses, daftar ini
di-invalidate supaya vote yang baru dibatalkan tidak tertinggal.

Fitur `features/vote` (tombol di detail) tidak dipecah. Datasource
riwayat tidak masuk `VoteController`.

---

## Modul

```
mobile/lib/features/my_votes/
├── domain/
├── data/
├── presentation/
│   ├── models/my_votes_state.dart
│   ├── providers/my_votes_providers.dart
│   └── pages/my_votes_page.dart
└── my_votes_router.dart
```
