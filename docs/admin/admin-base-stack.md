# Base Stack - Konsol Admin Kamus Digital Sambas-Indonesia (Frontend)

Dokumen ini jadi acuan tetap untuk semua prompt/fitur frontend admin
selanjutnya (halaman kata, tambah kata, antrean review, audit, dashboard,
dsb). Setiap prompt fitur baru akan mengikuti struktur dan konvensi di sini,
tanpa perlu dijelaskan ulang tiap kali - sama seperti peran
`docs/api/api-base-stack.md` untuk backend.

Konsol admin ini mengonsumsi API yang kontraknya ada di `docs/api/*` -
envelope response (Section 13), cursor pagination (Section 13),
auth token (Section 00-api-auth), role matrix (Section 22), dan error code
(`ERROR_CODES.md`) adalah "aturan main" dari sisi server yang diikuti ketat
di sisi frontend.

## Bukan halaman publik (wajib)

Konsol admin hanya untuk internal (admin, root, verifikator). Tidak untuk
publik, jadi robot dan crawler memang diblokir aksesnya:

- `console/public/robots.txt`: `Disallow: /` untuk semua user-agent.
- `console/public/_headers`: `X-Robots-Tag: noindex, nofollow` plus security
  headers lain (CSP, X-Frame-Options, HSTS, dsb).

Ini kebijakan yang disengaja, bukan kelalaian SEO. Jangan menambahkan
sitemap, meta SEO, canonical, atau usulan pengindeksan mesin pencari untuk
konsol. Halaman login pun tidak boleh terindeks.


## Gaya tulisan (wajib)

Tulisan teknis di repo ini (docs, komentar, UI copy) tidak memakai
em/en dash gaya AI.

1. JANGAN pakai em dash (`—`, U+2014) atau en dash (`–`, U+2013).
   Ganti hyphen ASCII biasa (`-`, U+002D).
2. Jangan berlebihan menyambung klausa dengan ` - `; lebih baik titik,
   koma, titik dua, atau kurung.
3. Judul: titik dua atau frasa utuh lebih jelas dari
   `Judul - Subjudul` berulang.
4. Referensi: `path: penjelasan` atau `path - penjelasan` dengan hyphen
   biasa (bukan `—` / `–`).
5. Bullet markdown dan `| --- |` di tabel tetap boleh (itu sintaks).
6. Berlaku juga untuk string UI (toast, label, hint, Modal, Tooltip) -
   jangan copy-paste `—` dari model AI ke kode.

### Nada copywriting UI (wajib)

Copy UI (label, hint, empty state, toast, Modal, Tooltip) memakai bahasa
santai yang memanusiakan, seperti warga Sambas ngobrol. Bukan bahasa
prosedural kaku. Poin:

1. Sapaan ke pengguna: **kamu** (jangan "Anda"). Bentuk posesif ringkas
   boleh: `usulanmu`, `emailmu`, `katamu`.
2. Ajakan dibaca seperti bicara: tambah `ya` atau `aja` di akhir kalimat
   instruksi bila cocok (`Masuk dulu ya sebelum mulai diskusi`,
   `Tulis dulu pertanyaan atau cerita kamu ya`).
3. "Anda bisa..." jadi `Kamu bisa...`. "Masukkan..." jadi `Tulis...`.
   "Jelaskan konteks..." jadi `Ceritakan...`.
4. Sebut manfaat atau hasil, bukan proses sistem:
   - BAD: `Jelaskan pertanyaan atau konteks bahasa yang ingin didiskusikan`
   - GOOD: `Tulis pertanyaan atau cerita kamu di sini. Semakin jelas konteksnya, semakin mudah warga membantu.`
5. Error tetap informatif: sebab + aksi, tetap santai:
   - BAD: `Deskripsi wajib diisi`
   - GOOD: `Tulis dulu pertanyaan atau cerita kamu ya`
6. Kalimat moderat: hanya satu partikel santai (`ya` / `aja`) per kalimat.
   Jangan sampai terdengar menggurui atau berlebihan.
7. Judul halaman, label aksi baku (`Kirim`, `Batal`, `Hapus`, `Coba lagi`,
   `Masuk`), dan status (`Menunggu pengecekan`) tetap netral; yang dibuat
   santai adalah kalimat penjelas, hint, empty state, dan pesan.

Pengecualian konsol admin: konfirmasi aksi destruktif (hapus akun, hapus
entri) tetap lugas dan formal seperlunya; kejelasan konsekuensi diutamakan
di atas kehangatan.

## Format tanggal-waktu UI (wajib)

Semua timestamp yang ditampilkan ke worker (tabel, Descriptions, detail)
pakai helper `formatDateTime` / `formatDateTimeSeconds` di
`shared/utils/format-datetime.ts` (dayjs parse + bulan ID custom).

| Pola | Contoh | Dipakai untuk |
| --- | --- | --- |
| `D MMM YYYY HH:mm` | `17 Nov 2026 21:00` | Default (tabel, detail) |
| `D MMM YYYY HH:mm:ss` | `17 Nov 2026 21:00:05` | Audit log saja |

Aturan:

1. JANGAN `dayjs(...).format(...)` inline di halaman - selalu lewat helper.
2. Bulan singkat Indonesia: Jan Feb Mar Apr Mei Jun Jul Agu Sep Okt Nov Des
   (bukan May/Aug/Oct/Dec; Agustus = `Agu`, bukan Agt dari dayjs locale).
3. Hari tanpa zero-pad (`1` bukan `01`); jam 24 jam zero-pad (`09:05`).
4. Tidak pakai koma sebelum jam; tidak pakai relatif ("2 jam lalu") kecuali
   fitur secara eksplisit minta relative time.
5. Nilai null/invalid → `-`.
6. Helper memakai daftar bulan sendiri (bukan `dayjs.locale('id')` MMM)
   supaya admin & mobile 1:1.

## Preview gambar (wajib)

Gambar konten di konsol (lampiran laporan, screenshot pengajuan,
ilustrasi kata, diff usulan) dibuka sebagai overlay di halaman yang
sama. Acuan yang sudah benar: detail pengajuan verifikator
(`Image` dari antd). Thumbnail bukan tautan yang membuka URL di tab baru.

### Kompresi unggah gambar kata (wajib)

Sebelum `POST /api/v1/images?purpose=word`, file dikompres di klien
(`shared/utils/compress-image.ts`):

- Max sisi **720×720** (aspect ratio tetap)
- WebP **quality 0.8**
- Selaras mobile (`kPhotoPickMaxWidth/Height` / `kPhotoPickQuality`)

Stock Media Explorer tidak dikompres (URL eksternal).

Aturan:

1. Pakai `Image` dari `antd`. Klik thumbnail membuka overlay preview
   (aktif secara default, tanpa prop tambahan).
2. Lebih dari satu gambar dalam satu kelompok visual (satu sel tabel,
   satu galeri) dibungkus `Image.PreviewGroup`, supaya overlay punya
   panah ke gambar berikutnya. `Image` tidak harus anak langsung:
   context grup tetap jalan di dalam `Space` / `Flex`.
3. Thumbnail: `objectFit: 'cover'` dan sudut membulat. Ukuran ikut
   konteks (sel tabel sekitar 36, blok detail sekitar 48-72).
4. Jangan `<img>` mentah, dan jangan bungkus gambar dengan
   `<a href target="_blank">`.
5. `preview={false}` hanya untuk blob lokal yang masih diunggah
   (lihat `word-images-field.tsx`).
6. Audio bukan gambar: tetap `<audio controls>` atau tautan berkas.
   Jangan pakai `Image` untuk file suara.
7. Tidak ada lampiran: teks `-`, bukan placeholder gambar.

