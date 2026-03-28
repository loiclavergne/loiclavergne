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
    try renderer.buildNotFoundPage()
    try renderer.buildSitemap(urls: urls.sorted())
    try renderer.buildFeeds()
    try renderer.buildManifests()
    try renderer.buildRobots()
    try renderer.buildHostingFiles()
    print("Generated \(urls.count) pages, 404.html, feeds, manifests, sitemap.xml, robots.txt, and hosting files")
} catch {
    let nsError = error as NSError
    fputs("SiteBuilder failed: \(error.localizedDescription)\n", stderr)
    fputs("Debug: \(String(reflecting: error))\n", stderr)
    fputs("NSError domain=\(nsError.domain) code=\(nsError.code)\n", stderr)
    exit(1)
}
