# SambasKu Mobile Proto

Static full mock (HTML) untuk aplikasi mobile SambasKu. Tidak ada backend,
tidak ada Flutter - hanya `styles.css` + file HTML per layar.

## Sumber

- Desain & aturan: `docs/UI.md`
- Struktur & copy: `mobile/lib/` (router, halaman, widget)
- Palet: `mobile/lib/core/theme/forui_palettes.dart` (`defaultPalette = zinc`)
- Kosakata mock: `csv/004-database sambasku:db_source.csv`

## Cara pakai

```bash
open docs/proto/mobile/OPENCODE-PROTO/index.html
```

Galeri `index.html` mengelompokkan semua layar dan bisa dicari. Setiap layar
punya stage-bar di atas frame ponsel yang menyebut route Flutter dan state
yang dimock (mis. `/words/:id · terverifikasi · login`).

## Peta layar

### Akun & Profil (36)

- `about.html` — Tentang · /about · loaded
- `bookmarks-empty.html` — Bookmark · /bookmarks · kosong
- `bookmarks-guest.html` — Bookmark · /bookmarks · guest
- `bookmarks.html` — Bookmark · /bookmarks · loaded
- `change-password-done.html` — Ubah Password · /change-password · sukses
- `change-password.html` — Ubah Password · /change-password · form
- `delete-account-done.html` — Hapus akun · /delete-account · selesai
- `delete-account.html` — Hapus akun · /delete-account · form
- `edit-profile.html` — Edit profil · /edit-profile · form
- `feedback-sent.html` — Beri Feedback · /feedback · sukses
- `feedback.html` — Beri Feedback · /feedback · form
- `linked-accounts-unlink.html` — Akun Terhubung · /linked-accounts · dialog konfirmasi
- `linked-accounts.html` — Akun Terhubung · /linked-accounts · loaded
- `my-comments-empty.html` — Komentar · /comments · kosong
- `my-comments-guest.html` — Komentar · /comments · guest
- `my-comments.html` — Komentar · /comments · loaded
- `my-contribution-404.html` — Detail usulan · /contributions/:kind/:id · 404
- `my-contribution-detail.html` — Detail usulan · /contributions/:kind/:id · menunggu
- `my-contribution-rejected.html` — Detail usulan · /contributions/:kind/:id · ditolak
- `my-contributions-empty.html` — Kontribusi Saya · /contributions · kosong
- `my-contributions-error.html` — Kontribusi Saya · /contributions · error
- `my-contributions.html` — Kontribusi Saya · /contributions · loaded
- `my-votes-empty.html` — Vote · /votes · kosong
- `my-votes-guest.html` — Vote · /votes · guest
- `my-votes.html` — Vote · /votes · loaded
- `notifications-empty.html` — Notifikasi · /notifications · kosong
- `notifications-guest.html` — Notifikasi · /notifications · guest
- `notifications.html` — Notifikasi · /notifications · loaded
- `report-bug-sent.html` — Laporkan Masalah · /report-bug · sukses
- `report-bug.html` — Laporkan Masalah · /report-bug · form
- `user-profile-404.html` — Profil publik · /users/:username · 404
- `user-profile.html` — Profil publik · /users/:username · loaded
- `verifier-application-approved.html` — Jadi verifikator · /verifier-application · disetujui
- `verifier-application-pending.html` — Jadi verifikator · /verifier-application · sedang ditinjau
- `verifier-application-rejected.html` — Jadi verifikator · /verifier-application · ditolak
- `verifier-application.html` — Jadi verifikator · /verifier-application · form

### Tab Utama (14)

- `activity-guest.html` — Kontribusi · /action · guest · deck read-only
- `activity.html` — Kontribusi · /action · login · deck aktif
- `appearance.html` — Tampilan · /profile → Tampilan
- `explore-bahasa-budaya.html` — Eksplorasi kategori · /explore/bahasa-budaya · live
- `explore-category.html` — Eksplorasi kategori · /explore/:id · coming soon
- `explore.html` — Eksplorasi · /explore · loaded
- `home-dark.html` — Home · / · loaded · Zinc dark
- `home-empty.html` — Home · / · feed kosong
- `home-error.html` — Home · / · state error
- `home-skeleton.html` — Home · / · loading skeleton
- `home.html` — Home · / · guest · loaded · Zinc light
- `profile-guest.html` — Profil · /profile · guest
- `profile-skeleton.html` — Profil · /profile · loading skeleton
- `profile.html` — Profil · /profile · login · role Reviewer

### Kontribusi (21)

