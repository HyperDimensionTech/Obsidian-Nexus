import Foundation

final class CodeTypeDetectorImpl: CodeTypeDetector {
    func detect(from raw: String) -> CodeType {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")

        // Simple heuristics
        switch code.count {
        case 10:
            return isValidISBN10(code) ? .isbn10 : .unknown
        case 13:
            if code.hasPrefix("978") || code.hasPrefix("979") {
                return isValidEAN13(code) ? .isbn13 : .ean13
            }
            return isValidEAN13(code) ? .ean13 : .unknown
        case 12:
            return isNumeric(code) ? .upcA : .unknown
        default:
            return .unknown
        }
    }

    private func isNumeric(_ s: String) -> Bool { s.allSatisfy { $0.isNumber } }

    private func isValidISBN10(_ s: String) -> Bool {
        guard s.dropLast().allSatisfy({ $0.isNumber }) else { return false }
        let chars = Array(s)
        var sum = 0
        for i in 0..<9 {
            guard let d = Int(String(chars[i])) else { return false }
            sum += (10 - i) * d
        }
        let checkChar = chars[9]
        let checkVal = (checkChar == "X" || checkChar == "x") ? 10 : Int(String(checkChar)) ?? -1
        guard checkVal >= 0 else { return false }
        sum += checkVal
        return sum % 11 == 0
    }

    private func isValidEAN13(_ s: String) -> Bool {
        guard isNumeric(s), s.count == 13 else { return false }
        let digits = s.compactMap { Int(String($0)) }
        guard digits.count == 13 else { return false }
        let checksum = (0..<12).reduce(0) { acc, i in
            acc + digits[i] * (i % 2 == 0 ? 1 : 3)
        }
        let check = (10 - (checksum % 10)) % 10
        return check == digits[12]
    }
}


