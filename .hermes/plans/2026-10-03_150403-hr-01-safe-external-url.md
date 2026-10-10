# Plan: HR-01 - Anchor dari data API tanpa allowlist skema (issue #59)

## Goal

Semua anchor `href` yang berasal dari data API (input publik / pihak ketiga) hanya
boleh `https:`; skema lain dirender teks polos, bukan link klikable.

## Current context / assumptions

- Repo: submodule `web/` (Remix/React Router 7 + Mantine). Superroot `sambasku/`
  hanya pointer; commit di dalam `web/`.
- Web submodule saat ini checkout di `feat/seo-lemma-diskusi` (WIP user, sudah 3
  commit lokal). JANGAN commit di situ - potong branch baru dari `origin/staging`.
- Dua titik render yang bermasalah (identik antara working tree dan `origin/staging`,
  sudah diverifikasi via `git show origin/staging:...`):
  1. `app/routes/ruang-diskusi.$id.tsx:173-182` - `help.link_url` (input bebas
     pembuat diskusi) langsung jadi `href`.
  2. `app/presentation/components/word/image-credit.tsx` - komponen `ExtLink`
     (baris 26-34) menerima `href` mentah; dipanggil di baris 45 (`attribution.url`
     Openverse), 47 (`home.url`, konstanta internal), 54 (`license_url`).
     Membenahi `ExtLink` saja otomatis menutup ketiga call site.
- Precedent yang harus ditiru: `app/presentation/utils/display-image-url.ts` sudah
  jadi choke point URL gambar (skema non-https ditolak) lengkap dengan test
  `display-image-url.test.ts`. Helper baru mengikuti pola yang sama.
- Test runner = node:test (BUKAN vitest). `npm test` = `node --experimental-strip-types
  --test "app/**/*.test.ts"`. Konsekuensi: file test WAJIB import relatif
  (`./safe-external-url.ts`), alias `@/` tidak resolve di node --test.
- Baseline test hijau (73+ di docs pentest). Gate verifikasi: `npm test`,
  `npm run typecheck`, `npm run lint` - semua dari `web/`.
- React 19 sudah memblok `javascript:`, tapi `data:text/html`, `vbscript:`, dan
  custom app protocol masih lolos jadi anchor - itulah yang ditutup.

## Architecture / proposed approach

Satu helper murni `safeExternalUrl(url)` di
`app/presentation/utils/safe-external-url.ts`: parse dengan `new URL`, terima
hanya `protocol === 'https:'`, selain itu return `undefined`. Pemanggil yang
menerima `undefined` merender teks polos. Dua titik masalah di-wire ke helper;
`ExtLink` di `image-credit.tsx` jadi choke point tunggal untuk attribution.

## Step-by-step tasks

Semua command dijalankan dari `/Users/ibnulmutaki/Development/github/sambasku/web/`
kecuali disebut lain.

### Task 1 - Potong branch dari staging (2 menit)

Cek dulu dua file target bersih (bawaan WIP user tidak menyentuhnya):

```
git status --short 'app/routes/ruang-diskusi.$id.tsx' app/presentation/components/word/image-credit.tsx
```

Expected output: kosong.

```
git fetch origin staging
git checkout -b fix/hr-01-safe-external-url origin/staging
git branch --show-current
```

Expected output terakhir: `fix/hr-01-safe-external-url`.

Kalau `git checkout` menolak karena working tree berantakan di file lain, STOP
dan laporkan - jangan stash pekerjaan user tanpa izin.

### Task 2 - Test merah (3 menit)

Buat file baru `app/presentation/utils/safe-external-url.test.ts`:

```ts
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { safeExternalUrl } from './safe-external-url.ts';

describe('safeExternalUrl (pentest HR-01, issue #59)', () => {
  it('menerima https apa adanya', () => {
    assert.equal(
      safeExternalUrl('https://example.com/artikel?a=1'),
      'https://example.com/artikel?a=1',
    );
    assert.equal(
      safeExternalUrl('HTTPS://EXAMPLE.COM/X'),
      'HTTPS://EXAMPLE.COM/X',
    );
  });

  it('menolak skema berbahaya dan eksotis', () => {
    assert.equal(
      safeExternalUrl('data:text/html,<script>alert(1)</script>'),
      undefined,
    );
    assert.equal(safeExternalUrl('javascript:alert(1)'), undefined);
    assert.equal(safeExternalUrl('vbscript:msgbox(1)'), undefined);
    assert.equal(safeExternalUrl('sambasku://app/users/x'), undefined);
    assert.equal(safeExternalUrl('ftp://files.example.com/a'), undefined);
    assert.equal(safeExternalUrl('http://example.com/'), undefined);
  });

  it('menolak input rusak dan kosong', () => {
    assert.equal(safeExternalUrl('bukan url'), undefined);
    assert.equal(safeExternalUrl(''), undefined);
    assert.equal(safeExternalUrl(null), undefined);
    assert.equal(safeExternalUrl(undefined), undefined);
  });
});
```

