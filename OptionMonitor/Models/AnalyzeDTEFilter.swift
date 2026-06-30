import Foundation

enum AnalyzeDTEFilter: String, CaseIterable {
    case days5
    case days30
    case days90
    case days180
    case all

    var days: Int? {
        switch self {
        case .days5: return 5
        case .days30: return 30
        case .days90: return 90
        case .days180: return 180
        case .all: return nil
        }
    }

    var label: String {
        switch self {
        case .days5: return "5"
        case .days30: return "30"
        case .days90: return "90"
        case .days180: return "180"
        case .all: return "All"
        }
    }
}
