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
const SEARCH_RECENT_STORAGE_KEY = "loic.engineer.search.recent";
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
 * Split a normalized query into searchable tokens.
 * @param {string} value
 * @returns {string[]}
 */
function tokenizeSearchValue(value) {
  return normalizeSearchValue(value)
    .split(/\s+/)
    .filter(Boolean);
}

/**
 * Build a normalized character map for accent-insensitive highlighting.
 * @param {string} value
 * @returns {{normalized: string, sourceIndexes: number[]}}
 */
function normalizedCharacterMap(value) {
  let normalized = "";
  const sourceIndexes = [];

  for (let index = 0; index < value.length; index += 1) {
    const fragment = value[index]
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase();

    for (const char of fragment) {
      normalized += char;
      sourceIndexes.push(index);
    }
  }

  return { normalized, sourceIndexes };
}

/**
 * Compute merged highlight ranges for a string and normalized query tokens.
 * @param {string} value
 * @param {string[]} tokens
 * @returns {Array<{start: number, end: number}>}
 */
function highlightRanges(value, tokens) {
  if (!tokens.length) {
    return [];
  }

  const { normalized, sourceIndexes } = normalizedCharacterMap(value);
  /** @type {Array<{start: number, end: number}>} */
  const ranges = [];

  for (const token of tokens) {
    if (!token) continue;

    let searchIndex = 0;
    while (searchIndex < normalized.length) {
      const matchIndex = normalized.indexOf(token, searchIndex);
      if (matchIndex === -1) break;

      const start = sourceIndexes[matchIndex];
      const end = sourceIndexes[matchIndex + token.length - 1] + 1;
      ranges.push({ start, end });
      searchIndex = matchIndex + token.length;
    }
  }

  if (!ranges.length) {
    return [];
  }

  ranges.sort((left, right) => left.start - right.start || left.end - right.end);

  /** @type {Array<{start: number, end: number}>} */
  const merged = [ranges[0]];
  for (const range of ranges.slice(1)) {
    const previous = merged[merged.length - 1];
    if (range.start <= previous.end) {
      previous.end = Math.max(previous.end, range.end);
    } else {
      merged.push({ ...range });
    }
  }

  return merged;
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
  const clearButton = document.querySelector("[data-search-clear]");
  const assist = document.querySelector("[data-search-assist]");
  const status = document.querySelector("[data-search-status]");
  const results = document.querySelector("[data-search-results]");
  const configNode = document.getElementById("search-config");
  const shellElements = Array.from(document.querySelectorAll("[data-header], main, .site-footer"));

  if (!openButton || !modal || !input || !clearButton || !assist || !status || !results || !configNode) {
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
   *   actionItems: Array<{action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}>,
   *   clearRecent: string,
   *   close: string,
   *   emptyState: string,
   *   fallbackItems: Array<{action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}>,
   *   fallbackNote: string,
   *   hint: string,
   *   indexURL: string,
   *   locale: string,
   *   loading: string,
   *   noResults: string,
   *   placeholder: string,
   *   recentLabel: string,
   *   recoveryLabel: string,
   *   resultsCountOne: string,
   *   resultsCountOther: string,
   *   resultsLabel: string,
   *   sectionLabels: Record<string, string>,
   *   suggestedLabel: string,
   *   title: string,
   *   unavailable: string
   * }} */
  let config;

  try {
    config = JSON.parse(configNode.textContent ?? "{}");
  } catch (error) {
    return;
  }

  /** @type {Array<{action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}>} */
  let allItems = [];
  /** @type {Array<{action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}>} */
  let visibleItems = [];
  /** @type {Promise<Array<{action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}>> | null} */
  let loadPromise = null;
  let activeIndex = -1;
  let lastTrigger = /** @type {HTMLElement | null} */ (null);
  let lockedScrollY = 0;
  let hasAttemptedLoad = false;
  let loadFailed = false;

  /**
   * @param {string} message
   */
  function setStatus(message) {
    status.textContent = message;
  }

  /**
   * Show or hide the secondary assist line below the main status.
   * @param {string} message
   */
  function setAssist(message = "") {
    const hasMessage = message.trim().length > 0;
    assist.hidden = !hasMessage;
    assist.textContent = hasMessage ? message : "";
  }

  /**
   * Replace tokenized placeholders in localized strings.
   * @param {string} template
   * @param {Record<string, string | number>} replacements
   * @returns {string}
   */
  function formatTemplate(template, replacements) {
    return template.replace(/\{\{(\w+)\}\}/g, (match, key) => {
      if (!(key in replacements)) return match;
      return String(replacements[key]);
    });
  }

  /**
   * Build a localized count label for visible results.
   * @param {number} count
   * @returns {string}
   */
  function resultCountMessage(count) {
    const template = count === 1 ? config.resultsCountOne : config.resultsCountOther;
    return formatTemplate(template, { count });
  }

  /**
   * @param {boolean} isExpanded
   */
  function setExpanded(isExpanded) {
    openButton.setAttribute("aria-expanded", String(isExpanded));
    input.setAttribute("aria-expanded", String(isExpanded));
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
      return !element.hasAttribute("disabled") && element.tabIndex >= 0 && element.getClientRects().length > 0;
    });
  }

  function focusSearchInput() {
    window.requestAnimationFrame(() => {
      input.focus({ preventScroll: true });
      input.select();
    });
  }

  /**
   * Resolve the locale-scoped storage key for recent destinations.
   * @returns {string}
   */
  function recentStorageKey() {
    return `${SEARCH_RECENT_STORAGE_KEY}.${config.locale}`;
  }

  /**
   * Read recent destination routes without breaking when storage is unavailable.
   * @returns {string[]}
   */
  function readRecentRoutes() {
    try {
      const stored = window.localStorage.getItem(recentStorageKey());
      if (!stored) return [];

      const parsed = JSON.parse(stored);
      if (!Array.isArray(parsed)) return [];

      return parsed.filter((value) => typeof value === "string" && value.startsWith("/"));
    } catch (error) {
      return [];
    }
  }

  /**
   * Persist a route in the locale-scoped recent destination list.
   * @param {string} route
   */
  function storeRecentRoute(route) {
    if (!route.startsWith("/")) return;

    try {
      const deduped = [route].concat(readRecentRoutes().filter((item) => item !== route)).slice(0, 5);
      window.localStorage.setItem(recentStorageKey(), JSON.stringify(deduped));
    } catch (error) {
      // Ignore storage failures and keep the search experience functional.
    }
  }

  /**
   * Remove all locale-scoped recent destinations.
   */
  function clearRecentRoutes() {
    try {
      window.localStorage.removeItem(recentStorageKey());
    } catch (error) {
      // Ignore storage failures and keep the search experience functional.
    }
  }

  /**
   * Close the palette and restore the shell without changing routes.
   */
  function dismissSearch() {
    modal.hidden = true;
    setBackgroundInteractivity(false);
    unlockScroll();
    setExpanded(false);
    input.value = "";
    syncClearButton();
    visibleItems = [];
    activeIndex = -1;
    results.replaceChildren();
    input.removeAttribute("aria-activedescendant");
    setStatus(config.emptyState);
    setAssist("");
  }

  /**
   * Keep the localized clear action in sync with the input state.
   */
  function syncClearButton() {
    const isEmpty = input.value.trim().length === 0;
    clearButton.hidden = isEmpty;
    clearButton.disabled = isEmpty;
  }

  /**
   * Render highlighted text into a node using normalized query tokens.
   * @param {HTMLElement} node
   * @param {string} value
   * @param {string[]} tokens
   */
  function appendHighlightedText(node, value, tokens) {
    node.replaceChildren();

    const ranges = highlightRanges(value, tokens);
    if (!ranges.length) {
      node.textContent = value;
      return;
    }

    let cursor = 0;
    for (const range of ranges) {
      if (cursor < range.start) {
        node.append(document.createTextNode(value.slice(cursor, range.start)));
      }

      const mark = document.createElement("mark");
      mark.textContent = value.slice(range.start, range.end);
      node.append(mark);
      cursor = range.end;
    }

    if (cursor < value.length) {
      node.append(document.createTextNode(value.slice(cursor)));
    }
  }

  /**
   * Return the best available item set for search and suggestions.
   * @returns {Array<{action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}>}
   */
  function searchItems() {
    const contentItems = allItems.length ? allItems : config.fallbackItems;
    return config.actionItems.concat(contentItems);
  }

  /**
   * Resolve the stored recent routes against the current locale item set.
   * @returns {Array<{action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}>}
   */
  function recentItems() {
    const itemsByRoute = new Map(
      searchItems()
        .filter((item) => typeof item.route === "string" && item.route.startsWith("/"))
        .map((item) => [item.route, item]),
    );
    return readRecentRoutes()
      .map((route) => itemsByRoute.get(route))
      .filter(Boolean);
  }

  /**
   * @returns {Array<{action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}>}
   */
  function defaultItems() {
    const recent = recentItems();
    const recentRoutes = new Set(recent.map((item) => item.route).filter(Boolean));
    const actionItems = config.actionItems;
    const suggestions = searchItems()
      .filter((item) => item.kind === "page")
      .concat(searchItems().filter((item) => item.kind === "project"))
      .filter((item) => !recentRoutes.has(item.route));

    return recent
      .concat(actionItems)
      .concat(suggestions)
      .slice(0, 8);
  }

  /**
   * @param {{action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}} item
   * @param {string} query
   * @param {string[]} queryTokens
   * @returns {number}
   */
  function scoreItem(item, query, queryTokens) {
    const title = normalizeSearchValue(item.title);
    const description = normalizeSearchValue(item.description);
    const route = normalizeSearchValue(item.route ?? "");
    const sectionLabel = normalizeSearchValue(config.sectionLabels[item.section] ?? item.section);
    const fields = [title, description, route, sectionLabel];
    let score = 0;

    if (title.startsWith(query)) score += 100;
    if (title.includes(query)) score += 60;
    if (description.includes(query)) score += 25;
    if (sectionLabel.startsWith(query)) score += 40;
    if (sectionLabel.includes(query)) score += 20;
    if (route.includes(query)) score += 10;

    for (const token of queryTokens) {
      if (!fields.some((field) => field.includes(token))) {
        return 0;
      }

      if (title.startsWith(token)) score += 48;
      else if (title.includes(token)) score += 28;

      if (sectionLabel.startsWith(token)) score += 24;
      else if (sectionLabel.includes(token)) score += 12;

      if (description.includes(token)) score += 12;
      if (route.includes(token)) score += 8;
    }

    if (item.kind === "page") score += 6;
    if (item.kind === "action") score += 4;

    return score;
  }

  /**
   * @param {string} query
   * @returns {Array<{action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}>}
   */
  function matchingItems(query) {
    if (!query) {
      return defaultItems();
    }

    const queryTokens = tokenizeSearchValue(query);

    return searchItems()
      .map((item) => ({ item, score: scoreItem(item, query, queryTokens) }))
      .filter((entry) => entry.score > 0)
      .sort((left, right) => right.score - left.score)
      .map((entry) => entry.item)
      .slice(0, 8);
  }

  /**
   * Group visible items by their localized section label.
   * @param {Array<{action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}>} items
   * @returns {Array<{actionLabel?: string, key: string, label: string, entries: Array<{item: {action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}, index: number}>}>}
   */
  function groupedItems(items, includeRecents = false) {
    /** @type {Map<string, Array<{item: {action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}, index: number}>>} */
    const entriesBySection = new Map();
    const orderedKeys = [];
    const recentRoutes = includeRecents ? new Set(recentItems().map((item) => item.route)) : new Set();

    /** @type {Array<{item: {action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}, index: number}>} */
    const recentEntries = [];

    items.forEach((item, index) => {
      if (recentRoutes.has(item.route)) {
        recentEntries.push({ item, index });
        return;
      }

      if (!entriesBySection.has(item.section)) {
        entriesBySection.set(item.section, []);
        orderedKeys.push(item.section);
      }

      entriesBySection.get(item.section)?.push({ item, index });
    });

    const sectionGroups = orderedKeys.map((key) => ({
      key,
      label: config.sectionLabels[key] ?? key,
      entries: entriesBySection.get(key) ?? [],
    }));

    if (!recentEntries.length) {
      return sectionGroups;
    }

    return [
      {
        actionLabel: config.clearRecent,
        key: "__recent__",
        label: config.recentLabel,
        entries: recentEntries,
      },
      ...sectionGroups,
    ];
  }

  function syncActiveResult() {
    const links = Array.from(results.querySelectorAll(".search-result"));
    links.forEach((link, index) => {
      const isActive = index === activeIndex;
      link.classList.toggle("is-active", isActive);
      link.setAttribute("aria-selected", String(isActive));
      if (isActive) {
        link.scrollIntoView({ block: "nearest" });
      }
    });

    const activeLink = activeIndex >= 0 ? links[activeIndex] : null;
    if (activeLink instanceof HTMLElement && activeLink.id) {
      input.setAttribute("aria-activedescendant", activeLink.id);
    } else {
      input.removeAttribute("aria-activedescendant");
    }
  }

  /**
   * Move the active result index and resync the listbox state.
   * @param {number} nextIndex
   */
  function setActiveIndex(nextIndex) {
    activeIndex = nextIndex;
    syncActiveResult();
  }

  /**
   * @param {string} query
   */
  function renderResults(query) {
    const queryTokens = tokenizeSearchValue(query);
    const matchedItems = matchingItems(query);
    let includeRecents = !query;

    visibleItems = matchedItems;
    activeIndex = -1;
    results.replaceChildren();
    results.setAttribute("aria-busy", "false");
    input.removeAttribute("aria-activedescendant");
    setAssist("");

    if (!matchedItems.length) {
      if (!query) {
        setStatus(loadFailed ? config.unavailable : config.emptyState);
        if (loadFailed) {
          setAssist(config.fallbackNote);
        }
        return;
      }

      const recoveryItems = defaultItems();
      if (!recoveryItems.length) {
        setStatus(loadFailed ? config.unavailable : config.noResults);
        if (loadFailed) {
          setAssist(config.fallbackNote);
        }
        return;
      }

      visibleItems = recoveryItems;
      includeRecents = true;
      setStatus(config.noResults);
      setAssist(config.recoveryLabel);
    } else if (loadFailed) {
      setStatus(config.unavailable);
      setAssist(config.fallbackNote);
    } else {
      setStatus(query ? resultCountMessage(visibleItems.length) : config.suggestedLabel);
    }

    const groups = groupedItems(visibleItems, includeRecents);

    results.replaceChildren(...groups.map((group) => {
      const groupItem = document.createElement("li");
      groupItem.className = "search-results__group";
      groupItem.setAttribute("role", "group");
      groupItem.setAttribute("aria-label", group.label);

      const groupHeader = document.createElement("div");
      groupHeader.className = "search-results__group-header";

      const groupLabel = document.createElement("p");
      groupLabel.className = "search-results__group-label";
      appendHighlightedText(groupLabel, group.label, queryTokens);
      groupHeader.append(groupLabel);

      if (group.actionLabel) {
        const groupAction = document.createElement("button");
        groupAction.className = "search-results__group-action";
        groupAction.type = "button";
        groupAction.textContent = group.actionLabel;
        groupAction.addEventListener("click", () => {
          clearRecentRoutes();
          renderResults("");
          focusSearchInput();
        });
        groupHeader.append(groupAction);
      }

      const groupList = document.createElement("div");
      groupList.className = "search-results__group-list";

      group.entries.forEach(({ item, index }) => {
        const resultNode = item.route
          ? document.createElement("a")
          : document.createElement("button");

        resultNode.className = "search-result";
        if (resultNode instanceof HTMLAnchorElement) {
          resultNode.href = item.route;
        } else {
          resultNode.type = "button";
        }
        resultNode.dataset.searchResult = String(index);
        resultNode.id = `site-search-result-${index}`;
        resultNode.setAttribute("role", "option");
        resultNode.tabIndex = -1;
        resultNode.setAttribute("aria-posinset", String(index + 1));
        resultNode.setAttribute("aria-selected", "false");
        resultNode.setAttribute("aria-setsize", String(visibleItems.length));

        const meta = document.createElement("span");
        meta.className = "search-result__meta";
        appendHighlightedText(meta, config.sectionLabels[item.section] ?? item.section, queryTokens);

        const title = document.createElement("span");
        title.className = "search-result__title";
        appendHighlightedText(title, item.title, queryTokens);

        const description = document.createElement("span");
        description.className = "search-result__description";
        appendHighlightedText(description, item.description, queryTokens);

        resultNode.append(meta, title, description);
        resultNode.addEventListener("mouseenter", () => {
          activeIndex = index;
          syncActiveResult();
        });
        resultNode.addEventListener("click", (event) => {
          activateResult(item, event);
        });

        groupList.append(resultNode);
      });

      groupItem.append(groupHeader, groupList);
      return groupItem;
    }));

    setActiveIndex(0);
  }

  /**
   * @returns {Promise<Array<{description: string, kind: string, locale: string, route: string, section: string, title: string}>>}
   */
  function loadIndex() {
    if (allItems.length || loadFailed || hasAttemptedLoad) {
      return Promise.resolve(allItems);
    }

    if (loadPromise) {
      return loadPromise;
    }

    hasAttemptedLoad = true;
    setStatus(config.loading);
    results.setAttribute("aria-busy", "true");

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
        loadFailed = false;
        allItems = Array.isArray(payload.items) ? payload.items : [];
        return allItems;
      })
      .catch(() => {
        loadFailed = true;
        allItems = [];
        setStatus(config.unavailable);
        return allItems;
      })
      .finally(() => {
        results.setAttribute("aria-busy", "false");
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
    syncClearButton();
    renderResults(normalizeSearchValue(input.value));

    void loadIndex().then(() => {
      renderResults(normalizeSearchValue(input.value));
    });

    focusSearchInput();
  }

  function closeSearch() {
    if (modal.hidden) return;

    dismissSearch();
    lastTrigger?.focus({ preventScroll: true });
  }

  /**
   * Run a search result item while preserving route modifiers when relevant.
   * @param {{action?: string, description: string, kind: string, locale: string, route?: string, section: string, title: string}} item
   * @param {MouseEvent | KeyboardEvent | null} event
   */
  function activateResult(item, event = null) {
    if (item.action === "theme:auto") {
      if (event) {
        event.preventDefault();
      }
      setTheme("auto");
      dismissSearch();
      lastTrigger?.focus({ preventScroll: true });
      return;
    }

    if (item.action === "theme:light") {
      if (event) {
        event.preventDefault();
      }
      setTheme("light");
      dismissSearch();
      lastTrigger?.focus({ preventScroll: true });
      return;
    }

    if (item.action === "theme:dark") {
      if (event) {
        event.preventDefault();
      }
      setTheme("dark");
      dismissSearch();
      lastTrigger?.focus({ preventScroll: true });
      return;
    }

    const route = item.route;
    if (!route) {
      return;
    }

    const isModifiedClick = event instanceof MouseEvent
      && (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0);

    storeRecentRoute(route);

    if (isModifiedClick) {
      return;
    }

    if (event) {
      event.preventDefault();
    }

    dismissSearch();
    window.location.href = route;
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

  clearButton.addEventListener("click", () => {
    input.value = "";
    syncClearButton();
    renderResults("");
    focusSearchInput();
  });

  input.addEventListener("input", () => {
    syncClearButton();
    renderResults(normalizeSearchValue(input.value));
    void loadIndex().then(() => {
      renderResults(normalizeSearchValue(input.value));
    });
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
      if (activeIndex < 0) {
        setActiveIndex(0);
        return;
      }
      setActiveIndex(Math.min(activeIndex + 1, visibleItems.length - 1));
      return;
    }

    if (event.key === "ArrowUp") {
      if (!visibleItems.length) return;
      event.preventDefault();
      if (activeIndex < 0) {
        setActiveIndex(visibleItems.length - 1);
        return;
      }
      setActiveIndex(Math.max(activeIndex - 1, 0));
      return;
    }

    if (event.key === "Home") {
      if (!visibleItems.length) return;
      event.preventDefault();
      setActiveIndex(0);
      return;
    }

    if (event.key === "End") {
      if (!visibleItems.length) return;
      event.preventDefault();
      setActiveIndex(visibleItems.length - 1);
      return;
    }

    if (event.key === "Enter") {
      const resultIndex = activeIndex >= 0 ? activeIndex : 0;
      if (!visibleItems[resultIndex]) return;
      activateResult(visibleItems[resultIndex], event);
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

  syncClearButton();
}

document.addEventListener("DOMContentLoaded", () => {
  initThemeControls();
  initHeaderState();
  initRevealObserver();
  initStoryPanels();
  initSearchPalette();
});
