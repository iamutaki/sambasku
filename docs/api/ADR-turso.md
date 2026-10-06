# ADR: Turso (libSQL) menggantikan Neon PostgreSQL

**Status:** accepted (2026-09-22)  
**Konteks:** API Cloudflare Workers + Node dual-runtime; sebelumnya Neon + driver WebSocket per-request.

## Keputusan

Database production/staging = **Turso Cloud** (libSQL). Lokal/CI = **file SQLite** (`file:./local.db` / `file:./test.db`). ORM tetap Drizzle (`dialect: 'turso'`, `sqliteTable`).

## Alasan

- Motivasi utama: **free tier** dengan headroom storage lebih longgar daripada Neon Free (~0.5 GB).
- Menyederhanakan Workers: HTTP Turso singleton, tanpa Neon WS / Hyperdrive / pool per-request.
- DX lokal tanpa Docker Postgres.

## Konsekuensi

- Keluar dari dialek PostgreSQL: rewrite `ILIKE`, `DISTINCT ON`, `md5()`, `FOR UPDATE`, kode error `2350x`, migrasi PG diarsipkan.
- Single-writer SQLite - cocok untuk kamus baca-berat, hati-hati jika write naik.
- D1 Cloudflare **tetap ditolak** (vendor lock Workers + fitur/SQL beda); Turso portable ke libSQL self-host.
- Rollback ke Postgres = revert kode + restore lineage migrasi `migrations-pg-archive/` (data Turso tidak otomatis balik).

## Env

| Env | `DATABASE_URL` | Token |
|-----|----------------|-------|
| lokal | `file:./local.db` | kosong |
| test/CI | `file:./test.db` | kosong |
| staging/prod | `libsql://…` | `DATABASE_AUTH_TOKEN` |
