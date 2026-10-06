# SambasKu - Local SQLite & Dataset Release Plan

## 1. Tujuan

Mengubah arsitektur SambasKu menjadi **local-first** dengan SQLite lokal sebagai sumber utama untuk seluruh operasi baca data kamus.

Arsitektur ini dirancang dengan prinsip:

> **API boleh mati, database cloud boleh mati, CDN boleh bermasalah, tetapi data kamus yang sudah pernah tersedia di perangkat tetap dapat digunakan.**

Tujuan:

* Pencarian kamus tidak bergantung pada API.
* Pencarian tetap berjalan tanpa internet.
* SQLite lokal menjadi fallback utama.
* API hanya digunakan untuk operasi dinamis dan sinkronisasi.
* Dataset publik dipisahkan dari production database.
* Data sensitif tidak pernah masuk public dataset.
* Admin dapat melakukan **Release** dari Console.
* Release menghasilkan immutable dataset.
* Mobile mengetahui perubahan melalui metadata.
* Mobile dapat memperbarui database tanpa merilis aplikasi baru.
* Perubahan schema/API dapat dikomunikasikan melalui metadata release.
* Tidak ada hard dependency terhadap satu provider external.

---

# 2. Prinsip Utama

SambasKu memiliki tiga lapisan data yang berbeda.

```text
┌──────────────────────────────┐
│ Production Database          │
│                              │
│ users                        │
│ submissions                  │
│ reviews                      │
│ words                        │
│ meanings                     │
│ examples                     │
│ dll.                         │
└──────────────┬───────────────┘
               │
       Public Dataset Export
               │
               ▼
┌──────────────────────────────┐
│ Public SQLite Dataset        │
│                              │
│ words                        │
│ meanings                     │
│ examples                     │
│ synonyms                     │
│ translations                 │
└──────────────┬───────────────┘
               │
           Release
               │
               ▼
┌──────────────────────────────┐
│ Flutter Local SQLite         │
│                              │
│ Primary read source          │
│ Offline source               │
│ Fallback source              │
└──────────────────────────────┘
```

**Production Database**, **Public Dataset**, dan **Local SQLite** bukan database yang sama.

---

# 3. Arsitektur Target

```text
                         ┌───────────────────────┐
                         │      Console          │
                         │                       │
                         │   [ RELEASE ]         │
                         └──────────┬────────────┘
                                    │
                              Release Trigger
                                    │
                                    ▼
                         ┌───────────────────────┐
                         │    Release Pipeline   │
                         │                       │
                         │ Export                │
                         │ Sanitize              │
                         │ Build SQLite          │
                         │ FTS5                  │
                         │ Validate              │
                         │ Checksum              │
                         │ Generate Metadata     │
                         └──────────┬────────────┘
                                    │
                         ┌──────────┴──────────┐
                         │                     │
                         ▼                     ▼
                  Public Dataset          Release Metadata
                         │                     │
                         └──────────┬──────────┘
                                    │
                              Static Hosting
                                    │
                                    ▼
                             Flutter Mobile
                                    │
                    ┌───────────────┴──────────────┐
                    │                              │
                    ▼                              ▼
             Local SQLite                    Metadata Check
                    │                              │
                    ▼                              ▼
                 Search                    Download Update
                    │                              │
                    └──────────────┬───────────────┘
                                   │
                                   ▼
                                  User
```

---

# 4. API Bukan Sumber Utama Dictionary Read

Operasi:

```text
search word
get meaning
get example
get synonym
get translation
browse dictionary
```

harus menggunakan:

```text
Flutter
   ↓
Local SQLite
   ↓
Result
```

Bukan:

```text
Flutter
   ↓
API
   ↓
Database
   ↓
Result
```

API tetap tersedia sebagai service tambahan untuk operasi yang memang membutuhkan server.

---

# 5. API Failure Behavior

Jika API mati:

```text
API
 ↓
UNAVAILABLE
```

aplikasi **tidak boleh menganggap dictionary tidak tersedia**.

Sebaliknya:

```text
Flutter
   ↓
Local SQLite
   ↓
Search
   ↓
Result
```

Contoh:

```text
User mencari:

kong
```

Aplikasi tidak perlu melakukan:

```text
API 1
 ↓ fail
API 2
 ↓ fail
API 3
```

Cukup:

