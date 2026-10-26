import Foundation
struct MediaScan {
    var files: [URL]
    var unreadableEntries: Int
}
func scanMP4Directory(_ folder: URL) throws -> MediaScan {
    let fm = FileManager.default
    let root = try folder.resourceValues(forKeys: [.isDirectoryKey, .isReadableKey])
    guard root.isDirectory == true, root.isReadable != false else {
        throw NSError(domain: "TrimWasp", code: 1, userInfo: [NSLocalizedDescriptionKey: "This folder cannot be read."])
    }
    var unreadable = 0
    guard let enumerator = fm.enumerator(at: folder,
        includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants],
        errorHandler: { _, _ in unreadable += 1; return true }) else {
        throw NSError(domain: "TrimWasp", code: 2, userInfo: [NSLocalizedDescriptionKey: "This folder could not be listed."])
    }
    var files: [URL] = []
    for case let url as URL in enumerator {
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            if values.isRegularFile == true, url.pathExtension.lowercased() == "mp4" {
                files.append(url.standardizedFileURL)
            }
        } catch { unreadable += 1 }
    }
    return MediaScan(files: files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }, unreadableEntries: unreadable)
}

struct MediaFileInfo {
    let created: Date?
    let modified: Date?
    let size: Int64?
}
func readMediaFileInfo(_ url: URL) throws -> MediaFileInfo {
    let values = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey])
    return MediaFileInfo(created: values.creationDate, modified: values.contentModificationDate, size: values.fileSize.map(Int64.init))
}
enum MediaSort: Int, CaseIterable {
    case name, created, modified, size, path
    var title: String {
        switch self {
        case .name: return "Name"
        case .created: return "Date Created"
        case .modified: return "Date Modified"
        case .size: return "Size"
        case .path: return "Folder / Path"
        }
    }
}
func sortedMediaFiles(_ urls: [URL], info: [URL: MediaFileInfo], by key: MediaSort, descending: Bool) -> [URL] {
    return urls.sorted { a, b in
        let ai = info[a], bi = info[b]
        var order: ComparisonResult = .orderedSame
        switch key {
        case .name: order = a.lastPathComponent.localizedStandardCompare(b.lastPathComponent)
        case .path: order = a.path.localizedStandardCompare(b.path)
        case .created, .modified:
            let av = key == .created ? ai?.created : ai?.modified
            let bv = key == .created ? bi?.created : bi?.modified
            if av == nil && bv != nil { return false }
            if av != nil && bv == nil { return true }
            if let av = av, let bv = bv { order = av.compare(bv) }
        case .size:
            let av = ai?.size, bv = bi?.size
            if av == nil && bv != nil { return false }
            if av != nil && bv == nil { return true }
            if let av = av, let bv = bv { order = av < bv ? .orderedAscending : (av > bv ? .orderedDescending : .orderedSame) }
        }
        if order == .orderedSame { return a.path.localizedStandardCompare(b.path) == .orderedAscending }
        return descending ? order == .orderedDescending : order == .orderedAscending
    }
}

func collectMP4Selections(_ selections: [URL]) -> MediaScan {
    var files = Set<URL>(), unreadable = 0
    for url in selections {
        do {
            let info = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            if info.isSymbolicLink == true { continue }
            if info.isDirectory == true {
                let scan = try scanMP4Directory(url); files.formUnion(scan.files); unreadable += scan.unreadableEntries
            } else if info.isRegularFile == true, url.pathExtension.lowercased() == "mp4" { files.insert(url.standardizedFileURL) }
        } catch { unreadable += 1 }
    }
    return MediaScan(files: files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }, unreadableEntries: unreadable)
}
