# Mobile - Lupa password

Mengikuti `mobile-base-stack.md`: Section 2 (3 lapis per fitur), 6
(networking Dio + envelope), 11 (mapping error_code). Kontrak API:
[`../api/00-api-auth.md`](../api/00-api-auth.md) bagian forgot/reset.

---

## Tujuan

User mengatur password baru **di aplikasi**: kode 6 karakter 0-9A-Z dari email
(pola OTP verifikasi). Email tidak menampilkan tombol atau tautan reset.

---

## Titik masuk

1. Login → `Lupa password?` → `/forgot-password`
2. Sukses kirim → `/reset-password?email=...` (kode + password baru)
3. Deep link `{APP_URL}/reset-password?token=...` tetap didukung API,
   tapi tidak dikirim di email (mobile first)

File: `features/auth/` (bukan fitur baru). Router
[`auth_router.dart`](../../mobile/lib/features/auth/auth_router.dart).

Ubah password saat sudah login tetap di
`features/change_password/` (`POST /change-password`).

---

## Perilaku

- Forgot: `POST /api/v1/auth/forgot-password` `{ email }`. Response
  selalu sama (anti-enumeration). Rate limit 5/15 menit. Email: kode
  `XXX-YYY` saja, tanpa tombol tautan.
- Reset di app: `POST /api/v1/auth/reset-password` `{ email, code,
  new_password }`.
- API masih menerima `{ token, new_password }` (deep link), bukan jalur
  utama.
- Sukses: semua sesi dicabut. Dialog lalu `/login`.
- Password baru: minimal 8 karakter, huruf + angka.

---

## Uji manual

1. Login → Lupa password → kode di email
2. Isi kode + password baru di app → dialog sukses → masuk
3. Kode salah / kadaluarsa → `RESET_TOKEN_INVALID`
4. Pakai kode yang sama lagi → ditolak
5. Email tidak berisi tombol "Atur password baru"
