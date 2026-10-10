# SEO web/* — `<lemma> bahasa sambas` + intent "Tanya terjemahan" → Ruang Diskusi + alert edukatif

## Goal

Satu kalimat: Maksimalkan peluang sambasku.com tampil untuk query `<lemma> bahasa sambas`, tangkap intent tanya-terjemahan dengan mengarahkannya ke Ruang Diskusi, dan pasang alert di Ruang Diskusi yang menjelaskan bahwa di sana kamu bisa bertanya soal bahasa & budaya Sambas.

## Konteks terverifikasi (dicek langsung, jangan difantasikan)

Path relatif ke `/Users/ibnulmutaki/Development/github/sambasku/web/`. Repo web = submodule terpisah, branch aktif `staging`, ada perubahan lokal milik user (`.env.production.example`, `README.md`, `locales.ts`, `analytics.ts`, `env.ts` — JANGAN disentuh/ di-commit).

1. **Fondasi SEO halaman kata SUDAH ADA** (`app/routes/words.$lemma.tsx`):
   - Title template i18n: `id.json:104` = `"{{lemma}} bahasa Sambas - arti & terjemahan"` (exact-match query), varian SBS `id-SBS.json:104`.
   - Kalimat lead SSR: `word_leadSentence` (`id.json:215`) = "Arti kata {{lemma}} dalam bahasa Sambas (Melayu Sambas)." — sudah SSR, ada komentar "jangan client-only".
   - JSON-LD `DefinedTerm` + `BreadcrumbList` via `buildWordJsonLd` (`app/application/utils/seo.ts:338`), dirender hanya `env.isProd && is_verified` (route line ~176-186).
   - `buildMetaTags` (`seo.ts:93`) sudah canonical + hreflang + OG/Twitter.
   **Kesimpulan: query "<lemma> bahasa sambas" SUDAH ter-cover di title/H1/lead/JSON-LD. Yang belum: keywords meta TIDAK ada (boleh ditambah, dampak kecil), dan TIDAK ada tautan silang ke Ruang Diskusi dari halaman kata.**
2. **Ruang Diskusi** (`app/routes/ruang-diskusi.tsx`, 254 lines):
   - Meta sekarang generik: title `'Ruang Diskusi'`, description "Baca obrolan warga..." (line 42-49). TIDAK memuat kata kunci "tanya terjemahan bahasa Sambas".
   - Belum ada JSON-LD. Belum ada alert/banner edukatif (yang ada kartu "Ingin ikut diskusi?" CTA download app, line ~155-178).
   - Route redirect lama `/bantuan-terjemahan` → `/ruang-diskusi` sudah ada (`bantuan-terjemahan-redirect.tsx`, 301 di prod) — aset SEO lama terpelihara.
   - Detail thread `ruang-diskusi.$id.tsx` `noindexAlways: true` (line 71) — benar, jangan diubah.
3. **Search page** `search.tsx` `noindexAlways: true` (thin content) — tidak disentuh.
4. **Testing**: `npm test` = `node --experimental-strip-types --test "app/**/*.test.ts"` (node:test + assert, BUKAN vitest). Test seo ada di `app/application/utils/seo.test.ts`. Gate lain: `npm run typecheck`, `npm run lint`.
5. i18n: SEMUA copy lewat `id.json` + `id-SBS.json` (`getFixedT`). Teks UI wajib bilingual dua file itu. Aturan copywriting repo (AGENTS.md §22): bahasa Indonesia santai, sapaan "kamu", max satu partikel (`ya`/`aja`) per kalimat, hyphen ASCII, error = sebab + aksi.
6. `npm test` di web TIDAK butuh DB/API (murni util).

## Pendekatan

