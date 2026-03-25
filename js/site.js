//
//  site.js
//  Loic Engineer Portfolio
//
//  Created by Loïc Lavergne on 25/03/2026
//  Copyright © 2026 Loïc Lavergne. All rights reserved.
//
//  Progressive enhancement for:
//  - appearance switching
//  - reveal-on-view behavior
//  - homepage story panel activation
//

const THEME_STORAGE_KEY = "loic.engineer.theme";
const systemThemeQuery = window.matchMedia("(prefers-color-scheme: dark)");
const reducedMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

/**
 * Read from localStorage without breaking when storage is unavailable.
 * @returns {string | null}
 */
function readStoredValue() {
  try {
    return window.localStorage.getItem(THEME_STORAGE_KEY);
  } catch (error) {
    return null;
  }
}

/**
 * Resolve the saved or default theme preference.
 * @returns {"auto" | "light" | "dark"}
 */
function getStoredTheme() {
  const stored = readStoredValue();
  if (stored === "light" || stored === "dark" || stored === "auto") {
    return stored;
  }
  return "auto";
}

/**
 * Resolve the effective light or dark theme.
 * @param {"auto" | "light" | "dark"} selection
 * @returns {"light" | "dark"}
 */
function getResolvedTheme(selection) {
  if (selection === "auto") {
    return systemThemeQuery.matches ? "dark" : "light";
  }
  return selection;
}

/**
 * Update the active appearance state on the document.
 * @param {"auto" | "light" | "dark"} selection
 */
function applyTheme(selection) {
  const resolvedTheme = getResolvedTheme(selection);
  document.documentElement.dataset.theme = selection;
  document.documentElement.dataset.resolvedTheme = resolvedTheme;

  document.querySelectorAll("[data-theme-control]").forEach((button) => {
    const isActive = button.getAttribute("data-theme-control") === selection;
    button.setAttribute("aria-pressed", String(isActive));
  });
}

/**
 * Persist and apply a theme selection.
 * @param {"auto" | "light" | "dark"} selection
 */
function setTheme(selection) {
  try {
    window.localStorage.setItem(THEME_STORAGE_KEY, selection);
  } catch (error) {
    // Ignore storage failures and still apply the theme for the current session.
  }
  applyTheme(selection);
}

/**
 * Initialize the appearance switcher.
 */
function initThemeControls() {
  applyTheme(getStoredTheme());

  document.querySelectorAll("[data-theme-control]").forEach((button) => {
    button.addEventListener("click", () => {
      const selection = /** @type {"auto" | "light" | "dark"} */ (button.getAttribute("data-theme-control"));
      setTheme(selection);
    });
  });

  systemThemeQuery.addEventListener("change", () => {
    if (getStoredTheme() === "auto") {
      applyTheme("auto");
    }
  });
}

/**
 * Toggle the elevated header style after the page scrolls.
 */
function initHeaderState() {
  const header = document.querySelector("[data-header]");
  if (!header) return;

  const syncHeader = () => {
    header.classList.toggle("is-scrolled", window.scrollY > 12);
  };

  syncHeader();
  window.addEventListener("scroll", syncHeader, { passive: true });
}

/**
 * Reveal cards and sections as they enter the viewport.
 */
function initRevealObserver() {
  const revealTargets = document.querySelectorAll(".reveal");
  if (!revealTargets.length || reducedMotionQuery.matches) {
    revealTargets.forEach((item) => item.classList.add("is-visible"));
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    },
    {
      threshold: 0.18,
      rootMargin: "0px 0px -8% 0px",
    },
  );

  revealTargets.forEach((target) => observer.observe(target));
}

/**
 * Activate the story panel that matches the currently visible story step.
 */
function initStoryPanels() {
  if (document.body.dataset.page !== "home") return;

  const steps = Array.from(document.querySelectorAll("[data-story-step]"));
  const panels = Array.from(document.querySelectorAll("[data-story-panel]"));
  if (!steps.length || !panels.length) return;

  const activatePanel = (storyId) => {
    panels.forEach((panel) => {
      const isActive = panel.getAttribute("data-story-panel") === storyId;
      panel.classList.toggle("is-active", isActive);
    });
  };

  activatePanel(steps[0].getAttribute("data-story-id"));

  if (reducedMotionQuery.matches) return;

  const observer = new IntersectionObserver(
    (entries) => {
      const visibleEntries = entries
        .filter((entry) => entry.isIntersecting)
        .sort((left, right) => right.intersectionRatio - left.intersectionRatio);

      if (!visibleEntries.length) return;
      const activeStep = visibleEntries[0].target;
      activatePanel(activeStep.getAttribute("data-story-id"));
    },
    {
      threshold: [0.3, 0.45, 0.65],
      rootMargin: "-18% 0px -34% 0px",
    },
  );

  steps.forEach((step) => observer.observe(step));
}

document.addEventListener("DOMContentLoaded", () => {
  initThemeControls();
  initHeaderState();
  initRevealObserver();
  initStoryPanels();
});
