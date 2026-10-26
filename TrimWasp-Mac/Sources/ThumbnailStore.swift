import AppKit
import AVFoundation
final class ThumbnailStore {
    private let images = NSCache<NSURL, NSImage>()
    private let queue = OperationQueue()
    private var paths: [URL: URL] = [:]
    private var operations: [URL: Operation] = [:]
    private let directory: URL
    var onReady: ((URL, NSImage?) -> Void)?
    init() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("TrimWasp-Thumbnails-" + UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        images.countLimit = 64; images.totalCostLimit = 32 * 1024 * 1024
        queue.name = "TrimWasp thumbnails"; queue.maxConcurrentOperationCount = 1; queue.qualityOfService = .utility
    }
    func image(for url: URL) -> NSImage? {
        if let image = images.object(forKey: url as NSURL) { return image }
        if let path = paths[url], let image = NSImage(contentsOf: path) {
            images.setObject(image, forKey: url as NSURL, cost: 480 * 270 * 4); return image
        }
        return nil
    }
    func isPending(_ url: URL) -> Bool { operations[url] != nil }
    func prepare(_ urls: [URL]) { for url in urls { request(url) } }
    func request(_ url: URL, priority: Bool = false) {
        if let operation = operations[url] {
            if priority { operation.queuePriority = .veryHigh }; return
        }
        guard paths[url] == nil else { return }
        let output = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        paths[url] = output
        let operation = BlockOperation { [weak self] in
            let data: Data? = autoreleasepool {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true; generator.maximumSize = CGSize(width: 480, height: 270)
                let frame = (try? generator.copyCGImage(at: CMTime(seconds: 0.1, preferredTimescale: 600), actualTime: nil)) ?? (try? generator.copyCGImage(at: .zero, actualTime: nil))
                guard let frame = frame else { return nil }
                return NSBitmapImageRep(cgImage: frame).representation(using: .jpeg, properties: [.compressionFactor: 0.72])
            }
            if let data = data { try? data.write(to: output, options: .atomic) }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.operations[url] = nil
                let image = data.flatMap { NSImage(data: $0) }
                if let image = image { self.images.setObject(image, forKey: url as NSURL, cost: 480 * 270 * 4) }
                self.onReady?(url, image)
            }
        }
        if priority { operation.queuePriority = .veryHigh }
        operations[url] = operation; queue.addOperation(operation)
    }
    func suspend(_ value: Bool) { queue.isSuspended = value }
    func shutdown() { queue.cancelAllOperations(); try? FileManager.default.removeItem(at: directory); images.removeAllObjects() }
}
