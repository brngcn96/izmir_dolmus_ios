import Foundation

/// Yol tarifi motoru: yürü → dolmuşa bin → (aktar →) in → yürü (Flutter'daki
/// `JourneyPlanner`'ın portu).
///
/// Dolmuş güzergah üzerinde uygun yerde indirip bindirdiği için biniş/iniş
/// noktası, hattın binilebilir çizgisine en yakın noktadır. Aktarma, iki hattın
/// birbirine 500 m'den yakın geçtiği yerlerde mümkün sayılır. Sefer saati verisi
/// yok; süreler mesafeden tahmin.
///
/// Kurulumu (bütün güzergahların yol boyu mesafeleri ve ızgara dizini) ağırdır;
/// bir kez kurulup saklanır. Değer tipidir ve `Sendable`: ana aktör dışında
/// kurulup orada çalıştırılabilir.
public struct JourneyPlanner: Sendable {
    /// Bir hattın tek yöndeki çizgisi ve çizgi başından her noktaya yol boyu mesafe.
    struct Line: Sendable {
        let hatID: String
        let hatName: String
        let geomIndex: Int
        let yon: String
        let points: [Coordinate]
        /// Kümülatif metre; `points` ile aynı uzunlukta.
        let along: [Double]
        let boardable: [Bool]

        func isBoardable(at index: Int) -> Bool {
            index < boardable.count ? boardable[index] : true
        }
    }

    /// Bir noktanın bir çizgiye izdüşümü.
    struct Projection {
        /// Çizgiye uzaklık (m).
        let distance: Double
        /// Çizgi başından yol boyu konum (m).
        let along: Double
        /// Çizgi üzerindeki en yakın nokta.
        let point: Coordinate
    }

    struct GridHit: Sendable {
        let line: Int
        let point: Int
    }

    let lines: [Line]
    /// Hücre → o hücreden geçen çizgi noktaları.
    let grid: [Int: [GridHit]]

    /// ~300-390 m'lik ızgara hücresi (derece).
    static let cell = 0.0035

    static func cellKey(_ c: Coordinate) -> Int {
        Int((c.latitude / cell).rounded(.down)) * 1_000_000 + Int((c.longitude / cell).rounded(.down))
    }

    public init(data: DolmusData) {
        self.init(hats: data.hats, geomsFor: data.geoms(for:))
    }

    init(hats: [DolmusHat], geomsFor: (String) -> [HatGeom]) {
        var lines: [Line] = []
        var grid: [Int: [GridHit]] = [:]
        for hat in hats {
            for (geomIndex, geom) in geomsFor(hat.id).enumerated() where geom.points.count >= 2 {
                var along = [Double](repeating: 0, count: geom.points.count)
                for index in 1..<geom.points.count {
                    along[index] = along[index - 1] + geom.points[index - 1].meters(to: geom.points[index])
                }
                let lineIndex = lines.count
                lines.append(Line(
                    hatID: hat.id,
                    hatName: hat.name,
                    geomIndex: geomIndex,
                    yon: geom.yon,
                    points: geom.points,
                    along: along,
                    boardable: geom.boardable
                ))
                for (pointIndex, point) in geom.points.enumerated() {
                    grid[Self.cellKey(point), default: []].append(GridHit(line: lineIndex, point: pointIndex))
                }
            }
        }
        self.lines = lines
        self.grid = grid
    }

    // MARK: Planlama

    /// Uygulamadaki akış: planla, yürüme bacaklarının uzunluğunu çöz, yeniden
    /// sırala, "önerilen"in açıkça daha kötü olmadığını garanti et.
    ///
    /// - Parameter fees: hat kimliği → güncel ücret aralığı.
    public func planTrip(
        from a: Coordinate,
        to b: Coordinate,
        fees: (String) -> (min: Int?, max: Int?),
        limit: Int = 5
    ) -> [Journey] {
        var journeys = plan(from: a, to: b, fees: fees, limit: limit).map { $0.resolvingWalks() }
        Self.rank(&journeys)
        Self.applyDominance(&journeys)
        return journeys
    }

