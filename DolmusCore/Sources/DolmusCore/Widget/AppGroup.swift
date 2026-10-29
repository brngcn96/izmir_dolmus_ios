//
//  AppGroup.swift
//  DolmusCore
//
//  Created by Baran Göcen on 29.10.2026.
//

import Foundation

/// Uygulamayla widget eklentisinin ortak klasörü ve ayarları (App Group).
/// İki hedefin "App Groups" yeteneğinde aynı kimlik işaretli olmalı.
public enum AppGroup {
    public static let identifier = "group.com.izmirdolmus.app"

    /// Ortak klasör; yetenek eksikse (ör. `swift test`'te) `nil`.
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Ortak ayarlar (ör. widget'ta elle seçilen yön).
    public static var defaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    /// Widget'ta ⇄ ile elle seçilen yön; seçim yoksa `nil`.
    public static var commuteOverride: CommuteOverride? {
        get {
            guard let data = defaults?.data(forKey: Keys.commuteOverride) else { return nil }
            return try? JSONDecoder().decode(CommuteOverride.self, from: data)
        }
        set {
            defaults?.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Keys.commuteOverride)
        }
    }

    private enum Keys {
        static let commuteOverride = "commute_override_v1"
    }

    /// Widget özetini okur; dosya yoksa ya da sürümü farklıysa `nil`.
    public static func readSnapshot() -> WidgetSnapshot? {
        guard let url = containerURL?.appending(path: WidgetSnapshot.fileName),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data),
              snapshot.version == WidgetSnapshot.currentVersion
        else { return nil }
        return snapshot
    }

    /// Özeti yazar. `.atomic`: önce geçici dosyaya yazılıp yerine konur; widget
    /// yarım yazılmış bir dosya okumaz.
    public static func write(_ snapshot: WidgetSnapshot) throws {
        guard let url = containerURL?.appending(path: WidgetSnapshot.fileName) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }
}
