# TELEGRAM_BOT - Kontribusi & lookup via bot Telegram

Dokumen backlog. **Belum diimplementasi.** Channel intake tambahan
yang memakai API kontribusi yang sudah ada; bukan pipeline review
baru. Lihat juga
[`docs/api/03-api-kontribusi-verifikasi.md`](../api/03-api-kontribusi-verifikasi.md)
(endpoint publik submit) dan pola monorepo submodule di README root.

## Tujuan

Bot Telegram sebagai **kamus saku + funnel usul kata cepat**. User
bisa lookup dan mengusulkan lemma Sambas dari chat dalam ~1 menit.
Antrean approve / reject / correct tetap di `api` + console.

Bukan pengganti form web/mobile (variasi, sinonim inline, media
lengkap).

## Positioning

| Bot lakukan (MVP) | Bot tidak lakukan (fase 1) |
| ----------------- | -------------------------- |
| Cari lemma cepat | Edit kata penuh / sinonim inline |
| Usul kata baru (teks minimal) | Upload banyak gambar / audio kompleks |
| Arahkan ke web untuk form lengkap | Ganti console verifikator |
| (Fase 2) status usulan jika akun linked | Approve/reject dari Telegram |

## Bentuk repo

Submodule baru di monorepo (sejajar `api/`, `web/`, `mobile/`),
misalnya `telegram/`. Repo Git sendiri, deploy & secret terpisah.

- Bot = **channel client** (HTTP ke `API_BASE_URL`)
- **Jangan** impor use case Drizzle dari `api`, **jangan** query DB
  kamus langsung
- Domain tetap `CreateWordUseCase` + modul `contribution`

```text
Telegram
   │ webhook
   ▼
telegram/  (submodule)
   ├── handlers/      /start /cari /usulkan
   ├── wizard/        state machine + draft session
   ├── api-client/    fetch ke API_BASE_URL
   └── refs-cache/    word classes, languages (TTL)
   │
   │ HTTPS JSON
   ▼
api/   CreateWordUseCase + antrean contribution (tidak berubah)
```

Session wizard (draft per `telegram_user_id`) hidup di storage bot
(Redis / KV / SQLite lokal bot), bukan di Turso kamus.

## Endpoint yang dipakai ulang

- **Submit:** `POST /api/v1/contributions/words`
  - Tanpa Bearer → user sistem Anonim
  - Dengan Bearer → atribusi user login
- **Lookup:** endpoint search / detail publik yang sudah ada
- **Referensi:** list kelas kata / bahasa (di-cache di bot saat boot
  atau TTL)
- **(Fase 2)** `GET /api/v1/contributions/my` setelah akun linked

Tidak ada antrean review khusus Telegram.

## Perintah

```text
/start     - sambutan + tombol: Cari | Usulkan | Bantuan
/cari      - lookup kata (GET publik)
/usulkan   - wizard kontribusi
/status    - usulan saya (fase 2, butuh akun linked)
/batal     - batalkan wizard yang sedang jalan
/bantuan   - cara pakai + link web/mobile
```

Inline mode (`@SambasKuBot lemma`) = opsional belakangan.

Default interaksi: **private chat / DM**. Di grup: `/cari` saja agar
tidak jadi spam.

## Wizard `/usulkan` (inti MVP)

1. **Lemma** - "Kata Sambas yang mau diusulkan?"
2. **Cek dulu** - lookup API; jika sudah ada, tawarkan lihat di web,
   jangan submit buta
3. **Padanan Indonesia** - arti singkat
4. **Kelas kata** - inline buttons (Nomina / Verba / …); ID dari cache
   referensi
5. **Definisi** - opsional (`/lewati` boleh; pastikan padanan terisi
   sesuai aturan API)
6. **Konfirmasi** - kartu ringkas + [Kirim] [Ubah] [Batal]
7. **Submit** - `POST /contributions/words` → pesan "masuk antrean
   verifikator"

