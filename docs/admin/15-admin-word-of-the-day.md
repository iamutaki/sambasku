# 15 - Admin Word of the Day (kartu Kata Hari Ini di dashboard)

Sumber keputusan: [`docs/backlogs/WORD_OF_THE_DAY.md`](../backlogs/WORD_OF_THE_DAY.md)
(diperluas: tampil juga di dashboard admin).
Kontrak API: [`28-api-word-of-the-day.md`](../api/28-api-word-of-the-day.md).

## Ringkasan

Dashboard admin menampilkan kartu **Kata Hari Ini** di atas strip KPI:
tim internal tahu kata apa yang dilihat semua user hari ini tanpa buka
aplikasi mobile.

- Endpoint: `GET /api/v1/words/today` (publik, lewat `client` axios
  yang sudah ter-auth - tidak ada endpoint admin khusus).
- Isi kartu: label + tanggal, lemma, arti pertama, chip "Kata baru
  minggu ini" saat `is_new_this_week`.
- Soft-fail: `data: null` / error = kartu hilang diam-diam, strip KPI
  tetap tampil (dashboard tidak boleh rusak karena WOTD gagal).
- `staleTime` 1 jam - kata tidak berubah dalam satu hari, tapi jangan
  hangus lebih lama dari ganti tanggal.

## Struktur (pola fitur dashboard)

```text
admin/src/features/word-of-day/
├── infrastructure/word-of-day-api.ts      # GET /words/today via client
├── application/use-word-of-day.ts         # useQuery(['word-of-day'])
└── presentation/word-of-day-card.tsx      # kartu antd
```

`dashboard-page.tsx`: kartu dirender di atas `<StatCards>`.

Tanpa navigasi ke detail kata admin di V1 (klik kartu tidak melakukan
apa-apa; cek kata lewat panel Kata seperti biasa).
