# Remark Reviewer (Huawei AppGallery)

Teks untuk field **Remarks** saat submit/update app SambasKu di
AppGallery Connect. Bahasa Inggris agar reviewer Huawei internasional paham;
salin blok di bawah apa adanya.

## Remarks (maks 300 karakter, 281)

```text
Test account:
reviewer@sambasku.com
pass1234@@
Sign-in is optional; the reviewer can search words and read meanings without an account. The account unlocks bookmark, contribution, discussion, and profile features. The app interface is in Indonesian. No purchases or ads in the app.
```

## Catatan

- Akun `reviewer@sambasku.com` adalah akun seed (`reviewer`, role `reviewer`)
  dari `api/src/scripts/seed-accounts.ts`. Pastikan environment yang diarahkan
  aplikasi (staging/production) punya akun ini dan password sesuai di atas
  sebelum submit.
- App tidak ada fitur beli; paragraf pembuka salin dari template Google Play,
  dipertahankan agar konsisten dengan submit Play Console.

ponytail: hanya satu versi teks (EN). Kalau reviewer Huawei minta bahasa lain,
tambahkan versi terjemahannya di sini.
