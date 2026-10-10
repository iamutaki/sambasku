# Mobile Komentar Saya

Mengikuti `mobile-base-stack.md`. Kontrak API:
[`../api/27-api-my-comments.md`](../api/27-api-my-comments.md).

Tile Profil "Komentar" membuka daftar komentar milik user, termasuk
yang diturunkan dan yang dihapus sendiri. Body di halaman ini utuh.

---

## Entry

- Route `/comments` (di luar tab shell, seperti Bookmark).
- Tile Profil "Komentar" hanya saat login: `context.push('/comments')`.
- Tamu yang buka route langsung melihat prompt "Masuk dulu untuk
  melihat komentar kamu" + tombol Masuk.

---

## Daftar

`GET /api/v1/comments/my?limit=20&cursor=&status=`.

Chip di atas list: Semua / Tayang / Diturunkan / Dihapus. Ganti chip
mengambil halaman pertama lagi.

| API | Label |
| --- | ----- |
| (tanpa `status`) | Semua |
| `published` | Tayang |
| `taken_down` | Diturunkan |
| `deleted_by_author` | Dihapus |

- Judul = `word_lemma`, atau "Kata tidak tersedia" jika lemma null.
- Subtitle = `{label status} · {cuplikan body 80 karakter} · {tanggal}`.
- Tap ke `/words/{word_id}` hanya jika `word_lemma != null`. Tidak ada
  deep-link ke komentar di detail kata.
- Kosong: "Belum ada komentar". Saat filter bukan Semua: "Tidak ada
  komentar dengan status ini".
- Pull-to-refresh, skeleton, error + coba lagi, load more.
- Tidak ada hapus dari daftar.

---

## Modul

```
mobile/lib/features/my_comments/
├── domain/
├── data/
├── presentation/
│   ├── models/my_comments_state.dart
│   ├── providers/my_comments_providers.dart
│   └── pages/my_comments_page.dart
└── my_comments_router.dart
```
