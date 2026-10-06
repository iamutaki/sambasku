# SambasKu Web - Local SQLite Architecture Plan

## 1. Tujuan

Membangun SambasKu Web/PWA dengan pendekatan **local-first**, sehingga fitur dictionary tidak bergantung pada API atau database remote untuk operasi baca.

Stack target:

* React
* React Router
* TypeScript
* SQLite WASM
* OPFS
* Service Worker / PWA
* Static dataset
* Release metadata

Prinsip utama:

> **Browser memiliki salinan dataset dictionary sendiri dan melakukan query secara lokal.**

API hanya digunakan untuk fitur dinamis.

---

# 2. Scope

Dokumen ini khusus untuk aplikasi SambasKu Web.

Target platform:

```text
Desktop Browser
Mobile Browser
PWA
```

Framework:

```text
React
React Router
TypeScript
```

Storage:

```text
SQLite WASM
+
OPFS
```

---

# 3. Arsitektur

```text
                         SambasKu Web
                              │
                         React Router
                              │
                     ┌────────┴─────────┐
                     │                  │
                Dictionary          Dynamic
                     │                  │
                     ▼                  ▼
              Local SQLite             API
                     │                  │
                 SQLite WASM            │
                     │                  │
                    OPFS                │
                                        │
                               ┌────────┼────────┐
                               │        │        │
                              API1     API2     API3
```

Dictionary:

```text
React
 ↓
Use Case
 ↓
Repository
 ↓
SQLite WASM
 ↓
OPFS
```

Dynamic operation:

```text
React
 ↓
Use Case
 ↓
Repository
 ↓
API
```

---

# 4. Zero Dependency Principle

Setelah dataset berhasil tersedia di browser:

```text
Internet
   ↓
tidak diperlukan
```

untuk:

* search
* dictionary detail
* meaning
* synonym
* translation
* example
* browsing dictionary

Browser dapat melakukan:

```text
Search
 ↓
SQLite
 ↓
Result
```

meskipun:

```text
API = DOWN
CDN = DOWN
Internet = OFF
```

---

# 5. React Router Tidak Menjadi Data Layer

React Router hanya menangani routing.

Contoh:

```text
/
 /search
 /dictionary/:word
 /dictionary/:id
 /about
```

Router tidak boleh melakukan query SQLite secara langsung.

Hindari:

```text
Route
 ↓
SQL query
```

Gunakan:

```text
Route
 ↓
Page
 ↓
Use Case
 ↓
Repository
 ↓
SQLite
```

---

# 6. Struktur Project

Struktur awal:

```text
src/
├── app/
│   ├── router/
│   ├── providers/
│   └── bootstrap/
│
├── features/
│   └── dictionary/
│       ├── data/
│       │   ├── database/
│       │   ├── datasources/
│       │   └── repositories/
│       │
│       ├── domain/
│       │   ├── entities/
│       │   ├── repositories/
│       │   └── usecases/
│       │
│       └── presentation/
│           ├── pages/
│           ├── components/
│           └── hooks/
│
├── infrastructure/
│   ├── sqlite/
│   ├── http/
│   └── storage/
│
└── routes/
```

---

# 7. Database Layer

Database layer bertanggung jawab terhadap:

* SQLite WASM initialization
* OPFS
* migrations
* connection
* query
* transaction
* database integrity

UI tidak boleh mengetahui detail:

```text
sqlite3
OPFS
SQL
database connection
```

---

# 8. SQLite WASM

Gunakan SQLite yang berjalan di browser melalui WebAssembly.

Konsep:

```text
Browser
   │
   ▼
SQLite WASM
   │
   ▼
OPFS
```

Keuntungan:

* SQL tetap digunakan.
* Schema sama dengan SQLite mobile.
* FTS5 dapat digunakan.
* Query behavior lebih konsisten.
* Dataset dapat menggunakan file SQLite yang sama.
* Tidak perlu membuat query engine dictionary khusus.

---

# 9. OPFS

OPFS digunakan sebagai persistent storage untuk database.

Konsep:

```text
database.sqlite
      │
      ▼
SQLite WASM
      │
      ▼
OPFS
```

OPFS dipilih karena database dapat diperlakukan sebagai file persistent, bukan sekadar object store biasa.

---

# 10. Worker Architecture

SQLite WASM sebaiknya tidak menjalankan query berat di main thread.

