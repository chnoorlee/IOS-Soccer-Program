# Home news discovery contract

Date frozen: 2026-08-07

This slice translates two observable patterns from the supplied reference screenshots into an original SportsHub implementation:

- a clear first-story visual hierarchy followed by a scannable article list;
- explicit all-news/saved-news scope and category controls.

It does not copy reference branding, artwork, copy, or protected content. The supplied Koora screenshot and Apple Lookup metadata are treated as public evidence; no unobserved page or private behavior is inferred.

## Before-you-build decision

- Risk: medium. The feature is local presentation and filtering, but it touches identity-scoped saved articles.
- Main assumption: users benefit from switching between the public feed and their saved stories without leaving Home.
- Smallest useful proof: deterministic model tests plus a UI journey that filters the mock feed by a real category and opens the saved scope after saving an article.
- Do now: pure mapping, accessible controls, independent saved loading/error state, identity invalidation, localization, and static checks.
- Delay: popularity, exclusivity, editorial priority, recommendations, sport taxonomy, hero imagery, and any claim that requires new provider fields or CMS evidence.
- Amendment (2026-08-08): the generic hero-imagery delay is superseded only by the narrow, rights-bounded `ArticleSummary.heroMedia` contract in `ARTICLE-HERO-MEDIA-CONTRACT.md`. Galleries, video covers, scraping, upload/editor tooling and recommendation imagery remain delayed.

## Data truth

1. `HomeFeed.articles` is the complete source for **All news**.
2. `favoriteArticles()` is the complete source for **Saved**. Saved content is not inferred by intersecting or guessing IDs from the public feed.
3. Article order is provider order. Selecting **All categories** preserves it exactly.
4. Category choices are the stable, first-occurrence set of `categoryKey` values in the active source. The client does not invent categories that are absent from the payload.
5. A selected category is an exact `categoryKey` filter. If a refreshed source no longer contains that key, the effective selection returns to **All categories**.
6. The first visible article receives a larger card only as a presentation hierarchy. It is not labelled or described as trending, exclusive, recommended, breaking, or editor-selected unless the provider later supplies such a contract.
7. A card may show the optional viewer-neutral `engagement` snapshot defined in `ARTICLE-ENGAGEMENT-SUMMARY-CONTRACT.md`. Counts never change Provider order or create a popularity label; absence hides the row rather than displaying zero.
8. A card may show the optional publisher-authorized `heroMedia` defined in `ARTICLE-HERO-MEDIA-CONTRACT.md`. It never changes Provider order, category, first-story status or navigation identity; missing media uses the original category cover without announcing a failure.

## State and identity boundaries

- Public feed loading/failure remains the Home page state.
- Saved loading, empty, and failure states are independent. A saved request failure must not hide or fail the public feed.
- A retry replaces only the saved request state.
- An article-favorite change reloads the saved source.
- An authentication-state change invalidates in-flight public, follow, and saved requests; clears saved articles immediately; resets news scope/category to public defaults; then reloads for the new identity.
- Request IDs prevent an older guest/account response from committing after an identity switch.

## Accessibility and layout

- Scope and category choices use native buttons with a minimum 44-point target.
- Selection is conveyed by text/icon and the accessibility selected trait, never color alone.
- At accessibility Dynamic Type sizes, both scope and category controls become vertical, full-width lists. Horizontal category scrolling is limited to non-accessibility sizes.
- SwiftUI logical leading/trailing alignment provides RTL mirroring. Arabic and English keys must remain identical.
- Loading, empty, and failure states have explicit text; retry is a native button; a failed visible saved request moves accessibility focus to its error card.
- Article links retain the existing `article.card.<id>` identifiers and opening hint.
- Public counts are complete localized phrases. They are informational children of the single article link, not nested controls; accessibility sizes stack them vertically.
- Card images are decorative children of that same article link. Detail images expose localized alternative text and visible credit; only a real load failure exposes status and a 44-point retry action.

## Acceptance checks

1. Pure tests prove stable category discovery, provider-order preservation, exact filtering, invalid-selection normalization, first/rest partitioning, and saved-source independence.
2. UI-test source proves the Statistics filter leaves `article-2` visible and removes `article-1` from the active hierarchy.
3. The existing save journey proves a saved article appears in Home's Saved scope before it is removed from Following.
4. Static verification requires the contract, model, tests, identifiers, localization keys, identity invalidation, and absence of unsupported marketing labels in Home source.
5. Arabic/English localization sets, Swift AST parsing, project structure, and existing API checks remain green.
6. Swift type checking, XCTest execution, simulator layout, RTL, Dynamic Type, and VoiceOver remain macOS/Xcode gates.
7. The UI journey verifies that the English article-card label includes both mock public counts without changing the original navigation target.
8. The same journey proves Mock's intentionally missing media is not announced as an image failure.
