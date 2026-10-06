# VERIF - Verifikator & profil publik

Catatan produk (per 2026-09-20). Fitur yang ingin dilihat nanti di app.

## Intent

Dari app, user bisa melihat **siapa verifikator** suatu entri (kata /
usulan yang sudah diverifikasi).

Ini adalah fitur **auth** (identitas user / peran), bukan sekadar label
teks di UI.

## Cakupan terkait

- User lain bisa **mengecek profil user lain** (profil publik).
- Dari profil verifikator (atau kontributor), user bisa melihat konteks
  siapa orang di balik aksi verify / kontribusi.

## Kontrak general

> Ditetapkan 2026-09-20, sebelum implementasi. Prompt implementasi:
> `docs/api/19-api-profil-publik.md` dan `docs/mobile/08-mobile-profil-publik.md`.
> Kontrak di bawah adalah sumber kebenarannya.

### Prinsip

- **Zero migration.** Semua data sudah ada: `words.verified_by` /
  `verified_at`, `contribution_reviews.reviewer_id`,
  `contributions.user_id`. Fitur ini murni baca + expose.
- Identitas publik = **`username`** (unique, stabil - tidak ada alur
  ganti username). **Email, phone, password hash, dan `is_active`
  tidak pernah diekspos** ke publik.
- Badge verifikator **diturunkan** dari `users.role`
  (`admin` / `editor` / `root` / `reviewer` = tim verifikator sesuai
  `resolvePublication` di 03-api-kontribusi-verifikasi.md) - bukan
  kolom baru. Bukan label `administrator`.

### 1. Endpoint profil publik

```text
GET /api/v1/users/:username          (PUBLIK - tanpa auth)
Middleware: rate limit 100 req/menit per IP (tier baca publik,
sama seperti GET /api/v1/search-misses)

Response 200 (envelope standar Section 13):
{
  "username": "budi",
  "role": "reviewer",
  "is_verifier": true,               // derived dari role
  "joined_at": "2026-08-01T00:00:00Z",  // users.created_at
  "stats": {
    "contributions_approved": 12,    // COUNT contributions
                                     //   user_id = :user, status IN
                                     //   ('approved','corrected')
    "verifications_done": 34         // COUNT contribution_reviews
                                     //   reviewer_id = :user,
                                     //   status != 'pending'
  }
}
```

- `:username` tidak ditemukan, user soft-deleted, **atau
  `is_active = false`** → `404 USER_NOT_FOUND` (kode sudah dipakai
  auth; daftarkan di ERROR_CODES.md jika belum).
- Lookup username exact match setelah decode path (spasi boleh; unique
  case-sensitive). Client: `Uri.encodeComponent`.
- Profil user sistem `anonim` boleh dibuka; stats jalan biasa.
- Tidak ada endpoint list/cari user di fase ini.

### 2. Atribusi verifikator di detail kata

`GET /api/v1/words/:id` menambah blok (backward compatible - field
baru, field lama tidak berubah):

```text
"verified_by": { "username": "budi", "role": "reviewer" } | null,
"verified_at": "2026-09-01T00:00:00Z" | null
```

- JOIN `users` di atas `words.verified_by`; user yang sudah
  soft-deleted **tetap ditampilkan** (atribusi tidak hilang).
- `is_verified = false` → `verified_by` dan `verified_at` null.
- Antrean admin sudah menampilkan `contributor_username` - tidak
  ada perubahan di sisi admin.

### 3. Kontrak lintas (WAJIB saat implementasi)

- Envelope standar Section 13; route `createRoute()` + schema Zod
  request/response (Section 9).
- Error code: `USER_NOT_FOUND` (404) sudah dipakai auth; wajib ada di
  ERROR_CODES.md.
- Koleksi Bruno `http/users/` + sample response `docs/json/users/`
  (Section 20 - tiga sumber tidak boleh saling tertinggal).
- Testing (Section 10): unit use case + e2e minimal 1 happy + 1 404.
- Modul: `modules/user/` (profil publik baca-saja). Kontrak respons
  tidak menempel di auth.

### Non-goals (fase ini)

- Avatar, bio, edit profil - butuh kolom + migration; buat kontrak
  terpisah kalau jadi dibutuhkan.
- Riwayat aktivitas per user (daftar kata yang diverifikasi / divote /
  dikomentari) - tumpang tindih dengan "riwayat aktivitas user"
  ([`../NEXT.md`](../NEXT.md) Prioritas 1, Vote/Komentar saya);
  `stats` agregat di atas cukup untuk konteks profil.
- Profil by ID ULID - username sudah cukup sebagai identitas publik.

## Catatan

Status: diimplementasikan 2026-09-21. Kontrak lengkap:
`docs/api/19-api-profil-publik.md`, mobile
`docs/mobile/08-mobile-profil-publik.md`.
