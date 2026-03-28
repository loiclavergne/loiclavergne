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
        }
    }
}
