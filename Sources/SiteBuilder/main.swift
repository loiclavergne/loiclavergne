//
//  main.swift
//  Loic Engineer Portfolio
//
//  Created by Loïc Lavergne on 25/03/2026
//  Copyright © 2026 Loïc Lavergne. All rights reserved.
//

import Foundation

/// Build the generated website from the bundled site data.
do {
    let payload = try SitePayload.load()
    let outputRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let renderer = SiteRenderer(payload: payload, rootURL: outputRoot)
    let urls = try renderer.buildPages()
    try renderer.buildSitemap(urls: urls.sorted())
    try renderer.buildFeeds()
    try renderer.buildRobots()
    print("Generated \(urls.count) pages, feeds, sitemap.xml, and robots.txt")
} catch {
    let nsError = error as NSError
    fputs("SiteBuilder failed: \(error.localizedDescription)\n", stderr)
    fputs("Debug: \(String(reflecting: error))\n", stderr)
    fputs("NSError domain=\(nsError.domain) code=\(nsError.code)\n", stderr)
    exit(1)
}
