//
//  JourneyActivityAttributes.swift
//  IzmirDolmus
//
//  Created by Baran Göcen on 29.10.2026.
//

import ActivityKit
import Foundation

/// Yolculuk modunun Live Activity'si. Uygulama başlatır ve günceller, widget
/// eklentisi kilit ekranında ve Dynamic Island'da çizer. İki taraf da aynı türü
/// tanımalı; bu yüzden iki hedefte birden derlenen `Shared/` klasöründe.
///
/// `nonisolated`: uygulama hedefinde varsayılan izolasyon `MainActor`; bu tür
/// ise ActivityKit tarafından her yerden kodlanıp çözülür.
nonisolated struct JourneyActivityAttributes: ActivityAttributes {
    /// Değişen kısım: her güncellemede yeniden gönderilir (en çok 4 KB).
    struct ContentState: Codable, Hashable {
        /// `steps` içindeki şu anki adım.
        var stepIndex: Int
        /// Şu anki adımın hedefine (durak, iniş ya da varış) kalan mesafe (m);
        /// bilinmiyorsa `nil`.
        var metersRemaining: Int?
        /// İnişe yaklaşıldı: "hazırlan" uyarısı.
        var isApproaching = false
        var hasArrived = false
    }

    /// Bir adım: yürüme ya da dolmuş. Etkinlik boyunca değişmez.
    struct Step: Codable, Hashable {
        enum Kind: String, Codable {
            case walk
            case ride
        }

        var kind: Kind
        /// Dolmuşta hattın adı; yürümede nereye: binilecek hat ya da varış yeri.
        var title: String
        var meters: Int
    }

    // Sabit kısım: etkinlik başlarken bir kez gönderilir.
    var fromLabel: String
    var toLabel: String
    var totalMinutes: Int
    var steps: [Step]
}
