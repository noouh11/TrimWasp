import Foundation

struct ThemeRGBA: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8, value.allSatisfy({ $0.isHexDigit }), let n = UInt64(value, radix: 16) else { return nil }
        let rgb = value.count == 8 ? n >> 8 : n
        red = Double((rgb >> 16) & 255) / 255; green = Double((rgb >> 8) & 255) / 255; blue = Double(rgb & 255) / 255
        alpha = value.count == 8 ? Double(n & 255) / 255 : 1
    }
    init(red: Double, green: Double, blue: Double, alpha: Double = 1) { self.red = red; self.green = green; self.blue = blue; self.alpha = alpha }
    var hex: String {
        func byte(_ x: Double) -> Int { Int((min(1, max(0, x)) * 255).rounded()) }
        let rgb = String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
        return byte(alpha) == 255 ? rgb : rgb + String(format: "%02X", byte(alpha))
    }
}
enum ThemeRole: String, CaseIterable {
    case window, panel, primaryText, secondaryText, accentText, button, inputBackground, inputText
    case card, cardBorder, cardSelection, cardSelectionBorder
    case timelineBackground, timelineTrack, range, marker, queuedRange, playhead, ruler
    case queueSelection, progress, progressTrack, videoBackground
    var title: String {
        switch self {
        case .window: return "Window background"
        case .panel: return "Panel backgrounds"
        case .primaryText: return "Primary text / file details"
        case .secondaryText: return "Secondary text / timeline labels"
        case .accentText: return "Headings / Pending Clips text"
        case .button: return "Button text / icons"
        case .inputBackground: return "Input backgrounds"
        case .inputText: return "Input text"
        case .card: return "Gallery card background"
        case .cardBorder: return "Gallery card border"
        case .cardSelection: return "Selected gallery card background"
        case .cardSelectionBorder: return "Selected gallery card border"
        case .timelineBackground: return "Timeline background"
        case .timelineTrack: return "Timeline empty track"
        case .range: return "Selected clip range fill"
        case .marker: return "Clip marker handles"
        case .queuedRange: return "Queued clip bars"
        case .playhead: return "Playhead line"
        case .ruler: return "Timeline ruler ticks"
        case .queueSelection: return "Selected queue row"
        case .progress: return "Export progress fill"
        case .progressTrack: return "Export progress track"
        case .videoBackground: return "Video preview background"
        }
    }
    var defaultHex: String {
        switch self {
        case .window: return "#131416"
        case .panel, .timelineBackground: return "#252627"
        case .primaryText, .inputText: return "#EEEEEE"
        case .secondaryText: return "#999999"
        case .accentText: return "#E9E2DD"
        case .button, .marker, .progress, .cardSelectionBorder: return "#BB0EF0"
        case .inputBackground: return "#353535"
        case .card: return "#FFFFFF0B"
        case .cardBorder: return "#FFFFFF12"
        case .cardSelection: return "#BB0EF026"
        case .timelineTrack: return "#FFFFFF09"
        case .range: return "#BB0EF02B"
        case .queuedRange: return "#BB0EF08C"
        case .playhead: return "#FFFFFF"
        case .ruler: return "#FFFFFF2B"
        case .queueSelection: return "#BB0EF059"
        case .progressTrack: return "#FFFFFF14"
        case .videoBackground: return "#000000"
        }
    }
}
struct ThemeConfiguration: Codable {
    var app = "TrimWasp"
    var schemaVersion = 1
    var colors: [String: String]
    static var defaults: ThemeConfiguration { ThemeConfiguration(colors: Dictionary(uniqueKeysWithValues: ThemeRole.allCases.map { ($0.rawValue, $0.defaultHex) })) }
}
