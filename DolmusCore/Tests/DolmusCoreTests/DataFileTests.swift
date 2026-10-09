import Foundation
import Testing
@testable import DolmusCore

@Suite("Paketle gelen veri dosyaları")
struct DataFileTests {
    /// `DataFile` ile `Resources/` birbirinden koparsa (eşitleme betiği bir
    /// dosyayı getirmezse ya da ad değişirse) uygulama açılışta veri bulamaz;
    /// bunu derleyici göremez, ancak burada yakalarız.
    @Test("Her veri dosyası paket kaynaklarında var ve boş değil", arguments: DataFile.allCases)
    func isBundled(_ file: DataFile) throws {
        let url = try #require(file.bundledURL)
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size > 0)
    }
}
