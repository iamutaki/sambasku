# PLAN STACK FIX - Program kredibilitas stack

Dokumen program maturity kanonik: memperbaiki disiplin struktur kode
dan kontrol keamanan/kualitas agar *trust center* SambasKu **bisa
dibuktikan** kepada mitra (Pemkab, grant, due diligence), bukan hanya
dijanjikan di pitch.

| Dokumen | Peran |
| ------- | ----- |
| **Ini** (`PLAN_STACK_FIX.md`) | Program maturity P0-P3, mapping standar, gate eng, evidence pack |
| [`ROADMAP_PLAN.md`](./ROADMAP_PLAN.md) | Strategi produk, vertikal, gate bisnis |
| [`MONETIZE_PLAN.md`](./MONETIZE_PLAN.md) | Jalur kemitraan / grant / B2B (butuh bukti teknis) |
| [`api/api-base-stack.md`](./api/api-base-stack.md) | Kontrak arsitektur & testing backend |
| [`mobile/mobile-base-stack.md`](./mobile/mobile-base-stack.md) | Kontrak arsitektur mobile |
| [`web/web-base-stack.md`](./web/web-base-stack.md) | Kontrak arsitektur web publik |
| [`admin/admin-base-stack.md`](./admin/admin-base-stack.md) | Kontrak arsitektur konsol admin |
| [`pentest/`](./pentest/) | Baseline temuan keamanan white-box (2026-09-24) |
| [`qa-review/`](./qa-review/) | Baseline temuan UX / a11y |
| [`backlogs/NEXT.md`](./backlogs/NEXT.md) | Slice engineering near-term (nilai ÷ usaha) |

Dokumen ini **mengorkestrasi** artefak di atas. Detail temuan tetap di
laporan pentest/QA; detail kontrak tetap di base-stack. Setiap kuartal,
PO memecah fase aktif di sini menjadi item di `NEXT.md`.

**Klaim jujur:** ini **bukan** rencana beli sertifikat ISO. Output =
*readiness* + *evidence pack* yang bisa diaudit. Sertifikasi formal
(jika pernah) adalah keputusan bisnis terpisah Year 3+.

---

## 1. Ringkasan eksekutif

**North star:** SambasKu adalah *trust center* bahasa Melayu Sambas.
Mitra membayar (atau menghibahkan) untuk **kanal terpercaya** - bukan
untuk "app baru". Kepercayaan itu harus bisa ditunjukkan lewat kontrol
teknis, audit trail, dan bukti remediasi - bukan hanya narasi produk.

**Tiga pilar maturity**

| Pilar | Inti | Acuan yang dipakai |
| ----- | ---- | ------------------ |
| Keamanan | AuthN/Z, session, rate limit, headers, secret, logging | ISO/IEC 27001 *aligned* + OWASP ASVS L1→L2 |
| Kualitas perangkat lunak | Maintainability, reliability, usability, a11y | ISO/IEC 25010 + base-stack clean architecture |
| Bukti & tata kelola | Evidence pack mitra, privasi ringan, IR/backup | Soft gate sebelum MoU jalur A/B di monetize |

**Status hari ini (baseline 2026-09)**

Fondasi sudah kuat:

- JWT RS256, refresh ter-hash + rotasi, OTP ter-hash + batas percobaan
- Role enforcement di API; audit trail mutasi; Zod di boundary
- Clean architecture terdokumentasi per stack; dual-runtime API
- Pentest white-box + QA UX sudah dijalankan dan tersimpan di repo

Gap terbesar untuk kredibilitas eksternal:

1. Temuan HIGH/MEDIUM pentest belum ditutup sebagai program resmi
2. Belum ada *evidence pack* satu paket untuk mitra / grant
3. Aturan base-stack belum semuanya jadi **gate** yang gagalkan PR

**Cara pakai**