```text
SQLite lokal
 ↓
kong
```

---

# 6. Zero Dependency Principle

Target arsitektur adalah:

> **Tidak ada external service yang menjadi dependency wajib untuk membaca dataset yang sudah tersedia di perangkat.**

Dengan demikian:

| Service           |       Wajib untuk search? |
| ----------------- | ------------------------: |
| Cloudflare Worker |                     Tidak |
| Deno Deploy       |                     Tidak |
| Render            |                     Tidak |
| PostgreSQL        |                     Tidak |
| Turso             |                     Tidak |
| CDN               | Tidak setelah DB tersedia |
| Internet          |                     Tidak |
| Local SQLite      |                    **Ya** |

CDN hanya diperlukan ketika aplikasi ingin mendapatkan dataset baru.

---

# 7. Production Database

Production database dapat berisi:

```text
users
sessions
submissions
reviews
audit_logs
words
meanings
examples
synonyms
translations
word_variants
dll.
```

Data tersebut **tidak boleh langsung dipublish**.

Production database tidak boleh:

```text
↓
git commit
↓
public repository
```

---

# 8. Public Dataset

Public dataset merupakan hasil export yang sudah disanitasi.

Contoh:

```text
public-dataset.sqlite
```

Berisi:

```text
words
meanings
examples
synonyms
translations
word_variants
languages
dialects
word_classes
```

Tidak berisi:

```text
users
emails
password_hash
sessions
tokens
private submissions
internal notes
audit logs
moderation metadata
```

---

# 9. Public Dataset Hanya Mengambil Data Published

Data harus mempunyai lifecycle.

```text
draft
   ↓
pending_review
   ↓
approved
   ↓
published
```

Hanya data:

```text
published
```

yang boleh masuk public dataset.

Contoh:

```text
Word: nerapak
Status: published
```

→ masuk dataset.

Sedangkan:

```text
Word: abcxyz
Status: pending_review
```

→ tidak masuk dataset.

---

# 10. Release Concept

SambasKu menggunakan konsep **Release**.

Release adalah proses resmi untuk mengubah:

```text
Production Data
```

menjadi:

```text
Public Dataset Version
```

Release **bukan sekadar backup**.

Release merupakan:

> publikasi snapshot data yang aman untuk digunakan oleh aplikasi mobile.

---

# 11. Release dari Console

Console menyediakan fitur:

```text
Dataset
────────────────────────────────

Current Release
v42

Published Changes
17

Last Release
2026-09-25 09:30

[ RELEASE DATASET ]
```

Ketika administrator menekan:

```text
RELEASE DATASET
```

Console memicu release pipeline.

---

# 12. Release Flow

```text
Admin
 │
 │ click RELEASE
 ▼
Console
 │
 ▼
Release API
 │
 ▼
Release Pipeline
 │
 ├── Read production data
 │
 ├── Select published data
 │
 ├── Sanitize
 │
 ├── Generate SQLite
 │
 ├── Build FTS5
 │
 ├── Validate
 │
 ├── Calculate checksum
 │
 ├── Generate metadata
 │
 └── Publish artifact
 │
 ▼
Public Dataset Release
```

---

# 13. Release Tidak Meng-copy Production DB

Jangan melakukan:

```text
production.db
      ↓
copy
      ↓
GitHub
```

Gunakan:

```text
production.db
      ↓
PUBLIC EXPORT
      ↓
sanitize
      ↓
SQLite Builder
      ↓
public-dataset.sqlite
```

Dengan demikian production data tetap privat.

---

# 14. Release Artifact

Setiap release menghasilkan:

```text
release/
├── database.sqlite
├── database.sqlite.gz
├── manifest.json
└── SHA256SUMS
```

Contoh:

```text
v42/
├── database.sqlite.gz
├── manifest.json
└── SHA256SUMS
```

Release bersifat immutable.

---

# 15. Release Version

Setiap release mempunyai version:

```text
v42
v43
v44
```

Version harus monotonic.

Contoh:

```text
Current = 42
New = 43
```

Mobile dapat menentukan:

```text
remote.version > local.version
```

---

# 16. Metadata

Setiap release mempunyai metadata.

Contoh:

