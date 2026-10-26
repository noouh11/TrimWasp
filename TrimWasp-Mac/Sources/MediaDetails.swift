import Foundation

func fileDetails(_ url: URL) -> String {
    let attributes = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
    let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .long
    func date(_ key: FileAttributeKey) -> String {
        guard let value = attributes[key] as? Date else { return "Unavailable" }
        return formatter.string(from: value)
    }
    let size = (attributes[.size] as? NSNumber).map { ByteCountFormatter.string(fromByteCount: $0.int64Value, countStyle: .file) } ?? "Unavailable"
    return [
        "Filename\n\(url.lastPathComponent)",
        "Filetype\n\(url.pathExtension.uppercased())",
        "Size\n\(size)",
        "Path\n\(url.deletingLastPathComponent().path)",
        "Creation date\n\(date(.creationDate))",
        "Last modified date\n\(date(.modificationDate))"
    ].joined(separator: "\n\n")
}
