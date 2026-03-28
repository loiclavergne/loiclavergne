//
//  SiteBuilderTests.swift
//  Loic Engineer Portfolio
//
//  Created by Loïc Lavergne on 27/03/2026
//  Copyright © 2026 Loïc Lavergne. All rights reserved.
//

import Foundation
import XCTest
@testable import SiteBuilder

final class SiteBuilderTests: XCTestCase {
    func testPayloadHasRoutesForEveryPageAndLocale() throws {
        let payload = try SitePayload.load()

        XCTAssertEqual(Set(payload.locales.keys), Set(["en", "fr"]))

        for pageKey in payload.pageKeys {
            let localizedRoutes = try XCTUnwrap(payload.routes[pageKey], "Missing route map for \(pageKey)")
            XCTAssertNotNil(localizedRoutes["en"], "Missing English route for \(pageKey)")
            XCTAssertNotNil(localizedRoutes["fr"], "Missing French route for \(pageKey)")
        }
    }

    func testReferencedDetailRoutesResolveToExistingPageKeys() throws {
        let payload = try SitePayload.load()

        for (locale, content) in payload.locales {
            for project in content.projects.featured {
                if let route = project.route {
                    XCTAssertTrue(payload.pageKeys.contains(route), "Unknown featured project route \(route) in \(locale)")
                    XCTAssertNotNil(content.projectDetails[route], "Missing featured project detail \(route) in \(locale)")
                }
            }

            for project in content.projects.archive {
                if let route = project.route {
                    XCTAssertTrue(payload.pageKeys.contains(route), "Unknown archive project route \(route) in \(locale)")
                    XCTAssertNotNil(content.projectDetails[route], "Missing archive project detail \(route) in \(locale)")
                }
            }

            for project in content.projects.hobby {
                if let route = project.route {
                    XCTAssertTrue(payload.pageKeys.contains(route), "Unknown hobby project route \(route) in \(locale)")
                    XCTAssertNotNil(content.projectDetails[route], "Missing hobby project detail \(route) in \(locale)")
                }
            }

            for post in content.writing.posts {
                if let route = post.route {
                    XCTAssertTrue(payload.pageKeys.contains(route), "Unknown writing route \(route) in \(locale)")
                    XCTAssertNotNil(content.writingDetails[route], "Missing writing detail \(route) in \(locale)")
                }
            }

            for book in content.library.books {
                if let route = book.route {
                    XCTAssertTrue(payload.pageKeys.contains(route), "Unknown library route \(route) in \(locale)")
                    XCTAssertNotNil(content.libraryDetails[route], "Missing library detail \(route) in \(locale)")
                }
            }
        }
    }

    func testGeneratorWritesSupportFiles() throws {
        let payload = try SitePayload.load()
        let outputRoot = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: outputRoot) }

        let renderer = SiteRenderer(payload: payload, rootURL: outputRoot)
        let urls = try renderer.buildPages()
        try renderer.buildSitemap(urls: urls.sorted())
        try renderer.buildFeeds()
        try renderer.buildManifests()
        try renderer.buildRobots()

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputRoot.appendingPathComponent("index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputRoot.appendingPathComponent("writing/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputRoot.appendingPathComponent("fr/writing/index.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputRoot.appendingPathComponent("feed.xml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputRoot.appendingPathComponent("fr/feed.xml").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputRoot.appendingPathComponent("site.webmanifest").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputRoot.appendingPathComponent("fr/site.webmanifest").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputRoot.appendingPathComponent("robots.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputRoot.appendingPathComponent("sitemap.xml").path))

        let englishFeed = try String(contentsOf: outputRoot.appendingPathComponent("feed.xml"), encoding: .utf8)
        XCTAssertTrue(englishFeed.contains("<feed xmlns=\"http://www.w3.org/2005/Atom\""))
        XCTAssertTrue(englishFeed.contains("https://loic.engineer/feed.xml"))

        let englishManifestData = try Data(contentsOf: outputRoot.appendingPathComponent("site.webmanifest"))
        let englishManifest = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: englishManifestData) as? [String: Any]
        )
        XCTAssertEqual(englishManifest["name"] as? String, "Loïc Lavergne")
        XCTAssertEqual(englishManifest["start_url"] as? String, "/")
        let englishIcons = try XCTUnwrap(englishManifest["icons"] as? [[String: Any]])
        XCTAssertEqual(englishIcons.first?["src"] as? String, "/assets/img/og/og-default.svg")

        let frenchManifestData = try Data(contentsOf: outputRoot.appendingPathComponent("fr/site.webmanifest"))
        let frenchManifest = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: frenchManifestData) as? [String: Any]
        )
        XCTAssertEqual(frenchManifest["start_url"] as? String, "/fr/")
        XCTAssertEqual(frenchManifest["scope"] as? String, "/fr/")

        let home = try String(contentsOf: outputRoot.appendingPathComponent("index.html"), encoding: .utf8)
        XCTAssertTrue(home.contains("<link rel=\"manifest\" href=\"https://loic.engineer/site.webmanifest\">"))

        let frenchHome = try String(contentsOf: outputRoot.appendingPathComponent("fr/index.html"), encoding: .utf8)
        XCTAssertTrue(frenchHome.contains("<link rel=\"manifest\" href=\"https://loic.engineer/fr/site.webmanifest\">"))

        let robots = try String(contentsOf: outputRoot.appendingPathComponent("robots.txt"), encoding: .utf8)
        XCTAssertTrue(robots.contains("User-agent: *"))
        XCTAssertTrue(robots.contains("Sitemap: https://loic.engineer/sitemap.xml"))
    }

    func testStructuredDataUsesPageSpecificSchemaTypes() throws {
        let payload = try SitePayload.load()
        let renderer = SiteRenderer(payload: payload, rootURL: makeTemporaryDirectory())

        let home = try renderer.renderStructuredData(pageKey: "home", locale: "en")
        XCTAssertTrue(home.contains("\"@type\" : \"ProfilePage\""))

        let writing = try renderer.renderStructuredData(pageKey: "writing", locale: "en")
        XCTAssertTrue(writing.contains("\"@type\" : \"CollectionPage\""))
        XCTAssertTrue(writing.contains("\"@type\" : \"Blog\""))
        XCTAssertTrue(writing.contains("\"@type\" : \"BreadcrumbList\""))

        let project = try renderer.renderStructuredData(pageKey: "project-roole-map", locale: "en")
        XCTAssertTrue(project.contains("\"@type\" : \"CreativeWork\""))
        XCTAssertTrue(project.contains("\"@type\" : \"BreadcrumbList\""))

        let library = try renderer.renderStructuredData(pageKey: "library", locale: "en")
        XCTAssertTrue(library.contains("\"@type\" : \"CollectionPage\""))

        let about = try renderer.renderStructuredData(pageKey: "about", locale: "en")
        XCTAssertTrue(about.contains("\"@type\" : \"AboutPage\""))
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SiteBuilderTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