### Payload minimal (contoh)

Selaras helper e2e kontribusi:

```json
{
  "language_id": "<SMB>",
  "lemma": "kalintiak",
  "word_type": "word",
  "category_ids": [],
  "related_words": [],
  "meanings": [
    {
      "word_class_id": "<NOMINA>",
      "definition": "-",
      "order_index": 1,
      "translations": [
        {
          "language_id": "<IDN>",
          "translation_text": "ikan kecil",
          "translation_type": "direct"
        }
      ]
    }
  ]
}
```

Default: `language_id` = Melayu Sambas, `word_type` = `word`.
Idiom / peribahasa / ungkapan = perluasan nanti.

## Identitas (bertingkat)

| Fase | Mode | Atribusi |
| ---- | ---- | -------- |
| 1 | Anonim (tanpa Bearer) | User sistem `anonim` |
| 2 | Link akun (`/hubungkan`) | `auth_identities.provider = 'telegram'` + Telegram user id; submit pakai Bearer |
| 3 | Notifikasi hasil review | DM saat approve/reject (butuh event dari API; opsional) |

Tabel `auth_identities` sudah generic (`provider` varchar). Nilai
`telegram` muat tanpa redesign skema. Pola sama Google/Facebook
(no-autolink agresif: ikuti keputusan auth yang ada).

## Guardrail

- Rate limit per Telegram user di bot (mis. 5 usulan/jam), di atas
  rate limit API
- Tolak lemma terlalu pendek / hanya angka / pola spam
- Setelah duplikat ditemukan, jangan submit
- Error API diterjemahkan ke bahasa chat sederhana (bukan JSON mentah)
- Tombol "Form lengkap di web" selalu ada di akhir wizard
- Secret: `BOT_TOKEN` + `API_BASE_URL` (+ token fase 2); jangan
  campur dengan secret JWT user di mobile

## Roadmap

1. **MVP** - submodule `telegram/`, webhook, `/cari` + `/usulkan`
   anonim → `POST /contributions/words`
2. **Link akun** - `/hubungkan` + `/status` via `contributions/my`
3. **Inline query** + notifikasi hasil review
4. **(Opsional, produk terpisah)** channel reviewer di Telegram -
   bukan bagian MVP kontribusi

## Anti-pola

- Jangan duplikasi tabel / antrean `contributions` khusus Telegram
- Jangan bot yang menulis langsung ke DB kamus
- Jangan wizard 20 field (variasi, related inline, multi-image) di
  chat; arahkan ke web/mobile
- Jangan jadikan grup publik sebagai channel submit default
- Jangan campur bot ke dalam repo `api/` hanya karena "sama-sama
  TypeScript"

## Urutan kerja saat dieksekusi

1. Buat repo `sambasku/telegram` + submodule di root; dokumentasikan
   di README monorepo
2. Kontrak singkat `docs/telegram/01-bot-kontribusi.md` (command,
   wizard, mapping DTO, error UX) - opsional tapi disarankan sebelum
   kode besar
3. Scaffold bot (Grammy / Telegraf / Worker) + webhook staging
4. Cache referensi (bahasa SMB/IDN, kelas kata) + client HTTP
5. Wizard `/usulkan` + `/cari` + rate limit lokal
6. Uji e2e manual: submit muncul di antrean admin dengan
   `contributor_username = anonim`
7. (Fase 2) link identity Telegram + Bearer

## Standar selesai (MVP)

- [ ] Submodule terdaftar; deploy staging dengan secret terpisah
- [ ] `/cari` mengembalikan hasil atau empty state yang jelas
- [ ] `/usulkan` end-to-end → baris di antrean `entity_type=word`
- [ ] Duplikat lemma ditangani sebelum POST
- [ ] `/batal` membersihkan session wizard
- [ ] Pesan sukses/gagal bahasa Indonesia, tanpa bocorkan ID internal
- [ ] Rate limit bot terbukti menolak flood