    /// A'dan B'ye aktarmasız ve tek aktarmalı yol tarifleri, iyiden kötüye;
    /// aynı hat kombinasyonundan tek seçenek, en çok `limit` tane.
    func plan(
        from a: Coordinate,
        to b: Coordinate,
        fees: (String) -> (min: Int?, max: Int?),
        limit: Int = 5
    ) -> [Journey] {
        // A'ya ve B'ye yürünebilir çizgiler; sırası çizgi sırası.
        var access: [Int: Projection] = [:]
        var accessOrder: [Int] = []
        var egress: [Int: Projection] = [:]
        for index in lines.indices {
            let pa = Self.project(a, onto: lines[index])
            if pa.distance <= TripConstants.maxAccessWalk {
                access[index] = pa
                accessOrder.append(index)
            }
            let pb = Self.project(b, onto: lines[index])
            if pb.distance <= TripConstants.maxAccessWalk {
                egress[index] = pb
            }
        }

        var journeys: [Journey] = []

        // Aktarmasız: aynı çizgi hem A'ya hem B'ye yakın ve doğru yönde. Halka ya
        // da geri dönen çizgiler bir noktadan birden çok geçebilir; bütün geçiş
        // çiftlerinden ileri yönlü ve toplam süresi en kısa olan seçilir.
        for lineIndex in accessOrder where egress[lineIndex] != nil {
            let line = lines[lineIndex]
            let aCandidates = Self.projectAll(a, onto: line, maxDistance: TripConstants.maxAccessWalk)
            let bCandidates = Self.projectAll(b, onto: line, maxDistance: TripConstants.maxAccessWalk)
            var best: (a: Projection, b: Projection)?
            var bestCost = Double.infinity
            for pa in aCandidates {
                for pb in bCandidates where pa.along < pb.along {
                    let walkMeters = (pa.distance + pb.distance) * TripConstants.walkDetourFactor
                    let cost = walkMeters / TripConstants.walkMetersPerMinute
                        + (pb.along - pa.along) / TripConstants.rideMetersPerMinute
                    if cost < bestCost {
                        bestCost = cost
                        best = (pa, pb)
                    }
                }
            }
            if let best {
                journeys.append(direct(line, a, b, best.a, best.b, fees: fees))
            }
        }

        // Tek aktarma: L1'in binişten sonraki bir noktası L2'nin binilebilir
        // çizgisine yeterince yakınsa. Her (L1, L2) için en kısa aktarma yürümesi.
        struct Transfer {
            let line1: Int
            let line2: Int
            let leave1: Double
            let board2: Double
            let t1: Coordinate
            let t2: Coordinate
            let distance: Double
        }
        var bestTransfer: [Int: Transfer] = [:]
        var transferOrder: [Int] = []
        for line1Index in accessOrder {
            let line1 = lines[line1Index]
            guard let pa = access[line1Index] else { continue }
            for index in line1.points.indices {
                if line1.along[index] <= pa.along { continue }  // binişten sonra
                if !line1.isBoardable(at: index) { continue }  // otoyolda inilmez
                // Bu noktanın çevresindeki hücrelerden aday çıkış çizgileri (sıralı, tekrarsız).
                let baseKey = Self.cellKey(line1.points[index])
                var candidates: [Int] = []
                var seen: Set<Int> = []
                for dy in -1...1 {
                    for dx in -1...1 {
                        guard let hits = grid[baseKey + dy * 1_000_000 + dx] else { continue }
                        for hit in hits where hit.line != line1Index && egress[hit.line] != nil {
                            if seen.insert(hit.line).inserted {
                                candidates.append(hit.line)
                            }
                        }
                    }
                }
                for line2Index in candidates {
                    let line2 = lines[line2Index]
                    if line1.hatID == line2.hatID { continue }  // aynı hattın başka yönü
                    let t = Self.project(line1.points[index], onto: line2)
                    if t.distance > TripConstants.maxTransferWalk { continue }
                    guard let pb = egress[line2Index], t.along < pb.along else { continue }
                    let key = line1Index * 100_000 + line2Index
                    if let current = bestTransfer[key], t.distance >= current.distance { continue }
                    if bestTransfer[key] == nil { transferOrder.append(key) }
                    bestTransfer[key] = Transfer(
                        line1: line1Index,
                        line2: line2Index,
                        leave1: line1.along[index],
                        board2: t.along,
                        t1: line1.points[index],
                        t2: t.point,
                        distance: t.distance
                    )
                }
            }
        }
        for key in transferOrder {
            guard let transfer = bestTransfer[key],
                  let pa = access[transfer.line1],
                  let pb = egress[transfer.line2]
            else { continue }
            journeys.append(oneTransfer(
                lines[transfer.line1], lines[transfer.line2], a, b, pa, pb,
                leave1: transfer.leave1, board2: transfer.board2, t1: transfer.t1, t2: transfer.t2,
                fees: fees
            ))
        }

        // Yürüme engelini (ör. havalimanı çiti) geçen rotalar elenir.
        journeys.removeAll { journey in
            journey.walks.contains { WalkBarriers.crosses($0.from, $0.to) }
        }

        Self.rank(&journeys)

        // Aynı hat kombinasyonundan biri yeter (varyantlar ayrı seçenek olmaz);
        // sıralama önce yapıldığı için her kombinasyonun en iyisi kalır.
        var result: [Journey] = []
        var keys: Set<String> = []
        for journey in journeys {
            if keys.insert(journey.id).inserted {
                result.append(journey)
            }
            if result.count >= limit { break }
        }
        Self.applyDominance(&result)
        return result
    }

