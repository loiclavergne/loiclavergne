# Loic Lavergne Portfolio

## Overview
This repository contains Loic Lavergne's portfolio website as a fully static site.

The site is data-driven:
- `index.html` defines the page shell and section structure.
- `assets/data.json` stores profile content (intro, timeline, skills, projects, socials).
- `js/main.js` renders content from JSON into the UI.

No build step is required.

## Stack
- HTML5
- CSS3 (modular stylesheets in `css/`)
- Vanilla JavaScript ES modules (in `js/`)
- Bootstrap 5 (local vendor files)

## Project Structure
- `index.html`: semantic layout and static containers
- `assets/data.json`: portfolio content source
- `css/`: component and system styles (`style`, `sections`, `tile`, `colors`, etc.)
- `js/`: rendering and interaction logic
- `vendor/`: Bootstrap, Bootstrap Icons, Normalize

## Key Systems
- Appearance system (`js/appearance.js`):
  - supports Light / Dark / Auto modes
  - persists preference to `localStorage`
  - updates CSS custom properties for contrast and glass surfaces
- Animation system (`js/animations.js`):
  - section entrance animations
  - mobile navbar collapse transitions
  - tile overlay open/close interactions
- Media fallback system (`js/lib.js`):
  - replaces failed images/videos with local placeholders

Detailed notes:
- `docs/ARCHITECTURE.md`

## SEO and Accessibility
- SEO metadata and social cards are declared in `index.html`.
- Structured data (`Person`) is embedded as JSON-LD in `index.html`.
- Crawl support files:
  - `robots.txt`
  - `sitemap.xml`
- Accessibility enhancements include:
  - skip link
  - semantic landmarks (`nav`, `main`, `section`, `footer`)
  - ARIA labels for interactive icon controls
  - keyboard-accessible appearance toggle and tile expand controls

## Local Development
Use a local HTTP server (required for ES modules and `fetch`):

```bash
cd /Users/loki/Developer/website
python3 -m http.server 8080
```

Open:

`http://localhost:8080`

## Hosting
This site is static and can be hosted directly on GitHub Pages.

Typical Pages setup:
1. Push repository to GitHub.
2. Open repository settings.
3. Go to Pages.
4. Set source to your branch root (`/`).
