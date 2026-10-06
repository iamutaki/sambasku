# Admin UI - Usul Perubahan Kata (Review Suggestion)

Mengikuti `admin-base-stack.md`: feature-based, React + TanStack Router + AntD,
React Query untuk server state. Kontrak API: `docs/api/17-api-suggest-edit-word.md`.

Dokumen ini menjelaskan halaman admin untuk **mereview usulan perubahan kata**
 dari user, menampilkan **riwayat perubahan** di detail kata, serta
 **dashboard antrean usulan**.

---

## 1. Halaman List Usulan (Admin)

### Route

```
/admin/word-suggestions        → list usulan perubahan (admin)
/admin/word-suggestions/:id   → detail usulan + diff + tindakan
```

### List Page (`WordSuggestionsListPage`)

- **Header**: judul "Usulan Perubahan Kata", badge count pending
- **Filter** (AntD Filter):
  - Status: Semua | Pending | Disetujui | Ditolak | Dikoreksi
  - Pencarian: cari berdasarkan lemma kata atau username kontributor
- **Tabel** (AntD Table):
  | Kolom | Keterangan |
  |-------|-----------|
  | ID | ULID suggestion (copyable, tooltip) |
  | Kata | Lemma + bahasa |
  | Kontributor | Username |
  | Alasan | Label reason_code (+ detail truncate) |
  | Ringkasan Perubahan | Lemma, catatan, makna (N), kategori (±N), relasi (N), varian (N), gambar (N) |
  | Status | Badge: pending (kuning), approved (hijau), rejected (merah), corrected (biru) |
  | Dikeluarkan | Tanggal relatif |
  | Aksi | Detail, Approve, Reject, Correct |

### Badge count pending

- Muncul di sidebar/navbar admin, mengarah ke `/admin/word-suggestions?status=pending`
- Dihitung lewat query terpisah (tanpa load semua list)
- Usulan dari verifikator (`admin|editor|root|reviewer`) **tidak** masuk
  antrean: API auto-apply + `status: approved` saat create (lihat
  `docs/api/17-api-suggest-edit-word.md`). Antrean hanya usulan kontributor.
- Mobile punya antrean paralel di hub `/review/suggestions` (approve/reject
  saja; **tanpa** Correct / sensor gambar per-file - itu tetap di sini).
  Lihat `docs/mobile/06-mobile-suggest-edit.md` bagian batasan mobile.

---

## 2. Halaman Detail Usulan + Diff

### Route

```
/admin/word-suggestions/:id
```

### Aplikasi (`WordSuggestionDetailPage`)

Layout: dua kolom (desktop) / stack (mobile/tablet)

#### Kolom kiri: Info usulan

- **Header**: "Review Usulan" + back button
- **Kata terkait**: lemma, bahasa, jenis entri (badge) - link ke detail kata
  admin (`/admin/words/:wordId`)
- **Kontributor**: username, waktu usul
- **Alasan**: badge `reason_code` + teks `reason` (label ± detail)
- **Status**: badge + info (contoh: "Menunggu review")
- **Button aksi** (bergantung status):
  - Pending: Approve, Reject, Correct
  - Approved/Rejected/Corrected: "Sudah diverifikasi" (nonaktif) + info reviewer & komentar

#### Kolom kanan: Diff viewer

**Header**: "Perbandingan: Usulan vs Saat Ini"

**Tab view**:
1. **Ringkasan** (default): list perubahan per kategori
   - Lemma / Catatan / Makna / Kategori (seperti sebelumnya)
   - **Relasi**: ditambahkan / dihapus (type + lemma target)
   - **Varian**: ditambahkan / dihapus (form)
   - **Gambar**: ditambahkan (thumbnail `Image` antd, klik overlay preview), dihapus, set primary
2. **JSON** (collapsible): proposed_changes mentah

**Visual diff**:
- Gunakan AntD `Diff` component atau custom highlight:
  - Baris yang berubah: background kuning muda
  - Baris baru: background hijau muda
  - Baris dihapus: background merah muda + strikethrough
