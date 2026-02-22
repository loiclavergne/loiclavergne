//
//  main.js
//  Loic Lavergne portfolio
//
//  Page bootstrap and data-driven rendering pipeline.
//  Loads `assets/data.json` and renders each section in order.
//

import { isDarkModeEnabled, refreshAppearance } from "./appearance.js";
import { initAnimations } from "./animations.js";
import { Tile } from "./components/Tile.js";
import { $, $$, cdnSrcset, setupMediaFallbacks } from "./lib.js";

const scrollIntoViewOptions = {
    behavior: "auto",
    block: "start"
};

const LIGHT_SURFACE_RGB = { r: 236, g: 243, b: 251 };
const DARK_SURFACE_RGB = { r: 16, g: 24, b: 42 };
const LIGHT_TEXT_RGB = { r: 246, g: 251, b: 255 };
const DARK_TEXT_RGB = { r: 15, g: 35, b: 66 };
const HERO_TYPING_DELAY_MS = 52;
const HERO_TYPING_JITTER_MS = 26;
const HERO_ERASE_DELAY_MS = 16;
const HERO_HOLD_DELAY_MS = 3600;
const HERO_ANSWER_START_DELAY_MS = 2000;
const HERO_BETWEEN_LINES_DELAY_MS = 120;
const HERO_ANIMATION_START_DELAY_MS = 650;
const HERO_HIGHLIGHT_PATTERN = /127\.0\.0\.1|merge conflict|edge cases|force unwraps|swiftui|xcode|spinner|deploy|tests?|builds?|source|refactor|ship(?:ping|ped)?|app|ci|qa|swift|merge|ios|engineers?|coverage|memory leaks?|race condition|rollback|hotfixes?|production/gi;
const HERO_FALLBACK_ROTATING_LINES = [
    "May the source be with you.",
    "These are the builds you're looking for.",
    "Live long and refactor.",
    "Boldly shipping where no app has shipped before.",
    "One does not simply ship on Friday.",
    "So we let CI decide.",
    "Winter is coming. So are edge cases.",
    "Good thing tests travel in packs.",
    "Houston, we have a merge conflict.",
    "Resolving at T-minus deploy.",
    "The app awakens.",
    "SwiftUI strikes back.",
    "Keep calm and let Xcode index.",
    "I ship when the spinner stops.",
    "There is no place like 127.0.0.1.",
    "Until QA says otherwise.",
    "In Swift we trust.",
    "In CI we verify.",
    "With great power comes great merge responsibility.",
    "And fewer force unwraps."
];
const DEFAULT_TYPEWRITER_ACCENT = "var(--azure)";
const PROJECT_GRADIENT_PALETTE = [
    { primary: "#007aff", secondary: "#5ac8fa" },
    { primary: "#34c759", secondary: "#30d158" },
    { primary: "#ff9500", secondary: "#ffcc00" },
    { primary: "#af52de", secondary: "#bf5af2" },
    { primary: "#5856d6", secondary: "#5e5ce6" },
    { primary: "#ff3b30", secondary: "#ff6961" }
];
const HOBBY_PROJECT_GRADIENT_PALETTE = [
    { primary: "#34c759", secondary: "#30d158" },
    { primary: "#2fd45c", secondary: "#7be495" },
    { primary: "#22c55e", secondary: "#86efac" },
    { primary: "#16c784", secondary: "#5eead4" }
];
const APPLE_LOGO_TOKEN = "{APPLE_LOGO}";
const typewriterControllers = new WeakMap();
let cachedAppleLogoGlyphSupport;
let greetingPlatformRotatorIntervalId;
let timelineModalInitialized = false;
let activeTimelineModalCheckbox = null;
let renderedTimelineEntries = [];

/**
 * Parse a hexadecimal color (`#RGB`, `#RRGGBB`, `#RRGGBBAA`).
 * @param {string} color
 * @returns {{r:number,g:number,b:number,a:number}|null}
 */
function parseHexColor(color) {
    const value = (color ?? "").trim();
    if (!value.startsWith("#")) return null;

    const hex = value.slice(1);
    if (hex.length === 3) {
        return {
            r: Number.parseInt(hex[0] + hex[0], 16),
            g: Number.parseInt(hex[1] + hex[1], 16),
            b: Number.parseInt(hex[2] + hex[2], 16),
            a: 1
        };
    }

    if (hex.length === 6 || hex.length === 8) {
        const alpha = hex.length === 8 ? Number.parseInt(hex.slice(6, 8), 16) / 255 : 1;
        return {
            r: Number.parseInt(hex.slice(0, 2), 16),
            g: Number.parseInt(hex.slice(2, 4), 16),
            b: Number.parseInt(hex.slice(4, 6), 16),
            a: Number.isNaN(alpha) ? 1 : alpha
        };
    }

    return null;
}

/**
 * Parse an `rgb(...)` or `rgba(...)` color string.
 * @param {string} color
 * @returns {{r:number,g:number,b:number,a:number}|null}
 */
function parseRgbColor(color) {
    const rgbMatch = /^rgba?\(([^)]+)\)$/i.exec((color ?? "").trim());
    if (!rgbMatch) return null;

    const channels = (rgbMatch[1].match(/[\d.]+/g) ?? [])
        .map(value => Number.parseFloat(value));
    if (channels.length < 3 || channels.slice(0, 3).some(Number.isNaN)) return null;

    return {
        r: channels[0],
        g: channels[1],
        b: channels[2],
        a: Number.isFinite(channels[3]) ? channels[3] : 1
    };
}

/**
 * Parse a CSS color supported by this module.
 * @param {string | undefined} color
 * @returns {{r:number,g:number,b:number,a:number}|null}
 */
function parseColor(color) {
    return parseHexColor(color ?? "") ?? parseRgbColor(color ?? "");
}

/**
 * Convert any supported CSS color into an rgba(...) string with custom alpha.
 * @param {string | undefined} color
 * @param {number} alpha
 * @param {{r:number,g:number,b:number}} [fallback]
 * @returns {string}
 */
function toRgbaColorString(color, alpha, fallback = { r: 2, g: 127, b: 255 }) {
    const parsed = parseColor(color);
    const source = parsed ? {
        r: Math.round(parsed.r),
        g: Math.round(parsed.g),
        b: Math.round(parsed.b)
    } : fallback;
    return `rgba(${source.r}, ${source.g}, ${source.b}, ${alpha})`;
}

/**
 * Convert an RGB triplet into an rgba(...) string.
 * @param {{r:number,g:number,b:number}} color
 * @param {number} [alpha]
 * @returns {string}
 */
function rgbToRgbaString(color, alpha = 1) {
    return `rgba(${Math.round(color.r)}, ${Math.round(color.g)}, ${Math.round(color.b)}, ${alpha})`;
}

/**
 * Linearly blend two RGB colors.
 * @param {{r:number,g:number,b:number}} first
 * @param {{r:number,g:number,b:number}} second
 * @param {number} ratio
 * @returns {{r:number,g:number,b:number}}
 */
function mixRgb(first, second, ratio) {
    const clampedRatio = Math.min(Math.max(ratio, 0), 1);
    const inverseRatio = 1 - clampedRatio;
    return {
        r: (first.r * inverseRatio) + (second.r * clampedRatio),
        g: (first.g * inverseRatio) + (second.g * clampedRatio),
        b: (first.b * inverseRatio) + (second.b * clampedRatio)
    };
}

