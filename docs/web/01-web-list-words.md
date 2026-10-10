# Web - Daftar Kata A-Z (List All)

Status dokumen: submodule `web/` masih kosong (README saja) - dokumen ini
contract awal STACK-AGNOSTIC yang mengikat perilaku halaman, bukan
implementasi. Satu-satunya sinyal stack tertulis: `admin-base-stack.md`
("React 19 dipakai juga di `web/`"). Saat web dibangun, pola implementasi
boleh meniru admin: `useCursorList` + `useDebouncedValue` + envelope axios
di `admin/src/shared/`. Kontrak API: `../api/18-api-list-words.md` -
daftar publik semua kata published urut lemma A-Z, cursor komposit
opaque, filter `q` server-side. Keputusan produk:
`../backlogs/PLAN_LIST_ALL.md`.

## 1. Route & Halaman

- Route `/words`: halaman "Daftar Kata A-Z" - list semua kata published,
  guest boleh (tanpa login).
- Tap item kata → navigasi ke `/words/:id` (halaman detail kata web =
  backlog TERPISAH, belum dikontrak; link/route-nya yang dikunci di
  sini).
- Entry point: tautan "Daftar Kata A-Z" dari beranda web (saat beranda
  web dibangun). Panel huruf A-Z di beranda memakai `?letter=D`
  (prefix lemma), **bukan** `?q=D` (contains).

## 2. State & Data Fetching

- Satu sumber data: `GET /api/v1/words` (kontrak 18). Tanpa state lokal
  duplikat.
- Pagination cursor WAJIB: infinite query dengan page param =
  `meta.next_cursor`; berhenti saat `has_more` false atau `next_cursor`
  null. Tidak ada nomor halaman, tidak ada total_items (envelope tidak
  menyediakannya).
- Query key cache bawa SEMUA filter aktif (q, word_type) - ganti filter
  = query baru, bukan mutasi cache.
- Abort request stale (signal bawa framework) saat q berubah cepat.

## 3. Pencarian (Filter q)

- Kotak cari di halaman: debounce ~300ms → kirim `q` ke endpoint yang
  sama (filter server-side `ILIKE %q%` pada lemma - BUKAN filter lokal,
  supaya hasil tetap benar saat pagination).
- Panel huruf beranda → `letter=A..Z` (prefix `lower(lemma) LIKE 'd%'`).
- Browse tanpa `q` tidak menampilkan kata ber-label `kasar` /
  `diskriminatif` (filter server di kontrak 18); `letter` ikut aturan
  browse itu. Pencarian manual (`q` terisi) tetap bisa menemukan
  keduanya; detail kata + badge tetap tayang.
- Hapus query → kembali full A-Z (reset cursor ke halaman pertama).
- Hasil kosong saat filter TIDAK termasuk search-miss - miss hanya
  direkam pencarian utama `/words/search` (kontrak 12).

## 4. UX & State Halaman

- Grouping huruf A-Z dari item termuat (client-side): header section
  per huruf pertama (uppercase); karakter non-alfabet → bucket `#`.
- Loading awal → skeleton baris; loading halaman lanjut → indikator
  bawah (footer spinner) atau tombol "Muat lagi" saat has_more.
- Empty → pesan "Tidak ada kata" + hint menghapus filter saat q berisi.
- Error → pesan + tombol "Coba lagi" (refetch); nilai q TIDAK hilang.
- Scroll position dipertahankan saat kembali dari detail (behavior
  bawaan SPA router - jangan remount list saat back).

## 5. Auth

- Halaman publik - TANPA auth, tanpa interceptor token. axios/fetch
  instance polos cukup.

## 6. Error Mapping

- 400 VALIDATION_ERROR (query/cursor salah) → reset ke halaman pertama
  + refetch (cursor dianggap opaque - TIDAK pernah didecode client).
- 429 RATE_LIMITED → tahan interaksi + tunggu sesuai header
  Retry-After, lalu refetch otomatis.
- 5xx / network error → pesan generik + "Coba lagi".

## Referensi Terkait

- `../api/18-api-list-words.md` - kontrak endpoint yang dikonsumsi.
- `../backlogs/PLAN_LIST_ALL.md` - keputusan produk fitur ini.
- `../admin/admin-base-stack.md` - referensi pola React 19 + TanStack
  Query + `useCursorList`/`useDebouncedValue` bila web memakai stack
  yang sama dengan admin.
