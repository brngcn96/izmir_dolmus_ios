import Foundation

/// Henüz yazılmamış bir "✍️ SEN" parçasına gelindiğinde fırlatılır; mesajı
/// hangi parçanın eksik olduğunu söyler.
///
/// GEÇİCİ: Faz 1'in son yer tutucusu da dolunca bu dosya silinecek.
struct Unwritten: LocalizedError, CustomStringConvertible {
    let piece: String

    init(_ piece: String) {
        self.piece = piece
    }

    var description: String { "\(piece) henüz yazılmadı" }
    var errorDescription: String? { description }
}