/**
 * Alpha-blend a foreground color over an RGB background.
 * @param {{r:number,g:number,b:number,a:number}} foreground
 * @param {{r:number,g:number,b:number}} background
 * @returns {{r:number,g:number,b:number}}
 */
function blendOverBackground(foreground, background) {
    const alpha = Math.min(Math.max(foreground.a, 0), 1);
    const inverseAlpha = 1 - alpha;
    return {
        r: (foreground.r * alpha) + (background.r * inverseAlpha),
        g: (foreground.g * alpha) + (background.g * inverseAlpha),
        b: (foreground.b * alpha) + (background.b * inverseAlpha)
    };
}

/**
 * Compute average RGB channels from a set of samples.
 * @param {{r:number,g:number,b:number}[]} colors
 * @returns {{r:number,g:number,b:number}}
 */
function averageRgb(colors) {
    if (!colors.length) return { ...LIGHT_SURFACE_RGB };

    const totals = colors.reduce((accumulator, color) => ({
        r: accumulator.r + color.r,
        g: accumulator.g + color.g,
        b: accumulator.b + color.b
    }), { r: 0, g: 0, b: 0 });

    return {
        r: totals.r / colors.length,
        g: totals.g / colors.length,
        b: totals.b / colors.length
    };
}

/**
 * Convert an sRGB channel to linear space.
 * @param {number} channel
 * @returns {number}
 */
function toLinearChannel(channel) {
    const normalized = channel / 255;
    return normalized <= 0.03928
        ? normalized / 12.92
        : ((normalized + 0.055) / 1.055) ** 2.4;
}

/**
 * Compute relative luminance (WCAG).
 * @param {{r:number,g:number,b:number}} color
 * @returns {number}
 */
function relativeLuminance(color) {
    return (0.2126 * toLinearChannel(color.r))
        + (0.7152 * toLinearChannel(color.g))
        + (0.0722 * toLinearChannel(color.b));
}

/**
 * Compute contrast ratio (WCAG).
 * @param {{r:number,g:number,b:number}} first
 * @param {{r:number,g:number,b:number}} second
 * @returns {number}
 */
function contrastRatio(first, second) {
    const firstLuminance = relativeLuminance(first);
    const secondLuminance = relativeLuminance(second);
    const lighter = Math.max(firstLuminance, secondLuminance);
    const darker = Math.min(firstLuminance, secondLuminance);
    return (lighter + 0.05) / (darker + 0.05);
}

/**
 * Estimate the effective tile background color from declared accent tokens.
 * @param {HTMLElement} tile
 * @param {boolean} darkMode
 * @returns {{r:number,g:number,b:number}}
 */
function estimateTileSurfaceColor(tile, darkMode) {
    const pageSurface = darkMode ? DARK_SURFACE_RGB : LIGHT_SURFACE_RGB;
    const defaultPrimaryAlpha = darkMode ? 0.64 : 0.56;
    const defaultSecondaryAlpha = darkMode ? 0.46 : 0.34;

    const primary = parseColor(tile.dataset.contrastPrimary);
    const secondary = parseColor(tile.dataset.contrastSecondary);
    const primaryAlpha = Number.parseFloat(tile.dataset.contrastPrimaryAlpha ?? `${defaultPrimaryAlpha}`);
    const secondaryAlpha = Number.parseFloat(tile.dataset.contrastSecondaryAlpha ?? `${defaultSecondaryAlpha}`);

    const samples = [];
    if (primary) {
        samples.push(blendOverBackground({ ...primary, a: primaryAlpha }, pageSurface));
    }
    if (secondary) {
        samples.push(blendOverBackground({ ...secondary, a: secondaryAlpha }, pageSurface));
    }

    if (!samples.length) {
        const computedBackground = parseColor(getComputedStyle(tile).backgroundColor);
        if (computedBackground) {
            samples.push(blendOverBackground(computedBackground, pageSurface));
        }
    }

    return samples.length ? averageRgb(samples) : { ...pageSurface };
}

/**
 * Apply contrast-aware text tokens to all expandable ("+") tiles.
 * In light mode, dark text is selected when backgrounds are bright.
 */
function applyContrastAwareTileTextColors() {
    const darkMode = isDarkModeEnabled();
    const candidateLight = "#f6fbff";
    const candidateDark = "#0f2342";

    $$(".tile").forEach(tileElement => {
        const tile = /** @type {HTMLElement} */ (tileElement);
        if (!tile.querySelector(".plus-go-x > input")) return;

        if (tile.closest("#timeline")) {
            tile.style.setProperty("--tile-contrast-text", "rgba(255, 255, 255, 0.98)");
            tile.style.setProperty("--tile-contrast-muted", "rgba(241, 248, 255, 0.86)");
            return;
        }

        if (darkMode) {
            tile.style.setProperty("--tile-contrast-text", candidateLight);
            tile.style.setProperty("--tile-contrast-muted", "rgba(246, 251, 255, 0.82)");
            return;
        }

        const estimatedSurface = estimateTileSurfaceColor(tile, false);
        const darkContrast = contrastRatio(estimatedSurface, DARK_TEXT_RGB);
        const lightContrast = contrastRatio(estimatedSurface, LIGHT_TEXT_RGB);
        const useDarkText = darkContrast >= lightContrast;

        tile.style.setProperty("--tile-contrast-text", useDarkText ? candidateDark : candidateLight);
        tile.style.setProperty(
            "--tile-contrast-muted",
            useDarkText ? "rgba(15, 35, 66, 0.74)" : "rgba(246, 251, 255, 0.82)"
        );
    });
}

/**
 * Render animated greeting rows behind the hero section.
 */
function initHellos(words = []) {
    const fallbackWords = [
        "Swift", "SwiftUI", "iOS Development", "Android Development", "Project Management", "Team Management",
        "Architecture", "CI/CD", "Kotlin", "Objective-C", "Git", "Firebase", "SQL", "Python", "JavaScript"
    ];
    const tickerWords = (Array.isArray(words) && words.length > 0 ? words : fallbackWords)
        .sort(() => Math.random() - 0.5);

    const itemsPerRow = Math.ceil(tickerWords.length / 3);
    const helloSets = [
        tickerWords.slice(0, itemsPerRow),
        tickerWords.slice(itemsPerRow, itemsPerRow * 2),
        tickerWords.slice(itemsPerRow * 2)
    ];

    $$(".hello-row").forEach((rowElement, rowIndex) => {
        rowElement.replaceChildren();
        const helloSet = helloSets[rowIndex];

        helloSet.forEach(hello => {
            const span = document.createElement("span");
            span.textContent = hello;
            rowElement.appendChild(span);
        });

        const firstSetWidth = rowElement.scrollWidth;
        rowElement.style.setProperty("--scroll-width", `${firstSetWidth}px`);

        rowElement
            .querySelectorAll("span")
            .forEach(span => rowElement.appendChild(span.cloneNode(true)));
    });
}

/**
 * Wait for a fixed delay, with optional abort support.
 * @param {number} durationMs
 * @param {AbortSignal | undefined} signal
 * @returns {Promise<void>}
 */
function waitForDelay(durationMs, signal) {
    if (!signal) {
        return new Promise(resolve => {
            window.setTimeout(resolve, durationMs);
        });
    }

    return new Promise((resolve, reject) => {
        if (signal.aborted) {
            reject(new Error("Hero typewriter aborted"));
            return;
        }

        const timeoutId = window.setTimeout(() => {
            signal.removeEventListener("abort", onAbort);
            resolve();
        }, durationMs);

        function onAbort() {
            window.clearTimeout(timeoutId);
            signal.removeEventListener("abort", onAbort);
            reject(new Error("Hero typewriter aborted"));
        }

        signal.addEventListener("abort", onAbort, { once: true });
    });
}

