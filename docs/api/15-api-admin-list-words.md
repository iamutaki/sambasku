# API - List Kata Admin (filter tayang)

Delta untuk panel `/words`: list semua status + filter `published`,
tanpa mencatat search miss.

Fondasi: `01-api-tambah-kata.md` (search publik), approval gate base-stack
Section 22.

---

## Keputusan

1. **Endpoint baru**: `GET /api/v1/admin/words` (auth: admin/editor/
   contributor/root/reviewer).
2. **Query** (sama bentuk item dengan search publik):
   - `q`, `limit`, `cursor`, `word_type`, `is_verified`
   - `published` opsional boolean:
     - `true` → hanya `status=published`
     - `false` → `status != published`
     - omit → semua status (belum soft-deleted)
3. **Tidak** memanggil search-miss record (beda dari
   `GET /words/search`).
4. **Search publik** tetap `published` saja; use case memaksa
   `published: true` di repo.

---

## Prompt

```text
SearchParams.published?; ListAdminWordsUseCase; GET /admin/words;
SearchWordsUseCase always published:true.
```