Tiga perubahan: (1) perkuat halaman kata: keywords meta `{{lemma}} bahasa sambas, terjemahan...` + satu CTA inline ke Ruang Diskusi ("belum ketemu artinya? tanya di Ruang Diskusi") di bawah definisi — internal link ber-anchor text relevan dari ribuan halaman kata; (2) perkuat meta Ruang Diskusi untuk query intent "tanya terjemahan X bahasa sambas / cara bilang X dalam bahasa Sambas" + FAQPage JSON-LD dua-tanya; (3) alert banner di Ruang Diskusi: "Di sini kamu bisa bertanya soal bahasa & budaya Sambas" + CTA ke thread/app. Semua copy lewat i18n dua locale, semua perubahan util SEO diuji node:test.

---

## Task 1 — Branch (1 menit)

```bash
cd /Users/ibnulmutaki/Development/github/sambasku/web
git fetch origin
git checkout -b feat/seo-lemma-diskusi origin/staging
```

(Awalnya branch `staging` ada dirty files milik user — checkout -b membawa perubahan itu ikut; jangan pernah `git add` file berikut: `.env.production.example`, `README.md`, `app/application/i18n/locales.ts`, `app/infrastructure/analytics/analytics.ts`, `app/infrastructure/config/env.ts`.)

## Task 2 — i18n keys (5 menit)

File `app/application/i18n/locales/id.json` — tambahkan (dekat blok `word_*` ~line 104-115):

```json
  "word_seoKeywords": "{{lemma}} bahasa sambas, arti {{lemma}}, terjemahan {{lemma}}, kamus sambas, {{lemma}} melayu sambas",
  "word_askDiscussionCtaTitle": "Belum ketemu artinya?",
  "word_askDiscussionCtaBody": "Tanya terjemahan {{lemma}} bahasa Sambas langsung ke warga di Ruang Diskusi.",
  "word_askDiscussionCtaButton": "Tanya di Ruang Diskusi",
```

Blok `seo_*` / `diskusi_*` (~line 200-an):

```json
  "seo_diskusiTitle": "Tanya Terjemahan Bahasa Sambas - Ruang Diskusi SambasKu",
  "seo_diskusiDescription": "Mau tanya terjemahan kata bahasa Sambas atau sebaliknya? Di Ruang Diskusi kamu bisa bertanya soal bahasa dan budaya Sambas ke warga, gratis.",
  "seo_diskusiKeywords": "tanya terjemahan bahasa sambas, bahasa sambas, melayu sambas, budaya sambas, kamus sambas",
  "diskusi_alertTitle": "Di sini kamu bisa tanya apa aja",
  "diskusi_alertBody": "Ruang Diskusi tempat bertanya soal bahasa dan budaya Sambas - arti kata, terjemahan, sampai kebiasaan sehari-hari. Warga SambasKu siap bantu jawab.",
```

(Perhatikan "apa aja" = satu partikel; kalimat berikut tanpa partikel.)

File `app/application/i18n/locales/id-SBS.json` — pasangan yang sama, disesuaikan ejaan SBS ("tejemahan", "base Sambas", "basa") mengikuti gaya file itu (lihat `word_seoTitleTemplate` SBS sebagai acuan).

Verifikasi:

```bash
node -e "const a=require('./app/application/i18n/locales/id.json'),b=require('./app/application/i18n/locales/id-SBS.json');const k=['word_seoKeywords','word_askDiscussionCtaTitle','word_askDiscussionCtaBody','word_askDiscussionCtaButton','seo_diskusiTitle','seo_diskusiDescription','seo_diskusiKeywords','diskusi_alertTitle','diskusi_alertBody'];console.log(k.map(x=>[x,!!a[x],!!b[x]].join(':')).join('\n'))"
```

Expected: semua `:true:true`. Commit:

```bash
git add app/application/i18n/locales/id.json app/application/i18n/locales/id-SBS.json
git commit -m "feat(i18n): copy SEO lemma + ruang diskusi (id, id-SBS)"
```

## Task 3 — buildMetaTags dukung keywords (RED→GREEN, 10 menit)

File `app/application/utils/seo.ts`:

3a. Interface `SeoMetaProps` (di atas line 93) — tambah field:

```ts
  /** Meta keywords - nilai SEO kecil, tapi gratis untuk exact-match query. */
  keywords?: string;
```

