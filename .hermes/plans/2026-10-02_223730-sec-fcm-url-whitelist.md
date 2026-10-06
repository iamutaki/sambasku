# Plan: Whitelist host untuk notifikasi FCM `action_kind=url` (#71)

## Goal

Tap notifikasi dengan `action_kind=url` hanya boleh membuka URL eksternal
di host yang di-whitelist; selain itu jatuh ke fallback in-app (inbox),
bukan error sheet.

## Current context / asumsi

- File inti: `mobile/lib/core/services/notification_navigation.dart`.
  - `navigateFromNotificationPayload` (line 30-33, 83-88): `actionKind == 'url'`
    → `_openExternalUrl` → `openHttpsUrl` → `launchUrl` external. Dua call site.
  - `openHttpsUrl` (line 198): validasi hanya scheme https + host non-empty +
    path tanpa `..`. Tidak ada whitelist host.
  - `playStoreMarketUri` (line 185): precedent benar - scoping ketat ke
    `play.google.com/store/apps/details?id=`.
- Sumber payload `url` di backend: campaign admin
  (`api/src/modules/notification-campaign/`). `deep_link_value` untuk
  `deep_link_kind=url` divalidasi hanya `z.string().trim().max(500)`
  (`campaign.validator.ts` line 55, 64, 109) - string bebas. Ini vektor yang
  dimaksud issue: admin/otomasi bisa menaruh URL mana pun.
- Host sah yang pernah dipakai app (dari `env.g.dart`, `auth_router.dart`):
  `sambasku.com`, `sambasku-web-staging.iamutaki.com`, `play.google.com`.
- Test existing: `mobile/test/core/services/play_store_uri_test.dart`
  (pattern: import package, test murni, tanpa pump widget).
- Branch mobile aktif: `fix/tab-freeze` (WIP dictionary user - commit hanya
  file notifikasi, jangan `git add -A`).
- Submodule API branch `fix/upload-token-auth` dari issue #67 sudah selesai;
  kerjaan API baru boleh cabang dari sana atau `staging` - ikuti status
  `git status` saat eksekusi.

## Pendekatan

Defense-in-depth dua lapis, minimal diff:

1. **Mobile (utama)**: fungsi `isAllowedNotificationHost(Uri)` di
   `notification_navigation.dart` - whitelist exact-host (bukan suffix match,
   supaya `evilsambasku.com` tidak lolos). `openHttpsUrl` TIDAK diubah
   (dipakai juga untuk syarat-ketentuan dll. yang host-nya fixed); gate
   ditaruh sebelum `_openExternalUrl` di kedua call site `url`. Host di luar
   whitelist → `_go(router, NotificationRouter.list.path)` + `debugPrint`
   (silent-ignore, no error sheet - user tidak bisa berbuat apa-apa soal
   payload rusak).
2. **API (lapis kedua)**: superRefine di `campaign.validator.ts` - saat
   `deep_link_kind == 'url'`, `deep_link_value` wajib https + host di
   whitelist yang sama. Tolak saat create/update template & create campaign,
   sebelum FCM terkirim.

Whitelist disimpan satu tempat per repo (konstata di file yang sama dengan
pemakainya), bukan config env - nilainya produk-stable, YAGNI env var.

## Task 1 - Mobile: test merah whitelist host

File: `mobile/test/core/services/notification_notification_url_test.dart`
(baru; nama bebas asal jelas, jangan bentrok `play_store_uri_test.dart`).

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sambasku_mobile/core/services/notification_navigation.dart';

void main() {
  test('host whitelist sambasku.com lolos', () {
    expect(
      isAllowedNotificationHost(Uri.parse('https://sambasku.com/id/donasi')),
      isTrue,
    );
  });

  test('host whitelist staging lolos', () {
    expect(
      isAllowedNotificationHost(
        Uri.parse('https://sambasku-web-staging.iamutaki.com/x'),
      ),
      isTrue,
    );
  });

  test('host whitelist play.google.com lolos', () {
    expect(
      isAllowedNotificationHost(
        Uri.parse('https://play.google.com/store/apps/details?id=x'),
      ),
      isTrue,
    );
  });

  test('domain mirip ditolak (evil suffix)', () {
    expect(
      isAllowedNotificationHost(Uri.parse('https://sambasku.com.evil.io')),
      isFalse,
    );
    expect(
      isAllowedNotificationHost(Uri.parse('https://evilsambasku.com')),
      isFalse,
    );
  });

  test('host lain ditolak', () {
    expect(
      isAllowedNotificationHost(Uri.parse('https://attacker.example/phish')),
      isFalse,
    );
  });

  test('subdomain acak dari host whitelist ditolak', () {
    // Exact-host match: hanya host yang terdaftar, bukan *.sambasku.com
    expect(
      isAllowedNotificationHost(Uri.parse('https://api.sambasku.com/x')),
      isFalse,
    );
  });
}
```

Verifikasi merah:

```
cd mobile && flutter test test/core/services/notification_notification_url_test.dart
```

Expected: compile error `isAllowedNotificationHost` undefined (itulah merahnya).

Commit: `test(notif): whitelist host url notification (red)`.

## Task 2 - Mobile: implementasi whitelist + gate dua call site

File: `mobile/lib/core/services/notification_notification_url.dart` (baru)
berisi whitelist + checker; atau langsung di `notification_navigation.dart`.
Pilih: **langsung di `notification_navigation.dart`** (satu file, dipakai
hanya di sana; file terpisah = abstraksi prematur).

Tambah di `notification_navigation.dart` (di atas `openHttpsUrl`):

```dart
/// Host yang boleh dibuka dari payload notifikasi. Exact match, bukan
/// suffix - `sambasku.com.evil.io` / `evilsambasku.com` harus tetap ditolak.
const Set<String> kAllowedNotificationHosts = {
  'sambasku.com',
  'sambasku-web-staging.iamutaki.com',
  'play.google.com',
};

