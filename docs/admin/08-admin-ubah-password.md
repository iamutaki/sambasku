# Admin Ubah Password - Halaman Profil & Ganti Password Sendiri

Halaman `/profile` (console layout) berisi layout profil user + satu
section "Ubah Password". Mengonsumsi `POST /api/v1/auth/change-password`
(`docs/api/10-api-ubah-password.md`) - TIDAK ada endpoint lain.
Setelah sukses, backend me-revoke SEMUA session; halaman wajib clear
sesi lokal + mengarahkan user ke login.

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):

- SUDAH ADA: base-stack admin (layout console, router flat child,
  `sessionStore` + `useAuth`, axios `client` Bearer + auto-refresh,
  pola form login-page, `ApiError.fieldErrors()` → `form.setFields`,
  `PageHeader`, `ROLE_LABELS`), endpoint API change-password (docs 10).
- Yang BELUM: fitur profile (folder `features/profile/`), route
  `/profile`, menu "Profil" di dropdown header, breadcrumb.

NON-GOAL (eksplisit):

- TIDAK menampilkan email - klaim JWT hanya `sub`/`role`/`username`,
  session user tidak menyimpan email. Follow-up: endpoint `/auth/me`
  atau tambah klaim `email` kalau profil perlu info lebih lengkap.
- TIDAK ada edit username/role sendiri. Role diubah admin lain lewat
  halaman Pengguna.

---

## Prompt

```text
Buatkan halaman Profil + form ubah password sendiri di admin console,
mengikuti pola features existing (domain/infrastructure/application/
presentation) dan form login-page.

KONTEKS:
- Endpoint: POST /auth/change-password body {old_password,
  new_password, confirm_password} → 200 {success, data:{message}};
  400 VALIDATION_ERROR/OAUTH_NO_PASSWORD; 401 INVALID_CREDENTIALS
  "Password lama salah"; semua session ter-revoke saat sukses.
- Akses: SEMUA role yang login (halaman profil, bukan admin-only).
- Session user: useAuth() → { id, username, role } (tanpa email).

STRUKTUR:
1. features/profile/infrastructure/profile-api.ts - BARU:
   changePasswordRequest(input) via axios `client` (Bearer). PENTING:
   pakai `client`, BUKAN `authClient` - prefix `/auth/` dikecualikan
   dari auto-retry 401, jadi 401 "Password lama salah" tidak memicu
   refresh cycle.
2. features/profile/application/use-change-password.ts - BARU:
   useMutation tipis (pola use-login), tanpa invalidasi query.
3. features/profile/presentation/pages/profile-page.tsx - BARU:
   PageHeader "Profil" + layout settings-style: Row → Col xs24 md8
   (Card identitas: Avatar UserOutlined besar, username strong, Tag
   role dari ROLE_LABELS; di bawahnya Menu mode="vertical" item
   "Ubah Password" LockOutlined) + Col xs24 md16 (Card "Ubah Password"
   berisi form). Mobile-first: semua Col xs=24 (Section 17).
4. features/profile/presentation/components/change-password-form.tsx
   - BARU: Form layout vertical requiredMark false, disabled saat
   pending. 3× Input.Password prefix LockOutlined:
   - "Password Lama" (autoComplete current-password, required)
   - "Password Baru" (autoComplete new-password; rules: min 8,
     mengandung huruf, mengandung angka, validator tidak boleh sama
     dengan password lama via dependencies ['old_password'])
   - "Konfirmasi Password Baru" (autoComplete new-password; validator
     sama dengan password baru via dependencies ['new_password'])
   Submit: mutateAsync → sukses: message.success("Password berhasil
   diubah. Silakan login kembali.") → sessionStore.clear() → navigate
   /login. Error: ApiError.fieldErrors() → form.setFields; 401 dengan
   message server → field error old_password; lainnya message.error.
5. app/router.tsx - UBAH: profileRoute path '/profile' (flat child
   consoleLayoutRoute, setelah usersRoute).
6. shared/layouts/console-layout.tsx - UBAH: (a) dropdown profil header
   dapat item "Profil" (UserOutlined) DI ATAS logout → navigate
   /profile; (b) BREADCRUMB_LABELS + 'profile': 'Profil'.

TIDAK ADA: perubahan API, unit test (pure presentation), menu sidebar.

Command verifikasi: pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

## Catatan Implementasi

- Request lewat axios `client` (Bearer), BUKAN `authClient`:
  interceptor `client` mengecualikan URL ber-prefix `/auth/` dari
  auto-retry 401, jadi 401 INVALID_CREDENTIALS "Password lama salah"
  TIDAK memicu refresh cycle (yang pasti gagal karena memakai cookie
  refresh yang masih valid - justru membuat error dobel). Kalau
  `AUTH_ENDPOINT_PREFIX` di `shared/api/client.ts` direfactor, cek
  endpoint ini ikut.
- `sessionStore.clear()` + `queryClient.clear()` dilakukan di hook
  `useChangePassword.onSuccess` (bukan di form) - form cukup
  `message.success` + `navigate({ to: '/login' })`. Query ter-cache
  tidak boleh nyangkut dengan sesi yang sudah mati.
- 401 dari backend dipetakan ke field error inline `old_password`
  (`form.setFields`) - pola sama dengan mapping `ApiError.fieldErrors()`
  untuk VALIDATION_ERROR.
- Casting `name as keyof ChangePasswordValues` diperlukan di
  `form.setFields` karena NamePath generic form (snake_case field
  names, langsung cocok dengan body API).
- Verifikasi: typecheck + lint (0 warning baru file tersentuh) + 91
  unit test + build sukses.

## Referensi Terkait

- `docs/api/10-api-ubah-password.md` - kontrak endpoint yang
  dikonsumsi (semantik revoke-all-session, error code).
- `docs/admin/admin-base-stack.md` - Section 7 (router & guard), 8
  (session), 9 (axios), 12 (error handling), 17 (responsive).
- `admin/src/features/auth/presentation/login-page.tsx` - pola form +
  mapping field error.
- `docs/api/00-api-auth.md` - fondasi auth (refresh token, kebijakan
  password).
