# Admin UI - Komentar pada Detail Kata (Marking + Takedown)

Kontrak: `09-api-comment.md`. Section "Komentar" di detail kata.

KEPUTUSAN (2026-09-22):
- Tampilkan semua status aktif (`published` | `taken_down` |
  `deleted_by_author`) dengan Tag warna berbeda.
- `taken_down`: Tag merah "Di-takedown"; body asli tetap terlihat admin.
- `deleted_by_author`: Tag abu "Dihapus penulis".
- Baris `published`: tombol Takedown inline (modal confirm).
- Jika `is_censored`: Tag emas "Disensor", tampilkan `body_original`,
  tombol **Pulihkan teks** → `POST .../uncensor`.
- Invalidasi queryKey prefix `['comments']` setelah takedown/uncensor.

## Referensi

- `06-comment-moderasi.md`
- `09-api-comment.md`
