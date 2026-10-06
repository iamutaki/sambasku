# GAMIFIKASI - Papan peringkat & retensi kontributor

Dokumen backlog. **Belum diimplementasi.** Tunggu volume kontributor
nyata dan funnel analitik (Firebase) stabil. Lihat juga
[`NEXT.md`](NEXT.md) (bagian tunda) dan kontrak skor
[`docs/api/31-api-leaderboard.md`](../api/31-api-leaderboard.md).

## Tujuan

Membuat kontribusi terasa berarti tanpa mengubah kamus jadi game.
Prioritas: **akuntabilitas skor** yang sudah ada di profil publik,
bukan XP / badge spekulatif.

## V1 (tipis)

1. Statistik pribadi (sudah ada di profil publik:
   kontribusi disetujui, verifikasi, komentar).
2. Leaderboard publik `GET /api/v1/leaderboard` sesuai
   `31-api-leaderboard.md`:
   - `period`: `all` | `week`
   - `metric`: `contributions` | `verifications` | `combined`
3. Mobile: layar papan peringkat + entry dari Profil.
4. Tidak ada kolom poin tersimpan. Skor dihitung ulang dari baris
   yang ada (kontrak API).

## V2 (nanti, YAGNI sampai V1 dipakai)

- Badge / streak / level
- Push “kamu naik peringkat”
- Poin buatan (XP) terpisah dari metrik nyata

## Anti-pola

- Jangan beri skor untuk komentar saja (`combined` = kontribusi +
  verifikasi; komentar tidak masuk gabungan).
- Jangan gamifikasi vote/brigading.
- Jangan tampilkan leaderboard sebelum API + event analitik siap.

## Event analitik (saat build)

Tambah ke tabel di `docs/mobile/mobile-base-stack.md` Section 14:

| Event | Kapan | Params |
| --- | --- | --- |
| `leaderboard_view` | buka papan | `period`, `metric` |
| `profile_stats_view` | lihat statistik di profil publik / saya | `is_self` |

## Urutan kerja saat dieksekusi

1. Implement API leaderboard (`31-api-leaderboard.md`) + Bruno + json.
2. Mobile UI + deep link dari Profil.
3. Update tabel event di `mobile-base-stack.md` di PR yang sama.
4. Uji Firebase DebugView (staging).
