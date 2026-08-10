# Public Sharing and Deep-Link Contract

Status: frozen for the current native iOS slice.

This contract defines how SportsHub creates public share links and accepts links
that request in-app navigation. Link handling is a security and trust boundary:
an arbitrary URL must never become an arbitrary network request or navigation
destination.

## 1. Supported routes

The canonical route grammar is exactly one entity collection followed by one ID:

- `/fixtures/{id}`
- `/articles/{id}`
- `/videos/{id}`
- `/teams/{id}`
- `/players/{id}`
- `/competitions/{id}`

Fixture routes open the Matches tab. All other supported routes open Explore.
The destination replaces that tab's current deep-link path so a newly received
link cannot be hidden behind stale navigation state.

## 2. Identifier rules

An ID is 1 through 128 user-perceived characters and contains only Unicode
letters/numbers or the unreserved ASCII characters `-._~`. The standalone values
`.` and `..` are forbidden. Whitespace, control characters, path separators,
backslashes, query/fragment delimiters and percent signs after one decoding pass
are forbidden.

Percent-encoded Unicode is accepted only when it decodes to a valid ID. Encoded
slashes, traversal segments, double encoding, empty components, duplicate
slashes and trailing slashes are rejected.

## 3. HTTPS public links

The public base URL comes from `SportsPublicWebBaseURL`. It is intentionally
empty in the repository and is valid only when it has:

- the `https` scheme;
- an explicit host controlled by the publisher;
- no user information, query or fragment;
- no non-default port;
- zero or more valid, canonical base-path components;
- no trailing slash except the origin root.

An incoming HTTPS link must match the configured scheme, host, port and base path
exactly. Query items and fragments are rejected; this slice does not add tracking
parameters. When no public base is configured, no HTTPS host is trusted and the
app emits no fabricated public URL.

`applinks:` entitlements, the AASA file, web previews and App Store fallback are
release gates owned by the eventual production domain. Source support for an
HTTPS route is not evidence that those external pieces are deployed.

## 4. Custom scheme

`sportshub://{collection}/{id}` is accepted as an installed-app routing fallback
and for deterministic UI tests. It uses the same collection and ID validation.
The custom scheme is never emitted as a public share link because recipients
without the app would reach a dead end.

## 5. Runtime behavior

- A valid link received before onboarding completes is queued; it cannot bypass
  language/team selection.
- The newest valid link replaces an older unconsumed link.
- Unsupported or malformed links fail closed and produce a localized alert after
  the main interface is available.
- Once consumed, a link is removed so view refreshes cannot push it twice.
- A syntactically valid route whose entity is absent uses the destination's
  existing not-found/error and retry behavior. It does not fall back to a
  different entity or mock a result.
- Links contain only public entity IDs. Account IDs, tokens, playback URLs,
  notification tokens, local history and other personal state are never included.

## 6. Sharing behavior

Match, article, video, team, player and competition detail screens use the native
iOS share control with a 44-point target and an explicit VoiceOver label/hint.
When a validated public base exists, they share the canonical HTTPS URL. Until
then they share localized public text only. This preserves a useful action
without claiming a deployable link that does not exist.

## 7. Acceptance evidence

- Unit tests cover every route round trip for HTTPS and custom scheme links.
- Boundary tests reject untrusted hosts, HTTP, credentials, ports, query,
  fragments, unknown/extra/missing paths, traversal, encoded slash, double
  encoding, whitespace, duplicate/trailing slash and overlong IDs.
- Coordinator tests cover queue/consume, newest-wins and invalid-link error state.
- A UI journey seeds a custom-scheme fixture route before onboarding and verifies
  that onboarding still completes before Match Center opens.
- macOS/Xcode remains required to execute XCTest, verify the native share sheet,
  test VoiceOver focus and validate real Universal Links against AASA.
