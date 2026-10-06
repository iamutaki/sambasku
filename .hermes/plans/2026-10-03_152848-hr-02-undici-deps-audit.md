# Plan: HR-02 - 10 kerentanan undici (2 high) di devDependencies via miniflare/wrangler (issue #60)

## Goal

Issue #60 ditutup dengan bukti terkini: `pnpm audit` 0 kerentanan dan `pnpm run
build` sukses - atau, kalau audit ternyata masih kotor, bump dependency + PR.

## Current context / assumptions

- Repo: submodule `web/` (Remix + Cloudflare Workers). Package manager = pnpm
  (ada `pnpm-lock.yaml`); pnpm 10.10.0, node v26.7.0 terpasang.
- **Temuan penting dari inspeksi (2026-10-03)**: issue ini tampaknya sudah
  tertutup oleh bump dependabot di upstream. Bukti di working tree (branch
  `fix/hr-01-safe-external-url`, lockfile IDENTIK dengan `origin/staging` -
  `git diff origin/staging -- package.json pnpm-lock.yaml` kosong):
  - `pnpm audit` -> `No known vulnerabilities found` (SUDAH dijalankan).
  - Lockfile berisi `undici@7.29.1` (versi patch yang disyaratkan issue) dan
    `wrangler@4.146.0` (naik dari 4.135.0 saat issue dibuat), `miniflare`
    5.20261001.0-alpha.
  - Jadi remediasi inti kemungkinan BESAR = verifikasi + tutup issue dengan
    bukti, BUKAN edit kode. Path B (bump) tetap disiapkan kalau ternyata audit
    berubah kotor.
- `undici` tidak ada di `package.json` (murni transitive via miniflare) -
  jangan tambahkan sebagai direct dep atau override kalau audit sudah bersih
  (YAGNI).
- Perhatian versi: `miniflare` 5.x adalah **alpha**. Itu keputusan upstream
  wrangler; JANGAN "perbaiki" dengan pin ke stable - bukan scope issue.
- Working tree web submodule berisi WIP Tuan (7 file modified + 3 untracked
  `wisata*`). WIP itu membuat `typecheck` error (file `wisata*.tsx` import
  `buildPlaceJsonLd` yang belum ada). Untuk build yang bisa dipertanggung-
  jawabkan, WIP di-stash dulu lalu di-pop balik.
- Deploy staging = keputusan Tuan (konvensi repo), bukan langkah plan ini.
  Plan hanya menyiapkan bukti build lokal.
- Issue #60 status: OPEN di `sambasku/web`.

## Architecture / proposed approach

Tidak ada perubahan arsitektur: ini tugas dependensi/verifikasi. Alur: verifikasi
audit pada lockfile staging -> buktikan build sukses di working tree bersih
(WIP di-stash) -> komentar bukti di issue #60 + tutup. Kontingensi Path B hanya
kalau audit ternyata masih menampilkan kerentanan.

## Step-by-step tasks

Semua command dari `/Users/ibnulmutaki/Development/github/sambasku/web/`.

### Task 1 - Pastikan baseline deps masih identik dengan staging (1 menit)

```
git diff origin/staging --stat -- package.json pnpm-lock.yaml
grep -m1 'undici@7' pnpm-lock.yaml
```

Expected: diff kosong (tidak ada output sebelum baris grep), dan grep
menampilkan `undici@7.29.1:`. Kalau diff TIDAK kosong, berarti working tree
bawa perubahan deps lain - stop dan laporkan isinya sebelum lanjut.

### Task 2 - Audit (1 menit)

```
pnpm audit
```

Expected: `No known vulnerabilities found`.

- Kalau hasil ini -> lanjut Task 3 (path verifikasi).
- Kalau masih ada kerentanan undici -> LOMPAT ke Path B di bawah.

### Task 3 - Stash WIP biar build bersih (1 menit)

```
git stash push -m "WIP (auto-saved saat verifikasi HR-02)" && git status --short
```

Expected: status tinggal 3 untracked (`wisata*`) - untracked tidak ikut stash
default, itu tidak mengganggu build karena tidak direferensi `app/routes.ts`
yang bersih... KOREKSI: `app/routes.ts` versi bersih TIDAK mendaftarkan wisata,
jadi untracked tsx tidak ikut kompilasi. Aman.

### Task 4 - Install + build (3 menit)

```
pnpm install --frozen-lockfile
pnpm run build
```

Expected: install selesai tanpa error; `react-router build` sukses
(`vite build` + SSR bundle, output diakhiri ringkasan aset di `build/` atau
`dist/` tanpa kata `error`).

Opsional tambahan (murah, naikkan keyakinan): `npm test` -> expected
`# pass 81`, `# fail 0` (baseline setelah PR #68).