```json
{
  "release_version": 43,
  "schema_version": 3,
  "data_version": 43,
  "min_app_version": "1.8.0",
  "recommended_app_version": "1.8.2",
  "database": {
    "file": "database.sqlite.gz",
    "size": 6328172,
    "sha256": "..."
  },
  "api": {
    "contract_version": 4
  },
  "released_at": "2026-09-25T04:00:00Z"
}
```

Metadata inilah yang dibaca mobile untuk menentukan kondisi dataset.

---

# 17. Perbedaan Version

Gunakan beberapa jenis version.

## 17.1 App Version

Contoh:

```text
1.8.2
```

Versi aplikasi Flutter.

---

## 17.2 Schema Version

Contoh:

```text
3
```

Menunjukkan struktur SQLite.

Misalnya:

```text
schema 2
```

menjadi:

```text
schema 3
```

karena ada tabel atau kolom baru.

---

## 17.3 Data Version

Contoh:

```text
43
```

Menunjukkan isi dataset.

Misalnya:

```text
v42
```

memiliki 10.000 kata.

Kemudian:

```text
v43
```

memiliki 10.025 kata.

Schema bisa tetap:

```text
3
```

---

## 17.4 API Contract Version

Contoh:

```text
4
```

Menunjukkan versi kontrak API dynamic.

Ini berguna jika ada perubahan API yang membutuhkan aplikasi versi tertentu.

---

# 18. Mobile Metadata Check

Mobile menyimpan:

```text
local_release_version
local_schema_version
local_api_contract_version
```

Contoh:

```text
Local:

release = 42
schema = 3
api = 3
```

Kemudian mendapatkan metadata:

```text
Remote:

release = 43
schema = 3
api = 3
```

Mobile mengetahui:

```text
43 > 42
```

Maka:

```text
Download database v43
```

---

# 19. Metadata Check Tidak Boleh Menghambat App Startup

Startup:

```text
Open local SQLite
        ↓
Show application
        ↓
Background metadata check
```

Bukan:

```text
Start app
   ↓
wait API
   ↓
check metadata
   ↓
download
   ↓
open database
   ↓
show app
```

User harus tetap bisa menggunakan database lokal.

---

# 20. Jika API Mati

Misalnya:

```text
API Primary    ❌
API Secondary  ❌
API Tertiary   ❌
```

Mobile tetap:

```text
Local SQLite v42
       ↓
Search
       ↓
Result
```

Metadata update dapat gagal:

```text
Metadata check
      ↓
Network unavailable
      ↓
Ignore
      ↓
Continue using v42
```

Tidak boleh:

```text
API mati
 ↓
dictionary disabled
```

---

# 21. Jika CDN Mati

Misalnya:

```text
Metadata berhasil diketahui:
v43 tersedia
```

tetapi:

```text
Download v43
 ↓
CDN unavailable
```

Maka:

```text
Keep v42
```

Aplikasi tetap normal.

Tidak boleh mengganti database lama sebelum database baru berhasil diverifikasi.

---

# 22. Atomic Update

Gunakan:

```text
database.sqlite
database.new.sqlite
```

Flow:

```text
Download v43
      ↓
database.new.sqlite
      ↓
SHA256 verification
      ↓
SQLite integrity_check
      ↓
Schema verification
      ↓
Smoke test
      ↓
Replace database
```

Jika salah satu gagal:

```text
database.new.sqlite
      ↓
delete
```

Database aktif tetap:

```text
v42
```

---

# 23. Schema Compatibility

Metadata harus memberitahu mobile apakah database kompatibel.

Contoh:

```json
{
  "release_version": 43,
  "schema_version": 3,
  "min_app_version": "1.8.0"
}
```

Jika aplikasi:

```text
1.7.5
```

dan membutuhkan:

```text
>= 1.8.0
```

maka mobile **tidak boleh memasang database tersebut**.

Mobile tetap menggunakan:

```text
database v42
```

dan memberi informasi bahwa aplikasi membutuhkan update.

---

# 24. Database Schema Migration

Ada dua kondisi.

### Data update saja

```text
schema 3
release 42
      ↓
schema 3
release 43
```

Tidak membutuhkan app update.

Database cukup diganti.

---

### Schema berubah

```text
schema 3
      ↓
schema 4
```

Jika aplikasi lama tidak mendukung schema 4:

```text
old app
   ↓
reject database v44
   ↓
keep old database
```

