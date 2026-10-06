# Plan: Finalisasi Issue #23 - Verifikasi + Commit Split per Submodule

## Goal

Rampungkan issue #23 (item user seragam di analitik "Aktivitas terbaru"): verifikasi ulang kedua sisi (API + mobile), lalu commit split per submodule (api, mobile, http, docs) atas persetujuan user.

## Current Context / Assumptions

- Kode fix SELESAI dan terverifikasi dari sesi sebelumnya:
  - API: `avatar_url` di `/discussions` (public/owner/admin, redact penulis terhapus), `voter_display_name` + `voter_avatar_url` di `/admin/votes`. Additive, console admin aman.
  - Mobile: mapping analitik konsisten (`dashboard_repository_impl.dart`), `DiscussionItem.avatarUrl` + avatar di feed diskusi.
  - Unit test: 5 fixture diskusi sudah disisip `avatarUrl: null`; test vote tidak perlu ubah (mock `items: []`). 47 unit pass.
  - docs/ + Bruno: barusan di-update (`docs/api/32-api-discussions.md`, `http/discussion/list-published.bru`, `http/discussion/get-detail.bru`, `http/vote/admin-list-votes.bru`).
- Struktur repo: monorepo dengan submodule. Root `/Users/ibnulmutaki/Development/github/sambasku` berisi submodule `api` (branch `staging`), `mobile` (branch `fix/tab-freeze`), `http` (branch `main`), `docs` (branch `main`).
- ATURAN WAJIB (`.cursor/rules/no-auto-commit-push.mdc`): JANGAN commit/push tanpa user minta eksplisit di chat. Semua langkah commit di plan ini menunggu gate persetujuan user.
- Working tree API berisi 113 file modified dari workstream lain (fitur user_roles, e2e updates, dll). HANYA file terdaftar di bawah yang boleh di-stage.
- `docs/api/32-api-discussions.md` adalah file UNTRACKED buatan workstream lain; edit kita cuma 1 baris (`avatar_url`) di dalamnya. Commit berarti commit seluruh file - jadi titik keputusan (lihat Risks).
- Sisa kerja non-commit: uji manual device (pekerjaan user, bukan agent).
- Error pre-existing di luar scope: tsc `role`/`roles`/TS2769 `derive-primary-role` (fitur user_roles), e2e votes skip `no such table: user_roles`, warning Flutter `public_profile_dto.dart`.

## Architecture / Proposed Approach

Verifikasi dulu (unit + analisis), baru commit per submodule dengan daftar file eksplisit (bukan `git add .`) supaya kerjaan workstream lain di tree yang sama tidak ikut ter-commit. Terakhir, submodule pointer di root di-commit bila user mau, dan serahkan checklist uji manual device ke user.

## File yang Termasuk Issue #23 (daftar commit eksplisit)

api/ (branch `staging`):
- `src/modules/discussion/domain/entities/discussion.entity.ts`
- `src/modules/discussion/infrastructure/discussion.repository.impl.ts`
- `src/modules/discussion/presentation/v1/discussion.controller.ts`
- `src/modules/discussion/presentation/v1/validators/discussion.validator.ts`
- `src/modules/vote/domain/repositories/vote.repository.ts`
- `src/modules/vote/infrastructure/vote.repository.impl.ts`
- `src/modules/vote/presentation/v1/admin-vote.controller.ts`
- `src/modules/vote/presentation/v1/validators/admin-votes.validator.ts`
- `src/modules/discussion/__tests__/unit/create-discussion.use-case.test.ts`
- `src/modules/discussion/__tests__/unit/approve-discussion.use-case.test.ts`
- `src/modules/discussion/__tests__/unit/create-discussion-reply.use-case.test.ts`
- `src/modules/discussion/__tests__/unit/create-discussion-reply-audio.use-case.test.ts`
- `src/modules/discussion/__tests__/unit/get-discussion-detail.use-case.test.ts`