```tsx
<Image.PreviewGroup>
  <Space size={4} wrap>
    {images.map((img) => (
      <Image
        key={img.provider_file_id}
        src={img.url}
        alt=""
        width={36}
        height={36}
        style={{ objectFit: 'cover', borderRadius: 4 }}
      />
    ))}
  </Space>
</Image.PreviewGroup>
```

Dipakai di kolom Lampiran Laporan Masalah, screenshot pengajuan
verifikator, gambar detail kata, dan preview kontribusi.

## Elevasi: tanpa shadow dekoratif (wajib)

Konsep visual sambasku adalah clean minimalism: permukaan datar, batas
lewat border tipis dan kontras warna. Drop shadow mengubah feel aplikasi,
jadi jangan ditambahkan sesuka hati.

1. **Dilarang** drop shadow dekoratif pada card, item list, tile grid,
   thumbnail, tombol, panel, atau section (`boxShadow` dengan blur/offset,
   `token.boxShadow*` di permukaan statis).
2. Pemisah antar elemen: `bordered` / border 1px token antd, warna latar
   berbeda (`colorFillAlter`), atau spacing.
3. **Boleh** (fungsional, bukan dekorasi):
   - Shadow bawaan antd pada lapisan melayang (Dropdown, Popover,
     Select, Modal, Drawer, notification) - jangan dioverride jadi lebih
     tebal.
   - Ring fokus/selected tanpa blur (`0 0 0 2px ...` atau `inset`).
   - Handle/kontrol di atas gambar yang butuh kontras agar terbaca
     (contoh: `image-censor-editor.tsx`).
4. Butuh shadow di luar daftar di atas: diskusikan dulu, jangan langsung
   tambah.
5. **Konsistensi UI lintas halaman (wajib)** - elemen yang fungsinya sama
   wajib tampak dan terletak sama di semua halaman konsol. Sebelum
   menambah tombol/panel/kartu, cek pola existing lalu tiru (komponen,
   posisi, ukuran, token). Contoh: aksi halaman selalu di `PageHeader`
   kanan; panel filter selalu `bordered` + radius token antd yang sama.
   Jangan bikin varian baru dari komponen yang sudah ada polanya.
   Rule: `.cursor/rules/ui-consistency.mdc`.

Acuan lintas app: `docs/web/web-base-stack.md` (Section 6) dan
`docs/mobile/mobile-base-stack.md` (Section 5e).

---

## 1. Tech Stack

| Layer              | Pilihan                                       | Alasan                                                                                              |
| ------------------ | --------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Framework          | React 19 (latest)                             | Tipe komponen + ekosistem terluas; dipakai juga di `web/`                                           |
| Bahasa             | TypeScript (strict)                           | Type safety; kontrak API (envelope/cursor) dijaga dari domain model sampai halaman                  |
| Build tool         | Vite                                          | Instan dev server + bundle production via rolldown                                                  |
| UI Library         | Ant Design **v6** (`antd`)                    | Komponen lengkap (Layout, Form, Table, Menu, Dropdown, Tag, Alert...), tema via token                |
| Data fetching      | TanStack Query v5 (`@tanstack/react-query`)   | Cache, retry, aborsi, infinite query untuk cursor pagination - tanpa boilerplate loading/error state |
| Routing            | TanStack Router (`@tanstack/react-router`)    | Type-safe route tree + `beforeLoad` guard (auth) + preload/scroll restoration                       |
| Tabel              | TanStack Table (`@tanstack/react-table`)      | Headless (state, kolom, cell render) - dirender lewat bridge ke antd `<Table>`                       |
| HTTP client        | axios                                         | Interceptor (attach token + auto refresh/retry) + `withCredentials` untuk cookie refresher          |
| Tanggal            | dayjs + `shared/utils/format-datetime.ts`     | Format baku UI: `17 Nov 2026 21:00` (lihat Section format tanggal) |
| Icons              | `@ant-design/icons`                           | Ikon menu/layout/halaman                                                                            |
| i18n               | `i18next` + `react-i18next` + JSON katalog    | Multi-bahasa chrome konsol (`CONSOLE-I18N.md`); antd `ConfigProvider locale`                        |
| Lint/Format        | ESLint (typescript-eslint) + Prettier         | Konsistensi kode; `react-hooks` + `react-refresh` plugin                                            |
| Testing            | Vitest                                        | Unit test cepat (node env), file di `src/**/__tests__/`                                             |
| Package manager    | pnpm                                          | Konsisten dengan repo (`api/`, `http/`)                                                            |

> Catatan versi: `react@19.3`, `antd@^6.6`, TanStack React Query `^5`, Router
> `^1.170`, Table `^8`. Semua dipakai sebagai mayor terbaru saat base stack
> dibuat - upgrade minor aman, upgrade mayor harus dibahas dulu.

---

## 2. Prinsip Clean Architecture yang Dipakai (Frontend)

Backend memakai empat lapisan (Section 2 `api-base-stack.md`). Admin
mengambil **tiga lapisan** - domain murni tetap ada, tapi "infrastructure"
di sini berarti **akses HTTP/API**, dan "presentation" adalah **halaman React
(UI)**:

```
Presentation (halaman React/antd) → Application (hooks/use cases)
                                        ↓
Domain (entitas + tipe)  ←── Infrastructure (client API / axios)
```

Arah dependency:

- **Domain**: tipe murni (`interface`, `const`, `type`). Tidak tahu React,
  axios, atau antd. Satu-satunya "sumber kebenaran" bentuk data yang datang
  dari API (kontrak `docs/api/*`).
- **Application**: hooks (use case). Logika "apa yang terjadi setelah data
  sampai/dikirim" - mis. `useLogin`: simpan ke session store + clear cache
  query. Memanggil **infrastructure**, memakai **domain**.
- **Infrastructure**: fungsi `*Request` / client API concurrency - akses
  `axios` (`client`/`authClient`), mapping query params, tipe envelope.
  TIDAK tahu React.
- **Presentation**: halaman `*-page.tsx` + komponen. Konsumsi hook
  application, render antd, kirim navigasi. TIDAK tahu axios langsung dan
  TIDAK memegang akses token/session.

Aturan keras (analog Section 2 & 4 api docs):

- **Halaman TIDAK pernah memanggil `client.get(...)` langsung** - selalu
  lewat infrastructure + application. Clean test, clean swap.
- **Infrastructure TIDAK pernah mutasi UI state / localStorage**
  (pengecualian: session store di `shared/auth/` - infrastruktur web).
  Mutasi sesi hanya lewat use case di `application/`.
- **Domain TIDAK mengimpor React/antd/axios** - murni TypeScript, bisa
  di-unit-test tanpa runtime browser.

Antar fitur berkomunikasi lewat `shared/` (bukan saling import internal) -
mis. `features/audit` dan `features/words` DUA-DUANYA memakai
`shared/hooks/use-cursor-list` + `shared/api/types.CursorPage`.

---

## 3. Struktur Folder - Feature-Based + Clean Architecture

Pendekatan sama dengan backend: **bungkus per fitur** (`features/<fitur>/`),
di dalam tiap fitur terapkan lapisan domain/application/infrastructure/
presentation. Alasan identik: file dari fitur berbeda tidak tercampur dalam
folder flat, cakupan satu fitur langsung kelihatan, rawan konflik rendah.

