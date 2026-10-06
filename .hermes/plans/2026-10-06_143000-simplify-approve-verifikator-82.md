# Plan: Simplify Approve for Verifikator (#82)

**Goal**: Add inline "Verifikasi" CTA on word detail page for verifikators when viewing an unverified word, so they can verify without navigating to the swipe review screen.

---

## Current Context / Assumptions

- **API**: `VerifyWordUseCase` exists (`POST /api/v1/words/:id/verify` with `{verified: true}`), requires `admin/root/reviewer` role.
- **Mobile**: `WordDetailPage` (`lib/features/dictionary/presentation/pages/word_detail_page.dart`) displays `WordDetail` entity with `isVerified`, `verifiedBy`, `createdBy`.
- **Auth**: `authStatusProvider` exposes current user `role` (e.g., `reviewer`, `admin`, `root`, `contributor`).
- **Review flow**: Separate `ReviewQueuePage` (swipe/tinder-like) at `/review/queue` for bulk review.
- **Design system**: ForUI (`FButton`, `FCard`, `FSnackbar`, `FDialog`) used throughout.
- **Routing**: GoRouter; word detail at `/words/:id`.

---

## Architecture / Proposed Approach

1. **CTA Placement**: In `_DetailBody` (word detail body), after the header/badges area, show a primary `FButton` "Verifikasi kata" when:
   - Current user role ∈ {`reviewer`, `admin`, `root`}
   - `detail.isVerified == false`
   - Word status is `published` (not draft/archived)

2. **Action**: On press → show confirmation dialog ("Verifikasi kata ini?") → call API `verifyWord` → on success: invalidate `wordDetailProvider`, show snackbar "Kata diverifikasi", rebuild UI with verified badge; on error: snackbar with error message.

3. **Reuse**: Existing `wordDetailProvider` + new `verifyWordMutation` (Riverpod `AsyncNotifier` or `Mutation`-style provider). No new API endpoints needed.

---

## Step-by-Step Tasks

### 1. Add VerifyWord mutation provider (mobile)

**File**: `lib/features/dictionary/presentation/providers/word_detail_providers.dart` (or new `verify_word_provider.dart`)

```dart
// In word_detail_providers.dart, after existing providers
final verifyWordProvider = AsyncNotifierProvider.autoDispose
    .family<VerifyWordNotifier, void, String>(VerifyWordNotifier.new);

class VerifyWordNotifier extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  Future<void> build(String wordId) async {}

  Future<void> verify({required String actorId}) async {
    state = const AsyncLoading();
    final repo = ref.read(wordRepositoryProvider);
    final result = await repo.verifyWord(wordId: arg, verified: true);
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (_) => state = const AsyncData(null),
    );
  }
}
```

**Repository method** (add to `WordRepository` interface + impl):

```dart
// lib/features/dictionary/domain/repositories/word_repository.dart
Future<Either<DictionaryFailure, Unit>> verifyWord({
  required String wordId,
  required bool verified,
});

// lib/features/dictionary/data/repositories/word_repository_impl.dart
@override
Future<Either<DictionaryFailure, Unit>> verifyWord({
  required String wordId,
  required bool verified,
}) async {
  try {
    final response = await _apiClient.post(
      '/words/$wordId/verify',
      body: {'verified': verified},
    );
    return Right(unit);
  } on ApiException catch (e) {
    return Left(DictionaryFailure(e.message, code: e.code));
  }
}
```

**Verification**: `flutter analyze` passes; `dart run build_runner build` if needed.

---

### 2. Add role helper + CTA widget in WordDetailPage

**File**: `lib/features/dictionary/presentation/pages/word_detail_page.dart`

Add near top of file (after imports):

```dart
/// True jika role user saat ini boleh verifikasi kata.
bool _canVerify(WidgetRef ref) {
  final role = ref.watch(authStatusProvider.select((s) => s.role));
  return role == 'reviewer' || role == 'admin' || role == 'root';
}
```

Add CTA widget (insert in `_DetailBody.build` after the status badges / before meanings):

```dart
// Inside _DetailBody.build, after the verified badge row:
if (!_canVerify(ref) || detail.isVerified || detail.status != 'published')
  const SizedBox.shrink()
else
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: SizedBox(
      width: double.infinity,
      child: FButton(
        onPress: () => _showVerifyDialog(context, ref, detail.id),
        child: const Text('Verifikasi kata'),
      ),
    ),
  ),
```

Dialog + action:

```dart
void _showVerifyDialog(BuildContext context, WidgetRef ref, String wordId) {
  showDialog<void>(
    context: context,
    builder: (ctx) => FDialog(
      title: const Text('Verifikasi kata'),
      body: const Text('Tandai kata ini sebagai terverifikasi?'),
      actions: [
        FButton(
          variant: FButtonVariant.secondary,
          onPress: () => Navigator.of(ctx).pop(),
          child: const Text('Batal'),
        ),
        FButton(
          onPress: () async {
            Navigator.of(ctx).pop();
            await _verifyWord(context, ref, wordId);
          },
          child: const Text('Verifikasi'),
        ),
      ],
    ),
  );
}

Future<void> _verifyWord(BuildContext context, WidgetRef ref, String wordId) async {
  final notifier = ref.read(verifyWordProvider(wordId).notifier);
  await notifier.verify(actorId: ''); // actorId diambil dari auth di server
  if (!context.mounted) return;
  if (notifier.state.hasError) {
    final failure = notifier.state.error as DictionaryFailure;
    FSnackbar.show(
      context,
      message: Text(failure.message),
      action: FSnackbarAction(label: 'OK', onPress: () {}),
    );
  } else {
    ref.invalidate(wordDetailProvider(wordId));
    FSnackbar.show(
      context,
      message: const Text('Kata diverifikasi'),
      action: FSnackbarAction(label: 'OK', onPress: () {}),
    );
  }
}
```

**Verification**: Hot reload → open unverified word as reviewer → button appears → tap → dialog → confirm → word shows verified badge + snackbar.

---

### 3. Update DTO/Repository if needed

Check `WordDetailDTO` has `isVerified` (already yes). Ensure `WordRepositoryImpl.verifyWord` calls correct endpoint with auth header (existing `ApiClient` handles Bearer).

**Verification**: Run existing dictionary tests:
```bash
flutter test test/features/dictionary/
```

---

### 4. Test: Unit + Widget

**File**: `test/features/dictionary/word_detail_page_test.dart` (new or extend)

```dart
testWidgets('Verifikator melihat tombol Verifikasi pada kata unverified', (tester) async {
  await tester.pumpWidget(makeTestableWidget(
    providers: [overrideWith(reviewerAuthProvider, ...)],
    child: WordDetailPage(wordId: 'w1'),
  ));
  // mock wordDetailProvider to return unverified word
  // expect find.byWidgetPredicate((w) => w is FButton && w.child is Text && (w.child as Text).data == 'Verifikasi kata')
});

testWidgets('Non-verifikator tidak melihat tombol', (tester) async {
  // override with contributor auth
  // expect no verify button
});
```

Run: `flutter test test/features/dictionary/word_detail_page_test.dart`

---

### 5. Edge Cases / Polish

| Case | Handling |
|------|----------|
| Word sudah verified | Button hidden (checked by `detail.isVerified`) |
| Status bukan `published` | Button hidden |
| User bukan verifikator | Button hidden |
| API error (rate limit, forbidden) | Snackbar with message, button re-enabled |
| Race condition double tap | `FButton` disabled during `AsyncLoading` state (wrap with `AsyncValue.when`) |

---

## Tests / Validation Checklist

- [ ] `flutter analyze` — 0 errors
- [ ] `flutter test test/features/dictionary/` — all pass
- [ ] Manual: login as reviewer → open unverified word → CTA visible → verify → badge updates
- [ ] Manual: login as contributor → same word → no CTA
- [ ] Manual: verified word → no CTA for reviewer
- [ ] Manual: offline / error → snackbar shows error

---

## Risks, Tradeoffs, Open Questions

| Risk | Mitigation |
|------|------------|
| Role string casing (`Reviewer` vs `reviewer`) | Normalize to lowercase in `_canVerify` |
| API endpoint path exactness | Confirm route: `POST /api/v1/words/:id/verify` |
| Auth header on mutation | Existing `ApiClient` attaches Bearer automatically |
| Duplicate verify (race) | Server returns `WORD_ALREADY_VERIFIED` → UI shows snackbar |
| Review queue vs inline verify UX overlap | Keep both; inline = quick action, queue = bulk |

**Open Questions** (decide before implementing):
1. Should CTA also appear on `WordCompletePage` (contribution complete screen)?
2. Unverify action needed? (prob not for MVP)
3. Analytics event for inline verify? (reuse `AnalyticsService.logVerify`)

---

## Saved Plan Path

`.hermes/plans/2026-10-06_143000-simplify-approve-verifikator-82.md`