Gunakan:

```text
React Main Thread
       │
       ▼
SQLite Worker
       │
       ▼
SQLite WASM
       │
       ▼
OPFS
```

Tujuan:

* UI tetap responsif.
* Search tidak memblok rendering.
* Query berat tidak mengganggu React.
* Database lifecycle lebih mudah dikontrol.

---

# 11. Search Flow

Ketika user mengetik:

```text
kong
```

flow:

```text
SearchInput
    ↓
SearchWordUseCase
    ↓
DictionaryRepository
    ↓
SQLiteDataSource
    ↓
SQLite Worker
    ↓
FTS5
    ↓
Result
    ↓
React
```

Tidak ada:

```text
HTTP request
```

untuk dictionary search.

---

# 12. FTS5

Dataset menggunakan FTS5.

Contoh konseptual:

```sql
SELECT
    words.id,
    words.word
FROM words_fts
JOIN words
    ON words_fts.rowid = words.id
WHERE words_fts MATCH ?
LIMIT 50;
```

FTS5 digunakan untuk:

* exact search
* prefix search
* partial search
* ranking
* fast dictionary lookup

---

# 13. Search Debounce

Search input harus menggunakan debounce.

Contoh:

```text
k
ko
kon
kong
```

Jangan menjalankan query untuk setiap keystroke secara agresif.

Gunakan debounce sekitar:

```text
150-300 ms
```

Nilai final dapat ditentukan berdasarkan profiling.

---

# 14. Search Result Limit

Jangan mengambil seluruh dataset.

Gunakan:

```text
LIMIT 20
```

atau nilai yang sesuai UX.

Pagination atau infinite scrolling dapat digunakan untuk hasil lebih banyak.

---

# 15. Dictionary Detail

Route:

```text
/dictionary/:word
```

Flow:

```text
React Router
      ↓
DictionaryDetailPage
      ↓
GetWordUseCase
      ↓
DictionaryRepository
      ↓
SQLite
```

Contoh:

```text
/dictionary/kong
```

tidak membutuhkan API.

---

# 16. Browser Bootstrap

Ketika aplikasi pertama kali dibuka:

```text
Browser
   ↓
App Bootstrap
   ↓
Check local database
```

Jika database tersedia:

```text
Open DB
 ↓
Start React
```

Jika belum tersedia:

```text
Download initial dataset
 ↓
Install SQLite
 ↓
Verify
 ↓
Start React
```

---

# 17. Jangan Block Startup Jika Database Sudah Ada

Jika database lokal tersedia:

```text
Open DB
 ↓
Render App
 ↓
Background update check
```

Jangan:

```text
Open App
 ↓
Check CDN
 ↓
Wait
 ↓
Download
 ↓
Start
```

---

# 18. Initial Dataset

Untuk Web, ada dua pilihan.

## Option A - Bundled

Dataset disertakan dalam deployment web.

```text
web/
├── assets/
│   └── database.sqlite.gz
```

Keuntungan:

* first load lebih deterministic
* bisa langsung offline setelah pertama kali membuka aplikasi

Kekurangan:

* deployment web lebih besar
* setiap deployment membawa dataset

---

## Option B - Static Download

Aplikasi hanya membawa bootstrap logic.

```text
App
 ↓
Download dataset
 ↓
Install
```

Keuntungan:

* bundle aplikasi lebih kecil
* dataset dapat dirilis terpisah

Kekurangan:

* first launch membutuhkan network

---

## Rekomendasi

Gunakan:

```text
Application bundle
    +
Local dataset
    +
Remote dataset update
```

Jika ukuran dataset masih kecil.

Jika dataset sudah besar:

```text
Application
    ↓
Download initial dataset
```

---

# 19. Dataset Release

Web menggunakan release yang sama dengan mobile.

Contoh:

```text
Release v43
```

menghasilkan:

```text
database.sqlite.gz
manifest.json
SHA256SUMS
```

Mobile dan Web menggunakan:

```text
manifest.json
```

yang sama.

---

# 20. Metadata

Contoh:

```json
{
  "release": {
    "version": 43,
    "status": "active"
  },

  "database": {
    "schema_version": 3,
    "file": "database.sqlite.gz",
    "sha256": "..."
  },

  "compatibility": {
    "min_web_version": "1.8.0"
  }
}
```

Web menyimpan:

