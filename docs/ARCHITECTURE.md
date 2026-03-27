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
- `/projects/roole-map/`
- `/projects/roole-premium/`
- `/projects/vialife-digital/`
- `/projects/myviapresse/`
- `/projects/digital-press-applications/`
- `/projects/dakar-presse/`
- `/projects/le-moniteur-des-pharmacies/`
- `/projects/le-point-veterinaire/`
- `/projects/loic-engineer/`
- `/projects/templated-mobile-starter/`
- `/writing/`
- `/library/`
- `/about/`

French routes:
- `/fr/`
- `/fr/work/`
- `/fr/projects/`
- `/fr/projects/roole-map/`
- `/fr/projects/roole-premium/`
- `/fr/projects/vialife-digital/`
- `/fr/projects/myviapresse/`
- `/fr/projects/digital-press-applications/`
- `/fr/projects/dakar-presse/`
- `/fr/projects/le-moniteur-des-pharmacies/`
- `/fr/projects/le-point-veterinaire/`
- `/fr/projects/loic-engineer/`
- `/fr/projects/templated-mobile-starter/`
- `/fr/writing/`
- `/fr/library/`
- `/fr/about/`

## Rendering Model

The repo keeps source files and generated output together.

Rendering flow:
1. `swift run SiteBuilder` launches the local Swift package executable.
2. `Sources/SiteBuilder/Resources/site.json` provides localized routes, page metadata, and page data.
3. `Sources/SiteBuilder/SiteModels.swift` decodes the content into typed Swift structures.
4. `Sources/SiteBuilder/SiteRenderer.swift` renders complete HTML documents for each page, locale, and project detail route.
5. `Sources/SiteBuilder/main.swift` writes generated `index.html` files into the route folders and regenerates `sitemap.xml`, localized Atom feeds, and `robots.txt`.
6. `swift run SiteServer` can serve the generated output locally for browser previews without Ruby, Node, or Python, including the root `404.html` on missing routes.
7. `404.html` provides a static fallback page with localized recovery links for missing routes.

This keeps the shipped site fully static while avoiding duplicated hand-written
HTML for every locale and page combination.

The earlier Bootstrap, vendor, and JSON-driven single-page asset tree is no
longer part of the active architecture.

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
- `assets/img/og/og-default.svg`
  Shared Open Graph image and SVG favicon.

## Active Asset Surface

The generated site currently depends on only four shared frontend assets:
- `css/tokens.css`
- `css/site.css`
- `js/site.js`
- `assets/img/og/og-default.svg`

In addition to HTML pages, the generator also produces:
- `sitemap.xml`
- `robots.txt`
- `feed.xml`
- `fr/feed.xml`

If a new asset is added, it should have a clear purpose in the generated site.
Do not reintroduce unused vendor bundles or archive-era media into the runtime
path.

## Localization Strategy

Localization is URL-linked, not dynamically swapped inside a single canonical
URL. This is intentional because it is better for:
- SEO and indexing
- sharing exact localized pages
- predictable browser history
- language-specific metadata and `hreflang`

The locale switcher simply moves users to the equivalent route in the other
language.

Localized project detail pages use the same English slugs in both locales, for
example `/projects/roole-map/` and `/fr/projects/roole-map/`.

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

The writing area now also has:
- a dedicated archive surface on the `/writing/` and `/fr/writing/` pages
- localized empty-state handling for when no public essays are available yet
- future-ready article detail support in the generator via localized `writing_details`
  content blocks and route keys

The library area now also has:
- a dedicated archive surface on the `/library/` and `/fr/library/` pages
- localized empty-state handling for when no public books are listed yet
- future-ready book detail support in the generator via localized `library_details`
  content blocks and route keys

The about page now treats sports and trophies as archive surfaces instead of
simple placeholder cards:
- sports has a public archive layer plus a separate system/curation layer
- trophies has a public archive layer plus a separate system/curation layer
- both sections launch with localized empty states until curated public entries
  are ready

Structured metadata is now page-type aware:
- the homepage emits `ProfilePage`
- section indexes emit `CollectionPage` or `AboutPage` depending on purpose
- project detail pages emit `CreativeWork`
- writing pages also emit `Blog`
- non-home pages emit `BreadcrumbList`

## Validation

The Swift package now includes automated tests for:
- route coverage across locales
- generator support outputs such as feeds, sitemap, and `robots.txt`
- structured-data regression checks for major page types

Run them with:
- `swift test --package-path /Users/loki/Developer/portfolio`

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