/**
 * Escape HTML-reserved characters for safe inline rendering.
 * @param {string} value
 * @returns {string}
 */
function escapeHTML(value) {
    return value
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll("\"", "&quot;")
        .replaceAll("'", "&#39;");
}

/**
 * Apply inline blue accent styling to selected geek/mobile keywords.
 * @param {string} line
 * @param {RegExp} highlightPattern
 * @returns {string}
 */
function highlightHeroLine(line, highlightPattern = HERO_HIGHLIGHT_PATTERN) {
    const regex = new RegExp(highlightPattern.source, "gi");
    const matches = Array.from(line.matchAll(regex));
    if (!matches.length) {
        return escapeHTML(line);
    }

    let currentIndex = 0;
    let highlighted = "";

    matches.forEach(match => {
        const index = match.index ?? 0;
        const term = match[0] ?? "";

        highlighted += escapeHTML(line.slice(currentIndex, index));
        highlighted += `<span class="hero-typewriter-accent">${escapeHTML(term)}</span>`;
        currentIndex = index + term.length;
    });

    highlighted += escapeHTML(line.slice(currentIndex));
    return highlighted;
}

/**
 * Resolve rotating hero lines from JSON config, with safe fallbacks.
 * @param {Record<string, any>} content
 * @returns {string[]}
 */
function resolveHeroRotatingLines(content = {}) {
    const configuredLines = Array.isArray(content.typewriter_lines)
        ? content.typewriter_lines
            .map(line => `${line ?? ""}`.trim())
            .filter(Boolean)
        : [];

    if (configuredLines.length > 0) {
        return configuredLines;
    }

    const heading = `${content.heading ?? ""}`.trim();
    if (heading) {
        return [heading];
    }

    return HERO_FALLBACK_ROTATING_LINES;
}

/**
 * Convert a flat line list into question/answer pairs.
 * Expects [question, answer, question, answer, ...].
 * @param {string[]} lines
 * @returns {{question: string, answer: string}[]}
 */
function buildTypewriterPairs(lines) {
    const pairs = [];

    for (let index = 0; index < lines.length; index += 2) {
        const question = `${lines[index] ?? ""}`.trim();
        const answer = `${lines[index + 1] ?? ""}`.trim();
        if (!question && !answer) continue;
        pairs.push({ question, answer });
    }

    return pairs;
}

/**
 * Build cursor markup for typewriter lines.
 * Cursor inherits font-size from surrounding text.
 * @returns {string}
 */
function buildTypewriterCursorMarkup() {
    return '<span class="hero-typewriter-cursor" aria-hidden="true">|</span>';
}

/**
 * Render a single typewriter line with an inline cursor.
 * @param {string} line
 * @param {RegExp} highlightPattern
 * @returns {string}
 */
function renderTypewriterLine(line, highlightPattern) {
    return `${highlightHeroLine(line, highlightPattern)}${buildTypewriterCursorMarkup()}`;
}

/**
 * Render a question/answer pair for typewriter output.
 * @param {string} question
 * @param {string} answer
 * @param {RegExp} highlightPattern
 * @param {"question" | "answer" | "none"} cursorTarget
 * @returns {string}
 */
function renderTypewriterPair(question, answer, highlightPattern, cursorTarget = "none") {
    const questionCursor = cursorTarget === "question" ? buildTypewriterCursorMarkup() : "";
    const answerCursor = cursorTarget === "answer" ? buildTypewriterCursorMarkup() : "";
    const questionMarkup = question
        ? `<span class="hero-typewriter-question">${highlightHeroLine(question, highlightPattern)}${questionCursor}</span>`
        : "";
    const answerMarkup = answer
        ? `<br><span class="hero-typewriter-answer">${highlightHeroLine(answer, highlightPattern)}${answerCursor}</span>`
        : "";
    return `${questionMarkup}${answerMarkup}`;
}

/**
 * Build the DOM nodes required for the hero typewriter effect.
 * @param {HTMLElement} headingElement
 * @param {string} accentColor
 * @returns {HTMLSpanElement | null}
 */
function mountHeroTypewriter(headingElement, accentColor) {
    headingElement.classList.add("typewriter-target");
    headingElement.style.setProperty("--typewriter-accent", accentColor);
    headingElement.replaceChildren();

    const text = document.createElement("span");
    text.className = "hero-typewriter-text";

    headingElement.setAttribute("aria-live", "off");
    headingElement.append(text);

    return text;
}

/**
 * Loop through all hero lines using a type-and-erase animation.
 * @param {string[]} lines
 * @param {HTMLElement} textElement
 * @param {AbortSignal} signal
 * @param {RegExp} highlightPattern
 */
async function runHeroTypewriter(lines, textElement, signal, highlightPattern = HERO_HIGHLIGHT_PATTERN) {
    let lineIndex = 0;

    while (!signal.aborted) {
        const line = lines[lineIndex % lines.length];

        for (let count = 1; count <= line.length; count += 1) {
            if (signal.aborted) return;
            textElement.innerHTML = renderTypewriterLine(line.slice(0, count), highlightPattern);
            const jitterMs = Math.floor(Math.random() * HERO_TYPING_JITTER_MS);
            await waitForDelay(HERO_TYPING_DELAY_MS + jitterMs, signal);
        }

        await waitForDelay(HERO_HOLD_DELAY_MS, signal);

        for (let count = line.length - 1; count >= 0; count -= 1) {
            if (signal.aborted) return;
            textElement.innerHTML = renderTypewriterLine(line.slice(0, count), highlightPattern);
            await waitForDelay(HERO_ERASE_DELAY_MS, signal);
        }

        await waitForDelay(HERO_BETWEEN_LINES_DELAY_MS, signal);
        lineIndex = (lineIndex + 1) % lines.length;
    }
}

/**
 * Loop through question/answer pairs using a stacked type-and-erase animation.
 * Questions type first, answers type directly below.
 * @param {string[]} lines
 * @param {HTMLElement} textElement
 * @param {AbortSignal} signal
 * @param {RegExp} highlightPattern
 */
async function runHeroPairTypewriter(lines, textElement, signal, highlightPattern = HERO_HIGHLIGHT_PATTERN) {
    const pairs = buildTypewriterPairs(lines);
    if (!pairs.length) {
        await runHeroTypewriter(lines, textElement, signal, highlightPattern);
        return;
    }

    let pairIndex = 0;

    while (!signal.aborted) {
        const { question, answer } = pairs[pairIndex % pairs.length];

        for (let count = 1; count <= question.length; count += 1) {
            if (signal.aborted) return;
            textElement.innerHTML = renderTypewriterPair(question.slice(0, count), "", highlightPattern, "question");
            const jitterMs = Math.floor(Math.random() * HERO_TYPING_JITTER_MS);
            await waitForDelay(HERO_TYPING_DELAY_MS + jitterMs, signal);
        }

        if (question.length > 0 && answer.length > 0) {
            await waitForDelay(HERO_ANSWER_START_DELAY_MS, signal);
        }

        for (let count = 1; count <= answer.length; count += 1) {
            if (signal.aborted) return;
            textElement.innerHTML = renderTypewriterPair(question, answer.slice(0, count), highlightPattern, "answer");
            const jitterMs = Math.floor(Math.random() * HERO_TYPING_JITTER_MS);
            await waitForDelay(HERO_TYPING_DELAY_MS + jitterMs, signal);
        }

        await waitForDelay(HERO_HOLD_DELAY_MS, signal);

        for (let count = answer.length - 1; count >= 0; count -= 1) {
            if (signal.aborted) return;
            textElement.innerHTML = renderTypewriterPair(question, answer.slice(0, count), highlightPattern, "answer");
            await waitForDelay(HERO_ERASE_DELAY_MS, signal);
        }

        for (let count = question.length - 1; count >= 0; count -= 1) {
            if (signal.aborted) return;
            textElement.innerHTML = renderTypewriterPair(question.slice(0, count), "", highlightPattern, "question");
            await waitForDelay(HERO_ERASE_DELAY_MS, signal);
        }

        await waitForDelay(HERO_BETWEEN_LINES_DELAY_MS, signal);
        pairIndex = (pairIndex + 1) % pairs.length;
    }
}

