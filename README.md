# Loic Engineer Portfolio

## Overview

This repository contains the source and generated output for `https://loic.engineer`.

The site is:
- static-first
- bilingual from day one (`/` in English, `/fr/` in French)
- deployable on GitHub Pages
- privacy-friendly by default
- intentionally lightweight at runtime

The current iteration replaces the earlier single-page Bootstrap portfolio with a
multi-page Apple-inspired editorial experience built from local source files.

## Stack

Shipped website:
- HTML5
- CSS custom properties and modern layout primitives
- vanilla JavaScript ES modules
- SVG assets

Build tooling:
- Swift toolchain and Swift Package Manager

There are no required external package dependencies for the current build.

## Architecture

Core source files:
- `Package.swift`: Swift package manifest for the local generator
- `Sources/SiteBuilder/Resources/site.json`: bilingual content, localized routes, metadata, and content model
- `Sources/SiteBuilder/SiteModels.swift`: typed content loading
- `Sources/SiteBuilder/SiteRenderer.swift`: shared renderers for pages, navigation, footer, and SEO tags
- `Sources/SiteBuilder/main.swift`: generates static HTML files and `sitemap.xml`
- `Sources/SiteServer/main.swift`: local Swift static file server for browser previews
- `css/tokens.css`: design tokens, themes, and motion settings
- `css/site.css`: layout, components, responsive rules, and page styling
- `js/site.js`: appearance switching, reveal behavior, and homepage story activation

Generated output:
- `index.html`
- `404.html`
- `fr/**/index.html`
- `work/index.html`
- `projects/index.html`
- `writing/index.html`
- `library/index.html`
- `about/index.html`
- `sitemap.xml`

Detailed notes:
- `docs/ARCHITECTURE.md`

## Local Development

Rebuild the site:

```bash
swift run SiteBuilder
```

Compile the generator:

```bash
swift build
```

Serve locally:

```bash
swift run SiteServer
```

The local server also serves the root `404.html` for missing routes, so broken
link recovery can be previewed locally.

If port `8080` is already in use:

```bash
swift run SiteServer --port 8081
```

Open:

`http://localhost:8080` or the port you passed to `--port`

## Product Scope In V1

The v1 architecture includes:
- homepage storytelling focused on current professional work
- work, projects, writing, library, and about pages
- English and French localization
- light, dark, and auto appearance modes
- structured static education section on the work page
- structured static surfaces for writing themes, reading shelves, sports, and trophy curation
- manual-first content architecture for sections where personal data is still being curated

The following remain intentionally static and manual for now:
- books and reading stats
- sports profile
- trophy case
- contact via `mailto:`

## Deployment

The generated site is plain static output and can be hosted directly on GitHub
Pages.

If a future feature truly requires live processing, the preferred escalation
path is:
1. keep the public site static
2. add the smallest possible optional runtime
3. isolate it behind a clearly bounded integration
