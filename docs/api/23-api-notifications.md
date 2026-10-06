# API Inbox Notifikasi Status Usulan

Mengikuti `api-base-stack.md`: Section 3 (modul 4 lapis), 7 (skema), 9
(OpenAPI), 10 (testing), 13 (envelope), 15 (rate limit), 19 (ID opaque).
Push FCM tetap di `17-api-device-push.md`. Inbox ini jalur in-app.

KEPUTUSAN PRODUK (2026-09-21, diperbarui 2026-09-28):
- Satu baris per `(user_id, type, target_kind, target_id)` unique.
  Keputusan kedua pada usulan yang sama tidak membuat baris baru.
  Komentar baru pada kata yang sama menimpa baris `word_comment`
  (upsert unread). Vote pada kata yang sama menimpa baris `word_vote`
  terpisah (boleh berdampingan dengan `word_comment`).
- Tulis inbox untuk approve, reject, dan correct yang publish. Koreksi
  tanpa publish (status tetap pending) tidak menulis inbox.
- Komentar baru pada kosakata: inbox + push ke peserta diskusi
  (komentator sebelumnya + pemilik kata), kecuali aktor / Anonim /
  Pengimpor Data CSV.
- Vote (upvote/downvote) pada konten terkait kata milik user: inbox +
  push ke **pemilik kata** saja. Unvote / self-vote / Anonim / CSV /
  `discussion*` tidak menulis. Target: `word`, `meaning`,
  `example`, `pronunciation`, `word_image`, `comment`.
- User Anonim dan Pengimpor Data CSV tidak punya inbox / push.
- Insert best-effort: gagal tulis inbox tidak menggagalkan review,
  create komentar, maupun toggle vote (preseden FCM).
- Push FCM untuk approve **dan** reject kontribusi (correct tetap tanpa
  push). Push komentar diskusi + vote kosakata juga FCM, cooldown Skip
  terpisah per channel.
- Approve/reject pengajuan verifikator: inbox + FCM (tanpa cooldown;
  satu keputusan per pengajuan). `data` FCM menyertakan `title`/`body`
  agar local notif foreground mobile tetap bisa tampil.
- **Cooldown push (mode Skip):** push pertama per channel ke user
  langsung; push berikutnya digeser sampai jeda menit berakhir. Inbox
  **tidak** di-throttle. Jendela dari push terakhir yang dikirim
  (`notification_push_cooldowns`).
- Durasi cooldown di `app_settings` (bisa diubah Console tanpa redeploy):
  - `notification.review_approve_push_cooldown_minutes` (default `360`)
  - `notification.review_reject_push_cooldown_minutes` (default `360`)
  - `notification.word_comment_push_cooldown_minutes` (default `3`)
  - `notification.word_vote_push_cooldown_minutes` (default `3`)
  - nilai `0` = cooldown mati (selalu kirim push)
