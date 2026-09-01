import Swift

enum BenchmarkFormatting {
    static func decimal(_ value: Double, places: Int) -> String {
        precondition(places >= 0)
        var factor: Int64 = 1
        for _ in 0..<places {
            factor *= 10
        }
        let magnitude = Int64((value.magnitude * Double(factor)).rounded())
        let whole = magnitude / factor
        guard places > 0 else {
            return value < 0 ? "-\(whole)" : "\(whole)"
        }
        let remainder = String(magnitude % factor)
        let padding = String(repeating: "0", count: places - remainder.count)
        let sign = value < 0 ? "-" : ""
        return "\(sign)\(whole).\(padding)\(remainder)"
    }
}
