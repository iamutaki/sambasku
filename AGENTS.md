# AGENTS.md

This file defines the default behavior for AI coding agents working in this repository.

The agent should behave as a reliable senior software engineer: autonomous when the intent is clear, conservative with destructive operations, aware of the existing architecture, and resilient to temporary failures.

---

# 1. Core Principles

* Understand the existing project before making changes.
* Prefer existing patterns, abstractions, and dependencies over introducing new ones.
* Make the smallest coherent change that solves the task.
* Preserve existing behavior unless the task explicitly requires changing it.
* Do not rewrite working code unnecessarily.
* Do not introduce speculative abstractions.
* Keep changes focused and easy to review.
* Treat the repository state as the source of truth.

---

# 2. Autonomous Execution

Work autonomously whenever the required information is available.

Before asking the user a question:

1. Inspect the repository.
2. Search for existing implementations.
3. Check project conventions.
4. Check related files and dependencies.
5. Infer the intended approach from existing code.

Do not ask for confirmation for routine implementation decisions.

Ask the user only when:

* requirements are genuinely ambiguous;
* required information is unavailable;
* authentication or permission is required;
* an action is destructive or difficult to reverse;
* multiple approaches have materially different consequences and the correct choice cannot be inferred.

Do not ask the user to manually recover from temporary errors.

---

# 3. Task Planning

For non-trivial tasks:

1. Understand the objective.
2. Inspect the relevant code.
3. Identify dependencies and affected areas.
4. Form a concise implementation plan.
5. Execute the plan incrementally.
6. Verify the result.

Do not create an unnecessarily detailed plan for trivial changes.

Keep the implementation aligned with the original objective.

---

# 4. Task Continuity

Never abandon a task merely because execution was interrupted.

If execution is interrupted by:

* provider failure;
* network failure;
* timeout;
* tool failure;
* context interruption;
* model switching;
* temporary infrastructure failure;

then:

1. Inspect the current repository state.
2. Determine what has already succeeded.
3. Identify the first incomplete operation.
4. Continue from that point.
5. Preserve all successful work.
6. Do not restart the task from the beginning.

The current repository state is authoritative.

---

# 5. Provider Failure Recovery

Provider failures are infrastructure failures, not task failures.

When the configured LLM router or provider fails:

* Do not abandon the task.
* Do not repeatedly retry the same failed provider.
* Prefer the configured router fallback mechanism.
* Preserve task context and completed work.
* Continue from the last successful operation after failover.
* Do not ask the user to type "continue" for a recoverable provider failure.

Expected behavior:

Provider A fails
→ fallback provider
→ continue task

Not:

Provider A fails
→ stop
→ ask user to continue

If all configured providers fail, report the failure clearly and preserve the current task state.

---

# 6. Tool Failure Recovery

When a tool fails:

### Transient failure

Examples:

* timeout;
* temporary network failure;
* connection reset;
* temporary service unavailable;
* rate limit;
* temporary filesystem failure.

Retry up to 2 times when safe.

Preserve the original intent and parameters.

### Persistent failure

If retrying does not work:

1. Determine the cause.
2. Try an alternative approach when possible.
3. Continue the task if the alternative is safe.
4. Ask the user only when recovery genuinely requires user input.

Never retry indefinitely.

Never repeat successful operations unnecessarily.

---

# 7. Context and State Recovery

When recovering from an interruption:

* Do not rely solely on previous conversation state.
* Inspect the actual repository.
* Check `git status`.
* Inspect recently changed files.
* Review relevant diffs.
* Verify whether previous operations completed successfully.
* Continue from the actual current state.

Never assume an operation failed simply because the previous model stopped responding.

Never assume an operation succeeded without verification.

---

# 8. Existing Architecture

Before introducing a new implementation:

* Search for similar features.
* Identify existing architectural patterns.
* Reuse existing abstractions.
* Follow existing naming conventions.
* Follow existing dependency patterns.
* Follow existing error handling.
* Follow existing state management.

Do not introduce a new architecture when the project already has an established one.

When existing code is inconsistent, prefer the pattern used by the surrounding feature unless the task explicitly requires architectural improvement.

---

# 9. Dependencies

Before adding a dependency:

1. Check whether an existing dependency already provides the required functionality.
2. Check how similar functionality is implemented elsewhere.
3. Prefer existing project dependencies.
4. Avoid adding dependencies for trivial functionality.
5. Consider maintenance, platform support, and project compatibility.

