# CONSOLE-I18N - Kontrak Multi-bahasa Konsol Admin

Kontrak dasar i18n untuk `console/` (admin frontend: React 19 + Vite +
Ant Design 6). **Dokumen ini adalah kontrak**; implementasi belakangan
(setelah atau paralel ringan dengan web). Setiap fitur admin baru wajib
mengikuti pola ini dan `docs/admin/admin-base-stack.md` (Section i18n).

Nama file: `CONSOLE-I18N.md` (bukan ADMIN-I18N) agar selaras nama
produk "Console Admin" di UI.

## 1. Tujuan & ruang lingkup

| Termasuk | Tidak termasuk |
| --- | --- |
| Label menu, breadcrumb, tombol, Tooltip, Modal, Form, tabel header, empty, Alert | Konten kamus dari API (lemma, makna, audit payload) |
| Locale komponen Ant Design (`ConfigProvider locale`) | SEO / hreflang (konsol noindex / di balik auth) |
| Pesan validasi form UI (bukan mengganti `message` API) | Menyimpan katalog UI di database |
| Language switcher di header konsol | Menerjemahkan `error_code` di client secara spekulatif |

Catatan: envelope API sudah berbahasa Indonesia (`message`,
`details[].message`). Fase awal **tetap tampilkan pesan API apa adanya**.
Locale UI mengatur chrome konsol; jangan double-translate pesan server
kecuali kelak API mengirim `error_code` stabil + katalog client (di luar
kontrak V1).

## 2. Locale registry (selaras web/mobile)

| Kode kanonik (BCP-47) | Label | Default | Ant Design locale pack |
| --- | --- | --- | --- |
| `id` | Bahasa Indonesia | ya | `antd/locale/id_ID` |
| `id-SBS` | Bahasa Sambas | tidak | fallback `id_ID` (antd belum punya pack Sambas) |

Aturan:

1. URL konsol **tidak** wajib ber-prefix locale (beda dari web publik).
   Locale = state app (memory + `localStorage` key `sk_console_locale`).
2. Mapping ke mobile/web memakai hyphen BCP-47 yang sama (`id`,
   `id-SBS`).
3. Locale baru: registry + JSON katalog + (opsional) pack antd.
4. Fallback string: `id`. Fallback komponen antd untuk locale tanpa pack:
   `id_ID`.

## 3. Stack pustaka (keputusan)

| Peran | Pilihan | Alasan |
| --- | --- | --- |
| Runtime | `i18next` + `react-i18next` | Sama keluarga dengan web; namespace; mudah port |
| Katalog | JSON di `src/shared/i18n/locales/{locale}/*.json` | Diff-friendly |
| Ant Design | `ConfigProvider locale={antdLocale}` dari map registry | Pagination, DatePicker, Empty bawaan antd |
| Persist | `localStorage` `sk_console_locale` | Preferensi worker |

Dilarang: string chrome baru hardcoded di `presentation/` setelah port
halaman itu; memakai dayjs locale Inggris untuk label bulan UI (tetap
ikuti helper `format-datetime.ts`; daftar bulan bisa diganti per locale
nanti tanpa memecah kontrak format).

## 4. Struktur folder

```text
console/src/shared/i18n/
├── locales.ts                 # registry + antd locale map + default
├── i18n.ts                    # init i18next (dipanggil dari main.tsx)
├── use-locale.ts              # baca/ubah locale + persist
└── locales/
    ├── id/
    │   ├── common.json
    │   ├── nav.json
    │   ├── words.json
    │   ├── contributions.json
    │   ├── auth.json
    │   └── errors.json
    └── id-SBS/
        └── (namespace 1:1 key dengan id)
```

Namespace awal:

| Namespace | Isi |
| --- | --- |
| `common` | Aksi umum, empty, konfirmasi, PageLoading tip generik |
| `nav` | Menu sider, breadcrumb labels, header, language switcher |
| `auth` | Login form |
| `words` | Halaman kata (kolom, filter, aksi Tooltip) |
| `contributions` | Antrean review |
| `errors` | Fallback UI bila tidak ada `error.message` API |

Fitur lain (`audit`, `bug-reports`, `dashboard`, …) menambah namespace
saat gelombang port, atau menambah file JSON setara nama fitur.

## 5. Konvensi key & pemakaian

1. Key konsisten lintas locale; nilai berbeda.
2. Interpolasi `{{var}}`.
3. Kolom tabel: header lewat `t('words:columns.lemma')`, bukan literal.
4. Tooltip aksi icon-only (wajib base stack): `title={t('words:actions.detail')}`.
5. `BREADCRUMB_LABELS` / `MENU_ROUTES`: label dari katalog `nav`, bukan
   string tetap di layout.
6. Jangan gabung potongan kalimat di TSX bila urutan kata bisa beda.
7. Tanpa em/en dash di nilai katalog.

```tsx
const { t } = useTranslation('words');
<Tooltip title={t('actions.detail')}>
  <Button type="link" icon={<EyeOutlined />} />
</Tooltip>
```

## 6. Integrasi main.tsx & layout

- Init i18n **sebelum** `createRoot().render`.
- `ConfigProvider` menerima `locale` antd dari registry menurut locale
  aktif (reaktif saat ganti bahasa).
- Switcher di header `console-layout` (dropdown kecil); worker admin
  jarang ganti bahasa, tapi kontrak menyiapkan dari awal.
- `document.documentElement.lang` di-update saat locale berubah.

Routing TanStack **tanpa** `/:locale`. Guard auth tidak berubah.

## 7. Format tanggal

Tetap lewat `shared/utils/format-datetime.ts`. Fase V1: format pola
sama untuk semua locale UI; daftar bulan mengikuti locale aktif bila
sudah disiapkan. Jangan `dayjs(...).format` inline (aturan base stack).

## 8. Port string (gelombang)

1. Inventarisasi literal halaman → key.
2. Isi `id` dulu, salin key ke `id-SBS`.
3. Ganti literal + pastikan Tooltip/Menu/Breadcrumb ikut.
4. Jangan port pesan mentah API di gelombang V1.

## 9. Testing & Definition of Done

Scaffold selesai bila:

- [ ] Registry + i18n init + persist
- [ ] `ConfigProvider` locale ikut ganti
- [ ] Switcher di header
- [ ] Namespace bootstrap terpasang
- [ ] `pnpm typecheck` / `lint` / `test` / `build` hijau

Port fitur selesai bila literal chrome di fitur itu hilang dari TSX
(kecuali konten API / data user).

## 10. Urutan eksekusi (disarankan)

1. **C0 - Scaffold**: i18next, registry, persist, switcher, antd map.
2. **C1 - Shell**: `nav` + `common` + `auth`.
3. **C2 - Words + contributions** (trafik harian tertinggi).
4. **C3 - Audit, bug reports, dashboard, sisa**.
5. **C4 - Review id-SBS**.

Prioritas lebih rendah dari web SEO; jangan menunda fitur moderasi
hanya demi port sempurna.

## 11. Referensi

- `docs/web/WEB-I18N.md` - kanonik locale + prioritas SEO web
- `docs/mobile/MOBILE-I18N.md` - Flutter ARB
- `docs/admin/admin-base-stack.md` - Section i18n
