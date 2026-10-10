# Plan: Add `suggestion_created` Event (#82 follow-up)

**Goal**: Emit `suggestion_created` event when user submits a word suggestion, so it appears in public feed/timeline.

---

## Current Context

- Event kinds defined in `api/src/modules/activity/domain/entities/activity-event.entity.ts`
- Feed repo `ActivityEventFeedRepositoryImpl` handles mapping (KIND_TO_WIRE, KIND_BODY, etc.)
- Suggestion created in `WordSuggestionRepositoryImpl.createSuggestion()` (line ~543)
- Docs: 37-api-activity-feed.md, 23-mobile-activity-feed.md, 19-api-profil-publik.md
- Rules: AGENTS.md #25, .cursor/rules/activity-events-public.mdc, skill sambasku-mobile

---

## Architecture

Add `suggestion_created` to the 16 event kinds. Event fires at suggestion creation (not approval). Actor = pengusul. Target = wordId + suggestionId. Visible immediately in feed (pending status doesn't hide event — only approval adds `suggestion_applied`).

---

## Step-by-Step Tasks

### 1. Add kind to entity + wire mapping

**File**: `api/src/modules/activity/domain/entities/activity-event.entity.ts`

```typescript
// In ACTIVITY_EVENT_KINDS array, add:
'suggestion_created',
```

```typescript
// In wireKind() mapping, add:
suggestion_created: 'suggestion',
```

### 2. Add feed repo mappings

**File**: `api/src/modules/activity/infrastructure/activity-event-feed.repository.impl.ts`

```typescript
// KIND_TO_WIRE
suggestion_created: 'suggestion',

// KIND_BODY
suggestion_created: 'Mengusulkan perubahan',

// subtitleFor
case 'suggestion_created':
  return 'Usulan baru';

// targetFor
case 'suggestion_created':
  return { type: 'suggestion', id: row.targetId ?? '' };

// publicSummary (profil timeline - category contribution)
case 'suggestion_created':
  return `Mengusulkan perubahan ${q}`.trim();
```

### 3. Emit event in createSuggestion

**File**: `api/src/modules/word-suggestions/infrastructure/word-suggestion.repository.impl.ts`

After successful insert (around line 645), add:

```typescript
await this.emitEvent({
  kind: 'suggestion_created',
  actorId: userId,
  targetWordId: wordId,
  targetId: suggestion.id,
  dedupeKey: `suggestion:${suggestion.id}`,
});
```

Need to inject activityEvents repo or use-case. Check how other emitters called.

### 4. Update docs

- `docs/api/37-api-activity-feed.md`: add row to kind mapping table
- `docs/mobile/23-mobile-activity-feed.md`: add wording for beranda/profil
- `docs/api/19-api-profil-publik.md`: add to contribution category

### 5. Update rules

- `AGENTS.md` #25: add `suggestion_created` to table (17 kinds now)
- `.cursor/rules/activity-events-public.mdc`: add to list
- Skill `sambasku-mobile`: sync

### 6. Tests

- Unit: verify event emitted on createSuggestion
- E2E: feed includes suggestion_created
- Run: `npx vitest run` (api), `flutter test` (mobile)

---

## Risks

- Duplicate event if user resubmits after reject? dedupeKey `suggestion:${id}` prevents (new suggestion = new id)
- Pending suggestion visible in feed before review — by design (user request)
- Timeline profil: suggestion_created goes to "contribution" category (pengusul)

---

## Saved Plan Path

`.hermes/plans/2026-10-06_153000-add-suggestion-created-event.md`