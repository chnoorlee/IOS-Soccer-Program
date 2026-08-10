# Video Poster Media Contract

Status: frozen for the current native iOS slice.

This contract covers the cover-led video discovery task directly evidenced in
the public SEC Sports screenshots and supported by the current Apple product
description. SportsHub keeps its own broadcast-aperture framing, palette,
typography and information hierarchy. It does not copy SEC photography,
branding, programme art, crops, ranking algorithm or private delivery fields.

## 1. Product scope

- `VideoSummary.poster` and `VideoDetail.poster` are the only new media fields.
  They identify a video before playback; they are not the video stream, a
  preview clip, an autoplay surface or proof that playback is available.
- Current API responses include `poster` explicitly as one object or `null`.
  Rolling-deployment clients tolerate omission and show SportsHub's original
  type-based artwork.
- Posters may appear in discovery, trending, generic video cards and video
  detail. A missing, expired, failed or disallowed image never hides the title,
  duration, type, availability, progress or editorial context.
- Posters do not affect featured/trending order, recommendation, search rank,
  favorite state, watch progress or `isPlayable`.

## 2. Rights and playback boundary

- The upstream publisher/CMS may include a poster only after verifying display
  rights for the requested market and retention window. The client cannot prove
  a licence from a URL and never labels an image "licensed."
- Every poster has a stable asset ID, direct public HTTPS URL, exact MIME type,
  encoded dimensions, bilingual image-specific alternative text and bilingual
  visible credit. The client never infers these values from the title, video
  publisher, URL, programme or reference apps.
- Poster display rights do not grant video playback rights. Playback still
  requires the existing `isPlayable`/availability contract followed by a
  short-lived playback session; no media URL is added to this object.
- Mock videos contain no third-party URL, photograph or frame. Their original
  SwiftUI artwork remains explicitly fictional and non-playable.

## 3. URL and response safety

- DTO validation requires HTTPS, a non-empty host/path, no credentials,
  fragment or custom port, and at most 2,048 URL characters. Signed publisher
  query values are preserved but never logged or retained in personal video
  state.
- Loading requires an exact lowercased host in `SportsMediaAllowedHosts`; an
  empty list fails closed, and wildcard/suffix matching is forbidden.
- The shared public-image session sends no Bearer token, cookies, account ID or
  client-added tracking parameters, disables credential storage and rejects
  redirects. HTTP 200, exact declared MIME, a non-empty body and an 8 MiB
  streaming cap are mandatory.
- JPEG, PNG, WebP, HEIC and HEIF are accepted. Width must be 640...4,096
  pixels, height 360...4,096 pixels, with at most 16 megapixels and a
  1.2...2.4 aspect ratio. ImageIO verifies body type and dimensions before
  creating a presentation-sized thumbnail, allowing orientation to swap width
  and height.

## 4. Original layout and accessibility

- The palette remains SportsHub deep ink `#0D1A33`, signal cyan `#057385`, warm
  timing gold `#A1660D` and live red `#D62940`, with system backgrounds and
  labels. The signature is the existing broadcast aperture and signal rail,
  not SEC's neon-green identity.
- The standard card uses a quiet 16:9 aperture above its title. The featured
  card keeps readable metadata over a restrained bottom scrim. Trending gains
  a compact thumbnail beside the truthful editorial rank. Detail uses the
  largest aperture and shows a visible localized credit after a successful
  load.
- Card and trending posters are decorative because their parent navigation
  targets already announce title, type, duration and availability. Detail
  exposes localized alternative text; a failure exposes a localized status and
  a native retry control with at least a 44-point target.
- Loading decoration is hidden from VoiceOver. There is no autoplay, shimmer,
  flashing or mandatory animation. Logical alignment and native Dynamic Type
  keep Arabic RTL and accessibility sizes intact.

## 5. Persistence and cache boundary

- Public API response caches may retain validated poster metadata. Image bytes
  use only their public CDN cache headers and remain independent of JSON cache
  freshness.
- Personal favorite/history/continue-watching snapshots omit `poster`, its
  signed URL and credit. The personal store strips this metadata before keeping
  either its in-memory or on-disk snapshot. A saved video renders fallback
  artwork until a fresh public response supplies current media.
- New public responses may replace or remove an asset. Loading identity uses the
  complete validated poster value rather than only the video ID.

## 6. Acceptance

- DTO/model tests cover mapping, object/null/missing migration, URL, MIME,
  dimensions, pixels, aspect ratio and bilingual text limits.
- Persistence tests prove encoded personal video models contain no poster URL,
  the live personal store immediately holds poster-free values, and old
  snapshots decode with `poster == nil`.
- Remote tests prove valid list/detail posters map exactly and malformed media
  fails before a public response enters the cache.
- Shared loader tests continue to cover exact-host allowlisting, redirect
  rejection, status, MIME, streaming byte limits, body type, dimensions and
  presentation downsampling for both article and video media.
- UI-test source checks the detail poster state and retry identifiers while Mock
  mode continues to render original artwork without claiming a load failure.
- Windows checks cover source structure, localization parity, plist shape,
  Swift syntax trees and OpenAPI validity only. Xcode compilation, XCTest,
  ImageIO/UIKit rendering, CDN behavior, RTL, Dynamic Type and VoiceOver remain
  Apple-platform gates.