1. Eng menutup P0/P1 sebagai hardening wajib (parallel produk boleh).
2. PO menjadwalkan P2/P3 tanpa memblok Explore roadmap.
3. Saat pitch Pemkab/grant: lampirkan ringkasan Section 6 (atau folder
   `docs/credibility/` setelah P3).

---

## 2. Peta standar → kontrol SambasKu

Mapping **pragmatis**. Bukan checklist sertifikasi 1:1. Setiap baris
menunjuk bukti yang sudah (atau akan) ada di repo.

| Acuan | Apa yang kita ambil | Bukti di repo / praktik |
| ----- | ------------------- | ----------------------- |
| ISO/IEC 27001 (*aligned*) | Inventaris aset & supplier, akses berdasar peran, logging/audit, penanganan secret, backup/restore, respons insiden ringan | `audit_logs`, wrangler/GitHub secrets, CI `environment: production`, pentest, Section 21 base-stack API |
| OWASP ASVS L1 → L2 | AuthN/Z, session, validasi input, crypto password, API abuse, konfigurasi klien (mobile/web/console) | `00-api-auth.md`, role matrix Section 22, Zod OpenAPI, secure storage mobile, cookie httpOnly console |
| ISO/IEC 25010 | Security, reliability, maintainability, usability, accessibility, portability | Empat/tiga lapisan per stack, Vitest + widget test, QA a11y, dual-runtime Node/Workers |
| UU PDP / privasi ringan | Transparansi data, consent analytics, retensi tinggi-level, tidak jual PII | Kebijakan privasi publik (P3), temuan M-09/M-10, anti-goal monetize "jangan jual data pribadi" |

**Yang tidak diklaim**

- "ISO 27001 certified" / "ASVS certified" di store, pitch, atau MoU
- "Compliance lawyer-approved" untuk UU PDP
- Audit pihak ketiga wajib tiap kuartal (cukup delta retest internal
  sampai Ada kebutuhan mitra yang meminta eksternal)

---

## 3. Baseline gap (dari artefak yang sudah ada)

Sumber: [`pentest/`](./pentest/) (API / web / mobile / console) dan
[`qa-review/`](./qa-review/). Severity mengikuti laporan asli.

### 3.1 Matriks remediasi keamanan (P0 / P1)

| ID | Stack | Severity | Bucket | Fase |
| -- | ----- | -------- | ------ | ---- |
| W-01 | web | HIGH | Headers / CSP / availability | **P0** |
| C-01 | console | HIGH | Headers / clickjacking / HSTS | **P0** |
| A-01 | api | MEDIUM | Rate limit (Workers isolate) | **P0** |
| A-02 | api | MEDIUM | Abuse kontribusi anonim | **P0** |
| A-03 | api | MEDIUM | Trusted proxy / IP key | **P0** |
| M-01 | mobile | MEDIUM | Token di RAM (network monitor rilis) | **P0** |
| M-02 | mobile | MEDIUM | Unbounded monitor buffer | **P0** |
| W-02 | web | MEDIUM | CSP `unsafe-inline` / `unsafe-eval` | P1 |
| W-03 | web | MEDIUM | Cache key flooding | P1 |
| W-04 | web | MEDIUM | Failover pin isolate / tanpa RL Worker | P1 |
| C-02 | console | MEDIUM | Route guard role (defense-in-depth) | P1 |
| A-04 | api | LOW | JWT `iss` / `aud` | P1 |
| A-05 | api | LOW | Dashboard tanpa `authorizeRole` | P1 |
| A-06 | api | LOW | Security headers API | P1 |
| A-07 | api | LOW | `/docs` + OpenAPI publik | P1 |
| M-03..M-07 | mobile | LOW | Log rilis, backup, signing, deeplink, FCM path | P1 |
| W-05..W-12 | web | LOW | COOP/CORP, error leak, token query, img allowlist, dll. | P1 |
| C-03..C-06 | console | LOW / INFO | URL skema, deep_link validasi, role fallback, noindex | P1 |

Detail dan remediasi teknis: buka laporan per stack, jangan salin ulang
di sini.

