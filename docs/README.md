<p align="center">
  <img src="logo.png" alt="SambasKu" width="320" />
</p>

# SambasKu Docs

Dokumentasi kanonik **Kamus Digital Sambas-Indonesia**. Ini sumber
keputusan untuk kontrak API, base stack tiap klien, sample JSON,
backlog, dan strategi produk. Bukan kode aplikasi.

## Aturan sinkronisasi (WAJIB)

Perubahan endpoint / bentuk response di `api/` **wajib** diikuti dalam
PR yang sama:

1. Dokumen kontrak di `api/` (atau update yang sudah ada)
2. File `.bru` di [sambasku-http](https://github.com/iamutaki/sambasku-http)
3. Sample JSON di `json/`
4. Blok `docs { }` pada request Bruno terkait

Tiga sumber contoh (OpenAPI di API, Bruno docs, folder `json/`) jangan
saling tertinggal. Envelope standar: `api/api-base-stack.md` Section 13.

## Struktur

| Folder | Isi |
| --- | --- |
| `api/` | Kontrak endpoint, `api-base-stack.md`, ADR Turso |
| `admin/` | Base stack + alur konsol admin + `CONSOLE-I18N.md` |
| `web/` | Base stack situs publik (SSR) + `WEB-I18N.md` |
| `webmaster/` | SEO / penemuan konten: [`01-inspeksi-seo.md`](./webmaster/01-inspeksi-seo.md), [`VERIFIKASI-CONSOLE.md`](./webmaster/VERIFIKASI-CONSOLE.md) |
| `mobile/` | Base stack aplikasi Flutter + `MOBILE-I18N.md` |
| [`UI.md`](./UI.md) | Prompt meta desain layout mobile (ChatGPT / Gemini / Qwen) |
| [`ROADMAP_PLAN.md`](./ROADMAP_PLAN.md) | Strategi produk 8 kuartal + Year 3+ (living culture) |
| [`MONETIZE_PLAN.md`](./MONETIZE_PLAN.md) | Sustainability: kemitraan, grant, B2B, listing |
| [`PLAN_STACK_FIX.md`](./PLAN_STACK_FIX.md) | Maturity keamanan/kualitas + evidence pack mitra |
| `pentest/` | Baseline temuan keamanan white-box per stack |
| `qa-review/` | Baseline temuan UX / a11y |
| `json/` | Sample response kanonik (mock, fixture, kontrak) |
| `produk/` | Catatan produk |
| `env/` | Catatan variabel lingkungan lintas repo |
| `backlogs/` | Pekerjaan ditunda; yang selesai di `backlogs/done/` |

## Mulai dari sini

| Peran | Bacaan pertama |
| --- | --- |
| Backend | [`api/api-base-stack.md`](./api/api-base-stack.md) |
| Admin | [`admin/admin-base-stack.md`](./admin/admin-base-stack.md) |
| Web publik | [`web/web-base-stack.md`](./web/web-base-stack.md) |
| Mobile | [`mobile/mobile-base-stack.md`](./mobile/mobile-base-stack.md) |
| Desain layout mobile (prompt AI) | [`UI.md`](./UI.md) |
| Proto HTML mobile | [`proto/mobile/CURSOR-PROTO/`](./proto/mobile/CURSOR-PROTO/) |
| i18n web (prioritas) | [`web/WEB-I18N.md`](./web/WEB-I18N.md) |
| i18n mobile | [`mobile/MOBILE-I18N.md`](./mobile/MOBILE-I18N.md) |
| i18n console | [`admin/CONSOLE-I18N.md`](./admin/CONSOLE-I18N.md) |
| Sample JSON | [`json/README.md`](./json/README.md) |
| Strategi produk (roadmap) | [`ROADMAP_PLAN.md`](./ROADMAP_PLAN.md) |
| Monetisasi / kemitraan | [`MONETIZE_PLAN.md`](./MONETIZE_PLAN.md) |
| Kredibilitas stack / mitra | [`PLAN_STACK_FIX.md`](./PLAN_STACK_FIX.md) |
| Backlog aktif | [`backlogs/NEXT.md`](./backlogs/NEXT.md) |
| Cache klien (backlog) | [`backlogs/CACHE.md`](./backlogs/CACHE.md) |
| Failover API | [`backlogs/FAILOVER.md`](./backlogs/FAILOVER.md) |

## Aset terkait (repo terpisah)

| Repo | Peran |
| --- | --- |
| [sambasku-api](https://github.com/iamutaki/sambasku-api) | Implementasi kontrak |
| [sambasku-http](https://github.com/iamutaki/sambasku-http) | Koleksi Bruno |
| [sambasku/images](https://github.com/sambasku/images) | Gambar kata + avatar (jsDelivr) |
| [sambasku/audios](https://github.com/sambasku/audios) | Audio pelafalan (jsDelivr) |

## Gaya tulisan

Tanpa em/en dash gaya AI (`-`, `-`). Pakai hyphen ASCII (`-`). Berlaku
untuk docs, komentar, dan copy UI yang digambar dari dokumen ini.
