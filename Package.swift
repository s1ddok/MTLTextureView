// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "MTLTextureView",
    platforms: [.iOS(.v11)],
    products: [
        .library(name: "MTLTextureView",
                 targets: ["MTLTextureView"]),
    ], dependencies: [
        .package(name: "Alloy",
                 url: "https://github.com/s1ddok/Alloy",
                 .upToNextMinor(from: "0.16.4"))
    ],
    targets: [
        .target(name: "MTLTextureView",
                dependencies: ["Alloy"],
                resources: [.process("MTLTextureViewShaderLibrary.metal")],
                swiftSettings: [.define("SWIFT_PM")])
    ]
)
