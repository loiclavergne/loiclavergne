//
//  SiteModels.swift
//  Loic Engineer Portfolio
//
//  Created by Loïc Lavergne on 25/03/2026
//  Copyright © 2026 Loïc Lavergne. All rights reserved.
//

import Foundation

/// Structured site payload loaded from the bundled JSON resource.
struct SitePayload: Decodable {
    let site: SiteMetadata
    let routes: [String: [String: String]]
    let pageKeys: [String]
    let locales: [String: LocaleContent]

    enum CodingKeys: String, CodingKey {
        case site
        case routes
        case pageKeys
        case locales
    }

    /// Load the site payload from split SwiftPM JSON resources.
    static func load() throws -> SitePayload {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let core: SiteCorePayload = try loadResource(
            named: "site-metadata",
            decoder: decoder
        )
        let locales = [
            "en": try loadResource(named: "en", subdirectory: "locales", decoder: decoder) as LocaleContent,
            "fr": try loadResource(named: "fr", subdirectory: "locales", decoder: decoder) as LocaleContent
        ]

        return SitePayload(
            site: core.site,
            routes: core.routes,
            pageKeys: core.pageKeys,
            locales: locales
        )
    }

    /// Validate that routes, localized content, and detail-page inventories stay aligned.
    func validate() throws {
        var issues: [String] = []
        let localeKeys = Set(locales.keys)
        let pageKeySet = Set(pageKeys)
        let routeKeySet = Set(routes.keys)
        let primaryNavigationKeys = Set(["home", "work", "projects", "writing", "library", "about"])
        let projectPageKeys = Set(pageKeys.filter { $0.hasPrefix("project-") })
        let writingPageKeys = Set(pageKeys.filter { $0.hasPrefix("post-") })
        let libraryPageKeys = Set(pageKeys.filter { $0.hasPrefix("book-") })

        if pageKeys.count != pageKeySet.count {
            issues.append("Found duplicate entries in pageKeys.")
        }

        appendDifferenceIssues(
            label: "route maps",
            expected: pageKeySet,
            actual: routeKeySet,
            issues: &issues
        )

        for pageKey in pageKeys {
            guard let localizedRoutes = routes[pageKey] else {
                continue
            }

            appendDifferenceIssues(
                label: "route locales for \(pageKey)",
                expected: localeKeys,
                actual: Set(localizedRoutes.keys),
                issues: &issues
            )
        }

        for (locale, content) in locales {
            if !localeKeys.contains(content.switchLocale) {
                issues.append("Locale \(locale) points to unknown switch locale \(content.switchLocale).")
            }

            appendDifferenceIssues(
                label: "navigation keys for \(locale)",
                expected: primaryNavigationKeys,
                actual: Set(content.nav.keys),
                issues: &issues
            )

            appendDifferenceIssues(
                label: "project detail keys for \(locale)",
                expected: projectPageKeys,
                actual: Set(content.projectDetails.keys),
                issues: &issues
            )

            appendDifferenceIssues(
                label: "writing detail keys for \(locale)",
                expected: writingPageKeys,
                actual: Set(content.writingDetails.keys),
                issues: &issues
            )

            appendDifferenceIssues(
                label: "library detail keys for \(locale)",
                expected: libraryPageKeys,
                actual: Set(content.libraryDetails.keys),
                issues: &issues
            )

            appendReferencedRouteIssues(
                locale: locale,
                routeGroups: [
                    ("featured projects", content.projects.featured.compactMap(\.route)),
                    ("archive projects", content.projects.archive.compactMap(\.route)),
                    ("hobby projects", content.projects.hobby.compactMap(\.route)),
                    ("writing posts", content.writing.posts.compactMap(\.route)),
                    ("library entries", content.library.books.compactMap(\.route))
                ],
                knownPageKeys: pageKeySet,
                issues: &issues
            )
        }

        if !issues.isEmpty {
            throw SiteBuilderError.invalidPayload(issues)
        }
    }

    /// Load and decode one bundled JSON resource.
    private static func loadResource<T: Decodable>(
        named resourceName: String,
        subdirectory: String? = nil,
        decoder: JSONDecoder
    ) throws -> T {
        guard let baseURL = Bundle.module.resourceURL else {
            let resourcePath = subdirectory.map { "\($0)/\(resourceName).json" } ?? "\(resourceName).json"
            throw SiteBuilderError.missingResource(resourcePath)
        }

        let candidatePaths = [
            subdirectory.map { "\($0)/\(resourceName).json" },
            "\(resourceName).json"
        ].compactMap { $0 }

        guard let resourceURL = candidatePaths
            .map({ baseURL.appendingPathComponent($0) })
            .first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            let preferredPath = subdirectory.map { "\($0)/\(resourceName).json" } ?? "\(resourceName).json"
            throw SiteBuilderError.missingResource(preferredPath)
        }