/**
 * Start (or restart) the hero typewriter effect.
 * @param {HTMLElement} headingElement
 * @param {string[]} lines
 * @param {{ accentColor?: string, highlightPattern?: RegExp, renderAsPairs?: boolean }} options
 */
function startHeroTypewriter(headingElement, lines, options = {}) {
    const existingController = typewriterControllers.get(headingElement);
    if (existingController) {
        existingController.abort();
    }

    const accentColor = options.accentColor ?? DEFAULT_TYPEWRITER_ACCENT;
    const highlightPattern = options.highlightPattern ?? HERO_HIGHLIGHT_PATTERN;
    const renderAsPairs = options.renderAsPairs ?? false;

    const textElement = mountHeroTypewriter(headingElement, accentColor);
    if (!textElement) return;

    const resolvedLines = lines.length ? lines : HERO_FALLBACK_ROTATING_LINES;
    const firstPair = buildTypewriterPairs(resolvedLines)[0];
    const firstLine = renderAsPairs
        ? (firstPair?.question || firstPair?.answer || resolvedLines[0])
        : resolvedLines[0];
    headingElement.setAttribute("aria-label", firstLine ?? "");

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
        headingElement.classList.add("typewriter-static");
        textElement.innerHTML = renderAsPairs
            ? renderTypewriterPair(firstPair?.question ?? firstLine, firstPair?.answer ?? "", highlightPattern)
            : highlightHeroLine(firstLine, highlightPattern);
        typewriterControllers.delete(headingElement);
        return;
    }

    headingElement.classList.remove("typewriter-static");
    const controller = new AbortController();
    typewriterControllers.set(headingElement, controller);
    const { signal } = controller;

    window.setTimeout(() => {
        if (signal.aborted) return;
        const runner = renderAsPairs ? runHeroPairTypewriter : runHeroTypewriter;
        void runner(resolvedLines, textElement, signal, highlightPattern).catch(error => {
            if (error instanceof Error && error.message === "Hero typewriter aborted") {
                return;
            }
            console.error(error);
        });
    }, HERO_ANIMATION_START_DELAY_MS);
}

/**
 * Main page bootstrapping flow.
 */
async function initPage() {
    try {
        const data = await fetchJSON("assets/data.json");

        initHellos(data.greeting.keywords);
        renderGreeting(data);
        renderIntro(data);
        renderSkills(data);
        renderProjects(data);
        renderSocialLinks(data);

        setupMediaFallbacks($("#main-container") ?? document);
        refreshAppearance();
        initAnimations();
    } catch (error) {
        console.error(error);
    }
}

/**
 * Build a simple alpha/bounds signature for a rendered glyph.
 * Used to compare the Apple logo glyph against the replacement glyph.
 * @param {CanvasRenderingContext2D} context
 * @param {string} glyph
 * @returns {{alphaSum:number,minX:number,minY:number,maxX:number,maxY:number}}
 */
function createGlyphSignature(context, glyph) {
    const { width, height } = context.canvas;
    context.clearRect(0, 0, width, height);
    context.fillText(glyph, 0, 0);

    const { data } = context.getImageData(0, 0, width, height);
    let alphaSum = 0;
    let minX = width;
    let minY = height;
    let maxX = -1;
    let maxY = -1;

    for (let index = 3; index < data.length; index += 4) {
        const alpha = data[index];
        if (alpha === 0) continue;

        const pixelIndex = (index - 3) / 4;
        const x = pixelIndex % width;
        const y = Math.floor(pixelIndex / width);

        alphaSum += alpha;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
    }

    if (alphaSum === 0) {
        return { alphaSum: 0, minX: -1, minY: -1, maxX: -1, maxY: -1 };
    }

    return { alphaSum, minX, minY, maxX, maxY };
}

/**
 * Compare two glyph signatures.
 * @param {{alphaSum:number,minX:number,minY:number,maxX:number,maxY:number}} first
 * @param {{alphaSum:number,minX:number,minY:number,maxX:number,maxY:number}} second
 * @returns {boolean}
 */
function isSameGlyphSignature(first, second) {
    return first.alphaSum === second.alphaSum
        && first.minX === second.minX
        && first.minY === second.minY
        && first.maxX === second.maxX
        && first.maxY === second.maxY;
}

/**
 * Detect whether the Apple logo glyph (``) appears to be supported.
 * Falls back to cached value after first evaluation.
 * @returns {boolean}
 */
function supportsAppleLogoGlyph() {
    if (typeof cachedAppleLogoGlyphSupport === "boolean") {
        return cachedAppleLogoGlyphSupport;
    }

    const canvas = document.createElement("canvas");
    canvas.width = 64;
    canvas.height = 64;

    const context = canvas.getContext("2d", { willReadFrequently: true });
    if (!context) {
        cachedAppleLogoGlyphSupport = true;
        return cachedAppleLogoGlyphSupport;
    }

    context.font = '52px -apple-system, BlinkMacSystemFont, "Segoe UI Symbol", "Arial Unicode MS", sans-serif';
    context.textBaseline = "top";
    context.fillStyle = "#000";

    const appleSignature = createGlyphSignature(context, "");
    const replacementSignature = createGlyphSignature(context, "\uFFFD");
    cachedAppleLogoGlyphSupport = appleSignature.alphaSum > 0
        && !isSameGlyphSignature(appleSignature, replacementSignature);

    return cachedAppleLogoGlyphSupport;
}

/**
 * Resolve greeting copy that may contain the Apple logo token/glyph.
 * Falls back to plain text (e.g. "Apple") when glyph rendering is unavailable.
 * @param {Record<string, any>} greeting
 * @returns {string}
 */
function resolveGreetingDescription(greeting) {
    const rawDescription = `${greeting.description ?? ""}`;
    if (!rawDescription) return "";

    const fallbackEnabled = greeting.enable_apple_logo_fallback !== false;
    const fallbackText = `${greeting.fallback_apple_logo_text ?? "Apple"}`;
    const withGlyph = rawDescription.replaceAll(APPLE_LOGO_TOKEN, "");

    if (!fallbackEnabled) return withGlyph;
    return supportsAppleLogoGlyph()
        ? withGlyph
        : withGlyph.replaceAll("", fallbackText);
}

/**
 * Stop the running greeting platform rotator timer, if any.
 */
function stopGreetingPlatformRotator() {
    if (typeof greetingPlatformRotatorIntervalId !== "number") return;
    window.clearInterval(greetingPlatformRotatorIntervalId);
    greetingPlatformRotatorIntervalId = undefined;
}

/**
 * Render the greeting subtitle as plain text or with a rotating platform token.
 * Rotates the "i" prefix in "iOS" to cycle through iPadOS/tvOS/macOS/watchOS.
 * @param {HTMLElement} target
 * @param {Record<string, any>} greeting
 */
