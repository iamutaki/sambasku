# Tayang, belum diverifikasi

Kontrak produk untuk kontribusi warga. Dua sumbu terpisah:

- `status` mengatur apakah isi terlihat publik (`draft`, `pending_review`, `published`, `rejected`).
- `is_verified` mengatur kepercayaan. Chip **Terverifikasi** hanya saat `true`.
- `contributions.status = pending` berarti masih ada pekerjaan review, termasuk isi yang sudah tayang.

## Siapa langsung tayang

| Pengirim | Hasil |
| --- | --- |
| Tamu (tanpa Bearer, akun sistem `anonim`) | `pending_review`, belum tayang. Setelah disetujui: `published` dan `is_verified = true`. |
| Pengguna login, bukan verifikator | `published`, `is_verified = false`, tetap di antrean. |
| `admin`, `editor`, `root`, `reviewer` | `published` dan `is_verified = true`, tidak masuk antrean. |
| Draf | Tidak tayang, tidak masuk antrean. |

Berlaku untuk kata baru, sinonim inline, gambar, pelafalan, dan contoh.

## Label

- Chip: **Menunggu pengecekan**
- Catatan detail: **Kata ini belum diperiksa tim Sambasku. Artinya atau terjemahannya bisa saja kurang tepat.**
- Baris kartu bagikan: **Arti belum diperiksa tim Sambasku.**
- Tamu: **Dikirim sebagai tamu. Kata belum tayang. Tim akan memeriksanya dulu.**
- Kata hari ini hanya `published` dan `is_verified = true`.

## Usul ubah

- Kata yang sudah **Terverifikasi**: usulan tidak menimpa isi tayang sampai disetujui.
- Kata yang masih **Menunggu pengecekan**: perubahan langsung tayang. Snapshot isi sebelumnya disimpan. Setujui hanya memasang **Terverifikasi**. Tolak mengembalikan snapshot.
- Satu usulan yang belum selesai per kata. Usulan kedua: **Kata ini sudah punya usulan yang belum selesai. Tunggu pemeriksaan tim sebelum mengirim usulan lain.**
- Selama usulan yang sudah menimpa masih pending, kata induk tidak bisa ditandai terverifikasi.

Media yang ditambahkan ke kata yang sudah terverifikasi tetap tayang dan tidak menurunkan badge kata. Kartu bagikan mengikuti `is_verified` kata, bukan media anak.

## Hak menulis

`users.can_contribute` (bawaan `true`) terpisah dari `is_active`. `false`
menolak **UGC tulis**: kata baru, media, usul ubah, komentar lemma, dan
diskusi (buat topik / balasan / audio) dengan **Akun ini tidak bisa mengirim
usulan saat ini.** Login dan baca tetap boleh. Akun `anonim` tidak bisa
dimatikan.

Mute sementara (`contribute_muted_until`) dari policy abuse otomatis
menolak tulis yang sama dengan **Akun ini sementara tidak bisa mengirim
konten. Coba lagi nanti.** (`CONTRIBUTION_MUTED`). Admin "Izinkan lagi"
juga membersihkan mute.

Tombol antrean: **Hentikan kontribusi**. Tab pengguna **Tidak bisa
kontribusi**: **Izinkan lagi**.

## Keputusan review

- Setujui isi yang sudah tayang: pasang **Terverifikasi**. Salinan kotak masuk: **Kata sudah dicek**.
- Tolak: status `rejected`, kata ditarik. Salinan: **Kata ditarik**.
- Koreksi diam pada isi yang sudah tayang: tetap tayang, `is_verified = false`, antrean tetap pending.