Setelah aplikasi di-update:

```text
app 1.9
   ↓
supports schema 4
   ↓
download v44
```

---

# 25. API Contract Metadata

Release metadata juga dapat memberi tahu versi API.

Contoh:

```json
{
  "api": {
    "contract_version": 4,
    "minimum_app_version": "1.9.0"
  }
}
```

Ini berguna jika:

```text
API v4
```

memerlukan:

```text
App >= 1.9.0
```

Namun dictionary read tetap menggunakan SQLite.

Dengan demikian perubahan API tidak otomatis mematikan dictionary.

---

# 26. API Compatibility Strategy

Gunakan prinsip:

```text
Dictionary
→ Local SQLite

Dynamic API
→ Versioned API Contract
```

Jika API berubah:

```text
API v3
API v4
```

client lama masih dapat menggunakan:

```text
Local SQLite
```

untuk dictionary.

---

# 27. Release Status

Console dapat menampilkan:

```text
Release #43

Status:
● Preparing
● Exporting
● Validating
● Publishing
● Completed
```

Jika gagal:

```text
Release #43

Status:
✕ Failed

Reason:
FTS validation failed
```

Release gagal **tidak memengaruhi release sebelumnya**.

---

# 28. Release Rollback

Misalnya:

```text
v42 → stable
v43 → published
```

kemudian ditemukan masalah.

Admin dapat:

```text
[ Rollback ]
```

Target:

```text
v42
```

Rollback cukup mengubah metadata:

```text
active_release = 42
```

Release v43 tetap disimpan sebagai artifact untuk investigasi.

---

# 29. Release vs Backup

Keduanya harus dipisahkan.

### Release

Tujuan:

```text
Production
   ↓
Public Dataset
```

Target:

```text
Mobile
```

### Backup

Tujuan:

```text
Production
   ↓
Disaster Recovery
```

Target:

```text
Private Backup Storage
```

Jangan menggunakan public GitHub repository sebagai backup production.

---

# 30. Backup Trigger

Console juga dapat memiliki:

```text
Database
────────────────────────────

Last Backup:
2026-09-25 03:00

[ BACKUP NOW ]
```

Flow:

```text
Console
   ↓
Backup API
   ↓
Production DB snapshot
   ↓
compress
   ↓
encrypt
   ↓
private storage
```

Backup tidak masuk public dataset.

---

# 31. Release Trigger

Tombol:

```text
[ RELEASE DATASET ]
```

berarti:

> Buat snapshot publik baru dari data yang sudah `published`.

Bukan:

> Backup seluruh database.

---

# 32. Release Pipeline

Pipeline ideal:

```text
RELEASE
   │
   ▼
Lock / snapshot source
   │
   ▼
Export published records
   │
   ▼
Sanitize
   │
   ▼
Build SQLite
   │
   ▼
Build FTS5
   │
   ▼
Validate
   │
   ├── schema
   ├── foreign keys
   ├── integrity
   ├── required fields
   └── dataset count
   │
   ▼
Calculate SHA256
   │
   ▼
Generate manifest
   │
   ▼
Publish artifact
   │
   ▼
Mark Release Active
```

---

# 33. Release Activation

Jangan langsung menjadikan artifact aktif sebelum semua tahap berhasil.

Gunakan:

```text
BUILDING
   ↓
VALIDATED
   ↓
PUBLISHED
   ↓
ACTIVE
```

Jika gagal:

```text
FAILED
```

Release sebelumnya tetap aktif.

---

# 34. Mobile Update Flow

```text
App Start
    │
    ▼
Open Local SQLite
    │
    ▼
Dictionary Ready
    │
    └───────────────┐
                    │ background
                    ▼
             Fetch Metadata
                    │
          ┌─────────┴─────────┐
          │                   │
       Same Version       New Version
          │                   │
          ▼                   ▼
        Done             Check compatibility
                              │
                    ┌─────────┴─────────┐
                    │                   │
                 Compatible         Incompatible
                    │                   │
                    ▼                   ▼
               Download DB         Keep current DB
                    │
                    ▼
                Verify
                    │
                    ▼
                Install
                    │
                    ▼
              New DB Active
```

---

# 35. Jika Metadata Tidak Bisa Diakses

Contoh:

```text
Internet OFF
```

atau:

```text
CDN OFF
```

