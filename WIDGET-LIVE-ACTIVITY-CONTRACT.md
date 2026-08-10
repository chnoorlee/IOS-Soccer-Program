# Widget and Live Activity contract

Status: implementation contract for the iOS 17 scaffold. This document does not
claim App Store signing, a physical-device run, or remote ActivityKit delivery.

## Product job

An Arabic-first supporter should understand the most relevant followed match in
under two seconds, then open the exact match center with one tap. The Lock Screen
Live Activity is an explicit, per-match opt-in; it is never started silently.

## Next-match selection

1. Only fixtures matching a followed team or competition are eligible.
2. `live` ranks before `halfTime`; both rank before `upcoming`.
3. Ties use kickoff ascending and then the stable fixture identifier.
4. Finished, postponed, and cancelled fixtures are not retained as the next match.
5. No matching follow or eligible fixture clears the shared snapshot. The widget
   must show an honest empty state and must never substitute an unrelated or
   fictional fixture.
6. This scaffold selects from the latest fully accepted Home-feed fixture set; it
   does not claim a separate background scan of every provider competition.

## Shared snapshot boundary

- The app writes a versioned JSON file in the App Group container and asks
  WidgetKit to reload `NextMatchWidget` only after a successful write or clear.
- The payload contains only public fixture data: fixture identifier, bilingual
  team and competition names, kickoff, state, score, minute, selected language,
  demo provenance, revision, and save time.
- Account identifiers, follow lists, auth tokens, device tokens, URLs from the
  server, and personal settings are forbidden in the shared payload.
- Identifiers and text are length-bounded. The shared file is capped at 16 KiB;
  score pairs and state-dependent fields are validated again while decoding so a
  malformed file fails closed.
- The widget deep link is constructed locally as
  `sportshub://fixtures/{validated-fixture-id}`.
- A live or half-time snapshot older than 15 minutes is labelled as needing an
  app refresh. An upcoming snapshot is stale after 24 hours or 15 minutes after
  kickoff. The widget does not imply continuing background delivery.
- Demo-backed content is visibly labelled in every non-placeholder presentation.

## Live Activity lifecycle

- The user starts or stops the activity from the match center. Starting is
  allowed for live/half-time fixtures and upcoming fixtures within four hours.
  This reserves the other half of ActivityKit's eight-hour active lifetime for
  delay, regulation time, extra time, and penalties.
- Starting is rejected when Live Activities are disabled, the fixture is
  terminal, the provider still says upcoming more than 15 minutes after kickoff,
  or kickoff is too far away. A duplicate activity for the same fixture is reused
  and updated rather than requested again.
- The app requests local updates with `pushType: nil`. It stores no push token and
  makes no remote-update claim.
- Each accepted match snapshot updates score, minute, status, demo provenance,
  stale date, and relevance. The system stale state is also rendered as visible
  text and included in the accessibility label. Unchanged content is not resent.
- Finished fixtures end with final content and a one-hour Lock Screen dismissal
  window. A fixture rescheduled outside the four-hour window, postponed/cancelled
  fixtures, and explicit user stops dismiss immediately. Invalid terminal content
  is never preserved as a final score; the activity instead ends immediately.
- The Activity payload is bounded well below ActivityKit's 4 KB dynamic-content
  limit and contains the same public-data subset as the widget.
- Local updates run only while that match-center screen is open in the foreground.
  Without an ActivityKit push backend, leaving the screen can make the activity
  stale. Upcoming content is marked stale after 15 minutes without a successful
  foreground verification. The match-center control states this limitation.

## Layout and accessibility

```text
small / rectangular                 medium / Lock Screen
+----------------------+           +--------------------------------+
| competition   status |           | competition       demo/status  |
| HOME            AWAY |           | HOME | score or time | AWAY    |
|        score/time    |           |      updated / refresh state   |
+----------------------+           +--------------------------------+
```

- Semantic text styles and monospaced digits are used; fixed-size body text is
  avoided. Truncation preserves the central score/status and never removes both
  team names.
- RTL/LTR follows the saved app language. Decorative symbols are hidden from
  assistive technology.
- Each compact surface exposes one complete accessibility label containing the
  competition, both teams, score or kickoff, state, demo flag, and stale warning.
- Match-center controls retain a minimum 44-point target, expose busy/selected
  state, and announce actionable failure text rather than color alone.

## Deferred production gates

- Replace `com.example.*` and the placeholder App Group with identifiers owned by
  the Apple Developer account, then regenerate signing profiles for both targets.
- Implement ActivityKit push-to-start/update tokens and the APNs/server lifecycle.
- Validate on physical devices: Lock Screen, all Dynamic Island presentations,
  StandBy, VoiceOver, Arabic RTL, Dynamic Type, stale transitions, and external
  dismissal.
