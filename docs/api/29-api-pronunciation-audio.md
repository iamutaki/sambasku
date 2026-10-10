# 29 - API Pronunciation Audio

Upload & baca file audio pelafalan (multi-take) lewat GitHub Contents API.
Notasi IPA (`POST .../pronunciations`) **tidak berubah**.

## Env

```env
PRONUNCIACION_PROVIDER=github
PRONUNCIACION_GITHUB_TOKEN=          # fine-grained PAT, Contents RW pada repo sambasku/audios
PRONUNCIACION_GITHUB_URL=https://github.com/sambasku/audios
```

Tanpa token/URL → upload balas **503** `PRONUNCIACION_UPLOAD_UNAVAILABLE`.

## Endpoints

### Upload (satu langkah)

```http
POST /api/v1/words/:wordId/pronunciations/audio
Content-Type: multipart/form-data
Authorization: Bearer <access>
```

| Field | Wajib | Keterangan |
|-------|-------|------------|
| `audio` | ya | file ≤5 MB; MIME: mpeg/mp4/wav/ogg/webm |
| `dialect_id` | tidak | ULID dialek |
| `example_id` | tidak | ULID contoh → audio kalimat (harus milik kata) |
| `speaker_name` | tidak | max 255; kosong/hilang → anonim (tidak dicantumkan) |
| `duration_ms` | tidak | 1…600000 |

Roles: `admin`, `editor`, `contributor`, `root`, `reviewer`. Rate limit 30/menit.

- Contributor (non-verifikator) → `pending_review` + `is_verified: false` (**belum** tayang di player publik)
- Admin/editor/root/reviewer → `published` + verified (langsung tayang)
- `speaker_name` opsional: user boleh kirim audio tanpa nama (anonim)
- Audio **pertama** per target (lemma vs per-example) → `is_primary=true`
- Path storage: `assets/audio/<dialect|umum>/<lemma-slug>/<ulid>.<ext>`

Respons 201:

```json
{
  "success": true,
  "data": {
    "id": "…",
    "word_id": "…",
    "example_id": null,
    "dialect_id": null,
    "url": "https://cdn.jsdelivr.net/gh/…@main/….m4a",
    "mime_type": "audio/mp4",
    "file_size": 12345,
    "duration_ms": 1200,
    "speaker_name": null,
    "is_primary": true,
    "status": "pending_review",
    "is_verified": false,
    "is_corrected": false
  }
}
```

### Delete

```http
DELETE /api/v1/words/:wordId/pronunciations/audio/:audioId
```

Roles: `admin`, `editor`, `root`. Soft-delete DB + best-effort hapus file GitHub.

### Read (word detail)

`GET /api/v1/words/:id`:

- `audios[]` - pelafalan lemma (`example_id` null), publik hanya `published`
- `meanings[].examples[].audios[]` - pelafalan per contoh
- Tiap item audio memuat `is_verified` (untuk badge Menunggu pengecekan di klien)

Urut: `is_primary` dulu, lalu terbaru.

## Error codes

| Code | HTTP |
|------|------|
| `PRONUNCIACION_UPLOAD_UNAVAILABLE` | 503 |
| `PRONUNCIACION_UPLOAD_FAILED` | 502 |
| `WORD_AUDIO_NOT_FOUND` | 404 |
| `EXAMPLE_NOT_FOUND` | 404 |
| `DIALECT_NOT_FOUND` | 404 |
| `INVALID_AUDIO_MIME` / `EMPTY_AUDIO_FILE` / `AUDIO_TOO_LARGE` / `INVALID_AUDIO_CONTENT` | 400 |

## Catatan

- Tabel notasi `pronunciations` + legacy `audio_url` tidak dimigrasi.
- Entity kontribusi: `word_audio` (antrean review).
- Repo pronunciation harus **public** agar raw URL bisa diputar client.
- Pre-moderasi audio beda dari child lain (`resolveChildPublication` me-publish kontributor): upload audio non-verifikator **sengaja** dipaksa `pending_review`.
