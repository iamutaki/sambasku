# Mobile - Verifikasi email OTP

Mengikuti `mobile-base-stack.md`: Section 2 (3 lapis per fitur), 6
(networking Dio + envelope), 11 (mapping error_code). Kontrak API:
[`../api/00-api-auth.md`](../api/00-api-auth.md) bagian OTP. Backlog:
[`../backlogs/AUTH_EMAIL_OTP.md`](../backlogs/AUTH_EMAIL_OTP.md).

Status (2026-09-21): V1. Register password tidak auto-login. Google
Sign-In bukan PR ini.

---

## Tujuan

Akun email/password aktif hanya setelah OTP 6 karakter 0-9A-Z dari email
(`XXX-YYY`). Login sebelum verifikasi: sheet, lalu halaman OTP.

---

## Titik masuk

1. Register sukses → `context.go('/verify-email?email=...')`
2. Login 403 `EMAIL_NOT_VERIFIED` → modal bottom sheet → halaman yang sama

File: `features/auth/` (bukan fitur baru). Router
[`auth_router.dart`](../../mobile/lib/features/auth/auth_router.dart).

---

## Perilaku

- Register: hapus auto-login. Copy bukan "langsung aktif tanpa OTP".
- Login: teruskan `errorCode` dari envelope. Jika
  `EMAIL_NOT_VERIFIED`, sheet (bukan toast). Email dari form.
- Verify: `POST /api/v1/auth/verify-email` `{ email, code, client_type:
  mobile }`. Sukses = envelope login. Simpan token + `markLoggedIn`.
- Resend: `POST /api/v1/auth/resend-otp`. Tombol disabled 2 menit
  setelah register / kirim ulang sukses / `429 RATE_LIMITED`. API
  menolak OTP < 2 menit (`RATE_LIMITED`). Email tak dikenal tetap 200.
- Input kode: 6 karakter 0-9A-Z, tampilan `XXX-YYY`. Kirim kode saja atau
  dengan tanda hubung (API terima keduanya).

Email OTP (API): header memakai wordmark horizontal PNG inline CID
(`otp-email-logo.ts`, MIME `image/png`). Bukan WebP - banyak klien
email (Outlook desktop) tidak merender WebP. Login/onboarding/about
mobile memakai `BrandLogo` (`logo.png` / `logo.staging.png`, radius
15). Reset password memakai HTML yang sama (logo CID + kotak kode),
tanpa tombol tautan: reset mobile first.

---

## Error UI

- `INVALID_OTP` / `OTP_EXPIRED`: alert di halaman verifikasi
- `RATE_LIMITED`: toast coba lagi
- 403 login: sheet judul "Email belum diverifikasi"

---

## Uji manual

1. Daftar email baru → bukan home; halaman OTP
2. Kode salah → INVALID_OTP, tetap di halaman
3. Kode benar → masuk home
4. Login akun belum verifikasi → sheet → OTP
5. Login akun lama (backfill) → langsung masuk
6. Kirim ulang: tombol menunggu 2 menit; terlalu cepat → RATE_LIMITED