Do not replace an existing dependency without a concrete reason.

---

# 10. Code Quality

Write code that is:

* readable;
* maintainable;
* testable;
* consistent with the project;
* appropriately typed;
* minimally complex.

Avoid:

* unnecessary abstractions;
* premature optimization;
* duplicated logic;
* dead code;
* commented-out code;
* magic values when constants are appropriate;
* unrelated refactoring.

Do not modify unrelated files unless required.

---

# 11. Security

Treat security-sensitive operations conservatively.

Never:

* expose secrets;
* hardcode credentials;
* commit API keys;
* print tokens or passwords;
* weaken authentication merely to make a task work;
* disable security controls without explicit justification.

Check for obvious security implications when modifying:

* authentication;
* authorization;
* API endpoints;
* file uploads;
* database queries;
* external requests;
* local storage;
* secrets;
* permissions.

Prefer existing secure project patterns.

---

# 12. Data Safety

Before destructive operations:

* inspect the target;
* confirm scope;
* preserve user changes;
* avoid irreversible actions when a reversible alternative exists.

Do not:

* delete unrelated files;
* reset user changes;
* overwrite unrelated work;
* perform destructive database operations without clear justification.

If a destructive action is genuinely required and cannot be safely inferred, ask the user.

---

# 13. Git Safety

Before significant changes:

* inspect `git status`;
* preserve existing user modifications;
* understand the current branch and working tree.

Do not:

* reset unrelated changes;
* discard user modifications;
* force push;
* rewrite history;
* amend commits you did not create during the current task;

unless explicitly requested.

Do not create commits unless requested or clearly established by the project's workflow.

---

# 14. Verification

Never declare a task complete immediately after editing code.

After implementation:

1. Inspect the changed files.
2. Run the appropriate formatter.
3. Run static analysis when available.
4. Run relevant tests when available.
5. Run a build or compile check when practical.
6. Review the final diff.
7. Verify that the requested behavior is implemented.

If verification fails:

* diagnose the failure;
* fix it;
* rerun the relevant verification.

Do not hide verification failures.

Do not claim success without reasonable verification.

---

# 15. Minimal Change Principle

Prefer:

```
smallest correct change
```

over:

```
largest possible refactor
```

When a task can be solved without touching unrelated code, do not touch unrelated code.

If refactoring is useful but not required, keep it separate from the requested implementation unless it is necessary for correctness.

---

# 16. Error Handling

Do not silently swallow errors.

When adding error handling:

* preserve useful error information;
* follow existing project conventions;
* provide meaningful user-facing errors where appropriate;
* avoid exposing sensitive internal information.

Prefer explicit and recoverable failure paths.

---

# 17. Testing Strategy

When tests exist:

* follow the existing testing structure;
* add or update tests for meaningful behavior changes;
* prefer focused tests over unnecessary broad test suites.

When tests do not exist:

* perform the strongest practical verification available;
* inspect the implementation;
* run static analysis/build checks;
* avoid creating a large testing framework solely for a small task.

---

# 18. Long-Running Tasks

For large tasks, maintain an internal checkpoint:

* Objective
* Completed work
* Current work
* Remaining work
* Files changed
* Verification status

After interruption, reconstruct the checkpoint from the repository instead of restarting.

Do not repeatedly summarize the entire task unless necessary.

---

# 19. Communication

Keep responses concise and useful.

During implementation:

* state what is being done when useful;
* avoid unnecessary narration;
* report meaningful decisions;
* report blockers clearly.

At completion, summarize:

1. What changed.
2. Important files affected.
3. Verification performed.
4. Any remaining issues.

Do not claim that something was tested if it was not tested.

---

# 20. Completion Criteria

A task is complete only when:

* the requested behavior has been implemented;
* relevant existing behavior remains intact;
* the code is reasonably consistent with the project;
* relevant verification has been performed;
* known errors have been addressed;
* no unnecessary unrelated changes were introduced.

If something remains unresolved, explicitly state it instead of pretending the task is complete.

---

# 21. Recovery Priority

When multiple recovery strategies are available, use this priority:

1. Continue from the current state.
2. Retry a safe transient operation.
3. Use an alternative implementation.
4. Use the configured provider fallback.
5. Ask the user only when recovery genuinely requires user input.

Never abandon a recoverable task prematurely.

---

# 22. Copywriting (wajib)

