import DolmusCore
import WidgetKit

/// Widget özetini güncel tutar: girdiler (Ev, İş, favoriler, ücretler) değişince
/// özeti yeniden kurar, App Group'a yazar ve WidgetKit'e widget'ları
/// tazelemesini söyler.
final class WidgetSync {
    /// Widget'ların bağlı olduğu girdiler; biri değişince özet yeniden kurulur.
    struct Inputs: Equatable {
        var home: PlacePoint?
        var work: PlacePoint?
        var favoriteHatIDs: [String]
        var fares: FareTable
    }

    /// Planlayıcı bir kez kurulur; aynı anda gelen istekler aynı kurulumu bekler.
    private var plannerTask: Task<JourneyPlanner, Never>?

    func update(data: DolmusData, inputs: Inputs) async {
        let planner = await planner(data: data)
        let snapshot = await Self.makeSnapshot(
            data: data, planner: planner,
            home: inputs.home, work: inputs.work, favoriteHatIDs: inputs.favoriteHatIDs
        )
        // Bu arada girdiler yine değiştiyse yeni görev yazacak; bu sonuç bayat.
        guard !Task.isCancelled else { return }
        do {
            try AppGroup.write(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // App Groups yeteneği yoksa ortak klasör yok; widget'lar boş kalır.
            print("Widget özeti yazılamadı: \(error)")
        }
    }

    private func planner(data: DolmusData) async -> JourneyPlanner {
        if let plannerTask {
            return await plannerTask.value
        }
        let task = Task { await JourneyPlanner.build(from: data) }
        plannerTask = task
        return await task.value
    }

    /// İki planlama yüzlerce ms sürebilir: ana aktörün dışında.
    @concurrent
    private static func makeSnapshot(
        data: DolmusData,
        planner: JourneyPlanner,
        home: PlacePoint?,
        work: PlacePoint?,
        favoriteHatIDs: [String]
    ) async -> WidgetSnapshot {
        WidgetSnapshot.make(data: data, planner: planner, home: home, work: work, favoriteHatIDs: favoriteHatIDs)
    }
}
