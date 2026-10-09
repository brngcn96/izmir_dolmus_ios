// swift-tools-version: 6.2

import PackageDescription

// Uygulama hedefindeki "Approachable Concurrency" ayarıyla aynı anlam: `async`
// fonksiyon çağıranın aktöründe kalır; ana aktör dışına çıkmak için açıkça
// `@concurrent` yazılır. Böylece paket ve uygulama tek bir zihin modeliyle okunur.
// (Uygulamadan farkı: burada varsayılan izolasyon MainActor DEĞİL — domain kodu
// hiçbir aktöre bağlı değildir.)
let settings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "DolmusCore",
    platforms: [
        .iOS(.v26),
        // Testler simülatör beklemeden, Mac'te `swift test` ile koşsun diye.
        .macOS(.v26),
    ],
    products: [
        .library(name: "DolmusCore", targets: ["DolmusCore"]),
    ],
    targets: [
        .target(
            name: "DolmusCore",
            // Veri dosyaları: `Scripts/sync-data.sh` ile Flutter repo'sundan gelir.
            resources: [.process("Resources")],
            swiftSettings: settings
        ),
        .testTarget(
            name: "DolmusCoreTests",
            dependencies: ["DolmusCore"],
            // Flutter kodundan üretilmiş beklenen çıktılar: `Scripts/export-golden.sh`.
            resources: [.copy("Golden")],
            swiftSettings: settings
        ),
    ]
)
