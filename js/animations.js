//
//  animations.js
//  Loic Lavergne portfolio
//
//  Handles interaction and motion systems:
//  - navbar collapse behavior
//  - section/tile entrance animations
//  - "+" to "x" overlay transitions
//

import { isDarkModeEnabled } from "./appearance.js";
import { $, $$ } from "./lib.js";

const sections = {
    greeting: $("#greeting"),
    intro: $("#intro"),
    skills: $("#skills"),
    projects: $("#projects"),
    contact: $("#contact")
};

const sendIcon = $("#send-icon");
const navbar = $("#navbar");
const navbarGlassCapsule = $("#navbar .bg-blur") ?? $("#navbar.bg-blur");
const navbarContent = $("#navbar-content");
const title = $("#title");
const mainContainer = $("#main-container");

const scrollIntoViewOptions = {
    behavior: "auto",
    block: "start"
};

/**
 * Apply a CSS animation string to each element in a list.
 * @param {NodeListOf<Element>} elements
 * @param {string} animation
 */
function setAnimation(elements, animation) {
    elements.forEach(element => {
        element.style.animation = animation;
    });
}

/**
 * Build and attach an intersection observer for a target element.
 * @param {Element | null} element
 * @param {IntersectionObserverCallback} callback
 */
function observeElement(element, callback) {
    if (!element) return;

    const observer = new IntersectionObserver(callback, {
        root: null,
        rootMargin: "0px",
        threshold: 0.1
    });

    observer.observe(element);
}

/**
 * Keep navbar glass color in sync with current mode and state.
 */
function refreshNavbarGlassColor() {
    if (!navbarGlassCapsule) return;
    navbarGlassCapsule.style.backgroundColor = isDarkModeEnabled()
        ? "var(--nav-background-dark)"
        : "var(--nav-background)";
}

/**
 * Bind mobile navbar open/close animation behavior.
 */
function initNavbarCollapseBehavior() {
    if (!navbarContent || !title || !mainContainer || !navbar) return;

    navbarContent.addEventListener("show.bs.collapse", () => {
        document.body.style.overflow = "hidden";
        title.style.pointerEvents = "none";
        title.style.animation = "fade_out 0.25s ease-in-out both";
        navbarContent.classList.remove("collapsing-out");
        navbarContent.classList.add("collapsing-in");
        refreshNavbarGlassColor();
        navbar.classList.add("not-collapsed");
        mainContainer.style.opacity = "0";
    });

    navbarContent.addEventListener("hide.bs.collapse", () => {
        document.body.style.overflow = "auto";
        title.style.pointerEvents = "auto";
        title.style.animation = "fade_in 0.25s 0.25s ease-in-out both";
        navbarContent.classList.remove("collapsing-in");
        navbarContent.classList.add("collapsing-out");

        setTimeout(refreshNavbarGlassColor, 100);
        navbar.classList.remove("not-collapsed");
        mainContainer.style.opacity = "1";
    });

    // Collapse mobile menu only when crossing the breakpoint to desktop.
    const desktopBreakpoint = window.matchMedia("(min-width: 576px)");
    const collapseIfDesktop = event => {
        const shouldCollapse = "matches" in event
            ? event.matches
            : desktopBreakpoint.matches;

        if (!shouldCollapse || !navbarContent.classList.contains("show")) return;
        const collapse = bootstrap.Collapse.getOrCreateInstance(navbarContent, { toggle: false });
        collapse.hide();
    };

    if (typeof desktopBreakpoint.addEventListener === "function") {
        desktopBreakpoint.addEventListener("change", collapseIfDesktop);
    } else {
        desktopBreakpoint.addListener(collapseIfDesktop);
    }
}

/**
 * Observe static page sections and attach one-off motion effects.
 */
function initSectionObservers() {
    observeElement(sections.greeting, entries => {
        if (!entries[0].isIntersecting) return;
        const greetingMemoji = $("#greeting .memoji");
        if (greetingMemoji) {
            greetingMemoji.style.animation = "slide_in 2s both 0.25s";
        }
        setAnimation($$("#greeting .text-white"), "fade_in 2s both 0.5s");
    });

    observeElement($("#skills .row .col"), entries => {
        const rows = $$(".technologies-row");
        if (entries[0].isIntersecting) {
            const animationName = window.matchMedia("(max-width: 767px)").matches
                ? "scroll_mobile"
                : "scroll";

            rows.forEach((row, index) => {
                row.style.animation = `${animationName} ${60 * (3 - index) / 2}s linear infinite`;
            });
            return;
        }
        setAnimation(rows, "none");
    });

    observeElement(sendIcon, entries => {
        if (entries[0].isIntersecting) {
            sendIcon.style.animation = "slide_diag_up 0.75s both 0.5s";
        }
    });

    const headings = $$(".section-inner-container > h2, .section-inner-container > div > h2, .section-inner-container > div > a");
    headings.forEach(heading => {
        observeElement(heading, (entries, observer) => {
            if (!entries[0].isIntersecting) return;
            heading.style.animation = "slide_in 0.75s ease-out both";
            observer.unobserve(heading);
        });
    });
}

/**
 * Attach section navigation click handlers.
 */
function initSectionNavigation() {
    title?.addEventListener("click", () => {
        sections.greeting?.scrollIntoView(scrollIntoViewOptions);
    });

    $$(".goto-intro").forEach(item => {
        item.addEventListener("click", () => sections.intro?.scrollIntoView(scrollIntoViewOptions));
    });
    $(".goto-skills")?.addEventListener("click", () => sections.skills?.scrollIntoView(scrollIntoViewOptions));
    $(".goto-projects")?.addEventListener("click", () => sections.projects?.scrollIntoView(scrollIntoViewOptions));

    $$(".goto-contact").forEach(item => {
        item.addEventListener("click", event => {
            event.preventDefault();
            sections.contact?.scrollIntoView(scrollIntoViewOptions);
        });
    });
}

