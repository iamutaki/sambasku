# Fix feed timeline inkonsisten (#86 + #85) — verifiedAt reset & jejak verifikator

Issue: https://github.com/sambasku/mobile/issues/86 (dan beririsan #85)

## Goal

Feed "Aktivitas terbaru" tidak lagi menampilkan kata lama sebagai "Baru ditambahkan" saat kata itu diedit/dilengkapi (tambah gambar dsb.), dan aksi verifikator (lengkapi kata / setujui usulan) tercatat jelas di timeline profil publiknya dengan label "Verifikasi".

## Current context / asumsi

- Superroot `sambasku` = kumpulan submodule git terpisah. Sentuhan: `api/` dan `mobile/`. Kerja langsung di branch `staging` di masing-masing submodule (JANGAN buat branch baru). Commit dengan pathspec eksplisit; working tree bisa membawa WIP user lain.
- Root cause terverifikasi lewat baca kode (bukan tebakan):
  1. `api/src/modules/word-suggestions/infrastructure/word-suggestion.repository.impl.ts` — dua lokasi menimpa `words.verified_by/verified_at` TANPA cek kata sudah verified:
     - `createSuggestion` cabang `selfApply` (~line 636-646, alur "Lengkapi kata" verifikator).
     - `approveSuggestion` cabang `baselineSnapshot` (~line 928-945).
     Padahal precedent preserve sudah ada: `contribution.repository.impl.ts:1318` (`if (!before?.isVerified)`) dan `publish-or-merge-meanings.ts:59`.
  2. Feed beranda `api/src/modules/activity/infrastructure/activity.repository.impl.ts:244` memakai `occurredAtSql(words.verifiedAt, words.createdAt)` — reset verifiedAt = kata lama lompat ke puncak feed berlabel "Kata · Baru ditambahkan" dengan actor = pembuat asli kata (screenshot #86: "lawang" oleh Jasmin padahal aksinya Ibnul Mutaki menambah gambar).
  3. Timeline profil publik: aksi verifikator di `word_edit_suggestions` (lengkapi kata / approve usulan) TIDAK pernah masuk `GET /users/:username/activity` karena `listRecentVerifications` (`public-user.repository.impl.ts:262`) hanya baca `contribution_reviews`. Ditambah di mobile, kind `verification` dipetakan ke `FeedActivityKind.vote` (label "Penilaian") — menyesatkan (keluhan #85).
- Kontrak feed: `docs/api/37-api-activity-feed.md`; profil publik: `docs/api/19-api-profil-publik.md`; feed mobile: `docs/mobile/23-mobile-activity-feed.md`. Docs wajib di-update di sesi yang sama.
- Perilaku tetap: `words.verified_by` menunjuk verifikator PERTAMA (atribusi tidak hilang saat verifikator lain mengedit) — sama dengan precedent contribution repo.
- Angka verifikasi: api full suite `npx vitest run` ±35 detik; mobile full `flutter test` 504+ lulus. Baseline error tsc/api dan analyze/mobile bisa non-nol karena WIP user — yang dikejar NOL error yang MENYEBUT file yang diubah.

## Arsitektur / pendekatan

Tiga lapis: (1) API berhenti menimpa stamp verifikasi kata yang sudah verified (akar masalah, menyelamatkan atribusi "Diverifikasi oleh" di detail kata sekaligus feed); (2) feed memakai `words.created_at` murni sebagai waktu kind `word` — semantik "Baru ditambahkan" jadi jujur dan self-healing untuk data staging yang sudah terlanjur salah; (3) timeline profil publik mengikutsertakan review `word_edit_suggestions` sebagai kind `verification` (sudah ada di enum wire schema), mobile memetakan kind itu ke label/ikon sendiri ("Verifikasi", badge check), bukan lagi menyamar jadi "Penilaian".

TDD per task: test merah dulu → implement minimal → hijau → commit kecil.

---

## Task 0 — Preflight (5 menit)

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/api && git branch --show-current   # harus: staging
cd ../mobile && git branch --show-current                                          # harus: staging
cd ../api && npx tsc --noEmit 2>&1 | grep -cE 'error TS'    # catat angka baseline
ls api/.env.test    # harus ada; kalau tidak, integration/e2e test akan skip (describe.skipIf) -> LAPOR, jangan paksa
```

Kalau salah satu submodule bukan di `staging`: STOP, laporkan (bukan tugasmu memindahkan branch user).

---

## Task 1 — API: preserve stamp verifikasi (RED)

File: `api/src/modules/word-suggestions/__tests__/integration/word-suggestion.repository.impl.test.ts`

Fixture `beforeEach` sudah menyiapkan kata `WORD` dengan `isVerified: true, verifiedBy: OWNER, verifiedAt: new Date()`.

1a. Ubah ekspektasi test yang ada (line ~115, test "reviewer → status approved, changes diterapkan + kata tetap verified"):

```ts
    const [word] = await db.select().from(words).where(eq(words.id, WORD));
    expect(word.notes).toBe('baru dari reviewer');
    expect(word.isVerified).toBe(true);
    // Stamp verifikasi ASLI dipertahankan: verifikator lain yang mengedit kata
    // yang sudah verified tidak menimpa atribusi verifikator pertama (#86).
    expect(word.verifiedBy).toBe(OWNER);
```

(ekspektasi lama `expect(word.verifiedBy).toBe(REVIEWER)` dihapus — itu yang mendokumentasikan bug.)

1b. Tambah test baru di describe yang sama untuk cabang `approveSuggestion` baseline (setelah test "reviewer pada kata belum verified"):

```ts
  it('approve usulan tayang-dulu: kata yang TERVERIFIKASI di tengah jalan tidak ditimpa stamp-nya', async () => {
    // Kontributor mengusulkan pada kata belum verified -> tayang dulu (baseline).
    await db
      .update(words)
      .set({ isVerified: false, verifiedBy: null, verifiedAt: null })
      .where(eq(words.id, WORD));
    const suggestion = await repo.createSuggestion(
      KONTRIBUTOR,
      WORD,
      { notes: 'usulan tayang dulu' },
      'Perbaikan',
      'typo',
      'contributor',
    );
    expect(suggestion.status).toBe('pending');

    // Verifikator lain memverifikasi kata lewat jalur lain sebelum usulan direview.
    const ORIGINAL_AT = new Date(Date.now() - 60_000);
    await db
      .update(words)
      .set({ isVerified: true, verifiedBy: OWNER, verifiedAt: ORIGINAL_AT })
      .where(eq(words.id, WORD));

    await repo.approveSuggestion(suggestion.id, REVIEWER, 'ok');

    const [word] = await db.select().from(words).where(eq(words.id, WORD));
    expect(word.isVerified).toBe(true);
    expect(word.verifiedBy).toBe(OWNER);
    expect(word.verifiedAt?.getTime()).toBe(ORIGINAL_AT.getTime());
  });
```

Catatan: kalau `createSuggestion` contributor pada kata unverified dengan `{notes}` tidak menghasilkan baseline (cek helper `isRevertibleForApplyPending`), ganti changes jadi bidang yang revertible sesuai test "sinonim kontributor pada kata belum terverifikasi tidak tayang sebelum disetujui" — ikuti pola fixture test itu.

Jalankan (harus GAGAL di dua ekspektasi `verifiedBy`):

```bash
cd api && npx vitest run src/modules/word-suggestions/__tests__/integration/word-suggestion.repository.impl.test.ts 2>&1 | tail -20
```

Commit merah:

```bash
git commit -m "test(word-suggestions): stamp verifikasi asli dipertahankan saat edit (#86, red)" -- src/modules/word-suggestions/__tests__/integration/word-suggestion.repository.impl.test.ts
```

## Task 2 — API: preserve stamp verifikasi (GREEN)

File: `api/src/modules/word-suggestions/infrastructure/word-suggestion.repository.impl.ts`

2a. Cabang `selfApply` di `createSuggestion` (~line 636-646). Variabel `word` di scope sudah memuat `isVerified` (di-select ~line 541). Bungkus update dengan guard:

```ts
        await applyChangesToWord(suggestion.id, userId, 'approve', undefined, prepared);
        // applyChangesToWord tidak set is_verified; verifikator = self-review (Section 22 parity).
        // Kata yang SUDAH verified mempertahankan stamp asli (parity guard
        // reviewWord di contribution repo): menimpanya membuat kata lama
        // muncul ulang di feed sebagai "baru" + menghapus atribusi verifikator
        // pertama (#86).
        if (!word.isVerified) {
          await db
            .update(words)
            .set({
              isVerified: true,
              verifiedBy: userId,
              verifiedAt: new Date(),
              updatedAt: new Date(),
            })
            .where(eq(words.id, wordId));
        }
```

2b. Cabang `baselineSnapshot` di `approveSuggestion` (~line 926-945). Ubah select + bungkus update:

```ts
      const [word] = await db
        .select({ lemma: words.lemma, isVerified: words.isVerified })
        .from(words)
        .where(eq(words.id, row.wordId))
        .limit(1);
      // Guard sama dengan selfApply: jangan timpa stamp verifikasi yang sudah ada.
      if (!word?.isVerified) {
        await db
          .update(words)
          .set({
            isVerified: true,
            verifiedBy: reviewerId,
            verifiedAt: new Date(),
            updatedAt: new Date(),
          })
          .where(eq(words.id, row.wordId));
      }
```

(Return `wordLemma: word?.lemma ?? ''` tetap.)

Jalankan (harus HIJAU semua):

```bash
npx vitest run src/modules/word-suggestions 2>&1 | tail -5
```

Commit hijau:

```bash
git commit -m "fix(word-suggestions): jangan timpa verified_by/at kata yang sudah verified (#86)" -- src/modules/word-suggestions/infrastructure/word-suggestion.repository.impl.ts
```

## Task 3 — API: waktu feed kind `word` = `created_at` (RED)

File baru: `api/src/modules/activity/__tests__/integration/activity-word-time.integration.test.ts`

Salin prolog `activity-keyset.integration.test.ts` (dotenv `.env.test` sebelum import `@/...`, `describe.skipIf(!hasTestDb)`). Fixture mandiri: 1 bahasa, 1 user, 2 kata published — `OLD` (createdAt 30 hari lalu, verifiedAt BARU-BARU INI / sekarang, meniru data staging yang sudah terlanjur salah) dan `NEW` (createdAt sekarang, verifiedAt null). Pakai id ULID 26-char seperti fixture keyset.

```ts
  it('waktu kind word = created_at; verified_at segalanya tidak menghidupkan ulang kata lama (#86)', async () => {
    const items = await repo.listRecentWords(10);
    expect(items.map((i) => i.id)).toEqual([`word:${NEW}`, `word:${OLD}`]);
    expect(items[1]!.createdAt.getTime()).toBe(OLD_SECONDS * 1000);
  });
```

Jalankan (harus GAGAL: saat ini OLD muncul pertama karena verifiedAt segar):

```bash
npx vitest run src/modules/activity/__tests__/integration/activity-word-time.integration.test.ts 2>&1 | tail -15
```

Commit merah. (Pathspec file test baru.)

## Task 4 — API: waktu feed kind `word` = `created_at` (GREEN)

File: `api/src/modules/activity/infrastructure/activity.repository.impl.ts` line 244, di dalam `listRecentWords`:

```ts
    // "Baru ditambahkan" = waktu kata DIBUAT. Jangan pakai verified_at:
    // edit/lengkapi kata pada kata lama menyentuh stamp verifikasi dan membuat
    // kata lama lompat ke puncak feed seolah baru ditambahkan (#86).
    const occurredAt = occurredAtSql(words.createdAt);
```

Jalankan seluruh modul activity (test keyset lama masih harus lulus — guard timestamp-nya tetap bekerja lewat created_at):

```bash
npx vitest run src/modules/activity 2>&1 | tail -5
```

Commit hijau.

## Task 5 — API: verifikasi usulan masuk timeline profil (RED)

File: `api/src/modules/user/__tests__/e2e/v1/public-profile.e2e.test.ts`

BACA dulu `beforeAll`/setup file itu, ikuti pola seed-nya. Tambah test: seed reviewer user `revver` + kata published + satu baris `wordEditSuggestions` (`status: 'approved'`, `reviewedBy: revver`, `reviewedAt: new Date()`, `userId` = user lain, `wordId` = kata itu), lalu:

```ts
    const res = await app.request('/api/v1/users/revver/activity');
    expect(res.status).toBe(200);
    const body = await res.json();
    const item = body.data.items.find((i: { kind: string }) => i.kind === 'verification');
    expect(item).toMatchObject({
      kind: 'verification',
      lemma: '<lemma kata>',
      word_id: '<id kata>',
      summary: 'Memverifikasi perubahan: <lemma kata>',
    });
```

Jalankan (harus GAGAL: item tidak ada):

```bash
npx vitest run src/modules/user/__tests__/e2e/v1/public-profile.e2e.test.ts 2>&1 | tail -15
```

Commit merah.

## Task 6 — API: verifikasi usulan masuk timeline profil (GREEN)

File: `api/src/modules/user/infrastructure/public-user.repository.impl.ts`, method `listRecentVerifications` (~line 262-308).

1. Tambah `wordEditSuggestions` ke import schema dari `@/shared/database/drizzle/schema` (belum diimport di file ini).
2. Refactor method jadi dua sumber + merge:

```ts
  async listRecentVerifications(
    userId: string,
    { limit, cursor }: RecentListParams,
  ): Promise<PublicActivityPage> {
    // Dua sumber review verifikator: antrean kontribusi (contribution_reviews)
    // dan usulan edit kata (word_edit_suggestions, termasuk self-apply
    // "Lengkapi kata"). Tanpa ini aksi lengkapi kata tidak pernah tampak di
    // timeline publik verifikator (#86).
    const reviewRows = await this.db /* ...query contribution_reviews SEKARANG TANPA limit+1 di sini... */
```

Bentuk konkret (query lama dipertahankan apa adanya, hanya `toPage` dipindah ke bawah):

```ts
    const [reviewRows, suggestionRows] = await Promise.all([
      this.db
        .select({
          id: contributionReviews.id,
          createdAt: contributionReviews.createdAt,
          entityType: contributions.entityType,
          entityId: contributions.entityId,
        })
        .from(contributionReviews)
        .innerJoin(contributions, eq(contributionReviews.contributionId, contributions.id))
        .where(
          and(
            eq(contributionReviews.reviewerId, userId),
            ne(contributionReviews.status, 'pending'),
            isNull(contributionReviews.deletedAt),
            cursor ? lt(contributionReviews.id, cursor) : undefined,
          ),
        )
        .orderBy(desc(contributionReviews.id))
        .limit(limit + 1),
      this.db
        .select({
          id: wordEditSuggestions.id,
          reviewedAt: wordEditSuggestions.reviewedAt,
          wordId: wordEditSuggestions.wordId,
          lemma: words.lemma,
        })
        .from(wordEditSuggestions)
        .innerJoin(words, eq(words.id, wordEditSuggestions.wordId))
        .where(
          and(
            eq(wordEditSuggestions.reviewedBy, userId),
            inArray(wordEditSuggestions.status, ['approved', 'corrected']),
            isNotNull(wordEditSuggestions.reviewedAt),
            isNull(wordEditSuggestions.deletedAt),
            isNull(words.deletedAt),
            eq(words.status, 'published'),
            cursor ? lt(wordEditSuggestions.id, cursor) : undefined,
          ),
        )
        .orderBy(desc(wordEditSuggestions.id))
        .limit(limit + 1),
    ]);

    const entries = [
      ...reviewRows.map((row) => ({
        id: row.id,
        item: {
          kind: 'verification' as const,
          id: row.id,
          occurredAt: row.createdAt,
          wordId: null as string | null, // diresolve di bawah (pola lama)
          lemma: null as string | null,
          summary: '',
        },
      })),
      ...suggestionRows.map((row) => ({
        id: row.id,
        item: {
          kind: 'verification' as const,
          id: row.id,
          occurredAt: row.reviewedAt!,
          wordId: row.wordId,
          lemma: row.lemma,
          summary: row.lemma
            ? `Memverifikasi perubahan: ${row.lemma}`
            : 'Memverifikasi perubahan',
        },
      })),
    ];
```

Catatan: JANGAN benar-benar meratakkan mapping lama `reviewRows` seperti sketsa di atas — pertahankan blok `resolveContributionParents` + `ENTITY_LABEL` yang ada untuk `reviewRows` (isi `wordId`/`lemma`/`summary` seperti semula), lalu gabung hasilnya dengan `suggestionRows.map(...)` di atas, urutkan `occurredAt` desc (tiebreak `id` desc), slice `limit + 1`, dan akhiri `return toPage(entries, limit);`. Cursor keyset `id < cursor` aman lintas dua tabel karena keduanya ULID monoton-waktu. (`inArray`, `isNotNull` sudah diimport? cek header file — tambah kalau belum.)

Jalankan:

```bash
npx vitest run src/modules/user 2>&1 | tail -5
```

Commit hijau: `fix(user): timeline verifikasi profil publik ikut memuat review usulan edit kata (#86)`.

## Task 7 — API: docs

1. `docs/api/37-api-activity-feed.md` — baris tabel kind `word` (line 23): tambah keterangan sumber waktu = `created_at` (bukan `verified_at`). Tambah bullet di "Feed sehat dan aman": waktu kind `word` selalu `created_at`; edit/lengkapi kata tidak menghidupkan ulang entri feed.
2. `docs/api/19-api-profil-publik.md` — bagian "Pembaruan (gambar publik + aktivitas)": ubah baris `GET /users/:username/activity` jadi menyebut sumber `verification` = `contribution_reviews` + `word_edit_suggestions (reviewed_by, approved/corrected)`, copy contoh `Memverifikasi perubahan: {lemma}`.

Verifikasi: `grep -n "created_at" docs/api/37-api-activity-feed.md` menunjukkan baris baru.

Commit (di submodule docs bila `docs/` submodule sendiri — cek `git -C docs rev-parse --show-toplevel`; kalau bagian superroot, commit di superroot dengan pathspec `docs/...`).

## Task 8 — API: gate penuh

```bash
npm run typecheck 2>&1 | grep -E 'error TS' | grep -E 'word-suggestions|activity|user/' ; echo "new-errors: $?"   # harus 1 (tidak ada match)
npx vitest run 2>&1 | grep 'Tests '    # semua pass; ±35 dtk; satu suite skip karena no-DB = laporkan
```

Kalau ada test lain GAGAL karena perubahan ekspektasi `verifiedBy` (grep pesan gagal untuk `verified`): test itu mendokumentasikan bug lama → perbarui ekspektasinya mengikuti Task 1, sebut di commit.

## Task 9 — Mobile: kind `verification` (RED)

File: `mobile/test/features/user_profile/public_activity_mapper_test.dart`

Ubah test "kind dipetakan ke enum feed terdekat" (line ~40):

```dart
    expect(
      mapPublicActivityToFeed(item('verification'), profile).kind,
      FeedActivityKind.verification,
    );
```

Jalankan (harus GAGAL — sekarang termap ke `vote`):

```bash
flutter test test/features/user_profile/public_activity_mapper_test.dart 2>&1 | tail -5
```

Commit merah.

## Task 10 — Mobile: kind `verification` (GREEN)

1. `mobile/lib/features/activity/domain/entities/feed_activity_item.dart`:
   - enum: tambah `verification,` setelah `vote,`.
   - `parseFeedActivityKind`: tambah `case 'verification': return FeedActivityKind.verification;`.
2. `mobile/lib/features/user_profile/domain/public_activity_mapper.dart` line 14: `'vote' || 'verification' => FeedActivityKind.vote,` dipecah:
   ```dart
     'vote' => FeedActivityKind.vote,
     'verification' => FeedActivityKind.verification,
   ```
3. `mobile/lib/features/activity/presentation/widgets/activity_feed_tile.dart`:
   - `_friendlyKindLabel` (line ~218): `FeedActivityKind.verification => 'Verifikasi',`.
   - `_ctaLabel` (line ~233): `FeedActivityKind.verification => 'Lihat kata',`.
4. `mobile/lib/features/activity/presentation/widgets/activity_kind_avatar.dart` `_styleFor` (switch setelah case vote, line ~100):
   ```dart
       case FeedActivityKind.verification:
         return _KindAvatarStyle(
           icon: FLucideIcons.badgeCheck,
           foreground: primary,
         );
   ```
5. `mobile/lib/features/dictionary/presentation/pages/home_search_page.dart` ~line 505-515 punya switch CTA kind paralel — tambah case `FeedActivityKind.verification => 'Lihat kata',` (`flutter analyze` akan menunjuk baris tepatnya kalau terlewat).

Jalankan:

```bash
flutter analyze --no-pub 2>&1 | grep -E 'feed_activity_item|public_activity_mapper|activity_feed_tile|activity_kind_avatar|home_search_page' ; echo "issues: $?"  # harus 1 (kosong)
flutter test test/features/user_profile test/features/activity 2>&1 | tail -3
```

Commit hijau: `feat(activity): kind verification di timeline profil - label + ikon badge check (#86)`.

## Task 11 — Mobile: docs + gate penuh

1. `docs/mobile/23-mobile-activity-feed.md` — bagian "Tampilan baris feed" / tile: tambah paragraf singkat: kind `verification` (timeline profil publik) tampil berlabel "Verifikasi", ikon badge check; sumber API `word_edit_suggestions` + `contribution_reviews`.
2. Gate:

```bash
flutter analyze --no-pub   # nol issue pada file yang diubah (baseline lain boleh)
flutter test 2>&1 | tail -3   # full suite, semua lulus
```

Commit docs.

## Task 12 — Push + PR

1. Pastikan lagi branch staging sebelum push (`git branch --show-current` per submodule).
2. Push `api/` dan `mobile/` (dan `docs/` bila submodule): `git push origin staging`.
3. PR per repo (base branch default repo masing-masing), body ringkas: root cause verifiedAt + waktu feed + trace verifikator.
   - PR mobile: body memuat `Closes #86` + `cc @iamutaki` (Tuan minta di-mention).
   - PR api: link issue #86 via body (`sambasku/mobile#86`).
4. JANGAN merge/deploy — keputusan Tuan.

## Verifikasi akhir (definisi selesai)

- [ ] `npx vitest run src/modules/word-suggestions src/modules/activity src/modules/user` hijau; full suite hijau.
- [ ] Test baru activity-word-time membuktikan kata lama (verifiedAt segar) TIDAK di puncak feed.
- [ ] `npm run typecheck` tanpa error baru yang menyebut modul yang diubah.
- [ ] Mobile: analyze bersih untuk file yang diubah; full `flutter test` hijau.
- [ ] Docs 37 + 19 + 23 updated; PR dibuat dan Tuan di-mention.

## Risiko, tradeoff, open questions

- **Tradeoff waktu feed** (`created_at` murni): kata kontribusi yang diusulkan lama tapi baru disetujui masuk feed pada waktu usulannya (bisa terkubur, tidak nongol di puncak). Ini jujur untuk label "Baru ditambahkan" dan self-healing untuk data staging yang salah; kalau nanti mau "waktu tayang", butuh kolom `published_at` eksplisit (migration) — di luar scope.
- **Perilaku atribusi berubah**: `verified_by` tetap verifikator PERTAMA walau verifikator lain mengedit. Konsisten precedent contribution repo + docs 19 (atribusi verifikator); satu ekspektasi test lama sengaja dibalik (Task 1).
- **Suggestion rows masuk `listRecentVerifications`** menaikkan jumlah item kategori Verifikasi (stats `verifications_done` TIDAK berubah — tetap COUNT `contribution_reviews` saja). Kalau Tuan mau stats ikut menghitung usulan, keputusan terpisah.
- **Out of scope (open question)**: kredit kontributor biasa yang usulannya disetujui (`word_edit_suggestions.userId`, non-self-apply) belum masuk daftar "Kontribusi" profil publik (masih hanya tabel `contributions`). Beranda feed sudah menampilkan mereka sebagai kind `suggestion` ("Mengusulkan perubahan"). Kalau mau paritas di profil, task lanjutan terpisah.
- Bruno/OpenAPI: tidak ada field wire baru (kind `verification` sudah ada di `publicActivityResponseSchema`), tidak perlu sentuh koleksi Bruno.
