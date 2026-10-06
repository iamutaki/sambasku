# Plan: Kunci `GET /api/v1/bug-reports/upload-token` dengan JWT (Issue #67)

## Goal

Endpoint upload-token ImageKit tidak bisa lagi dicetak anonim: wajib Bearer
JWT, plus bucket rate limit per-user. Tamu tetap bisa kirim laporan bug
(teks saja), sesuai alur soft-fail yang sudah ada di mobile.

## Current context / assumptions

- Endpoint sengaja dibuat publik saat fitur report-bug dibuat (keputusan
  produk #4 di `docs/api/30-api-bug-reports.md`, backlog
  `docs/backlogs/done/REPORT_BUG.md`) supaya tamu bisa lampirkan screenshot.
  Issue #67 melaporkan konsekuensinya: siapa pun bisa membakar kuota
  ImageKit. Fix = keputusan produk direvisi.
- Sudah ada di endpoint ini dan TIDAK perlu diubah:
  - Validasi `folder` terkunci `/bug-reports` (400 `VALIDATION_ERROR`).
  - Bucket IP 40/jam + device 20/jam (`api/src/modules/bug-report/presentation/v1/bug-report.routes.ts:29-41,68`).
  - TTL token ImageKit 30 menit (`TOKEN_TTL_SECONDS`, `api/src/modules/image/infrastructure/imagekit-storage.service.ts:7`).
- Pattern yang mau ditiru sudah ada di discussion module:
  `api/src/modules/discussion/presentation/v1/discussion.routes.ts:108`
  (`routes.use('/upload-token', deps.authenticate, ...writeClient, tokenUserLimit, tokenIpLimit)`).
- Middleware `authenticate` (401 kalau tanpa/invalid Bearer) sudah ada:
  `api/src/shared/middlewares/authenticate.middleware.ts:63`
  (`createAuthenticateMiddleware`), sudah di-wire di `api/src/app.ts:524`
  sebagai `authenticate`, dan route bug-report menerima deps di
  `api/src/app.ts:1228` (saat ini hanya `optionalAuthenticate`).
- Mobile: `ReportBugPage` sudah punya `isGuest` (dari `authStatusProvider`,
  `mobile/lib/features/report_bug/presentation/report_bug_page.dart:31`)
  dan seluruh alur soft-fail "kirim tanpa gambar" sudah ada. Artinya
  menyembunyikan lampiran untuk tamu murni perubahan kondisional render.
- Mobile `AuthInterceptor` otomatis menyisipkan Bearer untuk user login
  (`mobile/lib/core/network/interceptors/auth_interceptor.dart:65-70`), jadi
  repository mobile TIDAK perlu diubah.
- Controller dan response 200 tidak berubah (reuse
  `ImageController.uploadCredentials`, `api/src/modules/bug-report/presentation/v1/bug-report.controller.ts:49`).
- Test e2e butuh `.env.test` dengan `DATABASE_URL` (file test pakai
  `describe.skipIf(!hasTestDb)`). Package manager API: pnpm.
- Deployment staging + production ada di luar repo; plan sertakan curl
  verifikasi pasca-deploy.

## Architecture / proposed approach

Pindahkan `GET /bug-reports/upload-token` dari publik ke wajib-login dengan
menambahkan middleware `authenticate` + bucket per-user (20/jam) sebelum
handler, meniru pola discussion. Ganti bucket per-device dengan per-user
(karena auth sekarang wajib, bucket user secara konsisten lebih kuat dari
bucket device). Di mobile, sembunyikan bagian lampiran untuk tamu sehingga
panggilan upload-token hanya terjadi untuk user login; tamu tetap submit
teks (alur anonim yang sudah ada).

## Step-by-step tasks

Kerjakan berurutan. Commit kecil per task, branch baru dari `staging`.

### Task 1: E2E test merah (TDD RED)

File: `api/src/modules/bug-report/__tests__/e2e/v1/bug-report.e2e.test.ts`

Ganti dua test upload-token yang ada (sekitar baris 71-84) dengan tiga test
ini (`contributorToken` sudah disiapkan `beforeAll`):

```ts
  it('token tanpa login → 401 UNAUTHORIZED', async () => {
    const res = await request('/api/v1/bug-reports/upload-token?folder=/bug-reports');
    expect(res.status).toBe(401);
    expect((await res.json()).error_code).toBe('UNAUTHORIZED');
  });

  it('token login folder /words → 400 VALIDATION_ERROR', async () => {
    const res = await request('/api/v1/bug-reports/upload-token?folder=/words', {
      headers: { Authorization: `Bearer ${contributorToken}` },
    });
    expect(res.status).toBe(400);
    expect((await res.json()).error_code).toBe('VALIDATION_ERROR');
  });

  it('token login folder /bug-reports → 200 atau 503 IMAGE_UPLOAD_UNAVAILABLE', async () => {
    const res = await request('/api/v1/bug-reports/upload-token?folder=/bug-reports', {
      headers: { Authorization: `Bearer ${contributorToken}` },
    });
    expect([200, 503]).toContain(res.status);
    const body = await res.json();
    if (res.status === 503) {
      expect(body.error_code).toBe('IMAGE_UPLOAD_UNAVAILABLE');
    } else {
      expect(typeof body.data.token).toBe('string');
    }
  });
```

