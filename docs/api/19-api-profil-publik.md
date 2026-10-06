# API Profil Publik + Atribusi Verifikator

Mengikuti `api-base-stack.md`: Section 3 (struktur folder), 9
(`@hono/zod-openapi` + Scalar), 10 (testing), 11 (versioning `/api/v1/`),
13 (envelope & error), 15 (rate limiting). Sumber produk:
`docs/backlogs/VERIF.md`. Zero migration: data sudah ada di `users`,
`words.verified_by` / `verified_at`, `contributions`,
`contribution_reviews`.

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):
- SUDAH ADA: `users.username` unique, `users.role`, soft delete
  `deleted_at`, `is_active`, `words.verified_by` / `verified_at`,
  `GET /api/v1/words/:id` (controller sudah mengirim `verified_at` ISO
  tetapi Zod schema belum memuatnya), `resolvePublication` (role
  verifikator = `admin | editor | root | reviewer`), error
  `USER_NOT_FOUND` di auth (belum di ERROR_CODES.md).
- Yang BELUM: endpoint profil publik, JOIN username pada detail kata,
  mask `verified_by`/`verified_at` saat `is_verified = false`.

KEPUTUSAN PRODUK (2026-09-21, diperbarui 2026-09-24):
- Identitas URL publik = `username` (unique, case-sensitive, tidak ada alur
  ganti username). Email, phone, password hash, `is_active` tidak
  pernah diekspos.
- Nama tampilan publik = `display_name` (boleh diedit). Nilai awal =
  `username` (migrasi backfill + set saat register/OAuth create).
- Bio publik opsional = `bio` (nullable, edit via `PATCH /users/me`).
- `is_verifier` diturunkan dari role yang sama dengan
  `resolvePublication`: `admin | editor | root | reviewer`. Bukan
  kolom baru, bukan label `administrator`.
- Profil 404 `USER_NOT_FOUND` jika username tidak ada, `deleted_at`
  terisi, atau `is_active = false`. User sistem `anonim` boleh dibuka.
- Atribusi di detail kata: JOIN `users` pada `words.verified_by` tanpa
  filter `deleted_at` (atribusi tidak hilang meski akun dihapus).
- Stats `verifications_done` = COUNT `contribution_reviews` di mana
  `reviewer_id = user` dan `status != 'pending'` (bukan
  `words.verified_by`).
- Username di URL: register `name` boleh spasi. Path di-decode, lookup
  exact match. Client: `Uri.encodeComponent`.
- Modul `modules/user/`: profil publik + `GET`/`PATCH /users/me` +
  avatar. SELECT publik tidak menarik email/phone/hash.
- Avatar publik (`avatar_url`) dan umpan aktivitas (`GET …/activity`)
  sudah ada.
- Konsol admin memakai endpoint ini untuk modal info user
  (`UserInfoModal` / `UserInfoLink`). UI tidak menampilkan User ID.

---

## Pembaruan (gambar publik + aktivitas)

- `avatar_url` (jsDelivr, nullable) di profil publik dan payload login.
- Stats ketiga: `comments_published` (komentar status `published`).
- `GET /api/v1/users/:username/activity` - 20 item terbaru
  (`contribution` | `comment` | `verification` | `vote`), tanpa kursor.
- Pembaruan `vote`: vote user ke word/comment (kata masih published)
  ikut tayang. Copy identik feed beranda: `"lemma" sudah pas` /
  `"lemma" perlu dicek ulang` (arah vote dibaca dari akhiran).
- `POST` / `DELETE /api/v1/users/me/avatar` - multipart, login.
- Gambar kata: `POST /api/v1/images?purpose=word` (GitHub), bukan
  ImageKit. ImageKit tetap untuk laporan bug / bukti verifikator.

---

## Pembaruan (timeline event log, #86)

- Timeline kini membaca `activity_events` (write-through, sama dengan
  feed beranda) lewat
  `activity/infrastructure/activity-event-feed.repository.impl.ts`
  (`listPublicByActor`) - bukan lagi 4 query agregat repo lama.
- Kategori dipetakan dari kind event:
  - `contribution`: `word_created` + `contribution_*` + `suggestion_applied` + `suggestion_created` + `contribution_submitted`
  - `comment`: `comment_created`
  - `verification`: `word_verified` + `suggestion_selfapply`
  - `vote`: `vote_word` + `vote_comment`
- Wording summary: aksi berimbuhan tanpa subjek
  (`Menambahkan foto "lawang"`, `Memverifikasi kata "lawang"`,
  `Usulan perubahan diterima "lawang"`, `Mengusulkan perubahan "lawang"`,
  `Mengusulkan kata baru "lawang"`).
- Usulan ditolak: event usulan disembunyikan dari timeline actor juga
  (hide-on-reject, konsisten feed beranda).
- Cursor mode terfilter kini id event (ULID) - tetap opaque.
- Akun terhapus: event tetap tayang, profil tetap 404 (karya tidak
  hilang bersama akun); visibility dicek read-time.

