# Article Reactions and Safe Community Contract

Status: frozen for the current native iOS slice.

This contract adds the article interaction surface visible in the reference
products without cloning their branding or shipping an unsafe generic social
feed. It follows Apple App Review Guideline 1.2: filtering, reporting, blocking
and published contact information are one release gate, not independent future
enhancements.

## 1. Scope and release gate

- Article detail shows reaction totals and a newest-first, flat list of
  server-moderated comments.
- Authenticated accounts may add or replace one reaction, remove it, submit one
  text comment, report a published comment and block its author.
- Anonymous users may read the moderated surface. They cannot mutate it.
- Direct messages, anonymous chat, replies, media upload, profile discovery and
  follower graphs are explicitly excluded.
- Community mutations are enabled only when `SportsCommunityEnabled` is true,
  account authentication is available, and valid publisher-controlled HTTPS
  URLs exist for both community standards and support/contact. The checked-in
  development configuration remains disabled.
- Source completeness is not production readiness. Release still requires a
  deployed moderation queue, tested response SLA, staffed escalation path,
  production URLs and App Review evidence.

## 2. Read contract

- `GET /articles/{articleId}/comments?limit=20&cursor=...` returns at most 20
  comments and `PageInfo`. It always uses `Cache-Control: no-store`; an optional
  Bearer token lets the server remove blocked authors and mark the caller's own
  comments.
- Public pages contain only `PUBLISHED` comments. `PENDING`, `REJECTED` and
  `REMOVED` bodies are never exposed by this endpoint.
- Every comment echoes `articleId`, uses an opaque `authorId`, has a non-empty
  display name and body, and includes `isMine` plus `createdAt`.
- IDs are unique across loaded pages. `hasMore`, `nextCursor`, page size and
  cursor progress are validated before UI state changes.
- `GET /articles/{articleId}/reaction` is also uncached and optionally
  authenticated. It returns non-negative totals for exactly `LIKE`,
  `INSIGHTFUL` and `CELEBRATE`; `myReaction` is null while signed out.
- Community reads never enter the public ETag/offline cache and never cross the
  remote-to-Mock fallback boundary. A network failure produces an explicit
  unavailable state rather than fictional user speech.

## 3. Mutation contract

- `PUT /articles/{articleId}/reaction` creates or replaces the caller's single
  reaction. `DELETE` removes it. Both are idempotent and return the confirmed
  reaction summary; DELETE therefore returns 200 rather than a bodyless 204.
- `POST /articles/{articleId}/comments` accepts one normalized body of 1...500
  Unicode characters and returns the authoritative moderation state. It never
  publishes optimistically.
- A `PENDING` response is shown only to its author as a submission receipt. A
  `PUBLISHED` response may enter the visible list. A `REJECTED` response never
  exposes moderation internals or inserts content into the public list.
- `POST /community/comments/{commentId}/reports` accepts one stable reason:
  `HARASSMENT`, `HATE`, `SPAM`, `MISINFORMATION` or `OTHER`, plus optional
  details of at most 500 characters. It returns a `RECEIVED` receipt and does
  not promise immediate removal.
- `PUT /me/community-blocks/{authorId}` blocks an author and returns 204. After
  confirmation, that author's loaded comments are removed locally; the server
  filters future pages. Blocking one's own author identity is rejected.
- Every POST/PUT mutation carries a fresh idempotency key, Bearer authorization,
  JSON content type where applicable and `Cache-Control: no-store`.

## 4. Filtering and moderation

- The client trims surrounding whitespace, rejects blank/control-only input and
  enforces size limits before networking. This is input hygiene, not the
  objectionable-content filter.
- Server-side filtering and moderation remain authoritative. A harmful or
  otherwise unacceptable submission uses a stable problem code with HTTP 422;
  the client shows safe localized guidance without echoing internal rules.
- Report submission is retained as a confirmed receipt in the current view so
  repeat taps do not create duplicate reports.
- Report and block controls are absent for the caller's own comments. They are
  available from a native menu with textual labels, not color-only affordances.
- The client does not infer that a report is resolved, a user is abusive or a
  comment is unlawful.

## 5. Identity and concurrency

- Signed-out reads use the anonymous provider. Signed-in reads use the
  authenticated provider so server-side blocks and `isMine` are honored.
- All mutations fail closed without the same active account identity that
  initiated them. Guest-device storage never contains comments, reactions,
  reports or blocks.
- Authentication changes invalidate in-flight community reads and mutations;
  a stale response cannot overwrite the new identity's state.
- One reaction mutation, comment submission, report or block for the same UI
  element runs at a time. Confirmed prior state is retained on failure.

## 6. Interface and accessibility

- The surface is a compact “supporters' touchline”: three reaction buttons above
  a vertical commentary rail. It remains subordinate to the article itself and
  does not become an infinite social feed.
- All actionable targets are at least 44 points. Reaction controls expose type,
  selected state and count to VoiceOver; selection is conveyed by icon, text and
  trait in addition to color.
- The composer has a persistent label, 500-character counter, submission
  progress and explicit moderation notice. It is not represented by placeholder
  text alone.
- Load, empty, disabled, pending, rejected and mutation-failure states use
  localized text and symbols. VoiceOver focus moves to newly presented errors
  and submission receipts.
- Comment author, relative time and body preserve Dynamic Type, RTL layout and
  text selection. The report/block menu has deterministic accessibility IDs.
- Community standards and support/contact are visible before composition whenever
  valid configuration exists; otherwise the disabled development boundary is
  stated plainly.

## 7. Acceptance evidence

- DTO tests cover valid pages, optional reaction identity, all moderation
  states, exact reaction keys, duplicate IDs, bad cursors, unsafe IDs, oversized
  text and negative totals.
- Remote-provider tests cover anonymous/authenticated uncached reads, all exact
  paths and methods, authorization, idempotency, payloads, 200/201/204 handling
  and fail-before-network validation.
- Routing tests prove that signed-out mutation is unauthorized and that
  community data cannot use Mock fallback after a remote error.
- Mock tests cover reaction replacement/removal, pending comment submission,
  report receipts and author blocking without fabricating production proof.
- A UI journey covers the read-only moderated surface and the disabled release
  gate. Authenticated mutation journeys remain a macOS/Xcode plus deployed-test-
  backend requirement.
- Windows static validation may establish source syntax, localization parity,
  plist/project/OpenAPI structure and test presence only. It cannot establish
  compilation, XCTest, VoiceOver, RTL, backend moderation or App Store approval.