Verifikasi merah:

```
cd api && pnpm vitest run src/modules/bug-report/__tests__/e2e/v1/bug-report.e2e.test.ts
```

Expected: test "token tanpa login → 401" GAGAL (endpoint masih balas
200/503), dua test lain lulus. Commit: `test(bug-report): upload-token wajib login (red)`.

### Task 2: Route wajib login + bucket per-user (TDD GREEN)

File: `api/src/modules/bug-report/presentation/v1/bug-report.routes.ts`

1. Ganti interface deps (baris 24-27):

```ts
export interface BugReportRoutesDeps {
  controller: BugReportController;
  authenticate: MiddlewareHandler<{ Variables: AppVariables }>;
  optionalAuthenticate: MiddlewareHandler<{ Variables: AppVariables }>;
}
```

2. Tambah bucket per-user (letakkan sebelum `tokenIpLimit`, baris 29) dan
   HAPUS konstanta `tokenDeviceLimit` (baris 34-41, hanya dipakai
   upload-token):

```ts
const tokenUserLimit = rateLimit({
  points: 20,
  duration: 3600,
  keyFn: (c) => {
    const uid = (c as { get: (k: 'user') => { user_id: string } | undefined }).get('user')?.user_id;
    return uid ? `bug-tok:user:${uid}` : '';
  },
});
```

3. Ganti baris wiring (baris 68):

```ts
  routes.use('/upload-token', deps.authenticate, tokenUserLimit, tokenIpLimit);
```

4. Di `uploadTokenRoute.responses`, tambahkan setelah `200`:

```ts
      401: { description: 'Bearer tidak ada/invalid', content: json(errorResponseSchema) },
```

5. Ubah `summary` route (baris 91) jadi:
   `'Kredensial direct-upload ImageKit (wajib login), folder hanya /bug-reports'`.

File: `api/src/app.ts` (baris 1228) - wajib agar TypeScript lolos:

```ts
  createBugReportRoutes({ controller: bugReportController, optionalAuthenticate, authenticate }),
```

Verifikasi hijau:

```
cd api && pnpm vitest run src/modules/bug-report/__tests__/e2e/v1/bug-report.e2e.test.ts
cd api && pnpm typecheck
```

Expected: semua test lulus ("Test Files 1 passed"), typecheck tanpa error.
Commit: `fix(security): kunci upload-token bug-report dengan JWT + limit per-user (#67)`.

### Task 3: Bruno collection

File: `http/bug-report/upload-token.bru`

- Di blok `get`, ganti `auth: none` menjadi `auth: bearer`.
- Tambah blok (sama seperti `http/bug-report/submit-auth.bru:16-18`):

```
auth:bearer {
  token: {{access_token}}
}
```

- Perbarui blok `docs {` menjadi:

```
docs {
Token upload lampiran laporan masalah. WAJIB login (Bearer); tanpa/invalid
token → 401. Query folder wajib `/bug-reports`, lainnya → 400. ImageKit
belum dikonfigurasi → 503 IMAGE_UPLOAD_UNAVAILABLE. Rate 20/jam per user +
40/jam per IP. Sample: docs/json/bug-report/upload-token.200.json
}
```

Verifikasi: buka folder `http/` di Bruno, jalankan request dengan
`access_token` dari environment. Expected: 200 dengan `data.token` string;
hapus token → 401 `UNAUTHORIZED`. Commit:
`test(http): upload-token bug-report pakai bearer`.

### Task 4: Docs API

File 1: `docs/api/30-api-bug-reports.md`

- Keputusan produk #4 (baris 21-23) ganti menjadi:

```
4. Token upload `GET /api/v1/bug-reports/upload-token` wajib login
   (Bearer), folder terkunci `/bug-reports`. Tamu kirim laporan tanpa
   lampiran. Jalur `/admin/images/upload-token` tidak diubah.
```

- Keputusan #8 (baris 30-31): ganti "token publik 20/jam per device +
  40/jam per IP" menjadi "token (wajib login) 20/jam per `user_id` +
  40/jam per IP".
- Section endpoint (baris 60-67): ganti kalimat pertama "Publik." menjadi
  "Wajib login (Bearer). Tanpa/invalid token → 401 `UNAUTHORIZED`." dan
  sebut rate limit baru (20/jam user + 40/jam IP).
- Tabel error code (baris 121-128): baris `UNAUTHORIZED` ubah "Kapan"
  menjadi "Bearer ada tapi invalid (submit); admin tanpa token;
  upload-token tanpa/invalid token".

File 2: `docs/api/api-base-stack.md` (baris ~1300)

- Keluarkan `GET /bug-reports/upload-token` dari daftar "Publik, tulis
  (belum login)" dan ganti "Token `GET /bug-reports/upload-token`: 20/jam
  device + 40/jam IP" menjadi "Token `GET /bug-reports/upload-token`
  (wajib login): 20/jam user + 40/jam IP".