Mobile:

```text
Use existing SQLite
```

Tidak ada error fatal.

Metadata update merupakan:

> best-effort operation.

---

# 36. Initial Install

Ada dua strategi.

## Bundled

APK/App Bundle membawa dataset awal.

```text
App
 ├── application
 └── database.sqlite
```

Kelebihan:

* langsung offline
* tidak membutuhkan download awal

---

## Download on First Run

```text
Install
 ↓
Download initial dataset
 ↓
Initialize SQLite
```

Kelebihan:

* aplikasi lebih kecil

---

## Rekomendasi

Gunakan **bundled initial dataset** untuk SambasKu jika ukuran masih masuk akal.

Setelah itu:

```text
Bundled v42
      ↓
metadata
      ↓
v43 available
      ↓
background update
```

---

# 37. Local Database State

Mobile menyimpan metadata lokal:

```json
{
  "release_version": 42,
  "schema_version": 3,
  "installed_at": "2026-09-24T10:00:00Z",
  "database_hash": "..."
}
```

Informasi ini digunakan untuk:

* update check
* troubleshooting
* compatibility
* diagnostics

---

# 38. Release Manifest Example

```json
{
  "release": {
    "version": 43,
    "status": "active",
    "released_at": "2026-09-25T04:00:00Z"
  },

  "database": {
    "schema_version": 3,
    "file": "database.sqlite.gz",
    "size": 6328172,
    "sha256": "..."
  },

  "compatibility": {
    "min_app_version": "1.8.0",
    "max_app_version": null
  },

  "api": {
    "contract_version": 4,
    "min_app_version": "1.9.0"
  }
}
```

---

# 39. Public Dataset Repository

Repository public hanya berisi:

```text
sambasku-dataset/
├── README.md
├── schema/
├── metadata/
└── release documentation
```

Database besar sebaiknya dipublikasikan sebagai:

```text
GitHub Release Asset
```

bukan commit database baru setiap kali.

Contoh:

```text
Release v43

Assets:
database.sqlite.gz
SHA256SUMS
manifest.json
```

---

# 40. GitHub Bukan Source of Truth

Source of truth untuk data tetap:

```text
Production Database
```

Public GitHub:

```text
Published Dataset Artifact
```

Mobile:

```text
Replica
```

Dengan demikian:

```text
Production
   ↓
Public Export
   ↓
Release
   ↓
Mobile
```

bukan:

```text
GitHub
   ↓
Production Database
```

---

# 41. GitHub Actions

GitHub Actions dapat digunakan untuk:

* build SQLite
* validate
* generate FTS5
* checksum
* compress
* create release
* upload release assets
* publish metadata

Trigger dapat berasal dari Console.

Secara konseptual:

```text
Console
   ↓
Release API
   ↓
GitHub Actions workflow dispatch
   ↓
Dataset Build
```

---

# 42. Authentication Release

Endpoint release tidak boleh public.

Contoh:

```text
POST /admin/releases
```

Harus membutuhkan:

* authenticated admin
* authorization
* audit log

Setiap release menyimpan:

```text
released_by
released_at
release_version
source_version
status
```

---

# 43. Release Audit Log

Contoh:

```text
Release #43

Created by:
admin

Created:
2026-09-25 11:00

Source:
production snapshot

Result:
SUCCESS

Dataset:
12,431 words

Previous:
12,417 words
```

Audit log berada di production system.

Audit log tidak masuk public SQLite.

---

# 44. Dataset Diff

Console sebaiknya menampilkan perubahan sebelum release.

Contoh:

```text
Release Preview

Added:
+ 14 words

Updated:
~ 7 meanings

Removed:
- 0 words

Examples:
+ 23

Translations:
~ 4
```

Kemudian:

```text
[ CANCEL ]
[ RELEASE ]
```

Dengan demikian tombol Release adalah tindakan yang disengaja.

---

# 45. Release Idempotency

Jika admin menekan Release dua kali tanpa perubahan:

```text
Production dataset
       ↓
same content
```

pipeline sebaiknya mendeteksi:

```text
No changes
```

dan tidak membuat release baru yang tidak perlu.

---

# 46. Content Hash

Selain version, dataset dapat memiliki:

```text
content_hash
```

Contoh:

```json
{
  "version": 43,
  "content_hash": "sha256:..."
}
```

