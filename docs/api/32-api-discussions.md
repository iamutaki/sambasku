# API Ruang Diskusi (Discussions)

Mengikuti `api-base-stack.md`: Section 3 (modul 4 lapis), 9 (OpenAPI),
11 (`/api/v1/`), 13 (envelope & cursor), 15 (rate limit), 21 (audit),
22 (approval gate / pre-moderation).

Modul: `api/src/modules/discussion/`.

KEPUTUSAN PRODUK:
- User login boleh **membuka thread** (deskripsi wajib, tautan https
  opsional, ≤4 gambar opsional, **audio opsional** via
  `POST /discussions/:id/audio` setelah create) → status awal
  `pending_review` (belum tayang publik).
- **Pre-moderation:** verifikator (`admin` | `root` | `reviewer` |
  `editor`) approve / reject / takedown. Saat create: blast inbox +
  FCM tipe `discussion_pending_review` ke role tersebut (kecuali
  penulis). Gambar thread staging tidak tayang publik sebelum approve.
  **Audio opening** diunggah ke GitHub `sambasku/audios` seperti balasan;
  `audio_url` di-redact pada wire publik sampai `published`. Reject /
  takedown menghapus file audio best-effort.
- Approve mempromosikan gambar staging ImageKit → GitHub publik
  (`sambasku/images` via jsDelivr); URL ImageKit dihapus best-effort.
- Feed publik hanya status `published`; detail non-published hanya
  pemilik (atau admin).
- Balasan: login, hanya pada diskusi `published`; blocklist sensor seperti
  komentar; post-moderation (takedown / hapus penulis). Setelah balasan:
  inbox + push ke pemilik thread + pembalas sebelumnya (kecuali aktor /
  user sistem), copy dinamis; push cooldown Skip memakai setting
  `notification.word_comment_push_cooldown_minutes` (channel
  `discussion_reply` terpisah dari komentar kosakata).
- **Balasan suara:** multipart ke
  `POST /discussions/:id/replies/audio` (file ≤5 MB, MIME sama pelafalan
  kata); caption teks opsional; **publish langsung** (post-moderation,
  sama balasan teks). Storage GitHub `sambasku/audios` path
  `assets/audio/discussions/<discussionId>/<ulid>.<ext>`. Voice-only
  notify snippet: "mengirim rekaman suara". Hapus balasan → best-effort
  hapus file GitHub.
- Badge **Verifikator** di balasan = role `admin|editor|reviewer|root`
  (bukan kolom DB). Pin balasan oleh admin.
- Vote komunitas pada balasan (`target_type: discussion_reply`,
  modul `08-api-upvote-downvote.md`): user login upvote/downvote;
  detail menyertakan `upvotes`/`downvotes`; urutan reply =
  `created_at` naik, seri `id` naik. Sematan tidak mengubah posisi.
- Vote komunitas pada **pertanyaan** (`target_type: discussion`):
  **upvote-only** (downvote → 400); feed `?sort=popular` urut upvote.
- Web publik read-only (tampil skor); ajukan/balas/vote di aplikasi mobile.

Status diskusi: `pending_review` | `published` | `rejected` | `taken_down`.
Status reply: `published` | `taken_down` | `deleted_by_author`.

---

## Privasi gambar (ImageKit → GitHub)

| Fase | Storage | Siapa melihat `url` / `public_url` |
|---|---|---|
| Submit | ImageKit folder `/discussions` | Owner + admin: `url` + `provider_file_id`; `public_url = null` |
| Approve | Upload ke GitHub path discussion; hapus ImageKit;
  `content_warnings` per indeks di-set verifikator | Publik:
  `images[{ public_url, content_warnings }]`. Staging `url` tidak diekspos |
| Reject / takedown | Hapus ImageKit (reject); takedown tarik dari feed | Tidak tayang di GET publik |

Client publik (`GET /discussions`, detail published) menerima
`{ public_url, content_warnings }`. Flag `kekerasan` → blur sampai
reveal di mobile/web (parity foto kata). OG/share lewati foto ber-flag.