function renderGreetingDescription(target, greeting) {
    stopGreetingPlatformRotator();
    target.classList.remove("greeting-platform-line");
    target.removeAttribute("aria-label");

    const description = resolveGreetingDescription(greeting);
    const rotator = greeting.platform_rotator;
    const isRotatorEnabled = Boolean(rotator?.enabled);
    if (!isRotatorEnabled) {
        target.innerText = description;
        return;
    }

    const token = `${rotator.token ?? "iOS"}`;
    const suffix = `${rotator.suffix ?? "OS"}`;
    const prefixes = (Array.isArray(rotator.prefixes) ? rotator.prefixes : ["i", "iPad", "tv", "mac", "watch"])
        .map(item => `${item ?? ""}`.trim())
        .filter(Boolean);

    const tokenIndex = description.indexOf(token);
    if (!prefixes.length || tokenIndex < 0) {
        target.innerText = description;
        return;
    }

    const before = description.slice(0, tokenIndex);
    const after = description.slice(tokenIndex + token.length);
    const basePhrase = `${before}${prefixes[0]}${suffix}${after}`;

    target.setAttribute("aria-label", basePhrase);
    target.classList.add("greeting-platform-line");
    const animatedItems = [...prefixes, prefixes[0]];
    target.innerHTML = `
      <span class="greeting-platform-prefix" aria-hidden="true">${escapeHTML(before)}</span><span class="greeting-platform-rotator" aria-hidden="true">
        <span class="greeting-platform-viewport">
          <span class="greeting-platform-track">
            ${animatedItems.map(item => `<span class="greeting-platform-item">${escapeHTML(item)}</span>`).join("")}
          </span>
        </span><span class="greeting-platform-suffix">${escapeHTML(suffix)}</span>
      </span><span class="greeting-platform-after" aria-hidden="true">${escapeHTML(after)}</span>
      <span class="greeting-platform-measure" aria-hidden="true">
        ${prefixes.map(item => `<span class="greeting-platform-measure-item">${escapeHTML(item)}</span>`).join("")}
      </span>
    `;

    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReducedMotion || prefixes.length <= 1) {
        return;
    }

    const track = target.querySelector(".greeting-platform-track");
    const viewport = target.querySelector(".greeting-platform-viewport");
    if (!(track instanceof HTMLElement) || !(viewport instanceof HTMLElement)) {
        return;
    }

    const measureItems = Array.from(target.querySelectorAll(".greeting-platform-measure-item"));
    if (!measureItems.length) {
        return;
    }

    /** @returns {number[]} */
    const measurePrefixWidths = () => measureItems.map(item => {
        const width = Math.ceil(item.getBoundingClientRect().width);
        if (width > 0) return width;
        const text = item.textContent ?? "";
        return Math.max(8, text.length * 10);
    });
    let prefixWidths = measurePrefixWidths();
    const applyViewportWidth = index => {
        const width = prefixWidths[index] ?? prefixWidths[0] ?? 0;
        viewport.style.width = `${Math.max(1, width)}px`;
    };

    applyViewportWidth(0);

    const intervalMs = Math.max(700, Number.parseInt(`${rotator.interval_ms ?? 1000}`, 10) || 1000);
    const transitionDurationMs = 420;
    let step = 0;
    const lastIndex = prefixes.length;

    greetingPlatformRotatorIntervalId = window.setInterval(() => {
        step += 1;
        if (step <= prefixes.length - 1) {
            applyViewportWidth(step);
        } else {
            applyViewportWidth(0);
        }
        track.style.transition = "transform 420ms cubic-bezier(0.2, 0.8, 0.2, 1)";
        track.style.transform = `translate3d(0, calc(${step} * -1 * var(--greeting-platform-step)), 0)`;

        if (step !== lastIndex) {
            return;
        }

        window.setTimeout(() => {
            track.style.transition = "none";
            track.style.transform = "translate3d(0, 0, 0)";
            prefixWidths = measurePrefixWidths();
            applyViewportWidth(0);
            step = 0;
        }, transitionDurationMs + 20);
    }, intervalMs);
}

/**
 * Render hero title and subtitle.
 * @param {Record<string, any>} data
 */
function renderGreeting(data) {
    const headingElement = $("#greeting h1");
    if (headingElement) {
        const typewriterController = typewriterControllers.get(headingElement);
        if (typewriterController) {
            typewriterController.abort();
            typewriterControllers.delete(headingElement);
        }

        headingElement.classList.remove("typewriter-target", "typewriter-static");
        headingElement.style.removeProperty("--typewriter-accent");
        headingElement.replaceChildren();
        headingElement.innerText = data.greeting.heading;
    }

    const greetingDescriptionElement = $("#greeting p");
    if (!greetingDescriptionElement) return;
    renderGreetingDescription(greetingDescriptionElement, data.greeting ?? {});
}

/**
 * Render intro section and timeline blocks.
 * @param {Record<string, any>} data
 */
function renderIntro(data) {
    const introHeadingElement = $("#intro .tile h2");
    if (introHeadingElement) {
        introHeadingElement.innerHTML = data.intro.heading;
        const lines = resolveHeroRotatingLines(data.intro ?? {});
        startHeroTypewriter(introHeadingElement, lines);
    }

    const introOverlayContent = $("#intro .tile-overlay .overlay-content-glass");
    if (introOverlayContent) {
        introOverlayContent.innerHTML = "";
        data.intro.description.split("\n").forEach(line => {
            if (!line.trim()) return;
            introOverlayContent.insertAdjacentHTML("beforeend", `<p>${line}</p>`);
        });
    }

    const timelineTrack = $("#timeline .timeline-pager-track");
    if (!timelineTrack) return;

    renderedTimelineEntries = Array.isArray(data.intro.timeline)
        ? data.intro.timeline
        : [];

    const timelineMarkup = renderedTimelineEntries.map((milestone, index) => {
        const milestoneTitle = escapeHTML(`${milestone.title ?? ""}`);
        const milestoneSubtitle = escapeHTML(`${milestone.subtitle ?? ""}`);
        const milestoneDate = escapeHTML(`${milestone.date ?? ""}`);
        const hasDetails = `${milestone.description ?? ""}`.trim().length > 0;

        return `
            <div
              class="timeline-pager-slide ${index === 0 ? "is-active" : ""}"
              id="timeline-slide-${index + 1}"
              data-index="${index}"
              data-title="${milestoneTitle}"
              data-subtitle="${milestoneSubtitle}"
              data-date="${milestoneDate}"
              role="tabpanel"
              tabindex="${index === 0 ? "0" : "-1"}"
              aria-labelledby="timeline-pager-trigger-${index + 1}"
              aria-hidden="${index === 0 ? "false" : "true"}"
            >
              <div class="tile timeline-tile rounded-5 d-flex flex-column p-4-5 p-md-5 h-100">
                <div class="timeline-card-content fw-kinda-bold">
                  <div class="timeline-logo-shell">
                    <img
                      srcset="${cdnSrcset(milestone.img, [160, 320, 480])}"
                      sizes="(max-width: 767px) 112px, 120px"
                      src="${milestone.img}"
                      alt="${milestoneSubtitle} logo"
                      loading="lazy"
                      decoding="async"
                      fetchpriority="low"
                      class="app-icon timeline-logo"
                    >
                    ${hasDetails ? `
                    <div class="plus-go-x-container timeline-plus-trigger">
                      <label class="plus-go-x">
                        <input
                          type="checkbox"
                          aria-label="Open description for ${milestoneTitle}"
                          aria-expanded="false"
                        >
                        <div class="p-1">
                          <svg xmlns="http://www.w3.org/2000/svg" class="bi bi-plus-circle-fill" width="16" height="16" viewBox="0 0 16 16" aria-hidden="true" focusable="false">
                            <path d="M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0zM8.5 4.5a.5.5 0 0 0-1 0v3h-3a.5.5 0 0 0 0 1h3v3a.5.5 0 0 0 1 0v-3h3a.5.5 0 0 0 0-1h-3v-3z" />
                          </svg>
                        </div>
                      </label>
                    </div>
                    ` : ""}
                  </div>
                  <p class="timeline-meta">
                    <span class="timeline-title fw-kinda-bold">${milestoneTitle}</span><br>
                    <span class="timeline-company">${milestoneSubtitle}</span><br>
                    <span class="timeline-date">${milestoneDate}</span>
                  </p>
                </div>
              </div>
            </div>
        `;
    }).join("");

    timelineTrack.innerHTML = timelineMarkup;
    setupTimelinePager();
    initTimelineModalBehavior();
}

