# Issue #35 — Kecilkan jendela grace rotasi refresh token (60s → 10s) + reuse detection revoke semua sesi

## Goal

Satu kalimat: Turunkan `REFRESH_ROTATION_GRACE_MS` dari `60_000` ke `10_000` dan tambahkan reuse detection — pemakaian token yang SUDAH lewat jendela grace mencabut SEMUA refresh token user itu (`revokeAllForUser`) supaya token curian tidak bisa dipakai diam-diam.

## Konteks terverifikasi (dicek langsung di repo, jangan difantasikan)

Path relatif ke `/Users/ibnulmutaki/Development/github/sambasku/`.

1. **Konstanta**: `api/src/modules/auth/application/use-cases/refresh-token.use-case.ts:22` — `export const REFRESH_ROTATION_GRACE_MS = 60_000;`. Dipakai di `withinRotationGrace()` (line ~126-131), dan di-import oleh unit test + e2e test. Nama konstanta TIDAK berubah (hanya nilai).
2. **Alur refresh saat ini** (file sama, line ~46-62): ada TIGA titik yang menolak token rotasi ketika `withinRotationGrace === false`:
   - `record.isRevoked` true (line 48-50)
   - `markRotated` gagal → re-read `again` (line 56-59)
   - `again` tidak ada (line 57)
   Semua titik ini saat ini CUMA throw `UNAUTHORIZED` — tidak ada revoke-all. Inilah celah #35: attacker yang memakai token lama (lewat grace) dapat 401 polos, victim tetap online dengan token baru, attacker bisa coba-coba lagi diam-diam.