```text
local_release_version
local_schema_version
```

---

# 21. Metadata Update Flow

```text
Web App
   │
   ▼
Local DB
   │
   ▼
Application Ready
   │
   └──── background ────► manifest.json
                              │
                              ▼
                        Compare version
                              │
                    ┌─────────┴─────────┐
                    │                   │
                  same                newer
                    │                   │
                    ▼                   ▼
                  done              compatibility
                                        │
                                        ▼
                                  download dataset
```

---

# 22. API Mati

Jika:

```text
API 1 ❌
API 2 ❌
API 3 ❌
```

dictionary tetap:

```text
SQLite
 ↓
Search
 ↓
Result
```

Dynamic functionality dapat:

```text
queue
```

atau:

```text
graceful error
```

---

# 23. CDN Mati

Jika metadata atau dataset tidak dapat di-download:

```text
Local DB
 ↓
continue
```

Database lama tidak boleh dihapus hanya karena update gagal.

---

# 24. Internet Mati

Jika browser sudah memiliki database:

```text
Internet OFF
       ↓
React App
       ↓
SQLite WASM
       ↓
Search
```

Aplikasi dictionary tetap dapat digunakan.

---

# 25. Service Worker

PWA Service Worker bertanggung jawab terhadap:

```text
HTML
CSS
JS
icons
static assets
```

Service Worker bukan database layer.

Pisahkan:

```text
Service Worker
    ↓
Application assets

SQLite WASM
    ↓
Dictionary data
```

---

# 26. Cache Storage vs OPFS

Jangan menyimpan database utama di Cache Storage.

Gunakan:

```text
Cache Storage
    → JS/CSS/HTML/static assets

OPFS
    → SQLite database
```

Ini membuat lifecycle kedua jenis data jelas.

---

# 27. Database Update

Gunakan file temporary:

```text
database.sqlite
database.new.sqlite
```

Flow:

```text
Download
   ↓
database.new.sqlite
   ↓
SHA256
   ↓
SQLite integrity check
   ↓
Schema check
   ↓
Activate
```

Jika gagal:

```text
database.new.sqlite
   ↓
delete
```

Database lama tetap aktif.

---

# 28. Atomic Replacement

Database aktif tidak boleh dihapus terlebih dahulu.

Jangan:

```text
delete database
 ↓
download new
```

Gunakan:

```text
download new
 ↓
verify new
 ↓
activate new
 ↓
remove old
```

---

# 29. Database Compatibility

Web harus memeriksa:

```text
schema_version
min_web_version
```

Contoh:

```json
{
  "release": {
    "version": 43
  },
  "database": {
    "schema_version": 4
  },
  "compatibility": {
    "min_web_version": "2.0.0"
  }
}
```

Jika aplikasi:

```text
1.8.0
```

tidak mendukung schema 4:

```text
Keep existing DB
```

Jangan memaksa install.

---

# 30. Browser Storage Limit

Aplikasi harus mengantisipasi storage quota.

Sebelum download dataset besar:

```text
Estimate storage
 ↓
Check available storage
 ↓
Download
```

Jika storage tidak cukup:

```text
Keep existing database
```

User tetap dapat menggunakan dataset sebelumnya.

---

# 31. Private Browsing

Browser private/incognito mode dapat mempunyai persistence behavior yang berbeda.

Aplikasi harus menganggap local database sebagai:

```text
best-effort persistent storage
```

bukan sebagai permanent backup.

Jika storage hilang:

```text
Next launch
 ↓
Download initial dataset again
```

---

# 32. Multiple Tabs

Jika user membuka:

```text
Tab A
Tab B
Tab C
```

semua dapat mencoba mengakses database.

Gunakan mekanisme coordination/locking untuk mencegah:

```text
Tab A → update DB
Tab B → update DB
Tab C → update DB
```

secara bersamaan.

Gunakan konsep:

```text
Update Lock
```

dan bila tersedia:

```text
BroadcastChannel
```

untuk memberi tahu tab lain:

```text
Database updated to v43
```

---

# 33. Multi-Tab Update

Contoh:

```text
Tab A
 ↓
download v43
 ↓
activate
 ↓
BroadcastChannel
 ↓
"database-updated:v43"
```

Tab B:

```text
receive event
 ↓
reopen database connection
```

Tab C:

```text
receive event
 ↓
refresh database state
```

---

# 34. React State