Catatan: import pakai path relatif + ekstensi `.ts`, bukan `@/` (alias tidak
resolve di node --test; pola sama dengan `rss.test.ts`).

Jalankan:

```
npm test
```

Expected: test baru GAGAL (report `ERR_MODULE_NOT_FOUND` untuk
`./safe-external-url.ts` karena modulnya belum ada), test lama tetap lulus.
Itu bukti merah yang valid.

### Task 3 - Implementasi helper (2 menit)

Buat file baru `app/presentation/utils/safe-external-url.ts`:

```ts
/**
 * URL eksternal yang aman jadi anchor `href` (pentest HR-01, issue #59).
 *
 * Data dari API bisa berisi input publik (`link_url` diskusi) atau data pihak
 * ketiga (attribution Openverse). Hanya `https:` yang boleh jadi link
 * klikable; selain itu (javascript:, data:, vbscript:, custom app protocol,
 * URL rusak, kosong) kembalikan undefined - pemanggil render teks polos.
 */
export function safeExternalUrl(
  url: string | null | undefined,
): string | undefined {
  if (!url) return undefined;
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return undefined;
  }
  if (parsed.protocol !== 'https:') return undefined;
  return url;
}
```

Detail: return `url` asli (bukan `parsed.toString()`) supaya casing dan query
UTM tidak dinormalisasi; `parsed.protocol` sudah lowercase otomatis sehingga
`HTTPS://` tetap diterima.

Jalankan:

```
npm test
```

Expected: semua lulus, termasuk 3 test baru. Ringkasan diakhiri
`# pass <N>` dengan `# fail 0`.

### Task 4 - Wire ruang-diskusi.$id.tsx (3 menit)

Di `app/routes/ruang-diskusi.$id.tsx`:

Tambahkan import (satu blok dengan import util lain):

```tsx
import { safeExternalUrl } from '@/presentation/utils/safe-external-url';
```

Di dalam komponen `RuangDiskusiDetailPage`, tepat setelah deklarasi `author`
(sekitar baris 117-118), tambah:

```tsx
const linkUrl = safeExternalUrl(help.link_url?.trim());
```

Ganti blok anchor (baris 173-182):

```tsx
{help.link_url?.trim() ? (
  <Anchor
    href={help.link_url.trim()}
    target="_blank"
    rel="noopener noreferrer"
    size="sm"
  >
    {help.link_url.trim()}
  </Anchor>
) : null}
```

menjadi:

```tsx
{linkUrl ? (
  <Anchor
    href={linkUrl}
    target="_blank"
    rel="noopener noreferrer"
    size="sm"
  >
    {linkUrl}
  </Anchor>
) : help.link_url?.trim() ? (
  <Text size="sm" style={{ wordBreak: 'break-all' }}>
    {help.link_url.trim()}
  </Text>
) : null}
```

Perilaku: https tetap anchor; skema lain tampil sebagai teks polos yang masih
bisa disalin user (sesuai remediasi issue); kosong = tidak render apa pun
(perilaku lama tetap).

### Task 5 - Wire image-credit.tsx (3 menit)

Di `app/presentation/components/word/image-credit.tsx`, tambahkan import:

```tsx
import { safeExternalUrl } from '@/presentation/utils/safe-external-url';
```

Ganti fungsi `ExtLink` (baris 26-34):

```tsx
function ExtLink({ href, children }: { href?: string; children: string }) {
  if (!href) return <>{children}</>;
  return (
    <Anchor href={href} target="_blank" rel="noopener noreferrer" inherit>
      {children}
      {linkIcon}
    </Anchor>
  );
}
```

menjadi:

```tsx
function ExtLink({ href, children }: { href?: string; children: string }) {
  const safe = safeExternalUrl(href);
  if (!safe) return <>{children}</>;
  return (
    <Anchor href={safe} target="_blank" rel="noopener noreferrer" inherit>
      {children}
      {linkIcon}
    </Anchor>
  );
}
```

Satu choke point ini menutup ketiga pemakaian: `attribution.url` (baris 45,
sebelum `withUtm` - sanitasi tetap benar walau UTM disuntik setelahnya karena
validasi terjadi di ExtLink), `home.url` (baris 47, konstanta https internal,
tetap lolos), dan `license_url` (baris 54). Label teks (`{name}`, `{license}`)
tetap tampil sebagai teks polos saat URL ditolak - kredit tidak hilang.

### Task 6 - Verifikasi penuh (3 menit)

```
npm test
npm run typecheck
npm run lint
```