- `contribute-error.html` — Usulkan kata · /contribute · state validasi
- `contribute-guest.html` — Usulkan kata · /contribute · guest
- `contribute-success.html` — Usulkan kata · /contribute · sukses
- `contribute.html` — Usulkan kata · /contribute · form default · login
- `pronunciation-guest.html` — Rekam Pelafalan · /words/:id/record · guest
- `pronunciation-queue.html` — Tinjau Pelafalan · /review/pronunciations · loaded
- `pronunciation-record.html` — Rekam Pelafalan · /words/:id/record · siap merekam
- `pronunciation-recording.html` — Rekam Pelafalan · /words/:id/record · merekam
- `pronunciation-review.html` — Tinjau Rekaman · /words/:id/record · konfirmasi
- `pronunciation-sent.html` — Rekam Pelafalan · /words/:id/record · terkirim
- `suggest-edit-reason.html` — Usulkan Perubahan · /suggest-edit/:wordId · reason sheet
- `suggest-edit-success.html` — Usulkan Perubahan · /suggest-edit/:wordId · sukses
- `suggest-edit.html` — Usulkan Perubahan · /suggest-edit/:wordId · form
- `discussion-create-guest.html` — Minta Bantuan · /discussions/create · guest
- `discussion-create.html` — Minta Bantuan · /discussions/create · form
- `discussion-detail.html` — Detail Bantuan · /discussions/:id · loaded
- `discussion-empty.html` — Ruang Diskusi · /discussions · kosong
- `discussion-feed.html` — Ruang Diskusi · /discussions · feed
- `discussion-mine-empty.html` — Bantuan Saya · /discussions/my · kosong
- `discussion-mine.html` — Bantuan Saya · /discussions/my · loaded
- `discussion-pending.html` — Detail Bantuan · /discussions/:id · menunggu

### Auth & Onboarding (14)

- `forgot-password-sending.html` — Lupa password · /forgot-password · state sending
- `forgot-password.html` — Lupa password · /forgot-password
- `legal.html` — Legal · /syarat-ketentuan · webview
- `login-error.html` — Login · /login · state error
- `login-unverified.html` — Login · /login · email belum terverifikasi
- `login.html` — Login · /login · guest · Zinc light
- `onboarding-features.html` — Onboarding · /onboarding · slide 2
- `onboarding-notif.html` — Onboarding · /onboarding · izin notifikasi
- `onboarding.html` — Onboarding · /onboarding · slide 1 · guest
- `register.html` — Daftar · /register · guest
- `reset-password-done.html` — Reset password · /reset-password · sukses
- `reset-password.html` — Reset password · /reset-password
- `verify-email-error.html` — Verifikasi email · /verify-email · kode salah
- `verify-email.html` — Verifikasi email · /verify-email

### Kamus (17)

- `mic-permission.html` — Izin mikrofon · /words/:id → rekam pelafalan
- `search-miss-empty.html` — Kata yang sering dicari · /search-misses · kosong
- `search-miss-error.html` — Kata yang sering dicari · /search-misses · state error
- `search-miss.html` — Kata yang sering dicari · /search-misses · Indonesia → Sambas
- `share-card.html` — Share card · /words/:id → Bagikan kartu
- `word-detail-404.html` — Detail kata · /words/:id · WORD_NOT_FOUND
- `word-detail-error.html` — Detail kata · /words/:id · state error
- `word-detail-guest.html` — Detail kata · /words/:id · guest
- `word-detail-pending.html` — Detail kata · /words/:id · menunggu pengecekan
- `word-detail-sheet.html` — Detail kata · /words/:id · action sheet
- `word-detail.html` — Detail kata · /words/:id · terverifikasi · login
- `word-history.html` — Riwayat perubahan · /words/:id/history · loaded
- `word-list-miss.html` — Daftar Kata A-Z · /words · search miss · kosong
- `word-list-sambas.html` — Daftar Kata A-Z · /words?sambas=1 · hasil
- `word-list-skeleton.html` — Daftar Kata A-Z · /words · loading skeleton
- `word-list.html` — Daftar Kata A-Z · /words · Indonesia → Sambas · loaded
- `word-report-photo.html` — Detail kata · /words/:id · laporkan foto

### Review & Verifikasi (9)

- `review-correct.html` — Sesi tinjau · /review/session · form koreksi
- `review-forbidden.html` — Tinjau usulan · /review · role tidak diizinkan
- `review-queue-empty.html` — Tinjau usulan · /review · antrean kosong
- `review-queue-error.html` — Tinjau usulan · /review · state error
- `review-queue.html` — Tinjau usulan · /review · login reviewer · loaded
- `review-reject.html` — Sesi tinjau · /review/session · reject sheet
- `review-session-done.html` — Sesi tinjau · /review/session · selesai
- `review-session-verified.html` — Sesi tinjau · /review/:id · sudah terverifikasi
- `review-session.html` — Sesi tinjau · /review/session · kartu 1/5

## Catatan

- State yang dimock: loaded, skeleton, kosong, error, guest, forbidden, 404.
- Dark mode ada di `home-dark.html`; token warna dark di `styles.css`
  (`.phone.dark`).
- Semua ikon inline SVG, tidak ada dependensi eksternal.
