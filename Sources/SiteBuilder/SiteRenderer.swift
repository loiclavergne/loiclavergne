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

    /// Write sitemap.xml for the generated route set.
    func buildSitemap(urls: [String]) throws {
        let entries = urls.map {
            """
              <url>
                <loc>\($0)</loc>
                <lastmod>\(payload.site.buildDate)</lastmod>
              </url>
            """
        }.joined(separator: "\n")

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        \(entries)
        </urlset>
        """

        try xml.write(to: rootURL.appendingPathComponent("sitemap.xml"), atomically: true, encoding: .utf8)
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

        let metrics = page.metrics.map {
            """
            <article class="stat-card reveal">
              <span class="stat-card__value">\(escapeHTML($0.value))</span>
              <span class="stat-card__label">\(escapeHTML($0.label))</span>
            </article>
            """
        }.joined(separator: "\n")

        let sections = page.sections.map { section -> String in
            let cards = section.cards.map(renderContentCard).joined(separator: "\n")

            return """
            <section class="section section--compact">
              <div class="shell split-heading">
                <div>
                  <span class="eyebrow">\(escapeHTML(section.eyebrow))</span>
                  <h2>\(escapeHTML(section.title))</h2>
                </div>
                <div class="section-copy">
                  <p>\(escapeHTML(section.intro))</p>
                </div>
              </div>
              <div class="shell card-grid card-grid--three">
                \(cards)
              </div>
            </section>
            """
        }.joined(separator: "\n")

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
              <div class="shell">
                <article class="card card--featured reveal">
                  <span class="eyebrow">\(escapeHTML(page.organization))</span>
                  <h2>\(escapeHTML(page.roleTitle))</h2>
                  <p class="card__meta">\(escapeHTML(page.period))</p>
                  <p>\(escapeHTML(page.summary))</p>
                  \(renderList(page.highlights))
                </article>
              </div>
            </section>

            <section class="section section--compact">
              <div class="shell stat-grid">
                \(metrics)
              </div>
            </section>

            \(sections)
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

    /// Build the JSON-LD payload for the page.
    func renderStructuredData(pageKey: String, locale: String) throws -> String {
        let localeContent = try localeContent(locale)
        let pageTitle = try pageMetadata(pageKey: pageKey, localeContent: localeContent, locale: locale).title

        let graph: [[String: Any]] = [
            [
                "@type": "Person",
                "name": payload.site.name,
                "url": absoluteURL(for: try pagePath("home", locale: locale)),
                "jobTitle": payload.site.leadTitle,
                "worksFor": [
                    "@type": "Organization",
                    "name": "Roole"
                ],
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
                "name": payload.site.name,
                "url": payload.site.baseUrl + "/",
                "inLanguage": localeContent.localeCode
            ],
            [
                "@type": "WebPage",
                "name": pageTitle,
                "url": absoluteURL(for: try pagePath(pageKey, locale: locale)),
                "inLanguage": localeContent.localeCode
            ]
        ]

        let object: [String: Any] = [
            "@context": "https://schema.org",
            "@graph": graph
        ]

        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
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
          <link rel="me" href="https://github.com/loiclavergne/">
          <link rel="me" href="https://www.linkedin.com/in/loiclavergne/">
          <link rel="me" href="https://bsky.app/profile/loic.engineer">
          <link rel="me" href="https://www.instagram.com/loic.lavergne.tech">
          <link rel="icon" href="/assets/img/og/og-default.svg" type="image/svg+xml">
          <script>
            (() => {
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
          <link rel="stylesheet" href="/css/tokens.css">
          <link rel="stylesheet" href="/css/site.css">
          <title>\(escapeHTML(pageTitle))</title>
          <script type="application/ld+json">
        \(try renderStructuredData(pageKey: pageKey, locale: locale))
          </script>
        </head>
        <body data-page="\(escapeHTML(pageKey))">
          <a class="skip-link" href="#main">\(escapeHTML(localeContent.skipLink))</a>
        \(try renderNav(locale: locale, currentPage: pageKey))
          <main id="main">
        \(try renderMain(pageKey: pageKey, locale: locale))
          </main>
        \(try renderFooter(locale: locale))
          <script type="module" src="/js/site.js"></script>
        </body>
        </html>
        """
    }
}
