import AppKit
import AVFoundation
final class TimelineFilmstrip {
    static let frameCount = 16
    private let queue = OperationQueue()
    private let lock = NSLock()
    private var generation = 0
    init() { queue.name = "TrimWasp timeline frames"; queue.maxConcurrentOperationCount = 1; queue.qualityOfService = .utility }
    func cancel() { lock.lock(); generation += 1; lock.unlock(); queue.cancelAllOperations() }
    private func current(_ token: Int) -> Bool { lock.lock(); defer { lock.unlock() }; return generation == token }
    func prepare(_ asset: AVURLAsset, duration: Double, onFrame: @escaping (Int, NSImage) -> Void) {
        cancel(); lock.lock(); let token = generation; lock.unlock()
        queue.addOperation { [weak self] in
            guard let self = self, self.current(token) else { return }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.maximumSize = CGSize(width: 160, height: 90); generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
            let times = filmstripSampleTimes(duration: duration, count: Self.frameCount)
            for (index, time) in times.enumerated() {
                guard self.current(token) else { return }
                let data: Data? = autoreleasepool {
                    guard let frame = try? generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 60000), actualTime: nil) else { return nil }
                    return NSBitmapImageRep(cgImage: frame).representation(using: .jpeg, properties: [.compressionFactor: 0.75])
                }
                guard self.current(token), let data = data else { continue }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.current(token), let image = NSImage(data: data) else { return }
                    onFrame(index, image)
                }
            }
        }
    }
}