Ini berguna untuk memastikan bahwa:

```text
dataset v43
```

benar-benar identik dengan artifact yang didownload.

---

# 47. Differential Update

**Tidak diperlukan pada fase pertama.**

Versi pertama cukup:

```text
v42
 ↓
download full v43
```

Jika database sudah sangat besar, baru pertimbangkan:

```text
v42
 ↓
patch
 ↓
v43
```

Tetapi jangan menambah kompleksitas ini sebelum diperlukan.

---

# 48. Fallback Hierarchy

Fallback harus didefinisikan dengan jelas.

## Dictionary

```text
1. Local SQLite
2. Dataset update via CDN
3. Tidak ada network dependency
```

Local SQLite adalah sumber read utama.

---

## Dynamic API

```text
1. API Primary
2. API Secondary
3. API Tertiary
4. Local pending queue / cached state
```

Failover API hanya berlaku untuk dynamic operation.

---

# 49. Offline Queue

Untuk operasi yang membutuhkan server:

```text
submit correction
submit word
```

jika API mati:

```text
User
 ↓
Local Pending Queue
```

Kemudian ketika API tersedia:

```text
Pending Queue
 ↓
API
 ↓
Success
 ↓
Remove Queue
```

Dengan demikian API outage tidak harus menghilangkan kemampuan user membuat kontribusi.

---

# 50. Target Dependency Model

```text
                  ┌──────────────────────┐
                  │    External Services  │
                  └──────────┬───────────┘
                             │
                ┌────────────┼────────────┐
                │            │            │
                ▼            ▼            ▼
              API           CDN        Metadata
                │            │            │
                └────────────┼────────────┘
                             │
                             ▼
                       Flutter Mobile
                             │
                       ┌─────▼─────┐
                       │  SQLite   │
                       │  LOCAL    │
                       └───────────┘
```

External services membantu aplikasi mendapatkan data terbaru.

Tetapi:

> **External services tidak menjadi syarat untuk membaca data yang sudah dimiliki aplikasi.**

---

# 51. Failure Scenarios

## Semua API mati

```text
API ❌
SQLite ✅
```

Result:

```text
Dictionary → WORKS
Dynamic operation → queued/failed gracefully
```

---

## CDN mati

```text
CDN ❌
SQLite v42 ✅
```

Result:

```text
Dictionary → WORKS
Update → postponed
```

---

## Internet mati

```text
Internet ❌
SQLite v42 ✅
```

Result:

```text
Dictionary → WORKS
```

---

## Database update corrupt

```text
v43 ❌
v42 ✅
```

Result:

```text
Keep v42
```

---

## Release pipeline gagal

```text
v43 FAILED
v42 ACTIVE
```

Result:

```text
Mobile tetap menggunakan v42
```

---

# 52. Acceptance Criteria

## Local-first

* [ ] Dictionary search tidak membutuhkan API.
* [ ] Dictionary detail tidak membutuhkan API.
* [ ] Dictionary tetap berjalan offline.
* [ ] Local SQLite selalu tersedia setelah initial dataset terpasang.

## Release

* [ ] Console mempunyai tombol `Release`.
* [ ] Release hanya dapat dilakukan oleh authorized admin.
* [ ] Release menghasilkan immutable version.
* [ ] Release memiliki audit log.
* [ ] Release memiliki preview perubahan.
* [ ] Release gagal tidak mengganggu release sebelumnya.

## Security

* [ ] Production database tidak pernah dipublish.
* [ ] User data tidak masuk public SQLite.
* [ ] Session/token tidak masuk public dataset.
* [ ] Hanya data `published` yang diekspor.
* [ ] Public export menggunakan explicit field selection.

## Mobile Update

* [ ] Mobile menyimpan release version.
* [ ] Mobile membaca release metadata.
* [ ] Mobile mendeteksi versi baru.
* [ ] Mobile memeriksa compatibility.
* [ ] Mobile melakukan background update.
* [ ] Mobile memverifikasi checksum.
* [ ] Mobile melakukan SQLite integrity check.
* [ ] Update menggunakan atomic replacement.
* [ ] Database lama dipertahankan jika update gagal.

## API

* [ ] API tidak menjadi dependency dictionary read.
* [ ] API contract memiliki version.
* [ ] API failover hanya digunakan untuk dynamic operation.
* [ ] API outage tidak mematikan dictionary.

