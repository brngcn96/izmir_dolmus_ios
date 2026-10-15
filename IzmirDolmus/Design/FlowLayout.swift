import SwiftUI

/// Alt view'ları soldan sağa dizer; satır dolunca alt satıra geçer (chip'ler için).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = makeRows(subviews, maxWidth: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in makeRows(subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    /// Bir satırdaki öğeler ve satırın ölçüleri.
    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// Alt view'ları sırayla satırlara yerleştirir. Her biri en çok satır
    /// genişliğinde ölçülür; daha uzun bir metin chip'in içinde alt satıra kayar.
    private func makeRows(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            let widthWithItem = row.items.isEmpty ? size.width : row.width + spacing + size.width
            if widthWithItem > maxWidth && !row.items.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.items.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.items.append((index, size))
        }
        if !row.items.isEmpty {
            rows.append(row)
        }
        return rows
    }
}
