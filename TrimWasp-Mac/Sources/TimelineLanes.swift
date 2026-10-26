import Foundation
func clipTimelineLanes(_ ranges: [(start: Double, end: Double)]) -> [Int] {
    let order = ranges.indices.sorted {
        if ranges[$0].start == ranges[$1].start { return $0 < $1 }
        return ranges[$0].start < ranges[$1].start
    }
    var endings: [Double] = []
    var lanes = Array(repeating: 0, count: ranges.count)
    for index in order {
        if let lane = endings.firstIndex(where: { $0 <= ranges[index].start }) {
            lanes[index] = lane; endings[lane] = ranges[index].end
        } else {
            lanes[index] = endings.count; endings.append(ranges[index].end)
        }
    }
    return lanes
}