- API: [`pentest/api/01-START.md`](./pentest/api/01-START.md)
- Web: [`pentest/web/01-START.md`](./pentest/web/01-START.md)
- Mobile: [`pentest/mobile/01-START.md`](./pentest/mobile/01-START.md)
- Console: [`pentest/console/01-START.md`](./pentest/console/01-START.md)

### 3.2 Gap kualitas (ISO/IEC 25010 → P2)

| Area 25010 | Gap tipikal (dari QA / base-stack) | Fase |
| ---------- | ---------------------------------- | ---- |
| Usability | Validasi form web bisu vs mobile inline; search web belum dua arah otomatis | P2 |
| Accessibility | Semantics/TalkBack tipis di mobile; touch target web di bawah 44px pada aksi utama | P2 |
| Maintainability | Drift kontrak tanpa update Bruno/json/OpenAPI; bypass lapisan tanpa ADR | P1 gate + P2 |
| Reliability | Rate limit / failover (sebagian di P0/P1); retry form kontribusi | P1-P2 |
| Security | Lihat Section 3.1 | P0-P1 |

Sumber UX: [`qa-review/mobile/01-START.md`](./qa-review/mobile/01-START.md),
[`qa-review/web/01-START.md`](./qa-review/web/01-START.md),
[`qa-review/console/01-START.md`](./qa-review/console/01-START.md).

### 3.3 Gap bukti eksternal (P3)

| Artefak | Status hari ini |
| ------- | --------------- |
| Security Overview 1-pager mitra | Belum (kontrol positif tersebar di pentest P-*) |
| Privacy policy publik + consent analytics | Belum lengkap sebagai paket |
| Register aset & supplier (CF, Turso, ImageKit, Resend, dll.) | Implisit di base-stack / env |
| Runbook backup / restore / kontak insiden | Praktik di CI deploy; belum dokumen mitra |
| Retest pentest bertanggal setelah remediasi | Belum sebagai ritual resmi |
| Folder `docs/credibility/` siap lampiran MoU | Belum (dijanjikan di P3) |

---

## 4. Program fase (P0 → P3)

```text
P0 CloseCritical → P1 HardenAndGates → P2 Quality25010 → P3 EvidencePack
```

P0/P1 **boleh parallel** fitur produk (Explore, kontribusi). P2/P3
dijadwalkan agar tidak mematikan growth; tetap punya exit criteria
yang bisa dilampirkan ke mitra.

### 4.1 P0 - Close critical

**Tujuan:** tutup temuan yang merusak narasi "aman untuk mitra" dalam
satu putaran singkat.

**Cakupan wajib**

| ID | Aksi ringkas |
| -- | ------------ |
| W-01 | CSP produksi memuat host failover yang benar; redeploy + verifikasi header live |
| C-01 | `_headers` / Pages headers: CSP, X-Frame-Options, HSTS, Permissions-Policy (parity web) |
| A-01 | Rate limit bersama (WAF edge, DO, atau counter Turso) - bukan hanya memori isolate |
| A-02 | Rate limit + honeypot/challenge pada kontribusi anonim |
| A-03 | IP key hanya dari trusted source (`cf-connecting-ip` / proxy trust) |
| M-01 | Network monitor **mati** di build rilis; clear records saat logout |
| M-02 | Cap buffer monitor (hanya relevan di non-rilis setelah M-01) |

**Owner tipikal:** eng per stack. **PO:** pastikan masuk sprint, bukan
hanya backlog abadi.

**Exit criteria**

- Semua baris P0 di tabel 3.1 berstatus closed di catatan retest
- Retest singkat (live header + source check) tercatat sebagai addendum
  di folder pentest atau changelog Section 8 di bawah
- Tidak ada HIGH terbuka

**Artefak bukti:** tabel "Closed (tanggal)" + link PR; screenshot/
header dump untuk W-01 dan C-01.

### 4.2 P1 - Harden and gates

**Tujuan:** defense-in-depth + mencegah drift arsitektur kembali.

