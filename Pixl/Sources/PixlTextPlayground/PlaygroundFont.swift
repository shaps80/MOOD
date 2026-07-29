import Foundation

enum PlaygroundFont: String, CaseIterable, Identifiable {
    case zapfino
    case senilita

    var id: Self { self }

    var name: String {
        switch self {
        case .zapfino: "Zapfino"
        case .senilita: "Senilita"
        }
    }

    var path: String {
        switch self {
        case .zapfino:
            "/System/Library/Fonts/Supplemental/Zapfino.ttf"
        case .senilita:
            "/Users/shaps/Library/Fonts/Senilita.otf"
        }
    }

    func loadBytes() throws -> [UInt8] {
        Array(try Data(contentsOf: URL(filePath: path)))
    }
}