```
admin/src/
├── main.tsx                          # composition root UI (Section 8)
├── app/
│   ├── router.tsx                    # route tree TanStack Router + guard (Section 8)
│   └── query-client.ts               # instance QueryClient global
├── styles/
│   └── index.css                     # styling layout (base/console), token di main.tsx
├── test/
│   └── setup.ts                      # polyfill sessionStorage Utk tes unit (Section 15)
│
├── shared/                           # HANYA yang benar-benar lintas fitur
│   ├── api/
│   │   ├── client.ts                 # instance axios + interceptor auth/refresh (Section 10)
│   │   ├── refresh.ts                # single-flight refresh token
│   │   ├── error.ts                  # normalisasi error (ApiError, AuthExpiredError)
│   │   └── types.ts                  # envelope + cursor meta (kontrak Section 13 API)
│   ├── auth/
│   │   ├── session.ts                # session store in-memory observable (Section 9)
│   │   └── use-auth.ts               # hook reaktif ke session store
│   ├── components/
│   │   ├── data-table.tsx            # bridge TanStack Table → antd <Table>
│   │   ├── page-header.tsx           # judul + subjudul + aksi kanan standar
│   │   ├── page-loading.tsx          # Spin halaman penuh, selalu di tengah (Section 18)
│   │   └── user-info-modal.tsx       # popup profil publik (tanpa User ID)
│   ├── config/
│   │   └── env.ts                    # baca VITE_* env (Section 11)
│   ├── i18n/                         # registry + katalog JSON (CONSOLE-I18N.md)
│   ├── hooks/
│   │   ├── use-cursor-list.ts        # infinite query cursor (Section 13)
│   │   ├── use-debounced-value.ts    # debounce input pencarian
│   │   └── use-public-profile.ts     # GET /users/:username untuk UserInfoModal
│   ├── users/
│   │   └── public-profile.ts         # tipe + mapper profil publik (tanpa User ID)
│   ├── layouts/
│   │   ├── base-layout.tsx           # layout publik / pra-auth (login)
│   │   ├── console-layout.tsx        # layout terproteksi (sider + header + content)
│   │   └── not-found-page.tsx        # halaman 404
│   ├── utils/
│   │   ├── cursor.ts                 # getNextCursor() - helper murni pagination
│   │   └── jwt.ts                    # decode klaim JWT (restore sesi)
│   └── __tests__/                    # tes unit shared (Section 15)
│       ├── api/error.test.ts
│       ├── api/refresh.test.ts
│       ├── auth/session.test.ts
│       ├── users/public-profile.test.ts
│       └── utils/
│           ├── cursor.test.ts
│           └── jwt.test.ts
│
└── features/
    ├── auth/
    │   ├── domain/
    │   │   └── user.ts                # User, UserRole, LoginCredentials
    │   ├── application/
    │   │   ├── use-login.ts           # login → signIn session + clear query cache
    │   │   ├── use-logout.ts          # revoke refresh token + clear sesi
    │   │   └── try-restore-session.ts # restore sesi saat hard reload
    │   ├── infrastructure/
    │   │   └── auth-api.ts            # loginRequest / logoutRequest
    │   └── presentation/
    │       └── login-page.tsx         # form login (base layout)
    │
    ├── words/
    │   ├── domain/word.ts             # WordListItem, status/tipe konstanta
    │   ├── application/use-word-list.ts   # list kata (q, type, verified, cursor)
    │   ├── infrastructure/word-api.ts     # GET /words/search
    │   └── presentation/words-page.tsx   # tabel kata + filter + pencarian
    │
    ├── contributions/
    │   ├── domain/contribution.ts     # ContributionListItem + konstanta status
    │   ├── application/use-contribution-list.ts
    │   ├── infrastructure/contribution-api.ts  # GET /admin/contributions
    │   └── presentation/contributions-page.tsx # antrean review
    │
    ├── audit/
    │   ├── domain/audit-log.ts        # AuditLogListItem + warna tag aksi
    │   ├── application/use-audit-log-list.ts
    │   ├── infrastructure/audit-api.ts           # GET /admin/audit-logs
    │   └── presentation/audit-logs-page.tsx      # jejak audit (admin/root)
    │
    └── dashboard/
        └── presentation/dashboard-page.tsx      # landing + pintu cepat menu
```

**Aturan penting:**

- **Fitur "berscreaming"**: nama folder fitur langsung menyatakan domain
  (`words`, `auth`, `audit`, ...) - bukan pola arsitektur (`pages/`,
  `hooks/`, `services/` di root).
- Fitur sederhana (mis. `dashboard` yang statis) boleh TIDAK punya
  domain/infrastructure - cukup `presentation/`. Tetap jangan menambah
  folder kosong.
- **Tidak ada file "layanan halaman" di root** - setiap fitur mandiri.
- `shared/` berisi barang lintas fitur yang sudah dipakai minimal dua kali
  (atau berkaitan langsung dengan infrastruktur global: auth, http, env).

---

## 4. Contoh Alur Data

### Alur Login

```
login-page.tsx (Form antd)
   → useLogin()            features/auth/application/use-login.ts
   → loginRequest()        features/auth/infrastructure/auth-api.ts (authClient)
       POST /api/v1/auth/login  { email, password, client_type: 'web' }
   ← { success: true, data: { access_token, expires_in, user } }
   → sessionStore.signIn(accessToken, expiresIn, user)     [shared/auth/session.ts]
   → queryClient.clear()   (data sesi sebelumnya tidak valid)
   → navigate('/dashboard')
```

### Alur List (contoh: kata)

```
words-page.tsx (Select filter + Input pencarian + DataTable)
   → useWordList(args)     features/words/application/use-word-list.ts
   → useCursorList()       shared/hooks/use-cursor-list.ts  (useInfiniteQuery)
   → listWordsRequest()    features/words/infrastructure/word-api.ts (client)
       GET /api/v1/words/search?q=&word_type=&is_verified=&limit=20&cursor=
   ← { success: true, data:[...], meta:{ limit, next_cursor, has_more } }
   → halaman render DataTable; tombol "Muat lagi" → fetchNextPage(next_cursor)
```

### Alur Refresh Token (otomatis, transparan)

```
Request data → 401 TOKEN_EXPIRED
   → interceptor client.ts  → performRefresh() (single-flight, shared/api/refresh.ts)
       POST /api/v1/auth/refresh   (httpOnly cookie terkirim otomatis)
   → update token sesi → retry request asli dengan token baru
   → gagal (refresh token invalid) → sessionStore.clear() + navigasi /login
```

---

## 5. Konvensi Penamaan File

Mengikuti semangat Section 5 api-base-stack (kebab-case, deskriptif, akhiran
sufiks perannya):

| Peran                | Konvensi                          | Contoh                                  |
| -------------------- | --------------------------------- | --------------------------------------- |
| Halaman utama fitur  | `*-page.tsx`                      | `words-page.tsx`, `login-page.tsx`    |
| Komponen halaman     | `*-page.tsx` di `presentation/`   | `contributions-page.tsx`               |
| Hook aplikasi        | `use-*.ts` di `application/`    | `use-login.ts`, `use-word-list.ts`    |
| Akses API            | `*-api.ts` di `infrastructure/` | `word-api.ts`, `auth-api.ts`           |
| Domain/tipe          | `<nama>.ts` di `domain/`        | `word.ts`, `contribution.ts`           |
| Helper murni         | di `utils/`                       | `cursor.ts`, `jwt.ts`                  |
| Komponen shared      | `*-name.tsx` di `components/`   | `data-table.tsx`, `page-header.tsx`, `page-loading.tsx` |
| Layout               | `*-layout.tsx`                    | `base-layout.tsx`, `console-layout.tsx`|
| Store/state infra    | `session.ts`, `use-auth.ts`     | di `shared/auth/`                      |
| Tes unit             | `*.test.ts` di `__tests__/`     | `session.test.ts`, `cursor.test.ts`    |

Pola nama fungsi:

- Fungsi request HTTP: `<action>Request` (`listWordsRequest`, `loginRequest`)
  - jelas itu I/O.
- Hook: `use<Nama>` (`useLogin`, `useCursorList`, `useAuth`).
- Komponen: PascalCase (`WordsPage`, `DataTable`, `PageHeader`).
- Tipe data API: akhiran `ListItem` untuk item tabel (`WordListItem`),
  akhiran `Params` untuk argumen list (`ListWordsParams`).

---

## 6. Yang Perlu Disiapkan Sebelum Coding Dimulai

Status: **semua dasar sudah diimplementasikan**. Checklist awal yang disiapkan:

- [x] Scaffold Vite + React 19 + TS (package.json, tsconfig, vite, vitest, eslint)
- [x] Shared infra: axios client + interceptor refresh/retry, session store,
      env config, error normalization
- [x] Dua layout: `base-layout` (login) & `console-layout` (area auth)
- [x] Router TanStack Router + guard auth + `main.tsx` composition root
- [x] Fitur auth end-to-end (login page, hook, session restore saat reload)
- [x] Fitur words: TanStack Table + cursor pagination + pencarian
- [x] Fitur contributions (antrean review) & audit-logs (role admin/root)
- [x] Dashboard + breadcrumb menu
- [x] Vitest setup + unit test (session, cursor helper, jwt, error, refresh)
- [x] Build + typecheck + lint + test hijau

Prasyarat untuk menambah fitur BARU:

- Baca kontrak endpoint di `docs/api/*` **sebelum** menulis domain model
- Pastikan pola endpoint: `GET .../search` atau `GET .../admin/...` list
  memakai cursor pagination (Section 13) → pakai `useCursorList`
- Kalau halaman list: definisikan kolom dengan `createColumnHelper` TanStack
  → render lewat `DataTable` (jangan render antd Table manual)
- Kalau halaman detail/form menunggu data pertama: `return <PageLoading />`
  (Section 18). Jangan `return <Spin />` telanjang.
