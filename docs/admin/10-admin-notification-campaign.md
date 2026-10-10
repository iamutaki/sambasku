# Admin - Notification Campaign

Panel Console untuk kirim pengumuman ke pengguna app.

## Akses

Role `admin` atau `root`. Menu:

- **Campaign notifikasi** → `/notification-campaigns`
- **Template notifikasi** → `/notification-templates`

## Alur singkat

1. (Opsional) buat template di Template notifikasi.
2. Campaign baru → pilih template atau isi judul/body.
3. Audience: semua device aktif **atau** pilih user (cari username/email).
4. Opsional jadwalkan `send_at`.
5. Simpan draft → buka detail → konfirmasi **Kirim sekarang**.
6. Pantau status / push sukses-gagal / inbox tertulis. Batalkan hanya
   sebelum mengirim. Retry gagal tersedia untuk audience terpilih.

## Catatan produk

- “Semua device” = akun yang sudah register FCM token (app terpasang + login).
- Judul disarankan ≤50 karakter, isi ≤150 untuk tampilan push yang rapi.
- Deep link `word` / `contribution` / `suggestion` membuka layar terkait
  di mobile; `url` / tanpa deep link membuka inbox.
