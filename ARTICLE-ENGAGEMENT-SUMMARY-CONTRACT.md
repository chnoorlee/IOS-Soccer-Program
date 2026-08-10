# Article Card Engagement Summary Contract

Status: frozen for the current native iOS slice.

This contract covers the compact public interaction summary evidenced at the
bottom of the Koora Break news card. SportsHub keeps its own visual language
and does not copy the reference card, branding, protected media or private
analytics schema.

## 1. Public snapshot

- `ArticleSummary.engagement` contains exactly `totalReactions` and
  `publishedComments`.
- Both values are server-authoritative integers from `0...2,000,000,000`.
  `totalReactions` is the aggregate across the reaction types supported by the
  article community; `publishedComments` counts only comments currently safe
  for the public moderated list.
- The snapshot contains no caller identity, `myReaction`, blocked-author state,
  pending/rejected/removed comments, ranking score or share analytics.
- A missing field is tolerated by the iOS decoder during rolling deployment
  and by legacy saved articles. Missing means unavailable, not zero, so the
  card hides the summary.

## 2. Freshness and caching

- The summary travels with the public `ArticleSummary` and follows the same
  ETag/offline-cache policy. It is a point-in-time editorial-feed snapshot and
  is never labelled live.
- Article detail community reads remain independent `Cache-Control: no-store`
  requests. Their per-reaction totals and visible comments can be newer than a
  cached card snapshot.
- Reaction or comment mutations do not optimistically rewrite a cached public
  article. A later authoritative article refresh may replace the snapshot.
- Account-scoped saved-article responses may carry the same public snapshot,
  but the values must not vary by viewer.

## 3. Interface and accessibility

- A quiet divider and two textual metrics form the SportsHub “match pulse” at
  the bottom of standard and leading article cards.
- The metrics use localized number formatting, Dynamic Type and semantic SF
  Symbols. At accessibility sizes they stack vertically rather than truncate.
- Counts are informative, not separate buttons. The surrounding article card
  remains one navigation target with a minimum 44-point target and an “opens
  article” hint.
- The card does not include a nested share control. The existing article-detail
  share action remains the unambiguous route to the native share sheet.
- Meaning is never color-only; VoiceOver receives complete localized phrases
  such as “Reactions: 202” and “Published comments: 3.”

## 4. Validation and acceptance

- DTO tests cover exact mapping, a missing rolling-deployment field, negative
  values, overflow values and corrupt persisted snapshots.
- Remote-provider tests prove malformed engagement data fails before entering
  the public cache.
- Mock fixtures keep the card snapshot consistent with the initial mock
  reaction totals and moderated comment catalog.
- A UI journey asserts that the English card accessibility label exposes both
  public counts while retaining the existing article navigation flow.
- Windows static checks can verify source structure, localization parity and
  OpenAPI shape only. Xcode compilation, XCTest, VoiceOver, RTL and rendered
  Dynamic Type inspection remain Apple-platform gates.
