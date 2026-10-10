# Issue #31 — Aktifkan `OAUTH_REQUIRE_AZP = true` (token tanpa azp tidak lagi memegang full scope)

## Goal

Satu kalimat: Matikan grace mode `OAUTH_REQUIRE_AZP=false` sehingga JWT tanpa claim `azp` tidak lagi otomatis dipetakan ke `FIRST_PARTY_SCOPE_STRING`, dengan jalur keluar bersih untuk sesi legacy (refresh → 401 `SESSION_STALE` → client re-login), tanpa perubahan apa pun di mobile/console.

## Konteks terverifikasi (sudah dicek di repo, jangan difigurasi ulang)

Semua path relatif terhadap `/Users/ibnulmutaki/Development/github/sambasku/`.

1. **Flag**: `api/wrangler.toml` line 59 (root = production) DAN line 108 (`[env.staging.vars]`) berisi `OAUTH_REQUIRE_AZP = "false"`. `api/.env.example:106` = `false` (dokumentasi default). `api/.env.test` TIDAK set flag ini (default false).
2. **Satu-satunya pembaca flag**: `api/src/shared/middlewares/require-approved-client.middleware.ts:51`. Saat `false`, token tanpa `azp` di-map ke `FIRST_PARTY_SCOPE_STRING` (`legacyMapped: true`, line ~55-63) — inilah lubang keamanannya: token legacy memegang 7 scope penuh (`vote.write`, `comment.write`, `contribute.write`, `discussion.write`, `bookmark.write`, `profile.read`, `device.write`, lihat `api/src/modules/developer-oauth/domain/entities/api-client.entity.ts:24`). Middleware dipasang 14 titik di `api/src/app.ts` (gate vote/comment/contribute, line 535-545).
3. **Sumber azp untuk sesi baru**: semua jalur login (password, Google, Facebook, GitHub, verify-email) lewat `loginMetaWithClient` → `ResolveFirstPartyClientUseCase` (`api/src/modules/developer-oauth/application/use-cases/resolve-first-party-client.use-case.ts`) — default client per kanal (`mobile→sambasku-mobile`, `web→sambasku-web`), lalu `issueLoginSession` (`api/src/modules/auth/application/utils/issue-login-session.ts:41-46`) menempelkan claim `azp` + `scope` ke JWT. **Cuma ada 2 titik penerbitan access token** di seluruh `src/` (sudah di-grep): `issue-login-session.ts` dan `refresh-token.use-case.ts:102`. Keduanya sudah bawa azp untuk sesi baru.
4. **Lubang legacy yang tersisa**: `refresh-token.use-case.ts:64-70` — record refresh token dengan `clientId: null` (sesi dibuat sebelum migration `0021_api-clients-and-refresh-client-id.sql`) di-refresh → `resolveClientClaims` balik `{ clientId: null, scopes: null }` → **token baru tanpa azp terus diterbitkan**. Kalau flag dibalik `true` tanpa ini, sesi legacy dapat 401 `CLIENT_REQUIRED` di request tulis SEMENTARA refresh tetap sukses — mobile interceptor TIDAK logout untuk kasus itu (retry gagal bukan alasan hapus sesi, `mobile/lib/core/network/interceptors/auth_interceptor.dart:100`) → user diam-diam gagal menulis. Makanya perlu ditolak di refresh.
5. **Mobile SUDAH siap (verifikasi saja, nol perubahan kode)**:
   - `login/google/facebook/github/verify_email_request_dto.dart` semua punya `@JsonKey(name: 'client_type') @Default('mobile')`.
   - `register_request_dto.dart:28` + `auth_repository_impl.dart:50` kirim `client_id: 'sambasku-mobile'`.
   - Interceptor: `401/403 pada refresh → hapus sesi` (`auth_interceptor.dart:186`) — jadi `SESSION_STALE` (401) di refresh otomatis logout bersih → layar login.