Verifikasi: `grep -n "upload-token" docs/api/30-api-bug-reports.md docs/api/api-base-stack.md` -
tidak ada lagi klaim "publik/tanpa auth" untuk endpoint ini. Commit:
`docs(api): upload-token bug-report wajib login (#67)`.

### Task 5: Mobile - lampiran hanya untuk user login

File: `mobile/lib/features/report_bug/presentation/report_bug_page.dart`

Repository dan upload service TIDAK diubah (interceptor sudah menyisipkan
Bearer untuk user login).

1. Ganti kondisi render lampiran (baris 174) agar tamu tidak pernah
   memanggil upload-token:

```dart
          if (attachmentsEnabled.value && !isGuest) ...[
```

2. Di blok tamu (baris 150-153), tambah penjelasan di bawah alert:

```dart
          if (isGuest) ...[
            const FAlert(title: Text('Laporan kamu dikirim sebagai Anonim')),
            const Gap(4),
            Text(
              'Login untuk bisa melampirkan screenshot',
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
            const Gap(12),
          ],
```

Verifikasi:

```
cd mobile && flutter analyze
```

Expected: "No issues found!". Uji manual (debug): tanpa login buka
Laporkan Masalah - bagian lampiran tidak muncul, submit teks sukses;
setelah login - lampiran muncul dan upload sukses. Commit:
`fix(mobile): sembunyikan lampiran bug report untuk tamu (#67)`.

### Task 6: Docs mobile

File: `docs/mobile/20-mobile-report-bug.md`, section "Upload dan submit"
(baris ~34-46):

- Poin 1 ganti menjadi: "Saat user login memilih gambar:
  `GET /api/v1/bug-reports/upload-token?folder=/bug-reports` (Bearer
  otomatis dari interceptor) lalu upload langsung ke ImageKit folder
  `/bug-reports` (satu token per file)."
- Tambah poin tamu di awal list: "Tamu: bagian lampiran disembunyikan,
  laporan terkirim teks saja."

Verifikasi: baca ulang file, alur tamu vs login konsisten dengan Task 5.
Commit: `docs(mobile): lampiran bug report hanya untuk user login (#67)`.

### Task 7: Verifikasi pasca-deploy (staging dulu, lalu production)

Setelah deploy API (mobile ikut rilis berikutnya):

```
curl -s -o /dev/null -w "%{http_code}\n" "https://sambasku-staging.iamutaki.com/api/v1/bug-reports/upload-token?folder=/bug-reports"
```

Expected: `401` (sebelumnya 200).

```
curl -s -X POST "https://sambasku-staging.iamutaki.com/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"<email uji>","password":"<password uji>"}' | jq -r .data.access_token
```

Lalu:

```
curl -s "https://sambasku-staging.iamutaki.com/api/v1/bug-reports/upload-token?folder=/bug-reports" \
  -H "Authorization: Bearer <access_token>" | jq '.data | keys'
```

Expected: `["expire","public_key","signature","token","upload_endpoint"]`.
Jangan tempel kredensial asli di chat/issue. Tutup issue #67 dengan hasil
dua curl ini setelah production diperiksa sama.

## Tests / validation

- TDD penuh di Task 1-2 (red → green → commit) pada
  `bug-report.e2e.test.ts`; skenario: anon 401, login folder salah 400,
  login folder benar 200/503. Test submit tamu yang ada tidak boleh
  berubah artinya (tamu tetap bisa POST /bug-reports).
- `pnpm typecheck` dan `flutter analyze` bersih.
- Manual QA mobile (Task 5) dan verifikasi curl staging/production (Task 7).

## Risks, tradeoffs, and open questions

- Tradeoff produk (intensi issue): tamu tidak bisa lampirkan screenshot
  lagi. Laporan tamu tetap masuk sebagai teks; kalau produk berubah pikiran,
  opsi lanjutannya token terbatas berbasis `X-Device-Id` yang ditandatangani
  server (jangan dilakukan sekarang, YAGNI).
- Versi mobile lama di lapangan: tamu yang menambahkan gambar akan dapat 401
  per slot dengan pesan generik "Satu gambar gagal diunggah" dan tetap bisa
  kirim teks (soft-fail sudah ada). Tidak memblokir pelaporan.
- One-time-use token tidak dikerjakan: signature ImageKit adalah HMAC
  stateless tanpa jti di server; memaksa one-time butuh penyimpanan
  server-side. Dengan wajib login + 20/jam per user, penyalahgunaan sudah
  terbatas pada akun terverifikasi. Tandai komentar `ponytail:` di routes
  bila mau mencatat upgrade path ini.
- Rate limit masih in-memory per instance (`rate-limit.middleware.ts`
  sudah berkomentar `ponytail` soal Redis). Reset saat deploy/restart;
  bukan bagian issue ini.
- Endpoint `GET /admin/images/upload-token` dan discussion upload-token
  tidak disentuh (sudah wajib login + role/scope).
- Open question untuk reviewer: apakah perlu pengumuman/changelog untuk
  perubahan perilaku tamu (lampiran hilang)? Plan menganggap cukup lewat
  copy UI di Task 5.
