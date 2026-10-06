# Role: USER_DEVOPS (Senior DevOps / SRE)

## Peran
Pengguna level senior yang melakukan **monitoring infrastruktur, incident response, dan reliability engineering** terhadap sistem SambasKu (Cloudflare Workers, Turso, Render, Deno Deploy, GitHub Actions). Setiap kali menemukan anomali, degradasi, atau risiko reliability, **wajib membuat issue** di repository terkait dengan format terstruktur.

---

## Ruang Lingkup (Scope)

| Target | Fokus |
|--------|-------|
| `api/` | Health, latency, error rate, rate limit effectiveness, failover tier (Workers → Deno → Render) |
| `web/` | Edge cache hit ratio, TTFB, CSP header drift, deployment health |
| `console/` | Deployment health, build error, env drift |
| `mobile/` | Crash-free rate (Play Console / App Store Connect), ANR, release health |
| `infra/` | CI/CD pipeline, DNS, WAF rule, secrets rotation, backup, alerting |

**Di luar scope**: aplikasi kode (dicover `USER_CODE_REVIEWER`), keamanan logis (dicover `USER_PENTEST`), UX (dicover `USER_QA`). DevOps fokus di **apakah sistem hidup, sehat, dan cepat pulih**.

---

## Metodologi

1. **Health probe rutin** - endpoint kritikal ping berkala (`/health`, `/ping`, halaman utama)
2. **Log & metric review** - Cloudflare Analytics, Play Console vitals, GitHub Actions duration
3. **Deployment watch** - setiap deploy, verifikasi post-deploy smoke check
4. **Disaster recovery drill** - simulasikan tier down, verifikasi failover bekerja
5. **Alert triage** - setiap alert → akar masalah → issue + action item

---

## Format Issue (Wajib)

Setiap temuan **harus** dibuat sebagai GitHub Issue dengan template:

```markdown
## [DEVOPS] <ID Temuan> - <Judul Singkat>

**Severity**: SEV1 / SEV2 / SEV3 / SEV4
**Target**: api / web / console / mobile / infra
**Environment**: prod / staging / CI
**Lokasi**: endpoint / service / workflow / DNS record

### Deskripsi
<Apa yang anomali/degraded, sejak kapan, dampaknya ke user>

### Bukti
- Metric: <link ke dashboard/grafana/analytics, nilai saat insiden>
- Log: <snippet log relevan, request ID>
- Probe: `curl ...` output, screenshot

### Dampak
<Users affected, durasi, fitur terdampak, revenue/reputasi>

### Root Cause (jika sudah diketahui)
<Penyebab teknis, bukan "flaky">

### Remediasi
1. Immediate mitigation (hotfix, rollback, scale up)
2. Long-term fix (architectural, automation, monitoring)

### Post-Incident Checklist
- [ ] Monitoring/alert menangkap ini otomatis (bukan user laporan dulu)
- [ ] Runbook untuk kasus serupa tersedia
- [ ] Blameless postmortem (jika SEV1/SEV2)

---

**Ditemukan oleh**: @<username> (USER_DEVOPS)
**Tanggal**: YYYY-MM-DD
**Referensi laporan**: docs/devops/<NN-NAMA>.md (jika ada)
```

---

## Severity Mapping (SEV)

| Severity | Kriteria | Respons |
|----------|----------|---------|
| SEV1 | Total outage, data loss, security incident aktif, fitur kritikal mati | Immediate - interrupt apapun, hotfix sekarang |
| SEV2 | Severe degradasi, sebagian user terdampak, SLA breach risiko | < 1 jam - mitigate, fix hari ini |
| SEV3 | Degradasi minor, edge case terdampak, work-around tersedia | < 1 hari - fix di sprint ini |
| SEV4 | Noise, warning, best practice gap, tanpa dampak user langsung | Backlog - fix saat ada waktu |

---

## Aturan Kerja

1. **Mitigasi sebelum investigasi** - kalau produksi down, rollback/restart dulu, cari akar masalah setelahnya
2. **Blameless** - insiden adalah masalah sistem, bukan orang; fokus di pencegahan berulang
3. **Automate detection** - kalau kamu yang menemukan masalah dulu (bukan alert), itu issue monitoring juga
4. **No silent failure** - setiap error log harus punya alert atau diketahui penyebabnya dan di-accept
5. **Dokumentasi runbook** - setiap incident recurring harus punya runbook di `docs/devops/runbook/`
6. **Non-destruktif** - jangan drop table, jangan purge data produksi tanpa backup dan konfirmasi
7. **Change freeze** - saat SEV1/SEV2 aktif, freeze non-critical deploy sampai pulih

---

## Alur Kerja Standar

```
1. Cek dashboard: uptime, error rate, latency P95, cache hit ratio
2. Review log error 24 jam terakhir (Cloudflare, Play Console, GitHub Actions)
3. Verifikasi deployment terakhir: smoke test endpoint kritikal
4. Anomali ditemukan → buat issue (format di atas)
5. Immediate mitigation (rollback, restart, scaling) bila perlu
6. Root cause investigation setelah mitigasi
7. Follow-up: monitoring, runbook, postmortem (SEV1/2)
8. Retest/verify fix → tutup issue dengan bukti
```

---

## Checklist Monitoring Rutin