- Login/jangan panggil `client` untuk endpoint auth (pakai `authClient`)
- Tambahkan Bruno `.bru`/**docs** kalau endpoint baru (bagian repo `api`/`http`)

---

## 7. Dua Layout Dasar

UI admin dibagi **dua layout** yang diekspresikan sebagai layout route
TanStack Router (Section 8):

### Base Layout (`shared/layouts/base-layout.tsx`)

Untuk halaman **publik / pra-auth**. Berisi brand (logo + nama aplikasi +
"Console Admin"), `Outlet`, dan footer nama aplikasi dari env. Dipakai:
`/login`.

### Console Layout (`shared/layouts/console-layout.tsx`)

Untuk **semua halaman terautentikasi**. Struktur antd `Layout`:

- **Sider** (dark, collapsible): brand + `Menu` navigasi:
  Dashboard `/dashboard`, Kata `/words`, Antrean Review `/contributions`,
  Audit Log `/audit-logs`, Laporan Masalah `/bug-reports` (admin/root).
- **Header**: `Breadcrumb` (dari `pathname` + `BREADCRUMB_LABELS`) dan
  dropdown profil user (avatar + username + tag role + menu "Keluar").
- **Content**: card putih berisi `Outlet`.

Aturan:

- Menu/route baru: tambahkan SEKALIGUS ke `MENU_ROUTES` di
  `console-layout.tsx` DAN `BREADCRUMB_LABELS` (kalau segmen berbeda).
- Breadcrumb diambil dari segmen pertama path - untuk nested route (mis.
  `/words/:id/detail`) tambahkan label segmen di `BREADCRUMB_LABELS`.
- Guard navigasi utama ada di router (`beforeLoad`); layout punya guard
  reaktif tambahan (efek ke `/login` saat sesi mati di tengah pemakaian).

---

## 8. Router (TanStack Router) & Auth Guard

Route tree didefinisikan **manual** di `src/app/router.tsx` (bukan
file-based) - satu file pusat, mudah dibaca, tanpa codegen. Pola:

```
rootRoute                     beforeLoad: tryRestoreSession()  ← restore sesi saat reload
├── /                        redirect cerdas (login? → /login : /dashboard)
├── base-layout  (id)        layout publik
│   └── /login               beforeLoad: kalau sudah login → redirect /dashboard
└── console-layout (id)      layout terproteksi
    ├── /dashboard
    ├── /words
    ├── /contributions
    └── /audit-logs
                            notFoundComponent: NotFoundPage (halaman 404)
```

### Guard Auth

- Root `beforeLoad` menjalankan `tryRestoreSession()` - **satu-satunya
  tempat restore**, idempotent + single-flight (biaya nol kalau sesi sudah
  aktif). Karena parent `beforeLoad` selalu jalan duluan, state sesi sudah
  benar sebelum guard turunan dievaluasi.
- `console-layout.beforeLoad`: `!isAuthenticated → redirect /login`.
- `login.beforeLoad`: `isAuthenticated → redirect /dashboard`.
- Guard role PER-FITUR di halaman (mis. audit = admin/root) - router cukup
  membatasi "login atau belum", bukan wewenang.

### Pendaftaran di Composition Root (`main.tsx`)

```tsx
setOnAuthExpired(() => router.navigate({ to: '/login' }));  // refresh gagal

createRoot(...).render(
  <QueryClientProvider client={queryClient}>
    <ConfigProvider locale={idID} theme={{ token: { colorPrimary: '#1677ff', borderRadius: 8 } }}>
      <AntdApp>            {/* agar message/modal antd terpakai di mana pun */}
        <RouterProvider router={router} />
      </AntdApp>
    </ConfigProvider>
  </QueryClientProvider>,
);
```

### Aturan Wajib

- Path baru **wajib** didaftarkan di `router.tsx` dan menu
  `console-layout.tsx` (kalau halaman konsol).
- Guard di router HANYA soal autentikasi; **jangan** letakkan logika bisnis
  di `beforeLoad`.
- `declare module '@tanstack/react-router' Register` sudah dipasang -
  `navigate({ to: ... })` jadi type-checked terhadap route yang ada.

---

## 9. Session & Keamanan Token

Mengikuti `docs/api/00-api-auth.md` & Section 12 api docs. Prinsip inti:

- **`access_token` HANYA di memory** (module-level session store) - TIDAK
  pernah di localStorage/sessionStorage. XSS di halaman = token tetap aman.
- **`refresh_token` hidup di httpOnly cookie** yang dikelola browser -
  frontend tidak pernah melihat/menyimpannya. `withCredentials: true` di
  axios memastikan cookie ikut terkirim (juga saat lintas origin).
- Hard reload → access token hilang → `tryRestoreSession()` memanggil
  `POST /auth/refresh` (cookie otomatis terkirim) → token baru → user
  di-rebuild dari klaim JWT + cache identitas.

### Session Store (`shared/auth/session.ts`)

Store in-memory **observable** (mirip mini store, tanpa library state):

| State        | Isi                                             |
| ------------ | ------------------------------------------------ |
| `accessToken`| token akses saat ini (memory only)               |
| `expiresAt`  | epoch ms - token dianggap kadaluarsa setelah ini |
| `user`       | `{ id, username, role }`                         |

Method: `signIn` / `updateAccessToken` / `clear` / `isAuthenticated` /
`getSnapshot` / `subscribe`. Komponen memakainya via `useAuth()`
(`useSyncExternalStore`) - reaktif tanpa render ulang global.

**Cache identitas non-sensitif** (`id`/`username`/`role`) boleh di
sessionStorage (`restoreSessionUser()`) - dibutuhkan supaya header profil
benar tampil saat reload sambil menunggu refresh. Token TIDAK PERNAH
disentuh cache ini.

### Aturan Wajib

- Hanya `application/use-*.ts` yang memanggil `sessionStore.signIn/clear`
  (mis. `use-login.ts`, `use-logout.ts`) - halaman/layout tidak boleh.
- `shared/api/client.ts` + `shared/auth/use-auth.ts` boleh **membaca** state
  (interceptor menempel token; layout membaca user).
- Refresh gagal → interceptor lakukan `sessionStore.clear()` + panggil
  handler global `setOnAuthExpired` (terdaftar di `main.tsx`) → navigasi
  `/login`.

---

## 10. Axios Client & Interceptor (Refresh/Retry)

`shared/api/client.ts` membuat **dua instance** dengan base config yang sama
(`baseURL = env.apiBaseUrl`, `timeout` 15s, `withCredentials`, JSON headers):

| Instance      | Dipakai untuk                               | Interceptor auth |
| ------------- | ------------------------------------------- | ---------------- |
| `authClient`  | login / refresh / logout                    | ❌               |
| `client`      | SEMUA request data aplikasi                 | ✅               |

Pemisahan ini mencegah refresh berantai: request refresh tidak boleh memicu
interceptor 401 → refresh lagi (loop tak terbatas).

### Interceptor Request

`client` menyisipkan header `Authorization: Bearer <access_token>` dari
session store saat ada token.

### Interceptor Response (auto refresh + retry)

1. Response normal → diteruskan.
2. `401` + url bukan `/auth/*` + `_retried` belum set + sesi aktif →
   lakukan `performRefresh()`.
3. `performRefresh()` memakai **single-flight** (`shared/api/refresh.ts`):
   banyak request 401 paralel hanya memicu SATU `POST /auth/refresh`
   (mencegah rotasi token dieksekusi 2× - rotasi kedua dengan cookie bekas
   = 401).
4. Setelah token baru: `_retried = true`, header diperbarui, request asli
   di-retry.
5. Refresh gagal karena token invalid/expired → `sessionStore.clear()` +
   `onAuthExpired()` (navigasi login) + reject `AuthExpiredError`.
6. Gagal bukan karena token (mis. jaringan) → sesi dipertahankan, request
   asli gagal normal.

`performRefresh()` juga dipakai `try-restore-session.ts` saat boot - satu
jalur refresh untuk semua.

---

## 11. Env & Konfigurasi per Environment

`shared/config/env.ts` adalah **satu-satunya** tempat baca `import.meta.env`
(dilarang baca `import.meta.env` di file lain):

```ts
export const env = {
  appName: import.meta.env.VITE_APP_NAME ?? 'Kamus Sambas - Admin Console',
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL ?? 'https://sambasku-staging.iamutaki.com/api/v1',
};
```

### File env per mode (Vite `--mode`)

| Mode          | File              | `VITE_API_BASE_URL`                                     | Dipakai |
| ------------- | ----------------- | ------------------------------------------------------ | ------- |
| development   | `.env.development`| `https://sambasku-staging.iamutaki.com/api/v1` (Dev)   | `pnpm dev` |
| staging       | `.env.staging`    | `https://sambasku-staging.iamutaki.com/api/v1` (Staging)| `pnpm build:staging` |
| production    | `.env.production` | `https://sambasku.iamutaki.com/api/v1`                  | `pnpm build` |

`.env.example` memuat template lengkap + penjelasan (di-commit). File
`.env*` non-example ada di `.gitignore`.

### Aturan Wajib

- `VITE_*` hanya variabel **non-secret** (ter-bundle ke client). Secret apa
  pun tidak boleh ada (backend hanya lewat `wrangler secret`/env server).
- Path API relatif terhadap `VITE_API_BASE_URL` (sudah termasuk `/api/v1`) -
  mis. `/auth/login`, `/words/search`, `/admin/audit-logs`.
- Prod/Staging biasanya menghadap reverse proxy menuju backend (aspek CORS
  + cookie sameSite dijelaskan di `.env.example`).

---

## 12. React Query Strategy

`@tanstack/react-query` v5 menangani seluruh data fetching.

### QueryClient Global (`src/app/query-client.ts`)

```ts
new QueryClient({
  defaultOptions: {
    queries: { staleTime: 30_000, refetchOnWindowFocus: false, retry: 1 },
  },
});
```

### Pola per Fitur

Setiap fitur punya hook di `application/` (mis. `use-word-list.ts`):

```ts
export function useWordList(args: UseWordListArgs = {}) {
  return useCursorList<WordListItem>({
    queryKey: ['words', { q, wordType, isVerified }],
    fetcher: (pageParam, signal) => listWordsRequest({ ... }, signal),
    enabled,
  });
}
```

- **`queryKey` memuat SEMUA filter** - filter berubah ⇒ list fresh dari
  halaman 1 (kontrak `useCursorList`). Jangan gunakan key tanpa filter.
- `signal` dari TanStack Query: request basi otomatis di-abort (mis. user
  mengetik query baru) - mencegah race response.
- Mutation (login/logout) memakai `useMutation`; `useLogin` pada success
  memanggil `queryClient.clear()` (data user lama tidak valid).

### Aturan Wajib

- Query cuma dari hook aplikasi fitur - halaman tidak pernah bikin
  `useQuery` dengan fetcher inline.
- Jangan duplicate queryKey antar fitur; prefix nama fitur (`'words'`,
  `'contributions'`, `'audit-logs'`).
- Aborsi: selalu teruskan `signal` ke request yang mendukung (list).

---

## 13. Cursor Pagination, Tabel & Pencarian

### Hook `useCursorList` (`shared/hooks/use-cursor-list.ts`)

Satu hook baku untuk SEMUA endpoint list cursor (kontrak Section 13 API:
`?limit=&cursor=` + `meta.has_more`). Dibangun di atas `useInfiniteQuery`:

- `getNextPageParam` ← `getNextCursor(meta)` (helper murni
  `shared/utils/cursor.ts`, ter-unit-test).
- `items` = gabungan semua halaman (`flatMap`).
- Return API: `{ items, hasMore, loadMore, isLoading, isFetching,
  isFetchingNextPage, isError, error, refetch }`.

Pola UI "Muat lagi" (bukan nomor halaman):

```tsx
const { items, hasMore, loadMore, isLoading, refetch } = useWordList({ q, ... });
<DataTable ... loading={isLoading} />
{hasMore ? <Button onClick={() => loadMore()}>Muat lagi</Button> : null}
```

### Bridge Tabel: TanStack Table → antd (`shared/components/data-table.tsx`)

Kolom didefinisikan **headless di halaman** dengan `createColumnHelper`
(header, accessor, cell render, size) - state & cell render milik TanStack.
`DataTable` menerjemahkannya ke antd `<Table>` (render DOM). Halaman tidak
perlu menyentuh prop `columns` antd.

```tsx
const columns = useMemo(() => [
  columnHelper.accessor('lemma', { header: 'Kata Sambas', size: 220, cell: (i) => <Text strong>{i.getValue()}</Text> }),
  columnHelper.accessor('status', { header: 'Status', cell: (i) => <Tag color={...}>{...}</Tag> }),
  columnHelper.display({ id: 'actions', header: 'Aksi', cell: () => <Button type="link">Detail</Button> }),
], [deps]);

const table = useReactTable({ data: items, columns, getRowId: (r) => String(r.id), manualPagination: true });
<DataTable table={table} rowKey={(r) => String(r.id)} loading={...} />
```

Aturan:
- `getRowId` & `rowKey` WAJIB `String(record.id)` (ULID - Section 19 API).
- `manualPagination: true` (pagination dikendalikan cursor, bukan antd).
- Kolom kustom ukuran lewat `columnHelper.accessor(..., { size })`;
  `size: 150` dianggap default antd (tidak dipaksa).
- Kolom aksi di ujung tabel (display column `id: 'actions'`) WAJIB
  `meta: { fixed: 'right' }` - di-pin ke ujung kanan sehingga tombol aksi
  (mis. "Detail", "Review") selalu terlihat dan bisa ditekan **tanpa perlu
  scroll horizontal** saat tabel melebihi lebar container. `scroll.x` di
  `DataTable` sudah diset otomatis; kolom fixed butuh `width` yang
  didefinisikan (pakai `size`).
- Kolom kunci pengenal yang tak boleh hilang saat scroll (mis. lemma/ID)
  pakai `meta: { fixed: 'left' }`.
- Kolom sekunder yang boleh hilang di layar sempit ditandai
  `meta: { responsive: [...] }` (mis. `['lg']` = hanya tampil >= lg) -
  kombinasi dengan `fixed` jangan dipakai di kolom yang sama (kolom fixed
  selalu tampil di semua breakpoint).
- Sel yang menampilkan gambar konten mengikuti **Preview gambar (wajib)**
  di atas: `Image` antd (+ `Image.PreviewGroup` bila lebih dari satu),
  bukan tautan tab baru.

### Kolom Aksi Tabel - WAJIB Icon-only

**Referensi kanonik:** kolom Aksi di `words-page.tsx` (`Button type="link"`
+ ikon + `Tooltip`, tanpa teks anak). Semua list admin WAJIB mengikuti
pola yang sama (Komentar, Review, Search Miss, Moderasi Vote, Pengguna, …).

Tombol di kolom aksi tabel (`meta: { fixed: 'right' }`) memakai **ikon
saja tanpa label teks** - `Button type="link" icon={<.../>}` dibungkus
`<Tooltip title="...">`. Label teks di kolom fixed memakan lebar pin,
membuat baris tampil “benda sendiri” (primary/ghost/small tidak selaras),
dan membingungkan dibanding daftar lain.

#### Wajib

- `type="link"` (satu-satunya variant di kolom aksi).
- Hanya `icon={...}` - **tanpa children teks** (`Simpan`, `Reset`, dsb.).
- Setiap aksi dibungkus `<Tooltip title="<label Indonesia>">` (antd v6
  tidak punya prop `tooltip` di Button).
- Destructive (`Hapus` / `Tolak` / `Reset`) → `danger` + biasanya
  `Popconfirm` (kecuali aksi yang sudah pakai `modal.confirm`).
- `Flex gap={0} wrap={false} align="center"` untuk deret ikon.

#### Dilarang di kolom aksi

- `type="primary"` / `ghost` / `default` / `dashed`
- `size="small"` (ukuran default `link` sudah cukup)
- Teks sebagai children Button
- `MoreOutlined` / dropdown overflow untuk menyembunyikan aksi baris

#### Ikon standar (konsisten lintas fitur)

| Aksi              | Ikon                 | Catatan                                      |
| ----------------- | -------------------- | -------------------------------------------- |
| Detail            | `EyeOutlined`        | Atau `ToolOutlined` bila “buka review”        |
| Ubah / Edit       | `EditOutlined`       |                                              |
| Hapus             | `DeleteOutlined`     | `danger` + `Popconfirm`                      |
| Terbitkan/Approve | `CheckOutlined`      | antrean review / komentar                    |
| Tolak / Reject    | `CloseOutlined`      | `danger`                                     |
| Buat dari sumber  | `PlusOutlined`       | mis. Search Miss → buat kata                 |
| Simpan (inline)   | `SaveOutlined`       | mis. ubah role user                          |
| Dismiss / buang   | `ToolOutlined` atau `StopOutlined` | soft-delete panel             |

> **Bool / `is_*`:** jangan masukkan ke kolom aksi sebagai tombol ikon.
> Pakai kolom `Switch` tersendiri - lihat **§13 Field Boolean → Toggle**.

#### Contoh (salin pola Kata)

```tsx
columnHelper.display({
  id: 'actions',
  header: 'Aksi',
  size: 140,
  meta: { fixed: 'right' },
  cell: (info) => (
    <Flex gap={0} wrap={false} align="center">
      <Tooltip title="Detail">
        <Button
          type="link"
          icon={<EyeOutlined />}
          onClick={() => navigate({ to: '/words/$id', params: { id: info.row.original.id } })}
        />
      </Tooltip>
      <Tooltip title="Ubah">
        <Button
          type="link"
          icon={<EditOutlined />}
          onClick={() => navigate({ to: '/words/$id/edit', params: { id: info.row.original.id } })}
        />
      </Tooltip>
      <Popconfirm title="Hapus?" okText="Hapus" okButtonProps={{ danger: true }} cancelText="Batal">
        <Tooltip title="Hapus">
          <Button type="link" danger icon={<DeleteOutlined />} />
        </Tooltip>
      </Popconfirm>
    </Flex>
  ),
})
```

- Rule ini **KHUSUS kolom aksi tabel**. Tombol di luar tabel (PageHeader,
  action bar form, “Tambah Kata”, “Muat ulang”) tetap boleh berlabel teks
  (+ ikon opsional).

### Field Boolean / `is_*` - WAJIB Toggle (`Switch`)

Field boolean API (`is_verified`, `is_primary`, flag on/off, status yang
hanya punya dua keadaan seperti tayang/tidak) di UI admin **diutamakan**
sebagai **`Switch`**, bukan sepasang tombol Verifikasi / Batal Verifikasi
di kolom aksi.

**Mengapa:** on/off langsung terbaca; reverse tanpa Popconfirm ganda;
selaras pola kolom **Tayang** yang sudah ada di daftar kata.

#### Wajib

- Satu kolom (atau kontrol di header detail) per flag - label singkat
  (`Tayang`, `Terverifikasi`).
- `Switch` `size="small"` di tabel; di header detail boleh default + label
  teks di samping (`<Text type="secondary">…</Text>`).
- `checked={row.is_xxx}` (atau derived, mis. `status === 'published'`).
- `loading` per-baris saat mutasi jalan.
- Role tanpa izin: `disabled` (tetap tampilkan state, jangan sembunyikan).
- Prasyarat bisnis (mis. verifikasi hanya jika sudah tayang): `disabled` +
  `Tooltip` menjelaskan kenapa.

#### Dilarang

- Tombol ikon / `Popconfirm` berpasangan “aktifkan” + “nonaktifkan” untuk
  flag boolean di list/detail (kecuali aksi destruktif irreversible yang
  memang butuh konfirmasi - itu bukan toggle state).
- Menyembunyikan Switch lalu hanya menampilkan Tag; Tag boleh **pelengkap**
  (badge di body detail), kontrol tetap Switch.

#### Contoh (daftar kata)

```tsx
columnHelper.display({
  id: 'verified',
  header: 'Terverifikasi',
  size: 120,
  cell: (info) => {
    const row = info.row.original;
    const canToggle = canModerate && row.status === 'published';
    return (
      <Tooltip title={!canToggle && canModerate ? 'Hanya kata tayang…' : undefined}>
        <Switch
          checked={row.is_verified}
          size="small"
          disabled={!canToggle}
          loading={verifyingId === row.id}
          onChange={(next) => onToggleVerified(row.id, row.lemma, next)}
        />
      </Tooltip>
    );
  },
})
```

Referensi: `words-page.tsx` (kolom Tayang + Terverifikasi),
`word-detail-page.tsx` (Switch di PageHeader extra).

- Filter di atas tabel: gunakan `Select`+`useDebouncedValue` untuk input
  teks (debounce 300ms), tombol "Muat ulang" panggil `refetch()`.

---

## 14. Error Handling & Normalisasi

`shared/api/error.ts` menyatukan SEMUA bentuk error menjadi `ApiError`
untuk UI:

```ts
class ApiError extends Error {
  status; errorCode; details;       // dari envelope error backend
  fieldErrors(): Record<string, string>   // details → map field→pesan
}
class AuthExpiredError extends Error {}   // sesi mati → wajib ke /login
normalizeError(err, fallbackMessage?)     // satu titik normalisasi
```

Pemetaan:

| Sumber                              | Hasil                                |
| ----------------------------------- | ------------------------------------ |
| Envelope error backend (`success:false`) | `ApiError(status, error_code, message, details)` |
| Timeout (`ECONNABORTED`)            | `ApiError(0,'TIMEOUT_ERROR', fallback)` |
| Jaringan/lain (`isAxiosError`)      | `ApiError(0,'NETWORK_ERROR', fallback)` |
| Cancel                             | `ApiError(0,'REQUEST_CANCELLED')`    |
| Not dikenal                        | `ApiError(0,'UNKNOWN_ERROR', fallback)` |
| Refresh gagal 401                   | `AuthExpiredError` (+ navigasi login) |

**UI TIDAK membocorkan detail teknis** - `normalizeError` hanya membaca
`message` dari backend (Bahasa Indonesia, ramah). Stack trace tidak pernah
ditampilkan.

Pemakaian di halaman:

```tsx
if (isError) <Alert type="error" message="Gagal memuat data" description={error?.message} />
```

Login form memakai `ApiError.fieldErrors()` untuk inject error inline
(`form.setFields`). Aturan: semua blok error di komponen memakai
`error?.message` hasil normalisasi (sudah antd `Alert`/`message`), bukan
string bebas.

---

## 15. Testing (Vitest)

Unit test berjalan cepat dengan **environment node** (`vitest.config.ts`);
jangan import komponen React yang butuh DOM (belum ada @testing-library -
fokus ke logika murni: session, helper, normalisasi error, single-flight).

### Struktur

```
src/shared/__tests__/
├── api/error.test.ts       # normalizeError & class ApiError
├── api/refresh.test.ts     # single-flight refresh (1 kiriman utk N pemanggil)
├── auth/session.test.ts    # sessionStore + userFromJwtClaims + cache identitas
├── utils/cursor.test.ts    # getNextCursor (has_more/next_cursor)
└── utils/jwt.test.ts       # decodeJwtClaims
```

Fitur (`src/features/*/__tests__/`) menyusul mengikuti pola yang sama
(nama: `src/features/<fitur>/__tests__/unit/<use-case>.test.ts` - analog
Section 10 API).

### Setup (`src/test/setup.ts`)

Environment node tidak punya `sessionStorage` - polyfill in-memory minimal
diberikan supaya perilaku caching identitas (`session.ts`) bisa diuji.

### Aturan Wajib

- Setiap **helper murni baru** (`utils/*`, logika application tanpa React)
  wajib minimal 1 unit test.
- Setiap **API normalisasi/error** baru wajib dicover (envelope 4xx, timeout,
  jaringan, unknown).
- Tambahkan tes HANYA untuk logika - jangan menunggu DOM/network beneran.
- Command: `pnpm test` (run), `pnpm test:watch`, `pnpm test:unit`.

---

## 16. Lint, Typecheck & Build

| Command                    | Fungsi                                              |
| -------------------------- | --------------------------------------------------- |
| `pnpm dev`                 | Vite dev server (port 5174)                          |
| `pnpm build`               | `tsc -b` + `vite build --mode production`           |
| `pnpm build:staging`       | build mode staging                                   |
| `pnpm typecheck`           | `tsc -b` (noEmit)                                    |
| `pnpm lint` / `pnpm lint:fix` | ESLint + Prettier                                |
| `pnpm format`              | Prettier tulis `src/**/*.{ts,tsx}`                   |
| `pnpm test`                | Vitest run                                           |

**Aturan wajib sebelum prompt fitur dianggap selesai:** `typecheck`, `lint`,
`test`, dan `build` harus hijau. Lint hanya boleh menyisakan warning
`react-hooks/incompatible-library` pada `useReactTable` (dikenal, perilaku
TanStack Table) - bukan error.

**Catatan bundle:** antd + TanStack membuat bundle awal >500 kB (warning
vite `chunkSizeWarningLimit`). Upgrade path: route-level code splitting
(`lazy` route components / `dynamic import`) saat fitur bertambah - dicatat
di sini, belum diterapkan.

---

## 17. Responsive & Aturan Anti-Overflow di Layar Kecil

Konsol admin dipakai juga dari HP/tablet - setiap halaman WAJIB tidak
menimbulkan **scroll horizontal** di viewport 320px-768px. Prinsip:
**mobile-first** (susun untuk layar sempit dulu, perlebar bertahap dengan
breakpoint), bukan sebaliknya.

### Breakpoint yang Dipakai

Mengikuti antd Grid (semua komponen dihitung dari lebar **container**,
bukan viewport):

| Breakpoint | Min lebar | Maksud                                      |
| ---------- | --------- | ------------------------------------------- |
| `xs`       | < 576px   | HP portrait - baseline semua layout          |
| `sm`       | ≥ 576px   | HP landscape / tablet kecil                 |
| `md`       | ≥ 768px   | Tablet - naik grid form dari 1 ke banyak col |
| `lg`       | ≥ 992px   | Laptop - titik collapse default Sider        |
| `xl`/`xxl` | ≥ 1200/1600px | Layar lebar - kolom tabel boleh lebih banyak |

### Aturan Grid & Form

- Setiap `Row` di form memakai pola **`Col xs={24} md={...} lg={...}`** -
  `xs={24}` memaksa satu kolom penuh di HP, baru dibagi rata pada `md`/`lg`.
  JANGAN pakai `Col` tanpa `xs` (default `xs=24` memang aman, tapi perlebaran
  harus eksplisit supaya tidak kelewat).
- Contoh yang sudah benar (`create-word-page.tsx`): lemma `xs={24} md={12}
  lg={10}`, jenis entri `xs={24} md={6} lg={4}` - dsb.
- Ruas yang sempit di desktop (mis. `InputNumber` urutan, `Select` afiks)
  tetap `xs={24}` di HP; jangan paksa dua field berdampingan lebih dari
  ~140px dan hanya bilamana jelas muat.

### Aturan Action Bar (Tombol Aksi Form) - WAJIB

Tombol baris-baris form (mis. `Batal`, `Simpan sebagai Draft`,
`Simpan & Publikasikan`) paling rawan overflow karena teksnya panjang dan
ditaruh berdampingan dalam satu `Space` horizontal. Aturan keras:

- **`Space`/`Flex` horizontal berisi tombol boleh menumpuk (wrap) dan
  boleh lebih tinggi, TETAPI tidak boleh lebih lebar dari container.**
  Setiap tombol harus muat dalam satu baris sendirian.
- **Deteksi layar sempit dengan `Grid.useBreakpoint()`** (bukan prop
  responsif object - `Flex` antd v6 **belum** mendukung nilai responsif
  untuk `vertical`/`justify`/`gap`, itu CSS biasa).
- Layout HP (`!md`):
  - `Flex` diubah **`vertical`** (`flex-direction: column`) → info/peringatan
    naik ke baris sendiri, tombol di bawahnya.
  - Setiap tombol diberi **`block`** → full-width, menumpuk satu per baris.
    Mustahil overflow, dan area sentuh besar (aksesibilitas).
- Layout desktop (`md`): kembali ke baris semula - tombol inline kanan,
  `justify="space-between"`.
- **`<Space wrap>` selalu diset** sebagai jaring pengaman meski di desktop.
- Pola baku action bar (`create-word-page.tsx`):

```tsx
const { md } = Grid.useBreakpoint();

