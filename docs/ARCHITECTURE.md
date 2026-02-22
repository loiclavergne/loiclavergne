# Architecture Notes

## Rendering Flow
1. `js/main.js` boots the page (`initPage`).
2. `assets/data.json` is fetched and parsed.
3. Each section renderer injects HTML into static containers in `index.html`.
4. `refreshAppearance()` applies saved light/dark/auto mode.
5. `initAnimations()` binds observers and interaction handlers.

## Data Ownership
- `assets/data.json` is the single source of truth for:
  - greeting text + keyword ticker
  - intro/timeline entries
  - skills and projects cards
  - social links

This keeps content changes separate from UI logic.

## UI Systems
- Appearance (`js/appearance.js`)
  - preference persistence (`localStorage`)
  - system-mode support (`prefers-color-scheme`)
  - contrast and surface token tuning via CSS variables
- Motion (`js/animations.js`)
  - reveal animations with `IntersectionObserver`
  - expandable tile overlay transitions
  - responsive navbar collapse behavior
- Tile templating (`js/components/Tile.js`)
  - reusable card HTML generation from JSON objects

## Styling Organization
- `css/style.css`: global shell and shared components
- `css/colors.css`: color tokens and glass surfaces
- `css/sections.css`: section-specific layout rules
- `css/tile.css`: card and overlay visuals
- `css/animations.css`: keyframe definitions
- `css/typography.css`, `css/spacing.css`, `css/links.css`: utilities

## Hosting Model
The site is fully static and can be hosted directly on GitHub Pages.
