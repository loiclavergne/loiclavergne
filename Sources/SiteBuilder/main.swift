//
//  main.swift
//  Loic Engineer Portfolio
//
//  Created by Loïc Lavergne on 25/03/2026
//  Copyright © 2026 Loïc Lavergne. All rights reserved.
//

import Foundation

/// Supported command-line options for the site builder.
struct BuilderConfiguration {
    let validateOnly: Bool

    /// Parse supported flags for build and validation flows.
    static func parse(arguments: [String]) throws -> BuilderConfiguration {
        var validateOnly = false

        for argument in arguments {
            switch argument {
            case "--check", "--validate":
                validateOnly = true
            case "--help", "-h":
                printHelp()
                exit(0)
            default:
                throw SiteBuilderError.unknownArgument(argument)
            }
        }

        return BuilderConfiguration(validateOnly: validateOnly)
    }

    /// Print usage instructions for local validation and site generation.
    static func printHelp() {
        let help = """
        SiteBuilder validates the bundled content and generates the static site.

        Usage:
          swift run SiteBuilder
          swift run SiteBuilder --check

        Options:
          --check, --validate  Validate the payload without writing output files.
          --help, -h           Show this help message.
        """

        print(help)
    }
}

/// Build the generated website from the bundled site data.
do {
    let configuration = try BuilderConfiguration.parse(arguments: Array(CommandLine.arguments.dropFirst()))
    let payload = try SitePayload.load()
    try payload.validate()

    if configuration.validateOnly {
        print("SiteBuilder validation passed.")
        exit(0)
    }

    let outputRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let renderer = SiteRenderer(payload: payload, rootURL: outputRoot)
    let urls = try renderer.buildPages()
    try renderer.buildNotFoundPage()
    try renderer.buildSitemap()
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
