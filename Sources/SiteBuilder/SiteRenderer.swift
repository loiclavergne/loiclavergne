//
//  SiteRenderer.swift
//  Loic Engineer Portfolio
//
//  Created by Loïc Lavergne on 25/03/2026
//  Copyright © 2026 Loïc Lavergne. All rights reserved.
//

import Foundation

/// Generates localized HTML pages and the sitemap from the site payload.
struct SiteRenderer {
    let payload: SitePayload
    let rootURL: URL

    private struct ProjectFlowItem {
        let pageKey: String
        let sectionLabel: String
        let title: String
        let summary: String
        let period: String?
    }

    /// Build all localized pages and return their canonical URLs.
    func buildPages() throws -> [String] {
        var urls: [String] = []

        for pageKey in payload.pageKeys {
            for locale in payload.locales.keys.sorted() {
                let route = try pagePath(pageKey, locale: locale)
                let destination = outputURL(for: route)
                try FileManager.default.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try renderDocument(pageKey: pageKey, locale: locale)
                    .write(to: destination, atomically: true, encoding: .utf8)
                urls.append(absoluteURL(for: route))
            }
        }

        return urls
    }

    /// Write the root 404.html fallback page from localized site content.
    func buildNotFoundPage() throws {
        try renderNotFoundDocument().write(
            to: rootURL.appendingPathComponent("404.html"),
            atomically: true,
            encoding: .utf8
        )
    }

