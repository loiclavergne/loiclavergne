//
//  appearance.js
//  Loic Lavergne portfolio
//
//  Centralized appearance management:
//  - light / dark / auto mode switching
//  - localStorage persistence
//  - CSS custom-property tuning for contrast and glass rendering
//

import { $, $$ } from "./lib.js";

const navBar = $("#navbar");
const navBarTogglerBreadCrusts = $$("#navbar .navbar-toggler-bread-crust");
const blurBackgroundElements = $$(".bg-blur");
const miscellaneousElements = $$("#main-container, body, footer");
const skillsTile = $("#skills .tile");

const darkModeEnabled = window.matchMedia("(prefers-color-scheme: dark)");
let isSystemListenerBound = false;
let areControlsBound = false;

/**
 * Notify the UI that the effective appearance mode changed.
 * @param {"light" | "dark"} mode
 */
function announceAppearance(mode) {
    document.documentElement.dataset.appearance = mode;
    document.dispatchEvent(new CustomEvent("appearance:changed", {
        detail: { mode }
    }));
}

/**
 * Whether the mobile navbar is currently collapsed.
 * @returns {boolean}
 */
function isNavbarCollapsed() {
    return navBar ? !navBar.classList.contains("not-collapsed") : true;
}

/**
 * Apply a background color to each element in a NodeList.
 * @param {NodeListOf<Element>} elements
 * @param {string} value
 */
function setElementsBackground(elements, value) {
    elements.forEach(element => {
        element.style.backgroundColor = value;
    });
}

/**
 * Add or remove a class for all provided elements.
 * @param {NodeListOf<Element>} elements
 * @param {string} className
 * @param {boolean} shouldHaveClass
 */
function toggleClass(elements, className, shouldHaveClass) {
    elements.forEach(element => {
        element.classList.toggle(className, shouldHaveClass);
    });
}

/**
 * Apply the light appearance.
 */
function applyLightAppearance() {
    navBar?.classList.remove("navbar-dark");
    setElementsBackground(navBarTogglerBreadCrusts, "var(--dark-secondary)");
    setElementsBackground(
        blurBackgroundElements,
        isNavbarCollapsed() ? "var(--nav-background)" : "var(--light-secondary)"
    );

    setElementsBackground(miscellaneousElements, "var(--light-secondary)");
    if (skillsTile) {
        skillsTile.style.background = "linear-gradient(145deg, white 10%, #ffa560 70%)";
    }

    toggleClass($$(".text-matte-light"), "text-matte-dark", true);
    toggleClass($$(".text-light"), "text-dark", true);
    toggleClass($$(".bg-light-secondary"), "bg-dark-secondary", false);
    toggleClass($$(".bg-light"), "bg-dark", false);
    toggleClass($$(".app-icon"), "dark", false);
    announceAppearance("light");
}

/**
 * Apply the dark appearance.
 */
function applyDarkAppearance() {
    navBar?.classList.add("navbar-dark");
    setElementsBackground(navBarTogglerBreadCrusts, "var(--light-secondary)");
    setElementsBackground(
        blurBackgroundElements,
        isNavbarCollapsed() ? "var(--nav-background-dark)" : "var(--dark-secondary)"
    );

    setElementsBackground(miscellaneousElements, "var(--dark-secondary)");
    if (skillsTile) {
        skillsTile.style.background = "var(--dark-secondary)";
    }

    toggleClass($$(".text-matte-light"), "text-matte-dark", false);
    toggleClass($$(".text-light"), "text-dark", false);
    toggleClass($$(".bg-light-secondary"), "bg-dark-secondary", true);
    toggleClass($$(".bg-light"), "bg-dark", true);
    toggleClass($$(".app-icon"), "dark", true);
    announceAppearance("dark");
}

/**
 * Apply light or dark depending on the operating system setting.
 */
function applyAutoAppearance() {
    if (!isSystemListenerBound) {
        darkModeEnabled.addEventListener("change", event => {
            if (getPreferredAppearance() === "auto") {
                event.matches ? applyDarkAppearance() : applyLightAppearance();
            }
        });
        isSystemListenerBound = true;
    }

    darkModeEnabled.matches ? applyDarkAppearance() : applyLightAppearance();
}

/**
 * Get the persisted appearance preference.
 * @returns {"light" | "dark" | "auto"}
 */
function getPreferredAppearance() {
    return /** @type {"light" | "dark" | "auto"} */ (window.localStorage.getItem("appearance") ?? "auto");
}

/**
 * Set active state on toggle pills.
 * @param {"light" | "dark" | "auto"} preferredAppearance
 */
function setActiveToggle(preferredAppearance) {
    $$("#appearance-toggle .nav .nav-link.active").forEach(link => link.classList.remove("active"));
    $(`#${preferredAppearance}-appearance`)?.classList.add("active");
}

/**
 * Set preferred appearance and persist it.
 * @param {"light" | "dark" | "auto"} appearance
 */
function setPreferredAppearance(appearance) {
    const preferredAppearance = appearance.toLowerCase();

    switch (preferredAppearance) {
        case "light":
            applyLightAppearance();
            break;
        case "dark":
            applyDarkAppearance();
            break;
        case "auto":
        default:
            applyAutoAppearance();
            break;
    }

    setActiveToggle(preferredAppearance);
    window.localStorage.setItem("appearance", preferredAppearance);
}

/**
 * Initialize appearance event listeners.
 */
function initAppearanceControls() {
    if (areControlsBound) return;

    $("#light-appearance")?.addEventListener("click", () => setPreferredAppearance("light"));
    $("#dark-appearance")?.addEventListener("click", () => setPreferredAppearance("dark"));
    $("#auto-appearance")?.addEventListener("click", () => setPreferredAppearance("auto"));
    areControlsBound = true;
}

/**
 * Re-apply the persisted appearance preference.
 */
export function refreshAppearance() {
    initAppearanceControls();
    setPreferredAppearance(getPreferredAppearance());
}

/**
 * Resolve whether dark mode is effectively enabled.
 * @returns {boolean}
 */
export function isDarkModeEnabled() {
    if (getPreferredAppearance() === "auto") {
        return darkModeEnabled.matches;
    }
    return getPreferredAppearance() === "dark";
}