/**
 * Apply visual state for a timeline "+" control.
 * @param {HTMLInputElement} checkbox
 * @param {boolean} isOpen
 * @param {boolean} [animate]
 */
function setTimelinePlusState(checkbox, isOpen, animate = true) {
    checkbox.checked = isOpen;
    checkbox.setAttribute("aria-expanded", isOpen ? "true" : "false");

    const label = checkbox.parentElement;
    const container = label?.parentElement;
    const icon = label?.querySelector("div");

    label?.classList.toggle("checked", isOpen);
    container?.classList.toggle("is-open", isOpen);

    if (!(icon instanceof HTMLElement)) return;
    icon.classList.remove("animating");
    icon.style.animation = animate
        ? (isOpen
            ? "make_x 0.45s cubic-bezier(0.7, 0, 0.2, 1) both"
            : "make_plus 0.36s cubic-bezier(0.7, 0, 0.2, 1) both")
        : "none";
}

/**
 * Reset all timeline "+" controls in a slide.
 * @param {Element} slide
 * @param {boolean} [animate]
 */
function clearTimelinePlusInSlide(slide, animate = false) {
    const checkboxes = Array.from(slide.querySelectorAll(".plus-go-x > input"));
    checkboxes.forEach(checkboxElement => {
        if (!(checkboxElement instanceof HTMLInputElement)) return;
        setTimelinePlusState(checkboxElement, false, animate);
    });
}

/**
 * Close the shared timeline modal.
 * @param {{restoreFocus?: boolean}} [options]
 */
function closeTimelineJobModal(options = {}) {
    const { restoreFocus = true } = options;
    const modal = $("#timeline-job-modal");
    if (!modal) return;

    modal.classList.remove("is-open");
    modal.setAttribute("aria-hidden", "true");
    document.body.classList.remove("timeline-modal-open");

    if (!(activeTimelineModalCheckbox instanceof HTMLInputElement)) {
        activeTimelineModalCheckbox = null;
        return;
    }

    const previousCheckbox = activeTimelineModalCheckbox;
    activeTimelineModalCheckbox = null;
    setTimelinePlusState(previousCheckbox, false, false);
    if (restoreFocus) previousCheckbox.focus();
}

/**
 * Open the shared timeline modal with selected job details.
 * @param {Record<string, any>} entry
 * @param {HTMLInputElement} triggerCheckbox
 */
function openTimelineJobModal(entry, triggerCheckbox) {
    const modal = $("#timeline-job-modal");
    const titleElement = $("#timeline-job-modal-title");
    const metaElement = $("#timeline-job-modal-meta");
    const descriptionElement = $("#timeline-job-modal-description");
    if (!modal || !titleElement || !metaElement || !descriptionElement) return;

    if (activeTimelineModalCheckbox instanceof HTMLInputElement
        && activeTimelineModalCheckbox !== triggerCheckbox) {
        setTimelinePlusState(activeTimelineModalCheckbox, false, false);
    }

    const title = `${entry.title ?? ""}`.trim();
    const subtitle = `${entry.subtitle ?? ""}`.trim();
    const date = `${entry.date ?? ""}`.trim();
    const descriptionLines = `${entry.description ?? ""}`
        .split("\n")
        .map(line => line.trim())
        .filter(Boolean);

    titleElement.textContent = title;
    metaElement.textContent = [subtitle, date].filter(Boolean).join(" · ");
    descriptionElement.innerHTML = descriptionLines
        .map(line => `<p>${escapeHTML(line)}</p>`)
        .join("");

    setTimelinePlusState(triggerCheckbox, true, true);
    activeTimelineModalCheckbox = triggerCheckbox;

    modal.classList.add("is-open");
    modal.setAttribute("aria-hidden", "false");
    document.body.classList.add("timeline-modal-open");
}

/**
 * Initialize timeline modal close handlers once.
 */
function initTimelineModalBehavior() {
    if (timelineModalInitialized) return;
    const modal = $("#timeline-job-modal");
    if (!modal) return;

    modal.addEventListener("click", event => {
        const target = event.target;
        if (!(target instanceof Element)) return;
        if (!target.closest("[data-timeline-modal-close]")) return;
        closeTimelineJobModal({ restoreFocus: true });
    });

    document.addEventListener("keydown", event => {
        if (event.key !== "Escape") return;
        closeTimelineJobModal({ restoreFocus: true });
    });

    timelineModalInitialized = true;
}

/**
 * Initialize the Timeline pager controls and keyboard navigation.
 */