3b. Dalam return array (setelah `{ name: 'description', ... }`):

```ts
    ...(keywords ? [{ name: 'keywords', content: keywords }] : []),
```

File test `app/application/utils/seo.test.ts` — tambah (import `buildMetaTags` dari `./seo.ts`; cek dulu apakah file test sudah meng-import sesuatu dari `./seo.ts`, kalau belum tambahkan import):

```ts
describe('buildMetaTags keywords', () => {
  it('memunculkan meta keywords saat diberikan', () => {
    const tags = buildMetaTags({
      title: 'sabar bahasa Sambas',
      description: 'tes',
      keywords: 'sabar bahasa sambas, arti sabar',
      path: '/words/sabar',
    });
    const kw = tags.find((t) => 'name' in t && t.name === 'keywords');
    assert.ok(kw && 'content' in kw && kw.content === 'sabar bahasa sambas, arti sabar');
  });

  it('tanpa keywords tidak memunculkan tag keywords', () => {
    const tags = buildMetaTags({ title: 'x', description: 'y', path: '/' });
    assert.ok(!tags.some((t) => 'name' in t && t.name === 'keywords'));
  });
});
```

Catatan: `buildMetaTags` membaca `env` — cek cara test lain meng-handle (mock/persetiapan `env`). Kalau `env.appUrl` diperlukan, set `process.env.VITE_APP_URL`/setara sebelum import sesuai pola `app/infrastructure/config/env.ts`. RED dulu (keywords belum ada → test 1 gagal), lalu implement, GREEN:

```bash
npm test 2>&1 | grep -E 'pass|fail' | tail -3
```

Commit:

```bash
git add app/application/utils/seo.ts app/application/utils/seo.test.ts
git commit -m "feat(seo): opsi keywords di buildMetaTags"
```

## Task 4 — Halaman kata: keywords + CTA Ruang Diskusi (10 menit)

File `app/routes/words.$lemma.tsx`:

4a. `meta()` (~line 69-86): ambil `keywords` dari i18n dan teruskan:

```ts
  const { title, description } = buildWordSeoCopy(word, locale);
  // ... existing primaryImage code
  return buildMetaTags({
    title,
    description,
    keywords: tWord('word_seoKeywords', { lemma: word.lemma }),
    path: localePath(locale, `/words/${encodeURIComponent(word.lemma)}`),
    // ... sisanya tidak berubah
```

(`tWord` sudah ada di scope meta function.)

4b. CTA inline: di JSX, setelah blok meanings/definitions UTAMA (cari `<Blockquote` atau section definisi pertama ~line 230-an; letakkan SETELAH seluruh definisi selesai, sebelum section terakhir), tambah Paper kecil:

```tsx
        {/* Internal link ke Ruang Diskusi - tangkap intent "tanya terjemahan"
            yang tidak terjawab definisi (SEO + konversi diskusi). */}
        <Paper withBorder radius="md" p="md">
          <Stack gap={4}>
            <Text size="sm" fw={600}>
              {t('word_askDiscussionCtaTitle')}
            </Text>
            <Text size="sm" c="dimmed">
              {t('word_askDiscussionCtaBody', { lemma: word.lemma })}
            </Text>
            <Anchor
              component={Link}
              to={lp('/ruang-diskusi')}
              size="sm"
              fw={600}
            >
              {t('word_askDiscussionCtaButton')} →
            </Anchor>
          </Stack>
        </Paper>
```

(Import `Paper`, `Anchor` sudah ada di import @mantine/core route ini — cek; `lp` = `useLocalePath()` sudah dipakai route ini; `t` sudah ada.)

Verifikasi render lokal:

```bash
npm run dev -- --port 5199 &
sleep 5
curl -s http://localhost:5199/words/emas | grep -o 'name="keywords"[^>]*' | head -1
curl -s http://localhost:5199/words/emas | grep -c 'ruang-diskusi'
kill %1
```

Expected: keywords meta muncul; `ruang-diskusi` link muncul (angka ≥ 1).