3. **Reuse detection** = persis pola OAuth2 standar: token revoked-dirotasi dipakai LAGI setelah grace → indikasi token tercuri/ bocor → cabut seluruh sesi user. `revokeAllForUser(userId)` SUDAH ADA di interface repo (`api/src/modules/auth/domain/repositories/refresh-token.repository.ts:30`) dan dipakai 6 use-case lain (change-password, logout-all-devices, dll). Repository mock di unit test juga sudah punya field-nya (`refresh-token.use-case.test.ts` line ~64).
4. **Hati-hati: kasus `rotatedAt: null` + `isRevoked: true`** — itu logout/pencabutan disengaja (test line 108-112 'logout mengosongkan rotatedAt'), BUKAN reuse. Jangan revoke-all di kasus itu; revoke-all hanya untuk `rotatedAt` terisi tapi lewat grace (= pernah dipakai rotasi, lalu dipakai lagi terlalu lama kemudian).
5. **Grace 10 detik tetap cukup untuk mobile**: interceptor mobile (`mobile/lib/core/network/interceptors/auth_interceptor.dart`) single-flight queue (`_refreshFuture`), retry request yang sama, tidak ada retry-refresh berkala. Issue #35 sendiri bilang "5-10 detik cukup".
6. **Dokumentasi**: `docs/api/00-api-auth.md:232` menulis "masih diterima selama 60 detik" — harus jadi 10 detik + sebutkan revoke-all.
7. **Branch**: PR #37 SUDAH MERGE (`0e53c6b` di `origin/staging`). Kerjakan dari staging yang baru. Repo api lokal ada di `fix/oauth-require-azp` — buat branch baru `fix/refresh-grace-window` dari `origin/staging`.
8. Unit test pakai `vi.mock('@/shared/config/env')` pola hoisted (bawaan PR #37) — JANGAN diubah.

## Pendekatan

Dua perubahan kecil di satu file use-case + update docs. (1) Nilai konstanta 60_000 → 10_000. (2) Titik penolakan "token rotasi dipakai lewat grace" yang menandakan REUSE (ada `rotatedAt`, lewat jendela) memanggil `revokeAllForUser(record.userId)` sebelum throw. TDD: test unit dulu (RED), lalu implement, lalu satu test e2e memastikan reuse mencabut sesi baru korban. Nol perubahan mobile/console (perilaku 401 tidak berubah; client sudah logout saat 401 refresh).

---

## Task 1 — Branch (1 menit)

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/api
git fetch origin
git checkout -b fix/refresh-grace-window origin/staging
git log --oneline -1   # harap: 0e53c6b Merge pull request #37 ...
```

## Task 2 — RED: unit test nilai grace 10s + reuse detection (5 menit)

File: `api/src/modules/auth/__tests__/unit/refresh-token.use-case.test.ts`

2a. Ganti test lama 'token yang dirotasi lewat dari grace ditolak' (line ~96-105) menjadi DUA test:

```ts
  it('grace window 10 detik: rotasi 11 detik lalu sudah ditolak', async () => {
    const { useCase } = make(
      record({
        isRevoked: true,
        rotatedAt: new Date(Date.now() - 10_001),
      }),
    );
    await expect(useCase.execute('token-lama')).rejects.toMatchObject({
      errorCode: 'UNAUTHORIZED',
    });
  });

  it('grace window 10 detik: rotasi 9 detik lalu masih diterima', async () => {
    const { useCase, refreshTokenRepo } = make(
      record({ isRevoked: true, rotatedAt: new Date(Date.now() - 9_000) }),
    );
    const result = await useCase.execute('token-lama');
    expect(result.accessToken).toBe('access-baru');
    expect(refreshTokenRepo.create).toHaveBeenCalledOnce();
  });
```

2b. Tambah test reuse detection (letakkan setelah kedua test di atas):

```ts
  it('reuse: token rotasi dipakai lewat grace → revokeAllForUser dipanggil', async () => {
    const { useCase, refreshTokenRepo } = make(
      record({
        isRevoked: true,
        rotatedAt: new Date(Date.now() - REFRESH_ROTATION_GRACE_MS - 1),
      }),
    );
    await expect(useCase.execute('token-lama')).rejects.toMatchObject({
      errorCode: 'UNAUTHORIZED',
    });
    expect(refreshTokenRepo.revokeAllForUser).toHaveBeenCalledWith(USER_ID);
  });

  it('logout (rotatedAt null) TIDAK memicu revoke-all — bukan reuse', async () => {
    const { useCase, refreshTokenRepo } = make(record({ isRevoked: true, rotatedAt: null }));
    await expect(useCase.execute('token-lama')).rejects.toMatchObject({
      errorCode: 'UNAUTHORIZED',
    });
    expect(refreshTokenRepo.revokeAllForUser).not.toHaveBeenCalled();
  });
```

Jalankan — harap GAGAL 3 (nilai masih 60s + revoke belum ada), test logout-negatif harus SUDAH pass:

```bash
npx vitest run src/modules/auth/__tests__/unit/refresh-token.use-case.test.ts
```

Expected: `3 failed` / `x failed` — dua test 10-detik gagal (9s & 11s masih dalam 60s grace → bukan perilaku yang diharapkan), test reuse gagal (`revokeAllForUser` tidak dipanggil). Commit red:

```bash
git add src/modules/auth/__tests__/unit/refresh-token.use-case.test.ts
git commit -m "test(auth): grace 10s + reuse detection revoke-all (red) (#35)"
```

## Task 3 — GREEN: implementasi (5 menit)

File: `api/src/modules/auth/application/use-cases/refresh-token.use-case.ts`

3a. Line 22:

```ts
// Jendela grace rotasi: retry jaringan mobile + dua tab web. 10s cukup
// (interceptor mobile single-flight; issue #35: 60s = window curian terlalu panjang).
export const REFRESH_ROTATION_GRACE_MS = 10_000;
```

3b. Blok reuse utama (line ~46-51) — tambah revoke-all sebelum throw:

```ts
    if (record.isRevoked) {
      if (!withinRotationGrace(record.rotatedAt)) {
        // rotatedAt terisi + lewat grace = token rotasi dipakai ulang (reuse).
        // Indikasi token bocor → cabut SEMUA sesi user (issue #35).
        // rotatedAt null = logout/pencabutan disengaja, bukan reuse.
        if (record.rotatedAt) {
          await this.refreshTokenRepo.revokeAllForUser(record.userId);
        }
        throw new UnauthorizedError('UNAUTHORIZED', 'Refresh token tidak valid');
      }
      return this.issue(user.id, user.roles, user.username, clientClaims);
    }
```

3c. Race-race branch (line ~55-59) — kasus `again` ditemukan tapi lewat grace, SAMA indikasi reuse (markRotated kalah race lalu token dipakai lagi lama kemudian). Patch:

```ts
    const rotated = await this.refreshTokenRepo.markRotated(record.tokenHash);
    if (!rotated) {
      const again = await this.refreshTokenRepo.findByHash(record.tokenHash);
      if (!again || !withinRotationGrace(again.rotatedAt)) {
        if (again?.rotatedAt) {
          await this.refreshTokenRepo.revokeAllForUser(record.userId);
        }
        throw new UnauthorizedError('UNAUTHORIZED', 'Refresh token tidak valid');
      }
    }
```

Jalankan:

```bash
npx vitest run src/modules/auth/__tests__/unit/refresh-token.use-case.test.ts
```

Expected: `Tests  10 passed (10)` (6 lama tersisa + 4 baru). Commit green:

```bash
git add src/modules/auth/application/use-cases/refresh-token.use-case.ts
git commit -m "fix(security): grace rotasi 10s + reuse detection revoke-all (#35)"
```

## Task 4 — E2E: reuse mencabut sesi baru korban (10 menit)

File: `api/src/modules/auth/__tests__/e2e/auth.e2e.test.ts`

Tambah test setelah test 'MOBILE: refresh via body → token rotasi di body, token lama mati setelah grace' (sekitar line 330):

```ts
  it('SECURITY #35: pemakaian token lama lewat grace → seluruh sesi user dicabut', async () => {
    const email = unique();
    await registerAndVerify(email);
    const loginRes = await client.api.v1.auth.login.$post(
      { json: { email, password: 'Password123', client_type: 'mobile' } },
      { headers: xff() },
    );
    const stolenToken = (await loginRes.json()).data.refresh_token as string;

    // victim refresh normal → dapat token baru; stolenToken kini rotated
    const res1 = await client.api.v1.auth.refresh.$post(
      { json: { refresh_token: stolenToken } },
      { headers: {} },
    );
    expect(res1.status).toBe(200);
    const victimToken = ((await res1.json()).data as { refresh_token: string }).refresh_token;

    // lewati jendela grace
    await refreshAfterGrace(async () => {
      // attacker pakai token lama setelah grace → 401 DAN seluruh sesi mati
      const res2 = await client.api.v1.auth.refresh.$post(
        { json: { refresh_token: stolenToken } },
        { headers: {} },
      );
      expect(res2.status).toBe(401);
      return res2;
    });

    // token BARU victim (yang sah) ikut dicabut — sesi bocor dimatikan total
    const res3 = await client.api.v1.auth.refresh.$post(
      { json: { refresh_token: victimToken } },
      { headers: {} },
    );
    expect(res3.status).toBe(401);
  });
```

Catatan: `refreshAfterGrace` sudah ada di file (line ~18, dynamic import `REFRESH_ROTATION_GRACE_MS`, fake timers Date). Cek test lama 'token lama mati setelah grace' sebagai referensi pola `client.api.v1.auth.refresh.$post`.

Jalankan file e2e:

```bash
npx vitest run src/modules/auth/__tests__/e2e/auth.e2e.test.ts
```

Expected: semua pass + test baru. Kalau reuse-branch tidak terpicu karena `refreshAfterGrace` mock Date sebelum request, cek urutan — harusnya tetap jalan karena `withinRotationGrace` membaca `Date.now()` runtime.

Commit:

```bash
git add src/modules/auth/__tests__/e2e/auth.e2e.test.ts
git commit -m "test(auth): e2e reuse token lewat grace mencabut seluruh sesi (#35)"
```

## Task 5 — Docs + verifikasi penuh (5 menit)

File `docs/api/00-api-auth.md` (repo `docs`, BUKAN api) line ~231-234. Ganti kalimat:

```markdown
     (cegah replay attack). Token yang baru dirotasi masih diterima
     selama 60 detik (`rotated_at`) supaya retry setelah timeout atau
     dua tab tidak langsung logout. Logout dan cabut-semua-perangkat
     mengosongkan `rotated_at`, jadi grace tidak berlaku.
```

menjadi:

```markdown
     (cegah replay attack). Token yang baru dirotasi masih diterima
     selama 10 detik (`rotated_at`) supaya retry setelah timeout atau
     dua tab tidak langsung logout. Pemakaian token yang sudah dirotasi
     DI LUAR jendela grace = indikasi token bocor: seluruh refresh
     token user dicabut (reuse detection). Logout dan
     cabut-semua-perangkat mengosongkan `rotated_at`, jadi grace tidak
     berlaku dan tidak dianggap reuse.
```

Branch docs: `git checkout -b fix/refresh-grace-window-docs origin/main` (pola PR docs#1).

Verifikasi api penuh:

```bash
npm run typecheck          # exit 0
npm test 2>&1 | tail -3    # 0 gagal (baseline 1005 pass + 5 test baru)
```

Commit docs:

```bash
git add api/00-api-auth.md
git commit -m "docs(api): grace rotasi 10s + reuse detection revoke-all (#35)"
```

## Task 6 — Push + PR (3 menit, user check)

```bash
# api
git push -u origin fix/refresh-grace-window
gh pr create --base staging --title "fix(security): grace rotasi refresh 10s + reuse detection revoke-all" --body "..."
# docs
cd ../docs && git push -u origin fix/refresh-grace-window-docs
```

Body PR wajib menyebut: nilai baru 10_000ms, revoke-all kondisi (rotatedAt terisi + lewat grace), kasus logout TIDAK terpicu (rotatedAt null), angka test, closes #35. Deploy tetap manual (keputusan user, pola issue #31).

---

## Test / validasi (ringkas)

- Unit: 10 pass (incl. 4 baru: 9s dalam grace, 11s ditolak, reuse→revokeAll, logout≠reuse).
- E2E: file auth.e2e.test.ts semua pass (incl. reuse mencabut token baru victim).
- Full: `npm test` 0 gagal. `npm run typecheck` bersih.
- Mobile/console: NOL perubahan (401 sudah ditangani interceptor line 186; user kena logout massal hanya kalau token-nya benar-benar bocor).

## Risiko, tradeoff, pertanyaan terbuka

1. **Revoke-all agresif = DoS self**: user jahil yang menyimpan token lama >10s lalu memakainya akan mencabut sesinya sendiri di semua perangkat. Ini perilaku STANDAR reuse detection (OAuth2) dan justru tujuan issue. Risiko kecil: user dengan dua device yang offline lama — keduanya re-login. Diterima.
2. **Grace 10s vs jaringan lambat**: interceptor mobile single-flight + retry request (bukan refresh berkala), jadi 10s cukup. Kalau nanti muncul laporan logout acak di jaringan sangat lambat, naikkan ke 15s — satu konstanta, tanpa migration.
3. **Dua tab web**: keduanya share cookie httpOnly yang sama — tab kedua refresh dalam 10s setelah tab pertama masih lolos (grace), lewat itu → 401 → re-login. Tradeoff diterima (issue eksplisit minta 5-10s).
4. **`markRotated` race branch** juga memicu revoke-all via `again?.rotatedAt` — sengaja: pola pemakaian sama (token sudah dirotasi proses lain, dipakai lagi lewat grace). Syarat tetap `rotatedAt` terisi.
5. **Tidak dipakai (YAGNI)**: kolom DB `replaced_by_hash` untuk family tracking, audit log khusus reuse, alerting — revoke-all per-user sudah menutup threat; tambahan hanya kalau mau forensik.
