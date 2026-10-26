import AppKit

final class ThemeStore {
    static let shared = ThemeStore()
    private(set) var configuration: ThemeConfiguration
    var onChange: (() -> Void)?
    private let key = "TrimWasp.DeveloperTheme.v2"
    private init() {
        configuration = .defaults
        if let data = UserDefaults.standard.data(forKey: key), let saved = try? JSONDecoder().decode(ThemeConfiguration.self, from: data), saved.schemaVersion == 1 {
            for role in ThemeRole.allCases { if let hex = saved.colors[role.rawValue], ThemeRGBA(hex: hex) != nil { configuration.colors[role.rawValue] = hex } }
        }
    }
    func color(_ role: ThemeRole) -> NSColor {
        let c = ThemeRGBA(hex: configuration.colors[role.rawValue] ?? role.defaultHex) ?? ThemeRGBA(hex: role.defaultHex)!
        return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
    }
    func set(_ role: ThemeRole, color: NSColor) {
        guard let c = color.usingColorSpace(.sRGB) else { return }
        configuration.colors[role.rawValue] = ThemeRGBA(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent, alpha: c.alphaComponent).hex
        persist(); onChange?()
    }
    func reset() { configuration = .defaults; persist(); onChange?() }
    private func persist() { if let data = try? encoded() { UserDefaults.standard.set(data, forKey: key) } }
    func encoded() throws -> Data { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return try encoder.encode(configuration) }
}
func themeColor(_ role: ThemeRole) -> NSColor { ThemeStore.shared.color(role) }

