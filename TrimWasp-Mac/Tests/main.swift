import Foundation

let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent("TrimWasp-test-" + UUID().uuidString)
try fm.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: root) }
func file(_ name: String) throws {
    let url = root.appendingPathComponent(name)
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data().write(to: url)
}
try file("clip10.mp4"); try file("clip2.MP4"); try file("nested/clip3.mp4")
try file("preview.LRV"); try file("thumb.THM"); try file("fake.mp4.txt"); try file(".hidden.mp4")
try file(".hidden/hidden.mp4")
try fm.createDirectory(at: root.appendingPathComponent("directory.mp4"), withIntermediateDirectories: true)
try fm.createSymbolicLink(at: root.appendingPathComponent("link.mp4"), withDestinationURL: root.appendingPathComponent("clip10.mp4"))
try fm.createSymbolicLink(at: root.appendingPathComponent("linked-directory"), withDestinationURL: root.appendingPathComponent("nested"))
let scan = try scanMP4Directory(root)
assert(scan.files.map { $0.lastPathComponent } == ["clip2.MP4", "clip10.mp4", "clip3.mp4"])
assert(scan.unreadableEntries == 0)
let empty = root.appendingPathComponent("empty")
try fm.createDirectory(at: empty, withIntermediateDirectories: true)
let emptyScan = try scanMP4Directory(empty)
assert(emptyScan.files.isEmpty)
var rejectedMissing = false
do { _ = try scanMP4Directory(root.appendingPathComponent("missing")) } catch { rejectedMissing = true }
assert(rejectedMissing)
print("PASS: recursive MP4 listing, mixed-case extensions, natural order, hidden/sidecar/directory exclusions, symlink exclusions, empty and missing folders. No video data needed.")

let a = root.appendingPathComponent("clip2.MP4"), b = root.appendingPathComponent("clip10.mp4"), c = root.appendingPathComponent("nested/clip3.mp4")
let entries = [c, b, a]
let information = [
    a: MediaFileInfo(created: Date(timeIntervalSince1970: 2), modified: Date(timeIntervalSince1970: 30), size: 30),
    b: MediaFileInfo(created: Date(timeIntervalSince1970: 1), modified: Date(timeIntervalSince1970: 20), size: 10),
    c: MediaFileInfo(created: nil, modified: Date(timeIntervalSince1970: 10), size: 20)
]
assert(sortedMediaFiles(entries, info: information, by: .name, descending: false) == [a,c,b])
assert(sortedMediaFiles(entries, info: information, by: .created, descending: false) == [b,a,c])
assert(sortedMediaFiles(entries, info: information, by: .created, descending: true) == [a,b,c])
assert(sortedMediaFiles(entries, info: information, by: .modified, descending: false) == [c,b,a])
assert(sortedMediaFiles(entries, info: information, by: .modified, descending: true) == [a,b,c])
assert(sortedMediaFiles(entries, info: information, by: .size, descending: false) == [b,c,a])
assert(sortedMediaFiles(entries, info: information, by: .size, descending: true) == [a,c,b])
assert(sortedMediaFiles(entries, info: information, by: .path, descending: false) == [a,b,c])
assert(sortedMediaFiles(entries, info: [:], by: .created, descending: true) == [a,b,c])
try Data([1,2]).write(to: a)
let fileInformation = try readMediaFileInfo(a)
assert(fileInformation.size == 2)
print("PASS: natural filename/path ordering, creation/modification/size sort in both directions, unknown-date placement, deterministic ties, filesystem size reads.")

assert(parsePlaybackSpeed("1") == 1)
assert(parsePlaybackSpeed(" 1.5× ") == 1.5)
assert(parsePlaybackSpeed("0.25x") == 0.25)
assert(parsePlaybackSpeed("0.1") == 0.1)
assert(parsePlaybackSpeed("8X") == 8)
for invalid in ["", "0", "-1", "8.01", "nan", "inf", "fast", "x2x", "1×2"] {
    assert(parsePlaybackSpeed(invalid) == nil)
}
print("PASS: playback speed presets/custom values, bounds and invalid input rejection.")

var markers = MarkerSelection()
assert(markers.points.isEmpty && markers.bounds == nil)
assert(markers.add(8, duration: 10))
assert(markers.bounds == nil)
assert(markers.add(2, duration: 10))
assert(markers.bounds?.start == 2 && markers.bounds?.end == 8)
assert(!markers.add(5, duration: 10))
assert(markers.points.count == 2)
assert(markers.move(0, to: 1, duration: 10))
assert(markers.bounds?.start == 1 && markers.bounds?.end == 2)
markers.clear()
assert(markers.points.isEmpty && markers.bounds == nil)
assert(markers.add(3, duration: 10))
assert(!markers.add(Double.nan, duration: 10))
assert(!markers.set([1,2,3], duration: 10))
assert(markers.points == [3])
assert(markers.move(0, to: -1, duration: 10))
assert(markers.points == [0])
assert(!markers.move(2, to: 1, duration: 10))
assert(markers.set([9,1], duration: 10))
assert(markers.bounds?.start == 1 && markers.bounds?.end == 9)
print("PASS: markers in either order, two-marker maximum, crossing while dragging, clearing/reuse, bounds and invalid input checks.")