<Flex justify={md ? 'space-between' : 'flex-start'} vertical={!md} wrap gap={12} style={{ ... }}>
  <div>{peringatan ?? null}</div>
  <Space wrap style={{ width: md ? undefined : '100%' }}>
    <Button block={!md} onClick={() => navigate({ to: '/words' })}>Batal</Button>
    <Button block={!md} icon={<SaveOutlined />} loading={...} onClick={() => submit('draft')}>Simpan sebagai Draft</Button>
    <Button block={!md} type="primary" icon={<SendOutlined />} loading={...} onClick={() => submit('published')}>Simpan &amp; Publikasikan</Button>
  </Space>
</Flex>
```

### Aturan Tabel

- Lanjutkan lengkap dari **Section 13**: kolom aksi `meta: { fixed: 'right' }`,
  kolom pengenal `meta: { fixed: 'left' }`, kolom sekunder
  `meta: { responsive: [...] }` supaya layar sempit menampilkan field inti
  dulu. `DataTable` sudah menyetel `scroll.x` otomatis - tabel boleh
  scroll internal, halaman tidak boleh.
- Kolom aksi **WAJIB icon-only** (`type="link"` + `Tooltip`, tanpa teks
  anak) - lihat **§13 Kolom Aksi Tabel**. Referensi: `words-page.tsx`.
- Flag boolean / `is_*` **WAJIB `Switch`** (bukan tombol di kolom aksi) -
  lihat **§13 Field Boolean → Toggle**.
- Tabel BOLEH punya scroll horizontal internal; itu berbeda dengan halaman
  yang overflow. Pastikan memang tabelnya (bukan shell/layout) yang melebar.

### Aturan Layout & Teks Lainnya

- Padding `console-layout__content` sudah otomatis menyusut via media query
  di `styles/index.css` (≤768px → `16px 12px`, ≤480px → `12px 8px`).
  Jangan menimpa padding konten dengan nilai tetap besar di komponen.
- Hindari `white-space: nowrap` pada label/teks panjang (kecuali brand
  Sider yang sudah tersembunyi saat collapsed). Teks panjang biarkan wrap.
- `PageHeader` + tombol aksi kanan: pada layar sempit pastikan aksi turun
  ke baris sendiri, bukan ditaruh sejajar samping judul.
- `Space`/`Flex` dengan banyak anak: selalu sertakan `wrap` dan uji nilai
  minimum anak paling lebar sendirian.

### Aturan Verifikasi (Checklist)

Sebelum prompt fitur dianggap selesai, verifikasi responsif pada lebar:
**320px, 375px, 390px, 768px, 1024px** (devtools device mode):

- [ ] Tidak ada scroll horizontal - `document.documentElement.scrollWidth
      <= innerWidth` (kecuali overflow internal tabel yang disengaja).
- [ ] Kolom aksi tabel: icon-only `type="link"` + `Tooltip` (tanpa
      `primary`/`ghost`/`size="small"`/teks anak) - selaras Kata.
- [ ] Field bool / `is_*` pakai `Switch` (bukan sepasang tombol aksi).
- [ ] Setiap tombol aksi baris form muat utuh & bisa ditekan (tap target
      ≥ 44px bila memungkinkan).
- [ ] Semua field form dalam satu kolom (`xs={24}`) di HP; label tidak
      terpotong.
- [ ] Sider otomatis collapse (di bawah `lg`), dan brand/title tidak
      meluber.
- [ ] Loading halaman penuh memakai `PageLoading` (spinner di tengah),
      bukan `<Spin />` telanjang (Section 18).

---

## 18. Loading Halaman (wajib center)

Loading halaman penuh (menunggu data pertama, sebelum header/isi tampil)
WAJIB memakai `PageLoading` di `shared/components/page-loading.tsx`.
Spinner **selalu di tengah** area konten, horizontal dan vertikal.
Kartu konten (`console-layout__card`) adalah flex column yang mengisi sisa
viewport di bawah header; `PageLoading` memakai `flex: 1` sehingga spinner
berada di tengah area itu tanpa overflow.

Referensi: `word-suggestion-detail-page.tsx` (Usul Edit), `word-detail-page.tsx`,
`contribution-detail-page.tsx`.

### Wajib

```tsx
const { data, isLoading, isError } = useWordSuggestionDetail(id);

