# Admin UI - CMS Blocklist Kata Komentar

Kontrak: `10-api-comment-blocklist.md`.

Halaman `/comment-blocklist` (admin/root):
- List kata aktif (cursor) + pencarian `q` supaya kata di halaman lain bisa ditemukan lalu dihapus.
- Form tambah: satu kata, atau banyak sekaligus dipisah koma / baris baru (`lorem, ipsum, dolo`).
- Unggah CSV/TXT (maks 2 MB, 20.000 kata). Satu kata per baris, atau dipisah koma/titik koma. Header `word`/`kata` dilewati.
- Duplikat yang sudah aktif diabaikan (bukan error).
- Hapus (soft-delete) per baris.
- Menu sidebar di bawah/ dekat Komentar.

Tidak ada preview live filter di UI v1; efek terlihat saat create
komentar di mobile/API.

## Referensi

- `10-api-comment-blocklist.md`
- `09-api-comment.md`
