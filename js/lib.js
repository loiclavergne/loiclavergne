//
//  lib.js
//  Loic Lavergne portfolio
//
//  Shared DOM/media utilities used by rendering and interaction modules.
//

/**
 * Query a single element.
 *
 * Supports `#id` fast path and falls back to `querySelector`.
 * @param {string} s CSS selector.
 * @returns {Element|null}
 */
export const $ = s => s.startsWith("#") && ![".", " ", ">"].some(c => s.includes(c))
    ? document.getElementById(s.substring(1))
    : document.querySelector(s);

/**
 * Query all matching elements.
 * @param {string} s CSS selector.
 * @returns {NodeListOf<Element>}
 */
export const $$ = s => document.querySelectorAll(s);

/**
 * Build a local `srcset` string.
 *
 * The function name is kept for backward compatibility with existing imports.
 * @param {string} path Relative path to a local image.
 * @param {number[]} widths Width descriptors to expose in srcset.
 * @returns {string}
 */
export function cdnSrcset(path, widths = [128, 256]) {
    return widths.map(width => `${path} ${width}w`).join(", ");
}

const MEDIA_PLACEHOLDER_PATH = "assets/img/placeholders/placeholder-media.svg";
const BOUND_FLAG = "true";

/**
 * Attach image/video fallback handlers in the provided DOM scope.
 *
 * Call this after dynamic rendering to cover newly inserted media nodes.
 * @param {Document|Element} root Scope to scan.
 */
export function setupMediaFallbacks(root = document) {
    const images = root.querySelectorAll("img");
    const videos = root.querySelectorAll("video");

    images.forEach(bindImageFallback);
    videos.forEach(bindVideoFallback);
}

/**
 * Attach a one-time fallback handler to an image.
 * @param {HTMLImageElement} image
 */
function bindImageFallback(image) {
    if (image.dataset.fallbackBound === BOUND_FLAG) return;
    image.dataset.fallbackBound = BOUND_FLAG;

    const applyPlaceholder = () => {
        if (image.dataset.placeholderApplied === BOUND_FLAG) return;
        image.dataset.placeholderApplied = BOUND_FLAG;

        image.removeAttribute("srcset");
        image.src = MEDIA_PLACEHOLDER_PATH;
        image.alt = image.alt || "Image unavailable";
        image.classList.add("media-placeholder");
    };

    image.addEventListener("error", applyPlaceholder);

    if (image.complete && image.naturalWidth === 0) {
        applyPlaceholder();
    }
}

/**
 * Attach a one-time fallback handler to a video and its source tags.
 * Replaces the video with a placeholder image when media loading fails.
 * @param {HTMLVideoElement} video
 */
function bindVideoFallback(video) {
    if (video.dataset.fallbackBound === BOUND_FLAG) return;
    video.dataset.fallbackBound = BOUND_FLAG;

    const replaceWithPlaceholder = () => {
        if (video.dataset.placeholderApplied === BOUND_FLAG) return;
        video.dataset.placeholderApplied = BOUND_FLAG;

        const image = document.createElement("img");
        image.src = MEDIA_PLACEHOLDER_PATH;
        image.alt = video.getAttribute("aria-label") || video.title || "Video unavailable";
        image.loading = "lazy";
        image.className = `media-placeholder ${video.className}`.trim();
        video.replaceWith(image);
    };

    video.addEventListener("error", replaceWithPlaceholder);
    video.querySelectorAll("source").forEach(source =>
        source.addEventListener("error", replaceWithPlaceholder)
    );
}
