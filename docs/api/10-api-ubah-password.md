# API Ubah Password - Ganti Password Sendiri (User Ter-autentikasi)

Mengikuti `api-base-stack.md`: Section 3 (struktur folder), 9
(`@hono/zod-openapi` + Scalar), 10 (testing), 11 (versioning `/api/v1/`),
13 (envelope & error), 15 (rate limiting), 21 (audit trail). Endpoint ini
adalah pasangan self-service dari `reset-password` (00): reset via token
email untuk user lupa password, change untuk user yang MASIH login dan
tahu password lamanya.

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):

- SUDAH ADA: modul auth lengkap (register/login/refresh/logout/
  logout-all-devices/forgot/reset), `UserRepository.updatePassword(id,
  passwordHash)`, `RefreshTokenRepository.revokeAllForUser(userId)`,
  `PasswordHasherPort` (PBKDF2), value object `Password.create` (min 8,
  huruf, angka), preseden use case `reset-password` (update → revokeAll →
  audit `password_change`), rate limit keyFn per user (pola vote).
- Yang BELUM: endpoint change-password, use case, validator, wiring,
  tests, Bruno, error code `OAUTH_NO_PASSWORD`.

KEPUTUSAN PRODUK (2026-09-19):

- Hanya untuk user LOGIN (Bearer). `user_id` SELALU dari token, bukan
  body - user tidak bisa mengganti password orang lain.
- Wajib password lama (verifikasi kepemilikan akun di sisi server,
  menutup celah sesi aktif yang dibajak).
- Setelah sukses: SEMUA refresh token user di-revoke (logout paksa semua
  perangkat, termasuk yang sekarang) - preseden reset-password. Akses
  token stateless tetap hidup sampai exp, jadi client WAJIB clear sesi
  lokal + arahkan ke login.
- Akun OAuth-only (`password_hash` NULL) ditolak dengan error code
  khusus `OAUTH_NO_PASSWORD` + arahkan ke alur lupa password.

---

## Prompt

