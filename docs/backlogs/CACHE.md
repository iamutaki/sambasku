# CACHE - Response cache klien (mobile + web)

Dokumen backlog. **Belum diimplementasi.** Kontrak draft untuk
mengurangi hit ke API free-tier dan memberi degradasi baca saat
jaringan jelek. Lihat juga [`NEXT.md`](NEXT.md) (Medium: Cache offline
tipis).

## Status

| Item | Status |
| --- | --- |
| Kontrak mobile | Draft - [`CACHE-MOBILE.md`](CACHE-MOBILE.md) |
| Kontrak web | Draft - [`CACHE-WEB.md`](CACHE-WEB.md) |
| Implementasi mobile (disk L1) | Belum |
| Web Layer A fix (locale HTML SWR) | Belum (kode partial di `worker.ts`) |
| Web Layer B (JSON API edge cache) | Belum |
| Content epoch API (fase 2) | Belum / YAGNI sampai V1 terpakai |

## Tujuan

1. Kurangi beban API (rate limit 100/menit, Workers subrequest, cold
   host Render/Deno).
2. Cold start mobile tetap bisa menyajikan detail/reference yang pernah
   dibuka.
3. Satu kebijakan invalidation (L1 fresh / L2 SWR / L3 hard expiry /
   L4 event) dengan matriks TTL yang sama di mobile dan web.

## V1 (tipis)

1. Revisi & kunci angka TTL di kedua kontrak (PO + engineer).
2. Web P0: perbaiki `isCacheable` ber-locale + cache key tanpa query
   (`CACHE-WEB.md` Layer A).
3. Mobile: `ResponseCacheStore` + repository dictionary/reference
   (`CACHE-MOBILE.md`).
4. Web Layer B: wrapper GET publik di `apiClient` untuk reference,
   today, lemma detail.

Batas produk selaras NEXT: **bukan** full offline dictionary pack.
Fokus detail kata + reference + feed singkat; bookmark tetap jalur
akun (jangan campur dengan cache publik).

## V2 (nanti)

- `GET /cache-epoch` atau header `X-Content-Epoch`
- Browser Layer C (recently viewed) bila A+B sudah terukur hematnya
- ETag / 304 dari API jika traffic membenarkan

## Anti-pola

- Jangan cache auth token / PII / inbox / vote pribadi ke disk.
- Jangan hit API dulu baru cek cache (arahnya cache-aside).
- Jangan anggap failover host sebagai pengganti cache payload.
- Jangan taruh kontrak ini di `docs/mobile/` atau `docs/web/` sampai
  diimplementasi dan dipromosikan dari backlog.

## Urutan kerja saat dieksekusi

1. Kunci revisi TTL di `CACHE-MOBILE.md` + `CACHE-WEB.md`.
2. Web Layer A (locale + key hygiene) - win tercepat di produksi.
3. Mobile reference + word detail disk cache.
4. Web Layer B JSON cache.
5. Setelah live: pindahkan kontrak ke `docs/mobile/` + `docs/web/`
   (atau section di base-stack) dan isi checklist di
   `backlogs/done/`.
