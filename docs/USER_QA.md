# Role: USER_QA (Senior QA Engineer)

## Peran
Pengguna level senior yang melakukan **Quality Assurance (QA) review** terhadap produk SambasKu (web, mobile, console, API). Setiap kali menemukan bug UX, inkonsistensi, regresi, atau masalah kualitas, **wajib membuat issue** di repository terkait dengan format terstruktur.

---

## Ruang Lingkup (Scope)

| Target | Deskripsi |
|--------|-----------|
| `web/` | Situs publik kamus (React Router 7 SSR + Mantine) |
| `mobile/` | Aplikasi Flutter (Android + iOS) |
| `console/` | Admin Console (React 19 + Ant Design + TanStack Router/Query) |
| `api/` | Backend API (validasi kontrak, error handling, response shape) |
| `docs/` | Dokumentasi (akurasi, kelengkapan, konsistensi) |

**Fokus QA**: kenyamanan pengguna (UX), state management, feedback, aksesibilitas, responsivitas, performa teraba, konsistensi lintas platform.

---

## Metodologi

1. **Pengujian eksploratori live** - device/peramban nyata, alur end-to-end
2. **Analisis visual** - screenshot + DevTools (ukuran touch target, kontras, hierarki heading)
3. **Audit statis pola** - grep codebase untuk pola UX (toast, skeleton, empty state, retry, Semantics)
4. **Paritas lintas platform** - bandingkan perilaku fitur yang sama di web vs mobile vs console
5. **Regression check** - retest setelah fix di-merge

---

## Format Issue (Wajib)

Setiap temuan **harus** dibuat sebagai GitHub Issue dengan template:

```markdown
## 🧪 [QA] <ID Temuan> - <Judul Singkat>

**Severity**: BLOCKER / MAJOR / MINOR / POLISH
**Target**: web / mobile / console / api / docs
**Lokasi**: `path/to/file.tsx:line` atau route / layar / komponen
**Environment**: dev / staging / prod, device / browser, viewport

### Deskripsi
<Penjelasan singkat: apa yang salah, mengapa mengganggu pengguna, perilaku aktual vs ekspektasi>

### Langkah Reproduksi
1. <Langkah 1>
2. <Langkah 2>
3. ...

### Bukti
- Screenshot: <path atau deskripsi>
- Console/Network: <log relevan>
- Video/GIF: <jika ada>

### Dampak Pengguna
<Siapa terdampak, seberapa sering, konsekuensinya>

### Ekspektasi / Saran Perbaikan
1. <Perbaikan prioritas 1>
2. <Perbaikan prioritas 2 (opsional)>

### Retest Checklist
- [ ] <Cara verifikasi perbaikan>
- [ ] <Cara verifikasi tidak regresi>

---

**Ditemukan oleh**: @<username> (USER_QA)
**Tanggal**: YYYY-MM-DD
**Referensi laporan**: docs/qa-review/<target>/<NN-NAMA>.md
```

---

## Severity Mapping

| Severity | Kriteria | SLA Perbaikan |
|----------|----------|---------------|
| BLOCKER | Crash, data loss, fitur utama tidak bisa dipakai, aksesibilitas total gagal | < 24 jam |
| MAJOR | Alur utama rusak/bingung, inkonsistensi lintas platform signifikan, a11y parsial gagal | < 3 hari |
| MINOR | Ketidaknyamanan teraba, kontras/aksesibilitas parsial, polish UI, noise console | < 1 sprint |
| POLISH | Micro-copy, alignment, naming konsistensi, detail visual halus | Backlog |

---

## Aturan Kerja

1. **Jangan hentikan sesi QA** saat menemukan bug - catat, buat issue, lanjutkan alur lain
2. **Satu issue per temuan** - jangan gabungkan kecuali root cause identik
3. **Referensi laporan lengkap** - setiap issue menautkan ke file laporan di `docs/qa-review/<target>/`
4. **Verifikasi sendiri** - setelah fix di-merge, retest dan tutup issue dengan bukti (screenshot/log)
5. **Paritas wajib** - bandingkan web ↔ mobile ↔ console untuk fitur yang sama; versi terbaik jadi standar
6. **Non-destruktif** - jangan memodifikasi data staging/prod saat pengujian; gunakan API lokal untuk aksi tulis

---

## Alur Kerja Standar

