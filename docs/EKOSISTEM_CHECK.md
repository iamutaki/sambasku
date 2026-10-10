# EKOSISTEM_CHECK - Audit Prinsip Open Source dan Data Terbuka

Tanggal audit: 3 Oktober 2026
Lingkup: seluruh monorepo `sambasku` (root + 16 submodule)

## Verdict

| Area | Status |
| --- | --- |
| Lisensi kode dan data | COMPLY |
| Struktur monorepo dan publikasi data terbuka | COMPLY |
| Keamanan secret | AMAN DI GIT (koreksi: tidak pernah ter-commit), risiko proses tersisa |
| Praktik governance open source | CELAH MINOR |

## 1. Lisensi: COMPLY

Setiap repositori punya LICENSE. Skema konsisten:

| Repo | Lisensi | Jenis aset |
| --- | --- | --- |
| root (`sambasku`) | GPLv3 | Orkestrasi submodule |
| `api` | GPLv3 | Kode backend |
| `web` | GPLv3 | Kode situs publik |
| `console` | GPLv3 | Kode admin console |
| `mobile` | GPLv3 | Kode aplikasi Flutter |
| `docs` | GPLv3 | Dokumentasi |
| `http` | GPLv3 | Koleksi Bruno |
| `reference` | GPLv3 | Acuan editorial |
| `sqlite` | GPLv3 | Tooling SQLite |
| `worker` | GPLv3 | Kode worker |
| `github-pages` (`.github`) | GPLv3 | Profil organisasi |
| `audios` | CC BY-SA 4.0 | Audio pelafalan |
| `images` | CC BY-SA 4.0 | Gambar kata + avatar |
| `database` | CC BY-SA 4.0 | Dataset kamus publik (SQLite Release) |
| `csv` | CC BY-SA 4.0 | Korpus import + sumber |
| `assets` | CC BY-SA 4.0 | Aset umum |
| `data` | CC BY-SA 4.0 | Data terbuka |

Catatan:

- Pemisahan kode (GPLv3) vs data/media (CC BY-SA 4.0) sudah tepat sesuai praktik komunitas open source dan data terbuka.
- CC BY-SA 4.0 adalah lisensi terbuka yang diakui untuk data; syarat atribusi dan share-alike terpenuhi dengan menyimpan sumber mentah di `csv/source/wiktionary-raw` beserta jejak asalnya (Wiktionary, lisensi CC BY-SA).
- GPLv3 pada kode aplikasi memenuhi definisi open source (OSI-approved).

## 2. Data Terbuka: COMPLY

- `database/` hanya memuat artifact SQLite kamus `published` yang disanitasi, disalurkan lewat GitHub Release (bukan backup production, bukan token Turso). Sesuai kontrak di `database/README.md`.
- `audios/` dan `images/` publik dan diakses lewat CDN (jsDelivr), bukan lewat backend.
- Transparansi keuangan publik di `github-pages/` (`cashflow.csv`, `payable.csv`) sejalan dengan prinsip keterbukaan.
- Root repo bersih: tidak ada file `.env`, DB, keystore, atau secret yang ter-track git.

## 3. Keamanan Secret: AMAN DI GIT, RISIKO PROSES (diperbarui 3 Okt 2026)

Koreksi dari draft awal: setelah verifikasi `git ls-tree`, `git log -S`, dan `git rev-list --objects --all` terhadap `origin/main` dan seluruh branch lokal, `env/` **tidak pernah ter-track** di repo `docs`. `.gitignore` (`env/`) sudah bekerja sejak awal, sehingga:

- Riwayat git publik `sambasku/docs` TIDAK berisi secret (termasuk PR #1).
- Rotasi kredensial darurat TIDAK diperlukan karena kebocoran publik tidak terjadi.
- Purge riwayat / force push tidak diperlukan.

Isi `docs/env/` (private key JWT, service account Firebase, token Turso, API key Resend, 5 GitHub PAT, `upload-keystore.jks`, `sign.zip`) hanya ada di **lokal**. Semua kredensial tetap ASLI dan aktif.

Risiko yang tersisa adalah proses, bukan kebocoran yang sudah terjadi:

1. `env.zip` (arsip seluruh `env/`) sempat berada untracked TANPA di-ignore. Satu `git add -A` akan membawanya masuk. Sudah diperbaiki: `docs/.gitignore` kini men-ignore `env.zip` dan `.DS_Store`.
2. Satu-satunya backup `env/` berada di dalam folder repo itu sendiri. Sudah dipindahkan juga ke `~/.sambasku-env-backup/` (di luar repo).
3. Menyimpan secret dalam file markdown di folder kerja tetap rapuh terhadap kesalahan manusia (salah `git add -f`, screenshot, sinkronisasi cloud).

**Rekomendasi tetap berlaku:**

1. Pindahkan secret ke password manager atau secret manager. File markdown di lokal boleh jadi catatan sementara, bukan sistem final.
2. Aktifkan secret scanning + push protection di GitHub organization sebagai jaring pengaman.
3. Tambahkan `SECURITY.md` (lihat bagian Governance) sebagai kanal lapor bila kebocoran benar-benar terjadi kelak.

## 4. Governance: CELAH MINOR

| Praktik baik | Status |
| --- | --- |
| `LICENSE` di semua repo | Ada |
| `README.md` di semua repo | Hampir semua (`github-pages`, `csv` belum) |
| `CONTRIBUTING.md` | Belum ada di semua repo |
| `CODE_OF_CONDUCT.md` | Belum ada |
| `SECURITY.md` (kanal lapor kerentanan) | Belum ada |

Rekomendasi:

1. Tambahkan `SECURITY.md` minimal di `api`, `mobile`, `docs` supaya laporan kerentanan punya kanal resmi (email kontak, bukan issue publik).
2. Tambahkan `CONTRIBUTING.md` satu halaman: cara clone submodule, cara jalankan test, konvensi commit.
3. Tambahkan `CODE_OF_CONDUCT.md` (boleh pakai template Contributor Covenant).
4. Lengkapi README `github-pages` dan `csv`.

## Ringkasan Eksekusi

Struktur lisensi dan publikasi data terbuka di monorepo ini sudah benar dan bisa dijadikan contoh. Setelah verifikasi mendalam, `env/` tidak pernah bocor ke git publik; gitignore sudah melindungi sejak awal. Sisa pekerjaan: pindahkan secret ke password manager, aktifkan push protection, dan lengkapi file governance.