    /// İyiden kötüye: sıralama puanı, eşitse az aktarma, sonra az yürüme.
    static func rank(_ journeys: inout [Journey]) {
        journeys.sort { x, y in
            if x.sortScore != y.sortScore { return x.sortScore < y.sortScore }
            if x.transfers != y.transfers { return x.transfers < y.transfers }
            return x.walkMeters < y.walkMeters
        }
    }

    /// "Önerilen" (ilk) seçenek; süre, yürüme, aktarma ve ücretin hepsinde
    /// eşit-ya-da-daha-kötüyse onu geçen seçenek öne alınır.
    static func applyDominance(_ journeys: inout [Journey]) {
        guard journeys.count >= 2 else { return }
        var best = 0
        for index in 1..<journeys.count {
            if dominates(journeys[index], journeys[best]) {
                best = index
            }
        }
        if best != 0 {
            journeys.insert(journeys.remove(at: best), at: 0)
        }
    }

    static func dominates(_ x: Journey, _ y: Journey) -> Bool {
        let xFee = x.feeMax ?? (1 << 30), yFee = y.feeMax ?? (1 << 30)
        // Yürümede ~30 m tolerans: ölçüm gürültüsü baskınlık sayılmasın.
        let notWorse = x.estimatedMinutes <= y.estimatedMinutes
            && x.walkMeters <= y.walkMeters + 30
            && x.transfers <= y.transfers
            && xFee <= yFee
        let better = x.estimatedMinutes < y.estimatedMinutes
            || x.walkMeters + 30 < y.walkMeters
            || x.transfers < y.transfers
            || xFee < yFee
        return notWorse && better
    }

    // MARK: İzdüşümler

    /// `p`'nin çizgiye izdüşümü, yalnızca binilebilir parçalara (iki ucu da
    /// binilebilir). Binilebilir parça yoksa uzaklık sonsuz.
    static func project(_ p: Coordinate, onto line: Line) -> Projection {
        var best = Projection(distance: .infinity, along: 0, point: line.points[0])
        for index in 0..<(line.points.count - 1) {
            guard line.isBoardable(at: index), line.isBoardable(at: index + 1) else { continue }
            let a = line.points[index], b = line.points[index + 1]
            let projection = PlanarGeometry.project(p, onto: a, b)
            if projection.distance < best.distance {
                best = Projection(
                    distance: projection.distance,
                    along: line.along[index] + projection.t * (line.along[index + 1] - line.along[index]),
                    point: Coordinate(
                        latitude: a.latitude + projection.t * (b.latitude - a.latitude),
                        longitude: a.longitude + projection.t * (b.longitude - a.longitude)
                    )
                )
            }
        }
        return best.distance == .infinity ? Projection(distance: .infinity, along: 0, point: line.points[0]) : best
    }

