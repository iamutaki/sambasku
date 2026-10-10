# Fitur Filter Kategori Lintas Platform (#50)

## Ringkasan

Filter kategori/glosarium (hewan, sayur, olahraga, permainan, dll.)
di semua platform: API, Web, Mobile, Console, dan Docs.

**Status:** ✅ API & Web selesai | ⏳ Mobile UI selesai | ⏳ Console master CRUD pending | ⏳ Docs selesai

## API

### Endpoint Lama (tanpa perubahan)
`GET /api/v1/words?q=&letter=&is_verified=&cursor=&limit=`

### Endpoint Baru
`GET /api/v1/categories` — daftar semua kategori aktif (tanpa auth).

**Response:**
```json
{
  "success": true,
  "data": [
    { "id": "...", "parent_id": null, "name": "Hewan", "description": null, "word_count": 42 }
  ]
}
```

### Perubahan Endpoint List Words
`GET /api/v1/words` sekarang menerima parameter `category` (string, id kategori).
Jika diisi, hasil difilter hanya kata berkategori tersebut (kombinasi
dengan `q` dan `letter` diperbolehkan).

**Kontrak tidak berubah** — `word_count` per kategori adalah nilai
tambahan (field baru), bukan kolom lama.

**Route:** `/api/v1/categories` (GET, publik), `/api/v1/categories/:id` (PUT/DELETE, admin — pending).

## Web

Halaman `/words` mendapat dropdown kategori di atas filter yang ada.

- Dropdown fetch dari `GET /api/v1/categories` (TanStack Query, staleTime 5 menit).
- value = `category.id` (di-pass sebagai `category` param ke loader).
- Perubahan dropdown → navigasi ke URL baru (`?category=...`) → loader re-fetch.
- `category` tampil di meta halaman (title filter aktif).
- Kombinasi dengan `q` dan `letter` berjalan (di-back-end).

## Mobile

Halaman **Daftar Kata A-Z** (`WordListPage`) mendapat dropdown
kategori (FSelect) di antara toggle Sambas/Indonesia dan field cari.

- Kategori di-fetch via `categoriesProvider` → `listCategoriesUseCase` →
  `dictionaryRepository.listCategories()` → `GET /api/v1/categories`.
- `categoriesProvider` adalah `FutureProvider<List<WordCategory>>` —
  loading = dropdown tidak tampil (graceful).
- `onCategoryChanged` me-reset state (items = [], cursor = null,
  hasMore = false, isLoading = true) → fetch halaman pertama dengan
  `category` param.
- Clear button di dropdown → hapus filter kategori (fetch ulang semua).

**State:** `WordListState.category: String?` — null = semua.

**Flow:**
```
WordListPage
  → categoriesProvider (FutureProvider<List<WordCategory>>)
    → listCategoriesUseCaseProvider
      → DictionaryRepository.listCategories()
        → GET /api/v1/categories

User selects category
  → notifier.onCategoryChanged(id)
    → state = copyWith(category: id, items: [], clearNextCursor: true, ...)
      → load() → ListWordsParams(q: ..., category: state.category)
        → GET /api/v1/words?category=...
```

## Console (TBD)

Halaman master CRUD kategori (`/categories`).

- **List:** tabel nama, deskripsi, jumlah kata, aksi Edit + Hapus.
- **Create/Edit:** modal form (nama, deskripsi, parent_id opsional).
- **Delete:** soft delete + konfirmasi + audit log.
- **API:** `POST /api/v1/categories`, `PUT /api/v1/categories/:id`,
  `DELETE /api/v1/categories/:id` (pending impl subagent).

## Docs Tambahan

Dokumentasi API: lihat `docs/api/18-api-list-words.md` (category param
sudah tercakup).