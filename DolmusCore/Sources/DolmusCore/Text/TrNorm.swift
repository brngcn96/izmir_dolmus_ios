public func trNorm(_ input: String) -> String {
    var folded = String.UnicodeScalarView()
    for scalar in input.unicodeScalars {
        folded.append(fold(scalar))
    }
    return String(folded)
        .lowercased()
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
}

private func fold(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
    switch scalar {
    case "ç", "Ç": "c"
    case "ğ", "Ğ": "g"
    case "ı", "I", "İ", "î": "i"
    case "ö", "Ö": "o"
    case "ş", "Ş": "s"
    case "ü", "Ü", "û": "u"
    case "â": "a"
    default: scalar
    }
}