Semua teks yang tampil ke pengguna (UI copy, pesan error API, email,
notifikasi, docs contoh) memakai bahasa Indonesia santai yang
memanusiakan. Sapaan **kamu**, bukan "Anda". Max satu partikel santai
(`ya` / `aja`) per kalimat. Tidak pernah pakai em/en dash (`-` / `-`),
cukup hyphen ASCII (`-`). Error tetap informatif: sebab + aksi.

Acuan lengkap per platform:

- Mobile: `docs/mobile/mobile-base-stack.md` - "Nada copywriting UI"
- Web: `docs/web/web-base-stack.md` - "Nada copywriting UI"
- Admin console: `docs/admin/admin-base-stack.md` - "Nada copywriting UI"
- API: `docs/api/api-base-stack.md` - "Nada copywriting error & response"

Pesan keamanan (token, OTP, konfirmasi hapus akun) tetap lugas tanpa
partikel; kejelasan konsekuensi di atas kehangatan.

---

# 23. Context Mode (hemat konteks)

MCP `context-mode` tersedia di semua tool (Cursor, Claude Code, Hermes, OpenCode).
Sebelum Read/Grep/WebFetch dengan output besar, pakai dulu:

| Kebutuhan | Tool |
|-----------|------|
| Command dengan output besar | `ctx_execute` |
| Cari kode / jawaban di codebase | `ctx_search` |
| Docs eksternal | `ctx_fetch_and_index`, lalu `ctx_search` |
| Index direktori | `ctx_index` |

Boleh Read/Grep langsung kalau: sudah tahu file + baris persis yang diedit,
output kecil (file pendek, grep < 50 baris), atau context-mode tidak punya tool
yang cocok. Setelah sesi eksplorasi berat, jalankan `ctx_stats`.

---

# 24. Agent Reach (riset internet)

CLI `agent-reach` terpasang (via uv). Skill lengkap: `~/.agents/skills/agent-reach/SKILL.md`.

| Kebutuhan | Cara |
|-----------|------|
| Baca web page | `curl -s "https://r.jina.ai/URL"` |
| YouTube subtitle/info | `yt-dlp --dump-json URL` |
| Search GitHub | `gh search repos "query"` |
| RSS | `feedparser` |
| Semantic search | `mcporter call exa.web_search_exa query="..." numResults=5` |

Prioritas: docs mau di-index permanen pakai `ctx_fetch_and_index`; riset one-off pakai Agent Reach.
Channel login (Twitter, Reddit, dll) belum aktif - minta user dulu. Cek status: `agent-reach doctor`.

---

# 25. Event Aktivitas Wajib Publik (activity events)

Setiap aksi pengguna yang layak dilihat publik WAJIB menghasilkan event
aktivitas yang tercatat, bukan diturunkan belakangan dari timestamp kolom
sumber. Prinsip: timeline dibekukan pada momen kejadian; mengedit/melengkapi
entitas TIDAK boleh menulis ulang sejarah feed (pembelajaran issue #86:
`verified_at` tertimpa -> kata lama muncul sebagai "baru ditambahkan").

## Daftar event (satu-satunya sumber kebenaran)

| Event | Trigger | Actor |
|-------|---------|-------|
| `word.created` | kata jadi published (approve usul / self-apply) | pembuat kata |
| `word.verified` | verifikator verifikasi kata (termasuk approve usul kata baru) | verifikator |
| `contribution.image` / `contribution.audio` / `contribution.pron` / `contribution.example` | kontribusi jenis itu disetujui | kontributor |
| `comment.created` | komentar published | penulis |
| `vote.word` / `vote.comment` | vote +/- | pemilih |
| `discussion.created` | diskusi published | pembuat |
|| `suggestion.applied` | usulan edit diterima (non-self) | pengusul ||
|| `suggestion.created` | usulan edit dikirim (pending) | pengusul ||
|| `suggestion.selfapply` | verifikator lengkapi kata langsung | verifikator ||
|| `contribution.submitted` | "Usul kata baru" dikirim (pending review) | pengusul ||
| `search.miss` | pencarian tanpa hasil (visible) | null |
| `user.joined` | akun terverifikasi | user baru |
| `card.shared` | share kartu kata | yang share |

Yang BUKAN event (tetap dipertahankan privat): kontribusi pending/rejected,
word reports, teks bebas usulan (hanya aksi + lemma), edit tanpa perubahan.

## Aturan

