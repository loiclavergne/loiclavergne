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

    /// Load the site payload from the SwiftPM resource bundle.
    static func load() throws -> SitePayload {
        guard let resourceURL = Bundle.module.url(forResource: "site", withExtension: "json") else {
            throw SiteBuilderError.missingResource("site.json")
        }

        let data = try Data(contentsOf: resourceURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SitePayload.self, from: data)
    }
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
    let home: HomePage
    let work: WorkPage
    let projects: ProjectsPage
    let writing: WritingPage
    let library: LibraryPage
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
    let educationNote: String
}

struct FeaturedProject: Decodable {
    let name: String
    let period: String
    let summary: String
    let details: [String]
}

struct SummaryProject: Decodable {
    let name: String
    let period: String?
    let summary: String
    let details: [String]?
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

struct WritingPage: Decodable {
    let pageTitle: String
    let description: String
    let eyebrow: String
    let title: String
    let intro: String
    let statusTitle: String
    let statusCopy: String
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
    let statusTitle: String
    let statusCopy: String
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
    let trophiesTitle: String
    let trophiesCopy: String
    let contactTitle: String
    let contactCopy: String
}

enum SiteBuilderError: Error, LocalizedError {
    case missingResource(String)
    case missingRoute(pageKey: String, locale: String)
    case missingLocale(String)

    var errorDescription: String? {
        switch self {
        case let .missingResource(name):
            return "Missing bundled resource: \(name)"
        case let .missingRoute(pageKey, locale):
            return "Missing route for page '\(pageKey)' and locale '\(locale)'"
        case let .missingLocale(locale):
            return "Missing locale content for '\(locale)'"
        }
    }
}
