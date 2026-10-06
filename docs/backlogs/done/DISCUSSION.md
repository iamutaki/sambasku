# Ruang Diskusi (Discussion)

Fitur komunitas: user membuka thread (teks dan/atau gambar) tentang bahasa
Sambas; warga dan verifikator membalas, vote, dan pin jawaban terbaik.

Sebelumnya dikenal sebagai Bantuan / Tanya Terjemahan. Identitas teknis
sekarang `discussion*` (tabel `discussions`, API `/discussions`).

## Status

| Lapisan | Status |
|---|---|
| API (modul + admin + publik) | Done |
| Migrasi `0012_translation-helps` + `0032_rename-…-to-discussions` | Done |
| Web publik (feed + detail + CTA Play Store) | Done (read-only) |
| Mobile (ajukan / balas / upload) | Done |
| Console moderasi | Done |

## Ringkas produk

1. Submit (login, mobile): teks ≤1000 dan/atau ≤4 gambar ImageKit staging.
2. Moderasi: approve → gambar ke GitHub publik; reject → hapus staging + note.
3. Feed publik: hanya `published`; balasan langsung tayang (blocklist),
   takedown admin / hapus penulis.
4. Web: baca feed & detail; CTA wajib ke Play Store untuk ajukan/balas.
5. Pin balasan + badge Verifikator di UI.
6. Vote komunitas pada balasan (upvote/downvote) agar jawaban terbaik
   naik; pin admin tetap di atas ranking. Vote pertanyaan: upvote-only.

## Acuan

- API: `docs/api/32-api-discussions.md`
- Bruno: `http/discussion/`
- Web: `web/app/routes/ruang-diskusi*.tsx` (legacy `/bantuan-terjemahan` → 301)
