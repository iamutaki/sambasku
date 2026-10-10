<p align="center">
  <img src="logo.png" alt="SambasKu" width="320" />
</p>

# SambasKu

Monorepo **Kamus Digital Sambas-Indonesia**. Tiap bagian adalah repositori
Git sendiri (submodule) supaya aset publik, API, dan klien bisa berversi
terpisah.

| Submodule | Repo | Peran |
| --------- | ---- | ----- |
| `api/` | [sambasku-api](https://github.com/iamutaki/sambasku-api) | Backend Hono + Drizzle + Turso |
| `web/` | [sambasku-web](https://github.com/iamutaki/sambasku-web) | Situs publik (SSR) |
| `admin/` | [sambasku-admin](https://github.com/iamutaki/sambasku-admin) | Konsol admin |
| `mobile/` | [sambasku-mobile](https://github.com/iamutaki/sambasku-mobile) | Aplikasi Flutter |
| `docs/` | [sambasku-docs](https://github.com/iamutaki/sambasku-docs) | Kontrak API, base stack, backlog |
| `http/` | [sambasku-http](https://github.com/iamutaki/sambasku-http) | Koleksi Bruno |
| `pronunciation/` | [sambasku-pronunciation](https://github.com/iamutaki/sambasku-pronunciation) | Audio pelafalan (jsDelivr) |
| `images/` | [sambasku-images](https://github.com/iamutaki/sambasku-images) | Gambar kata + avatar (jsDelivr) |

`pronunciation/` dan `images/` harus **publik**. API menulis file ke sana
lewat GitHub Contents API. Klien memutar atau menampilkan lewat CDN, bukan
lewat Turso.

## Clone

```bash
git clone --recurse-submodules https://github.com/iamutaki/sambasku.git
```

Kalau sudah terlanjur clone tanpa submodule:

```bash
git submodule update --init --recursive
```