Commit:

```bash
git add app/routes/words.\$lemma.tsx
git commit -m "feat(seo): keywords lemma + CTA tanya di Ruang Diskusi dari halaman kata"
```

## Task 5 — Meta Ruang Diskusi + FAQPage JSON-LD (10 menit)

File `app/routes/ruang-diskusi.tsx`:

5a. Ganti `meta()` (line 41-49):

```tsx
export function meta({ params }: Route.MetaArgs) {
  const locale = isAppLocale(params.locale) ? params.locale : DEFAULT_LOCALE;
  const t = getFixedT(locale);
  return buildMetaTags({
    title: t('seo_diskusiTitle'),
    description: t('seo_diskusiDescription'),
    keywords: t('seo_diskusiKeywords'),
    path: localePath(locale, '/ruang-diskusi'),
    locale,
  });
}
```

(Cek import `getFixedT` — route ini belum meng-importnya; tambahkan `import { getFixedT } from '@/application/i18n/i18n-instance';` bila belum.)

5b. FAQPage JSON-LD untuk intent tanya: tambahkan builder di `app/application/utils/seo.ts` (dekat `buildFaqJsonLd` line 244):

```ts
/**
 * FAQPage khusus Ruang Diskusi - menangkap query intent
 * "tanya terjemahan X bahasa sambas" / "cara bilang X bahasa Sambas".
 */
export function buildDiscussionFaqJsonLd(localeInput?: string) {
  const locale = resolveLocale(localeInput);
  const t = getFixedT(locale);
  const discussUrl = `${env.appUrl}${localePath(locale, '/ruang-diskusi')}`;
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    '@id': `${discussUrl}#faq`,
    mainEntity: [
      {
        '@type': 'Question',
        name: t('diskusi_faqQ1'),
        acceptedAnswer: { '@type': 'Answer', text: t('diskusi_faqA1') },
      },
      {
        '@type': 'Question',
        name: t('diskusi_faqQ2'),
        acceptedAnswer: { '@type': 'Answer', text: t('diskusi_faqA2') },
      },
    ],
  };
}
```

i18n keys baru (dua file locale):

```json
  "diskusi_faqQ1": "Di mana saya bisa tanya terjemahan kata bahasa Sambas?",
  "diskusi_faqA1": "Di Ruang Diskusi SambasKu. Kamu posting pertanyaannya, warga yang paham bahasa Sambas akan bantu jawab.",
  "diskusi_faqQ2": "Apa yang bisa ditanyakan di Ruang Diskusi SambasKu?",
  "diskusi_faqA2": "Semua soal bahasa dan budaya Sambas: arti kata, terjemahan, ucapan, sampai kebiasaan sehari-hari.",
```

(id-SBS: adaptasi ejaan.)

Render di route (pola sama seperti words.$lemma.tsx line ~176):

```tsx
      {env.isProd && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify(jsonLd).replace(/</g, '\\u003c'),
          }}
        />
      )}
```

(`jsonLd = buildDiscussionFaqJsonLd(locale)` di body; import `env` bila belum.)

Verifikasi:

```bash
npm run typecheck && npm test 2>&1 | grep -E 'pass|fail' | tail -2
```

Commit:

```bash
git add app/application/utils/seo.ts app/routes/ruang-diskusi.tsx app/application/i18n/locales/id.json app/application/i18n/locales/id-SBS.json
git commit -m "feat(seo): meta + FAQPage JSON-LD Ruang Diskusi untuk intent tanya terjemahan"
```

## Task 6 — Alert banner Ruang Diskusi (5 menit)

File `app/routes/ruang-diskusi.tsx` — di JSX utama, tepat SETELAH Stack header (setelah `</Stack>` yang menutup judul+deskripsi, sebelum Card "Ingin ikut diskusi?" line ~155):

```tsx
        {/* Alert edukatif: pengunjung dari pencarian tahu fungsi halaman ini. */}
        <Alert icon={<InfoCircle size={18} />} title={t('diskusi_alertTitle')} radius="md">
          {t('diskusi_alertBody')}
        </Alert>
