# Mobile Kontribusi: Search-Miss Menu + Vote Deck

Mengikuti `mobile-base-stack.md`. Kontrak API:
[`../api/34-api-vote-deck.md`](../api/34-api-vote-deck.md).
Backlog: [`../backlogs/KONTRIBUSI_VOTE_DECK.md`](../backlogs/KONTRIBUSI_VOTE_DECK.md).

---

## Intent

Tab **Kontribusi** (`/action`) menjadi hub dua pekerjaan:

1. Menu usul (form + **Kata yang sering dicari** + Ruang Diskusi).
2. Deck swipe **Bantu nilai kamus** di bawah - kata terbit yang user
   belum vote.

---

## Tab Kontribusi (`ActivityPage`)

### Tile (urut)

1. **Usul kata baru** - subtitle “Isi form kosong dari awal” →
   `/contribute` (tetap).
2. **Kata yang sering dicari** - subtitle “Pilih kata yang warga cari
   tapi belum ada” → `/search-misses` (**baru**).
3. **Ruang Diskusi** - tetap → feed discussion.

List search-miss **tidak** lagi di tab.

### Section deck (bawah tile)

- Judul: **Bantu nilai kamus**
- Subtitle: **Geser kartu - apakah arti kata ini masuk akal buat kamu?**
- Area kartu + footer tombol **Kurang pas** | **Masuk akal**
- Hint: Geser kanan kalau masuk akal, kiri kalau kurang pas - atau
  pakai tombol

**Login:** `GET /api/v1/votes/deck` → swipe/tombol → kartu maju
**segera** (optimistic); `POST /api/v1/votes` dikirim di background
lewat antrian (`VoteSubmitQueue`, max 3 paralel). Gagal jaringan →
toast + kartu dikembalikan ke depan antrean. Rewind: cancel job
yang belum terkirim, atau undo toggle jika sudah settle.

**Tamu:** jangan panggil `/votes/deck`. Tampilkan 1-2 kartu sample dari
`GET /words/latest` (read-only) + soft gate “Masuk dulu untuk menilai
kata” (CTA login). Swipe/tombol membuka gate, bukan vote.

**Empty:** “Kamu sudah menilai semua kata di antrean. Terima kasih
membantu warga lain.”

**Error:** “Gagal memuat antrean penilaian. Tarik untuk coba lagi.”

Pull-to-refresh: invalidate deck (+ sample latest untuk tamu).

---

## Halaman `/search-misses`

- Header: **Kata yang sering dicari**
- Body: list yang sebelumnya di tab (term, arah, hit count) →
  `/contribute?lemma&search_in&miss_id` + analytics
  `search_miss_tap` / `contribute_start` (`from: search_miss`).
- Empty: “Belum ada antrian dari pencarian warga. Coba lagi nanti,
  atau usul kata baru dari menu di atas.”
- Loading / error: sama pola sebelumnya di tab.

Route di luar atau dalam shell: **di luar tab shell** (push seperti
`/contribute`) agar back ke tab Kontribusi.

---

## Gesture & widget

- Adaptasi pola `ReviewSwipeCard` (kanan positif, kiri negatif).
- Widget **baru** di fitur vote/activity (mis. `VoteDeckSwipeCard`) -
  **jangan** share state dengan review.
- `onSwiped` → drop lokal + enqueue vote background; return `true`
  segera (tanpa menunggu POST). Gagal submit → toast + reinsert.
- Prefetch halaman deck berikutnya saat sisa kartu rendah.

---

## Modul / file

```
mobile/lib/features/
├── activity/presentation/pages/activity_page.dart   # tile + deck shell
├── search_miss/
│   └── presentation/pages/search_miss_list_page.dart  # BARU
└── vote/
    ├── data/... getDeck
    └── presentation/
        ├── pages/vote_deck_section.dart (atau widget di activity)
        └── widgets/vote_deck_swipe_card.dart
```

Router: daftarkan `/search-misses` (SearchMissRouter atau di activity
router). Deck **inline** di tab (bukan full-screen session V1).

---

## Analytics

| Event | Kapan | Params |
| ----- | ----- | ------ |
| `vote_deck_view` | Section deck tampil (login) | - |
| `vote_deck_swipe` | Setelah vote sukses dari deck | `direction` (`up`/`down`), `word_id` |
| `vote_cast` | Reuse helper existing jika ada | - |
| `search_miss_tap` | Tap item di halaman miss | `miss_id` |

---

## Copy ringkas

Lihat tabel copy di backlog `KONTRIBUSI_VOTE_DECK.md`.