let summary = fileDetails(a)
let fields = summary.components(separatedBy: "\n\n")
assert(fields.count == 6)
assert(fields[0] == "Filename\nclip2.MP4")
assert(fields[1] == "Filetype\nMP4")
assert(fields[2].hasPrefix("Size\n"))
assert(fields[3] == "Path\n" + root.path)
assert(fields[4].hasPrefix("Creation date\n"))
assert(fields[5].hasPrefix("Last modified date\n"))
for extra in ["NSFile", "TRACK", "Codec", "Last accessed", "Permissions", "EMBEDDED"] { assert(!summary.contains(extra)) }
print("PASS: only six requested detail fields, parent-directory path without filename, no metadata dump.")

assert(ThemeRGBA(hex: "#bb0ef0")?.hex == "#BB0EF0")
assert(ThemeRGBA(hex: "11223380")?.hex == "#11223380")
assert(ThemeRGBA(hex: "#00000000")?.alpha == 0)
assert(ThemeRGBA(hex: "#FFFFFF")?.alpha == 1)
for invalid in ["", "#123", "#12345", "#GGGGGG", "#123456789", "bb#0ef0"] { assert(ThemeRGBA(hex: invalid) == nil) }
let defaults = ThemeConfiguration.defaults
assert(defaults.colors.count == ThemeRole.allCases.count)
assert(defaults.colors[ThemeRole.accentText.rawValue] == "#E9E2DD")
for value in defaults.colors.values { assert(ThemeRGBA(hex: value) != nil) }
let themeData = try JSONEncoder().encode(defaults)
let decodedTheme = try JSONDecoder().decode(ThemeConfiguration.self, from: themeData)
assert(decodedTheme.schemaVersion == 1 && decodedTheme.colors == defaults.colors)
print("PASS: hex/RGBA parsing, valid theme defaults, #BB0EF0 accent, named-role JSON round trip.")

assert(clipTimelineLanes([]).isEmpty)
assert(clipTimelineLanes([(0,2),(2,4)]) == [0,0])
assert(clipTimelineLanes([(0,4),(1,3),(2,5)]) == [0,1,2])
assert(clipTimelineLanes([(5,7),(0,6),(1,2)]) == [1,0,1])
let spans: [(start: Double, end: Double)] = (0..<60).map { i in
    let start = Double((i * 7) % 23) / 2
    return (start, start + Double(i % 4 + 1) / 2)
}
let lanes = clipTimelineLanes(spans)
for i in spans.indices {
    for j in spans.indices where j > i && lanes[i] == lanes[j] {
        assert(spans[i].end <= spans[j].start || spans[j].end <= spans[i].start)
    }
}
print("PASS: adjacent ranges share lanes; overlaps/nested ranges stack; no intersecting ranges share a lane.")

let committed = [Clip(start: 1, end: 4), Clip(start: 5, end: 9)]
var draftSelection = MarkerSelection()
assert(draftSelection.set([8,2], duration: 10))
let livePreview = clipPreview(committed, editingIndex: 0, selection: draftSelection)
assert(livePreview == [Clip(start: 2, end: 8), Clip(start: 5, end: 9)])
assert(committed[0] == Clip(start: 1, end: 4))
assert(clipPreview(committed, editingIndex: nil, selection: draftSelection) == committed)
assert(clipPreview(committed, editingIndex: 50, selection: draftSelection) == committed)
draftSelection.clear()
assert(clipPreview(committed, editingIndex: 0, selection: draftSelection) == committed)
let mixedScan = collectMP4Selections([root, a, root.appendingPathComponent("nested"), root.appendingPathComponent("preview.LRV")])
assert(Set(mixedScan.files) == Set([a,b,c]))
assert(mixedScan.files.count == 3)
let acceptedTheme = try JSONDecoder().decode(ThemeConfiguration.self, from: Data(contentsOf: URL(fileURLWithPath: "Theme.json")))
assert(acceptedTheme.colors == ThemeConfiguration.defaults.colors)
print("PASS: live range previews preserve committed clips, mixed file/folder selections deduplicate, and baked colors exactly match the accepted theme.")

let sampleTimes = filmstripSampleTimes(duration: 6.339667)
assert(sampleTimes.count == 16)
assert(sampleTimes.allSatisfy { $0 > 0 && $0 < 6.339667 })
assert(zip(sampleTimes, sampleTimes.dropFirst()).allSatisfy { $0.0 < $0.1 })
assert(filmstripSampleTimes(duration: 0).isEmpty)
assert(filmstripSampleTimes(duration: .nan).isEmpty)
assert(filmstripSampleTimes(duration: 10, count: 1000).count == 32)
assert(!timelineViewportPlan(requiredHeight: 200, viewportHeight: 100, topOffset: 0, dragging: true).showsScrollbar)
assert(timelineViewportPlan(requiredHeight: 200, viewportHeight: 100, topOffset: 0, dragging: false).showsScrollbar)
assert(!timelineViewportPlan(requiredHeight: 100, viewportHeight: 200, topOffset: 0, dragging: false).showsScrollbar)
assert(!timelineViewportPlan(requiredHeight: 200.5, viewportHeight: 200, topOffset: 0, dragging: false).showsScrollbar)
assert(timelineViewportPlan(requiredHeight: 100, viewportHeight: 200, topOffset: 0, dragging: false).documentHeight == 200)
assert(timelineViewportPlan(requiredHeight: 500, viewportHeight: 200, topOffset: 20, dragging: false).offsetY == 280)
assert(timelineViewportPlan(requiredHeight: 500, viewportHeight: 200, topOffset: 1000, dragging: false).offsetY == 0)
print("PASS: bounded filmstrip samples stay within the source; scrollbar visibility waits for drag release, ignores tiny boundary overflow, and preserves/clamps scroll position.")