/**
 * Bind delegated change handling for all expandable "+" controls.
 * Works for both static and dynamically rendered tiles.
 */
function initPlusToggleDelegation() {
    document.addEventListener("change", event => {
        const target = event.target;
        if (!(target instanceof HTMLInputElement)) return;
        if (!target.matches(".plus-go-x > input")) return;

        if (target.closest("#timeline")) {
            if (typeof window.timelinePlusGoXHandler === "function") {
                window.timelinePlusGoXHandler(event);
            }
            return;
        }

        if (target.closest("#contact")) {
            window.contactPlusGoXHandler(event);
            return;
        }
        window.plusGoXHandler(event);
    });
}

/**
 * Toggle the overlay state for a tile using the "+" control.
 * @param {Event} event
 */
window.plusGoXHandler = function plusGoXHandler(event) {
    const easingFunctions = [
        "cubic-bezier(0.7, 0, 0.2, 1)",
        "cubic-bezier(0.66, 0, 0.01, 1)",
        "cubic-bezier(0.66, 0, 0.2, 1)"
    ];

    const checkbox = /** @type {HTMLInputElement} */ (event.target);
    const label = checkbox.parentElement;
    const icon = label?.querySelector("div");
    if (!label || !icon || icon.classList.contains("animating")) return;

    icon.classList.add("animating");

    const container = label.parentElement;
    const tile = container?.closest(".tile");
    if (!tile) {
        icon.classList.remove("animating");
        return;
    }

    const tileTitle = tile.querySelector("h5");
    const tileContent = tile.querySelectorAll(".tile-content");
    const tileOverlay = tile.querySelector(".tile-overlay");
    const tileOverlayBackground = tile.querySelector(".tile-overlay-background");

    if (!tileOverlay || !tileOverlayBackground) {
        icon.classList.remove("animating");
        return;
    }

    if (!tileTitle) {
        icon.classList.remove("animating");
        return;
    }

    if (checkbox.checked) {
        checkbox.setAttribute("aria-expanded", "true");
        icon.style.animation = `make_x 0.65s ${easingFunctions[0]} both`;
        tileTitle.classList.add("text-white-animated");

        setTimeout(() => {
            setAnimation(tileContent, "fade_out 0.45s both");
            tileOverlayBackground.style.animation = `fade_in 0.65s ${easingFunctions[1]} both`;
            label.classList.add("checked");

            setTimeout(() => {
                tileOverlay.classList.add("text-white-animated");
                tileOverlay.classList.remove("d-none");
                tileOverlay.style.animation = `slide_in_down 0.65s ${easingFunctions[2]} both`;
                icon.classList.remove("animating");
            }, 650);
        }, 100);
        return;
    }

    checkbox.setAttribute("aria-expanded", "false");
    icon.style.animation = `make_plus 0.65s ${easingFunctions[0]} both`;
    tileOverlay.style.animation = `slide_out_up 0.65s ${easingFunctions[2]} both`;

    setTimeout(() => {
        tileOverlay.classList.add("d-none");
        tileOverlay.classList.remove("text-white-animated");
        tileOverlayBackground.style.animation = `fade_out 0.65s ${easingFunctions[1]} both`;
        setAnimation(tileContent, "fade_in 0.55s both 0.15s");
        tileTitle.classList.remove("text-white-animated");

        setTimeout(() => {
            label.classList.remove("checked");
            icon.classList.remove("animating");
        }, 150);
    }, 650);
};

/**
 * Contact tile variant of plusGoXHandler with icon-specific motion.
 * @param {Event} event
 */
window.contactPlusGoXHandler = function contactPlusGoXHandler(event) {
    window.plusGoXHandler(event);

    if (!sendIcon) return;
    if ((/** @type {HTMLInputElement} */ (event.target)).checked) {
        sendIcon.style.animation = "slide_out_diag_up 0.75s both 0s";
        return;
    }
    setTimeout(() => {
        sendIcon.style.animation = "slide_diag_up 0.75s both 0s";
    }, 750);
};

/**
 * Initialize scroll-triggered animations for tiles and timeline entries.
 */
export function initAnimations() {
    initNavbarCollapseBehavior();
    initSectionObservers();
    initSectionNavigation();
    initPlusToggleDelegation();

    ["#intro", "#skills", "#projects", "#contact"].forEach(sectionSelector => {
        const sectionTiles = Array.from($$(`${sectionSelector} .tile`))
            .filter(tile => !(sectionSelector === "#intro" && tile.classList.contains("timeline-tile")));
        const totalTiles = sectionTiles.length;

        sectionTiles.forEach((tile, index) => {
            let delay = 0;
            if (totalTiles === 1) {
                delay = 0;
            } else if (totalTiles % 2 === 0) {
                delay = index % 2 === 0 ? 0.1 : 0.2;
            } else {
                delay = index === 0 ? 0 : ((index - 1) % 2 === 0 ? 0.1 : 0.2);
            }

            observeElement(tile, (entries, observer) => {
                if (!entries[0].isIntersecting) return;
                tile.style.animation = `slide_in 0.5s ease-out both ${delay * 1.25}s`;
                observer.unobserve(tile);
            });
        });
    });

}