---

# 53. Tahapan Implementasi

## Phase 1 - Local SQLite

* [ ] Implement SQLite schema.
* [ ] Import dataset.
* [ ] Implement FTS5.
* [ ] Implement repository.
* [ ] Implement search.
* [ ] Implement dictionary detail.
* [ ] Bundle initial database.

Target:

```text
Dictionary dapat berjalan 100% offline.
```

---

## Phase 2 - Dataset Builder

* [ ] Production → public export.
* [ ] Sanitization.
* [ ] SQLite generator.
* [ ] FTS5 builder.
* [ ] Validation.
* [ ] SHA256.
* [ ] Compression.

Target:

```text
Production DB
    ↓
Safe public SQLite
```

---

## Phase 3 - Release Pipeline

* [ ] Release model.
* [ ] Release status.
* [ ] Release version.
* [ ] Release audit.
* [ ] Release preview.
* [ ] Release trigger.
* [ ] GitHub Actions.
* [ ] GitHub Release artifact.

Target:

```text
Console → Release → Dataset Artifact
```

---

## Phase 4 - Mobile Metadata

* [ ] manifest.json.
* [ ] release version.
* [ ] schema version.
* [ ] app compatibility.
* [ ] API contract version.
* [ ] background metadata check.

Target:

```text
Mobile mengetahui dataset terbaru.
```

---

## Phase 5 - Mobile Update

* [ ] Download.
* [ ] checksum.
* [ ] integrity check.
* [ ] atomic replacement.
* [ ] rollback.
* [ ] failed update handling.

Target:

```text
Mobile dapat update database tanpa app release.
```

---

## Phase 6 - Remove Read API Dependency

Migrasikan seluruh read operation:

```text
API → SQLite
```

Contoh:

```text
GET /words
GET /words/:id
GET /search
GET /meanings
GET /examples
GET /synonyms
```

menjadi local repository.

API endpoint dapat dipertahankan sementara untuk compatibility.

---

## Phase 7 - Dynamic API

Pertahankan API untuk:

```text
authentication
submission
correction
review
moderation
notification
sync
analytics
```

---

# 54. Final Architecture

```text
                           SAMBASKU
                              │
               ┌──────────────┴──────────────┐
               │                             │
          PUBLIC READ                  DYNAMIC DATA
               │                             │
               ▼                             ▼
        Local SQLite                       API
               │                             │
               │                    ┌────────┼────────┐
               │                    │        │        │
               │                  API #1   API #2   API #3
               │
               ▼
             FTS5
               │
               ▼
             User


DATA RELEASE PIPELINE

Production DB
      │
      ├──────────────────┐
      │                  │
      ▼                  ▼
   Backup            Public Export
      │                  │
      ▼                  ▼
Private Storage      Sanitize
                         │
                         ▼
                    SQLite + FTS5
                         │
                         ▼
                      Validate
                         │
                         ▼
                    GitHub Release
                         │
                         ▼
                         CDN
                         │
                         ▼
                    Mobile Update


CONSOLE

Admin
  │
  ▼
[ RELEASE ]
  │
  ▼
Release Preview
  │
  ▼
Confirm
  │
  ▼
Release Pipeline
  │
  ▼
v43 ACTIVE
```

---

# 55. Prinsip Final

Arsitektur SambasKu mengikuti prinsip:

```text
                "Server publishes.
                 Client owns a copy."
```

Server bertugas menerbitkan dataset.

Client memiliki salinan dataset tersebut.

Karena itu:

```text
API mati
    ↓
SQLite tetap ada
    ↓
Dictionary tetap bekerja
```

dan:

```text
CDN mati
    ↓
SQLite versi sebelumnya tetap ada
    ↓
Dictionary tetap bekerja
```

Sedangkan ketika semuanya normal:

```text
Admin
 ↓
Release
 ↓
Public Dataset v43
 ↓
Metadata
 ↓
Mobile detects v43
 ↓
Download
 ↓
Verify
 ↓
Install
 ↓
SQLite v43
```

Dengan model ini, **Release di Console menjadi satu-satunya pintu resmi untuk mengubah public dataset**, sementara production database tetap privat dan mobile tidak pernah perlu mengetahui atau memiliki akses langsung ke database production.