```

Import tambahan: `Alert` ke daftar @mantine/core; `InfoCircle` ke lucide-react; pastikan route mengambil `const { t } = useTranslation();` atau `getFixedT` — route ini sudah pakai pola i18n (cek header; kalau belum ada `t` di scope, gunakan `getFixedT(locale)` via `useLocale()` seperti route lain).

Verifikasi visual + dev server seperti Task 4 (`/ruang-diskusi` harus menampilkan alert).

Commit:

```bash
git add app/routes/ruang-diskusi.tsx
git commit -m "feat(diskusi): alert kamu bisa tanya bahasa & budaya Sambas"
```

## Task 7 — Gate penuh + push (5 menit)

```bash
npm run typecheck   # exit 0
npm run lint        # exit 0
npm test 2>&1 | tail -3   # 0 fail
git add -A app/application/utils/seo.ts app/application/utils/seo.test.ts app/routes/words.\$lemma.tsx app/routes/ruang-diskusi.tsx app/application/i18n/locales/id.json app/application/i18n/locales/id-SBS.json
git status   # PASTIKAN tidak ada file user (env.ts, analytics.ts, locales.ts, README, .env.production.example) yang ter-staged
git push -u origin feat/seo-lemma-diskusi
```

PR → `staging`, body: query target, daftar perubahan (keywords, CTA, meta diskusi, FAQPage, alert), catatan file user TIDAK ikut. `Closes` tidak ada issue GitHub (request verbal) — sebut "SEO improvisasi web" di title PR.

---

## Test / validasi (ringkas)

- `npm test`: keywords meta 2 test baru pass, total 0 fail.
- `npm run typecheck`, `npm run lint`: bersih.
- Dev server: `/words/emas` menampilkan keywords meta + link ruang-diskusi; `/ruang-diskusi` menampilkan alert + title meta baru; view-source JSON-LD FAQPage (hanya prod; di dev cek via komponen/builder).
- Schema validator (opsional, manual): paste JSON-LD ke https://search.google.com/test/rich-results setelah deploy.

## Risiko, tradeoff, pertanyaan terbuka

1. **Meta keywords = sinyal lemah** (Google mengabaikan sejak 2009); tidak merugikan, exact-match Bing/kekadang Yandex masih baca. Nilai utama tetap di title/H1/lead/JSON-LD yang SUDAH ada — PR ini menambah internal linking ribuan halaman kata → ruang-diskusi, itu yang paling bernilai.
2. **FAQPage JSON-LD tanpa markup FAQ terlihat di halaman** = risiko dicek manual Google (kebijakan 2023+: FAQ rich result hanya untuk situs otoritatif pemerintah/kesehatan). Tetap valid structured data; kalau mau aman total, tampilkan teks FAQ yang sama secara visual kecil di bawah feed (opsi B, +1 task). Default plan: JSON-LD saja, teks FAQ juga dirender singkat (sudah tercakup lewat alert body yang menyentuh hal serupa).
3. **CTA di halaman kata**: anchor text "Tanya di Ruang Diskusi" + body berisi "Tanya terjemahan {{lemma}} bahasa Sambas" — kalau Google menganggap boilerplate massal, bisa diabaikan; volume internal link tetap membantu discovery ruang-diskusi. Boleh diverifikasi dampaknya 2-4 minggu di Search Console.
4. **id-SBS.json**: ejaan adaptasi harus konsisten dengan gaya file itu — implementer WAJIB baca 3-4 key sekitar sebelum menulis.
5. **Bukan scope (YAGNI)**: programmatic landing page per-huruf "tanya terjemahan" terpisah, halaman A-Z terjemahan Indonesia→Sambas, sitemap baru. Kalau SERP "tanya terjemahan" nanti tetap tidak menangkap, opsi lanjutan = dedicated landing `/tanya-terjemahan` — keputusan berdasarkan data Search Console, bukan sekarang.
