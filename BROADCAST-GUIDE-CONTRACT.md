# Regional Broadcast Guide Contract

This contract defines a read-only, region-aware broadcast guide for fixture lists and the
match centre. It answers where a supporter can look for an authorised telecast or audio feed;
it does not grant playback rights or create a streaming destination.

## Product and rights boundary

- Broadcast metadata is public editorial schedule data. A listing is never evidence that the
  current user owns a subscription, is physically eligible, or may play protected media.
- The client displays only Provider-supplied listings. It must not infer channels from a
  competition, team, device locale, title text, past fixtures or another region.
- No broadcast object contains a stream URL, deep link, price, purchase action or entitlement.
  Playback remains a separate, short-lived, server-authorised contract.
- Empty data is presented as "no confirmed broadcast information" rather than "not televised".
  A missing listing is not proof that no legal broadcast exists.
- Cancelled and postponed fixtures must not retain broadcast listings. A Provider must publish
  a newly confirmed schedule after a postponement.

## Data contract

- `FixtureSummary.broadcasts` is optional on the wire for backward compatibility and maps to an
  empty domain array when absent. The client writes the explicit array into new local snapshots.
- A fixture contains at most 12 listings in Provider order. Order is editorial and is preserved.
- Every listing contains:
  - a two-letter uppercase ISO-style `regionCode`;
  - non-empty Arabic and English channel names;
  - either both Arabic and English commentator names or neither;
  - an optional canonical audio language tag using the supported BCP-47 subset: a lowercase
    2...3-letter language code with an optional uppercase two-letter region (for example `ar`
    or `en-GB`).
- Channel and commentator text is trimmed, contains no control characters and is bounded to
  100 characters per locale.
- Duplicate `(regionCode, channel, commentator, audioLanguageCode)` listings are rejected after
  case- and diacritic-insensitive canonicalisation. A channel may appear more than once only for
  a genuinely distinct language or commentary feed.
- DTO violations fail before any public response is cached. Existing cache freshness and named
  demo-fallback rules apply to the containing fixture resource.

## Presentation and accessibility

- Subject: Arabic-speaking football supporters. Single job: identify the confirmed regional
  channel and commentary option before opening another authorised service.
- The match card uses a compact antenna label only when at least one listing exists. It names the
  first Provider channel and announces the number of additional options without hiding match
  state, teams, score or kickoff.
- The match-centre Summary tab contains the complete guide. The signature is a quiet "tuned
  signal rail": one teal antenna tile beside a vertical stack of channel, region, language and
  commentator text. It uses SportsHub ink, teal and warm-gold tokens without adding animation.
- Region and audio language codes are localised with the current Arabic or English `Locale` when
  Apple supplies a display name; the raw validated code remains the deterministic fallback.
- Information is never encoded by colour alone. Every row is one coherent VoiceOver element,
  visible text scales with Dynamic Type, and static metadata is not presented as a tappable card.
- Empty, cancelled and postponed states use explicit text. There is no automatic VoiceOver
  announcement because broadcast changes arrive with the normal user-initiated/foreground
  fixture refresh.

## Evidence boundary

- Mock channels and commentators are fictional and visibly part of Demo data.
- Windows static checks and Swift AST parsing do not prove Swift type checking, cached-model
  migration, Arabic RTL layout, Dynamic Type or VoiceOver behaviour.
- Real channel marks, regional schedules, subscriptions, entitlement checks and stream playback
  require a licensed Provider and legal/rights review before release.
