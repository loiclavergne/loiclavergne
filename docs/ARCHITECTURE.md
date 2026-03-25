# Architecture Notes

## Current Direction

The site has been redesigned as a bilingual, static-first portfolio with a
present-first information architecture:
- current role and current work lead the experience
- deeper pages expand into projects, writing, books, sports, and profile details
- localization is URL-based instead of client-only

English routes:
- `/`
- `/work/`
- `/projects/`
- `/writing/`
- `/library/`
- `/about/`

French routes:
- `/fr/`
- `/fr/work/`
- `/fr/projects/`
- `/fr/writing/`
- `/fr/library/`
- `/fr/about/`

## Rendering Model

The repo keeps source files and generated output together.

Rendering flow:
1. `swift run SiteBuilder` launches the local Swift package executable.
2. `Sources/SiteBuilder/Resources/site.json` provides localized routes, page metadata, and page data.
3. `Sources/SiteBuilder/SiteModels.swift` decodes the content into typed Swift structures.
4. `Sources/SiteBuilder/SiteRenderer.swift` renders complete HTML documents for each page and locale.
5. `Sources/SiteBuilder/main.swift` writes generated `index.html` files into the route folders and regenerates `sitemap.xml`.
6. `swift run SiteServer` can serve the generated output locally for browser previews without Ruby, Node, or Python, including the root `404.html` on missing routes.
7. `404.html` provides a static fallback page with localized recovery links for missing routes.

This keeps the shipped site fully static while avoiding duplicated hand-written
HTML for every locale and page combination.

## Source Layout

- `Package.swift`
  Swift package manifest for the site generator.
- `Sources/SiteBuilder/Resources/site.json`
  Source of truth for localized copy, navigation labels, route definitions,
  social links, and public metadata.
- `Sources/SiteBuilder/SiteModels.swift`
  Typed content loading.
- `Sources/SiteBuilder/SiteRenderer.swift`
  HTML renderers for navigation, footer, shared document shell, and each page.
- `Sources/SiteBuilder/main.swift`
  Site generation entry point.
- `Sources/SiteServer/main.swift`
  Local Swift static file server for development previews.
- `css/tokens.css`
  Theme tokens, spacing scale, radii, shadows, motion durations.
- `css/site.css`
  Component and page styling.
- `js/site.js`
  Theme controls, reveal observer, and homepage story state.

## Localization Strategy

Localization is URL-linked, not dynamically swapped inside a single canonical
URL. This is intentional because it is better for:
- SEO and indexing
- sharing exact localized pages
- predictable browser history
- language-specific metadata and `hreflang`

The locale switcher simply moves users to the equivalent route in the other
language.

## Appearance And Motion

The UI follows system appearance by default and exposes a manual toggle for:
- auto
- light
- dark

The homepage uses progressive enhancement for reveal behavior and a
scroll-activated narrative panel. Core content remains fully readable with
JavaScript disabled and motion reduced.

## Secondary Sections

The education, writing, library, sports, and trophy areas are now modeled as
structured static content rather than single placeholder paragraphs.

This matters because:
- the site can present these areas as real product surfaces before live data exists
- future content can be added by editing localized JSON without changing the renderer
- the architecture stays static-first while leaving room for richer manual curation

## Why No Framework

The current build avoids frontend and build-time package dependencies because:
- the content model is finite and well understood
- the public output should remain extremely lightweight
- GitHub Pages compatibility matters
- the project benefits more from strict control than from a generic framework

If complexity grows later, the next step should still preserve static output and
privacy-first delivery.

## Known Content Gaps

The architecture is ready for these sections, but the detailed content still
needs a later pass:
- formal education institutions, degrees, and dates
- real books and reading counts
- actual sports activities and milestones
- trophy case selections
- final public contact email