```text
Buatkan endpoint ubah password sendiri untuk user ter-autentikasi
pada modul auth backend Kamus Digital Sambas-Indonesia. TIDAK ADA
perubahan schema/method repository - semua fondasi sudah ada.

LOKASI: modules/auth/ (extend modul existing)

STRUKTUR FILE YANG PERLU DIBUAT/DIUBAH:

modules/auth/
├── application/
│   ├── dto/change-password.dto.ts                    # BARU
│   └── use-cases/change-password.use-case.ts         # BARU
└── presentation/v1/
    ├── auth.controller.ts                            # UBAH: +changePassword
    ├── auth.routes.ts                                # UBAH: +route
    └── validators/change-password.validator.ts       # BARU

app.ts                                                 # UBAH: DI use case
ERROR_CODES.md                                         # UBAH: +OAUTH_NO_PASSWORD

DTO: ChangePasswordDto { oldPassword: string; newPassword: string }
(confirm_password TIDAK melewati batas controller - itu concern
validator zod, sama seperti register.)

USE CASE ChangePasswordUseCase(userRepo, hasher, auditRepo,
refreshTokenRepo).execute(dto, userId, requestId?) urutan:
1. Password.create(dto.newPassword) - gate domain (ValidationError
   400 kalau <8 karakter / tanpa huruf / tanpa angka).
2. dto.oldPassword === dto.newPassword → ValidationError field
   `new_password` "Password baru tidak boleh sama dengan password
   lama" (tetap VALIDATION_ERROR, tanpa kode katalog baru).
3. userRepo.findById(userId) null → UnauthorizedError('UNAUTHORIZED').
4. user.passwordHash === null (OAuth-only) → BadRequestError(
   'OAUTH_NO_PASSWORD', 'Akun ini tidak memiliki password (login via
   OAuth). Gunakan lupa password untuk membuat password.') - cek ini
   SEBELUM hasher.compare (compare ke null menyesatkan).
5. hasher.compare(old, passwordHash) false → UnauthorizedError(
   'INVALID_CREDENTIALS', 'Password lama salah').
6. userRepo.updatePassword(userId, hasher.hash(new)).
7. refreshTokenRepo.revokeAllForUser(userId).
8. auditRepo.record({ userId, action: 'password_change',
   entityType: 'user', entityId: userId, newData: { changed: true,
   via: 'change_password' }, requestId }) - best-effort, TANPA hash.

VALIDATOR change-password.validator.ts (cermin register +
reset-password):
- old_password: z.string().min(1, 'Password lama wajib diisi')
- new_password: z.string().min(8).regex(/[a-zA-Z]/, 'harus mengandung
  huruf').regex(/[0-9]/, 'harus mengandung angka')
- confirm_password: z.string().min(1)
- .refine(new === confirm, path ['confirm_password'], 'Konfirmasi
  password tidak sama dengan password baru')
- changePasswordResponseSchema: { success: literal(true), data:
  { message: string } } (cermin resetPasswordResponseSchema)

CONTROLLER changePassword(c, body):
- userId = ctx.get('user').user_id (dari token, BUKAN body) +
  requestId = ctx.get('requestId').
- Map body snake_case → dto camelCase.
- Response 200: { success: true, data: { message: 'Password berhasil
  diubah. Silakan login kembali.' } }

ENDPOINT (WAJIB - Section 9, createRoute + json helper):

POST /api/v1/auth/change-password
Middleware (urutan PENTING, daftarkan dengan routes.use SEBELUM semua
openapi() lain):
  1. authenticate  (Bearer; HARUS duluan supaya c.get('user') terisi)
  2. rateLimit({ points: 5, duration: 900, keyFn: c =>
     `change-password:${c.get('user')?.user_id}` })  // 5/15 menit per
     user (bukan IP - user login, identitas pasti)

Request:
{
  "old_password": "Password123",
  "new_password": "PasswordBaru123",
  "confirm_password": "PasswordBaru123"
}

Response 200:
{ "success": true, "data": { "message": "Password berhasil diubah. Silakan login kembali." } }

Response 400 VALIDATION_ERROR (body lemah / confirm beda / new=old):
{ "success": false, "error_code": "VALIDATION_ERROR", "message": "Data yang dikirim tidak valid", "details": [{ "field": "new_password", "message": "harus mengandung angka" }] }

Response 400 OAUTH_NO_PASSWORD:
{ "success": false, "error_code": "OAUTH_NO_PASSWORD", "message": "Akun ini tidak memiliki password (login via OAuth). Gunakan lupa password untuk membuat password.", "details": null }

Response 401 (tanpa/invalid token ATAU password lama salah):
{ "success": false, "error_code": "INVALID_CREDENTIALS", "message": "Password lama salah", "details": null }

Response 429 RATE_LIMITED: standar Section 15.

OpenAPI responses: 200/400/401/429 semua json(errorResponseSchema)/
changePasswordResponseSchema, tags ['Auth'].

KEPUTUSAN SEMANTIK:
- Konfirmasi ulang via password lama = verifikasi kepemilikan; token
  valid BUKAN bukti cukup (laptop yang tidak terkunci, dsb.).
- revokeAllForUser = SEMUA sesi mati termasuk current (akun mungkin
  tercompromi; aman daripada nyaman) - preseden reset-password.
- Rate limit per user_id (5/15 menit) menahan brute-force password
  lama lewat endpoint ini.
- Access token stateless TIDAK dicabut (tidak ada mekanisme) - client
  harus clear sesi lokal + redirect login setelah sukses.

KEAMANAN & CATATAN:
- user_id dari token saja (cek controller).
- Audit newData TIDAK memuat hash/password mentah (Section 21).
- ERROR_CODES.md wajib ditambah baris OAUTH_NO_PASSWORD (400) di PR
  yang sama.
- Bruno: http/auth/change-password.bru (Bearer var + body JSON).

TESTING:
- Unit (mock repo): sukses (urutan compare → updatePassword →
  revokeAll → audit); old salah → INVALID_CREDENTIALS; hash null →
  OAUTH_NO_PASSWORD; user null → UNAUTHORIZED; new=old →
  ValidationError; password lemah throw SEBELUM pemanggilan repo.
- E2E (auth.e2e.test.ts, describe baru, user segar per kasus karena
  rate limit per user): happy path 200 → refresh token lama jadi 401 →
  login dengan password BARU sukses, password lama 401; old salah 401;
  validasi (kurang dari 8 / confirm beda / sama dengan lama) 400;
  tanpa token 401.
```

## Catatan Implementasi

- Middleware `authRoutes.use('/change-password', deps.authenticate,
  rateLimit(...))` didaftarkan DI ATAS blok `openapi()` lain di
  `createAuthRoutes` - Hono match `.use` per path; urutan blok `use`
  sudah ada sebelumnya (register/login/forgot), cukup ikut sisip di
  sana.
- Guard `user.passwordHash === null` (OAUTH_NO_PASSWORD) dilakukan
  SEBELUM `hasher.compare` - compare ke null akan false-negative
  menjadi "Password lama salah" yang menyesatkan.
- Audit `newData` memuat `via: 'change_password'` untuk membedakan
  dari reset-password (sama-sama `action: 'password_change'`).
- Testing: 40 file / 257 test lulus (+6 unit use case, +4 e2e auth).
  E2E happy path memverifikasi refresh token lama jadi 401 setelah
  ubah password (semua session ter-revoke) dan login ulang dengan
  password baru sukses.

## Referensi Terkait

- `docs/api/00-api-auth.md` - fondasi auth (register policy password,
  refresh token, reset-password).
- `docs/api/api-base-stack.md` - Section 13 (envelope & error), 15
  (rate limiting), 21 (audit trail).
- `api/ERROR_CODES.md` - katalog error code (termasuk
  `OAUTH_NO_PASSWORD`).
- `http/auth/change-password.bru` - request Bruno.
- `docs/admin/08-admin-ubah-password.md` - UI admin yang mengonsumsi
  endpoint ini.