function setupTimelinePager() {
    const timelineElement = $("#timeline");
    const slides = Array.from($$("#timeline .timeline-pager-slide"));
    const triggersContainer = $("#timeline .timeline-media-card-gallery-nav");
    const previousButton = $("#timeline .timeline-pager-prev");
    const nextButton = $("#timeline .timeline-pager-next");

    if (!timelineElement || !slides.length || !triggersContainer || !previousButton || !nextButton) {
        return;
    }

    let activeIndex = Math.max(0, slides.findIndex(slide => slide.classList.contains("is-active")));
    if (activeIndex < 0) activeIndex = 0;
    const triggers = [];

    /**
     * Scroll active trigger into view.
     * @param {HTMLButtonElement | undefined} trigger
     * @param {"auto" | "smooth"} behavior
     */
    function keepTriggerVisible(trigger, behavior = "smooth") {
        if (!trigger) return;
        trigger.scrollIntoView({
            behavior,
            block: "nearest",
            inline: "center"
        });
    }

    /**
     * Set active slide.
     * @param {number} index
     * @param {boolean} [shouldFocusTrigger]
     * @param {"auto" | "smooth"} [scrollBehavior]
     */
    function setActiveSlide(index, shouldFocusTrigger = false, scrollBehavior = "smooth") {
        activeIndex = (index + slides.length) % slides.length;

        slides.forEach((slide, slideIndex) => {
            const isActive = slideIndex === activeIndex;
            slide.classList.toggle("is-active", isActive);
            slide.setAttribute("aria-hidden", isActive ? "false" : "true");
            slide.setAttribute("tabindex", isActive ? "0" : "-1");
            if (!isActive) clearTimelinePlusInSlide(slide, false);
        });

        triggers.forEach((trigger, triggerIndex) => {
            const isActive = triggerIndex === activeIndex;
            trigger.classList.toggle("is-active", isActive);
            trigger.setAttribute("aria-selected", isActive ? "true" : "false");
            trigger.setAttribute("tabindex", isActive ? "0" : "-1");
            trigger.setAttribute("aria-current", isActive ? "true" : "false");
        });

        previousButton.disabled = slides.length <= 1;
        nextButton.disabled = slides.length <= 1;
        timelineElement.classList.toggle("timeline-single", slides.length <= 1);
        keepTriggerVisible(triggers[activeIndex], scrollBehavior);

        if (activeTimelineModalCheckbox instanceof HTMLInputElement
            && !slides[activeIndex]?.contains(activeTimelineModalCheckbox)) {
            closeTimelineJobModal({ restoreFocus: false });
        }

        if (shouldFocusTrigger) triggers[activeIndex]?.focus();
    }

    triggersContainer.replaceChildren();
    slides.forEach((slide, index) => {
        const title = `${slide.dataset.title ?? ""}`.trim() || `Job ${index + 1}`;
        const subtitle = `${slide.dataset.subtitle ?? ""}`.trim();
        const date = `${slide.dataset.date ?? ""}`.trim();

        const trigger = document.createElement("button");
        trigger.type = "button";
        trigger.id = `timeline-pager-trigger-${index + 1}`;
        trigger.className = "timeline-pager-trigger";
        trigger.setAttribute("role", "tab");
        trigger.setAttribute("aria-controls", slide.id);
        trigger.setAttribute("aria-label", `Show ${title}${subtitle ? ` at ${subtitle}` : ""}${date ? `, ${date}` : ""}`);

        const line = document.createElement("span");
        line.className = "timeline-pager-trigger-line";
        line.setAttribute("aria-hidden", "true");

        const textWrap = document.createElement("span");
        textWrap.className = "timeline-pager-trigger-meta";

        const titleElement = document.createElement("span");
        titleElement.className = "timeline-pager-trigger-title";
        titleElement.textContent = title;

        const subtitleElement = document.createElement("span");
        subtitleElement.className = "timeline-pager-trigger-subtitle";
        subtitleElement.textContent = subtitle || date;

        textWrap.append(titleElement);
        if (subtitle || date) textWrap.append(subtitleElement);

        trigger.append(line, textWrap);
        trigger.addEventListener("click", () => setActiveSlide(index, true, "smooth"));
        trigger.addEventListener("focus", () => keepTriggerVisible(trigger, "smooth"));
        triggersContainer.appendChild(trigger);
        triggers.push(trigger);
    });

    previousButton.onclick = () => setActiveSlide(activeIndex - 1, false, "smooth");
    nextButton.onclick = () => setActiveSlide(activeIndex + 1, false, "smooth");

    timelineElement.onkeydown = event => {
        if (event.key === "ArrowLeft") {
            event.preventDefault();
            setActiveSlide(activeIndex - 1, true, "smooth");
        } else if (event.key === "ArrowRight") {
            event.preventDefault();
            setActiveSlide(activeIndex + 1, true, "smooth");
        }
    };

    setActiveSlide(activeIndex, false, "auto");
}

/**
 * Timeline-specific "+" handler to open the shared Apple-like modal.
 * @param {Event} event
 */
window.timelinePlusGoXHandler = function timelinePlusGoXHandler(event) {
    const checkbox = /** @type {HTMLInputElement} */ (event.target);
    if (!(checkbox instanceof HTMLInputElement)) return;

    const slide = checkbox.closest(".timeline-pager-slide");
    if (!(slide instanceof HTMLElement)) return;

    const index = Number.parseInt(slide.dataset.index ?? "-1", 10);
    if (Number.isNaN(index) || !renderedTimelineEntries[index]) {
        setTimelinePlusState(checkbox, false, false);
        return;
    }

    const entry = renderedTimelineEntries[index];
    const hasDescription = `${entry.description ?? ""}`.trim().length > 0;
    if (!hasDescription) {
        setTimelinePlusState(checkbox, false, false);
        return;
    }

    if (!checkbox.checked) {
        closeTimelineJobModal({ restoreFocus: false });
        setTimelinePlusState(checkbox, false, true);
        return;
    }

    openTimelineJobModal(entry, checkbox);
};

/**
 * Build a technology icon image tag used by the marquee rows.
 * @param {string} iconName
 * @returns {string}
 */
function buildTechnologyIcon(iconName) {
    return `<img src="assets/img/technology-icons/${iconName}.png" alt="${iconName}" loading="lazy" decoding="async" fetchpriority="low">`;
}

/**
 * Build a full technology row.
 * @param {string[]} iconNames
 * @param {number} repetitions
 * @returns {string}
 */
function buildTechnologyRow(iconNames, repetitions = 2) {
    const unit = iconNames.map(buildTechnologyIcon).join("");
    return unit.repeat(repetitions);
}

/**
 * Render technologies rows and skill tiles.
 * @param {Record<string, any>} data
 */
function renderSkills(data) {
    const rows = $$(".technologies-row");
    const languages = ["html", "css", "js", "php", "java", "python", "swift", "c"];
    const technologies = ["node", "nextjs", "react", "docker", "mysql", "pg", "gcp", "ios-sdk"];
    const tools = ["github", "postman", "vscode", "eclipse", "android-studio", "intellij", "xcode", "terminal"];

    if (rows.length >= 3) {
        rows[0].innerHTML = buildTechnologyRow(languages);
        rows[1].innerHTML = `${buildTechnologyRow(technologies)}${buildTechnologyIcon(technologies[0])}`;
        rows[2].innerHTML = buildTechnologyRow(tools);
    }

    $("#skills .tile-content p:first-of-type").innerText = data.skills.description;
    const skillsRow = $("#skills>.section-inner-container>.row");
    if (skillsRow) {
        skillsRow.insertAdjacentHTML(
            "beforeend",
            data.skills.list
                .map(item => Tile(item, data.skills.color, data.skills.muted_color))
                .join("")
        );
    }
}

/**
 * Render project tiles from local JSON data.
 * @param {Record<string, any>} data
 */
function renderProjects(data) {
    const projectsHeading = $("#projects-typewriter");
    if (projectsHeading) {
        const projectHeadlineLines = resolveHeroRotatingLines(data.projects ?? {});
        startHeroTypewriter(projectsHeading, projectHeadlineLines, {
            accentColor: data.projects?.color ?? "var(--tomato)",
            renderAsPairs: true
        });
    }

    const projectsConfig = data.projects ?? {};
    const hobbyProjectsConfig = {
        ...projectsConfig,
        color: projectsConfig.hobby_color ?? "#34c759",
        muted_color: projectsConfig.hobby_muted_color ?? "#30d158"
    };
    const baseProProjects = Array.isArray(projectsConfig.pro)
        ? projectsConfig.pro
        : (Array.isArray(projectsConfig.list) ? projectsConfig.list : []);
    const baseHobbyProjects = Array.isArray(projectsConfig.hobby) ? projectsConfig.hobby : [];
    const proProjects = decorateProjectTiles(baseProProjects, {
        enableGradients: false
    });
    const hobbyProjects = decorateProjectTiles(baseHobbyProjects, {
        gradientPalette: HOBBY_PROJECT_GRADIENT_PALETTE,
        enableGradients: false
    });

    const proProjectsRow = $("#projects-pro-row");
    if (proProjectsRow) {
        proProjectsRow.innerHTML = renderProjectTiles(proProjects, projectsConfig);
    }

    const hobbyProjectsRow = $("#projects-hobby-row");
    if (hobbyProjectsRow) {
        hobbyProjectsRow.innerHTML = renderProjectTiles(hobbyProjects, hobbyProjectsConfig);
    }
}