    /// `p`'nin çizgiye bütün geçişleri: eşiğin altına inen her ayrı bölge için o
    /// bölgedeki en yakın nokta. Halka hatlarda doğru yönlü çifti bulmak için.
    static func projectAll(_ p: Coordinate, onto line: Line, maxDistance: Double) -> [Projection] {
        var result: [Projection] = []
        var inRegion = false
        var regionBest = Projection(distance: .infinity, along: 0, point: line.points[0])
        func flush() {
            if inRegion {
                result.append(regionBest)
                inRegion = false
                regionBest = Projection(distance: .infinity, along: regionBest.along, point: regionBest.point)
            }
        }
        for index in 0..<(line.points.count - 1) {
            guard line.isBoardable(at: index), line.isBoardable(at: index + 1) else {
                flush()
                continue
            }
            let a = line.points[index], b = line.points[index + 1]
            let projection = PlanarGeometry.project(p, onto: a, b)
            if projection.distance <= maxDistance {
                inRegion = true
                if projection.distance < regionBest.distance {
                    regionBest = Projection(
                        distance: projection.distance,
                        along: line.along[index] + projection.t * (line.along[index + 1] - line.along[index]),
                        point: Coordinate(
                            latitude: a.latitude + projection.t * (b.latitude - a.latitude),
                            longitude: a.longitude + projection.t * (b.longitude - a.longitude)
                        )
                    )
                }
            } else {
                flush()
            }
        }
        flush()
        return result
    }

    /// Çizginin iki yol boyu konumu arasındaki noktaları (biniş ve iniş dahil).
    static func slice(_ line: Line, from fromAlong: Double, to toAlong: Double, board: Coordinate, alight: Coordinate) -> [Coordinate] {
        var result = [board]
        for index in line.points.indices where line.along[index] > fromAlong && line.along[index] < toAlong {
            result.append(line.points[index])
        }
        result.append(alight)
        return result
    }

    // MARK: Seçenekler

    private func ride(
        _ line: Line, board: Coordinate, alight: Coordinate, from fromAlong: Double, to toAlong: Double,
        fees: (String) -> (min: Int?, max: Int?)
    ) -> RideLeg {
        let fee = fees(line.hatID)
        return RideLeg(
            hatID: line.hatID,
            hatName: line.hatName,
            geomIndex: line.geomIndex,
            yon: line.yon,
            board: board,
            alight: alight,
            ridePoints: Self.slice(line, from: fromAlong, to: toAlong, board: board, alight: alight),
            meters: abs(toAlong - fromAlong),
            feeMin: fee.min,
            feeMax: fee.max
        )
    }

    private func direct(
        _ line: Line, _ a: Coordinate, _ b: Coordinate, _ pa: Projection, _ pb: Projection,
        fees: (String) -> (min: Int?, max: Int?)
    ) -> Journey {
        Journey(legs: [
            .walk(WalkLeg(from: a, to: pa.point, straightMeters: pa.distance, toLabel: line.hatName)),
            .ride(ride(line, board: pa.point, alight: pb.point, from: pa.along, to: pb.along, fees: fees)),
            .walk(WalkLeg(from: pb.point, to: b, straightMeters: pb.distance, toLabel: "Varış")),
        ])
    }

    private func oneTransfer(
        _ line1: Line, _ line2: Line, _ a: Coordinate, _ b: Coordinate, _ pa: Projection, _ pb: Projection,
        leave1: Double, board2: Double, t1: Coordinate, t2: Coordinate,
        fees: (String) -> (min: Int?, max: Int?)
    ) -> Journey {
        Journey(legs: [
            .walk(WalkLeg(from: a, to: pa.point, straightMeters: pa.distance, toLabel: line1.hatName)),
            .ride(ride(line1, board: pa.point, alight: t1, from: pa.along, to: leave1, fees: fees)),
            .walk(WalkLeg(from: t1, to: t2, straightMeters: t1.meters(to: t2), toLabel: line2.hatName)),
            .ride(ride(line2, board: t2, alight: pb.point, from: board2, to: pb.along, fees: fees)),
            .walk(WalkLeg(from: pb.point, to: b, straightMeters: pb.distance, toLabel: "Varış")),
        ])
    }
}

extension JourneyPlanner {
    /// Kurulum ağır (bütün güzergahların yol boyu mesafeleri): ana aktör dışında.
    @concurrent
    public static func build(from data: DolmusData) async -> JourneyPlanner {
        JourneyPlanner(data: data)
    }

    /// Planlama ana aktör dışında; ücretler `data`'daki güncel değerlerden.
    @concurrent
    public func planTrip(from a: Coordinate, to b: Coordinate, data: DolmusData, limit: Int = 5) async -> [Journey] {
        planTrip(from: a, to: b, fees: { id in
            let hat = data.hat(id: id)
            return (hat?.feeMin, hat?.feeMax)
        }, limit: limit)
    }
}