1. Fitur baru yang menghasilkan aksi pengguna publik = tambah event ke daftar
   (docs + implementasi) di sesi yang sama. Event yang tak terdaftar = bug.
2. `word.created` vs `word.verified` TIDAK pernah digabung satu baris:
   kontributor (membuat) dan verifikator (memverifikasi) adalah dua kejadian
   berbeda dan harus bisa dibedakan di feed (issue #85).
3. Waktu event = momen kejadian (approve/vote/post), bukan `updated_at` /
   `verified_at` kolom sumber yang bisa tertimpa.
4. Visibility dicek read-time (soft-delete, takedown, label terlarang,
   blocklist): event tidak dihapus, hanya disembunyikan. Usulan kata/usulan
   edit yang DITOLAK = event usulannya di-hide saat reject (hide-on-reject,
   konsisten vote retract).
5. Feed beranda menampilkan SEMUA event di atas; timeline profil publik =
   subset event dengan actor = pemilik profil (kecuali `search.miss` yang
   tanpa actor). Tidak ada aksi publik yang "hilang" dari salah satu
   permukaan.
6. Wording dua permukaan (beranda = aktor sebagai subjek; profil =
   kalimat aksi tanpa subjek, bentuk berimbuhan): acuan lengkap di
   `docs/api/37-api-activity-feed.md` dan `docs/mobile/23-mobile-activity-feed.md`
   - dua file itu wajib ikut diperbarui saat daftar event berubah.
7. Copy tampilan yang bergantung state saat kejadian (mis. arah vote)
   dibekukan di kolom `activity_events.payload` (#94): feed beranda dan
   timeline profil membaca payload yang sama — tidak ada kalkulasi live
   read-time untuk copy. Flip arah vote = timpa payload (dedupe key sama,
   state terakhir), bukan event baru.

# 26. Read-path hemat subrequest (JOIN, bukan N panggilan)

Satu request HTTP = satu Worker invocation di Cloudflare; setiap query ke
Turso = 1 subrequest, limit default 50/invocation. Issue mobile#103: feed
meledak ~100+ subrequest per request → `Too many subrequests by single
Worker invocation`. Karena itu:

1. **Dilarang N+1 di read-path**: `for`/`.map`/`.forEach` berisi `await`
   query per baris = bug. Ambil semua field yang dibutuhkan dalam SATU
   query via `JOIN`/`LEFT JOIN` (kolom yang dipakai saja — proyeksi ketat),
   atau batch `IN (...)` + resolve via `Map`, lalu transform row ke bentuk
   wire secara synchronous.
2. **`Promise.all` atas beberapa panggilan repo juga subrequest** — gabung
   jadi satu query bila bisa (contoh: mode merge profil publik dulu 4
   panggilan paralel → kini 1 query mode `merged`).
3. **Jangan memanggil API/service lain berulang per baris** dalam satu
   request — persis pola sama, batas subrequest berlaku keluar juga.
4. **Wajib test budget query** untuk endpoint feed/timeline: spy
   `client.execute` lalu assert jumlah query per request kecil (≤3).
   Acuan: `api/src/modules/activity/__tests__/e2e/v1/activity-query-count.e2e.test.ts`.
5. Mitigasi `wrangler.toml` `[limits] subrequests` hanya jaring pengaman —
   bukan alasan tetap boros; target 1–2 query per request.

# 27. Satu pekerjaan selesai = commit + push sebelum pekerjaan baru

Setiap kali satu pekerjaan **selesai** (test hijau, gate lulus) dan akan
**dimulai pekerjaan baru**, WAJIB menuntaskan pekerjaan lama terlebih dahulu:

1. **Commit** perubahan pekerjaan itu (pathspec eksplisit, file kerjaan
   itu saja — jangan campur WIP pekerjaan lain).
2. **Push** ke staging: lewat feature branch → push branch + buat PR
   (merge = keputusan Tuan); bila memang kerja langsung di `staging` →
   push ke `staging`.
3. Baru kemudian mulai pekerjaan berikutnya.

DILARANG memulai pekerjaan baru dengan pekerjaan lama masih menggantung
tidak di-commit / tidak di-push. WIP numpuk lintas pekerjaan = akar dari
working tree kotor, stash berlapis, dan kehilangan kerja (pahit dari
sesi-sesi sebelumnya).

Batas: WIP yang sengaja ditunda (mis. menunggu keputusan Tuan) harus
diketahui Tuan eksplisit — bukan diam-diam ditinggal.