Expected: `# fail 0` di test; typecheck dan lint keluar tanpa error baru
(error yang MENYEBUT file yang kamu ubah = blocker; error pre-existing di file
lain = catat, bukan regresimu).

Review diff:

```
git diff --stat
git diff
```

Expected: hanya 4 file berubah (2 baru, 2 edit). Tidak ada perubahan lain.

### Task 7 - Commit (2 menit)

Pathspec eksplisit, jangan `git add -A` (working tree submodule bisa berisi WIP
user dari fitur lain):

```
git add app/presentation/utils/safe-external-url.ts app/presentation/utils/safe-external-url.test.ts 'app/routes/ruang-diskusi.$id.tsx' app/presentation/components/word/image-credit.tsx
git commit -m 'fix: hanya izinkan https di anchor data eksternal (HR-01, #59)'
```

Verifikasi:

```
git status --short
git log --oneline -1
```

Expected: file target tidak ada lagi di status; commit `fix/hr-01-safe-external-url`
muncul di atas branch.

### Task 8 - Push + PR, jangan merge (3 menit)

```
git push -u origin fix/hr-01-safe-external-url
```

Cek remote dulu (`git remote get-url origin`) untuk menentukan repo PR.
Kalau issue #59 ada di repo yang sama dengan PR, gunakan `Closes #59` di body
agar auto-close saat merge; kalau beda repo, tempel link PR sebagai komentar di
issue #59.

```
gh pr create --base staging --title 'fix: hanya izinkan https di anchor data eksternal (HR-01)' --body '...'
```

Isi body PR (sesuaikan repo issue):

```markdown
## Ringkasan
- Helper `safeExternalUrl()`: hanya `https:` yang boleh jadi anchor href dari data eksternal; selain itu dirender teks polos.
- Titik yang diperbaiki: `link_url` diskusi (app/routes/ruang-diskusi.$id.tsx) dan attribution Openverse via choke point `ExtLink` (app/presentation/components/word/image-credit.tsx).
- Test unit baru: skema berbahaya/eksotis (data:, vbscript:, javascript:, custom protocol, http:) ditolak; https lolos apa adanya.

## Retest
- `link_url = "data:text/html,<script>alert(1)</script>"` -> teks polos, bukan anchor (unit test).
- `https://` normal -> tetap link (unit test).

Closes #59
```

JANGAN merge - Tuan review sendiri. Deploy selalu keputusan Tuan.

### Task 9 (opsional, submodule docs) - Update status pentest (2 menit)

Setelah PR terbuka, di repo `docs/` edit
`docs/pentest/web/09-HERMES-PENTEST.md` baris 26: status HR-01 dari
`Issue terbuka` jadi `Selesai (PR <nomor>)`. Commit terpisah di submodule docs,
branch ikuti arahan Tuan (default `staging`). Kalau ragu, lewaskan dan biarkan
Tuan memutuskan.

## Tests / validation

Sudah tertutup per task di atas (siklus TDD Task 2 merah -> Task 3 hijau ->
Task 6 gate penuh). Ringkasan kasus retest dari issue #59 dan pemetaannya:

1. `data:text/html,<script>alert(1)</script>` di `link_url` -> unit test
   `menolak skema berbahaya dan eksotis` + cabang fallback `Text` di Task 4.
2. `https://` normal -> unit test `menerima https apa adanya`.
3. Regresi render: `npm run typecheck` menjamin props Mantine (`Text`,
   `Anchor`) yang dipakai valid.

Tidak perlu dev server/manual QA: logika murni util + JSX sederhana, unit test
sudah menutup keduanya.

## Risks, tradeoffs, dan open questions

- **Tradeoff http:// ditolak**: beberapa situs lama masih http. Keputusan issue
  sudah tegas "hanya https:", jalan.
- **Konsistensi dengan kode lama**: `pronunciation-player.tsx:18` masih pakai
  `startsWith('https:')` dan `users.$username.tsx:138` anchor `sambasku://`
  (deep link internal, bukan input publik). Keduanya TIDAK disentuh - bukan
  vektor dari data API. Migrasi `startsWith` ke helper bisa menyusul kalau mau
  rapi, tapi di luar scope (YAGNI).
- **`license_url` Openverse ditolak** (seandainya API mengembalikan non-https):
  label lisensi tetap tampil sebagai teks, tidak crash. Perilaku fail-closed
  yang diinginkan.
- **Open question**: repo lokasi issue #59 (web submodule vs superroot) menentukan
  `Closes #59` vs komentar manual - cek `git remote get-url origin` saat Task 8.
- Risiko merge konflik kecil di `ruang-diskusi.$id.tsx` karena `feat/seo-lemma-diskusi`
  (WIP user) juga menyentuh file itu; branch ini dari `origin/staging` jadi PR
  bersih, konflik hanya muncul saat WIP seo diteruskan - bukan masalah PR ini.