6. **Console SUDAH siap (verifikasi saja)**: `console/src/features/auth/infrastructure/auth-api.ts:16` kirim `client_type: 'web'` (server default-kan ke `sambasku-web`); refresh via cookie httpOnly; `console/src/shared/auth/session.ts` clear session saat refresh gagal.
7. **PRASYARAT BRANCH**: repo `api` sekarang ada di branch `fix/fcm-url-whitelist` (kerja issue #71, commit `5efbffc`). Issue #31 (`fix/refresh-channel-gate`, PR #36) **belum merge**. Kerjakan issue #31 SETELAH PR #36 merge, branch baru dari `origin/staging`.

## Pendekatan

Balik flag jadi `true` di kedua env wrangler + `.env.test`, tutup satu-satunya lubang legacy (refresh record tanpa `client_id` ditolak `401 SESSION_STALE` saat flag ketat — 6 baris di `resolveClientClaims`), lalu buktikan via TDD unit + e2e bahwa sesi baru ber-azp dan sesi legacy mati bersih. Nol perubahan mobile/console.

---

## Task 1 — Siapkan branch api (2 menit)

Syarat: PR #36 sudah merge. Jalankan:

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/api
git fetch origin
git checkout -b fix/oauth-require-azp origin/staging
git log --oneline -1   # harap: commit yang SUDAH memuat 4ff7a0c (gerbang kanal)
```

Expected: `git log --oneline --all | grep 4ff7a0c` menunjukkan commit itu ada di histori branch.

## Task 2 — RED: unit test sesi legacy di-refresh saat mode ketat (5 menit)

File: `api/src/modules/auth/__tests__/unit/refresh-token.use-case.test.ts`

Tambahkan import di atas (dekat import lain):

```ts
import { env } from '@/shared/config/env';
```

Tambahkan test baru di dalam `describe('RefreshTokenUseCase', ...)`:

```ts
  it('OAUTH_REQUIRE_AZP=true: record tanpa clientId → SESSION_STALE, bukan token baru tanpa azp', async () => {
    env.OAUTH_REQUIRE_AZP = true;
    try {
      const { useCase } = make(record()); // record() default clientId: null
      await expect(useCase.execute('token-legacy')).rejects.toMatchObject({
        errorCode: 'SESSION_STALE',
      });
    } finally {
      env.OAUTH_REQUIRE_AZP = false;
    }
  });
```

Catatan: `record()` dan `make()` sudah ada di file itu (line ~36 dan ~53), `record()` default `clientId: null` — persis kasus legacy. Mutasi properti `env` aman karena use-case membaca `env.OAUTH_REQUIRE_AZP` saat runtime (bukan saat import).

Jalankan, harap GAGAL (sekarang use-case masih menerbitkan token):

```bash
npx vitest run src/modules/auth/__tests__/unit/refresh-token.use-case.test.ts
```

Expected output mengandung: `1 failed` dengan pesan semacam "Received promise resolved instead of rejected" untuk test baru; test lama tetap hijau.

Commit red:

```bash
git add src/modules/auth/__tests__/unit/refresh-token.use-case.test.ts
git commit -m "test(auth): sesi legacy tanpa client_id ditolak saat OAUTH_REQUIRE_AZP=true (red) (#31)"
```

## Task 3 — GREEN: tolak sesi legacy di refresh saat mode ketat (5 menit)

File: `api/src/modules/auth/application/use-cases/refresh-token.use-case.ts`

Tambahkan import (file ini sudah import `UnauthorizedError` — cek dulu, kalau sudah ada jangan duplikat):

```ts
import { env } from '@/shared/config/env';
```

Patch `resolveClientClaims` (line ~64-70), ganti blok awal:

```ts
  private async resolveClientClaims(
    clientId: string | null,
  ): Promise<{ clientId: string | null; scopes: string | null }> {
    if (!clientId) {
      // Mode ketat (issue #31): sesi legacy tanpa client_id dihentikan di
      // refresh supaya client logout bersih, bukan meneruskan token tanpa azp
      // yang pasti gagal 401 CLIENT_REQUIRED di gate write.
      if (env.OAUTH_REQUIRE_AZP) {
        throw new UnauthorizedError(
          'SESSION_STALE',
          'Sesi sudah kadaluarsa. Silakan masuk lagi ya.',
        );
      }
      // Grace: token legacy tetap tanpa azp (OAUTH_REQUIRE_AZP=false)
      return { clientId: null, scopes: null };
    }
    // ... sisanya TIDAK berubah
```

Jalankan lagi:

```bash
npx vitest run src/modules/auth/__tests__/unit/refresh-token.use-case.test.ts
```

Expected: `Tests  6 passed (6)` (5 lama + 1 baru). Lalu typecheck:

```bash
npm run typecheck
```

Expected: exit 0, tanpa output error.

Commit:

```bash
git add src/modules/auth/application/use-cases/refresh-token.use-case.ts
git commit -m "fix(auth): refresh sesi legacy tanpa client_id → SESSION_STALE saat mode ketat (#31)"
```

## Task 4 — RED→GREEN e2e: mode ketat aktif di test + guard azp JWT (10 menit)

4a. File `api/.env.test` — tambahkan baris (di bawah `NODE_ENV=test`):

```
# Issue #31: e2e jalan di mode ketat - sesi baru wajib ber-azp
OAUTH_REQUIRE_AZP=true
```

4b. File `api/src/modules/auth/__tests__/e2e/auth.e2e.test.ts` — tambahkan helper + test di dalam `describe` (dekat test MOBILE lain, sekitar line 277):

```ts
  const decodeJwtClaims = (token: string) =>
    JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));

  it('MOBILE: login mode ketat → JWT ber-azp sambasku-mobile + scope penuh', async () => {
    const email = unique();
    await registerAndVerify(email);
    const res = await client.api.v1.auth.login.$post(
      { json: { email, password: 'Password123', client_type: 'mobile' } },
      { headers: xff() },
    );
    expect(res.status).toBe(200);
    const claims = decodeJwtClaims((await res.json()).data.access_token);
    expect(claims.azp).toBe('sambasku-mobile');
    expect(claims.scope).toContain('vote.write');
  });
