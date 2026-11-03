import SwiftUI

/// Lisanslar ve kaynaklar: hava durumu verisinin künyesi (WeatherKit'in şartı) ve
/// uygulamayla dağıtılan yazı tipinin lisansı (SIL Open Font License, yazı tipiyle
/// birlikte telif notunun ve lisans metninin de dağıtılmasını istiyor).
struct LicensesView: View {
    @Environment(\.weatherProvider) private var weatherProvider
    @State private var credit: WeatherCredit?

    var body: some View {
        List {
            Section("Hava durumu verisi") {
                if let credit {
                    WeatherMark(credit: credit, height: 16)
                        .accessibilityLabel(credit.serviceName)
                    Link("Veri kaynakları", destination: credit.legalPageURL)
                } else {
                    Text("Apple Weather")
                }
            }
            Section("Figtree yazı tipi · SIL Open Font License 1.1") {
                Text(Self.fontLicense)
                    .font(.figtree(.footnote))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Lisanslar ve kaynaklar")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            credit = try? await weatherProvider.credit()
        }
    }

    /// Paketteki `Fonts/OFL.txt`; bir kez okunur. Dosya 70 sütunda elle kırılmış:
    /// dar ekranda ikinci kez kırılmasın diye paragraflar tek satıra birleşir, büyük
    /// harfli başlıklar ("PREAMBLE") kendi satırında kalır, yalnızca tirelerden oluşan
    /// ayırıcı satırlar atlanır. Metnin sözcükleri değişmez.
    private static let fontLicense: String = {
        guard let url = Bundle.main.url(forResource: "OFL", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "SIL Open Font License 1.1 · https://openfontlicense.org" }
        return text
            .components(separatedBy: "\n\n")
            .map { paragraph in
                let lines = paragraph
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty && !$0.allSatisfy { $0 == "-" } }
                if let heading = lines.first, lines.count > 1, heading == heading.uppercased(), heading.count < 40 {
                    return heading + "\n" + lines.dropFirst().joined(separator: " ")
                }
                return lines.joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }()
}
