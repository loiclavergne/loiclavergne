//
//  Tile.js
//  Loic Lavergne portfolio
//
//  Tile templating utility.
//  Converts JSON tile descriptors into HTML blocks rendered by main.js.
//

import { cdnSrcset } from "../lib.js";

/**
 * Resolve the responsive image srcset widths for a given image type.
 * @param {string | undefined} imageType
 * @returns {number[]}
 */
function getImageWidths(imageType) {
    return imageType?.includes("device") ? [800, 1200, 1600] : [400, 600, 800];
}

/**
 * Resolve the responsive image sizes attribute for a given image type.
 * @param {string | undefined} imageType
 * @returns {string}
 */
function getImageSizes(imageType) {
    return imageType?.includes("device")
        ? "(max-width: 767px) 95vw, 66vw"
        : "(max-width: 767px) 90vw, 555px";
}

/**
 * Build the inline style used for icon-only gradient tiles.
 * @param {Record<string, any>} item
 * @param {string} primaryColor
 * @param {string | undefined} secondaryColor
 * @returns {string}
 */
function getTileStyle(item, primaryColor, secondaryColor) {
    const styles = [];

    if (item.no_padding_bottom) {
        styles.push("padding-bottom:0!important;");
    }

    if (((!item.img && primaryColor) || item.tile_gradient) && primaryColor) {
        styles.push(`background: linear-gradient(155deg, ${primaryColor} 12%, ${secondaryColor ?? primaryColor} 88%);`);
    }

    return styles.join("");
}

/**
 * Build the cover content (front face) for a tile.
 * @param {Record<string, any>} item
 * @param {string | undefined} customCoverDescriptionHTML
 * @returns {string}
 */
function buildCoverContent(item, customCoverDescriptionHTML) {
    const coverTextClass = item.use_contrast_text ? "tile-contrast-text" : "";

    if (!item.img) {
        return `
          <div class="mb-2 mb-md-3 ${item.lg_size >= 6 ? "p-md-3 p-lg-5" : ""} tile-contrast-text">
            <i class="bi ${item.bootstrap_icon}" style="font-size: 5em;"></i>
            <h2>${item.cover_description}</h2>
          </div>
        `;
    }

    return `
      <div>
        <p class="lh-md ${coverTextClass}">${item.cover_description}</p>
        ${customCoverDescriptionHTML ?? ""}
      </div>
      <div>
        <img
          srcset="${cdnSrcset(item.img, getImageWidths(item.img_type))}"
          sizes="${getImageSizes(item.img_type)}"
          src="${item.img}"
          alt="${item.img_alt}"
          loading="lazy"
          decoding="async"
          fetchpriority="low"
          class="${item.img_type}"
          ${item.no_padding_bottom ? `style="height: unset; max-height:654px; margin-bottom: -2.25vw;"` : ""}
        >
      </div>
      ${item.center_image ? "<div></div>" : ""}
    `;
}

/**
 * Build the overlay body for expandable tiles.
 * @param {Record<string, any>} item
 * @returns {string}
 */
function buildOverlayContent(item) {
    if (!item.description) {
        return "";
    }

    const lines = item.description
        .split("\n")
        .map(line => `<p>${line}</p>`)
        .join("");

    return `
      <div class="tile-overlay p-4-5 p-md-5 fs-6 rounded-5 lh-md fw-kinda-bold initially-hidden d-none">
        <div class="d-flex flex-column align-items-center justify-content-center h-100 tile-contrast-text">
          <div class="overlay-content-glass">
            ${lines}
          </div>
        </div>
      </div>
    `;
}

/**
 * Build the overlay background tint used during "+" transitions.
 * @param {string} primaryColor
 * @param {string | undefined} secondaryColor
 * @returns {string}
 */
function buildOverlayBackground(primaryColor, secondaryColor) {
    return `
      <span class="tile-overlay-background rounded-5 initially-hidden"
        style="background-color: ${primaryColor};">
      </span>
    `;
}

/**
 * Build the "+" button for expandable tiles.
 * @param {Record<string, any>} item
 * @returns {string}
 */
function buildExpandButton(item) {
    if (!item.description) {
        return "";
    }

    return `
      <div class="plus-go-x-container">
        <label class="plus-go-x ${item.img ? "" : "fill-white"}">
          <input
            type="checkbox"
            aria-label="Toggle details for ${item.heading}"
            aria-expanded="false"
          >
          <div class="p-1">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" class="bi bi-plus-circle-fill" viewBox="0 0 16 16" aria-hidden="true" focusable="false">
              <path d="M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0zM8.5 4.5a.5.5 0 0 0-1 0v3h-3a.5.5 0 0 0 0 1h3v3a.5.5 0 0 0 1 0v-3h3a.5.5 0 0 0 0-1h-3v-3z" />
            </svg>
          </div>
        </label>
      </div>
    `;
}

/**
 * Build a portfolio tile from JSON content.
 * @param {Record<string, any>} item Tile data.
 * @param {string} primaryColor Main tile accent color.
 * @param {string} secondaryColor Optional gradient secondary color.
 * @param {string} customCoverDescriptionHTML Optional custom cover description block.
 * @returns {string}
 */
export function Tile(item, primaryColor, secondaryColor, customCoverDescriptionHTML) {
    const tileStyle = getTileStyle(item, primaryColor, secondaryColor);
    const headingAttributes = item.use_contrast_text
        ? `class="tile-contrast-text"`
        : (item.img ? `style="color: ${primaryColor};"` : `class="tile-contrast-text"`);

    return `
      <div class="col col-md-${item.md_size ?? "12"} col-lg-${item.lg_size ?? item.md_size ?? "12"}">
        <div
          class="tile bg-light-secondary p-4-5 p-md-5 rounded-5 h-100 d-flex flex-column justify-content-between"
          data-contrast-primary="${primaryColor}"
          data-contrast-secondary="${secondaryColor ?? primaryColor}"
          data-contrast-primary-alpha="0.56"
          data-contrast-secondary-alpha="0.34"
          ${tileStyle ? `style="${tileStyle}"` : ""}
        >
          <h5 ${headingAttributes}>
            ${item.heading}
          </h5>

          <div class="tile-content h-100 d-flex flex-column ${item.img ? "justify-content-between" : "justify-content-center"} fw-kinda-bold">
            ${buildCoverContent(item, customCoverDescriptionHTML)}
          </div>

          ${buildOverlayContent(item)}
          ${buildOverlayBackground(primaryColor, secondaryColor)}
          ${buildExpandButton(item)}
        </div>
      </div>
    `;
}