React state tidak boleh menjadi source of truth untuk dictionary.

Jangan:

```text
React State
   ↓
entire dictionary
```

Dataset dapat terlalu besar.

Gunakan:

```text
React
 ↓
Query
 ↓
Result subset
```

Contoh:

```text
20 search results
```

bukan:

```text
12.000 words
```

---

# 35. React Router Loader

React Router loader dapat digunakan untuk data route-level.

Contoh:

```text
/dictionary/:word
```

Loader:

```text
loader
 ↓
GetWordUseCase
 ↓
SQLite
```

Namun loader tetap tidak boleh mengetahui detail SQLite.

Gunakan:

```text
route loader
 ↓
use case
 ↓
repository
```

---

# 36. Route Example

Konseptual:

```text
routes/
├── home
├── search
├── dictionary/:word
├── explore
└── about
```

Dictionary route:

```text
dictionary/:word
      ↓
getWord(word)
      ↓
repository
      ↓
SQLite
```

---

# 37. React Query / TanStack Query

TanStack Query dapat digunakan untuk:

* API data
* dynamic data
* mutation
* server state

Namun dictionary SQLite bukan server state.

Jangan membuat:

```text
SQLite → TanStack Query → seluruh dataset
```

Gunakan repository langsung atau adapter query yang sesuai.

TanStack Query dapat digunakan untuk:

```text
user profile
notifications
submissions
```

---

# 38. Dynamic API

API tetap digunakan untuk:

```text
login
register
profile
submission
correction
favorites sync
notifications
analytics
```

Dictionary read:

```text
SQLite
```

---

# 39. Offline Contribution Queue

Jika user melakukan:

```text
Submit Correction
```

saat offline:

```text
React
 ↓
Local Queue
 ↓
Pending
```

Ketika online:

```text
Pending Queue
 ↓
API
 ↓
Success
 ↓
Remove
```

Implementasi queue dapat menggunakan IndexedDB atau storage yang sesuai.

Queue ini terpisah dari SQLite dictionary.

---

# 40. Release Metadata Endpoint

Metadata sebaiknya berupa static JSON.

Contoh:

```text
/releases/latest/manifest.json
```

atau:

```text
/releases/active.json
```

Tujuannya agar metadata tidak membutuhkan API.

Flow:

```text
Browser
 ↓
static manifest
```

Bukan:

```text
Browser
 ↓
API
 ↓
metadata
```

Dengan demikian API mati tidak mempengaruhi kemampuan Web mengetahui dataset sebelumnya.

---

# 41. Metadata Fallback

Jika metadata tidak dapat diakses:

```text
Local database version
```

tetap digunakan.

Tidak ada kondisi:

```text
metadata unavailable
 ↓
delete local database
```

---

# 42. Release Rollback

Jika Release v43 bermasalah:

```text
Active:
v43
```

admin melakukan rollback:

```text
Active:
v42
```

Web pada update berikutnya akan mengetahui:

```text
remote = 42
local = 43
```

Karena version dapat bergerak mundur akibat rollback, jangan hanya menggunakan:

```text
remote > local
```

Gunakan status release dan content identity.

Contoh:

```json
{
  "release": {
    "version": 42,
    "content_hash": "sha256:..."
  }
}
```

Web dapat menentukan bahwa local content berbeda dengan active release.

---

# 43. Release Identity

Gunakan:

```text
release_version
content_hash
```

sebagai identitas dataset.

Contoh:

```text
v43
sha256:abc123
```

Ini lebih aman daripada hanya membandingkan angka version.

---

# 44. Initial Bootstrap Metadata

Web membutuhkan informasi minimal:

```text
app version
local DB version
schema version
```

Jika belum ada database:

```text
database = null
```

maka bootstrap flow:

```text
Fetch manifest
 ↓
Check compatibility
 ↓
Download
 ↓
Install
```

---

# 45. Web Deployment

Static hosting dapat digunakan untuk React Web.

Contoh deployment:

```text
GitHub
 ↓
Build React
 ↓
Static Hosting
```

Database dataset tidak harus dibundel bersama deployment aplikasi.

Pisahkan:

```text
Application Release
```

dan:

```text
Dataset Release
```

---

# 46. Independent Release

Ini adalah salah satu manfaat penting arsitektur.

Misalnya:

```text
Web App:
v2.4.0
```

Dataset:

```text
v43
```

Kemudian data diperbarui:

```text
v44
```

Tanpa perlu:

```text
Web App v2.4.1
```

Dataset dapat dirilis sendiri.

---

# 47. App Release vs Dataset Release

Pisahkan:

```text
APP RELEASE
2.4.0
```

dan:

```text
DATA RELEASE
43
```

Contoh:

```text
Application
v2.4.0

Dictionary
v43

API Contract
v4
```

Ketiganya memiliki lifecycle sendiri.

---

# 48. Zero-Dependency Target

Setelah initial dataset terpasang:

```text
┌──────────────────────────┐
│       SambasKu Web       │
│                          │
│ React Router             │
│ SQLite WASM              │
│ OPFS                     │
│ Service Worker           │
│                          │
│       OFFLINE            │
└──────────────────────────┘
```

Tetap dapat:

```text
search
browse
read
```

tanpa:

```text
API
CDN
Database Cloud
```

---

# 49. Dependency Matrix

| Fitur               | Internet |   API | Local DB |
| ------------------- | -------: | ----: | -------: |
| Search              |    Tidak | Tidak |       Ya |
| Detail kata         |    Tidak | Tidak |       Ya |
| Meaning             |    Tidak | Tidak |       Ya |
| Example             |    Tidak | Tidak |       Ya |
| Synonym             |    Tidak | Tidak |       Ya |
| Translation         |    Tidak | Tidak |       Ya |
| Dataset update      |       Ya | Tidak |       Ya |
| Login               |       Ya |    Ya |    Tidak |
| Submit contribution |      Ya* |    Ya |    Queue |
| Profile             |       Ya |    Ya |    Tidak |
| Notification        |       Ya |    Ya |    Tidak |

`*` dapat masuk local queue ketika offline.

---

# 50. Failure Matrix

| Kondisi                | Dictionary       | Dataset Update             | Dynamic API |
| ---------------------- | ---------------- | -------------------------- | ----------- |
| Internet OFF           | Berjalan         | Ditunda                    | Queue/error |
| API OFF                | Berjalan         | Berjalan jika CDN tersedia | Failover    |
| CDN OFF                | Berjalan         | Ditunda                    | Berjalan    |
| Database corrupt       | Fallback DB lama | Ditunda                    | Berjalan    |
| Release pipeline gagal | Berjalan         | Release lama               | Berjalan    |
| Storage penuh          | Berjalan         | Ditunda                    | Berjalan    |
| Browser storage hilang | Download ulang   | Perlu initial download     | Berjalan    |

---

# 51. Security

Public dataset boleh berada di static hosting.

Namun:

* production DB tidak boleh dipublish
* user data tidak boleh masuk dataset
* authentication token tidak boleh masuk dataset
* internal moderation data tidak boleh masuk dataset
* private submission tidak boleh masuk dataset
* hanya data `published` yang diekspor

Checksum harus diverifikasi sebelum database digunakan.

---

# 52. Performance Target

Target awal:

```text
App startup:
tidak menunggu API

Search:
local query

Dictionary detail:
local query

Dataset update:
background
```

SQLite Worker digunakan agar query tidak mengganggu UI.

---

# 53. Testing

## Browser

Test:

* Chrome
* Firefox
* Safari
* Edge

## Storage

Test:

* fresh install
* existing database
* database update
* storage quota
* private browsing
* multiple tabs

## Offline

Test:

```text
Network OFF
```

kemudian:

```text
open app
search
open detail
navigate
```

Semua dictionary functionality harus tetap berjalan.

---

# 54. Acceptance Criteria

### Local-first

* [ ] Dictionary search tidak menggunakan API.
* [ ] Dictionary detail tidak menggunakan API.
* [ ] Dictionary dapat digunakan offline.
* [ ] SQLite WASM digunakan sebagai query engine.
* [ ] Database persistent disimpan melalui OPFS.

### React

* [ ] React Router hanya menangani routing.
* [ ] Route tidak menjalankan raw SQL.
* [ ] Repository menjadi abstraction layer.
* [ ] Use case menjadi application layer.
* [ ] UI hanya menerima hasil query.

### Release

* [ ] Web menggunakan release dataset yang sama dengan mobile.
* [ ] Release memiliki version.
* [ ] Release memiliki content hash.
* [ ] Release memiliki schema version.
* [ ] Release memiliki compatibility metadata.
* [ ] Release dapat di-rollback.

