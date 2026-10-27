import Foundation

extension Coordinate {
    /// İki nokta arasındaki elipsoit (WGS-84) uzaklığı, Vincenty formülüyle,
    /// tam metreye yuvarlanmış. Flutter'daki `latlong2` `Distance().as(Meter, …)`
    /// ile aynı hesap: kategori listeleri bu uzaklığa göre sıralanır.
    public func meters(to other: Coordinate) -> Double {
        let distance = Self.vincenty(self, other)
        guard distance.isFinite else { return 0 }
        return distance.rounded()
    }

    private static let equatorRadius = 6_378_137.0
    private static let polarRadius = 6_356_752.314245
    private static let flattening = 1 / 298.257223563

    private static func vincenty(_ p1: Coordinate, _ p2: Coordinate) -> Double {
        let a = equatorRadius, b = polarRadius, f = flattening
        let l = radians(p2.longitude) - radians(p1.longitude)
        let u1 = atan((1 - f) * tan(radians(p1.latitude)))
        let u2 = atan((1 - f) * tan(radians(p2.latitude)))
        let sinU1 = sin(u1), cosU1 = cos(u1)
        let sinU2 = sin(u2), cosU2 = cos(u2)

        var lambda = l
        var lambdaP: Double
        var sinSigma = 0.0, cosSigma = 0.0, sigma = 0.0, cosSqAlpha = 0.0, cos2SigmaM = 0.0
        var iterations = 200
        repeat {
            let sinLambda = sin(lambda), cosLambda = cos(lambda)
            let x = cosU2 * sinLambda
            let y = cosU1 * sinU2 - sinU1 * cosU2 * cosLambda
            sinSigma = (x * x + y * y).squareRoot()
            if sinSigma == 0 { return 0 }  // aynı nokta
            cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda
            sigma = atan2(sinSigma, cosSigma)
            let sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma
            cosSqAlpha = 1 - sinAlpha * sinAlpha
            cos2SigmaM = cosSigma - 2 * sinU1 * sinU2 / cosSqAlpha
            if cos2SigmaM.isNaN { cos2SigmaM = 0 }  // ekvator üzerinde
            let c = f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha))
            lambdaP = lambda
            lambda = l + (1 - c) * f * sinAlpha
                * (sigma + c * sinSigma * (cos2SigmaM + c * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)))
            iterations -= 1
        } while abs(lambda - lambdaP) > 1e-12 && iterations > 0
        if iterations == 0 { return .nan }

        let uSq = cosSqAlpha * (a * a - b * b) / (b * b)
        let bigA = 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)))
        let bigB = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)))
        let deltaSigma = bigB * sinSigma * (cos2SigmaM + bigB / 4
            * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)
                - bigB / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3 + 4 * cos2SigmaM * cos2SigmaM)))
        return b * bigA * (sigma - deltaSigma)
    }

    private static func radians(_ degrees: Double) -> Double {
        degrees * (Double.pi / 180)
    }
}
