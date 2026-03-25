// swift-tools-version: 6.0
//
//  Package.swift
//  Loic Engineer Portfolio
//
//  Created by Loïc Lavergne on 25/03/2026
//  Copyright © 2026 Loïc Lavergne. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "SiteBuilder",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SiteBuilder", targets: ["SiteBuilder"]),
        .executable(name: "SiteServer", targets: ["SiteServer"])
    ],
    targets: [
        .executableTarget(
            name: "SiteBuilder",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "SiteServer"
        )
    ]
)
