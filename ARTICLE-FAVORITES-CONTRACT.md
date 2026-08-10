# Article Favorites and Following Hub Contract

Status: frozen for the current native iOS slice.

This contract extends the existing personal-state boundary to saved news
articles and turns Following into a deterministic hub for user-controlled
interests. It does not add inferred recommendations or claim that an article is
about a followed team when the content contract does not provide that relation.

## 1. Public behavior

- A published article can be saved or removed from its detail screen.
- Save, repeated save, remove and repeated remove are idempotent.
- Saved articles are listed newest-saved first. Equal timestamps use article ID
  as a stable tie-breaker.
- The Following tab independently presents notification settings, saved
  articles, saved videos and followed teams, players, or competitions. A failure in one section cannot
  erase or hide successfully loaded sections.
- When every personal section has loaded successfully and is empty, one combined
  empty state explains that users can follow sports interests or save articles/videos.
- No recommendation score, inferred team relationship or synthetic content is
  generated in this slice.

## 2. Identity routing

- Signed-out/unavailable-account builds read and write the device guest store.
- A valid account session reads and writes only authenticated `/me` resources.
- An expired or unreadable account session fails closed; it must not silently
  write account activity into the guest profile.
- Authentication changes invalidate in-flight article state and Following loads.
  A response started for an old identity cannot overwrite the current identity.
- Guest data is offered for explicit merge after sign-in. It is never merged
  silently.

## 3. Guest persistence and privacy

- The guest store keeps only saved article metadata, article ID and saved time.
  Article bodies, media URLs, account IDs and authentication tokens are excluded.
- Removing an article also removes its private metadata snapshot. Merely reading
  an unsaved article does not create a durable personal article snapshot.
- A corrected article may update the metadata snapshot only while it remains
  saved. Its original saved timestamp is retained.
- Device-data summary, confirmation and clear operations explicitly include
  saved articles. Clearing guest personalization removes article favorites along
  with existing guest history, saved videos and follows, but preserves language,
  onboarding, device identifiers, public cache and any signed-in account data.
- Existing version-1 guest files decode with empty article fields and migrate
  without losing video progress, video favorites or follows.

## 4. Account API

Authenticated state uses these resources:

- `GET /me/article-favorites?limit=100`
- `GET /me/article-favorites/{articleId}`
- `PUT /me/article-favorites/{articleId}`
- `DELETE /me/article-favorites/{articleId}`

All requests require Bearer authentication and `Cache-Control: no-store`.
Mutation requests carry an idempotency key. State-bearing GET/PUT responses must
echo the requested article ID and a PUT must return `isFavorite: true`;
mismatches are contract errors. DELETE returns 204 without a body. Personal
responses never enter the public ETag cache and never fall back to Mock data.

## 5. Guest-to-account merge

- Merge records contain only `articleId` and `updatedAt`.
- Article favorites are batched independently with at most 500 records per
  request, matching the existing progress/video/follow batching rule.
- Duplicate IDs, unsafe IDs and timestamps more than five minutes in the future
  are rejected before network access.
- The server separately acknowledges `articleFavoritesUpserted`; every submitted
  record must be counted exactly once across upserted and server-newer-retained
  totals.
- The device guest store is cleared only after every batch has been acknowledged.
  Any failure retains the complete local state for retry.

## 6. Correction and withdrawal behavior

- Saved-list metadata is a local/account snapshot and may still be visible while
  offline.
- Opening an article always uses the authoritative article-detail path. A 410
  response displays the withdrawn state and must not be revived by its favorite
  snapshot or Mock fallback.
- An already-saved withdrawn article remains removable. A withdrawn or otherwise
  unavailable article cannot be newly saved.
- When authoritative corrected metadata loads for a saved guest article, the
  stored title, summary, source, category and correction flag may refresh; the
  article body is never copied into the personal store.

## 7. Accessibility and interaction

- The save/remove control is a native Button with a minimum 44-point target.
- Its visible label, icon and VoiceOver label all distinguish Save from Remove;
  color is never the only state signal.
- While a mutation is running, the button is disabled and exposes a textual
  progress state.
- Mutation and section-load failures use localized text plus an icon, retain the
  previous confirmed state, and move VoiceOver focus to the relevant failure.
- Article, video and team cards remain normal NavigationLinks with explicit
  open-destination hints and deterministic accessibility identifiers.

## 8. Acceptance evidence

- Store tests cover persistence, version-1 migration, correction refresh,
  idempotent removal and isolation from video/follow state.
- Mock and remote provider tests cover list/get/put/delete, request security,
  response ID/state validation and authentication failure before network access.
- Authentication tests cover article merge payloads, batching, acknowledgement,
  duplicate/future-date rejection and retain-on-failure behavior.
- A UI journey saves an article, opens Following, finds the saved article and
  removes it without changing any followed interest.
- macOS/Xcode remains required to execute XCTest and verify VoiceOver focus,
  Dynamic Type, RTL rendering and real authenticated API behavior.
