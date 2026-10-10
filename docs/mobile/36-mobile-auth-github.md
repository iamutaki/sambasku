# Mobile Auth GitHub

Masuk / daftar / tautkan akun via GitHub OAuth (AppAuth). Secret
tidak pernah di APK - mobile hanya dapat authorization code.

## Alur

1. User tap ikon GitHub.
2. `flutter_appauth` buka authorize GitHub (PKCE).
3. Callback **HTTPS** App Link: `{webAppUrl}/oauth/github`
   (GitHub menolak custom scheme seperti `com.app:/...`).
4. App kirim `code` + `redirect_uri` + `code_verifier` ke
   `POST /api/v1/auth/github` (atau `/github/link`).
5. API tukar code dengan `GITHUB_CLIENT_SECRET`, verifikasi user, JWT.

## Env Flutter (`.env`)

```
GITHUB_CLIENT_ID_STAGING=
GITHUB_CLIENT_ID_PRODUCTION=
```

Sama dengan API `GITHUB_CLIENT_ID`. Kosong = tombol disembunyikan.

## Callback OAuth App (GitHub Developer Settings)

Isi **Authorization callback URL** dengan URL https valid:

| Flavor | Authorization callback URL |
| ------ | -------------------------- |
| staging | `https://sambasku-web-staging.iamutaki.com/oauth/github` |
| production | `https://sambasku.com/oauth/github` |

Scope: `read:user`, `user:email`.

Buat **OAuth App terpisah** untuk staging vs production (callback beda).

## Native

- Android: `RedirectUriReceiverActivity` + App Link path `/oauth/github`
  (`deepLinkHost` per flavor).
- iOS: Universal Link path `/oauth/github` di
  `apple-app-site-association`.
- Web: rute `oauth/github` (fallback browser).

## API

Lihat `docs/api/36-api-auth-github.md`.
