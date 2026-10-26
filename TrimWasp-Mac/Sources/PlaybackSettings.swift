import Foundation

func parsePlaybackSpeed(_ text: String) -> Float? {
    var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if cleaned.hasSuffix("×") || cleaned.hasSuffix("x") { cleaned.removeLast() }
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let value = Float(cleaned), value.isFinite, (0.1...8).contains(value) else { return nil }
    return value
}

func filmstripSampleTimes(duration: Double, count: Int = 16) -> [Double] {
    guard duration.isFinite, duration > 0, count > 0 else { return [] }
    let boundedCount = min(32, count)
    return (0..<boundedCount).map { duration * (Double($0) + 0.5) / Double(boundedCount) }
}
struct TimelineViewportPlan {
    let documentHeight: Double
    let showsScrollbar: Bool
    let offsetY: Double
}
func timelineViewportPlan(requiredHeight: Double, viewportHeight: Double, topOffset: Double, dragging: Bool) -> TimelineViewportPlan {
    let viewport = max(0, viewportHeight), height = max(requiredHeight, viewport)
    return TimelineViewportPlan(documentHeight: height, showsScrollbar: !dragging && requiredHeight > viewport + 1,
        offsetY: min(max(0, height - viewport), max(0, height - viewport - topOffset)))
}