if (isLoading) return <PageLoading tip="Memuat usulan…" />;
```

- Satu komponen shared. Jangan copy-paste `Flex` + `Spin` di tiap halaman.
- `tip` opsional (teks sekunder di bawah spinner, Bahasa Indonesia).
- Halaman detail, edit, dan form yang `isPending` / `isLoading` tanpa data
  yang bisa dirender: early-return `PageLoading`.

### Dilarang

- `return <Spin />` telanjang. Spin antd tanpa wrapper adalah inline dan
  nempel kiri-atas kartu konten.
- `Spin` halaman penuh tanpa `align="center"` + `justify="center"` + tinggi
  yang mengisi area konten.
- `Skeleton` sebagai pengganti loading **halaman penuh**. Skeleton hanya
  untuk bagian dalam halaman yang kerangkanya sudah ada.

### Bukan `PageLoading` (pola lain tetap)

| Konteks | Pola |
| --- | --- |
| Tabel list (`DataTable`) | Prop `loading` (overlay antd Table, sudah center di tabel) |
| Tombol / Switch / aksi baris | `loading={mutation.isPending}` |
| Bagian dalam halaman (komentar, vote, strip dashboard) | `Skeleton` lokal |
| Body Modal / Drawer | Center di body itu sendiri (pola KBBI picker), bukan `PageLoading` |

---

## 19. Modal info user (reusable)

Identitas di UI admin = **username**, bukan User ID. Popup profil memakai
`UserInfoModal` / `UserInfoLink` di
`shared/components/user-info-modal.tsx`.

```tsx
<UserInfoLink username={detail.username} />
```

Aturan:

- Klik username membuka modal `GET /api/v1/users/:username`.
- Isi modal: username, peran, verifikator, bergabung, statistik kontribusi.
- **Jangan** tampilkan `id` / `user_id` / `reviewed_by` di layar.
- Loading di body modal: `Flex` + `Spin` di tengah (pola KBBI picker),
  bukan `PageLoading` dan bukan `Spin` telanjang.
- Halaman review yang punya aktor (pemohon, reviewer, penyetuju) memakai
  tautan ini, bukan string username polos.

Referensi: `docs/admin/14-admin-verifier-application.md`,
`docs/api/19-api-profil-publik.md`.

---

## 20. i18n (multi-bahasa) - wajib untuk modul baru

Kontrak penuh: [`docs/admin/CONSOLE-I18N.md`](./CONSOLE-I18N.md).
Kode locale selaras web/mobile (`id`, `id-SBS`).

| Item | Aturan |
| --- | --- |
| Locale V1 | `id` (default), `id-SBS`; persist `localStorage` |
| URL | Tanpa prefix locale (beda dari web publik); state app |
| Ant Design | `ConfigProvider locale` dari map registry (`id_ID` fallback utk Sambas) |
| Katalog | JSON namespace di `shared/i18n/locales/{locale}/` via i18next |
| String UI | Menu, breadcrumb, Tooltip aksi, Form label lewat `t()` setelah port |
| Pesan API | Tampilkan `message` server apa adanya di V1 (jangan double-translate) |

Prioritas lebih rendah dari web SEO. Fitur baru: tambah key ke katalog
`id` (+ mirror `id-SBS`) bersamaan dengan chrome UI.

## 21. Referensi Terkait

- `docs/admin/CONSOLE-I18N.md` - kontrak multi-bahasa konsol
- `docs/web/WEB-I18N.md` - kanonik locale lintas klien
- `docs/api/api-base-stack.md` - acuan backend: envelope (Section 13),
  pagination (Section 13), auth (Section 12, 23), role (Section 22), audit
  (Section 21), ID ULID (Section 19)
- `docs/api/00-api-auth.md` - kontrak login/refresh/logout yang dipakai
  `features/auth`
- `docs/api/01-api-tambah-kata.md` - kontrak kata & `/words/search`
  (dipakai `features/words`)
- `docs/api/02-api-audit-logs.md` - kontrak `GET /admin/audit-logs`
  (dipakai `features/audit`)
- `docs/api/30-api-bug-reports.md` + `docs/admin/16-admin-bug-reports.md`
  - antrean Laporan Masalah, menu sejajar Audit Log
- `docs/api/03-api-kontribusi-verifikasi.md` - kontrak antrean review
  `GET /admin/contributions` (dipakai `features/contributions`)
 - `docs/api/40-api-admin-whatsapp.md` + `docs/admin/18-admin-whatsapp.md`
  - fitur WhatsApp (System > WhatsApp): test send, template, quota + log
- `docs/admin/admin-tambah-kata.md` - prompt fitur "tambah kata" (belum
  diimplementasi; ikuti pola base stack ini)
- `docs/dbdiagram.dbml` - skema database
- `ERROR_CODES.md` - katalog error code (source of truth pesan error)