- Untuk makna: tampilkan makna per-item dengan definisi side-by-side atau
  stacked (current di atas, proposed di bawah)

**Preview kata setelah approve** (opsional - nice-to-have):
- "Jika disetujui, kata akan berubah menjadi:" → tampilkan lemma baru,
  definisi baru, kategori baru dalam bentuk preview card mirip detail kata.

---

## 3. Tindakan Admin

### Approve

- Konfirmasi dialog: "Setujui usulan ini? Perubahan akan langsung diterapkan
  ke kata."
- Jika ada komentar opsional: input kecil "Komentar (opsional)"
- Foto ImageKit di diff: **Tayangkan / Jangan tayangkan** per foto;
  tombol **Sensor** (ImageCensorEditor) hanya untuk yang ditayangkan.
  Approve kirim multipart (`image_decisions` + `file_<key>` sensor).
- Setelah approve:
  - Toast sukses: "Usulan disetujui, 3 perubahan telah diterapkan."
  - Redirect ke list (atau tetap di halaman detail, status badge berubah)
  - Kalau ada notification, kirim notifikasi ke kontributor

### Reject

- Form wajib: input "Alasan penolakan" (textarea, wajib diisi minimal 10 char)
- Konfirmasi: "Tolak usulan ini? Kontributor akan diberi tahu alasan ini."
- Staging ImageKit di usulan dihapus; bila changes sudah apply_pending,
  baris foto staging di kata soft-delete.
- Setelah reject:
  - Toast: "Usulan ditolak."
  - Status badge berubah ke "Ditolak"

### Correct (koreksi sebelum approve)

- Form: tampilkan form edit mirip form approve tapi dengan field yang bisa
  diubah admin.
- Contoh: admin ingin memperbaiki typo di usulan user sebelum tayang.
- Field yang bisa dikoreksi: lemma, catatan, makna, kategori (sama seperti
  form usulan).
- Opsi: "Terapkan langsung" (publish=true) atau "Simpan koreksi saja"
  (publish=false, masih pending)
- Setelah correct + publish:
  - Toast: "Koreksi diterapkan, usulan disetujui."
- Setelah correct tanpa publish:
  - Toast: "Koreksi diterima, menunggu persetujuan."

---

## 4. Riwayat Perubahan di Detail Kata (Admin & Public)

### Route (keduanya)

```
/admin/words/:id/history     → riwayat lengkap (admin)
/words/:id/history           → riwayat publik (bisa diakses user umum)
```

### Halaman `WordHistoryPage`

**Header**:
- Title: "Riwayat Perubahan"
- Back button → detail kata
- Info kata: lemma + bahasa

**Timeline** (AntD Timeline component):
- Setiap perubahan = satu item timeline
- Urutan: terbaru di atas (descending)

**Item timeline**:
```
[Icon] [Timestamp] [Actor: username (role badge)]
Tipe: [Direct Edit | Usulan dari user]
Penjelasan: [Daftar perubahan]

Jika usulan:
  → Diusulkan oleh: username (tautan ke profil user jika ada)
  → Alasan: "..."
  → Ditinjau oleh: username (kalau sudah review)
  → Komentar: "..."
```

**Perubahan per item**:
- List perubahan dalam format yang mudah dibaca:
  - "Lemma: `kete'` → `kete'` (tidak berubah - tetap)"
  - "Definisi makna 1: '...' → '...'"
  - "Kategori: + Greeting, - Formal"
- Kalau perubahan banyak: expandable accordion

**Footer**:
- "Kembali ke detail kata" button

### Role access

- Public: bisa melihat riwayat tapi TIDAK bisa tindakan edit
- Admin: bisa melihat + tindakan (lihat bagian admin review)

---

## 5. State Management (React Query)

### Hooks (custom)

