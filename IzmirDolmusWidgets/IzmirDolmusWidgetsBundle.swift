//
//  IzmirDolmusWidgetsBundle.swift
//  IzmirDolmusWidgets
//
//  Created by Baran Göcen on 29.10.2026.
//

import WidgetKit
import SwiftUI

@main
struct IzmirDolmusWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CommuteWidget()
        FavoriteHatWidget()
        TripPlannerControl()
        GoHomeControl()
        // Şablonun Live Activity'si; Faz Y'de Yolculuk modu bunun yerine gelecek.
        IzmirDolmusWidgetsLiveActivity()
    }
}
