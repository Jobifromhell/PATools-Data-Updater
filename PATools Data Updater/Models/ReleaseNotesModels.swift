import Foundation

struct ReleaseNoteEntry: Identifiable, Equatable {
    let id = UUID()
    let datasetId: String
    let version: String
    let date: Date
    let notes: String
}

enum DatasetKind: String, CaseIterable, Identifiable {
    case ampLoad = "ampload"
    case prealignment = "prealignment"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ampLoad:
            return "Amp Load"
        case .prealignment:
            return "Pre-alignment"
        }
    }
}
