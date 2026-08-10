# Article Hero Media Contract

Status: frozen for the current native iOS slice.

This contract covers the licensed editorial image task evidenced in the public
Koora Break and GOAT news screenshots. SportsHub uses its own framing,
placeholders and data contract. It does not copy reference photography,
branding, crops, page composition or private media-delivery fields.

## 1. Product scope

- `ArticleSummary.heroMedia` is the only media added by this slice. Video,
  galleries, infographics, remote HTML and user uploads remain separate.
- Current API responses include `heroMedia` explicitly, either as one object or
  `null`. Rolling-deployment clients tolerate an omitted field and render the
  original SportsHub category cover.
- A missing asset is not an error and does not imply that the publisher owns no
  image. A failed or disallowed request never hides the article title, summary,
  source, correction state or interaction summary.
- Hero media does not affect article ordering, recommendation, popularity,
  correction or community state.

## 2. Editorial and rights boundary

- The upstream publisher/CMS may return a hero asset only after it has verified
  publication rights for the requested market and retention window. The iOS
  client cannot prove a licence from a URL and never labels an image “licensed.”
- Every asset has a stable provider ID, direct HTTPS URL, exact MIME type,
  encoded width/height, bilingual alternative text and bilingual visible
  credit. The client does not infer a credit from the URL or article source.
- Mock articles contain no third-party URL or photo. Their category covers are
  original SwiftUI artwork and remain clearly part of the fictional demo.
- Image bytes are public and unauthenticated. Requests never carry the SportsHub
  Bearer token, cookies, account identifiers, article-favorite state or tracking
  query parameters added by the client.

## 3. URL and response safety

- DTO validation requires HTTPS, a non-empty host/path, no credentials, no
  fragment, no custom port and at most 2,048 URL characters. Signed query values
  supplied by the publisher are preserved but never logged or persisted in a
  personal article snapshot.
- Production loading additionally requires the exact lowercased host to appear
  in `SportsMediaAllowedHosts`. An empty allowlist fails closed. Wildcards and
  suffix matching are forbidden.
- The media session uses normal public HTTP caching, disables cookies and URL
  credential storage, sends no authorization header and rejects redirects.
  Responses must be HTTP 200, match
  the declared MIME type and remain at or below 8 MiB. A declared oversize
  response fails before body consumption; an unknown-length body is counted and
  stopped while streaming instead of being fully buffered first.
- Supported MIME types are JPEG, PNG, WebP, HEIC and HEIF. Metadata dimensions
  are 640...4,096 pixels per side, at most 16 megapixels, and 1.2...2.4 aspect
  ratio. ImageIO reads pixel dimensions without decoding the bitmap first;
  its source type must match the declared MIME and its dimensions must agree
  with the metadata, allowing orientation to swap width and height, before it
  creates a presentation-sized thumbnail for UIKit instead of retaining a feed
  of full-resolution bitmaps.

## 4. Layout and accessibility

- SportsHub’s original “broadcast aperture” uses a 16:9 crop, deep-ink frame,
  cyan signal rail and warm timing mark. It does not reuse the reference apps’
  black/neon-green or black/orange cards.
- Standard cards place the aperture after the headline. The leading card starts
  with it. Article detail places it after metadata and shows the visible credit
  only when the image loaded successfully.
- The whole news card remains one navigation target. Its image is decorative to
  avoid repeating title/summary content. In detail, a loaded image exposes the
  localized alternative text; the visible credit is also readable text.
- Loading indicators and decorative framing are hidden from VoiceOver. A detail
  failure exposes a localized status and a native retry button with at least a
  44-point target. No shimmer or mandatory motion is used.
- The crop uses logical layout and contains no embedded overlay text, so Arabic
  RTL does not reverse the photograph or alter reading order.

## 5. Persistence and caching

- The article JSON response and its ETag cache may contain media metadata. Image
  bytes follow the CDN response’s public cache headers and are independent from
  the JSON cache lifetime.
- Personal saved-article snapshots deliberately omit `heroMedia`, including its
  signed URL and credit. Saved cards render the category cover until a fresh
  public/account response supplies current media again.
- A new public response may replace or remove the asset. The client keys loading
  by the full validated media value, not only by article ID.

## 6. Acceptance

- Model/DTO tests cover exact mapping, null/missing migration, URL rules,
  localized text, MIME allowlist, dimensions, pixels and aspect ratio.
- Persistence tests prove encoded saved articles contain no hero URL or media
  object and old snapshots still decode with `heroMedia == nil`.
- Remote tests prove a valid list/detail asset maps exactly and invalid media is
  rejected before the article response enters the public cache.
- Loader-policy tests cover exact-host allowlisting, empty configuration,
  suffix attacks, redirects, status, MIME and byte limits.
- UI test source proves Mock mode does not announce a missing asset as a load
  failure while the existing article navigation journey remains intact.
- Windows checks prove source structure, localization parity, plist shape,
  Swift syntax trees and OpenAPI validity only. Xcode compilation, XCTest,
  decoded-image rendering, CDN cache behavior, RTL, Dynamic Type and VoiceOver
  remain Apple-platform gates.