**Cakupan**

- Sisa MEDIUM/LOW pentest yang berdampak ASVS (W-02..W-04, C-02,
  A-04..A-07, M-03..M-07, dll. - prioritaskan yang murah + terlihat mitra)
- Security headers API (A-06); batasi inventaris OpenAPI di prod bila perlu (A-07)
- **Gate engineering** Section 5 aktif di review/CI sejauh praktis

**Exit criteria**

- Console security headers = parity web (sudah dari P0; dijaga di CI/docs)
- Checklist ASVS L1 internal terisi (lampiran ringan di PR atau
  `docs/credibility/` draft)
- PR fitur baru yang langgar envelope / sync Bruno-json-OpenAPI ditolak
  di review
- Tidak ada MEDIUM rate-limit / token-leak baru tanpa ticket remediasi

**Artefak bukti:** checklist ASVS L1 bertanggal; daftar PR gate;
addendum pentest delta.

### 4.3 P2 - Quality (ISO/IEC 25010)

**Tujuan:** pengalaman dan maintainability setara janji *trust center*.

**Cakupan**

- Samakan perilaku produk inti web ↔ mobile (validasi inline, search
  dua arah) - mobile sebagai standar perilaku
- A11y: Semantics/label pada aksi ikon-only layar inti (detail kata,
  nav, tema, audio)
- Touch target & kontras dari QA major
- Coverage test sesuai base-stack: use case baru = unit; endpoint baru =
  E2E minimal; layar kunci = widget test
- Larangan bypass lapisan tanpa ADR singkat di `docs/api/` atau modul

**Exit criteria**

- Temuan QA **Major** untuk alur inti (cari, detail, auth, kontribusi)
  ditutup atau punya ticket bertanggal
- Tidak ada bypass clean-architecture baru tanpa ADR
- Semantics/label pada kontrol ikon-only layar inti mobile

**Artefak bukti:** ringkasan QA retest; daftar ADR; metrik tes CI hijau
pada path kritis.

### 4.4 P3 - Evidence pack

**Tujuan:** satu paket yang bisa dilampirkan ke MoU / grant tanpa
mengirim seluruh repo.

**Deliverable folder** (dibuat di fase ini, bukan sekarang):

```text
docs/credibility/
├── README.md                 # cara pakai paket untuk PO / mitra
├── SECURITY_OVERVIEW.md      # 1-pager arsitektur + kontrol
├── DATA_HANDLING.md          # PII, retensi tinggi-level, analytics
├── ASSET_SUPPLIER_REGISTER.md
├── INCIDENT_AND_BACKUP.md    # kontak + runbook ringkas
├── REMEDIATION_STATUS.md     # ID temuan → closed/open + tanggal
└── PENTEST_SUMMARY.md        # ringkasan non-teknis + link laporan penuh
```

**Exit criteria**

- Folder di atas lengkap dan direview PO
- Privacy policy publik live (URL stabil)
- Ritual: delta retest setelah perubahan kontrol material (auth, RL,
  headers) - minimal catatan tanggal
- Taut dari [`MONETIZE_PLAN.md`](./MONETIZE_PLAN.md) jalur A/B: evidence
  pack = prasyarat soft sebelum MoU konten resmi

**Artefak bukti:** ZIP/PDF pilihan dari folder (generate manual saat
diminta mitra); jangan commit secret.

---

## 5. Gate engineering (perbaiki struktur tanpa rewrite)

Prinsip: **enforce + close gap**, bukan redesign stack. Base-stack tetap
sumber kontrak; gate memastikan PR tidak mengikisnya.

### 5.1 API (`api/`)