        let data = try Data(contentsOf: resourceURL)
        return try decoder.decode(T.self, from: data)
    }

    /// Append missing or unexpected keys for a validation set comparison.
    private func appendDifferenceIssues(
        label: String,
        expected: Set<String>,
        actual: Set<String>,
        issues: inout [String]
    ) {
        let missing = expected.subtracting(actual).sorted()
        let unexpected = actual.subtracting(expected).sorted()

        if !missing.isEmpty {
            issues.append("Missing \(label): \(missing.joined(separator: ", ")).")
        }

        if !unexpected.isEmpty {
            issues.append("Unexpected \(label): \(unexpected.joined(separator: ", ")).")
        }
    }

    /// Append route-reference issues for curated content sections.
    private func appendReferencedRouteIssues(
        locale: String,
        routeGroups: [(label: String, routes: [String])],
        knownPageKeys: Set<String>,
        issues: inout [String]
    ) {
        for group in routeGroups {
            let unknownRoutes = group.routes.filter { !knownPageKeys.contains($0) }.sorted()
            if !unknownRoutes.isEmpty {
                issues.append("Unknown \(group.label) in \(locale): \(unknownRoutes.joined(separator: ", ")).")
            }
        }
    }
}

private struct SiteCorePayload: Decodable {
    let site: SiteMetadata
    let routes: [String: [String: String]]
    let pageKeys: [String]
}

struct SiteMetadata: Decodable {
    let baseUrl: String
    let name: String
    let appName: String
    let leadTitle: String
    let buildDate: String
    let contactEmail: String
    let socials: [SocialLink]
}

struct SocialLink: Decodable {
    let label: String
    let href: String
}

struct LocaleContent: Decodable {
    let htmlLang: String
    let localeCode: String
    let switchLocale: String
    let switchLabel: String
    let skipLink: String
    let nav: [String: String]
    let labels: [String: String]
    let footer: FooterContent
    let theme: ThemeContent
    let search: SearchContent
    let seo: SEOContent
    let notFound: NotFoundContent
    let home: HomePage
    let work: WorkPage
    let projects: ProjectsPage
    let projectDetails: [String: ProjectDetailPage]
    let writing: WritingPage
    let writingDetails: [String: WritingPostPage]
    let library: LibraryPage
    let libraryDetails: [String: LibraryEntryPage]
    let about: AboutPage
}

struct FooterContent: Decodable {
    let tagline: String
    let copyright: String
}

struct ThemeContent: Decodable {
    let label: String
    let auto: String
    let light: String
    let dark: String
}

struct SearchContent: Decodable {
    let button: String
    let hint: String
    let title: String
    let placeholder: String
    let loading: String
    let fallbackNote: String
    let quickActionsLabel: String
    let recentLabel: String
    let clearRecent: String
    let recoveryLabel: String
    let switchLocaleDescription: String
    let suggestedLabel: String
    let themeAutoDescription: String
    let themeLightDescription: String
    let themeDarkDescription: String
    let emptyState: String
    let noResults: String
    let resultsCountOne: String
    let resultsCountOther: String
    let unavailable: String
    let resultsLabel: String
    let close: String
    let clear: String
}

struct SEOContent: Decodable {
    let siteDescription: String
    let ogImage: String
}

struct NotFoundContent: Decodable {
    let documentTitle: String
    let title: String
    let copy: String
    let home: String
    let primary: String
    let note: String
    let ariaLabel: String
}

struct RouteAction: Decodable {
    let label: String
    let route: String
}

struct MetricItem: Decodable {
    let value: String
    let label: String
}

struct StoryStep: Decodable {
    let id: String
    let eyebrow: String
    let title: String
    let copy: String
    let facts: [String]
}

struct EntryPoint: Decodable {
    let route: String
    let title: String
    let copy: String
}

struct HomePage: Decodable {
    let pageTitle: String
    let description: String
    let eyebrow: String
    let title: String
    let lede: String
    let ctaPrimary: RouteAction
    let ctaSecondary: RouteAction
    let metrics: [MetricItem]
    let storyHeading: String
    let storyIntro: String
    let storySteps: [StoryStep]
    let featuredProjectsHeading: String
    let entryPointsHeading: String
    let entryPoints: [EntryPoint]
}

struct CurrentRole: Decodable {
    let organization: String
    let title: String
    let period: String
    let location: String
    let summary: String
    let highlights: [String]
}

struct ProductCard: Decodable {
    let name: String
    let summary: String
}

struct ExperienceItem: Decodable {
    let title: String
    let organization: String
    let period: String
    let summary: String
    let highlights: [String]?
}

struct WorkPage: Decodable {
    let pageTitle: String
    let description: String
    let eyebrow: String
    let title: String
    let intro: String
    let currentRole: CurrentRole
    let productCards: [ProductCard]
    let experienceHeading: String
    let experience: [ExperienceItem]
    let educationHeading: String
    let educationIntro: String
    let educationCards: [ContentCard]
}

struct FeaturedProject: Decodable {
    let name: String
    let period: String
    let summary: String
    let details: [String]
    let route: String?
}