BRUNO + JSON tambahan:
- `http/users/get-public-activity.bru`, `upload-avatar.bru`, `delete-avatar.bru`
- `http/image/upload-public-image.bru`
- `docs/json/users/get-public-activity.200.json`, `upload-avatar.200.json`
- `docs/json/image/upload-public-image.201.json`, `.503`

---

## Pembaruan (guide kontribusi, 2026-10-03)

- Kolom baru `users.read_contribution_guide_at` (migrasi 0053, nullable).
- `GET /api/v1/users/me` mengirim `has_read_contribution_guide`
  (boolean, derived dari `read_contribution_guide_at`).
- `PATCH /api/v1/users/me` menerima `has_read_contribution_guide: true`
  (hanya true, tidak bisa reset). Set timestamp sekali; panggilan ulang
  diabaikan (idempoten).
- Dipakai mobile: guide swipe sekali di tab Kontribusi; tap "Mengerti"
  memanggil PATCH ini. Dismiss tanpa tombol = tidak persist, guide
  muncul lagi kunjungan berikutnya.
- Bruno: `http/users/mark-contribution-guide-read.bru`.

---

## Prompt

```text
Buatkan modul profil publik (baca-saja) + atribusi verifikator di
detail kata, mengikuti pola modul 4 lapis (Section 3). Zero migration.

LOKASI MODUL BARU: modules/user/

STRUKTUR:
modules/user/
├── domain/
│   ├── entities/public-profile.entity.ts
│   └── repositories/public-user.repository.ts
├── application/use-cases/get-public-profile.use-case.ts
├── infrastructure/public-user.repository.impl.ts
└── presentation/v1/
    ├── user.controller.ts
    ├── user.routes.ts
    └── validators/public-profile.validator.ts

UBAH:
- word/application/utils/resolve-publication.ts: ekstrak isVerifierRole()
- word/domain/entities/word.entity.ts: WordDetail.verifier
- word/infrastructure/word.repository.impl.ts: LEFT JOIN users
- word/presentation/v1/word.controller.ts: mask verified_by/verified_at
- word/presentation/v1/validators/create-word.validator.ts:
  +verified_by object + verified_at (schema belum memuat verified_at)
- app.ts: wiring + mount /api/v1/users
- ERROR_CODES.md: daftarkan USER_NOT_FOUND (sudah dipakai auth)

HELPER:
export function isVerifierRole(role: string): boolean {
  return ['admin', 'editor', 'root', 'reviewer'].includes(role);
}
resolvePublication memakai helper ini (satu sumber).

ENDPOINT:
GET /api/v1/users/:username
- Publik, tanpa auth
- rateLimit 100/menit per IP (tier baca, sama search-misses)
- params: username string trim min 1 max 100 (bukan ULID)
- 200 envelope:
  {
    username, role, is_verifier, joined_at (ISO users.created_at),
    stats: { contributions_approved, verifications_done }
  }
- 404 USER_NOT_FOUND: tidak ada / soft-deleted / is_active false
- Lookup exact match setelah decode path

REPO PublicUserRepository:
- findPublicByUsername(username): Promise<PublicProfile | null>
  SELECT id, username, role, created_at WHERE username = :u
  AND deleted_at IS NULL AND is_active = true.
  JANGAN select email/phone/password_hash/is_active.
- COUNT paralel:
  contributions_approved = COUNT contributions WHERE user_id = id
    AND status IN ('approved','corrected') AND deleted_at IS NULL
  verifications_done = COUNT contribution_reviews WHERE reviewer_id = id
    AND status != 'pending' AND deleted_at IS NULL
- is_verifier dihitung di use case via isVerifierRole(role)

USE CASE:
- null dari repo → NotFoundError('USER_NOT_FOUND', 'User tidak ditemukan')

ATRIBUSI KATA (GET /api/v1/words/:id, backward compatible):
- findDetailById LEFT JOIN users dua kali: verified_by dan created_by
  (tanpa filter deleted_at)
- WordDetail.verifier / creator = { username, role } | null
- Controller:
  is_verified false → verified_by null, verified_at null, self_verified false
  selain itu → verified_by { username, display_name, role }, verified_at ISO | null
  self_verified true hanya jika created_by === verified_by (id)
  created_by selalu { username, display_name, role } | null (JOIN users.created_by).
  Jangan kirim id user.
  Label UI memakai display_name; navigasi profil memakai username.
  Akun soft-deleted (users.deleted_at terisi): username publik
  "Akun tidak ditemukan" (bukan username internal dihapus-…).
  GET profil username itu → 404 USER_NOT_FOUND.

TESTING:
- unit GetPublicProfileUseCase: happy verifier, contributor
  is_verifier false, null → 404
- e2e: 200 anonim, 200 reviewer + stats, 404 username acak
- e2e detail kata: admin publish → verified_by.username terisi +
  self_verified true; unverify → verified_by/at null + self_verified false
  kontributor di-approve orang lain → self_verified false

BRUNO + JSON:
- http/users/get-public-profile.bru
- docs/json/users/get-public-profile.200.json + .404.json
- update docs/json/word/get-word-detail.200.json (+varian) dan
  http/word/get-word-detail.bru
```