```typescript
// hooks/useSuggestions.ts
export function useSuggestions(params?: ListParams) {
  return useQuery({
    queryKey: ['word-suggestions', params],
    queryFn: () => fetchSuggestions(params),
  });
}

export function useSuggestionDetail(id: string) {
  return useQuery({
    queryKey: ['word-suggestion', id],
    queryFn: () => fetchSuggestionDetail(id),
    enabled: !!id,
  });
}

export function useChangeHistory(wordId: string) {
  return useQuery({
    queryKey: ['change-history', wordId],
    queryFn: () => fetchChangeHistory(wordId),
    enabled: !!wordId,
  });
}

export function useApproveSuggestion() {
  return useMutation({
    mutationFn: (id: string, comment?: string) => approveSuggestion(id, comment),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['word-suggestions'] });
      queryClient.invalidateQueries({ queryKey: ['change-history'] });
    },
  });
}
```

### API service

```typescript
// api/word-suggestions.ts
export const wordSuggestionsApi = {
  list: (params?: ListParams) =>
    apiClient.get('/api/v1/admin/word-suggestions', { params }),

  getDetail: (id: string) =>
    apiClient.get(`/api/v1/admin/word-suggestions/${id}`),

  approve: (id: string, comment?: string) =>
    apiClient.post(`/api/v1/admin/word-suggestions/${id}/approve`, { comment }),

  reject: (id: string, comment: string) =>
    apiClient.post(`/api/v1/admin/word-suggestions/${id}/reject`, { comment }),

  correct: (id: string, data: CorrectRequest) =>
    apiClient.post(`/api/v1/admin/word-suggestions/${id}/correct`, data),

  getChangeHistory: (wordId: string, params?: HistoryParams) =>
    apiClient.get(`/api/v1/words/${wordId}/change-history`, { params }),
};
```

---

## 6. Tampilan & UX

### Komponen

- **SuggestionCard**: komponen card untuk list item (gabungkan dengan AntD Card)
- **DiffViewer**: komponen untuk menampilkan diff (bisa pake library `diff` npm)
- **ChangePreview**: preview bagaimana kata akan terlihat setelah approve
- **StatusBadge**: badge status suggestion (pending/approved/rejected/corrected)

### Styling

- Warna status:
  - Pending: `#F59E0B` (amber/yellow)
  - Approved: `#10B981` (green)
  - Rejected: `#EF4444` (red)
  - Corrected: `#3B82F6` (blue)
- Font: sama seperti admin lainnya (AntD default)
- Spacing: 16px padding, 12px gap

### Empty state

- Kalau tidak ada usulan: "Belum ada usulan perubahan. Komunitas akan
  mengusulkan perubahan kata yang tayang."

---

## 7. Integrasi dengan Fitur Lain

### Detail Kata (admin)

- Di halaman detail kata admin, tambahkan tab "Riwayat Perubahan"
  (`/admin/words/:id?tab=history`)
- Atau buat link terpisah "Lihat Riwayat Perubahan" di halaman detail

### Notification

- Saat usulan disetujui/ditolak/dikoreksi, kirim notifikasi ke kontributor
  (lihat backlog `NEXT.md` - fitur notifikasi status usulan)

### Kontribusi Saya (user)

- User bisa melihat status usulannya di halaman profil/kontribusinya
  (lihat `docs/mobile/10-mobile-kontribusi-saya.md`)

---

## 8. Testing

- Unit test: API service functions (mock fetch)
- Integration test: halaman list + detail + tindakan (mock React Query)
- E2E test (Playwright/Cypress): alur lengkap review usulan

---

## Referensi Terkait

- `docs/api/17-api-suggest-edit-word.md` - kontrak API lengkap
- `docs/admin/admin-base-stack.md` - arsitektur & konvensi admin
- `docs/admin/10-admin-search-miss-buat-kata.md` - pola list + detail admin
- `docs/api/03-api-kontribusi-verifikasi.md` - pola review (referensii UI approve/reject/correct)
- Backlog `NEXT.md` - fitur notifikasi status usulan
