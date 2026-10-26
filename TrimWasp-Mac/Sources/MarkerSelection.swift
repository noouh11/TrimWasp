import Foundation

struct MarkerSelection {
    private(set) var points: [Double] = []
    var ordered: [Double] { points.sorted() }
    var bounds: (start: Double, end: Double)? {
        guard points.count == 2 else { return nil }
        let values = ordered
        return (values[0], values[1])
    }
    @discardableResult mutating func add(_ time: Double, duration: Double) -> Bool {
        guard points.count < 2, time.isFinite, duration.isFinite, duration > 0, (0...duration).contains(time) else { return false }
        points.append(time); return true
    }
    @discardableResult mutating func move(_ index: Int, to time: Double, duration: Double) -> Bool {
        guard points.indices.contains(index), time.isFinite, duration.isFinite, duration > 0 else { return false }
        points[index] = min(duration, max(0, time)); return true
    }
    @discardableResult mutating func set(_ values: [Double], duration: Double) -> Bool {
        guard values.count <= 2, duration.isFinite, duration > 0,
              values.allSatisfy({ $0.isFinite && (0...duration).contains($0) }) else { return false }
        points = values; return true
    }
    mutating func clear() { points.removeAll(keepingCapacity: true) }
}

struct Clip: Codable, Equatable {
    var start: Double
    var end: Double
}
func clipPreview(_ clips: [Clip], editingIndex: Int?, selection: MarkerSelection) -> [Clip] {
    guard let index = editingIndex, clips.indices.contains(index), let range = selection.bounds else { return clips }
    var preview = clips; preview[index] = Clip(start: range.start, end: range.end); return preview
}