- CTA tap (#19): kolom opsional `action_kind` + `action_value`
  (`word` | `contribution` | `suggestion` | `discussion` | `url`).
  Campaign menyalin dari `deep_link_*`. Mobile: in-app via go_router;
  `url` hanya `https://` via browser eksternal.
- Tidak diaudit (baris user-state).

---

## Endpoint

Middleware: `authenticate` (semua role) + rate 100/menit per `user_id`.

### 1. GET /api/v1/notifications

Query: `limit` 1-100 (default 20), `cursor` (id item terakhir), `unread`
opsional `true` (hanya belum dibaca).

Urutan: `id DESC`. Cursor: `id < cursor`.

Item:

```json
{
  "id": "01H...",
  "type": "contribution_approved",
  "title": "Usulan disetujui",
  "body": "Usulan kata Anda telah disetujui dan dipublikasikan.",
  "image_url": null,
  "target_kind": "contribution",
  "target_id": "01H...",
  "action_kind": null,
  "action_value": null,
  "read_at": null,
  "created_at": "2026-09-21T00:00:00.000Z"
}
```

`image_url`: opsional (null untuk notifikasi transactional). Campaign
bisa mengisi HTTPS URL gambar untuk thumbnail inbox / rich push.
`type`: `contribution_approved` | `contribution_rejected` |
`contribution_corrected` | `suggestion_approved` |
`suggestion_rejected` | `suggestion_corrected` | `word_taken_down` |
`contribution_paused` | `contribution_resumed` |
`discussion_pending_review` | `discussion_approved` | `discussion_rejected` |
`discussion_taken_down` | `discussion_reply` | `word_comment` |
`word_vote` | `campaign` | `verifier_application_approved` |
`verifier_application_rejected`.

`target_kind`: `contribution` | `suggestion` | `word` |
`discussion` | `campaign` | `verifier_application`.

Tap mobile (prioritas `action_*`, fallback `target_*`):
- `word` / `word_vote` / `word_comment` → `/words/:id?focus=activity`
- `discussion` → detail diskusi
- `url` → browser eksternal (https only)
- `campaign` tanpa CTA → tetap inbox
- `verifier_application` / `verifier_application_*` → `/verifier-application`
- selain itu → detail Kontribusi Saya

401 tanpa token. Meta cursor standar.

### 2. GET /api/v1/notifications/unread-count

```json
{ "success": true, "data": { "unread_count": 2 } }
```

### 3. POST /api/v1/notifications/:id/read

Idempotent. Bukan milik pemohon atau tidak ada → 404
`NOTIFICATION_NOT_FOUND` (bukan 403).

```json
{ "success": true, "data": { "id": "01H...", "already_read": false } }
```

### 4. POST /api/v1/notifications/read-all

```json
{ "success": true, "data": { "updated": 2 } }
```

---

## Kapan baris ditulis

| Keputusan | type | Push FCM |
| --------- | ---- | -------- |
| Approve kontribusi | `contribution_approved` | ya (cooldown Skip) |
| Reject kontribusi | `contribution_rejected` | ya (cooldown Skip) |
| Correct + publish kontribusi | `contribution_corrected` | tidak |
| Approve usul perubahan | `suggestion_approved` | tidak |
| Reject usul perubahan | `suggestion_rejected` | tidak |
| Correct + publish usul perubahan | `suggestion_corrected` | tidak |
| Komentar baru di kosakata | `word_comment` | ya (cooldown Skip, default 3 menit) |
| Diskusi baru menunggu tinjauan | `discussion_pending_review` | ya (tanpa cooldown) |
| Approve diskusi | `discussion_approved` | tidak (inbox saja) |
| Reject diskusi | `discussion_rejected` | tidak (inbox saja) |
| Takedown diskusi | `discussion_taken_down` | tidak (inbox saja) |
| Balasan baru di Ruang Diskusi | `discussion_reply` | ya (cooldown Skip, setting sama, channel terpisah) |
| Vote pada konten terkait kata | `word_vote` | ya (cooldown Skip, default 3 menit) |
| Approve pengajuan verifikator | `verifier_application_approved` | ya (tanpa cooldown) |
| Reject pengajuan verifikator | `verifier_application_rejected` | ya (tanpa cooldown) |

Penerima `verifier_application_*`: pemohon (`verifier_applications.user_id`).
Salinan approve: "Selamat, Anda jadi verifikator" + pengingat masuk ulang.
Reject: judul sama; body menyertakan cuplikan catatan admin.
Tap mobile → `/verifier-application`.

Penerima `discussion_pending_review`: user aktif role
`reviewer|admin|root|editor`, kecuali penulis diskusi. Dipicu di
`CreateDiscussionUseCase` (inbox + FCM, tanpa cooldown). Salinan:
title "Diskusi menunggu tinjauan"; body cuplikan deskripsi.
Tap mobile verifikator → `/review/discussions/:id`.

Penerima `word_comment`: komentator sebelumnya pada kata + pemilik
(`words.created_by`), kecuali penulis komentar baru, Anonim, dan
Pengimpor Data CSV. Satu baris per `(user, type=word_comment, word)`.

Penerima `discussion_reply`: pembalas sebelumnya pada thread + pemilik
diskusi, kecuali penulis balasan baru, Anonim, dan Pengimpor Data CSV.
Salinan: “{nama} juga membalas di "{cuplikan topik}": {cuplikan balasan}.”
Satu baris per `(user, type=discussion_reply, discussion)` (upsert unread).

Penerima `word_vote`: pemilik kata saja. Salinan: “{nama} memberi
upvote/downvote pada "{lemma}".” Satu baris per
`(user, type=word_vote, word)` - vote berikutnya upsert unread.

---

## Modul

- `RecordInboxNotificationUseCase`, `ListMyNotificationsUseCase`,
  `GetUnreadNotificationCountUseCase`, `MarkNotificationReadUseCase`,
  `MarkAllNotificationsReadUseCase`
- `ReviewPushCooldownGate` + `WordCommentPushCooldownGate` +
  `DiscussionReplyPushCooldownGate` + `WordVotePushCooldownGate` +
  `NotificationPushCooldownRepository`
  (gate push review di `ReviewContributionUseCase`; komentar di
  `CreateCommentUseCase`; balasan Ruang Diskusi di
  `CreateDiscussionReplyUseCase`; vote di `ToggleVoteUseCase`)
- `NotificationRepository`
- Mount: `createNotificationRoutes` di `/api/v1/notifications`

Migrasi: `notifications` + `0025_review-push-cooldown.sql` +
`0029_word-comment-push-cooldown.sql` +
`0031_notification-vote-action.sql` (unique + type, `action_*`,
seed cooldown vote).