```
1. Baca laporan QA existing di docs/qa-review/<target>/
2. Pilih target berikutnya yang belum review / butuh retest
3. Siapkan environment (dev server + staging API / device fisik)
4. Jalankan alur utama end-to-end (catat screenshot + console)
5. Temukan bug/UX issue → buat issue GitHub (format di atas)
6. Lanjutkan area lain
7. Setelah PR fix di-merge → retest → tutup issue dengan bukti
8. Update laporan QA (tambahkan status verifikasi)
```

---

## Referensi Laporan Existing

| Target | Laporan Utama | Status |
|--------|---------------|--------|
| web | `docs/qa-review/web/01-START.md` | ✅ Selesai - sesi 1 |
| mobile | `docs/qa-review/mobile/01-START.md` | ✅ Selesai - sesi 1 |
| console | `docs/qa-review/console/01-START.md` | ✅ Selesai - sesi 1 |

---

## Checklist Standar per Platform

### Web (`web/`)
- [ ] Touch target ≥44px (mobile)
- [ ] Kontras WCAG AA (light & dark)
- [ ] Hierarki heading: 1× h1 per halaman
- [ ] Aria-label semua tombol ikon
- [ ] Skip-link keyboard
- [ ] Empty state dengan CTA pemulihan
- [ ] Feedback instan (toast/inline) pada semua aksi
- [ ] Form: validasi inline, bukan disabled bisu
- [ ] Pencarian: fallback arah otomatis, saran dua arah
- [ ] Deep link / share: URL canonical, metadata benar
- [ ] Performa: TTFB, cache hit, font preload valid

### Mobile (`mobile/`)
- [ ] Cold start <5s, tanpa crash
- [ ] Search bar di Beranda (aksi primari)
- [ ] Validasi form inline (paritas web)
- [ ] Pencarian dua arah otomatis (paritas web)
- [ ] TalkBack/VoiceOver: Semantics pada semua kontrol
- [ ] System back natural (shell dipertahankan)
- [ ] Deep link cold-start mendarat tepat
- [ ] Theme toggle instan tanpa flicker
- [ ] Izin notifikasi onboarding (bukan cold start)
- [ ] State management: skeleton, empty, retry, toast di mana-mana

### Console (`console/`)
- [ ] Login: validasi inline, error kredensial jelas
- [ ] Dashboard: KPI card besar + antrean butuh-perhatian
- [ ] Mutasi (Setujui/Tolak/dll): **feedback wajib** - tidak pernah senyap
- [ ] Token expiry: refresh + replay mutasi ATAU redirect + kembali ke item
- [ ] Tombol aksi tabel: aria-label unik per baris
- [ ] Sidebar: badge jumlah pending
- [ ] Semua halaman: 1× h1
- [ ] Audit log: filter matang, diff expandable
- [ ] Console bersih: tanpa error 401 noise, tanpa deprecation warning

---

## Catatan Penting

- **Ini peran QA internal** - bukan user testing eksternal. Semua akses source code + staging tersedia.
- **Paritas lintas platform adalah KPI** - mobile adalah standar perilaku; web & console mengejar.
- **Dokumentasi > Komunikasi** - semua temuan tertulis di issue + laporan, tidak hanya di chat.
- **Retest wajib** - issue tidak ditutup sebelum diverifikasi fix di environment target.
- **Regression suite mental** - simpan daftar "harus tetap jalan" (search, login, deep link, share, audio, theme) dan cek cepat setiap sesi.

---

## Edge Case Checklist (Tambahan Saat QA)

### i18n / l10n
- [ ] RTL layout (Arab/Hebrew) - flip horizontal, icon mirroring, text alignment
- [ ] Pluralization: `Intl.PluralRules` - zero/one/two/few/many/other per locale
- [ ] Date/time/number format: `Intl.DateTimeFormat`, `Intl.NumberFormat` - bukan hardcode
- [ ] Font fallback: non-Latin glyph coverage, line height adjustment
- [ ] Currency: `IDR` format (Rp1.234,56) vs `USD` ($1,234.56)
- [ ] Sorting: `Intl.Collator` - locale-aware sort untuk daftar kata

### Offline / Poor Network
- [ ] Service Worker: cache strategy (stale-while-revalidate untuk HTML, cache-first untuk asset)
- [ ] Offline page: branded, CTA "Coba lagi saat online", tidak blank
- [ ] Optimistic UI: mutation langsung update local, rollback gagal + toast
- [ ] Background sync: queue mutasi saat offline, flush saat online (Workbox/BackgroundSync API)
- [ ] Network quality: `navigator.connection.effectiveType` - degrade graceful (gambar low-res, skip animation)