| Gate | Aturan | Acuan |
| ---- | ------ | ----- |
| Arah dependency | Presentation → Application → Domain; Infrastructure mengimplementasikan port/repo | api-base-stack Section 2-3 |
| Boundary | Zod (+ OpenAPI) di tiap endpoint baru; envelope Section 13 | Section 11, 13 |
| AuthZ | Write sensitif lewat `authenticate` + `authorizeRole` sesuai matriks | Section 22, `00-api-auth` |
| Audit | Mutasi data penting → `audit_logs` | Section 21 |
| Testing | Use case baru → unit; repo impl baru → integration; endpoint baru → ≥1 E2E | Section 10 |
| Sync kontrak | PR yang ubah response/endpoint wajib update docs API + Bruno + `docs/json` | [`README.md`](./README.md) |

### 5.2 Mobile (`mobile/`)

| Gate | Aturan |
| ---- | ------ |
| Lapisan | Page/notifier tidak memanggil Dio langsung; lewat use case → repository |
| Error | `Either<Failure, T>` di batas data; tidak swallow exception diam-diam |
| Token | Hanya `flutter_secure_storage`; monitor jaringan **off** di rilis (P0) |
| Busy multi-CTA | `pendingAction`, bukan `isSubmitting` global (lihat mobile-base-stack) |
| Testing | Use case unit + widget test form/layar kunci untuk fitur baru |

### 5.3 Web publik (`web/`)

| Gate | Aturan |
| ---- | ------ |
| Fetch | Route/halaman **tidak** `fetch` langsung; lewat use case → `apiClient` |
| Env | Hanya `infrastructure/config/env.ts` membaca `import.meta.env` |
| Domain | Entity murni TS; tanpa React/Mantine |
| Security | Header Worker + CSP dijaga parity dengan temuan W-*; fail keras bila env prod kosong |

### 5.4 Console admin (`console/`)

| Gate | Aturan |
| ---- | ------ |
| Session | Access token hanya memori; refresh httpOnly Strict |
| AuthZ UI | Guard route berdasar role (defense-in-depth; API tetap sumber kebenaran) |
| Headers | `_headers` / Pages headers wajib di setiap deploy |
| URL user-content | Hanya skema `https:` untuk anchor dari data kontribusi |

### 5.5 Anti-drift (lintas stack)

1. Perubahan kontrak API tanpa update docs + Bruno + json → **gagal review**.
2. Imppor lintas lapisan melawan arah dependency → tolak atau wajib ADR.
3. Menambah secret/env baru tanpa daftar di base-stack / `.env.example` → tolak.
4. "Hanya sementara" bypass rate limit / auth di prod path → tolak.

Gate otomatis penuh (eslint boundary, CI sync-check) boleh menyusul;
sampai saat itu **review checklist** di PR template cukup sebagai P1.

---

## 6. Evidence pack eksternal

Dipakai saat due diligence Pemkab, lembaga hibah, atau CSR. Isi
mengacu Section 4.4. Di bawah ini: kerangka yang mitra biasanya minta.

### 6.1 Ringkasan arsitektur & trust boundary

Sketsa untuk `SECURITY_OVERVIEW.md`:

```text
[Mobile / Web / Console]
        |  HTTPS
        v
[Cloudflare edge: WAF / headers / cache]
        |
        v
[API Hono - JWT verify, Zod, rate limit, role]
        |
        +--> Turso/libSQL (data + audit_logs)
        +--> ImageKit / jsDelivr (media)
        +--> Mailer (OTP, reset)
```

Batas: klien tidak dipercaya untuk AuthZ; API menegakkan peran; secret
hanya di platform hosting / GitHub Environments.

### 6.2 Ringkasan kontrol (dari temuan positif pentest)

Contoh poin yang sudah terbukti di laporan (kutip ID P-* per stack saat
menulis overview):

- JWT asimetris RS256; refresh ter-hash; OTP ter-hash + attempt limit
- Anti-enumerasi login / forgot-password
- OAuth Google/Facebook diverifikasi server-side
- Console: access token hanya memori; cookie refresh Strict
- Mobile: secure storage + obfuscation CI rilis
- Web: escaping React, header keamanan inti, noindex staging

Update daftar ini setiap kali P0/P1 menutup temuan negatif.