### Task 5 - Bukti + tutup issue #60 (3 menit)

Simpan output audit ke komentar issue:

```
gh issue comment 60 --repo sambasku/web --body 'Retest HR-02 (2026-10-03):
- pnpm audit: No known vulnerabilities found
- lockfile: undici@7.29.1 (patch >= 7.29.1 terpenuhi), wrangler@4.146.0, miniflare 5.20261001.0-alpha (transitive, devDependencies saja)
- pnpm run build: sukses
Ditutup oleh bump dependabot upstream (wrangler 4.135.0 -> 4.146.0).'
gh issue close 60 --repo sambasku/web --reason completed
```

Expected: URL komentar + konfirmasi close.

### Task 6 - Pulihkan WIP (1 menit)

```
git stash pop && git status --short
```

Expected: 7 file modified + 3 untracked kembali persis seperti sebelum Task 3.

### Path B - Kontingensi kalau audit masih kotor (jalankan hanya bila Task 2 gagal)

1. Stash WIP (sama seperti Task 3).
2. Potong branch:
   ```
   git checkout -b chore/hr-02-undici-audit origin/staging
   pnpm update miniflare wrangler
   ```
3. Kalau `pnpm audit` masih menampilkan undici < 7.29.1, tambahkan ke
   `package.json` (blok paling bawah sebelum `}`):
   ```json
   "pnpm": {
     "overrides": {
       "undici": ">=7.29.1"
     }
   }
   ```
   lalu `pnpm install` (regenerate `pnpm-lock.yaml`).
4. Verifikasi: `pnpm audit` -> `No known vulnerabilities found`;
   `pnpm run build` sukses; `npm test` -> `# pass 81, # fail 0`.
5. Commit pathspec eksplisit (working tree bisa bawa WIP lain setelah pop -
   di path B, pop BELUM dilakukan, tapi tetap disiplin):
   ```
   git add package.json pnpm-lock.yaml
   git commit -m 'chore(deps): patch undici >= 7.29.1 via wrangler/miniflare (HR-02, #60)'
   git push -u origin chore/hr-02-undici-audit
   gh pr create --base staging --title 'chore(deps): patch undici >= 7.29.1 (HR-02)' --body 'Closes #60' ...
   ```
6. JANGAN merge - Tuan review. Lalu checkout balik `fix/hr-01-safe-external-url`
   dan `git stash pop`.

## Tests / validation

TDD tidak berlaku (tidak ada kode baru; gate-nya audit + build):

1. `pnpm audit` -> `No known vulnerabilities found` (retest pertama issue).
2. `pnpm run build` -> sukses tanpa error (retest kedua, versi lokal).
3. `npm test` -> `# pass 81, # fail 0` (sinyal regresi gratis).
4. Deploy staging tetap sukses -> di luar plan ini, jalanan Tuan setelah merge/
   keputusan deploy (konvensi repo: deploy selalu manual).

## Risks, tradeoffs, dan open questions

- **Issue mungkin sudah stale**: semua indikasi menunjukkan dependabot sudah
  menutup lubangnya. Risiko utama plan ini justru over-work: menambah override
  `undici` padahal tidak perlu. Karena itu Path B hanya kontingensi.
- **miniflare alpha**: bump `pnpm update miniflare wrangler` di Path B bisa
  menaikkan miniflare ke versi alpha lebih baru. Terima saja (upstream wrangler
  yang memilih), selama audit + build hijau.
- **Build memakai node_modules eksisting**: `pnpm install --frozen-lockfile`
  memastikan node_modules = lockfile, jadi bukti build valid untuk lockfile
  yang di-audit.
- **Open question**: apakah Tuan mau issue #60 ditutup oleh agent atau mau
  menutup sendiri setelah baca bukti. Default plan: komentari + tutup (bukti
  konklusif, tidak ada perubahan kode yang perlu direview). Kalau Tuan ingin
 PR kosong tidak masuk akal; kalau mau keep-open, skip perintah close di
  Task 5.
- **Cache pnpm store**: kalau `pnpm install --frozen-lockfile` gagal karena
  store korup, `pnpm install --frozen-lockfile --force`. Jangan hapus
  `node_modules` manual dulu.