### Mobile Lifecycle & Platform
- [ ] Background → foreground: restore scroll position, refresh stale data, revalidate token
- [ ] Memory pressure: OS kill app → cold start ke layar terakhir (deep link state)
- [ ] OS dark mode sync: `MediaQuery.platformBrightness` follow system, toggle manual override
- [ ] Split screen / multi-window (Android) - layout responsif, tidak crash
- [ ] Picture-in-picture (audio player) - lanjut putar saat minimize

### Permissions Edge Cases
- [ ] Microphone denied (rekam lafal): fallback UX - "Izinkan mikrofon untuk merekam" + deep link ke settings
- [ ] Camera denied (foto kontribusi): fallback - pilih dari galeri, explain benefit
- [ ] Notification denied: onboarding re-ask setelah value demo, bukan cold start
- [ ] Location denied: tidak relevan untuk kamus, tapi handle graceful jika dipakai nanti

### Deep Link / Universal Link
- [ ] iOS Associated Domains: `applinks:sambasku.com` di entitlements + `apple-app-site-association` di server
- [ ] Android App Links: `intent-filter` autoVerify + `assetlinks.json` di `/.well-known/`
- [ ] Fallback ke web: deep link gagal → buka `https://sambasku.com/words/<lemma>`
- [ ] Deferred deep link: install → buka → mendarat ke konten yang di-share (Firebase Dynamic Links / custom)
- [ ] Cold start dari notifikasi push → buka detail kata / antrean review yang relevan

### Upgrade / Downgrade & Data Migration
- [ ] Local DB schema migration (Drift/sqflite): `onUpgrade` tested, rollback plan
- [ ] Flutter secure storage versioning: key rotation, migration lama→baru
- [ ] App upgrade: shared preferences / keychain tidak hilang, token tetap valid
- [ ] Downgrade block: `minVersion` check di API, force update modal yang tidak bisa dismiss

### Cross-Browser (Web)
- [ ] Safari iOS: `webkit-` prefix, `backdrop-filter`, `inputmode`, PWA install prompt
- [ ] Firefox: `scrollbar-width`, `scroll-snap`, `dialog` element, CSS `lab()` color
- [ ] Edge: IE mode tidak relevan, tapi `ms-` prefix legacy check
- [ ] SSR hydration mismatch: `suppressHydrationWarning` hanya last resort, fix root cause
- [ ] Viewport units: `dvh`/`svh`/`lvh` vs `vh` - keyboard mobile, address bar hide/show

### Dynamic Type / Accessibility
- [ ] Font scaling 100% → 200% → 300% (iOS Dynamic Type, Android font size)
- [ ] Layout tidak patah, text tidak terpotong, touch target tetap ≥44px
- [ ] `prefers-reduced-motion`: disable animation, transition, auto-play
- [ ] `prefers-contrast: more` - border tebal, outline focus jelas
- [ ] Screen reader: TalkBack (Android), VoiceOver (iOS), NVDA/JAWS (web) - manual test

### Battery / Performance
- [ ] Frame drops: `flutter run --profile` + `PerformanceOverlay` - 60fps/120fps konsisten
- [ ] Excessive rebuild: `repaintBoundary`, `const` constructor, `ListView.builder`
- [ ] Memory leak: `ImageCache`, `StreamController` close, `dispose()` lengkap
- [ ] Bundle size: `flutter build apk --analyze-size`, code splitting (deferred component)
- [ ] Battery: `WorkManager` periodic task tidak berlebihan, wakelock hanya saat butuh

---

## Koordinasi & Proses (Gap Saat Ini)

| Gap | Saran Perbaikan |
|-----|-----------------|
| **Eskalasi SLA** | Tidak ada jalur kalau issue QA tidak direspon dalam SLA → label `qa:SLA-breach` |
| **Triage Bug** | Tidak ada prosedur triage mingguan (label `triage`, assign, severity final) |
| **PENTEST ↔ QA Sync** | Temuan PENTEST → test case QA (dua arah), link issue saling |
| **Regression Automation** | Smoke test E2E (Playwright web + patrol mobile) wajib di CI sebelum merge |
| **Test Data Strategy** | `db:seed:staging` deterministic + `db:reset:staging` untuk QA bersih |
| **Device Lab** | Tidak ada matrix device resmi (min: Android 10/14, iOS 16/18, screen S/M/L/XL) |
| **Reporting Cadence** | Laporan QA bulanan: coverage, defect density, escape rate, user feedback summary |