```

(`registerAndVerify`, `unique`, `xff` sudah ada di file itu; `atob` global Node ≥16.)

Jalankan seluruh file e2e auth (flag `.env.test` baru ikut terbaca karena dotenv di-load sebelum `import('@/app')`):

```bash
npx vitest run src/modules/auth/__tests__/e2e/auth.e2e.test.ts
```

Expected: SEMUA pass, termasuk test baru dan semua test lama (sesi test semuanya dibuat lewat login → ber-azp → lolos mode ketat). Kalau ada test lama jebol, itu sesi legacy sungguhan di test — laporkan, jangan di-skip diem-diam.

Commit:

```bash
git add .env.test src/modules/auth/__tests__/e2e/auth.e2e.test.ts
git commit -m "test(auth): e2e mode ketat OAUTH_REQUIRE_AZP + guard azp JWT sesi baru (#31)"
```

## Task 5 — Balik flag produksi + staging (2 menit)

File `api/wrangler.toml` — DUA lokasi (line ~59 root dan ~108 `[env.staging.vars]`), ganti keduanya:

```toml
# Gate JWT azp pada write (true = ketat: token tanpa azp → CLIENT_REQUIRED).
# Issue #31: grace dimatikan. Sesi legacy di-refresh → 401 SESSION_STALE
# → client paksa re-login. Cutover lewat redeploy.
OAUTH_REQUIRE_AZP = "true"
```

File `api/.env.example` line 106 — biarkan `false` (itu dokumentasi DEFAULT env.ts, bukan keputusan deploy), tapi rapikan komentar di line 102-105 jadi:

```
# Gate write: JWT wajib claim `azp` (client_id). Default false = grace
# (token lama tanpa azp masih lolos). PRODUKSI & STAGING sudah true sejak
# issue #31 - lihat wrangler.toml. docs/api/35-api-oauth-client-azp.md.
OAUTH_REQUIRE_AZP=false
```

Verifikasi cepat:

```bash
grep -n 'OAUTH_REQUIRE_AZP' wrangler.toml   # harap: 2 baris, keduanya "true"
npm run typecheck && npm test 2>&1 | tail -3
```

Expected: typecheck bersih; full suite hijau (jumlah pass naik dari baseline, NOL gagal; baseline terakhir 1003 pass / 166 file sebelum PR #36).

Commit:

```bash
git add wrangler.toml .env.example
git commit -m "feat(security): aktifkan OAUTH_REQUIRE_AZP=true di produksi & staging (#31)"
```

## Task 6 — Verifikasi mobile & console TANPA perubahan kode (5 menit, read-only)

Mobile (repo `mobile`, branch apa pun yang bersih, saat ini `fix/tab-freeze`):

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/mobile
grep -c "client_type" lib/features/auth/data/models/login_request_dto.dart lib/features/auth/data/models/verify_email_request_dto.dart   # harap: masing-masing >= 1
grep -n "401 || 403" lib/core/network/interceptors/auth_interceptor.dart   # harap: line 186 (refresh 401 → hapus sesi)
flutter test test/features/auth --reporter compact 2>&1 | tail -2          # harap: All tests passed!
```

Console (repo `console`):

```bash
grep -n "client_type: 'web'" /Users/ibnulmutaki/Development/github/sambasku/console/src/features/auth/infrastructure/auth-api.ts   # harap: line 16
```

