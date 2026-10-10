# PREPARE_DELETE: Runbook Hapus Akun SambasKu

Dokumen internal pengelola. Tidak dipublikasikan.

Dasar hukum: UU 27/2022 (PDP) Pasal 7 ayat (1) hak tarik persetujuan, Pasal 9b kewajiban hapus. SLA: selesai paling lama 30 hari kerja sejak permintaan terverifikasi.

## Prinsip Pembagian

| Data | Perlakuan | Alasan |
|---|---|---|
| Data akun (user, token, avatar) | Hapus | Data pribadi murni |
| Rekaman suara (`word_audios`) | Hapus file + baris | Suara = data biometrik (PDP Pasal 1 angka 8) |
| Kontribusi teks (kata, arti, contoh, komentar, diskusi, vote, laporan) | Anonimkan pengunggah (`createdBy`/`userId` null) | Bukan data pribadi; jaga keutuhan kamus |
| Gambar kata (`word_images`) | Anonimkan pengunggah, file tetap | Foto benda/tempat bukan data pribadi pengunggah |

Pengecualian gambar: foto menampilkan orang yang dapat diidentifikasi DAN yang bersangkutan minta hapus → hapus file + baris.

Pengecualian audio: `speakerName` milik penutur lain TANPA bukti persetujuan (`speaker_consent` false/null) → tetap wajib hapus, dasarnya sama.

## Urutan Eksekusi

1. Verifikasi identitas peminta (email terdaftar di akun, atau bukti wali kalau anak di bawah 18).
2. Backup audit: simpan salinan catatan eksekusi (bukan datanya) ke audit log.
3. Jalankan penghapusan data pribadi, pola di `api/src/modules/auth/infrastructure/account-erasure.repository.impl.ts`:
   - user row, auth_identities, refresh tokens, device tokens, bookmarks, email/OTP tokens, password reset tokens;
   - avatar: hapus file di provider storage, null kolom `avatarUrl`/`avatarProvider`/`avatarProviderFileId`.
4. Hapus rekaman suara buatan akun: soft-delete baris `word_audios` (`deletedAt`), lalu hapus file di storage provider (`provider` + `providerFileId`).
5. Anonimkan `createdBy`/`userId` ke null pada: words, meanings, examples, pronunciations, word_images, discussions, comments, votes, word_reports, dan tabel UGC lain yang merujuk user.
6. Verifikasi akhir (query checklist):
   - tidak ada tabel UGC yang masih merujuk `userId` yang dihapus;
   - tidak ada baris `word_audios` aktif dari akun tersebut;
   - profil publik pengguna sudah tidak bisa diakses.
7. Balas email peminta: konfirmasi selesai + penjelasan kontribusi anonim yang tetap tayang.
8. Catat tanggal selesai untuk SLA 30 hari kerja.

## Kalau yang Minta Hapus Bukan Pemilik Akun

- Penutur suara (bukan pengunggah): cukup hapus rekaman suaranya, dasar PDP data biometrik.
- Orang yang ada di foto: hapus foto itu saja.
- Orang tua untuk anak: hapus seluruh akun anak.
