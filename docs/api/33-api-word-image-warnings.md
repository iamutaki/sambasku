# API - Peringatan visual foto kata (`content_warnings`)

Flag menempel di **`word_images`**, bukan di parent `words` / `usage_labels`.

## Enum V1

| Nilai | Arti |
| --- | --- |
| `kekerasan` | Foto memperlihatkan kekerasan; klien blur + tap untuk lihat |

Array JSON, tanpa duplikat. Kosong `[]` = tanpa peringatan.

## Wire

### Request create / add / update images

```json
{
  "url": "https://…",
  "provider_file_id": "…",
  "is_primary": false,
  "content_warnings": ["kekerasan"]
}
```

### Response publik `images[]` (GET detail / today)

```json
{
  "id": "…",
  "url": "https://…",
  "provider_file_id": "…",
  "alt_text": null,
  "is_primary": true,
  "content_warnings": ["kekerasan"],
  "is_verified": true,
  "attribution": {
    "name": "Ada",
    "url": "https://www.flickr.com/photos/…",
    "license": "CC BY 2.0",
    "license_url": "https://creativecommons.org/licenses/by/2.0/",
    "source": "flickr",
    "provider": "openverse"
  }
}
```

- `is_verified` selalu dikirim ke publik (pending staging tetap boleh redact URL).
- `attribution` (nullable): kredit foto stock Media Explorer. Hanya terisi
  untuk provider stock (`unsplash|openverse|pixabay|…`), jadi `provider` di
  dalamnya aman untuk publik. `null` untuk upload user dan gambar lama.
  Klien wajib menampilkannya di tempat foto tampil: Unsplash "Foto oleh
  {name} di Unsplash" (link ber-UTM), Openverse dengan lisensi + link,
  Pixabay "Foto oleh {name} di Pixabay".
- Admin/review: tambahan `provider` seperti sebelumnya.

## Siapa yang set

- Kontributor saat unggah (opsional)
- Verifikator / admin saat review atau edit
- Resolve laporan pembaca: `POST /api/v1/admin/word-reports/:id/flag-violent-image`

## Laporan foto

`POST /api/v1/words/:id/reports`

```json
{
  "reason_code": "violent_image",
  "image_id": "<word_image_id>"
}
```

Login wajib; rate limit sama laporan kata. Unique open per `(word, user)` untuk laporan kata dan per `(word, user, image)` untuk laporan foto.

## Bukan ini

- Jangan pakai `usage_labels` kata (`seksual`, `diskriminatif`, …) untuk blur foto.
- Deteksi AI otomatis: di luar V1.