mobile/ (branch `fix/tab-freeze`):
- `lib/features/admin_analytics/data/repositories/dashboard_repository_impl.dart`
- `lib/features/discussion/domain/discussion_models.dart`
- `lib/features/discussion/presentation/pages/discussion_feed_page.dart`

http/ (branch `main`):
- `discussion/list-published.bru`
- `discussion/get-detail.bru`
- `vote/admin-list-votes.bru`

docs/ (branch `main`):
- `api/32-api-discussions.md` (untracked; mengandung edit kita + isi workstream lain - lihat Risks)

## Step-by-step Tasks

### Task 1 - Pre-flight: cocokkan diff vs daftar file (read-only)

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/api && git diff --stat -- src/modules/discussion src/modules/vote
cd ../mobile && git diff --stat
cd ../http && git diff --stat -- discussion vote
```

Expected: hanya file di daftar atas; api ~15 files changed; mobile 3 files; http 3 files. Kalau ada file di diff yang TIDAK ada di daftar, berhenti dan tanya user (mungkin workstream lain menyentuh folder yang sama).

### Task 2 - Verifikasi API

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/api
npx vitest run src/modules/discussion/__tests__/unit src/modules/vote/__tests__/unit
```

Expected: `Test Files  10 passed (10)` dan `Tests  47 passed (47)`.
(Tidak jalan `tsc --noEmit` sebagai gate: error pre-existing `role`/`roles` dari fitur user_roles yang di-tree, bukan milik perubahan ini. Cukup unit test.)

### Task 3 - Verifikasi mobile

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/mobile
flutter analyze --no-pub 2>&1 | tail -3
flutter test test/features/admin_analytics/ test/features/activity/ test/features/vote/
```

Expected: analyze "No issues found!" (atau hanya artefak `build/` pods); test `All tests passed!` (59 test).

### Task 4 - GATE: minta persetujuan commit ke user

Tanya user di chat: "Verifikasi lulus. Mau Aku commit split per submodule sekarang?" Commit TIDAK boleh jalan tanpa jawaban eksplisit (rule `no-auto-commit-push`). Sertakan daftar file + pesan commit yang diusulkan (Task 5-8).

### Task 5 - Commit api (jika disetujui)

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/api
git add src/modules/discussion/domain/entities/discussion.entity.ts \
  src/modules/discussion/infrastructure/discussion.repository.impl.ts \
  src/modules/discussion/presentation/v1/discussion.controller.ts \
  src/modules/discussion/presentation/v1/validators/discussion.validator.ts \
  src/modules/vote/domain/repositories/vote.repository.ts \
  src/modules/vote/infrastructure/vote.repository.impl.ts \
  src/modules/vote/presentation/v1/admin-vote.controller.ts \
  src/modules/vote/presentation/v1/validators/admin-votes.validator.ts \
  src/modules/discussion/__tests__/unit/create-discussion.use-case.test.ts \
  src/modules/discussion/__tests__/unit/approve-discussion.use-case.test.ts \
  src/modules/discussion/__tests__/unit/create-discussion-reply.use-case.test.ts \
  src/modules/discussion/__tests__/unit/create-discussion-reply-audio.use-case.test.ts \
  src/modules/discussion/__tests__/unit/get-discussion-detail.use-case.test.ts
git commit -m "feat(discussion,vote): expose avatar_url & voter display data for uniform activity items (#23)"
```

Expected: 1 commit, `git status` tidak lagi menampilkan 13 file itu (file workstream lain tetap modified).

### Task 6 - Commit mobile (jika disetujui)

Branch: `fix/tab-freeze` langsung (keputusan user, tidak pindah branch).

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/mobile
git add lib/features/admin_analytics/data/repositories/dashboard_repository_impl.dart \
  lib/features/discussion/domain/discussion_models.dart \
  lib/features/discussion/presentation/pages/discussion_feed_page.dart
