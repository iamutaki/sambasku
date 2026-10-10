# API Duplicate Meaning Confirm - Vote saat kontribusi exact-match

Saat user mengirim kata/makna dengan **lemma + definition + terjemahan
Indonesia** yang exact-match (trim, lowercase, collapse whitespace) dengan
entri **published**, API menolak insert (`409 DUPLICATE_MEANING`) dan klien
menampilkan modal upvote/downvote. Konfirmasi lewat endpoint ini: cast
vote pada makna + satu baris `audit_logs` (`action=duplicate_vote`) agar
muncul di `GET /api/v1/words/:id/change-history`.

## Endpoint

### POST /api/v1/contributions/duplicate-confirm

Auth wajib. Scope azp: `vote.write` (sama gate vote toggle).

Body:

```json
{
  "word_id": "01…",
  "meaning_id": "01…",
  "value": 1
}
```

`value`: `1` = upvote, `-1` = downvote (toggle sama modul vote).

Response 200:

```json
{
  "success": true,
  "data": {
    "word_id": "01…",
    "meaning_id": "01…",
    "lemma": "makatn",
    "my_vote": 1,
    "upvotes": 3,
    "downvotes": 0,
    "message": "Terima kasih. Kamu tercatat di riwayat perubahan makatn."
  }
}
```

### 409 DUPLICATE_MEANING (dari create)

Dipicu oleh `POST /api/v1/contributions/words`, `POST /api/v1/admin/words`,
dan `POST /api/v1/words/:id/meanings` sebelum insert.

```json
{
  "success": false,
  "error_code": "DUPLICATE_MEANING",
  "message": "Kata dan makna ini sudah ada di kamus. …",
  "details": null,
  "data": {
    "word_id": "01…",
    "meaning_id": "01…",
    "lemma": "makatn",
    "definition": "…",
    "translation_text": "…"
  }
}
```

## Change history

Tipe baru: `duplicate_vote` (selain `direct_edit` | `suggest_edit`).