**Approve multipart (admin):** `file_0..file_{N-1}` (JPEG/PNG tersensor
atau kosong = rehost staging) + field teks `content_warnings` =
JSON array panjang N, mis. `[[],["kekerasan"]]`. Tanpa sensor/flag:
JSON `{}` tetap valid.

**Audio balasan:** upload ke `sambasku/audios` lewat API (bukan staging
ImageKit). Tayang segera setelah create (post-moderation). R2 privat
bisa menyusul untuk media thread lain.

---

## Endpoint publik

### GET /api/v1/discussions

Feed published, cursor pagination (`limit` 1..50 default 20, `cursor`).
Query `sort`: `latest` (default, id desc) | `popular` (upvote desc,
lalu id desc; cursor popular = base64url `upvotes:id`).

Item: `id`, `user_id`, `username`, `display_name`, `avatar_url`,
`body`,
`images[{public_url, content_warnings}]`, `status: "published"`,
`pinned_reply_id`, `upvotes`, `created_at`.

### GET /api/v1/discussions/:id

- Published → publik + `replies[]` (`avatar_url`, `is_verifier`, `is_pinned`,
  `upvotes`, `downvotes`, `audio_url` / `audio_mime_type` /
  `audio_duration_ms`, body/audio di-redact jika non-published).
  Urutan: `created_at` naik, seri `id` naik. Sematan tidak mengubah posisi.
- Pending / rejected / taken_down → hanya pemilik (auth opsional).
- Lainnya → 404 `DISCUSSION_NOT_FOUND`.

---

## Endpoint user (login)

| Method | Path | Ringkas |
|---|---|---|
| GET | `/discussions/upload-token?folder=/discussions` | Kredensial direct-upload ImageKit |
| POST | `/discussions` | Buat pending_review (body dan/atau images) |
| POST | `/discussions/:id/audio` | Lampirkan audio opening (owner, pending_review) |
| GET | `/discussions/my` | Riwayat milik user (+ filter status) |
| POST | `/discussions/:id/replies` | Balas teks (help harus published) → 201 |
| POST | `/discussions/:id/replies/audio` | Balas suara multipart (`audio` wajib; `body`/`duration_ms` opsional) → 201 |
| DELETE | `/discussions/replies/:id` | Hapus balasan sendiri → `deleted_by_author` |

Rate limit: upload-token & submit & reply per user/IP; reply audio
30/menit per user (lihat routes). Env storage sama pelafalan kata
(`PRONUNCIACION_*`); tanpa token → 503 `PRONUNCIACION_UPLOAD_UNAVAILABLE`.

---

## Endpoint admin

Prefix: `/api/v1/admin/discussions`  
Role: `admin` | `root` | `reviewer` | `editor`.

| Method | Path | Ringkas |
|---|---|---|
| GET | `/` | Antrean (+ filter status) |
| GET | `/:id` | Detail admin (URL staging ImageKit jika ada) |
| POST | `/:id/approve` | JSON kosong atau multipart `file` / `file_0…` (sensor) → published + promote GitHub |
| POST | `/:id/reject` | `{ note }` wajib; hapus ImageKit |
| POST | `/:id/takedown` | Dari published |
| POST | `/:id/pin-reply` | `{ reply_id }` |
| POST | `/replies/:id/takedown` | Takedown balasan |

---

## Error codes

Lihat `api/ERROR_CODES.md`:
`DISCUSSION_NOT_FOUND`, `DISCUSSION_REPLY_NOT_FOUND`,
`DISCUSSION_NOT_PUBLISHED` (409 balas sebelum tayang),
`DISCUSSION_NOT_PENDING` (409 lampir audio opening selain pending_review).

---

## Referensi

- Skema: `discussions`, `discussion_replies` (migrasi 0012;
  audio balasan: 0037; audio opening: 0039)
- Bruno: `http/discussion/`
- Backlog: `docs/backlogs/done/DISCUSSION.md`
- Web publik: `/ruang-diskusi`, `/ruang-diskusi/:id`