    /// Write sitemap.xml for the localized route set with alternates.
    func buildSitemap() throws {
        let locales = payload.locales.keys.sorted()
        let entries = try payload.pageKeys.flatMap { pageKey -> [String] in
            let englishDefaultPath = try pagePath(pageKey, locale: "en")
            let alternateLinks = try locales.map { locale -> String in
                let path = try pagePath(pageKey, locale: locale)
                let hreflang = try localeContent(locale).htmlLang
                return #"    <xhtml:link rel="alternate" hreflang="\#(escapeHTML(hreflang))" href="\#(escapeHTML(absoluteURL(for: path)))"/>"#
            }
            let alternatesMarkup = (alternateLinks + [
                #"    <xhtml:link rel="alternate" hreflang="x-default" href="\#(escapeHTML(absoluteURL(for: englishDefaultPath)))"/>"#
            ]).joined(separator: "\n")

            return try locales.map { locale in
                let path = try pagePath(pageKey, locale: locale)
                return """
                  <url>
                    <loc>\(absoluteURL(for: path))</loc>
                    <lastmod>\(payload.site.buildDate)</lastmod>
                \(alternatesMarkup)
                  </url>
                """
            }
        }.joined(separator: "\n")

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
        \(entries)
        </urlset>
        """

        try xml.write(to: rootURL.appendingPathComponent("sitemap.xml"), atomically: true, encoding: .utf8)
    }

    /// Write localized Atom feeds for the writing section.
    func buildFeeds() throws {
        for locale in payload.locales.keys.sorted() {
            let localeContent = try localeContent(locale)
            let feedURL = absoluteFeedURL(for: locale)
            let writingURL = absoluteURL(for: try pagePath("writing", locale: locale))
            let updated = payload.site.buildDate + "T00:00:00Z"

            let entries = localeContent.writing.posts.compactMap { post -> String? in
                guard let route = post.route else {
                    return nil
                }

                guard let path = try? pagePath(route, locale: locale) else {
                    return nil
                }

                let postURL = absoluteURL(for: path)
                let summary = escapeHTML(post.summary)

                return """
                  <entry>
                    <title>\(escapeHTML(post.title))</title>
                    <link href="\(escapeHTML(postURL))"/>
                    <id>\(escapeHTML(postURL))</id>
                    <updated>\(updated)</updated>
                    <summary>\(summary)</summary>
                  </entry>
                """
            }.joined(separator: "\n")

            let feed = """
            <?xml version="1.0" encoding="utf-8"?>
            <feed xmlns="http://www.w3.org/2005/Atom" xml:lang="\(escapeHTML(localeContent.htmlLang))">
              <title>\(escapeHTML(payload.site.name)) \(escapeHTML(localeContent.writing.eyebrow))</title>
              <subtitle>\(escapeHTML(localeContent.writing.description))</subtitle>
              <link href="\(escapeHTML(feedURL))" rel="self" type="application/atom+xml"/>
              <link href="\(escapeHTML(writingURL))" rel="alternate" type="text/html"/>
              <id>\(escapeHTML(feedURL))</id>
              <updated>\(updated)</updated>
              <author>
                <name>\(escapeHTML(payload.site.name))</name>
                <email>\(escapeHTML(payload.site.contactEmail))</email>
              </author>
            \(entries.isEmpty ? "" : entries)
            </feed>
            """

            let outputURL = locale == "fr"
                ? rootURL.appendingPathComponent("fr/feed.xml")
                : rootURL.appendingPathComponent("feed.xml")

            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try feed.write(to: outputURL, atomically: true, encoding: .utf8)
        }
    }

    /// Write localized web app manifests for installable browser support.
    func buildManifests() throws {
        for locale in payload.locales.keys.sorted() {
            let localeContent = try localeContent(locale)
            let startURL = try pagePath("home", locale: locale)
            let manifest: [String: Any] = [
                "background_color": "#f5f5f7",
                "description": localeContent.seo.siteDescription,
                "dir": "ltr",
                "display": "standalone",
                "icons": [
                    [
                        "purpose": "any",
                        "sizes": "any",
                        "src": "/assets/img/og/og-default.svg",
                        "type": "image/svg+xml"
                    ]
                ],
                "lang": localeContent.htmlLang,
                "name": payload.site.name,
                "scope": locale == "fr" ? "/fr/" : "/",
                "short_name": payload.site.name,
                "start_url": startURL,
                "theme_color": "#f5f5f7"
            ]

            let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            let outputURL = locale == "fr"
                ? rootURL.appendingPathComponent("fr/site.webmanifest")
                : rootURL.appendingPathComponent("site.webmanifest")

            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: outputURL)
        }
    }

    /// Write localized search indexes for future static search surfaces.
    func buildSearchIndexes() throws {
        for locale in payload.locales.keys.sorted() {
            let localeContent = try localeContent(locale)
            let items = try payload.pageKeys.map { pageKey -> [String: String] in
                let metadata = try searchIndexMetadata(pageKey: pageKey, localeContent: localeContent, locale: locale)
                let route = try pagePath(pageKey, locale: locale)

                return [
                    "description": metadata.description,
                    "kind": searchIndexKind(for: pageKey),
                    "locale": locale,
                    "route": route,
                    "section": primaryPageKey(for: pageKey),
                    "title": metadata.title
                ]
            }

            let index: [String: Any] = [
                "generated_at": payload.site.buildDate,
                "items": items,
                "locale": locale,
                "site": payload.site.name
            ]

            let data = try JSONSerialization.data(withJSONObject: index, options: [.prettyPrinted, .sortedKeys])
            let outputURL = locale == "fr"
                ? rootURL.appendingPathComponent("fr/search-index.json")
                : rootURL.appendingPathComponent("search-index.json")

            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: outputURL)
        }
    }

    /// Write the root robots.txt file.
    func buildRobots() throws {
        let robots = """
        User-agent: *
        Allow: /

        Sitemap: \(payload.site.baseUrl)/sitemap.xml
        """

        try robots.write(to: rootURL.appendingPathComponent("robots.txt"), atomically: true, encoding: .utf8)
    }

    /// Write GitHub Pages hosting support files derived from site metadata.
    func buildHostingFiles() throws {
        guard let host = URL(string: payload.site.baseUrl)?.host, !host.isEmpty else {
            throw SiteBuilderError.invalidURL(payload.site.baseUrl)
        }

        try "\(host)\n".write(
            to: rootURL.appendingPathComponent("CNAME"),
            atomically: true,
            encoding: .utf8
        )
        try "".write(
            to: rootURL.appendingPathComponent(".nojekyll"),
            atomically: true,
            encoding: .utf8
        )
    }

    /// Resolve a localized route for the page.
    func pagePath(_ pageKey: String, locale: String) throws -> String {
        guard let localizedRoutes = payload.routes[pageKey], let path = localizedRoutes[locale] else {
            throw SiteBuilderError.missingRoute(pageKey: pageKey, locale: locale)
        }
        return path
    }

    /// Resolve the locale content block.
    func localeContent(_ locale: String) throws -> LocaleContent {
        guard let content = payload.locales[locale] else {
            throw SiteBuilderError.missingLocale(locale)
        }
        return content
    }

    /// Build an absolute site URL from a route.
    func absoluteURL(for path: String) -> String {
        if path == "/" {
            return payload.site.baseUrl + "/"
        }
        return payload.site.baseUrl + path
    }

    /// Build an absolute feed URL from a locale.
    func absoluteFeedURL(for locale: String) -> String {
        if locale == "fr" {
            return payload.site.baseUrl + "/fr/feed.xml"
        }

        return payload.site.baseUrl + "/feed.xml"
    }

    /// Build an absolute manifest URL from a locale.
    func absoluteManifestURL(for locale: String) -> String {
        if locale == "fr" {
            return payload.site.baseUrl + "/fr/site.webmanifest"
        }

        return payload.site.baseUrl + "/site.webmanifest"
    }

    /// Build a stable in-page anchor identifier for project detail sections.
    func projectDetailSectionID(kind: String, index: Int? = nil) -> String {
        if let index {
            return "section-\(index)-\(kind)"
        }

        return "section-\(kind)"
    }

    /// Build a localized search-index path.
    func searchIndexPath(for locale: String) -> String {
        locale == "fr" ? "/fr/search-index.json" : "/search-index.json"
    }

    /// Render the theme bootstrap script used before CSS paints.
    func renderThemeBootstrapScript() -> String {
        """
          <script>
            (() => {
              document.documentElement.classList.add("js");
              let stored = null;
              try {
                stored = window.localStorage.getItem("loic.engineer.theme");
              } catch (error) {
                stored = null;
              }
              const theme = ["auto", "light", "dark"].includes(stored) ? stored : "auto";
              const resolved = theme === "auto"
                ? (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
                : theme;
              document.documentElement.dataset.theme = theme;
              document.documentElement.dataset.resolvedTheme = resolved;
            })();
          </script>
        """
    }

    /// Build the localized route suggestions used by the shared 404 page.
    func notFoundRouteItems(locale: String, localeContent: LocaleContent) throws -> [[String: String]] {
        let orderedPageKeys = ["home", "work", "projects", "writing", "library", "about"]

        return try orderedPageKeys.map { pageKey in
            [
                "href": try pagePath(pageKey, locale: locale),
                "label": localeContent.nav[pageKey] ?? pageKey.capitalized
            ]
        }
    }

    /// Render the translation payload for the generated 404 page.
    func renderNotFoundTranslations() throws -> String {
        let english = try localeContent("en")
        let french = try localeContent("fr")

        let translations: [String: Any] = [
            "en": [
                "ariaLabel": english.notFound.ariaLabel,
                "copy": english.notFound.copy,
                "documentTitle": english.notFound.documentTitle,
                "home": english.notFound.home,
                "note": english.notFound.note,
                "primary": english.notFound.primary,
                "routes": try notFoundRouteItems(locale: "en", localeContent: english),
                "title": english.notFound.title
            ],
            "fr": [
                "ariaLabel": french.notFound.ariaLabel,
                "copy": french.notFound.copy,
                "documentTitle": french.notFound.documentTitle,
                "home": french.notFound.home,
                "note": french.notFound.note,
                "primary": french.notFound.primary,
                "routes": try notFoundRouteItems(locale: "fr", localeContent: french),
                "title": french.notFound.title
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: translations, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self).replacingOccurrences(of: "</", with: "<\\/")
    }

    /// Render the localized search UI configuration.
    func renderSearchConfig(currentPage: String, locale: String, localeContent: LocaleContent) throws -> String {
        let fallbackPageKeys = ["home", "work", "projects", "writing", "library", "about"]
        let fallbackPages = try fallbackPageKeys.map { pageKey -> [String: String] in
            let metadata = try searchIndexMetadata(pageKey: pageKey, localeContent: localeContent, locale: locale)
            return [
                "description": metadata.description,
                "kind": searchIndexKind(for: pageKey),
                "locale": locale,
                "route": try pagePath(pageKey, locale: locale),
                "section": primaryPageKey(for: pageKey),
                "title": metadata.title
            ]
        }

        let fallbackProjects = try localeContent.projects.featured.compactMap { project -> [String: String]? in
            guard let routeKey = project.route else {
                return nil
            }

            let metadata = try searchIndexMetadata(pageKey: routeKey, localeContent: localeContent, locale: locale)
            return [
                "description": metadata.description,
                "kind": "project",
                "locale": locale,
                "route": try pagePath(routeKey, locale: locale),
                "section": "projects",
                "title": metadata.title
            ]
        }

        let switchLocale = localeContent.switchLocale
        let switchPath = try pagePath(currentPage, locale: switchLocale)
        let switchDescription = localeContent.search.switchLocaleDescription
            .replacingOccurrences(of: "{{locale}}", with: localeContent.switchLabel)
        let contactActions: [[String: String]] = [
            [
                "description": localeContent.search.emailDescription
                    .replacingOccurrences(of: "{{email}}", with: payload.site.contactEmail),
                "kind": "action",
                "locale": locale,
                "route": "mailto:\(payload.site.contactEmail)",
                "section": "__contact__",
                "title": label(localeContent.labels, key: "email", fallback: "Email")
            ]
        ] + payload.site.socials.map { social in
            [
                "description": localeContent.search.openProfileDescription
                    .replacingOccurrences(of: "{{label}}", with: social.label),
                "kind": "action",
                "locale": locale,
                "route": social.href,
                "section": "__contact__",
                "title": social.label
            ]
        }

        let actionItems: [[String: String]] = [
            [
                "action": "theme:auto",
                "description": localeContent.search.themeAutoDescription,
                "kind": "action",
                "locale": locale,
                "section": "__actions__",
                "title": localeContent.theme.auto
            ],
            [
                "action": "theme:light",
                "description": localeContent.search.themeLightDescription,
                "kind": "action",
                "locale": locale,
                "section": "__actions__",
                "title": localeContent.theme.light
            ],
            [
                "action": "theme:dark",
                "description": localeContent.search.themeDarkDescription,
                "kind": "action",
                "locale": locale,
                "section": "__actions__",
                "title": localeContent.theme.dark
            ],
            [
                "description": switchDescription,
                "kind": "action",
                "locale": locale,
                "route": switchPath,
                "section": "__actions__",
                "title": localeContent.switchLabel
            ]
        ] + contactActions

        var sectionLabels = localeContent.nav
        sectionLabels["__actions__"] = localeContent.search.quickActionsLabel
        sectionLabels["__contact__"] = label(localeContent.labels, key: "reach_out", fallback: "Reach out")

        let config: [String: Any] = [
            "actionItems": actionItems,
            "close": localeContent.search.close,
            "emptyState": localeContent.search.emptyState,
            "fallbackItems": fallbackPages + fallbackProjects,
            "hint": localeContent.search.hint,
            "indexURL": searchIndexPath(for: locale),
            "locale": locale,
            "loading": localeContent.search.loading,
            "clearRecent": localeContent.search.clearRecent,
            "fallbackNote": localeContent.search.fallbackNote,
            "noResults": localeContent.search.noResults,
            "placeholder": localeContent.search.placeholder,
            "recentLabel": localeContent.search.recentLabel,
            "recoveryLabel": localeContent.search.recoveryLabel,
            "resultsCountOne": localeContent.search.resultsCountOne,
            "resultsCountOther": localeContent.search.resultsCountOther,
            "resultsLabel": localeContent.search.resultsLabel,
            "sectionLabels": sectionLabels,
            "suggestedLabel": localeContent.search.suggestedLabel,
            "title": localeContent.search.title,
            "unavailable": localeContent.search.unavailable
        ]

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self).replacingOccurrences(of: "</", with: "<\\/")
    }

    /// Render the shared search modal for the current locale.
    func renderSearchModal(currentPage: String, locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let search = localeContent.search
        let config = try renderSearchConfig(currentPage: currentPage, locale: locale, localeContent: localeContent)

        return """
            <div class="search-modal" data-search-modal hidden>
              <div class="search-modal__backdrop" data-search-close></div>
              <section class="search-modal__sheet" id="site-search" role="dialog" aria-modal="true" aria-labelledby="site-search-title" aria-describedby="site-search-status">
                <div class="search-modal__header">
                  <div>
                    <span class="eyebrow">\(escapeHTML(search.button))</span>
                    <h2 id="site-search-title">\(escapeHTML(search.title))</h2>
                  </div>
                  <button class="search-modal__close" type="button" data-search-close">\(escapeHTML(search.close))</button>
                </div>
                <div class="search-modal__field">
                  <div class="search-modal__field-row">
                    <input
                      id="site-search-input"
                      class="search-modal__input"
                      type="search"
                      data-search-input
                      autocomplete="off"
                      autocapitalize="none"
                      spellcheck="false"
                      enterkeyhint="go"
                      placeholder="\(escapeHTML(search.placeholder))"
                      aria-label="\(escapeHTML(search.title))"
                      role="combobox"
                      aria-autocomplete="list"
                      aria-controls="site-search-results"
                      aria-expanded="false"
                    >
                    <button class="search-modal__clear" type="button" data-search-clear hidden aria-label="\(escapeHTML(search.clear))">\(escapeHTML(search.clear))</button>
                  </div>
                </div>
                <p class="search-modal__status" id="site-search-status" data-search-status aria-live="polite">\(escapeHTML(search.emptyState))</p>
                <p class="search-modal__assist" data-search-assist hidden></p>
                <ul class="search-results" id="site-search-results" data-search-results aria-label="\(escapeHTML(search.resultsLabel))" role="listbox"></ul>
              </section>
            </div>
            <script type="application/json" id="search-config">
        \(config)
            </script>
        """
    }

    /// Map a route like `/fr/projects/` to the generated output file.
    func outputURL(for route: String) -> URL {
        if route == "/" {
            return rootURL.appendingPathComponent("index.html")
        }

        let trimmed = route.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return rootURL
            .appendingPathComponent(trimmed, isDirectory: true)
            .appendingPathComponent("index.html")
    }

    /// Escape text for safe HTML insertion.
    func escapeHTML(_ value: String) -> String {
        var escaped = value
        let replacements = [
            ("&", "&amp;"),
            ("<", "&lt;"),
            (">", "&gt;"),
            ("\"", "&quot;"),
            ("'", "&#x27;")
        ]

        for (source, target) in replacements {
            escaped = escaped.replacingOccurrences(of: source, with: target)
        }

        return escaped
    }

    /// Read a label from a dictionary with a safe fallback.
    func label(_ labels: [String: String], key: String, fallback: String) -> String {
        labels[key] ?? fallback
    }

    /// Map detail pages back to their primary navigation section.
    func primaryPageKey(for pageKey: String) -> String {
        if pageKey.hasPrefix("project-") {
            return "projects"
        }

        if pageKey.hasPrefix("post-") {
            return "writing"
        }

        if pageKey.hasPrefix("book-") {
            return "library"
        }

        return pageKey
    }

    /// Classify a page for the generated search index.
    func searchIndexKind(for pageKey: String) -> String {
        if pageKey.hasPrefix("project-") {
            return "project"
        }

        if pageKey.hasPrefix("post-") {
            return "post"
        }

        if pageKey.hasPrefix("book-") {
            return "book"
        }

        return "page"
    }

    /// Resolve a project detail page from the locale payload.
    func projectDetail(pageKey: String, localeContent: LocaleContent, locale: String) throws -> ProjectDetailPage {
        guard let page = localeContent.projectDetails[pageKey] else {
            throw SiteBuilderError.missingRoute(pageKey: pageKey, locale: locale)
        }

        return page
    }

    /// Resolve a writing detail page from the locale payload.
    func writingDetail(pageKey: String, localeContent: LocaleContent, locale: String) throws -> WritingPostPage {
        guard let page = localeContent.writingDetails[pageKey] else {
            throw SiteBuilderError.missingRoute(pageKey: pageKey, locale: locale)
        }

        return page
    }

    /// Resolve a library detail page from the locale payload.
    func libraryDetail(pageKey: String, localeContent: LocaleContent, locale: String) throws -> LibraryEntryPage {
        guard let page = localeContent.libraryDetails[pageKey] else {
            throw SiteBuilderError.missingRoute(pageKey: pageKey, locale: locale)
        }

        return page
    }

    /// Resolve shared page metadata for standard and project detail pages.
    func pageMetadata(pageKey: String, localeContent: LocaleContent, locale: String) throws -> (title: String, description: String) {
        switch pageKey {
        case "home":
            return (localeContent.home.pageTitle, localeContent.home.description)
        case "work":
            return (localeContent.work.pageTitle, localeContent.work.description)
        case "projects":
            return (localeContent.projects.pageTitle, localeContent.projects.description)
        case "writing":
            return (localeContent.writing.pageTitle, localeContent.writing.description)
        case "library":
            return (localeContent.library.pageTitle, localeContent.library.description)
        case "about":
            return (localeContent.about.pageTitle, localeContent.about.description)
        default:
            if let detailPage = localeContent.projectDetails[pageKey] {
                return (detailPage.pageTitle, detailPage.description)
            }

            if let detailPage = localeContent.writingDetails[pageKey] {
                return (detailPage.pageTitle, detailPage.description)
            }

            if let detailPage = localeContent.libraryDetails[pageKey] {
                return (detailPage.pageTitle, detailPage.description)
            }

            throw SiteBuilderError.missingRoute(pageKey: pageKey, locale: locale)
        }
    }

    /// Resolve cleaner metadata for the generated search index.
    func searchIndexMetadata(pageKey: String, localeContent: LocaleContent, locale: String) throws -> (title: String, description: String) {
        switch pageKey {
        case "home":
            return (localeContent.nav["home"] ?? "Home", localeContent.home.lede)
        case "work":
            return (localeContent.work.title, localeContent.work.intro)
        case "projects":
            return (localeContent.projects.title, localeContent.projects.intro)
        case "writing":
            return (localeContent.writing.title, localeContent.writing.intro)
        case "library":
            return (localeContent.library.title, localeContent.library.intro)
        case "about":
            return (localeContent.about.title, localeContent.about.intro)
        default:
            if let detailPage = localeContent.projectDetails[pageKey] {
                return (detailPage.title, detailPage.summary)
            }

            if let detailPage = localeContent.writingDetails[pageKey] {
                return (detailPage.title, detailPage.intro)
            }

            if let detailPage = localeContent.libraryDetails[pageKey] {
                return (detailPage.title, detailPage.intro)
            }

            throw SiteBuilderError.missingRoute(pageKey: pageKey, locale: locale)
        }
    }

    /// Render a simple unordered list.
    func renderList(_ items: [String], className: String = "detail-list") -> String {
        let content = items.map { "<li>\(escapeHTML($0))</li>" }.joined()
        return #"<ul class="\#(className)">\#(content)</ul>"#
    }

    /// Render a list only when items are present.
    func renderOptionalList(_ items: [String]?, className: String = "detail-list") -> String {
        guard let items, !items.isEmpty else {
            return ""
        }

        return renderList(items, className: className)
    }

    /// Render a content card with optional supporting bullet points.
    func renderContentCard(_ card: ContentCard) -> String {
        """
        <article class="card reveal">
          <h3>\(escapeHTML(card.title))</h3>
          <p>\(escapeHTML(card.copy))</p>
          \(renderOptionalList(card.items))
        </article>
        """
    }

    /// Render a project-detail heading with a stable permalink.
    func renderProjectSectionTitle(title: String, sectionID: String, permalinkLabel: String) -> String {
        """
        <div class="project-section-title">
          <h2>\(escapeHTML(title))</h2>
          <a class="section-permalink" href="#\(escapeHTML(sectionID))" aria-label="\(escapeHTML(permalinkLabel)): \(escapeHTML(title))" data-section-permalink>#</a>
        </div>
        """
    }

    /// Render a featured project card with an optional detail-page action.
    func renderFeaturedProjectCard(_ project: FeaturedProject, locale: String, localeContent: LocaleContent) throws -> String {
        let actionMarkup: String

        if let route = project.route {
            actionMarkup = """
              <div class="button-row">
                <a class="button button--secondary" href="\(try pagePath(route, locale: locale))">\(escapeHTML(label(localeContent.labels, key: "view_project", fallback: "View project")))</a>
              </div>
            """
        } else {
            actionMarkup = ""
        }

        return """
        <article class="card card--project reveal">
          <span class="eyebrow">\(escapeHTML(project.period))</span>
          <h3>\(escapeHTML(project.name))</h3>
          <p>\(escapeHTML(project.summary))</p>
          \(renderList(project.details))
          \(actionMarkup)
        </article>
        """
    }

    /// Render a summary project card with an optional detail-page action.
    func renderSummaryProjectCard(_ project: SummaryProject, locale: String, localeContent: LocaleContent, eyebrow: String) throws -> String {
        let actionMarkup: String

        if let route = project.route {
            actionMarkup = """
              <div class="button-row">
                <a class="button button--secondary" href="\(try pagePath(route, locale: locale))">\(escapeHTML(label(localeContent.labels, key: "view_project", fallback: "View project")))</a>
              </div>
            """
        } else {
            actionMarkup = ""
        }

        return """
        <article class="card reveal">
          <span class="eyebrow">\(escapeHTML(project.period ?? eyebrow))</span>
          <h3>\(escapeHTML(project.name))</h3>
          <p>\(escapeHTML(project.summary))</p>
          \(renderOptionalList(project.details))
          \(actionMarkup)
        </article>
        """
    }

    /// Build the ordered project sequence from the localized curated project groups.
    private func projectFlowItems(localeContent: LocaleContent) -> [ProjectFlowItem] {
        let labels = localeContent.labels
        let featuredLabel = label(labels, key: "featured", fallback: "Featured")
        let archiveLabel = label(labels, key: "archive", fallback: "Archive")
        let hobbyLabel = label(labels, key: "side_work", fallback: "Side Work")

        let featured = localeContent.projects.featured.compactMap { project -> ProjectFlowItem? in
            guard let route = project.route else {
                return nil
            }

            return ProjectFlowItem(
                pageKey: route,
                sectionLabel: featuredLabel,
                title: project.name,
                summary: project.summary,
                period: project.period
            )
        }

        let archive = localeContent.projects.archive.compactMap { project -> ProjectFlowItem? in
            guard let route = project.route else {
                return nil
            }

            return ProjectFlowItem(
                pageKey: route,
                sectionLabel: archiveLabel,
                title: project.name,
                summary: project.summary,
                period: project.period
            )
        }

        let hobby = localeContent.projects.hobby.compactMap { project -> ProjectFlowItem? in
            guard let route = project.route else {
                return nil
            }

            return ProjectFlowItem(
                pageKey: route,
                sectionLabel: hobbyLabel,
                title: project.name,
                summary: project.summary,
                period: project.period
            )
        }

        return featured + archive + hobby
    }

    /// Resolve the previous and next project within the curated project sequence.
    private func projectFlowNeighbors(pageKey: String, localeContent: LocaleContent) -> (previous: ProjectFlowItem?, next: ProjectFlowItem?) {
        let items = projectFlowItems(localeContent: localeContent)

        guard let index = items.firstIndex(where: { $0.pageKey == pageKey }) else {
            return (nil, nil)
        }

        let previous = index > 0 ? items[index - 1] : nil
        let next = index < items.count - 1 ? items[index + 1] : nil
        return (previous, next)
    }

    /// Render one navigation card within the project detail flow section.
    private func renderProjectFlowCard(
        _ item: ProjectFlowItem,
        eyebrow: String,
        locale: String,
        localeContent: LocaleContent
    ) throws -> String {
        let meta = [item.sectionLabel, item.period].compactMap { $0 }.joined(separator: " · ")

        return """
        <article class="card card--entry card--project-flow reveal">
          <span class="eyebrow">\(escapeHTML(eyebrow))</span>
          <h3>\(escapeHTML(item.title))</h3>
          <p class="project-flow__meta">\(escapeHTML(meta))</p>
          <p>\(escapeHTML(item.summary))</p>
          <div class="button-row">
            <a class="button button--secondary" href="\(try pagePath(item.pageKey, locale: locale))">\(escapeHTML(label(localeContent.labels, key: "view_project", fallback: "View project")))</a>
          </div>
        </article>
        """
    }

    /// Render a writing archive card with an optional detail-page action.
    func renderWritingPostCard(_ post: WritingPostSummary, locale: String, localeContent: LocaleContent) throws -> String {
        let actionMarkup: String

        if let route = post.route {
            actionMarkup = """
              <div class="button-row">
                <a class="button button--secondary" href="\(try pagePath(route, locale: locale))">\(escapeHTML(label(localeContent.labels, key: "read_post", fallback: "Read post")))</a>
              </div>
            """
        } else {
            actionMarkup = ""
        }

        return """
        <article class="card reveal">
          <h3>\(escapeHTML(post.title))</h3>
          <p>\(escapeHTML(post.summary))</p>
          \(renderOptionalList(post.details))
          \(actionMarkup)
        </article>
        """
    }

    /// Render a library archive card with an optional detail-page action.
    func renderLibraryEntryCard(_ entry: LibraryEntrySummary, locale: String, localeContent: LocaleContent) throws -> String {
        let actionMarkup: String

        if let route = entry.route {
            actionMarkup = """
              <div class="button-row">
                <a class="button button--secondary" href="\(try pagePath(route, locale: locale))">\(escapeHTML(label(localeContent.labels, key: "view_book", fallback: "View book")))</a>
              </div>
            """
        } else {
            actionMarkup = ""
        }

        return """
        <article class="card reveal">
          <h3>\(escapeHTML(entry.title))</h3>
          <p>\(escapeHTML(entry.summary))</p>
          \(renderOptionalList(entry.details))
          \(actionMarkup)
        </article>
        """
    }

    /// Render the localized header navigation.
    func renderNav(locale: String, currentPage: String) throws -> String {
        let localeContent = try localeContent(locale)
        let labels = localeContent.labels
        let search = localeContent.search
        let switchLocale = localeContent.switchLocale
        let switchPath = try pagePath(currentPage, locale: switchLocale)
        let orderedPageKeys = ["home", "work", "projects", "writing", "library", "about"]
        let activePage = primaryPageKey(for: currentPage)

        let links = orderedPageKeys.map { pageKey -> String in
            let currentAttribute = activePage == pageKey ? #" aria-current="page""# : ""
            let href = (try? pagePath(pageKey, locale: locale)) ?? "/"
            let text = localeContent.nav[pageKey] ?? pageKey.capitalized
            return #"<a class="site-nav__link" href="\#(href)"\#(currentAttribute)>\#(escapeHTML(text))</a>"#
        }.joined()

        return """
            <header class="site-header" data-header>
              <div class="shell site-header__inner">
                <a class="site-brand" href="\(try pagePath("home", locale: locale))">
                  <span class="site-brand__name">\(escapeHTML(payload.site.name))</span>
                  <span class="site-brand__role">\(escapeHTML(payload.site.leadTitle))</span>
                </a>
                <nav class="site-nav" aria-label="\(escapeHTML(label(labels, key: "primary_nav", fallback: "Primary")))">
                  \(links)
                </nav>
                <div class="site-header__controls">
                  <button class="search-trigger" type="button" data-search-open aria-haspopup="dialog" aria-controls="site-search" aria-expanded="false">
                    <span class="search-trigger__label">\(escapeHTML(search.button))</span>
                    <span class="search-trigger__hint" aria-hidden="true">\(escapeHTML(search.hint))</span>
                  </button>
                  <div class="theme-switcher" aria-label="\(escapeHTML(localeContent.theme.label))">
                    <button class="theme-switcher__button" type="button" data-theme-control="auto">\(escapeHTML(localeContent.theme.auto))</button>
                    <button class="theme-switcher__button" type="button" data-theme-control="light">\(escapeHTML(localeContent.theme.light))</button>
                    <button class="theme-switcher__button" type="button" data-theme-control="dark">\(escapeHTML(localeContent.theme.dark))</button>
                  </div>
                  <a class="locale-link" hreflang="\(escapeHTML(switchLocale))" href="\(switchPath)">\(escapeHTML(localeContent.switchLabel))</a>
                </div>
              </div>
            </header>
        """
    }

    /// Render the localized footer.
    func renderFooter(locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let labels = localeContent.labels
        let socialLinks = payload.site.socials.map {
            #"<a href="\#(escapeHTML($0.href))" rel="me noopener noreferrer" target="_blank">\#(escapeHTML($0.label))</a>"#
        }.joined()

        return """
            <footer class="site-footer">
              <div class="shell site-footer__inner">
                <div>
                  <p class="site-footer__tagline">\(escapeHTML(localeContent.footer.tagline))</p>
                  <p class="site-footer__copyright">© 2026 \(escapeHTML(payload.site.name)). \(escapeHTML(localeContent.footer.copyright))</p>
                </div>
                <nav class="site-footer__nav" aria-label="\(escapeHTML(label(labels, key: "social_links", fallback: "Social links")))">
                  \(socialLinks)
                </nav>
              </div>
            </footer>
        """
    }

    /// Render the homepage.
    func renderHome(locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let page = localeContent.home
        let labels = localeContent.labels
        let featured = localeContent.projects.featured

        let metricMarkup = page.metrics.map {
            """
            <li class="metric-card">
              <span class="metric-card__value">\(escapeHTML($0.value))</span>
              <span class="metric-card__label">\(escapeHTML($0.label))</span>
            </li>
            """
        }.joined(separator: "\n")

        let storyPanels = page.storySteps.enumerated().map { index, step in
            let activeClass = index == 0 ? " is-active" : ""
            let formattedIndex = String(format: "%02d", index + 1)
            return """
            <article class="story-panel\(activeClass)" data-story-panel="\(escapeHTML(step.id))" aria-hidden="true">
              <span class="story-panel__index">\(formattedIndex)</span>
              <span class="eyebrow">\(escapeHTML(step.eyebrow))</span>
              <h3>\(escapeHTML(step.title))</h3>
              <p>\(escapeHTML(step.copy))</p>
            </article>
            """
        }.joined(separator: "\n")

        let storySteps = page.storySteps.map {
            """
            <article class="story-step reveal" data-story-step data-story-id="\(escapeHTML($0.id))">
              <span class="eyebrow">\(escapeHTML($0.eyebrow))</span>
              <h3>\(escapeHTML($0.title))</h3>
              <p>\(escapeHTML($0.copy))</p>
              \(renderList($0.facts))
            </article>
            """
        }.joined(separator: "\n")

        let featuredMarkup = try featured.map {
            try renderFeaturedProjectCard($0, locale: locale, localeContent: localeContent)
        }.joined(separator: "\n")

        let entryPoints = page.entryPoints.map { item in
            let navTitle = localeContent.nav[item.route] ?? item.route.capitalized
            let href = (try? pagePath(item.route, locale: locale)) ?? "/"
            return """
            <a class="card card--entry reveal" href="\(href)">
              <span class="eyebrow">\(escapeHTML(navTitle))</span>
              <h3>\(escapeHTML(item.title))</h3>
              <p>\(escapeHTML(item.copy))</p>
            </a>
            """
        }.joined(separator: "\n")

        return """
            <section class="hero hero--home">
              <div class="hero__backdrop" aria-hidden="true">
                <div class="hero__orb hero__orb--one"></div>
                <div class="hero__orb hero__orb--two"></div>
                <div class="hero__grid"></div>
              </div>
              <div class="shell hero__content">
                <span class="eyebrow">\(escapeHTML(page.eyebrow))</span>
                <h1>\(escapeHTML(page.title))</h1>
                <p class="hero__lede">\(escapeHTML(page.lede))</p>
                <div class="hero__actions">
                  <a class="button button--primary" href="\(try pagePath(page.ctaPrimary.route, locale: locale))">\(escapeHTML(page.ctaPrimary.label))</a>
                  <a class="button button--secondary" href="\(try pagePath(page.ctaSecondary.route, locale: locale))">\(escapeHTML(page.ctaSecondary.label))</a>
                </div>
                <ul class="metric-grid" aria-label="\(escapeHTML(label(labels, key: "highlights", fallback: "Highlights")))">
                  \(metricMarkup)
                </ul>
              </div>
            </section>

            <section class="section">
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "approach", fallback: "Approach")))</span>
                  <h2>\(escapeHTML(page.storyHeading))</h2>
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(page.storyIntro))</p>
                </div>
              </div>
              <div class="shell story-grid">
                <div class="story-visual" aria-hidden="true">
                  \(storyPanels)
                </div>
                <div class="story-steps">
                  \(storySteps)
                </div>
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "current_work", fallback: "Current Work")))</span>
                <h2>\(escapeHTML(page.featuredProjectsHeading))</h2>
              </div>
              <div class="shell card-grid card-grid--two">
                \(featuredMarkup)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "beyond_homepage", fallback: "Beyond the homepage")))</span>
                <h2>\(escapeHTML(page.entryPointsHeading))</h2>
              </div>
              <div class="shell card-grid card-grid--three">
                \(entryPoints)
              </div>
            </section>
        """
    }

    /// Render the work page.
    func renderWork(locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let page = localeContent.work
        let labels = localeContent.labels

        let productCards = page.productCards.map {
            """
            <article class="card reveal">
              <span class="eyebrow">\(escapeHTML(label(labels, key: "current_product", fallback: "Current Product")))</span>
              <h3>\(escapeHTML($0.name))</h3>
              <p>\(escapeHTML($0.summary))</p>
            </article>
            """
        }.joined(separator: "\n")

        let timeline = page.experience.map {
            """
            <article class="timeline-entry reveal">
              <div class="timeline-entry__meta">
                <span class="eyebrow">\(escapeHTML($0.organization))</span>
                <span class="timeline-entry__period">\(escapeHTML($0.period))</span>
              </div>
              <h3>\(escapeHTML($0.title))</h3>
              <p>\(escapeHTML($0.summary))</p>
              \(renderOptionalList($0.highlights))
            </article>
            """
        }.joined(separator: "\n")

        let educationCards = page.educationCards.map(renderContentCard).joined(separator: "\n")

        return """
            <section class="hero hero--page">
              <div class="shell hero__content hero__content--page">
                <span class="eyebrow">\(escapeHTML(page.eyebrow))</span>
                <h1>\(escapeHTML(page.title))</h1>
                <p class="hero__lede">\(escapeHTML(page.intro))</p>
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell">
                <article class="card card--featured reveal">
                  <span class="eyebrow">\(escapeHTML(page.currentRole.organization))</span>
                  <h2>\(escapeHTML(page.currentRole.title))</h2>
                  <p class="card__meta">\(escapeHTML(page.currentRole.period)) · \(escapeHTML(page.currentRole.location))</p>
                  <p>\(escapeHTML(page.currentRole.summary))</p>
                  \(renderList(page.currentRole.highlights))
                </article>
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "scope", fallback: "Scope")))</span>
                <h2>\(escapeHTML(label(labels, key: "role_today", fallback: "Roole today")))</h2>
              </div>
              <div class="shell card-grid card-grid--two">
                \(productCards)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "career", fallback: "Career")))</span>
                <h2>\(escapeHTML(page.experienceHeading))</h2>
              </div>
              <div class="shell timeline">
                \(timeline)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "context", fallback: "Context")))</span>
                  <h2>\(escapeHTML(page.educationHeading))</h2>
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(page.educationIntro))</p>
                </div>
              </div>
              <div class="shell card-grid card-grid--three">
                \(educationCards)
              </div>
            </section>
        """
    }

    /// Render the projects page.
    func renderProjects(locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let page = localeContent.projects
        let labels = localeContent.labels
        let hobbyLabel = locale == "fr" ? "Projet perso" : "Hobby"

        let featured = try page.featured.map {
            try renderFeaturedProjectCard($0, locale: locale, localeContent: localeContent)
        }.joined(separator: "\n")

        let archive = try page.archive.map {
            try renderSummaryProjectCard($0, locale: locale, localeContent: localeContent, eyebrow: "")
        }.joined(separator: "\n")

        let hobby = try page.hobby.map {
            try renderSummaryProjectCard($0, locale: locale, localeContent: localeContent, eyebrow: hobbyLabel)
        }.joined(separator: "\n")

        return """
            <section class="hero hero--page">
              <div class="shell hero__content hero__content--page">
                <span class="eyebrow">\(escapeHTML(page.eyebrow))</span>
                <h1>\(escapeHTML(page.title))</h1>
                <p class="hero__lede">\(escapeHTML(page.intro))</p>
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "featured", fallback: "Featured")))</span>
                <h2>\(escapeHTML(label(labels, key: "current_focus", fallback: "Current focus")))</h2>
              </div>
              <div class="shell card-grid card-grid--two">
                \(featured)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "archive", fallback: "Archive")))</span>
                <h2>\(escapeHTML(page.archiveHeading))</h2>
              </div>
              <div class="shell card-grid card-grid--two">
                \(archive)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "side_work", fallback: "Side Work")))</span>
                <h2>\(escapeHTML(page.hobbyHeading))</h2>
              </div>
              <div class="shell card-grid card-grid--two">
                \(hobby)
              </div>
            </section>
        """
    }

    /// Render a localized project detail page.
    func renderProjectDetail(pageKey: String, locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let labels = localeContent.labels
        let page = try projectDetail(pageKey: pageKey, localeContent: localeContent, locale: locale)
        let neighbors = projectFlowNeighbors(pageKey: pageKey, localeContent: localeContent)
        let overviewID = projectDetailSectionID(kind: "overview", index: 1)
        let signalsID = projectDetailSectionID(kind: "signals", index: 2)

        let metrics = page.metrics.map {
            """
            <article class="stat-card reveal">
              <span class="stat-card__value">\(escapeHTML($0.value))</span>
              <span class="stat-card__label">\(escapeHTML($0.label))</span>
            </article>
            """
        }.joined(separator: "\n")

        let detailSections = page.sections.enumerated().map { index, section -> (id: String, title: String, markup: String) in
            let sectionID = projectDetailSectionID(kind: "detail", index: index + 3)
            let cards = section.cards.map(renderContentCard).joined(separator: "\n")

            let markup = """
            <section class="section section--compact project-detail__section" id="\(sectionID)">
              <div class="split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(section.eyebrow))</span>
                  \(renderProjectSectionTitle(
                    title: section.title,
                    sectionID: sectionID,
                    permalinkLabel: label(labels, key: "section_permalink", fallback: "Link to section")
                  ))
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(section.intro))</p>
                </div>
              </div>
              <div class="card-grid card-grid--three">
                \(cards)
              </div>
            </section>
            """

            return (sectionID, section.title, markup)
        }

        let sectionIndexItems = [
            (id: overviewID, title: label(labels, key: "overview", fallback: "Overview")),
            (id: signalsID, title: label(labels, key: "key_signals", fallback: "Key signals"))
        ] + detailSections.map { (id: $0.id, title: $0.title) }

        let sectionIndexLinks = sectionIndexItems.map {
            "<a class=\"section-index__link\" href=\"#\($0.id)\" data-section-link=\"\(escapeHTML($0.id))\">\(escapeHTML($0.title))</a>"
        }.joined(separator: "\n")

        let sectionIndex = """
          <nav class="section-index reveal" data-section-index aria-label="\(escapeHTML(label(labels, key: "on_this_page", fallback: "On this page")))">
            <span class="eyebrow">\(escapeHTML(label(labels, key: "context", fallback: "Context")))</span>
            <div class="section-index__header">
              <h2>\(escapeHTML(label(labels, key: "on_this_page", fallback: "On this page")))</h2>
              <p>\(escapeHTML(label(labels, key: "section_index_copy", fallback: "Jump between the overview, delivery signals, and the main sections of the case study.")))</p>
            </div>
            <div class="section-index__items">
              \(sectionIndexLinks)
            </div>
          </nav>
        """

        let sections = detailSections.map(\.markup).joined(separator: "\n")

        var flowCards: [String] = []

        if let previous = neighbors.previous {
            flowCards.append(
                try renderProjectFlowCard(
                    previous,
                    eyebrow: label(labels, key: "previous_project", fallback: "Previous project"),
                    locale: locale,
                    localeContent: localeContent
                )
            )
        }

        flowCards.append(
            """
            <article class="card card--project-flow reveal">
              <span class="eyebrow">\(escapeHTML(localeContent.nav["projects"] ?? "Projects"))</span>
              <h3>\(escapeHTML(label(labels, key: "all_projects", fallback: "All projects")))</h3>
              <p>\(escapeHTML(label(labels, key: "project_index_copy", fallback: "Return to the full projects index to jump across current work, archive case studies, and side projects.")))</p>
              <div class="button-row">
                <a class="button button--secondary" href="\(try pagePath("projects", locale: locale))">\(escapeHTML(label(labels, key: "all_projects", fallback: "All projects")))</a>
              </div>
            </article>
            """
        )

        if let next = neighbors.next {
            flowCards.append(
                try renderProjectFlowCard(
                    next,
                    eyebrow: label(labels, key: "next_project", fallback: "Next project"),
                    locale: locale,
                    localeContent: localeContent
                )
            )
        }

        return """
            <section class="hero hero--page">
              <div class="shell hero__content hero__content--page">
                <a class="context-link" href="\(try pagePath("projects", locale: locale))">\(escapeHTML(label(labels, key: "back_to_projects", fallback: "Back to projects")))</a>
                <span class="eyebrow">\(escapeHTML(page.eyebrow))</span>
                <h1>\(escapeHTML(page.title))</h1>
                <p class="hero__lede">\(escapeHTML(page.intro))</p>
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell project-detail-layout">
                <aside class="project-detail-layout__aside">
                  \(sectionIndex)
                </aside>
                <div class="project-detail-layout__content">
            <section class="section section--compact project-detail__section" id="\(overviewID)">
                  <article class="card card--featured reveal">
                    <span class="eyebrow">\(escapeHTML(page.organization))</span>
                    \(renderProjectSectionTitle(
                      title: page.roleTitle,
                      sectionID: overviewID,
                    permalinkLabel: label(labels, key: "section_permalink", fallback: "Link to section")
                  ))
                  <p class="card__meta">\(escapeHTML(page.period))</p>
                    <p>\(escapeHTML(page.summary))</p>
                    \(renderList(page.highlights))
                  </article>
            </section>

            <section class="section section--compact project-detail__section" id="\(signalsID)">
              <div class="split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "context", fallback: "Context")))</span>
                  \(renderProjectSectionTitle(
                    title: label(labels, key: "key_signals", fallback: "Key signals"),
                    sectionID: signalsID,
                    permalinkLabel: label(labels, key: "section_permalink", fallback: "Link to section")
                  ))
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(label(labels, key: "signals_copy", fallback: "These signals compress the main product, delivery, and operating constraints into a quick scan before the deeper sections.")))</p>
                </div>
              </div>
              <div class="stat-grid">
                \(metrics)
              </div>
            </section>

            \(sections)
                </div>
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "context", fallback: "Context")))</span>
                  <h2>\(escapeHTML(label(labels, key: "continue_exploring", fallback: "Continue exploring")))</h2>
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(label(labels, key: "project_sequence_copy", fallback: "Move through the current case studies, archive work, and side projects without leaving the flow.")))</p>
                </div>
              </div>
              <div class="shell card-grid card-grid--three project-flow">
                \(flowCards.joined(separator: "\n"))
              </div>
            </section>
        """
    }

    /// Render the writing page.
    func renderWriting(locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let page = localeContent.writing
        let labels = localeContent.labels
        let themes = page.themes.map(renderContentCard).joined(separator: "\n")
        let archiveMarkup: String
        if page.posts.isEmpty {
            archiveMarkup = """
              <article class="card card--empty reveal">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "status", fallback: "Status")))</span>
                <h3>\(escapeHTML(page.emptyStateTitle))</h3>
                <p>\(escapeHTML(page.emptyStateCopy))</p>
              </article>
            """
        } else {
            archiveMarkup = try page.posts.map {
                try renderWritingPostCard($0, locale: locale, localeContent: localeContent)
            }.joined(separator: "\n")
        }
        let publishingCards = page.publishingCards.map(renderContentCard).joined(separator: "\n")
        let systemCards = page.systemCards.map(renderContentCard).joined(separator: "\n")

        return """
            <section class="hero hero--page">
              <div class="shell hero__content hero__content--page">
                <span class="eyebrow">\(escapeHTML(page.eyebrow))</span>
                <h1>\(escapeHTML(page.title))</h1>
                <p class="hero__lede">\(escapeHTML(page.intro))</p>
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "current_focus", fallback: "Current focus")))</span>
                <h2>\(escapeHTML(page.themesHeading))</h2>
              </div>
              <div class="shell card-grid card-grid--three">
                \(themes)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "archive", fallback: "Archive")))</span>
                  <h2>\(escapeHTML(page.archiveHeading))</h2>
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(page.archiveIntro))</p>
                </div>
              </div>
              <div class="shell card-grid card-grid--two">
                \(archiveMarkup)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "context", fallback: "Context")))</span>
                <h2>\(escapeHTML(page.publishingHeading))</h2>
              </div>
              <div class="shell card-grid card-grid--three">
                \(publishingCards)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "approach", fallback: "Approach")))</span>
                <h2>\(escapeHTML(page.systemHeading))</h2>
              </div>
              <div class="shell card-grid card-grid--three">
                \(systemCards)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell">
                <article class="card card--empty reveal">
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "status", fallback: "Status")))</span>
                  <h2>\(escapeHTML(page.statusTitle))</h2>
                  <p>\(escapeHTML(page.statusCopy))</p>
                </article>
              </div>
            </section>
        """
    }

    /// Render a localized writing post page.
    func renderWritingPost(pageKey: String, locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let page = try writingDetail(pageKey: pageKey, localeContent: localeContent, locale: locale)
        let labels = localeContent.labels

        let metaCards = """
          <article class="stat-card reveal">
            <span class="stat-card__value">\(escapeHTML(page.publishedValue))</span>
            <span class="stat-card__label">\(escapeHTML(page.publishedLabel))</span>
          </article>
          <article class="stat-card reveal">
            <span class="stat-card__value">\(escapeHTML(page.readingTimeValue))</span>
            <span class="stat-card__label">\(escapeHTML(page.readingTimeLabel))</span>
          </article>
        """

        let sections = page.sections.map { section -> String in
            let paragraphs = section.paragraphs.map { "<p>\(escapeHTML($0))</p>" }.joined(separator: "\n")

            return """
            <section class="section section--compact">
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(section.eyebrow))</span>
                  <h2>\(escapeHTML(section.title))</h2>
                </div>
                <div class="section-copy">
                  \(paragraphs)
                  \(renderOptionalList(section.items))
                </div>
              </div>
            </section>
            """
        }.joined(separator: "\n")

        return """
            <section class="hero hero--page">
              <div class="shell hero__content hero__content--page">
                <a class="context-link" href="\(try pagePath("writing", locale: locale))">\(escapeHTML(label(labels, key: "back_to_writing", fallback: "Back to writing")))</a>
                <span class="eyebrow">\(escapeHTML(page.eyebrow))</span>
                <h1>\(escapeHTML(page.title))</h1>
                <p class="hero__lede">\(escapeHTML(page.intro))</p>
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell stat-grid stat-grid--two">
                \(metaCards)
              </div>
            </section>

            \(sections)
        """
    }

    /// Render the library page.
    func renderLibrary(locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let page = localeContent.library
        let labels = localeContent.labels

        let stats = page.stats.map {
            """
            <article class="stat-card reveal">
              <span class="stat-card__value">\(escapeHTML($0.value))</span>
              <span class="stat-card__label">\(escapeHTML($0.label))</span>
            </article>
            """
        }.joined(separator: "\n")

        let shelves = page.shelves.map(renderContentCard).joined(separator: "\n")
        let archiveMarkup: String
        if page.books.isEmpty {
            archiveMarkup = """
              <article class="card card--empty reveal">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "status", fallback: "Status")))</span>
                <h3>\(escapeHTML(page.emptyStateTitle))</h3>
                <p>\(escapeHTML(page.emptyStateCopy))</p>
              </article>
            """
        } else {
            archiveMarkup = try page.books.map {
                try renderLibraryEntryCard($0, locale: locale, localeContent: localeContent)
            }.joined(separator: "\n")
        }
        let trackingCards = page.trackingCards.map(renderContentCard).joined(separator: "\n")
        let systemCards = page.systemCards.map(renderContentCard).joined(separator: "\n")

        return """
            <section class="hero hero--page">
              <div class="shell hero__content hero__content--page">
                <span class="eyebrow">\(escapeHTML(page.eyebrow))</span>
                <h1>\(escapeHTML(page.title))</h1>
                <p class="hero__lede">\(escapeHTML(page.intro))</p>
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell stat-grid">
                \(stats)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "featured", fallback: "Featured")))</span>
                <h2>\(escapeHTML(page.shelvesHeading))</h2>
              </div>
              <div class="shell card-grid card-grid--three">
                \(shelves)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "archive", fallback: "Archive")))</span>
                  <h2>\(escapeHTML(page.archiveHeading))</h2>
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(page.archiveIntro))</p>
                </div>
              </div>
              <div class="shell card-grid card-grid--two">
                \(archiveMarkup)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "tracking", fallback: "Tracking")))</span>
                <h2>\(escapeHTML(page.trackingHeading))</h2>
              </div>
              <div class="shell card-grid card-grid--three">
                \(trackingCards)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "approach", fallback: "Approach")))</span>
                <h2>\(escapeHTML(page.systemHeading))</h2>
              </div>
              <div class="shell card-grid card-grid--three">
                \(systemCards)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell">
                <article class="card card--empty reveal">
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "tracking", fallback: "Tracking")))</span>
                  <h2>\(escapeHTML(page.statusTitle))</h2>
                  <p>\(escapeHTML(page.statusCopy))</p>
                </article>
              </div>
            </section>
        """
    }

    /// Render a localized library entry page.
    func renderLibraryEntry(pageKey: String, locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let page = try libraryDetail(pageKey: pageKey, localeContent: localeContent, locale: locale)
        let labels = localeContent.labels

        let metaCards = page.metrics.map {
            """
            <article class="stat-card reveal">
              <span class="stat-card__value">\(escapeHTML($0.value))</span>
              <span class="stat-card__label">\(escapeHTML($0.label))</span>
            </article>
            """
        }.joined(separator: "\n")

        let sections = page.sections.map { section -> String in
            let paragraphs = section.paragraphs.map { "<p>\(escapeHTML($0))</p>" }.joined(separator: "\n")

            return """
            <section class="section section--compact">
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(section.eyebrow))</span>
                  <h2>\(escapeHTML(section.title))</h2>
                </div>
                <div class="section-copy">
                  \(paragraphs)
                  \(renderOptionalList(section.items))
                </div>
              </div>
            </section>
            """
        }.joined(separator: "\n")

        return """
            <section class="hero hero--page">
              <div class="shell hero__content hero__content--page">
                <a class="context-link" href="\(try pagePath("library", locale: locale))">\(escapeHTML(label(labels, key: "back_to_library", fallback: "Back to library")))</a>
                <span class="eyebrow">\(escapeHTML(page.eyebrow))</span>
                <h1>\(escapeHTML(page.title))</h1>
                <p class="hero__lede">\(escapeHTML(page.intro))</p>
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell stat-grid stat-grid--two">
                \(metaCards)
              </div>
            </section>

            \(sections)
        """
    }

    /// Render the about page.
    func renderAbout(locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let page = localeContent.about
        let labels = localeContent.labels

        let skills = page.skillGroups.map {
            """
            <article class="card reveal">
              <span class="eyebrow">\(escapeHTML($0.title))</span>
              \(renderList($0.items, className: "tag-list"))
            </article>
            """
        }.joined(separator: "\n")

        let sportsCards = page.sportsCards.map(renderContentCard).joined(separator: "\n")
        let sportsArchiveMarkup: String
        if page.sportsEntries.isEmpty {
            sportsArchiveMarkup = """
              <article class="card card--empty reveal">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "status", fallback: "Status")))</span>
                <h3>\(escapeHTML(page.sportsEmptyStateTitle))</h3>
                <p>\(escapeHTML(page.sportsEmptyStateCopy))</p>
              </article>
            """
        } else {
            sportsArchiveMarkup = page.sportsEntries.map(renderContentCard).joined(separator: "\n")
        }
        let trophyCards = page.trophyCards.map(renderContentCard).joined(separator: "\n")
        let trophyArchiveMarkup: String
        if page.trophyEntries.isEmpty {
            trophyArchiveMarkup = """
              <article class="card card--empty reveal">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "status", fallback: "Status")))</span>
                <h3>\(escapeHTML(page.trophiesEmptyStateTitle))</h3>
                <p>\(escapeHTML(page.trophiesEmptyStateCopy))</p>
              </article>
            """
        } else {
            trophyArchiveMarkup = page.trophyEntries.map(renderContentCard).joined(separator: "\n")
        }

        let socialLinks = payload.site.socials.map {
            #"<a class="button button--secondary" href="\#(escapeHTML($0.href))" rel="noopener noreferrer" target="_blank">\#(escapeHTML($0.label))</a>"#
        }.joined()

        return """
            <section class="hero hero--page">
              <div class="shell hero__content hero__content--page">
                <span class="eyebrow">\(escapeHTML(page.eyebrow))</span>
                <h1>\(escapeHTML(page.title))</h1>
                <p class="hero__lede">\(escapeHTML(page.intro))</p>
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "profile", fallback: "Profile")))</span>
                  <h2>\(escapeHTML(page.skillsHeading))</h2>
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(page.bio))</p>
                </div>
              </div>
              <div class="shell card-grid card-grid--three">
                \(skills)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "life", fallback: "Life")))</span>
                  <h2>\(escapeHTML(page.sportsTitle))</h2>
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(page.sportsCopy))</p>
                </div>
              </div>
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "archive", fallback: "Archive")))</span>
                  <h3>\(escapeHTML(page.sportsArchiveHeading))</h3>
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(page.sportsArchiveIntro))</p>
                </div>
              </div>
              <div class="shell card-grid card-grid--two">
                \(sportsArchiveMarkup)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "approach", fallback: "Approach")))</span>
                <h2>\(escapeHTML(page.sportsSystemHeading))</h2>
              </div>
              <div class="shell card-grid card-grid--three">
                \(sportsCards)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "milestones", fallback: "Milestones")))</span>
                  <h2>\(escapeHTML(page.trophiesTitle))</h2>
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(page.trophiesCopy))</p>
                </div>
              </div>
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "archive", fallback: "Archive")))</span>
                  <h3>\(escapeHTML(page.trophiesArchiveHeading))</h3>
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(page.trophiesArchiveIntro))</p>
                </div>
              </div>
              <div class="shell card-grid card-grid--two">
                \(trophyArchiveMarkup)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell section-heading">
                <span class="eyebrow">\(escapeHTML(label(labels, key: "approach", fallback: "Approach")))</span>
                <h2>\(escapeHTML(page.trophiesSystemHeading))</h2>
              </div>
              <div class="shell card-grid card-grid--three">
                \(trophyCards)
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell">
                <article class="card card--featured reveal">
                  <span class="eyebrow">\(escapeHTML(label(labels, key: "reach_out", fallback: "Reach out")))</span>
                  <h2>\(escapeHTML(page.contactTitle))</h2>
                  <p>\(escapeHTML(page.contactCopy))</p>
                  <div class="button-row">
                    <a class="button button--primary" href="mailto:\(escapeHTML(payload.site.contactEmail))">\(escapeHTML(label(labels, key: "email", fallback: "Email")))</a>
                    \(socialLinks)
                  </div>
                </article>
              </div>
            </section>
        """
    }

    /// Dispatch page rendering by key.
    func renderMain(pageKey: String, locale: String) throws -> String {
        switch pageKey {
        case "home":
            return try renderHome(locale: locale)
        case "work":
            return try renderWork(locale: locale)
        case "projects":
            return try renderProjects(locale: locale)
        case "writing":
            return try renderWriting(locale: locale)
        case "library":
            return try renderLibrary(locale: locale)
        case "about":
            return try renderAbout(locale: locale)
        default:
            let localeContent = try localeContent(locale)

            if localeContent.projectDetails[pageKey] != nil {
                return try renderProjectDetail(pageKey: pageKey, locale: locale)
            }

            if localeContent.writingDetails[pageKey] != nil {
                return try renderWritingPost(pageKey: pageKey, locale: locale)
            }

            if localeContent.libraryDetails[pageKey] != nil {
                return try renderLibraryEntry(pageKey: pageKey, locale: locale)
            }

            throw SiteBuilderError.missingRoute(pageKey: pageKey, locale: locale)
        }
    }

    /// Build a schema.org organization object.
    func organizationSchema(name: String) -> [String: Any] {
        [
            "@type": "Organization",
            "name": name
        ]
    }

    /// Build a breadcrumb graph node for non-home pages.
    func breadcrumbGraph(pageKey: String, locale: String, localeContent: LocaleContent) throws -> [String: Any]? {
        guard pageKey != "home" else {
            return nil
        }

        let homeURL = absoluteURL(for: try pagePath("home", locale: locale))
        var elements: [[String: Any]] = [[
            "@type": "ListItem",
            "position": 1,
            "name": localeContent.nav["home"] ?? "Home",
            "item": homeURL
        ]]

        var position = 2

        if pageKey.hasPrefix("project-") {
            let projectsURL = absoluteURL(for: try pagePath("projects", locale: locale))
            let detailPage = try projectDetail(pageKey: pageKey, localeContent: localeContent, locale: locale)
            elements.append([
                "@type": "ListItem",
                "position": position,
                "name": localeContent.nav["projects"] ?? "Projects",
                "item": projectsURL
            ])
            position += 1
            elements.append([
                "@type": "ListItem",
                "position": position,
                "name": detailPage.eyebrow,
                "item": absoluteURL(for: try pagePath(pageKey, locale: locale))
            ])
        } else if pageKey.hasPrefix("post-") {
            let writingURL = absoluteURL(for: try pagePath("writing", locale: locale))
            let detailPage = try writingDetail(pageKey: pageKey, localeContent: localeContent, locale: locale)
            elements.append([
                "@type": "ListItem",
                "position": position,
                "name": localeContent.nav["writing"] ?? "Writing",
                "item": writingURL
            ])
            position += 1
            elements.append([
                "@type": "ListItem",
                "position": position,
                "name": detailPage.title,
                "item": absoluteURL(for: try pagePath(pageKey, locale: locale))
            ])
        } else if pageKey.hasPrefix("book-") {
            let libraryURL = absoluteURL(for: try pagePath("library", locale: locale))
            let detailPage = try libraryDetail(pageKey: pageKey, localeContent: localeContent, locale: locale)
            elements.append([
                "@type": "ListItem",
                "position": position,
                "name": localeContent.nav["library"] ?? "Library",
                "item": libraryURL
            ])
            position += 1
            elements.append([
                "@type": "ListItem",
                "position": position,
                "name": detailPage.title,
                "item": absoluteURL(for: try pagePath(pageKey, locale: locale))
            ])
        } else {
            let metadata = try pageMetadata(pageKey: pageKey, localeContent: localeContent, locale: locale)
            let pageName = localeContent.nav[pageKey] ?? metadata.title
            elements.append([
                "@type": "ListItem",
                "position": position,
                "name": pageName,
                "item": absoluteURL(for: try pagePath(pageKey, locale: locale))
            ])
        }

        return [
            "@type": "BreadcrumbList",
            "itemListElement": elements
        ]
    }

    /// Build page-specific structured data nodes.
    func pageSpecificStructuredData(
        pageKey: String,
        locale: String,
        localeContent: LocaleContent,
        canonicalURL: String,
        personID: String,
        websiteID: String
    ) throws -> [[String: Any]] {
        let commonPage: [String: Any] = [
            "url": canonicalURL,
            "inLanguage": localeContent.localeCode,
            "isPartOf": ["@id": websiteID],
            "about": ["@id": personID]
        ]

        switch pageKey {
        case "home":
            return [[
                "@type": "ProfilePage",
                "name": payload.site.name,
                "description": localeContent.home.description,
                "mainEntity": ["@id": personID]
            ].merging(commonPage, uniquingKeysWith: { _, new in new })]
        case "work":
            return [[
                "@type": "AboutPage",
                "name": localeContent.work.pageTitle,
                "description": localeContent.work.description
            ].merging(commonPage, uniquingKeysWith: { _, new in new })]
        case "projects":
            return [[
                "@type": "CollectionPage",
                "name": localeContent.projects.pageTitle,
                "description": localeContent.projects.description
            ].merging(commonPage, uniquingKeysWith: { _, new in new })]
        case "writing":
            return [
                [
                    "@type": "CollectionPage",
                    "name": localeContent.writing.pageTitle,
                    "description": localeContent.writing.description
                ].merging(commonPage, uniquingKeysWith: { _, new in new }),
                [
                    "@type": "Blog",
                    "name": localeContent.writing.eyebrow,
                    "description": localeContent.writing.description,
                    "url": canonicalURL,
                    "inLanguage": localeContent.localeCode,
                    "author": ["@id": personID],
                    "publisher": ["@id": personID]
                ]
            ]
        case "library":
            return [[
                "@type": "CollectionPage",
                "name": localeContent.library.pageTitle,
                "description": localeContent.library.description
            ].merging(commonPage, uniquingKeysWith: { _, new in new })]
        case "about":
            return [[
                "@type": "AboutPage",
                "name": localeContent.about.pageTitle,
                "description": localeContent.about.description,
                "mainEntity": ["@id": personID]
            ].merging(commonPage, uniquingKeysWith: { _, new in new })]
        default:
            if let detailPage = localeContent.projectDetails[pageKey] {
                return [
                    [
                        "@type": "WebPage",
                        "name": detailPage.pageTitle,
                        "description": detailPage.description,
                        "mainEntity": ["@id": canonicalURL + "#project"]
                    ].merging(commonPage, uniquingKeysWith: { _, new in new }),
                    [
                        "@type": "CreativeWork",
                        "@id": canonicalURL + "#project",
                        "name": detailPage.eyebrow,
                        "description": detailPage.description,
                        "creator": ["@id": personID],
                        "publisher": organizationSchema(name: detailPage.organization),
                        "inLanguage": localeContent.localeCode,
                        "url": canonicalURL
                    ]
                ]
            }

            if let detailPage = localeContent.writingDetails[pageKey] {
                return [
                    [
                        "@type": "WebPage",
                        "name": detailPage.pageTitle,
                        "description": detailPage.description,
                        "mainEntity": ["@id": canonicalURL + "#article"]
                    ].merging(commonPage, uniquingKeysWith: { _, new in new }),
                    [
                        "@type": "BlogPosting",
                        "@id": canonicalURL + "#article",
                        "headline": detailPage.title,
                        "description": detailPage.description,
                        "author": ["@id": personID],
                        "publisher": ["@id": personID],
                        "mainEntityOfPage": canonicalURL,
                        "inLanguage": localeContent.localeCode,
                        "url": canonicalURL
                    ]
                ]
            }

            if let detailPage = localeContent.libraryDetails[pageKey] {
                return [
                    [
                        "@type": "WebPage",
                        "name": detailPage.pageTitle,
                        "description": detailPage.description,
                        "mainEntity": ["@id": canonicalURL + "#entry"]
                    ].merging(commonPage, uniquingKeysWith: { _, new in new }),
                    [
                        "@type": "CreativeWork",
                        "@id": canonicalURL + "#entry",
                        "name": detailPage.title,
                        "description": detailPage.description,
                        "creator": ["@id": personID],
                        "inLanguage": localeContent.localeCode,
                        "url": canonicalURL
                    ]
                ]
            }

            return [[
                "@type": "WebPage",
                "name": try pageMetadata(pageKey: pageKey, localeContent: localeContent, locale: locale).title,
                "description": try pageMetadata(pageKey: pageKey, localeContent: localeContent, locale: locale).description
            ].merging(commonPage, uniquingKeysWith: { _, new in new })]
        }
    }

    /// Build the JSON-LD payload for the page.
    func renderStructuredData(pageKey: String, locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let canonicalURL = absoluteURL(for: try pagePath(pageKey, locale: locale))
        let personID = payload.site.baseUrl + "/#person"
        let websiteID = payload.site.baseUrl + "/#website"

        var graph: [[String: Any]] = [
            [
                "@type": "Person",
                "@id": personID,
                "name": payload.site.name,
                "url": absoluteURL(for: try pagePath("home", locale: locale)),
                "jobTitle": payload.site.leadTitle,
                "worksFor": organizationSchema(name: "Roole"),
                "sameAs": payload.site.socials.map(\.href),
                "knowsAbout": [
                    "Mobile Engineering",
                    "Engineering Management",
                    "iOS Development",
                    "SwiftUI",
                    "Technical Architecture",
                    "Product Delivery",
                    "Agentic Engineering"
                ]
            ],
            [
                "@type": "WebSite",
                "@id": websiteID,
                "name": payload.site.name,
                "url": payload.site.baseUrl + "/",
                "inLanguage": localeContent.localeCode,
                "publisher": ["@id": personID]
            ]
        ]

        graph.append(contentsOf: try pageSpecificStructuredData(
            pageKey: pageKey,
            locale: locale,
            localeContent: localeContent,
            canonicalURL: canonicalURL,
            personID: personID,
            websiteID: websiteID
        ))

        if let breadcrumb = try breadcrumbGraph(pageKey: pageKey, locale: locale, localeContent: localeContent) {
            graph.append(breadcrumb)
        }

        let object: [String: Any] = [
            "@context": "https://schema.org",
            "@graph": graph
        ]

        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    /// Render the root 404 document with locale-aware recovery links.
    func renderNotFoundDocument() throws -> String {
        let english = try localeContent("en")
        let translations = try renderNotFoundTranslations()

        return """
        <!--
          404.html
          \(payload.site.appName)

          Created by Loïc Lavergne on 25/03/2026
          Copyright © 2026 Loïc Lavergne. All rights reserved.
        -->
        <!DOCTYPE html>
        <html lang="en" data-theme="auto">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="robots" content="noindex">
          <meta name="theme-color" content="#f5f5f7" media="(prefers-color-scheme: light)">
          <meta name="theme-color" content="#05080d" media="(prefers-color-scheme: dark)">
          <link rel="icon" href="/assets/img/og/og-default.svg" type="image/svg+xml">
        \(renderThemeBootstrapScript())
          <link rel="stylesheet" href="/css/tokens.css">
          <link rel="stylesheet" href="/css/site.css">
          <style>
            .error-page {
              min-height: 100vh;
              display: grid;
              align-items: center;
              padding: 2rem 0;
            }

            .error-card {
              gap: 1.25rem;
            }

            .error-card h1 {
              max-width: 10ch;
            }

            .route-grid {
              display: grid;
              grid-template-columns: repeat(3, minmax(0, 1fr));
              gap: 0.85rem;
            }

            .route-link {
              display: grid;
              gap: 0.3rem;
              padding: 1rem 1.1rem;
              border-radius: var(--radius-sm);
              border: 1px solid var(--surface-border);
              background: var(--page-background-strong);
              transition:
                transform var(--duration-fast) var(--easing-standard),
                border-color var(--duration-fast) var(--easing-standard),
                background var(--duration-fast) var(--easing-standard);
            }

            .route-link:hover {
              transform: translateY(-1px);
              border-color: var(--surface-border-strong);
            }

            .route-link__label {
              color: var(--text-primary);
              font-weight: 590;
              letter-spacing: -0.01em;
            }

            .route-link__path {
              color: var(--text-tertiary);
              font-family: var(--font-mono);
              font-size: 0.8rem;
            }

            .error-note {
              color: var(--text-tertiary);
              font-size: 0.95rem;
            }

            @media (max-width: 760px) {
              .route-grid {
                grid-template-columns: 1fr;
              }
            }
          </style>
          <title>\(escapeHTML(english.notFound.documentTitle))</title>
        </head>
        <body data-page="not-found">
          <main class="error-page" id="main">
            <section class="shell">
              <article class="card card--featured error-card">
                <span class="eyebrow" id="error-code">404</span>
                <h1 id="error-title">\(escapeHTML(english.notFound.title))</h1>
                <p class="hero__lede" id="error-copy">\(escapeHTML(english.notFound.copy))</p>
                <div class="button-row">
                  <a class="button button--primary" id="home-link" href="/">\(escapeHTML(english.notFound.home))</a>
                  <a class="button button--secondary" id="primary-link" href="/work/">\(escapeHTML(english.notFound.primary))</a>
                </div>
                <div class="route-grid" id="route-grid" aria-label="\(escapeHTML(english.notFound.ariaLabel))"></div>
                <p class="error-note" id="error-note">\(escapeHTML(english.notFound.note))</p>
              </article>
            </section>
          </main>
          <script>
            (() => {
              const translations = \(translations);

              function normalizePathname(pathname) {
                let normalized = pathname || "/";
                normalized = normalized.replace(/index\\.html$/, "");
                if (!normalized.endsWith("/")) {
                  normalized += "/";
                }
                return normalized;
              }

              const normalizedPathname = normalizePathname(window.location.pathname);
              const locale = normalizedPathname.startsWith("/fr/") ? "fr" : "en";
              const content = translations[locale];
              const primaryRoute = content.routes[1];

              document.documentElement.lang = locale;
              document.title = content.documentTitle;
              document.getElementById("error-title").textContent = content.title;
              document.getElementById("error-copy").textContent = content.copy;
              document.getElementById("error-note").textContent = content.note;

              const homeLink = document.getElementById("home-link");
              homeLink.href = content.routes[0].href;
              homeLink.textContent = content.home;

              const primaryLink = document.getElementById("primary-link");
              primaryLink.href = primaryRoute.href;
              primaryLink.textContent = content.primary;

              const routeGrid = document.getElementById("route-grid");
              routeGrid.setAttribute("aria-label", content.ariaLabel);
              routeGrid.replaceChildren(...content.routes.map((route) => {
                const link = document.createElement("a");
                link.className = "route-link";
                link.href = route.href;

                const label = document.createElement("span");
                label.className = "route-link__label";
                label.textContent = route.label;

                const path = document.createElement("span");
                path.className = "route-link__path";
                path.textContent = route.href;

                link.append(label, path);
                return link;
              }));
            })();
          </script>
        </body>
        </html>
        """
    }

    /// Render a complete localized HTML document.
    func renderDocument(pageKey: String, locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let canonicalPath = try pagePath(pageKey, locale: locale)
        let alternateEN = absoluteURL(for: try pagePath(pageKey, locale: "en"))
        let alternateFR = absoluteURL(for: try pagePath(pageKey, locale: "fr"))
        let metadata = try pageMetadata(pageKey: pageKey, localeContent: localeContent, locale: locale)
        let pageTitle = metadata.title
        let description = metadata.description

        let ogImage = absoluteURL(for: localeContent.seo.ogImage)
        let englishFeed = absoluteFeedURL(for: "en")
        let frenchFeed = absoluteFeedURL(for: "fr")
        let manifestURL = absoluteManifestURL(for: locale)

        return """
        <!--
          \(pageKey).html
          \(payload.site.appName)

          Created by Loïc Lavergne on 25/03/2026
          Copyright © 2026 Loïc Lavergne. All rights reserved.
        -->
        <!DOCTYPE html>
        <html lang="\(escapeHTML(localeContent.htmlLang))" data-theme="auto">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="description" content="\(escapeHTML(description))">
          <meta name="author" content="\(escapeHTML(payload.site.name))">
          <meta name="robots" content="index,follow">
          <meta name="theme-color" content="#f5f5f7" media="(prefers-color-scheme: light)">
          <meta name="theme-color" content="#05080d" media="(prefers-color-scheme: dark)">
          <meta property="og:site_name" content="\(escapeHTML(payload.site.name))">
          <meta property="og:type" content="website">
          <meta property="og:locale" content="\(escapeHTML(localeContent.localeCode))">
          <meta property="og:title" content="\(escapeHTML(pageTitle))">
          <meta property="og:description" content="\(escapeHTML(description))">
          <meta property="og:url" content="\(escapeHTML(absoluteURL(for: canonicalPath)))">
          <meta property="og:image" content="\(escapeHTML(ogImage))">
          <meta name="twitter:card" content="summary_large_image">
          <meta name="twitter:title" content="\(escapeHTML(pageTitle))">
          <meta name="twitter:description" content="\(escapeHTML(description))">
          <meta name="twitter:image" content="\(escapeHTML(ogImage))">
          <link rel="canonical" href="\(escapeHTML(absoluteURL(for: canonicalPath)))">
          <link rel="alternate" hreflang="en" href="\(escapeHTML(alternateEN))">
          <link rel="alternate" hreflang="fr" href="\(escapeHTML(alternateFR))">
          <link rel="alternate" hreflang="x-default" href="\(escapeHTML(alternateEN))">
          <link rel="alternate" type="application/atom+xml" title="\(escapeHTML(payload.site.name)) Writing" href="\(escapeHTML(englishFeed))">
          <link rel="alternate" type="application/atom+xml" title="\(escapeHTML(payload.site.name)) Écrits" href="\(escapeHTML(frenchFeed))">
          <link rel="manifest" href="\(escapeHTML(manifestURL))">
          <link rel="me" href="https://github.com/loiclavergne/">
          <link rel="me" href="https://www.linkedin.com/in/loiclavergne/">
          <link rel="me" href="https://bsky.app/profile/loic.engineer">
          <link rel="me" href="https://www.instagram.com/loic.lavergne.tech">
          <link rel="icon" href="/assets/img/og/og-default.svg" type="image/svg+xml">
        \(renderThemeBootstrapScript())
          <link rel="stylesheet" href="/css/tokens.css">
          <link rel="stylesheet" href="/css/site.css">
          <title>\(escapeHTML(pageTitle))</title>
          <script type="application/ld+json">
        \(try renderStructuredData(pageKey: pageKey, locale: locale))
          </script>
        </head>
        <body data-page="\(escapeHTML(pageKey))">
          <a class="skip-link" href="#main">\(escapeHTML(localeContent.skipLink))</a>
          <div
            class="visually-hidden"
            aria-live="polite"
            aria-atomic="true"
            data-section-announce
            data-copy-success="\(escapeHTML(label(localeContent.labels, key: "section_link_copied", fallback: "Section link copied.")))"
            data-copy-failure="\(escapeHTML(label(localeContent.labels, key: "section_link_copy_failed", fallback: "Could not copy section link.")))"
          ></div>
        \(try renderNav(locale: locale, currentPage: pageKey))
          <main id="main">
        \(try renderMain(pageKey: pageKey, locale: locale))
          </main>
        \(try renderFooter(locale: locale))
        \(try renderSearchModal(currentPage: pageKey, locale: locale))
          <script type="module" src="/js/site.js"></script>
        </body>
        </html>
        """
    }
}
