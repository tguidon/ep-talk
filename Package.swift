// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EPTalk",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "EPTalk", targets: ["EPTalk"])],
    targets: [
        .target(name: "EPTalkCore"),
        .executableTarget(name: "EPTalk", dependencies: ["EPTalkCore"], resources: [.copy("Resources/Mic")]),
        .testTarget(name: "EPTalkCoreTests", dependencies: ["EPTalkCore"])
    ]
)
