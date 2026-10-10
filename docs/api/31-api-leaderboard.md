# Kontrak leaderboard (belum diimplementasi)

Dokumen ini mengunci arti angka sebelum ada endpoint, tabel poin, atau UI.
Gamifikasi penuh (badge, level, push) tetap ditunda - lihat
[`docs/backlogs/NEXT.md`](../backlogs/NEXT.md).

Sumber angka sudah ada di [`19-api-profil-publik.md`](19-api-profil-publik.md).
Tidak ada kolom poin tersimpan. Skor selalu dihitung ulang dari baris yang ada.

## Definisi skor

| Metrik | Sumber | Catatan |
| --- | --- | --- |
| `contributions` | `contributions` milik user dengan `status` `approved` atau `corrected`, `deleted_at` null | Sama dengan `stats.contributions_approved` di profil publik |
| `verifications` | satu baris `contribution_reviews` per keputusan, `reviewer_id` = user, `status` bukan `pending` | Sama dengan `stats.verifications_done`. Bukan `words.verified_by` |
| `comments` | komentar `published` milik user | Sama dengan `stats.comments_published` |
| `combined` | `contributions + verifications` | Komentar tidak masuk gabungan, supaya diskusi tidak menyaingi kontribusi kamus |

Satu keputusan review memberi paling banyak satu poin verifikasi.
Jalur **409** (`CONTRIBUTION_ALREADY_REVIEWED`, `WORD_ALREADY_VERIFIED`,
`WORD_ALREADY_UNVERIFIED`) tidak menyisipkan baris `contribution_reviews`
dan tidak menambah skor.

Periode:

- `all` - seluruh riwayat
- `week` - 7 hari ke belakang dari `contribution_reviews.created_at`
  (verifikasi) atau `contributions.updated_at` (kontribusi disetujui).
  Bukan tabel event baru.

## Endpoint yang diusulkan

Belum dibangun. Bentuknya, supaya klien nanti tidak menebak:

`GET /api/v1/leaderboard`

Query:

- `period`: `all` (default) atau `week`
- `metric`: `contributions` | `verifications` | `combined` (default `combined`)
- `limit`: 1-50, default 20

Respons 200, publik, tanpa autentikasi:

```json
{
  "success": true,
  "data": [
    {
      "rank": 1,
      "username": "rina",
      "avatar_url": null,
      "score": 12,
      "is_verifier": true
    }
  ]
}
```

`is_verifier` mengikuti peran antrean publik di profil (`admin`, `editor`,
`root`, `reviewer`). Tidak ada field `tier`, `badge`, atau `level`.

Seri: username yang sama, urutan `username` menaik, `rank` boleh seri
(dua orang `rank` 2, berikutnya `rank` 4).

User `anonim`, soft-deleted, atau `is_active = false` tidak masuk daftar.