### 6.3 Status remediasi

Tabel hidup di `REMEDIATION_STATUS.md`: ID → severity → status →
tanggal closed → PR. Sumber awal: Section 3.1 dokumen ini.

### 6.4 Kebijakan akses peran

Ringkas matriks role (contributor / verifier / admin) dari
api-base-stack Section 22 + `00-api-auth.md`. Mitra konten resmi:
**editor terbatas**, bukan root (selaras monetize).

### 6.5 Penanganan data pribadi & retensi

Tinggi-level saja: akun, email, token, UDID perangkat, analytics
behavioral. Jelaskan: tidak jual PII; retention refresh/OTP; jalur
hapus akun bila sudah ada di produk. Consent analytics (M-10) masuk
sini.

### 6.6 Kontak insiden + backup

- Kontak teknis / keamanan (email atau channel yang dipantau)
- Backup sebelum migrate production (praktik CI yang sudah ada)
- Restore drill: frekuensi target (mis. 1× per semester) - catat hasil

**Kaitan monetize:** jalur A (grant) dan B (Pemkab) di
[`MONETIZE_PLAN.md`](./MONETIZE_PLAN.md) memakai evidence pack sebagai
**prasyarat soft** sebelum MoU distribusi konten resmi.

---

## 7. Anti-goal & batas

| Larangan | Alasan |
| -------- | ------ |
| Klaim "ISO certified" / "ASVS certified" di store atau pitch | Dokumen ini readiness, bukan sertifikat |
| Memblok seluruh roadmap Explore sampai checklist 100% | P0/P1 parallel; P2/P3 terjadwal |
| Audit ulang white-box penuh tiap kuartal | Mahal; pakai delta retest pada kontrol yang berubah |
| Scope konsultan ISO / biaya sertifikasi di dokumen ini | Keputusan bisnis Year 3+ terpisah |
| Menyalin seluruh laporan pentest ke pitch mitra | Kirim summary + overview; laporan penuh hanya NDA bila perlu |
| Menurunkan AuthZ hanya ke UI console | API tetap sumber kebenaran; C-02 hanya defense-in-depth |
| Paywall atau jual data demi "compliance theater" | Bertentangan misi & monetize anti-goal |

---

## 8. Jurnal remediasi & retest

Isi baris saat P0/P1 selesai (contoh format). Jangan hapus riwayat.

| Tanggal | ID | Aksi | Bukti | Retest |
| ------- | -- | ---- | ----- | ------ |
| (kosong) | - | Baseline pentest 2026-09-24 | `docs/pentest/*/01-START.md` | - |

---

## 9. Urutan kerja praktis (untuk `NEXT.md`)

Prioritas slice yang disarankan masuk backlog engineering:

1. **P0 batch keamanan** - W-01, C-01, A-01..A-03, M-01..M-02
2. **P1 headers & AuthZ UI** - A-06, C-02, sisa LOW berdampak visible
3. **P1 gate PR** - checklist anti-drift + (opsional) CI sync docs
4. **P2 UX/a11y inti** - dari QA major mobile/web
5. **P3 credibility folder** - saat mendekati pitch Pemkab/grant konkret

Produk Explore dan loop kontribusi tetap jalan; jangan campur ticket
maturity dengan ticket fitur tanpa label jelas (`security`, `quality`,
`credibility`).

---

## 10. Definisi selesai program (Definition of Done)

Program `PLAN_STACK_FIX` dianggap **fase aktif selesai** (bukan "selesai
selamanya") ketika:

1. Tidak ada temuan HIGH terbuka; MEDIUM P0 closed
2. Gate Section 5 dipakai di review rutin
3. `docs/credibility/` ada dan bisa dilampirkan dalam 1 hari kerja
4. Satu delta retest bertanggal setelah remediasi P0 tercatat di Section 8
5. Taut silang dari README + monetize/roadmap tetap akurat

Setelah itu: maintenance = delta retest + update evidence pack, bukan
proyek rewrite baru.