struct SummaryProject: Decodable {
    let name: String
    let period: String?
    let summary: String
    let details: [String]?
    let route: String?
}

struct ProjectsPage: Decodable {
    let pageTitle: String
    let description: String
    let eyebrow: String
    let title: String
    let intro: String
    let featured: [FeaturedProject]
    let archiveHeading: String
    let archive: [SummaryProject]
    let hobbyHeading: String
    let hobby: [SummaryProject]
}

struct ProjectDetailSection: Decodable {
    let eyebrow: String
    let title: String
    let intro: String
    let cards: [ContentCard]
}

struct ProjectDetailPage: Decodable {
    let pageTitle: String
    let description: String
    let eyebrow: String
    let title: String
    let intro: String
    let roleTitle: String
    let organization: String
    let period: String
    let summary: String
    let highlights: [String]
    let metrics: [MetricItem]
    let sections: [ProjectDetailSection]
}

struct ContentCard: Decodable {
    let title: String
    let copy: String
    let items: [String]?
}

struct WritingPage: Decodable {
    let pageTitle: String
    let description: String
    let eyebrow: String
    let title: String
    let intro: String
    let themesHeading: String
    let themes: [ContentCard]
    let archiveHeading: String
    let archiveIntro: String
    let posts: [WritingPostSummary]
    let emptyStateTitle: String
    let emptyStateCopy: String
    let publishingHeading: String
    let publishingCards: [ContentCard]
    let systemHeading: String
    let systemCards: [ContentCard]
    let statusTitle: String
    let statusCopy: String
}

struct WritingPostSummary: Decodable {
    let title: String
    let summary: String
    let details: [String]?
    let route: String?
}

struct WritingPostSection: Decodable {
    let eyebrow: String
    let title: String
    let paragraphs: [String]
    let items: [String]?
}

struct WritingPostPage: Decodable {
    let pageTitle: String
    let description: String
    let eyebrow: String
    let title: String
    let intro: String
    let publishedLabel: String
    let publishedValue: String
    let readingTimeLabel: String
    let readingTimeValue: String
    let sections: [WritingPostSection]
}

struct ReadingStat: Decodable {
    let label: String
    let value: String
}

struct LibraryPage: Decodable {
    let pageTitle: String
    let description: String
    let eyebrow: String
    let title: String
    let intro: String
    let stats: [ReadingStat]
    let shelvesHeading: String
    let shelves: [ContentCard]
    let archiveHeading: String
    let archiveIntro: String
    let books: [LibraryEntrySummary]
    let emptyStateTitle: String
    let emptyStateCopy: String
    let trackingHeading: String
    let trackingCards: [ContentCard]
    let systemHeading: String
    let systemCards: [ContentCard]
    let statusTitle: String
    let statusCopy: String
}

struct LibraryEntrySummary: Decodable {
    let title: String
    let summary: String
    let details: [String]?
    let route: String?
}

struct LibraryEntryPage: Decodable {
    let pageTitle: String
    let description: String
    let eyebrow: String
    let title: String
    let intro: String
    let metrics: [MetricItem]
    let sections: [WritingPostSection]
}

struct SkillGroup: Decodable {
    let title: String
    let items: [String]
}

struct AboutPage: Decodable {
    let pageTitle: String
    let description: String
    let eyebrow: String
    let title: String
    let intro: String
    let bio: String
    let skillsHeading: String
    let skillGroups: [SkillGroup]
    let sportsTitle: String
    let sportsCopy: String
    let sportsArchiveHeading: String
    let sportsArchiveIntro: String
    let sportsEntries: [ContentCard]
    let sportsEmptyStateTitle: String
    let sportsEmptyStateCopy: String
    let sportsSystemHeading: String
    let sportsCards: [ContentCard]
    let trophiesTitle: String
    let trophiesCopy: String
    let trophiesArchiveHeading: String
    let trophiesArchiveIntro: String
    let trophyEntries: [ContentCard]
    let trophiesEmptyStateTitle: String
    let trophiesEmptyStateCopy: String
    let trophiesSystemHeading: String
    let trophyCards: [ContentCard]
    let contactTitle: String
    let contactCopy: String
}

enum SiteBuilderError: Error, LocalizedError {
    case missingResource(String)
    case missingRoute(pageKey: String, locale: String)
    case missingLocale(String)
    case invalidURL(String)
    case invalidPayload([String])
    case unknownArgument(String)

    var errorDescription: String? {
        switch self {
        case let .missingResource(name):
            return "Missing bundled resource: \(name)"
        case let .missingRoute(pageKey, locale):
            return "Missing route for page '\(pageKey)' and locale '\(locale)'"
        case let .missingLocale(locale):
            return "Missing locale content for '\(locale)'"
        case let .invalidURL(url):
            return "Invalid site URL: \(url)"
        case let .invalidPayload(issues):
            let details = issues.map { "- \($0)" }.joined(separator: "\n")
            return "Invalid site payload:\n\(details)"
        case let .unknownArgument(argument):
            return "Unknown argument '\(argument)'."
        }
    }
}
