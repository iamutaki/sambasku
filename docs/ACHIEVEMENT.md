# ACHIEVEMENT - Sistem lencana dengan kriteria terkonfigurasi

Dokumen desain (warm-up) sistem achievement. Meneruskan
[`GAMIFIKASI_CONCEPT.md`](./GAMIFIKASI_CONCEPT.md) ("achievement memiliki
badge, ditampilkan di profil user jika target sudah tercapai") dan berjalan
berdampingan dengan [`LEADERBOARD_WEEKLY_PLAN.md`](./LEADERBOARD_WEEKLY_PLAN.md)
(infrastruktur serupa: hitung dari baris yang ada, publikasikan hasil, bukan
hitung per-request).

Achievement pertama yang diminta: **kohort pendaftaran**, user yang
terdaftar antara tanggal X sampai Y menerima lencana (contoh kasus:
"Perintis", anggota awal). Sistem harus menerima kriteria sejenis terus
bertambah: komentar, kontribusi kata, vote, diskusi, dan lainnya, tanpa
deploy ulang tiap kriteria baru.

---

## 1. Prinsip desain

1. **Kriteria adalah data, bukan kode.** Katalog achievement hidup di tabel,
   dibuat lewat console admin. Menambah achievement baru = tambah baris,
   bukan PR. Yang ada di kode hanya **registry sumber** (daftar aspek yang
   bisa dinilai, lihat Section 3) yang tumbuh perlahan dan sadar.
2. **Skor selalu dihitung ulang dari baris yang ada** (kontrak leaderboard
   juga begitu). Tidak ada tabel event baru, tidak ada counter inkremental.
   Yang disimpan hanyalah **fakta penganugerahan** (award), karena itu
   memang state: jejak permanen "user X mendapat lencana Y pada saat Z".
3. **Satu achievement = satu sumber kriteria.** Aturan gabungan kompleks
   ("10 kata DAN 50 komentar") tidak masuk grammar V1; kebutuhan itu
   dijawab dengan memberi dua achievement. Grammar kecil = validasi
   ketat = tidak ada mesin rules-engine yang tumbuh liar.
4. **Penganugerahan idempotent.** `UNIQUE (achievement_id, user_id)`;
   scan boleh diulang kapan pun tanpa dobel. Revokasi = soft delete +
   audit, award lama tetap tercatat.
5. **Evaluasi offline (cron), bukan on-write hook.** Tidak menyentuh use
   case modul lain (kontribusi, komentar, vote) saat mereka jalan. Lag
   beberapa jam antara "syarat terpenuhi" dan "lencana muncul" acceptable;
   desentralisasi hook = sumber bug yang jauh lebih mahal.

---

## 2. Model data

Dua tabel baru, konvensi sama (ULID `varchar(26)`, soft delete, timestamp).

```text
achievements                          # katalog (dikelola admin via console)
  id           varchar(26) PK
  code         text NOT NULL UNIQUE   # slug stabil: 'perintis-2026'
  title        text NOT NULL          # copy Indonesia: "Perintis 2026"
  description  text NOT NULL
  category     text NOT NULL          # 'kohort' | 'kontribusi' | 'komunitas' | 'kualitas' | 'momen'
  badge_url    text NULL              # asset via pola public-image (jsDelivr)
  criteria     json NOT NULL          # grammar Section 3, divalidasi Zod
  family       text NULL              # grup tier: 'kata-disetujui'
  level        integer NULL           # 1/2/3 untuk tier bronze/perak/emas
  is_active    integer NOT NULL DEFAULT 1   # 0 = berhenti diajukan, award lama tetap
  created_at / updated_at / deleted_at / deleted_by

user_achievements                     # fakta penganugerahan
  id              varchar(26) PK
  achievement_id  varchar(26) NOT NULL FK achievements.id
  user_id         varchar(26) NOT NULL FK users.id
  awarded_at      timestamp NOT NULL
  granted_via     text NOT NULL       # 'scan' | 'admin'
  context         json NULL           -- snapshot saat award, mis. {"registered_at": "..."}
  created_at / deleted_at / deleted_by
  UNIQUE (achievement_id, user_id)
```

Catatan kolom:

- `family` + `level` mengizinkan tier (10/50/100 kata) tanpa struktur khusus;
  profil menampilkan level tertinggi per family. Tanpa tier: keduanya NULL.
- `granted_via` membedakan hasil mesin scan vs pemberian manual admin
  (lencana "juara event" tidak punya kriteria komputabel, lihat source
  `manual`).
- Tidak ada kolom `progress`. Progres (8/10) kalau nanti ditampilkan,
  dihitung ulang dari agregat yang sama saat dibaca.

Index:

```sql
CREATE UNIQUE INDEX user_achievements_unique ON user_achievements (achievement_id, user_id);
CREATE INDEX user_achievements_user ON user_achievements (user_id);
```

`docs/dbdiagram.dbml` diupdate di PR yang sama.

---

## 3. Grammar kriteria

`criteria` adalah objek JSON kecil yang divalidasi Zod terhadap registry.
Bentuk umum:

```json
{
  "source": "registration",
  "threshold": null,
  "window": { "from": "2026-01-01T00:00:00+07:00", "to": "2026-12-31T00:00:00+07:00" }
}
```

| Bagian | Arti |
| --- | --- |
| `source` | aspek yang dinilai, wajib, harus terdaftar di registry |
| `threshold` | jumlah minimum (integer >= 1). `null`/absen = tanpa ambang (kohort) |
| `window` | batas waktu `[from, to)` format ISO 8601 offset WIB. Absen = sepanjang waktu |
| `filters` | modifier opsional per source, mis. `{"entity_type": "word"}` |

Semantik: **user memenuhi kriteria = agregat source-nya (dalam window,
dengan filter) >= threshold**, atau untuk kohort tanpa threshold, user
masuk himpunan window. Zona waktu window: WIB (UTC+7), konsisten dengan
siklus leaderboard.

### Registry sumber (V1)

| `source` | Aspek | Basis data | Catatan anti-gaming |
| --- | --- | --- | --- |
| `registration` | Terdaftar dalam window | `users.created_at` | Excluded: `anonim`, `is_active = false`, soft-deleted |
| `manual` | Pemberian admin, tanpa komputasi | tidak ada | Tidak pernah discan; hanya grant manual |
| `contributions_approved` | Kontribusi disetujui (gabungan semua jenis) | `contributions` `status in ('approved','corrected')`, `deleted_at` null | Hanya yang lolos gerbang verifikasi |
| `contributions_approved` + filter `entity_type` | Varian per jenis: `word`, `pronunciation`, `word_image`, `example`, `word_edit_suggestion` | sama, plus `entity_type = ?` | Mengisi kelengkapan (sinonim/contoh/audio) jadi jalur poin tambahan sesuai konsep GAMIFIKASI |
| `verifications_done` | Keputusan review dilakukan reviewer | `contribution_reviews` per `reviewer_id`, `status != 'pending'` | Maksimal satu per baris review (kontrak 31) |
| `comments_published` | Komentar tayang | `comments` `status = 'published'` | Takedown/soft-delete keluar dari hitungan |
| `discussions_created` | Ruang diskusi disetujui | `discussions` `user_id`, status approved | Status `pending_review` tidak hitung |
| `discussion_replies_published` | Membalas diskusi | `discussion_replies` `status = 'published'` | |
| `votes_received` | Karyanya menerima vote | `votes` pada entitas milik user yang statusnya published/approved | **Vote yang diberikan tidak pernah jadi sumber** (anti-brigading, sesuai anti-pola GAMIFIKASI); hanya vote diterima atas karya yang lolos moderasi |

### Sumber menyusul (belum V1, daftarkan saat fiturnya hidup)

| `source` | Menunggu apa |
| --- | --- |
| `streak_days` | Fitur streak (GAMIFIKASI CONCEPT, belum dibangun) |
| `leaderboard_top` | Peringkat mingguan (tabel `leaderboard_week_entries` dari plan leaderboard) |
| `search_miss_resolved` | Kontribusi dari search-miss yang menghasilkan kata tayang |
| `bug_reports_accepted` | Laporan masuk yang ditindak admin |

Menambah source = tambah satu handler agregat di registry + satu baris
tabel di dokumen ini. Menambah achievement dari source yang sudah ada =
murni operasi data di console.

Sumber yang tidak akan ditambahkan: vote diberikan, login harian,
membuka aplikasi (vanity, mudah digaming, bertentangan dengan semangat
"aksi nyata" di GAMIFIKASI_CONCEPT).

---

## 4. Mesin evaluasi

### 4.1 Scan berkala via cron yang sudah ada

Sama seperti leaderboard: hook ke handler `scheduled` (`* * * * *`) dengan
export baru di `app.ts`:

```text
runDueAchievementScan(): Promise<{ scanned: number; awarded: number }>
```

Due-check dari `app_settings` (tabel sudah ada): kunci
`achievements_last_scan_at`; scan berjalan tiap 6 jam, idempotent,
self-healing. Scan juga bisa dipicu manual lewat endpoint admin (backfill).

### 4.2 Satu putaran scan

Per achievement aktif (non-`manual`), satu statement SQL anti-join yang
mengembalikan user yang memenuhi kriteria tetapi belum punya award:

```sql
-- contoh source registration, window X -> Y
SELECT u.id, u.created_at
FROM users u
WHERE u.created_at >= :from AND u.created_at < :to
  AND u.deleted_at IS NULL AND u.is_active = 1
  AND u.username != 'anonim'
  AND NOT EXISTS (
    SELECT 1 FROM user_achievements ua
    WHERE ua.achievement_id = :id AND ua.user_id = u.id AND ua.deleted_at IS NULL
  );

-- contoh source contributions_approved, threshold N
SELECT c.user_id, COUNT(*) AS n
FROM contributions c
WHERE c.status IN ('approved','corrected') AND c.deleted_at IS NULL
  AND (:from IS NULL OR c.updated_at >= :from) AND (:to IS NULL OR c.updated_at < :to)
GROUP BY c.user_id
HAVING COUNT(*) >= :threshold;
```

(lapisan anti-join user valid + belum-award disatukan di query akhir;
bentuk di atas untuk kejelasan.)

Eksekusi mengikuti anggaran subrequest Section 24 base-stack:

```text
1. db.batch(seluruh SELECT agregat achievement aktif)   → 1 subrequest
2. db.batch(INSERT user_achievements baru
            + INSERT baris notifications per award)     → 1 subrequest
3. audit_logs satu baris ringkasan scan                 → dalam batch yang sama
Total ~2-3 subrequest per putaran, berapa pun jumlah achievement.
```

Notifikasi award: baris inbox (tabel `notifications` sudah ada, pola
modul `notification`) berisi "Kamu mendapat lencana: Perintis 2026".
Push FCM menyusul lewat infra campaign yang ada, bukan jalur khusus.

### 4.3 Kasus khusus pendaftaran (kohort berjalan)

Window "terdaftar sebelum 2027" yang masih berlungsur berarti user baru
harus menunggu scan berikutnya (maks 6 jam) setelah register. Dua opsi:

- **V1: scan saja.** Delay acceptable; cadence bisa dinaikkan jadi tiap
  jam tanpa perubahan kode (satu konstanta). Dipilih.
- V1.1 kalau "Perintis" harus instan saat signup: evaluasi inline di use
  case register (satu SELECT terhadap baris user sendiri + insert).
  Berarti modul auth memanggil interface achievement; dibuat hanya kalau
  delay terbukti mengganggu.

Kohort yang sudah lewat (misal "anggota 2026"): admin membuat achievement,
klik "Scan" di console, semua user match kebagian (backfill), selesai.
Tidak ada yang perlu dijadwalkan lagi; `is_active` boleh dibiarkan 1
(scan berikutnya otomatis kosong karena window sudah lewat).

---

## 5. Achievement pertama: "Perintis" (spesifikasi lengkap)

Kasus pakai pembuka: lencana untuk user yang terdaftar dari tanggal X
sampai Y.

```json
// achievements (satu baris, dibuat via console)
{
  "code": "perintis-2026",
  "title": "Perintis 2026",
  "description": "Terdaftar sebagai pengguna SambasKu pada tahun pertama",
  "category": "kohort",
  "badge_url": "https://cdn.jsdelivr.net/gh/sambasku/images@main/achievements/perintis-2026.png",
  "criteria": {
    "source": "registration",
    "window": { "from": "2026-01-01T00:00:00+07:00", "to": "2027-01-01T00:00:00+07:00" }
  },
  "family": null,
  "level": null,
  "is_active": 1
}
```

Alur hidupnya:

```text
1. Admin upload badge (pola upload public-image, path achievements/<code>.png)
2. Admin buat achievement di console (form: source=registration, window X->Y)
3. Admin klik "Scan" → backfill: semua user match kebagian + notifikasi inbox
4. Cron 6 jam menjaga: pendaftar baru dalam window otomatis kebagian
5. Profil user menampilkan badge; GET me/achievements mengembalikan + context
6. Setelah window lewat: tidak ada yang berubah, award permanen
```

Kriteria serupa tinggal ganti angka window: kohort event, kohort bulan
peluncuran versi mobile, dan seterusnya. Semua tanpa deploy.

---

## 6. Warm-up katalog (kandidat dari tiap aspek)

Working title; penamaan bermakna budaya dikurasi belakangan dari
`reference/` (GAMIFIKASI_CONCEPT sudah menunjuk arah itu).

| Kode (kerja) | Source | Kriteria | Tier |
| --- | --- | --- | --- |
| perintis-2026 | `registration` | window tahun pertama | - |
| kata-pertama | `contributions_approved` + `entity_type=word` | threshold 1 | 1 |
| kata-panjang | sama | 10 | 2 |
| kata-tokoh | sama | 50 | 3 |
| suara-penutur | `contributions_approved` + `entity_type=pronunciation` | 5 | 1 |
| contoh-berguna | `contributions_approved` + `entity_type=example` | 10 | 1 |
| penjaga-pintu | `verifications_done` | 25 | 1 |
| penjaga-agung | sama | 250 | 2 |
| bercakap | `comments_published` | 10 | 1 |
| betanyar | `discussions_created` | 3 | 1 |
| penyambung | `discussion_replies_published` | 20 | 1 |
| karya-disukai | `votes_received` | 25 | 1 |
| juara-lomba-xxx | `manual` | admin grant daftar username | - |

Pola yang keluar dari warm-up ini: kriteria jenis apapun selalu
terurai menjadi (source, filter, threshold, window). Grammar tidak perlu
tumbuh untuk kandidat berikutnya; hanya registry source yang bertambah.

---

## 7. Kontrak API

Endpoint publik (tanpa autentikasi, rate 100/menit per IP):

`GET /api/v1/achievements` - katalog aktif (untuk layar "semua lencana").

`GET /api/v1/users/:username/achievements` - badge yang sudah didapat
(dipakai profil publik):

```json
{
  "success": true,
  "data": [
    { "code": "perintis-2026", "title": "Perintis 2026",
      "description": "…", "badge_url": "…",
      "awarded_at": "2026-09-29T04:00:00Z" }
  ]
}
```

Endpoint login (30/menit per user):

`GET /api/v1/me/achievements` - sama + `locked`: daftar achievement aktif
yang belum didapat. V1 tanpa angka progres; progres (8/10) menyusul di
V1.1 lewat endpoint agregat per-source, bukan kolom simpanan.

Endpoint admin (role admin/root):

| Endpoint | Fungsi |
| --- | --- |
| `POST /api/v1/admin/achievements` | buat (criteria divalidasi Zod terhadap registry; source tak dikenal = `ACHIEVEMENT_CRITERIA_INVALID`) |
| `PUT /api/v1/admin/achievements/:id` | ubah katalog (code tidak bisa ganti; ubah criteria = tidak menghapus award lama, hanya memengaruhi scan berikutnya) |
| `DELETE /api/v1/admin/achievements/:id` | soft delete |
| `POST /api/v1/admin/achievements/:id/scan` | jalankan scan achievement ini saja (backfill / pemulihan) |
| `POST /api/v1/admin/achievements/:id/grant` | grant manual, body `usernames[]` (untuk source `manual` dan kasus khusus) |
| `DELETE /api/v1/admin/user-achievements/:id` | revoke (soft delete) |

Error code baru ke `ERROR_CODES.md`:
`ACHIEVEMENT_NOT_FOUND` (404), `ACHIEVEMENT_CODE_ALREADY_EXISTS` (409),
`ACHIEVEMENT_CRITERIA_INVALID` (400), `ACHIEVEMENT_ALREADY_GRANTED` (409,
grant manual ke user yang sudah punya).

Semua mutasi admin menulis `audit_logs` (`entity_type 'achievement'` /
`'user_achievement'`) sesuai Section 21.

---

## 8. Console admin dan UI client

Console (submodule `console`, pola halaman admin yang sudah ada):

- Halaman "Achievement": tabel katalog (badge, kode, kategori, aktif,
  jumlah penerima), tombol Scan per baris + Scan semua.
- Form buat/edit: dropdown source (dari registry, label Indonesia),
  filter jenis kontribusi bila relevan, threshold, rentang window
  (date picker), upload badge.
- Aksi grant manual (textarea usernames) dan revoke.

Mobile / web:

- Profil publik: deretan badge (level tertinggi per family).
- "Lencana saya" dari `me/achievements`: tab Dimiliki / Terkunci.
- Entry notifikasi inbox sudah ada; tap → profil.
- Event analitik (tabel Section 14 mobile-base-stack, PR yang sama):
  `achievements_view` (buka daftar lencana, params `tab`),
  `achievement_badge_view` (lihat detail badge, params `code`).

---

## 9. Anti-gaming dan privasi

- Vote yang diberikan tidak pernah jadi sumber; vote diterima hanya pada
  entitas published/approved milik user.
- Komentar/discusi hanya status published/approved; hasil moderasi
  (takedown, soft delete) mengeluarkannya dari hitungan. Konsekuensi:
  award yang sudah terlanjur bisa dicabut admin via revoke; mesin tidak
  meng-auto-revoke (V1; catat sebagai kandidat rapih kalau dibutuhkan).
- Excluded user menyeluruh: `anonim`, `is_active = false`, soft-deleted.
- Kriteria tidak pernah membaca data privat (email, perangkat); hanya
  agregat aksi yang sudah tampak di profil publik.
- Konsistensi dengan ROADMAP: leaderboard dan achievement aktif bersamaan
  setelah keputusan gate PO (ROADMAP Section 8); infrastruktur boleh
  dibangun dan jalan duluan di staging.

---

## 10. Testing

- **Unit (wajib PR)**: validasi grammar Zod (source dikenal/tidak,
  threshold >= 1, window from < to, filter sesuai source); builder SQL
  per source menghasilkan klausa window/filter yang benar.
- **Unit**: use case scan dengan repository mock: idempotensi (dua kali
  scan tidak dobel award), achievement nonaktif dilewati, `manual` tidak
  discan.
- **Integration** (`file:./test.db` + seed): tiap source satu kasus
  positif-negatif (user di atas threshold kebagian, di bawah tidak;
  komentar takedown tidak hitung; `anonim` excluded).
- **E2E**: katalog publik, profil, `me` happy path; admin create dengan
  criteria salah → 400; grant dobel → 409.
- Smoke staging: scan nyata di Workers (batch besar = 1 subrequest,
  verifikasi Section 24).

---

## 11. Sinkronisasi dokumen (checklist PR)

| Artefak | Aksi |
| --- | --- |
| `docs/dbdiagram.dbml` | Tambah `achievements`, `user_achievements` |
| `api/src/.../ERROR_CODES.md` | 4 error code Section 7 |
| `http/achievements/*.bru` | Koleksi Bruno semua endpoint |
| `docs/json/achievements/` | Contoh response + payload criteria |
| `docs/mobile/mobile-base-stack.md` | Tabel event Section 14 |
| `GAMIFIKASI_CONCEPT.md` / `backlogs/GAMIFIKASI.md` | Taut plan ini sebagai eksekusi achievement |
| `docs/api/39-api-achievements.md` | Kontrak endpoint penuh saat eksekusi (penomoran lanjut 38) |

---

## 12. Urutan PR

1. **Fondasi**: migration 2 tabel + index, dbml, grammar Zod + registry
   (V1: `registration`, `manual`, `contributions_approved` + filter),
   unit test.
2. **Modul achievement**: repository, use case scan (batch), notifikasi
   award, hook `runDueAchievementScan()` di `worker.ts`, endpoint admin +
   Bruno + json.
3. **Endpoint publik + `me`**: client bisa membaca; profil badge.
4. **Console**: halaman kelola + upload badge + grant/revoke + scan.
5. **Data pertama**: buat "Perintis" di staging, backfill, verifikasi
   notifikasi dan badge; lanjut produksi setelah observe.
6. **Ekspansi registry** (PR terpisah per batch): komentar, diskusi,
   verifikasi, vote-diterima + halaman "semua lencana" di mobile.

---

## 13. Keputusan terbuka

| Pertanyaan | Rekomendasi V1 |
| --- | --- |
| Award instan saat register (inline) vs scan-only? | Scan-only; naikkan cadence kalau delay terasa |
| Tampilkan progres (8/10) di lencana terkunci? | Belum; endpoint agregat V1.1 |
| Auto-revoke saat baris yang mendasari award dihapus? | Tidak; revoke manual + notifikasi |
| Achievement rahasia (baru terlihat setelah didapat)? | Skip; kolom menyusul kalau ada kebutuhan nyata |
| Penamaan bertema Melayu Sambas | Kurasi dari `reference/` sebelum rilis publik, terpisah dari PR teknis |
