# Arabic-first global search contract

## Purpose

This slice makes Explore search usable as a first-class Arabic and English discovery surface for articles, videos, teams, players, and competitions. It defines matching, provider ordering, client filtering, asynchronous state, and accessibility without inventing popularity, personalization, or relevance scores.

## Evidence boundary

- The supplied reference screenshots expose prominent search entry points inside dense sports-news, video, match, and team surfaces.
- The referenced GOAT App Store listing publicly describes the five searchable content families already represented by this repository: news, video, teams and players, competitions, and match-related coverage.
- Neither the screenshots nor the public listing disclose a private search-ranking algorithm.
- `GET /search` is therefore the only source of truth for remote result membership and relevance order. The client may filter that ordered response by type, but never reranks it.

## Query contract

1. The client trims leading and trailing whitespace and sends the remaining user text unchanged as UTF-8.
2. A query must contain 2 through 100 Swift `Character` values after trimming. Shorter queries stay local; longer queries fail before network access.
3. The remote service owns matching. It must compare localized titles, aliases, and approved searchable copy using Unicode-normalized text.
4. The repository mock uses the deterministic normalization below so Arabic demo behavior is reproducible. It is a matching rule, not a relevance algorithm:
   - compatibility decomposition plus case- and diacritic-insensitive folding;
   - remove Arabic tatweel and Arabic combining marks;
   - map `أ`, `إ`, and `آ` to `ا`;
   - map `ى` to `ي`;
   - collapse internal whitespace and trim the result.
5. Arabic letter normalization must not transliterate between Arabic and Latin scripts, conflate `ة` with `ه`, or mutate the original query shown to the user.
6. A normalized query that contains fewer than two characters returns no mock results.
7. Mock relevance is deterministic and documented: exact primary title or alias, then primary prefix, then primary substring, then supporting-copy substring. Ties keep canonical mock catalog order.

## Response and ordering

1. Each response item has exactly one supported type and one non-empty, validated entity ID.
2. The combination of type and entity ID is unique within a response page.
3. A page contains at most 100 items. An oversized or duplicate response fails closed before caching or presentation.
4. Array order is the complete remote relevance contract. The client preserves it exactly in the All scope.
5. Type scopes use a stable canonical control order: All, Articles, Videos, Teams, Players, Competitions. Scopes with zero loaded results are omitted, except All.
6. Filtering by a type preserves the relative provider order of matching results. Changing a scope never performs local relevance sorting.
7. The displayed number is explicitly the count of results loaded in the current response, not a claimed total across all cursor pages.
8. Result titles, subtitles, entity IDs, and types remain unchanged by the presentation layer.
9. `hasMore: true` requires a non-empty result page and a non-empty cursor. `hasMore: false` requires a null cursor, even though this client slice does not yet request subsequent pages.
10. Search has no stale/demo provenance banner in this slice, so a remote failure must not silently return an offline snapshot or fictional Mock hits. It fails into the visible retry state instead. Explicit all-Mock builds remain visibly governed by the app-wide demo boundary.

## Interaction and asynchronous state

1. Search waits 350 milliseconds after an edit before issuing a request.
2. Every request receives a local identity. Only the latest identity whose query still matches the visible trimmed query may update results, loading state, error state, or VoiceOver status.
3. Editing the query resets the selected scope to All.
4. A retry repeats only the current search request; it does not reload unrelated Explore categories.
5. Loading, too-short, empty, error, and populated states are mutually exclusive.
6. The first remote page is requested with `limit=100`. Cursor pagination remains an explicit follow-up; the interface must not imply that the loaded count is a global total.

## Layout and accessibility

- A compact scoreboard-style summary shows the original visible query and the loaded-result count.
- Type scopes are text-and-icon buttons with a selected trait, stable identifiers, and a minimum 44-point target.
- Regular Dynamic Type uses a horizontal scope rail. Accessibility Dynamic Type uses full-width vertical controls.
- Search result rows expose localized title, optional subtitle, and localized result type. Type is never communicated by icon or color alone.
- A completed current search announces its loaded-result count to VoiceOver. A failed current search moves accessibility focus to its error state.
- Arabic and English localization key sets remain identical, and layout uses leading/trailing semantics rather than fixed left/right assumptions.

## Deferred until evidence exists

- Personalized ranking, trending queries, popularity badges, recent-query history, typo suggestions, transliteration, and autocomplete require separate product and privacy contracts.
- Full cursor pagination requires a page-aware domain API and a visible load-more state.
- Search artwork requires licensed media metadata; SF Symbols remain the fallback.
- Backend ranking quality, latency, and Arabic recall require a working service and production query corpus. Static repository validation cannot prove them.
