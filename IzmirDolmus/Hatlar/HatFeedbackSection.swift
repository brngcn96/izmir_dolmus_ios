import Accessibility
import DolmusCore
import SwiftUI

/// Hat detayının sonundaki geri bildirim: iki evet/hayır sorusu, not ve gönderme.
/// Oylar ve not cihazda saklanır; gönderilince geliştiricinin formuna gider.
struct HatFeedbackSection: View {
    let hat: DolmusHat

    @Environment(FeedbackStore.self) private var store
    @FocusState private var isEditingNote: Bool

    var body: some View {
        let feedback = store.feedback(for: hat.id)
        let state = store.sendState(for: hat.id)
        let canSend = !feedback.isEmpty && state != .sending
        Section {
            VoteRow(title: "Güzergah doğru mu?", systemImage: "point.topleft.down.to.point.bottomright.curvepath", vote: feedback.routeIsCorrect) {
                store.vote($0, on: .route, for: hat.id)
            }
            VoteRow(title: "Ücretler güncel mi?", systemImage: "turkishlirasign.circle", vote: feedback.feesAreCurrent) {
                store.vote($0, on: .fees, for: hat.id)
            }
            TextField(
                "Not",
                text: Binding(get: { feedback.note }, set: { store.setNote($0, for: hat.id) }),
                prompt: Text("Not ekle (isteğe bağlı): son durak taşındı, sık sefer var…"),
                axis: .vertical
            )
            .lineLimit(3...6)
            .focused($isEditingNote)
            // Not alanında: `Section`'a eklenince bölümün her satırına uygulanıyor,
            // klavyenin üstünde dört "Bitti" çıkıyordu.
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") { isEditingNote = false }
                }
            }
            Button {
                isEditingNote = false
                // Gönderim ekrandan bağımsız sürsün diye `.task` değil `Task`:
                // kullanıcı geri dönse de tamamlanır.
                Task { await store.send(for: hat) }
            } label: {
                HStack {
                    Label("Geri bildirimi gönder", systemImage: "paperplane")
                    if state == .sending {
                        Spacer()
                        ProgressView()
                    }
                }
                // List'te devre dışı button siyah çiziliyor; gri olsun ki
                // dokunulabilir sanılmasın.
                .foregroundStyle(canSend ? Color.accent : Color.textSecondary)
            }
            .disabled(!canSend)
        } header: {
            Text("Geri bildirim")
        } footer: {
            footer(for: state)
        }
        // Sonuç listenin altında kalabilir: VoiceOver kullanıcısına okunur.
        .onChange(of: state) { _, state in
            switch state {
            case .sent:
                AccessibilityNotification.Announcement("Geri bildirimin gönderildi. Teşekkürler!").post()
            case .failed(let message):
                AccessibilityNotification.Announcement("Gönderilemedi: \(message)").post()
            case .idle, .sending:
                break
            }
        }
    }

    @ViewBuilder
    private func footer(for state: FeedbackStore.SendState) -> some View {
        switch state {
        case .sent:
            Label("Geri bildirimin gönderildi. Teşekkürler!", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Text("Gönderilemedi: \(message) Notun telefonda kayıtlı.")
                .foregroundStyle(.red)
        case .idle, .sending:
            Text("Güzergah ya da ücrette bir hata varsa bildir; geliştiriciye ulaşır ve verinin düzeltilmesine yardım eder.")
        }
    }
}

/// Bir evet/hayır sorusu. Seçili cevaba yeniden basmak oyu geri alır.
private struct VoteRow: View {
    let title: String
    let systemImage: String
    let vote: Bool?
    let onVote: (Bool) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                voteButton(true, answer: "Evet", systemImage: "hand.thumbsup")
                voteButton(false, answer: "Hayır", systemImage: "hand.thumbsdown")
            }
        }
    }

    private func voteButton(_ value: Bool, answer: String, systemImage: String) -> some View {
        let isSelected = vote == value
        return Button {
            onVote(value)
        } label: {
            Image(systemName: isSelected ? "\(systemImage).fill" : systemImage)
                .font(.title3)
                .frame(minWidth: 44, minHeight: 36)
                .foregroundStyle(isSelected ? Color.white : Color.accent)
                .background(isSelected ? Color.accent : Color.brandSoft, in: .capsule)
        }
        // List satırında button'lar ayrı ayrı dokunulsun diye; yoksa bütün
        // satır tek bir button gibi davranır.
        .buttonStyle(.borderless)
        // İki soruda da "Evet" var: hangisine ait olduğu da okunur.
        .accessibilityLabel("\(title) \(answer)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
