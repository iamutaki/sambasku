# Admin UI - Koreksi Term & Tayang Search Miss

Mengikuti `admin-base-stack.md` (feature-based, React Query, DataTable,
Switch tayang). Kontrak API:

- Moderasi: `docs/api/14-api-search-miss-moderation.md`
- Fondasi list/dismiss: `docs/api/03-api-kontribusi-verifikasi.md`
- Buat kata dari miss: `docs/admin/10-admin-search-miss-buat-kata.md`

Status fondasi saat dokumen ini dibuat (JANGAN diduplikasi):

- SUDAH ADA (admin): `/search-misses` list + filter arah/fulfilled +
  dismiss + Buat kata.
- SUDAH ADA (API): list/dismiss; **baru di 14-api**: PATCH term +
  `is_visible`, list expose `is_visible`.
- YANG BELUM (ditutup dokumen ini): edit inline kolom Kata Dicari;
  Switch Tayang; filter tayang.

---

## Keputusan UX (terkunci)

1. **Kolom Kata Dicari** editable inline (klik teks → input; Enter/blur
   simpan). Hanya role yang boleh PATCH (`admin` | `root`). Role lain
   lihat teks biasa.
2. **Kolom Tayang** = Switch (pola `/words` kolom Tayang). Default off
   untuk miss baru. ON → `PATCH { is_visible: true }`; OFF → false.
3. **Tabs terpenuhi** (POV admin - antrean kerja):
   **Belum Terpenuhi** (default) | **Terpenuhi** | **Semua** → query
   `fulfilled=false|true|(omit)`.
4. **Filter Tayang** tetap di toolbar Select (opsional) → `visible`.
   Switch kolom Tayang per baris tetap ada.
5. Prefill **Buat kata** tetap pakai `row.term` (sudah terkoreksi bila
   admin sempat edit).
6. Toast sukses singkat; error conflict term → `message.warning` dari
   envelope error.

---

## Prompt

```text
Perluas SearchMissesPage mengikuti 14-api.

DOMAIN / INFRA:
- SearchMissListItem + SearchMissWire: tambah isVisible / is_visible
- listSearchMissesRequest: param visible?: boolean
- updateSearchMissRequest(id, { term?, isVisible? })
  → PATCH /api/v1/admin/search-misses/:id
- Mapper normalize is_visible → isVisible

APPLICATION:
- useUpdateSearchMiss: useMutation, invalidate ['search-misses']
- useSearchMissList: teruskan visible ke API + queryKey

PRESENTATION (/search-misses):
1. Tabs fulfilled di bawah PageHeader (default key=pending):
   Belum Terpenuhi | Terpenuhi | Semua → fulfilled false|true|undefined
2. Kolom Kata Dicari: Typography.Text editable (atau Input blur)
   untuk canEdit; onSave → updateSearchMiss({ term })
3. Kolom Tayang (Switch size=small): canEdit → onChange is_visible;
   selain itu Switch disabled menampilkan state
4. Filter Select: arah + tayang (visibility)
5. canEdit = role admin | root (selaras API; dismiss boleh tetap
   reviewer sesuai gate existing bila ada)

Command verifikasi: pnpm typecheck && pnpm lint && pnpm test && pnpm build
```

---

## Catatan Implementasi

- Jangan buat halaman detail terpisah - edit di tabel cukup.
- Optimistic update opsional; invalidate list sudah cukup (lazy).
- Dismiss tetap Popconfirm; unpublish (Switch off) tanpa confirm.