### Update

* [ ] Metadata diperiksa secara background.
* [ ] Database lama tidak dihapus sebelum database baru valid.
* [ ] SHA256 diverifikasi.
* [ ] SQLite integrity check dilakukan.
* [ ] Schema compatibility diverifikasi.
* [ ] Update menggunakan atomic replacement.

### Offline

* [ ] App dapat dibuka ketika offline jika assets telah tersedia.
* [ ] Search tetap bekerja.
* [ ] Detail kata tetap bekerja.
* [ ] Dataset lama tetap tersedia ketika update gagal.

---

# 55. Implementasi Bertahap

## Phase 1 - SQLite WASM

* [ ] Setup SQLite WASM.
* [ ] Setup OPFS.
* [ ] Buat Worker.
* [ ] Load initial database.
* [ ] Implement query.
* [ ] Implement FTS5.

Target:

```text
React Web
   ↓
SQLite WASM
   ↓
Search
```

---

## Phase 2 - Repository

* [ ] DictionaryRepository.
* [ ] LocalDataSource.
* [ ] Use cases.
* [ ] Search.
* [ ] Detail.
* [ ] Meaning.
* [ ] Example.
* [ ] Synonym.
* [ ] Translation.

---

## Phase 3 - React Router

* [ ] Home.
* [ ] Search.
* [ ] Dictionary detail.
* [ ] Explore.
* [ ] Error route.
* [ ] Offline state.

---

## Phase 4 - Dataset Release

* [ ] manifest.
* [ ] version.
* [ ] checksum.
* [ ] static dataset.
* [ ] release endpoint.
* [ ] background update.

---

## Phase 5 - PWA

* [ ] Service Worker.
* [ ] Static asset caching.
* [ ] Offline shell.
* [ ] SQLite persistence.
* [ ] Installability.

---

## Phase 6 - Dynamic API

* [ ] Authentication.
* [ ] User profile.
* [ ] Contribution.
* [ ] Correction.
* [ ] Notification.
* [ ] Sync.
* [ ] Offline queue.

---

# 56. Final Architecture

```text
                           SAMBASKU WEB
                                │
                         React + Router
                                │
                 ┌──────────────┴──────────────┐
                 │                             │
            DICTIONARY                     DYNAMIC
                 │                             │
                 ▼                             ▼
           Use Cases                       Use Cases
                 │                             │
                 ▼                             ▼
           Repository                      Repository
                 │                             │
                 ▼                             ▼
          SQLite DataSource                API Client
                 │                             │
                 ▼                     ┌───────┼───────┐
          SQLite Worker                 │       │       │
                 │                    API #1  API #2  API #3
                 ▼
            SQLite WASM
                 │
                 ▼
               OPFS


DATA RELEASE

Production DB
      │
      ▼
Public Export
      │
      ▼
Sanitize
      │
      ▼
SQLite + FTS5
      │
      ▼
Validate
      │
      ▼
Release v43
      │
      ├──────────────► manifest.json
      │
      └──────────────► database.sqlite.gz
                              │
                              ▼
                             CDN
                              │
                              ▼
                          Browser
                              │
                              ▼
                         SQLite WASM
                              │
                              ▼
                             OPFS
```

---

# 57. Prinsip Akhir

SambasKu Web menggunakan prinsip:

> **The browser owns a local copy of the public dictionary dataset.**

Server hanya bertugas:

```text
publish
update
authenticate
synchronize
```

Browser bertugas:

```text
store
query
search
browse
```

Sehingga:

```text
API mati
    ↓
SQLite tetap tersedia

CDN mati
    ↓
SQLite tetap tersedia

Internet mati
    ↓
SQLite tetap tersedia

Release gagal
    ↓
Dataset sebelumnya tetap tersedia
```

Target akhirnya:

```text
                 PUBLIC DATA
                      │
                  RELEASE
                      │
                      ▼
                ┌───────────┐
                │  Browser  │
                └─────┬─────┘
                      │
                SQLite WASM
                      │
                    OPFS
                      │
                      ▼
                  SEARCH
                      │
                      ▼
                    USER
```

**React Router hanya menjadi navigation layer. SQLite WASM + OPFS menjadi local data layer. Service Worker menjadi application/offline asset layer. API tetap menjadi dynamic data layer.**
