# 17 - Mobile Word of the Day (kartu Kata Hari Ini)

Sumber keputusan: [`docs/backlogs/WORD_OF_THE_DAY.md`](../backlogs/WORD_OF_THE_DAY.md).
Kontrak API: [`28-api-word-of-the-day.md`](../api/28-api-word-of-the-day.md).

## Ringkasan

Kartu **Kata Hari Ini** di Home saat query kosong (state idle), di atas
list search-miss. Begitu user mengetik, kartu hilang - hasil pencarian
mengambil alih. Tap kartu → `WordDetailPage` (navigasi + model reuse).

- Endpoint: `GET /api/v1/words/today` (publik; guest tampil).
- Response = `WordDetailDto` reuse + field optional `date` +
  `is_new_this_week` (default aman untuk response lama).
- Soft-fail: loading = shimmer seukuran kartu; error / `data: null` /
  offline = kartu disembunyikan diam-diam, Home tetap jalan.

## Rantai data (pola fitur dictionary)

```text
data/datasources/dictionary_remote_datasource.dart   # +getWordOfDay()
data/repositories/dictionary_repository_impl.dart    # +getWordOfDay() -> WordOfDay?
domain/entities/word_of_day.dart                     # {word, date, isNewThisWeek}
domain/repositories/dictionary_repository.dart       # +getWordOfDay()
domain/usecases/get_word_of_day_use_case.dart        # BARU
domain/providers/dictionary_domain_providers.dart    # +getWordOfDayUseCase
presentation/providers/word_of_day_providers.dart    # wordOfDayProvider
presentation/widgets/word_of_day_card.dart           # BARU
presentation/pages/home_search_page.dart             # sisip kartu di idle
```

`WordDetailDto` ditambah dua field optional (`date`,
`is_new_this_week`) - tidak memecah parsing response detail lama yang
tidak punya field itu.

## Kartu

- Label kecil "Kata Hari Ini" + tanggal (`date`), lemma besar, arti
  pertama satu baris ellipsis (`definition` makna pertama, fallback
  terjemahan pertama), chip **"Kata baru minggu ini"** hanya saat
  `is_new_this_week` true.
- Provider: `FutureProvider` manual invalidate mengikuti siklus hidup
  biasa (cold start = fetch baru). Tidak ada timer pergantian hari.

## Yang tidak masuk

Share button di kartu (share V1 ada di detail), arsip hari sebelumnya,
cache lintas restart, notifikasi push. Lihat backlog untuk daftar
lengkap.
