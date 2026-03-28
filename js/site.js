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
//  - command-palette search
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

/**
 * Normalize text for accent-insensitive search comparisons.
 * @param {string} value
 * @returns {string}
 */
function normalizeSearchValue(value) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}

/**
 * Determine whether the current event target is editable.
 * @param {EventTarget | null} target
 * @returns {boolean}
 */
function isEditableTarget(target) {
  if (!(target instanceof HTMLElement)) return false;
  if (target.isContentEditable) return true;
  return target instanceof HTMLInputElement
    || target instanceof HTMLTextAreaElement
    || target instanceof HTMLSelectElement;
}

/**
 * Initialize the static command-palette search.
 */
function initSearchPalette() {
  const openButton = document.querySelector("[data-search-open]");
  const modal = document.querySelector("[data-search-modal]");
  const input = document.querySelector("[data-search-input]");
  const status = document.querySelector("[data-search-status]");
  const results = document.querySelector("[data-search-results]");
  const configNode = document.getElementById("search-config");
  const shellElements = Array.from(document.querySelectorAll("[data-header], main, .site-footer"));

  if (!openButton || !modal || !input || !status || !results || !configNode) {
    return;
  }

  const focusableSelector = [
    "a[href]",
    "button:not([disabled])",
    "input:not([disabled])",
    "select:not([disabled])",
    "textarea:not([disabled])",
    "[tabindex]:not([tabindex='-1'])",
  ].join(", ");

  /** @type {{
   *   close: string,
   *   emptyState: string,
   *   hint: string,
   *   indexURL: string,
   *   loading: string,
   *   noResults: string,
   *   placeholder: string,
   *   resultsLabel: string,
   *   sectionLabels: Record<string, string>,
   *   title: string
   * }} */
  let config;

  try {
    config = JSON.parse(configNode.textContent ?? "{}");
  } catch (error) {
    return;
  }

  /** @type {Array<{description: string, kind: string, locale: string, route: string, section: string, title: string}>} */
  let allItems = [];
  /** @type {Array<{description: string, kind: string, locale: string, route: string, section: string, title: string}>} */
  let visibleItems = [];
  /** @type {Promise<Array<{description: string, kind: string, locale: string, route: string, section: string, title: string}>> | null} */
  let loadPromise = null;
  let activeIndex = -1;
  let lastTrigger = /** @type {HTMLElement | null} */ (null);
  let lockedScrollY = 0;

  /**
   * @param {string} message
   */
  function setStatus(message) {
    status.textContent = message;
  }

  /**
   * @param {boolean} isExpanded
   */
  function setExpanded(isExpanded) {
    openButton.setAttribute("aria-expanded", String(isExpanded));
  }

  /**
   * Keep the background shell inert while the modal is open.
   * @param {boolean} isInactive
   */
  function setBackgroundInteractivity(isInactive) {
    shellElements.forEach((element) => {
      if (!(element instanceof HTMLElement)) return;

      if ("inert" in element) {
        element.inert = isInactive;
      }

      if (isInactive) {
        element.setAttribute("aria-hidden", "true");
      } else {
        element.removeAttribute("aria-hidden");
      }
    });
  }

  /**
   * Lock page scrolling in a Safari-friendly way.
   */
  function lockScroll() {
    lockedScrollY = window.scrollY;
    document.body.classList.add("search-open");
    document.body.style.position = "fixed";
    document.body.style.top = `-${lockedScrollY}px`;
    document.body.style.left = "0";
    document.body.style.right = "0";
    document.body.style.width = "100%";
  }

  /**
   * Restore page scrolling after the modal closes.
   */
  function unlockScroll() {
    document.body.classList.remove("search-open");
    document.body.style.position = "";
    document.body.style.top = "";
    document.body.style.left = "";
    document.body.style.right = "";
    document.body.style.width = "";
    window.scrollTo(0, lockedScrollY);
  }

  /**
   * Find focusable elements within the modal.
   * @returns {HTMLElement[]}
   */
  function focusableNodes() {
    return Array.from(modal.querySelectorAll(focusableSelector)).filter((element) => {
      if (!(element instanceof HTMLElement)) return false;
      return !element.hasAttribute("disabled") && element.getClientRects().length > 0;
    });
  }

  function focusSearchInput() {
    window.requestAnimationFrame(() => {
      input.focus({ preventScroll: true });
      input.select();
    });
  }

  /**
   * @returns {Array<{description: string, kind: string, locale: string, route: string, section: string, title: string}>}
   */
  function defaultItems() {
    return allItems
      .filter((item) => item.kind === "page")
      .concat(allItems.filter((item) => item.kind === "project"))
      .slice(0, 8);
  }

  /**
   * @param {{description: string, kind: string, locale: string, route: string, section: string, title: string}} item
   * @param {string} query
   * @returns {number}
   */
  function scoreItem(item, query) {
    const title = normalizeSearchValue(item.title);
    const description = normalizeSearchValue(item.description);
    const route = normalizeSearchValue(item.route);
    let score = 0;

    if (title.startsWith(query)) score += 100;
    if (title.includes(query)) score += 60;
    if (description.includes(query)) score += 25;
    if (route.includes(query)) score += 10;
    if (item.kind === "page") score += 6;

    return score;
  }

  /**
   * @param {string} query
   * @returns {Array<{description: string, kind: string, locale: string, route: string, section: string, title: string}>}
   */
  function matchingItems(query) {
    if (!query) {
      return defaultItems();
    }

    return allItems
      .map((item) => ({ item, score: scoreItem(item, query) }))
      .filter((entry) => entry.score > 0)
      .sort((left, right) => right.score - left.score)
      .map((entry) => entry.item)
      .slice(0, 8);
  }

  function syncActiveResult() {
    const links = Array.from(results.querySelectorAll(".search-result"));
    links.forEach((link, index) => {
      const isActive = index === activeIndex;
      link.classList.toggle("is-active", isActive);
      link.setAttribute("aria-current", isActive ? "true" : "false");
      if (isActive) {
        link.scrollIntoView({ block: "nearest" });
      }
    });
  }

  /**
   * @param {string} query
   */
  function renderResults(query) {
    visibleItems = matchingItems(query);
    activeIndex = -1;
    results.replaceChildren();

    if (!visibleItems.length) {
      setStatus(query ? config.noResults : config.emptyState);
      return;
    }

    setStatus(query ? config.resultsLabel : config.emptyState);

    results.replaceChildren(...visibleItems.map((item, index) => {
      const listItem = document.createElement("li");
      listItem.className = "search-results__item";

      const link = document.createElement("a");
      link.className = "search-result";
      link.href = item.route;
      link.dataset.searchResult = String(index);

      const meta = document.createElement("span");
      meta.className = "search-result__meta";
      meta.textContent = config.sectionLabels[item.section] ?? item.section;

      const title = document.createElement("span");
      title.className = "search-result__title";
      title.textContent = item.title;

      const description = document.createElement("span");
      description.className = "search-result__description";
      description.textContent = item.description;

      link.append(meta, title, description);
      link.addEventListener("mouseenter", () => {
        activeIndex = index;
        syncActiveResult();
      });

      listItem.append(link);
      return listItem;
    }));
  }

  /**
   * @returns {Promise<Array<{description: string, kind: string, locale: string, route: string, section: string, title: string}>>}
   */
  function loadIndex() {
    if (allItems.length) {
      return Promise.resolve(allItems);
    }

    if (loadPromise) {
      return loadPromise;
    }

    setStatus(config.loading);

    loadPromise = fetch(config.indexURL, {
      headers: {
        Accept: "application/json",
      },
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error("Search index request failed.");
        }
        return response.json();
      })
      .then((payload) => {
        allItems = Array.isArray(payload.items) ? payload.items : [];
        return allItems;
      })
      .catch(() => {
        allItems = [];
        setStatus(config.noResults);
        return allItems;
      })
      .finally(() => {
        loadPromise = null;
      });

    return loadPromise;
  }

  /**
   * @param {HTMLElement} trigger
   */
  function openSearch(trigger) {
    if (!modal.hidden) {
      focusSearchInput();
      return;
    }

    lastTrigger = trigger;
    modal.hidden = false;
    lockScroll();
    setBackgroundInteractivity(true);
    setExpanded(true);

    void loadIndex().then(() => {
      renderResults(normalizeSearchValue(input.value));
    });

    focusSearchInput();
  }

  function closeSearch() {
    if (modal.hidden) return;

    modal.hidden = true;
    setBackgroundInteractivity(false);
    unlockScroll();
    setExpanded(false);
    input.value = "";
    visibleItems = [];
    activeIndex = -1;
    results.replaceChildren();
    setStatus(config.emptyState);
    lastTrigger?.focus({ preventScroll: true });
  }

  openButton.addEventListener("click", () => {
    openSearch(openButton);
  });

  modal.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    if (target.closest("[data-search-close]")) {
      closeSearch();
    }
  });

  input.addEventListener("input", async () => {
    await loadIndex();
    renderResults(normalizeSearchValue(input.value));
  });

  input.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      event.preventDefault();
      closeSearch();
      return;
    }

    if (event.key === "ArrowDown") {
      if (!visibleItems.length) return;
      event.preventDefault();
      activeIndex = Math.min(activeIndex + 1, visibleItems.length - 1);
      syncActiveResult();
      return;
    }

    if (event.key === "ArrowUp") {
      if (!visibleItems.length) return;
      event.preventDefault();
      activeIndex = Math.max(activeIndex - 1, 0);
      syncActiveResult();
      return;
    }

    if (event.key === "Enter" && activeIndex >= 0 && visibleItems[activeIndex]) {
      event.preventDefault();
      window.location.href = visibleItems[activeIndex].route;
    }
  });

  modal.addEventListener("keydown", (event) => {
    if (event.key !== "Tab") return;

    const focusables = focusableNodes();
    if (!focusables.length) return;

    const first = focusables[0];
    const last = focusables[focusables.length - 1];
    const activeElement = document.activeElement;

    if (!(activeElement instanceof HTMLElement) || !modal.contains(activeElement)) {
      event.preventDefault();
      first.focus({ preventScroll: true });
      return;
    }

    if (event.shiftKey && activeElement === first) {
      event.preventDefault();
      last.focus({ preventScroll: true });
      return;
    }

    if (!event.shiftKey && activeElement === last) {
      event.preventDefault();
      first.focus({ preventScroll: true });
    }
  });

  document.addEventListener("keydown", (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault();
      openSearch(openButton);
      return;
    }

    if (event.key === "/" && !event.metaKey && !event.ctrlKey && !event.altKey) {
      if (!modal.hidden || isEditableTarget(event.target)) {
        return;
      }

      event.preventDefault();
      openSearch(openButton);
      return;
    }

    if (event.key === "Escape" && !modal.hidden) {
      event.preventDefault();
      closeSearch();
    }
  });
}

document.addEventListener("DOMContentLoaded", () => {
  initThemeControls();
  initHeaderState();
  initRevealObserver();
  initStoryPanels();
  initSearchPalette();
});