git commit -m "fix(analytics): uniform actor label + avatar across activity feed sources (#23)"
```

Expected: 1 commit di `fix/tab-freeze`; `assets/images/wotd_cover.png` (bukan milik kita) tetap untracked.

### Task 7 - Commit http + docs (jika disetujui)

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/http
git add discussion/list-published.bru discussion/get-detail.bru vote/admin-list-votes.bru
git commit -m "test(bruno): assert avatar_url & voter display fields (#23)"

cd ../docs
git add api/32-api-discussions.md
git commit -m "docs(api): document avatar_url in discussion list item (#23)"
```

Expected: 1 commit per submodule. File docs commit utuh sesuai keputusan user (lihat "Keputusan User").

### Task 8 - Commit pointer submodule di root (jika disetujui, opsional)

```bash
cd /Users/ibnulmutaki/Development/github/sambasku
git add api mobile http docs
git commit -m "chore: bump submodules for issue #23 (uniform activity user items)"
```

Expected: root menunjuk commit baru keempat submodule. JANGAN sentuh `.gitmodules` (sudah staged oleh orang lain), JANGAN `git push` apapun.

### Task 9 - Serahkan checklist uji manual device ke user

Ceklist untuk user (bukan tugas agent):
1. Login akun yang punya aktivitas vote + komentar + diskusi, buka Admin → Analitik → Aktivitas terbaru.
2. Item vote dari user X kini tampil display_name + avatar (bukan username polos).
3. Item diskusi dari user X tampil avatar (sebelumnya tanpa avatar).
4. Label + avatar user X identik di semua kind aktivitas.
5. Feed diskusi publik: avatar pembuka thread tampil; thread penulis terhapus: avatar kosong tanpa crash.

## Tests / Validation

- Task 2: `npx vitest run src/modules/discussion/__tests__/unit src/modules/vote/__tests__/unit` → 47 passed. Gagal = stop, perbaiki sebelum commit.
- Task 3: `flutter test test/features/admin_analytics/ test/features/activity/ test/features/vote/` → 59 passed; `flutter analyze --no-pub` tanpa error baru.
- Smoke Bruno (opsional, butuh server lokal jalan):
  ```bash
  cd /Users/ibnulmutaki/Development/github/sambasku/http && bru run discussion/list-published.bru --env local
  ```
  Expected: 200 + semua assert lulus termasuk `avatar_url`.
- Setelah commit: `git status` per submodule bersih dari file daftar issue #23.

## Keputusan User (dijawab di sesi plan)

- `docs/api/32-api-discussions.md` (untracked, workstream lain): COMMIT UTUH FILE SEKARANG. Seluruh isi file ikut ter-commit, itu disetujui user.
- Branch mobile: commit issue #23 LANGSUNG DI `fix/tab-freeze`, tidak pindah branch.

## Risks, Tradeoffs, Open Questions

1. Tree API bercampur workstream lain (113 file, termasuk fitur user_roles yang bikin e2e skip `no such table: user_roles`). Mitigasi: stage eksplisit per file; pre-flight Task 1 membandingkan diff vs daftar.
2. `docs/api/32-api-discussions.md` untracked milik workstream lain; commit kita ikut mem-publish isi itu. TERJAWAB: user setuju commit utuh file sekarang (Task 7 jalan apa adanya).
3. Mobile ada di branch `fix/tab-freeze`, bukan `staging`. TERJAWAB: user pilih commit langsung di `fix/tab-freeze` (Task 6 jalan tanpa pindah branch).
4. Bruno baru diverifikasi secara statis (edit file), belum dijalan `bru run` (butuh server + env lokal). Tradeoff disengaja: unit + kontrak validator sudah jadi pagar; smoke run opsional.
5. Uji manual device hanya bisa dilakukan user; agent tidak bisa memverifikasi tampilan avatar di device.
6. Push tidak masuk plan kecuali user minta (aturan repo).
