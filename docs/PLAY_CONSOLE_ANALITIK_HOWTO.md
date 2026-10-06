# Play Console Analitik - Cara Kerja & Persiapan

> Status: modul selesai dibangun, menunggu laporan bulanan pertama dari Google.
> Halaman console: `Analitik > Play Store` (`/dashboard/play`). Sementara tampil
> "Laporan Play Console belum tersedia" - itu normal, bukan error.
>
> Catatan: di build **staging** semua halaman Analitik (Ringkasan, Trafik Web,
> Play Store) diblokir dengan pesan "Halaman analitik hanya tersedia di mode
> Production" supaya panggilan API eksternal Google dihemat. Lokal (dev) dan
> production tidak terblokir.

## Ringkasan

Statistik Play Store (instal, uninstall, rating) diambil dari **export CSV harian
Play Console di Google Cloud Storage**, bukan API langsung. Modul sudah selesai:

- **API** `api/src/modules/play-analytics/`: endpoint `GET /api/v1/admin/play-analytics/{overview|growth|ratings}` (admin & root, rate limit 60/menit, cache TTL 6 jam). Parser CSV + agregator sendiri, tanpa dependency baru.
- **Console**: 3 tab:
  - **Ikhtisar**: instal baru, instal aktif, uninstall, rating rata-rata + tren harian.
  - **Pertumbuhan**: pertumbuhan bersih (instal dikurangi uninstall) per hari.
  - **Rating**: rating rata-rata + jumlah ulasan.
- **Error** Google dinormalisasi jadi `PLAY_*` error code di dalam HTTP 200 (pola sama dengan Trafik Web, lihat `api/ERROR_CODES.md`).
- **Panduan setup**: `docs/env/analitik_api_keys/play_console.md`.

Verifikasi saat pembangunan: tsc API + console bersih, 54 test lolos (17 baru),
lint 0 error, `wrangler deploy --dry-run` OK.

## Kenapa sekarang masih kosong

Halaman Play Console > Download reports menampilkan "No monthly reports
available" karena Google **belum membuatkan laporan bulanan pertama**:

1. Laporan bulanan dibuat sekitar **5 hari kerja setelah bulan tutup**. Laporan September 2026 lazim muncul sekitar 5-10 Oktober 2026.
2. Kalau aplikasi baru tayang bulan ini juga, laporan pertama baru ada **awal bulan setelah bulan kalender pertama yang penuh**.
3. Sampai file ada, tab Play Store di console menampilkan status kosong dengan pesan "Laporan Play Console belum tersedia". Endpoint balas `status: "empty"`, bukan error.

Tidak ada langkah setup yang tertinggal. Setelah laporan pertama jadi, bucket
GCS otomatis terisi dan halaman langsung menampilkan data.

## Persiapan saat laporan sudah tersedia (10 menit)

Cek ulang sekitar **10 Oktober 2026**:

1. Play Console > **Download reports > Statistics** > klik **Cloud Storage URI**, salin nama bucket (mis. `pubsrc_id.sambasku.app`).
2. Di bucket itu, beri service account `sambasku-analytics-reader@router-501815.iam.gserviceaccount.com` izin **Object Viewer**.
3. Isi nama bucket:
   - Lokal: `PLAY_STATS_GCS_BUCKET=...` di `api/.env`.
   - Workers: `npx wrangler secret put PLAY_STATS_GCS_BUCKET` lalu ulangi dengan `--env staging`.
4. Deploy ulang API, buka `/dashboard/play`.

`PLAY_STATS_GCS_PREFIX` dikosongkan (default) di `wrangler.toml`: provider
me-list seluruh bucket lalu memfilter nama file `installs_*.csv` /
`ratings_*.csv`, jadi aman terhadap perubahan struktur folder export Play.
Service account dipakai dari `GOOGLE_ANALYTICS_SA_EMAIL` /
`GOOGLE_ANALYTICS_SA_PRIVATE_KEY`
yang sudah terpasang (sama dengan GA4/GSC).

## Keterbatasan & upgrade path

- **Distribusi bintang 1-5 tidak ada** di export CSV standar. Tab Rating
  menampilkan pesan penjelas kalau kosong. Upgrade: Play Developer Reporting
  API (`playdeveloperreporting.googleapis.com`), sudah ditandai `ponytail:` di
  `fake-play-stats.provider.ts` dan `play-stats.provider.ts`.
- **Cache in-memory** TTL 6 jam (`PLAY_CACHE_TTL_SECONDS`), hilang saat isolate
  restart. Upgrade ke Workers KV kalau butuh lintas isolate.
- **Lag data** H+1..H+2; UI sudah mencantumkan catatan ini di toolbar.
