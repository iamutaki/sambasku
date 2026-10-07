# 37 - API Feed lintas aktivitas (beranda)

Feed publik **Aktivitas terbaru** untuk beranda mobile/web. Bukan antrean
admin Analitik. Tanpa realtime (HTTP + pull-to-refresh saja).

## Ringkasan

`GET /api/v1/activity?limit=20` - publik, tanpa auth.

- Rate limit: 100/menit per IP.
- Cursor opaque (`created_at` + `id`) untuk halaman berikutnya; `limit` 1-50
  (default 20).
- Sumber: tabel `activity_events` (write-through event log, #86). Setiap aksi
  publik tercatat **di momen kejadian**; feed membaca satu tabel, sort
  `(occurred_at, id)` desc, tanpa agregasi lintas sumber.
- Query `exclude_self` opsional untuk menyembunyikan karya sendiri saat login
  (lihat bagiannya di bawah). Tidak mengubah perilaku default.
- Tidak mengekspos email, status moderasi privat, atau kontribusi pending.

## Kind

| Kind (wire) | Kind event | Sumber event | Actor | Copy body (contoh) |
|------|------|--------|-------|--------------------|
| `word` | `word_created` | kata jadi published (approve usul / self-apply) | pembuat kata | `"{lemma}" · sense`; subtitle "Baru ditambahkan" |
| `comment` | `comment_created` | komentar published | penulis | isi komentar |
| `vote` | `vote_word` / `vote_comment` | vote +/- | pemilih (tanpa email) | `"{lemma}" sudah pas` / `"{lemma}" perlu dicek ulang` |
| `discussion` | `discussion_created` | diskusi published | pembuat | isi atau "Membuka ruang diskusi" |
| `word_image` / `word_audio` / `pronunciation` / `example` | `contribution_image` / `contribution_audio` / `contribution_pron` / `contribution_example` | kontribusi disetujui | kontributor | `Menambah foto · "{lemma}"` (juga suara/cara baca/contoh) |
| `search_miss` | `search_miss` | miss dibuat visible | `null` → UI "Seseorang" | `Mencari "…" - belum ada di kamus.` (CTA "Bantu isi" dari klien) |
| `welcome` | `user_joined` | email terverifikasi | user baru | `Bergabung di SambasKu` |
| `card_share` | `card_shared` | share kartu (dedupe 24 jam) | yang membagikan | `Membagikan kartu · "{lemma}"` |
| `suggestion` | `suggestion_created` / `suggestion_applied` / `suggestion_selfapply` | usulan dibuat / usulan diterima / verifikator lengkapi kata | pengusul / pengusul / verifikator | `Mengusulkan perubahan · "{lemma}"` / `Mengusulkan perubahan · "{lemma}"` / `Melengkapi kata · "{lemma}"` |
| `contribution` | `contribution_submitted` | "Usul kata baru" dikirim (pending review) | pengusul | `Mengusulkan kata baru · "{lemma}"` |
| `vote` (subtitle "Verifikasi") | `word_verified` | verifikator verifikasi kata (termasuk approve usul kata baru) | verifikator | `Memverifikasi kata · "{lemma}"` |
| `announcement` | `announcement` | admin buat/edit pengumuman (#102) | admin (root/admin) | `Pengumuman` (isi di field `announcement`) |

`word.created` (kontributor membuat) dan `word.verified` (verifikator
memverifikasi) adalah dua event terpisah - tidak pernah digabung satu baris
(#85). Cap-per-kind lama dihapus: feed = urutan murni event.

Lemma di body selalu dalam tanda kutip ganda (sama dengan `search_miss`); klien boleh menebalkan bagian berkutip, kecuali `comment`/`discussion` (teks bebas user).

## Payload beku (#94)

Copy body event vote disimpan **beku** di kolom `activity_events.payload` pada momen kejadian (`"{lemma}" sudah pas` / `"{lemma}" perlu dicek ulang` — arah dari nilai vote final). Satu sumber kebenaran: feed beranda DAN timeline profil membaca `payload` ini; flip arah vote menimpa payload lewat dedupe key sama (state terakhir, bukan riwayat). Event lama tanpa payload → fallback `bodyFor()` read-time (vote lama: live `votes`, bisa kosong). Backfill: `pnpm db:backfill-activity` section 9 (idempoten, hanya `payload IS NULL`).

Laporan kata (`word_reports`) sengaja **tidak** masuk feed publik.

## Feed sehat dan aman

- Semua baris yang menyebut kata (komentar, vote, kontribusi, share, usulan)
  hanya tampil bila katanya published, tidak dihapus, dan **tidak** berlabel
  `kasar`, `tabu`, `seksual`, atau `diskriminatif`.
- `search_miss` disembunyikan bila term sama dengan lemma berlabel di atas,
  atau kena blocklist komentar.
- Isi `comment` dan `discussion` disensor ulang dengan blocklist saat dibaca
  (menutup data lama dan kata blocklist yang baru ditambah). Diskusi baru juga
  disaring saat dibuat; isi yang hilang lebih dari separuh ditolak.
- `card_share` dan `suggestion` hanya aksi + lemma. Teks bebas pengusul
  (definisi, catatan, alasan) tidak pernah masuk feed.
- Usulan yang ditolak: event `suggestion_created` / `contribution_submitted`
  disembunyikan dari feed saat reject (hide, bukan delete - sejarah tetap
  tercatat untuk audit dan bisa dimunculkan lagi).
- Waktu `suggestion`: `created_at` bila tayang dulu (baseline), selain itu
  `reviewed_at`.

## Pengumuman admin (#102)

`POST/GET/PATCH/DELETE /api/v1/admin/announcements` (role root/admin). Tabel
`announcements` + write-through event kind `announcement` payload beku
`{title, body, actionUrl?, actionLabel?, expiresAt?}` (pola #94), dedupe key
`announcement:{id}`; edit = re-publish copy, delete = soft delete + hide event
(pola #56). `expires_at` opsional, disaring read-time: kadaluarsa tetap tayang
dengan `announcement.expired=true` (feed tidak bergeser). `action_url` wajib
https + whitelist host: `sambasku.com`, `www.sambasku.com`,
`sambasku-staging.iamutaki.com`, `sambasku.iamutaki.com`, `play.google.com`.
List admin: keyset cursor ULID (`before`), tanpa offset. v1: feed saja, tanpa
push notification.

## Catat share kartu

`POST /api/v1/words/:id/card-shares` - login (semua role), tanpa body.

- Dipanggil app setelah share sheet **tidak dibatalkan**
  (`ShareResultStatus.dismissed` diabaikan; `unavailable` dihitung sukses).
  Simpan ke galeri tidak dicatat.
- Dedupe: satu catatan per user+kata per 24 jam.
- Rate limit: 30/jam per user.

| Status | Arti |
|--------|------|
| 201 | `{ "success": true, "data": { "recorded": true } }` |
| 200 | Sudah tercatat 24 jam terakhir, `recorded: false` |
| 401 | Belum login |
| 404 `WORD_NOT_FOUND` | Kata tidak ada, dihapus, atau belum published |

## Item wire

```json
{
  "id": "comment:01…",
  "kind": "comment",
  "created_at": "2026-09-28T12:00:00.000Z",
  "actor": {
    "username": "budi",
    "display_name": "Budi",
    "avatar_url": "https://…"
  },
  "body": "teks ringkas",
  "subtitle": "lading",
  "target": { "type": "word", "id": "01…" }
}
```

- `id` stabil = `{kind}:{entityId}` (kontribusi memakai id baris `contributions`).
- `actor` null hanya untuk `search_miss`.
- `target.type` = `word` | `discussion` | `search_miss` | entity vote lain.

## Response

```json
{
  "success": true,
  "data": [ /* ActivityItem[] */ ],
  "meta": { "limit": 20, "next_cursor": "eyJ…", "has_more": true }
}
```

`next_cursor` opaque (`created_at` + `id`); `null` kalau habis. Kirim sebagai
`?cursor=` untuk halaman berikutnya.

## Menyembunyikan karya sendiri (`exclude_self`)

`GET /api/v1/activity?limit=20&exclude_self=true`

Feed beranda mobile memakai ini supaya activity milik user yang sedang login
tidak muncul di beranda. Karya sendiri tetap bisa dilihat lewat Kontribusi Saya,
Komentar Saya, Nilai Saya, dan tab Aktivitas.

- **Auth opsional, tidak pernah 401.** Tanpa `Authorization` → tamu. Dengan
  Bearer valid → `exclude_self` berlaku. Dengan Bearer rusak/kedaluarsa → tetap
  tamu (soft auth). Token basi hanya berarti "tampilkan feed lengkap", bukan
  error: route publik yang 401 akan membuat Home gagal total padahal feed publiknya
  masih bisa dibaca.
- Tanpa token sah, flag **diabaikan** dan feed tetap publik penuh. Bukan gate,
  cuma preferensi tampilan — tidak ada 400.
- Penyaringan terjadi **di SQL, sebelum cap 4 per jenis**. Kalau ditunda sampai
  sesudah query, 4 baris milik sendiri tetap memakan 4 slot jenis itu dan jenisnya
  hilang dari halaman; baris yang terbuang tidak bisa di-backfill karena `limit`
  sudah terpakai di query.
- Berlaku untuk semua jenis: `comment`, `vote`, `discussion`, `word`,
  `word_image`/`word_audio`/`pronunciation`/`example`, `card_share`, `suggestion`,
  `welcome`.
- `vote` disaring dua lapis: pelaku (`votes.user_id`) **dan target**. Vote
  orang lain atas kata milik sendiri disembunyikan juga - feed ini soal "karya
  orang lain", sedangkan vote di kata saya bukan bagian dari itu. Target dicek
  sampai ke `words.created_by` untuk semua jenis target yang menyebut kata
  (`word`, `comment`, `meaning`, `example`, `pronunciation`, `word_image`,
  `word_audio`); `discussion`/`discussion_reply` tidak menyebut kata jadi tidak
  tersentuh.
- `search_miss` disaring lewat tabel `search_miss_searchers`: miss yang pernah
  dicari viewer sendiri disembunyikan dari berandanya. Atribusinya **per-viewer**,
  bukan global - user lain tetap melihat miss yang sama, dan tanpa flag miss
  tetap tampil untuk semua. Baris searcher hanya tercatat kalau pencarian
  dilakukan dengan Bearer sah (`GET /words/search` pakai soft auth).
- Kata impor sistem (`words.created_by` NULL) tetap tampil. `NULL <> 'x'` di SQL
  adalah NULL, bukan true, jadi penyaringan harus menjaga NULL.
- Response jadi berbeda per identitas → header `Vary: Authorization` dikirim.

## Bruno / contoh

- `http/activity/get-activity.bru` (tamu)
- `http/activity/get-activity-exclude-self.bru` (login + flag)
- `http/activity/get-activity-bad-token.bru` (Bearer tidak sah → tetap 200)
- `http/activity/record-card-share.bru`
- `docs/json/activity/get-activity.200.json`

## Catatan

- `GET /words/latest` tetap ada (vote deck, dll.); beranda memakai endpoint ini.
- Realtime (Ably/dll.) di luar scope dokumen ini.