bool isAllowedNotificationHost(Uri uri) =>
    kAllowedNotificationHosts.contains(uri.host.toLowerCase());
```

Ubah call site pertama (line 30-33) menjadi:

```dart
  if (actionKind == 'url' && actionValue != null && actionValue.isNotEmpty) {
    await _openNotificationUrl(context, actionValue);
    return;
  }
```

Call site kedua (campaign, line 83-88):

```dart
    if (deepLinkKind == 'url' &&
        deepLinkValue != null &&
        deepLinkValue.isNotEmpty) {
      await _openNotificationUrl(context, deepLinkValue);
      return;
    }
```

Helper baru (letakkan dekat `_openExternalUrl`):

```dart
/// Payload url notifikasi: hanya host whitelist. Selain itu fallback
/// inbox - jangan error sheet (payload rusak bukan salah user).
Future<void> _openNotificationUrl(BuildContext? context, String raw) async {
  final uri = Uri.tryParse(raw.trim());
  if (uri != null && isAllowedNotificationHost(uri)) {
    await _openExternalUrl(context, raw);
    return;
  }
  debugPrint('notification url rejected (host not allowed): $raw');
  _go(AppRouter.router, NotificationRouter.list.path);
}
```

Verifikasi hijau:

```
cd mobile && flutter test test/core/services/notification_notification_url_test.dart
flutter analyze --no-pub | grep notification   # → kosong (0 issue)
```

Commit: `fix(security): whitelist host url notifikasi (#71)`.

## Task 3 - API: test merah validator campaign

File: tambah group di
`api/src/modules/notification-campaign/__tests__/unit/campaign.use-case.test.ts`
ATAU file baru
`api/src/modules/notification-campaign/__tests__/unit/campaign.validator.test.ts`
(prefer file baru - fokus validator murni, tanpa mock infra).

```ts
import { describe, expect, it } from 'vitest';

import { createTemplateBodySchema } from '../../presentation/v1/validators/campaign.validator';

const base = {
  name: 'T',
  title: 'Judul',
  body: 'Isi',
};

describe('deep_link_value url whitelist', () => {
  it('menerima https://sambasku.com/...', () => {
    const r = createTemplateBodySchema.safeParse({
      ...base,
      deep_link_kind: 'url',
      deep_link_value: 'https://sambasku.com/id/donasi',
    });
    expect(r.success).toBe(true);
  });

  it('menolak host luar', () => {
    const r = createTemplateBodySchema.safeParse({
      ...base,
      deep_link_kind: 'url',
      deep_link_value: 'https://attacker.example/phish',
    });
    expect(r.success).toBe(false);
  });

  it('menolak non-https', () => {
    const r = createTemplateBodySchema.safeParse({
      ...base,
      deep_link_kind: 'url',
      deep_link_value: 'http://sambasku.com/x',
    });
    expect(r.success).toBe(false);
  });

  it('menolak host mirip (suffix trick)', () => {
    const r = createTemplateBodySchema.safeParse({
      ...base,
      deep_link_kind: 'url',
      deep_link_value: 'https://sambasku.com.evil.io/x',
    });
    expect(r.success).toBe(false);
  });

  it('menerima deep_link_kind word (nilai bebas id)', () => {
    const r = createTemplateBodySchema.safeParse({
      ...base,
      deep_link_kind: 'word',
      deep_link_value: 'abc123',
    });
    expect(r.success).toBe(true);
  });
});
```

(Catatan: jangan copy buta - periksa nama file & import path sesuai tempat
test disimpan.)

Verifikasi merah:

```
cd api && pnpm vitest run src/modules/notification-campaign/__tests__/unit/campaign.validator.test.ts
```

Expected saat merah: test "menerima https://sambasku.com" dan "menerima
deep_link_kind word" PASS (schema lama sudah terima), sedangkan 3 test tolak
FAIL (schema lama masih terima host luar) - itulah merahnya.

Commit: `test(campaign): whitelist host deep_link url (red)`.

## Task 4 - API: superRefine di campaign.validator.ts

File: `api/src/modules/notification-campaign/presentation/v1/validators/campaign.validator.ts`.

Tambah konstanta + helper (taruh di bawah `deepLinkKindSchema`):

```ts
/** Host yang boleh dipakai deep_link_kind=url. Sinkron dengan mobile:
 *  lib/core/services/notification_navigation.dart - kAllowedNotificationHosts. */
const ALLOWED_DEEP_LINK_HOSTS = new Set([
  'sambasku.com',
  'sambasku-web-staging.iamutaki.com',
  'play.google.com',
]);

function refineDeepLinkUrl<
  T extends {
    deep_link_kind?: string | null;
    deep_link_value?: string | null;
  },
>(schema: z.ZodType<T>) {
  return schema.superRefine((v, ctx) => {
    if (v.deep_link_kind !== 'url') return;
    const raw = v.deep_link_value?.trim();
    if (raw == null || raw === '') {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['deep_link_value'],
        message: 'URL deep link wajib diisi untuk kind url',
      });
      return;
    }
    let host: string;
    try {
      const u = new URL(raw);
      if (u.protocol !== 'https:') throw new Error('bukan https');
      host = u.host.toLowerCase();
    } catch {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['deep_link_value'],
        message: 'URL deep link harus HTTPS yang valid',
      });
      return;
    }
    if (!ALLOWED_DEEP_LINK_HOSTS.has(host)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['deep_link_value'],
        message:
          'Host URL deep link tidak diizinkan. Gunakan sambasku.com, ' +
          'sambasku-web-staging.iamutaki.com, atau play.google.com',
      });
    }
  });
}
```

Terapkan ke tiga schema tanpa mengubah field yang ada:

```ts
export const createTemplateBodySchema = refineDeepLinkUrl(
  z.object({
    // ...field yang sudah ada, tidak diubah...
  }),
);

export const updateTemplateBodySchema = refineDeepLinkUrl(
  z.object({
    // ...field yang sudah ada...
  }),
);

export const createCampaignBodySchema = refineDeepLinkUrl(
  z
    .object({
      // ...field yang sudah ada...
    })
    .refine((v) => v.template_id || (v.title && v.body), {
      message: 'Pilih template atau isi judul dan body',
    }),
);
```

`createCampaignBodySchema` sudah punya `.refine` sendiri; rantai
`refineDeepLinkUrl(z.object(...).refine(...))` additive, urutan aman.

Verifikasi hijau:

```
cd api && pnpm vitest run src/modules/notification-campaign/__tests__/unit/campaign.validator.test.ts
pnpm typecheck
```

Commit: `fix(security): tolak deep_link url host luar di campaign (#71)`.

## Task 5 - Docs

`docs/api/30-api-notification-campaign.md`: bagian `deep_link_kind` (line ~54):
tambah kalimat "Untuk `url`: wajib HTTPS dan host harus `sambasku.com`,
`sambasku-web-staging.iamutaki.com`, atau `play.google.com` (ditolak 400
`VALIDATION_ERROR`)." + contoh error.

`docs/api/23-api-notifications.md` line ~43: satu kalimat: mobile hanya buka
url notifikasi di host whitelist; selain itu fallback inbox.

Commit docs (submodule docs): `docs: whitelist host deep_link url (#71)`.

## Task 6 - Verifikasi akhir

```
cd api && pnpm vitest run src/modules/notification-campaign && pnpm typecheck
cd ../mobile && flutter test test/core/services/ && flutter analyze --no-pub
```

Expected: semua hijau, analyze 0 issue di file terkait. `flutter test` full
suite sudah diketahui punya 1 gagal pre-existing (`home_contribute_button_hide_test.dart`,
WIP dictionary user) - bukan blocker, jangan diperbaiki di sini.

Root superroot: jangan commit pointer submodule sebelum diperintah.

## Risks / tradeoffs / open questions

- **Exact-host vs subdomain**: exact match menolak `api.sambasku.com`. Kalau
  kelak campaign butuh link API/docs subdomain, tambah host eksplisit ke
  whitelist (satu baris). Subdomain wildcard = attack surface (`.iamutaki.com`
  punya banyak service) - jangan.
- **Mobile gate vs openHttpsUrl**: gate hanya di jalur notifikasi. `openHttpsUrl`
  tetap bebas host (dipakai syarat-ketentuan). Kalau mau total-lock, ubah
  `openHttpsUrl` - out of scope, host-nya fixed di kode.
- **Campaign lama di DB** dengan url host luar: tetap tersimpan; setelah fix,
  tap di mobile jatuh ke inbox (aman), tidak crash. Backend tidak menolak
  baca - hanya create/update baru.
- **Sinkronisasi dua whitelist** (mobile + api): didokumentasikan via komentar
  silang di kedua file. Env var bersama = over-engineering untuk 3 host.
- **Fallback inbox vs ignore total**: pilih inbox (user dapat konteks "ada
  notifikasi") sesuai perilaku fallback campaign yang sudah ada (line 89).
