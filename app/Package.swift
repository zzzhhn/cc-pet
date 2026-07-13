// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClawPet",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ClawPetCore"),
        .executableTarget(name: "ClawPet", dependencies: ["ClawPetCore"]),
        // No Xcode installed -> XCTest unavailable. Tests run as a plain
        // executable under CommandLineTools: `swift run ClawPetTests`.
        .executableTarget(name: "ClawPetTests", dependencies: ["ClawPetCore"]),
    ]
)