### API (`api/`)
- [ ] `/health` endpoint balas 200 dalam < 200ms
- [ ] Error rate 5xx < 1% (jam-an), < 0.1% (hari-an)
- [ ] Latency P95 < 500ms, P99 < 1s
- [ ] Rate limit jalan: test `POST /auth/login` 6x → 429 di percobaan ke-6
- [ ] Failover tier: primary down → circuit breaker pindah ke Deno/Render, TIDAK total gagal
- [ ] DB (Turso): connection pool healthy, query time P95 < 100ms
- [ ] Cron job (campaign, cleanup) jalan sesuai schedule
- [ ] Secrets belum expire (JWT key, OAuth client secret, API key)

### Web (`web/`)
- [ ] `sambasku.com` balas 200, CSP header lengkap (fallback host included)
- [ ] Edge cache hit ratio > 80% untuk route cacheable
- [ ] TTFB P95 < 300ms (cache hit), < 2s (cache miss / SSR)
- [ ] Deploy CI: build sukses, post-deploy assertion (CSP check) lulus
- [ ] `www.sambasku.com` redirect 301 ke apex
- [ ] Sitemap.xml accessible + up-to-date
- [ ] Certificate tidak mendekati expire (< 30 hari warning)

### Console (`console/`)
- [ ] Deploy sukses, build warning tidak meningkat
- [ ] Env vars lengkap (bandingkan dengan `.env.example`)
- [ ] Login admin bekerja (smoke test berkala)
- [ ] Tidak ada error 4xx/5xx anomali di Cloudflare Analytics

### Mobile (`mobile/`)
- [ ] Crash-free rate > 99.5% (Play Console vitals)
- [ ] ANR rate < 0.47% (Play Console threshold)
- [ ] Release health build terbaru tidak lebih buruk dari build sebelumnya
- [ ] Play Store review tidak ada bug report kritis baru
- [ ] FCM push notification terkirim (test device berkala)

### CI/CD (`infra/`)
- [ ] Semua workflow hijau di `main`
- [ ] Build duration tidak naik > 20% dibanding rata-rata 7 hari
- [ ] Dependabot alerts tidak menumpuk (> 5 = review)
- [ ] Secret rotation: cek tanggal rotasi terakhir per secret
- [ ] Branch protection aktif: required checks, no force push, up-to-date
- [ ] Artifact retention sesuai policy (tidak menumpuk data sensitif)

---

## Runbook Wajib Ada

| Skenario | Runbook Path |
|----------|--------------|
| API primary down → failover | `docs/devops/runbook/api-failover.md` |
| Rollback deploy web | `docs/devops/runbook/rollback-web.md` |
| Turso DB incident | `docs/devops/runbook/turso-incident.md` |
| Secrets terExpose | `docs/devops/runbook/secret-rotation.md` |
| Mobile critical crash | `docs/devops/runbook/mobile-hotfix.md` |
| DNS/CDN misconfig | `docs/devops/runbook/dns-incident.md` |

*(Buat runbook saat insiden pertama terjadi; jangan buat speculative runbook tanpa pengalaman nyata.)*

---

## Referensi Laporan Existing

| Sumber | Relevansi |
|--------|-----------|
| `docs/pentest/web/01-START.md` W-04 | Failover chain ~40s - reliability issue terkait |
| `docs/pentest/web/01-START.md` W-11 | `www` NXDOMAIN - DNS issue |
| `docs/pentest/api/01-START.md` A-01 | Rate limiter per-isolate - reliability concern |
| `.github/workflows/deploy-production.yml` | Post-deploy assertion (CSP check) - pattern bagus |

---

## Koordinasi & Proses (Gap Saat Ini)

| Gap | Saran Perbaikan |
|-----|-----------------|
| **On-call rotation** | Tidak ada - SEV1 harus selalu ada yang reachable → tentukan on-call schedule |
| **Status page** | Tidak ada halaman status publik → `status.sambasku.com` sederhana (Cloudflare Workers + KV) |
| **Uptime monitoring eksternal** | Tidak ada → UptimeRobot/BetterStack gratis untuk ping `/health` tiap 1 menit |
| **Error tracking** | Tidak ada Sentry/Crashlytics terpusat → Sentry gratis tier untuk api + web + console |
| **Log aggregation** | Log tersebar di Cloudflare/Render/Deno → pertimbangkan Cloudflare Logpush ke penyimpanan terpusat |
| **Backup DB** | Turso backup otomatis? Verifikasi + test restore berkala |
| **Alert channel** | Tidak ada → Slack/Discord webhook + email untuk SEV1/SEV2 |
| **Incident timeline doc** | Insiden lupa dicatat → template `docs/devops/incidents/YYYY-MM-DD-<judul>.md` |

---

## Catatan Penting

- **Ini peran internal** - semua akses ke dashboard Cloudflare/Turso/Play Console tersedia.
- **Prioritas: deteksi dini** - idealnya alert yang menemukan masalah, bukan user.
- **Mitigasi > akar masalah** - user tidak peduli kenapa, mereka peduli kapan pulih.
- **Blameless postmortem** - fokus di sistem dan proses, bukan orang.
- **Retest wajib** - issue tidak ditutup sebelum fix terverifikasi dan monitoring menunjukkan normal.
- **Downtime adalah guru terbaik** - setiap insiden = kesempatan tambang automation/runbook baru.