/**
 * Build cover-side links and topic badges for a project tile.
 * @param {Record<string, any>} project
 * @param {Record<string, any>} projectsConfig
 * @returns {string}
 */
function buildProjectCoverDescription(project, projectsConfig) {
    let markup = "";
    const accentColor = project.tile_primary_color ?? projectsConfig.color;
    const linkClass = project.use_contrast_text ? "link-light" : "link-primary";
    const topicColor = project.use_contrast_text ? "rgba(255, 255, 255, 0.95)" : accentColor;

    if (project.custom_url) {
        markup += `
        <a target="_blank"
            href="${project.custom_url}"
            rel="noopener noreferrer"
            class="fs-6 ${linkClass} d-block"
            style="margin-top: 4px; margin-bottom: 10px; width: fit-content;"
        >
            <span class="link-text fw-normal">
                ${project.custom_url_text ?? "View details"}
            </span>
            <i class="bi bi-chevron-right" aria-hidden="true"></i>
        </a>`;
    }

    if (project.custom_url_2?.url) {
        markup += `
        <a target="_blank"
            href="${project.custom_url_2.url}"
            rel="noopener noreferrer"
            class="fs-6 ${linkClass} d-block"
            style="margin-top: -5px; margin-bottom: 10px; width: fit-content;"
        >
            <span class="link-text fw-normal">
                ${project.custom_url_2.text ?? "View details"}
            </span>
            <i class="bi bi-chevron-right" aria-hidden="true"></i>
        </a>`;
    }

    if (Array.isArray(project.topics) && project.topics.length > 0) {
        markup += "<p>";
        project.topics.forEach(topic => {
            markup += `
            <span class="topic-badge m-1" style="color:${topicColor}; border-color: ${topicColor};">
                ${topic}
            </span>`;
        });
        markup += "</p>";
    }

    return markup;
}

/**
 * Render an array of project objects into tile markup.
 * @param {Record<string, any>[]} projects
 * @param {Record<string, any>} projectsConfig
 * @returns {string}
 */
function renderProjectTiles(projects, projectsConfig) {
    if (!Array.isArray(projects) || projects.length === 0) return "";

    return projects
        .map(project => {
            const customCoverDescriptionHTML = buildProjectCoverDescription(project, projectsConfig);
            const primaryColor = project.tile_primary_color ?? projectsConfig.color;
            const secondaryColor = project.tile_secondary_color ?? projectsConfig.muted_color;
            return Tile(project, primaryColor, secondaryColor, customCoverDescriptionHTML);
        })
        .join("");
}

/**
 * Create a stable hash from text to drive deterministic layout/color variance.
 * @param {string} value
 * @returns {number}
 */
function hashString(value) {
    let hash = 0;
    for (let index = 0; index < value.length; index += 1) {
        hash = ((hash << 5) - hash) + value.charCodeAt(index);
        hash |= 0;
    }
    return Math.abs(hash);
}

/**
 * Decorate project tiles with varied row layouts and selective gradient themes.
 * Pattern cycles: large-small, small-large, then three small cards.
 * If a project declares `md_size` / `lg_size` in JSON, those values are preserved.
 * @param {Record<string, any>[]} projects
 * @param {{ gradientPalette?: { primary: string, secondary: string }[], enableGradients?: boolean }} options
 * @returns {Record<string, any>[]}
 */
function decorateProjectTiles(projects, options = {}) {
    if (!Array.isArray(projects) || projects.length === 0) return [];

    const enableGradients = options.enableGradients ?? true;
    const gradientPalette = Array.isArray(options.gradientPalette) && options.gradientPalette.length > 0
        ? options.gradientPalette
        : PROJECT_GRADIENT_PALETTE;
    const decoratedProjects = [];
    const alternatingRowPatterns = [
        [8, 4],
        [4, 8]
    ];
    let projectIndex = 0;
    let patternIndex = 0;
    let hasThreeSmallRow = false;

    while (projectIndex < projects.length) {
        const remainingProjects = projects.length - projectIndex;
        let pattern = alternatingRowPatterns[patternIndex % alternatingRowPatterns.length];

        if (!hasThreeSmallRow && remainingProjects >= 3 && (remainingProjects === 3 || remainingProjects >= 5)) {
            pattern = [4, 4, 4];
            hasThreeSmallRow = true;
        }

        patternIndex += 1;

        for (let slotIndex = 0; slotIndex < pattern.length && projectIndex < projects.length; slotIndex += 1) {
            const sourceProject = projects[projectIndex];
            const project = { ...sourceProject };
            const providedMdSize = Number.parseInt(`${sourceProject.md_size ?? ""}`, 10);
            const providedLgSize = Number.parseInt(`${sourceProject.lg_size ?? ""}`, 10);
            project.md_size = Number.isFinite(providedMdSize) ? providedMdSize : 6;
            project.lg_size = Number.isFinite(providedLgSize) ? providedLgSize : pattern[slotIndex];
            project.tile_gradient = false;
            project.use_contrast_text = false;
            project.tile_primary_color = undefined;
            project.tile_secondary_color = undefined;

            const projectHash = hashString(`${project.heading ?? "project"}-${projectIndex}`);
            const useGradient = enableGradients && ((projectHash % 3 === 0) || pattern.length === 3);
            if (useGradient) {
                const palette = gradientPalette[projectHash % gradientPalette.length];
                project.tile_primary_color = palette.primary;
                project.tile_secondary_color = palette.secondary;
                project.tile_gradient = true;
                project.use_contrast_text = true;
            }

            decoratedProjects.push(project);
            projectIndex += 1;
        }
    }

    return decoratedProjects;
}

/**
 * Render social links section.
 * @param {Record<string, any>} data
 */
function renderSocialLinks(data) {
    const socialsContainer = $("#contact #socials-container");
    if (!socialsContainer) return;

    const socialLinksMarkup = data.socials.map(item => {
        const username = item.username_prefix ? `${item.username_prefix}${item.username}` : item.username;
        return `
            <a href="https://www.${item.platform}.com/${username}" target="_blank" rel="noopener noreferrer"
                class="social-link text-light d-flex flex-row align-items-center m-1"
                aria-label="${item.platform} profile"
            >
                <img src="assets/img/app-icons/app-icon-${item.platform}.png" alt="${item.platform}-icon" class="app-icon m-2" loading="lazy" decoding="async" fetchpriority="low">
                ${item.username_prefix ? username : "@" + item.username}
            </a>
        `;
    }).join("");

    socialsContainer.insertAdjacentHTML("beforeend", socialLinksMarkup);
}

/**
 * Fetch and parse a local JSON resource.
 * @param {string} url
 * @returns {Promise<Record<string, any>>}
 */
async function fetchJSON(url) {
    const response = await fetch(url);

    if (!response.ok) {
        throw new Error(`Failed to fetch ${url}: ${response.status}`);
    }

    return response.json();
}

/**
 * Programmatically opens the contact tile with a prefilled message.
 */
window.requestResume = function requestResume() {
    $("#contact").scrollIntoView(scrollIntoViewOptions);

    const checkbox = $("#contact .plus-go-x>input");
    const message = $("#contact #message");
    if (!checkbox || !message) return;

    message.value = "Hello, I'd like to take a look at your resume.";
    if (checkbox.checked) return;

    checkbox.checked = true;
    checkbox.dispatchEvent(new Event("change"));
};

void initPage();