Expected: semua cocok → tidak ada commit di mobile/console. Kalau ada yang tidak cocok, BERHENTI dan laporkan sebelum lanjut.

## Task 7 — Docs (repo `docs`, 5 menit)

File: `docs/api/35-api-oauth-client-azp.md` (tabel mode di line ~25-26).

Branch baru dari default branch repo docs (jangan pakai `fix/upload-token-auth` — itu masih nunggu PR terpisah):

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/docs
git fetch origin && git checkout -b fix/oauth-require-azp-docs origin/main 2>/dev/null || git checkout -b fix/oauth-require-azp-docs
```

Patch baris `| false / kosong / tidak di-set (default) | ...` → tambah keterangan sudah tidak dipakai di produksi, dan baris `true` → tandai sebagai mode aktif. Tambah paragraf setelah tabel:

```markdown
### Status cutover (issue #31, 2026-10-02)

Produksi & staging memakai `OAUTH_REQUIRE_AZP=true`. Efek bagi sesi lama
(dibuat sebelum migration `0021`): refresh berikutnya → `401 SESSION_STALE`
→ aplikasi memaksa login ulang. Setelah itu semua JWT selalu ber-azp.
Grace mode (false) hanya relevan untuk environment dev lokal.
```

Commit (file eksplisit, sesuai aturan repo):

```bash
git add api/35-api-oauth-client-azp.md
git commit -m "docs(api): cutover OAUTH_REQUIRE_AZP=true - sesi legacy ditolak di refresh (#31)"
```

## Task 8 — Push + PR + deploy staging (external, minta akun dulu)

1. Push api: `git push -u origin fix/oauth-require-azp`, lalu PR ke `staging` dengan body: ringkasan issue #31, perubahan 3 file (use-case, wrangler, env), hasil test, catatan efek sesi legacy (re-login maksimal 30 hari terakhir).
2. Push docs + PR repo docs.
3. **Deploy = gate user**: `npm run deploy:staging` butuh auth wrangler; jangan jalan sendiri tanpa persetujuan. Setelah deploy, verifikasi manual: login di app staging → tulis (vote/comment) sukses = token ber-azp; device dengan sesi lama → diminta login ulang.

---

## Test / validasi (ringkas)

- Unit: `npx vitest run src/modules/auth/__tests__/unit/refresh-token.use-case.test.ts` → 6 pass.
- E2E auth: `npx vitest run src/modules/auth/__tests__/e2e/auth.e2e.test.ts` → semua pass dalam mode ketat.
- Full: `npm test` → 0 gagal (baseline 1003 pass / 166 file + test baru + test PR #36).
- `npm run typecheck` → bersih.
- Mobile: `flutter test test/features/auth` → pass, tanpa perubahan file.

## Risiko, tradeoff, pertanyaan terbuka

1. **Sesi legacy mati dengan re-login**: semua refresh token dibuat sebelum migration 0021 (maksimal umur 30 hari) akan ditolak sekali di refresh berikutnya setelah deploy. Diterima sebagai biaya cutover (docs 35 memang merancang cutover lewat redeploy). Alternatif yang DITOLAK: backfill `client_id` saat refresh dengan menebak kanal dari cookie/body — kompleks untuk manfaat kecil.
2. **Jendela 15 menit**: access token tanpa azp yang masih hidup saat deploy akan gagal di gate write (`CLIENT_REQUIRED`) sampai kadaluarsa; refresh berikutnya membersihkannya. Singkat, diterima.
3. **`.env.test` global true** memengaruhi SEMUA file e2e (termasuk milik PR #36 setelah merge). Kalau nanti muncul test yang sengaja bikin token legacy, penulisnya harus set flag via `env` object per-test (pola Task 2), bukan balikin `.env.test`.
4. **Urutan merge**: PR #36 (gerbang kanal) HARUS merge dulu supaya branch #31 berangkat dari histori yang memuat `refresh-channel.ts`; kalau tidak, konflik kecil di `auth.controller.ts` tetap bisa muncul.
5. **Terbuka untuk user**: timing deploy produksi (staging dulu, pantau 1-2 hari, baru produksi) — jangan didecide sendiri.
6. Sengaja tidak dipakai: force-revoke massal sesi lama via DB (YAGNI — penolakan di refresh sudah menghasilkan logout organik), env baru/allowlist client (flag sudah ada, cukup dibalik).
