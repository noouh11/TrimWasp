import AppKit
import AVFoundation
import AVKit
import UniformTypeIdentifiers

let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
let appDisplayName = "TrimWasp \(appVersion)"
func stamp(_ seconds: Double) -> String {
    let ms = Int((max(0, seconds.isFinite ? seconds : 0) * 1000).rounded())
    return String(format: "%02d:%02d:%02d.%03d", ms / 3_600_000, ms / 60_000 % 60, ms / 1000 % 60, ms % 1000)
}
func parseTime(_ text: String) -> Double? {
    let parts = text.split(separator: ":", omittingEmptySubsequences: false)
    guard (1...3).contains(parts.count) else { return nil }
    var total = 0.0
    for part in parts {
        guard let n = Double(part), n.isFinite, n >= 0 else { return nil }
        total = total * 60 + n
    }
    return total
}
struct Project: Codable {
    var version: Int = 1
    var sourcePath: String
    var clips: [Clip]
}

var accent: NSColor { themeColor(.accentText) }
var panelColor: NSColor { themeColor(.panel) }

final class ProgressBar: NSView {
    var doubleValue = 0.0 { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        themeColor(.progressTrack).setFill(); NSBezierPath(roundedRect: bounds, xRadius: 2, yRadius: 2).fill()
        themeColor(.progress).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: bounds.width * CGFloat(min(1, max(0, doubleValue))), height: bounds.height), xRadius: 2, yRadius: 2).fill()
    }
}
final class ClipRow: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        themeColor(.queueSelection).setFill(); bounds.fill()
    }
}

final class MediaCard: NSCollectionViewItem {
    let nameLabel = NSTextField(labelWithString: "")
    let thumbnail = NSImageView()
    var representedURL: URL?
    override func loadView() {
        view = NSView(); view.wantsLayer = true; view.layer?.cornerRadius = 8
        thumbnail.imageScaling = .scaleProportionallyUpOrDown; thumbnail.contentTintColor = accent
        nameLabel.font = .systemFont(ofSize: 11, weight: .medium); nameLabel.lineBreakMode = .byTruncatingMiddle
        for v in [thumbnail, nameLabel] as [NSView] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        NSLayoutConstraint.activate([
            thumbnail.topAnchor.constraint(equalTo: view.topAnchor, constant: 4), thumbnail.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4), thumbnail.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4), thumbnail.heightAnchor.constraint(equalToConstant: 70),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8), nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8), nameLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -9)
        ])
        updateSelection()
    }
    override var isSelected: Bool { didSet { if isViewLoaded { updateSelection() } } }
    func updateSelection() {
        nameLabel.textColor = themeColor(.primaryText); thumbnail.contentTintColor = themeColor(.button)
        view.layer?.backgroundColor = themeColor(isSelected ? .cardSelection : .card).cgColor
        view.layer?.borderWidth = isSelected ? 1.5 : 1
        view.layer?.borderColor = themeColor(isSelected ? .cardSelectionBorder : .cardBorder).cgColor
    }
    func setThumbnail(_ image: NSImage?) { thumbnail.image = image ?? NSImage(systemSymbolName: "film", accessibilityDescription: "Video thumbnail unavailable") }
    func configure(_ url: URL, image: NSImage?) { _ = view; representedURL = url; nameLabel.stringValue = url.lastPathComponent; view.toolTip = url.path; setThumbnail(image) }
}

final class VerticalClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds); rect.origin.x = 0; return rect
    }
}
final class DetailsScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let text = documentView as? NSTextView else { return }
        let width = contentSize.width
        if abs(text.frame.width - width) > 0.5 { text.setFrameSize(NSSize(width: width, height: text.frame.height)) }
    }
}

final class Timeline: NSView {
    var filmstrip: [NSImage?] = []
    var fallbackThumbnail: NSImage?
    var editingEnabled = false { didSet { needsDisplay = true } }
    var duration = 0.0
    var current = 0.0
    var selection = MarkerSelection()
    var laneIndices: [Int] = []
    var requiredHeight: CGFloat { max(154, 122 + CGFloat((laneIndices.max().map { $0 + 1 }) ?? 0) * 22) }
    var clips: [Clip] = [] {
        didSet { laneIndices = clipTimelineLanes(clips.map { (start: $0.start, end: $0.end) }); needsDisplay = true }
    }
    var onSeek: ((Double, Bool) -> Void)?
    var onMoveMark: ((Int, Double) -> Void)?
    var onAddMark: ((Double) -> Void)?
    var onSelectClip: ((Int) -> Void)?
    private var dragKind = 0
    private var track: NSRect { NSRect(x: 26, y: bounds.height - 102, width: max(1, bounds.width - 52), height: 50) }
    private func x(_ t: Double) -> CGFloat { track.minX + CGFloat(t / max(duration, 0.001)) * track.width }
    private func t(_ x: CGFloat) -> Double { max(0, min(duration, Double((x - track.minX) / track.width) * duration)) }
    private func clipBar(at index: Int) -> NSRect {
        let clip = clips[index]
        let lane = laneIndices.indices.contains(index) ? laneIndices[index] : 0
        return NSRect(x: x(clip.start), y: track.minY - CGFloat(lane + 1) * 22, width: max(2, x(clip.end) - x(clip.start)), height: 16)
    }
    override var acceptsFirstResponder: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        themeColor(.timelineBackground).setFill(); bounds.fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular), .foregroundColor: themeColor(.secondaryText)]
        themeColor(.timelineTrack).setFill()
        NSBezierPath(roundedRect: track, xRadius: 5, yRadius: 5).fill()
        guard duration > 0, editingEnabled else {
            ("Select a video and click Import Video to begin clipping" as NSString).draw(at: NSPoint(x: 40, y: track.minY + 18), withAttributes: attrs)
            return
        }
        drawFilmstrip()
        for i in 0...20 {
            let time = duration * Double(i) / 20
            let tick = NSBezierPath(); tick.move(to: NSPoint(x: x(time), y: bounds.height - 41)); tick.line(to: NSPoint(x: x(time), y: bounds.height - (i % 5 == 0 ? 31 : 36)))
            themeColor(.ruler).setStroke(); tick.stroke()
            if i % 5 == 0 {
                let label = stamp(time) as NSString; let w = label.size(withAttributes: attrs).width
                label.draw(at: NSPoint(x: min(bounds.width - w - 8, max(8, x(time) - w / 2)), y: bounds.height - 23), withAttributes: attrs)
            }
        }
        for index in clips.indices {
            themeColor(.queuedRange).setFill()
            let bar = clipBar(at: index)
            NSBezierPath(roundedRect: bar, xRadius: 3, yRadius: 3).fill()
            if bar.width > 26 {
                let text = bar.width > 64 ? "Clip \(index + 1)" : "\(index + 1)"
                text.draw(at: NSPoint(x: bar.minX + 5, y: bar.minY + 2), withAttributes: [.font: NSFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: themeColor(.primaryText)])
            }
        }
        if let range = selection.bounds {
            themeColor(.range).setFill()
            let selected = NSBezierPath(roundedRect: NSRect(x: x(range.start), y: track.minY, width: max(1, x(range.end) - x(range.start)), height: 50), xRadius: 5, yRadius: 5)
            selected.fill(); themeColor(.marker).setStroke(); selected.lineWidth = 1.5; selected.stroke()
        }
        for time in selection.points {
            themeColor(.marker).setFill()
            NSBezierPath(roundedRect: NSRect(x: x(time) - 4, y: track.minY - 2, width: 8, height: 54), xRadius: 3, yRadius: 3).fill()
        }
        themeColor(.playhead).setStroke()
        let head = NSBezierPath(); head.move(to: NSPoint(x: x(current), y: 6)); head.line(to: NSPoint(x: x(current), y: bounds.height - 31)); head.lineWidth = 1.5; head.stroke()
    }
    private func drawFilmstrip() {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: track, xRadius: 5, yRadius: 5).addClip()
        let count = max(1, filmstrip.count), width = track.width / CGFloat(count)
        for i in 0..<count {
            guard let image = (filmstrip.indices.contains(i) ? filmstrip[i] : nil) ?? fallbackThumbnail, image.size.width > 0, image.size.height > 0 else { continue }
            let destination = NSRect(x: track.minX + CGFloat(i) * width, y: track.minY, width: width + 0.5, height: track.height)
            let scale = max(destination.width / image.size.width, destination.height / image.size.height)
            let cropSize = NSSize(width: destination.width / scale, height: destination.height / scale)
            let crop = NSRect(x: (image.size.width - cropSize.width) / 2, y: (image.size.height - cropSize.height) / 2, width: cropSize.width, height: cropSize.height)
            image.draw(in: destination, from: crop, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
        }
        NSGraphicsContext.restoreGraphicsState()
        if fallbackThumbnail == nil && !filmstrip.contains(where: { $0 != nil }) {
            ("Preparing video thumbnails…" as NSString).draw(at: NSPoint(x: track.minX + 10, y: track.minY + 18), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: themeColor(.primaryText)])
        }
    }
    override func mouseDown(with event: NSEvent) {
        guard duration > 0, editingEnabled else { return }; window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        if let index = clips.indices.reversed().first(where: { clipBar(at: $0).contains(point) }) {
            dragKind = -1; onSelectClip?(index); return
        }
        if event.clickCount == 2 {
            dragKind = -1; onAddMark?(t(point.x)); return
        }
        if (track.minY - 2...track.maxY + 2).contains(point.y), let index = selection.points.indices.min(by: { abs(point.x - x(selection.points[$0])) < abs(point.x - x(selection.points[$1])) }), abs(point.x - x(selection.points[index])) <= 9 {
            dragKind = index + 1
        } else { dragKind = 0 }
        move(event, finished: false)
    }
    override func mouseDragged(with event: NSEvent) { move(event, finished: false) }
    override func mouseUp(with event: NSEvent) { move(event, finished: true) }
    private func move(_ event: NSEvent, finished: Bool) {
        let time = t(convert(event.locationInWindow, from: nil).x)
        if dragKind == 0 { onSeek?(time, finished) } else if dragKind > 0 { onMoveMark?(dragKind - 1, time) }
    }
}

final class EditorSplitView: NSSplitView {
    override var isFlipped: Bool { true }
    override var dividerThickness: CGFloat { 6 }
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?
    override func drawDivider(in rect: NSRect) { themeColor(.window).setFill(); rect.fill() }
    override func mouseDown(with event: NSEvent) {
        onDragBegan?(); super.mouseDown(with: event); onDragEnded?()
    }
}

final class App: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate, NSTextFieldDelegate, NSCollectionViewDataSource, NSCollectionViewDelegate, NSSplitViewDelegate, NSComboBoxDelegate {
    var window: NSWindow!
    var easterEggWindow: NSWindow?
    let editorSplit = EditorSplitView()
    let filmstripGenerator = TimelineFilmstrip()
    var timelineDividerDragging = false
    var timelineResizeScheduled = false
    var updatingTimelineViewport = false
    let clipActionButton = NSButton(title: "Add Clip [A]", target: nil, action: nil)
    var editingClipIndex: Int?
    var developerClickCount = 0
    var developerClickStart = 0.0
    var queuedWindow: NSWindow?
    let queuedSource = NSTextField(labelWithString: "No clips queued")
    let timelineScroll = NSScrollView()
    let media = NSCollectionView()
    let thumbnails = ThumbnailStore()
    let thumbnailPreview = NSImageView()
    let importVideoButton = NSButton(title: "Import Video", target: nil, action: nil)
    var selectedMedia: URL?
    var previewingSelection = false
    var pendingRestoredClips: [Clip]?
    var sourceControls: [NSControl] = []
    let workspaceSplit = NSSplitView()
    let detailsSplit = NSSplitView()
    var sortKey = MediaSort.name
    let cancelExportButton = NSButton(title: "Cancel Export", target: nil, action: nil)
    let playButton = NSButton(title: "", target: nil, action: nil)
    let speedBox = NSComboBox()
    var playbackSpeed: Float = 1
    var rateObservation: NSKeyValueObservation?
    let detailsText = NSTextView()
    var mediaInformation: [URL: MediaFileInfo] = [:]
    var sorting = false
    var sortDescending = false
    var sortGeneration = 0
    let mediaCount = NSTextField(labelWithString: "Add a folder to list its MP4 videos")
    let mediaFolder = NSTextField(labelWithString: "No folder selected")
    let detailQueue = NSTextField(labelWithString: "Pending Clips: 0")
    let playerTitle = NSTextField(labelWithString: "Player")
    let emptyPlayer = NSTextField(labelWithString: "Select a video from Media")
    var mediaFiles: [URL] = []
    var scanning = false
    let player = AVPlayer()
    let video = AVPlayerView()
    let timeline = Timeline()
    let table = NSTableView()
    let status = NSTextField(labelWithString: "Open an MP4 to begin. Your original video is never modified.")
    let timeLabel = NSTextField(labelWithString: "00:00:00.000 / 00:00:00.000")
    let inField = NSTextField(string: "")
    let outField = NSTextField(string: "")
    let mode = NSPopUpButton(frame: .zero, pullsDown: false)
    let progress = ProgressBar()
    var controls: [NSControl] = []
    var asset: AVURLAsset?
    var source: URL?
    var duration = 0.0
    var fps = 30.0
    var clips: [Clip] = []
    var observer: Any?
    var keyMonitor: Any?
    var playbackFailure: NSObjectProtocol?
    var session: AVAssetExportSession?
    var exportTimer: Timer?
    var exporting = false
    var cancelled = false
    var loading = false
    var dirty = false
    var finished = 0
    var failures: [String] = []
    var seekBusy = false
    var pendingSeek: (Double, Bool)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeMenu(); makeWindow()
        ThemeStore.shared.onChange = { [weak self] in self?.applyTheme() }
        applyTheme()
        thumbnails.onReady = { [weak self] url, image in
            guard let self = self else { return }
            for case let card as MediaCard in self.media.visibleItems() where card.representedURL == url { card.setThumbnail(image) }
            if self.source?.standardizedFileURL == url.standardizedFileURL {
                self.timeline.fallbackThumbnail = image; self.timeline.needsDisplay = true
            }
            if self.selectedMedia == url, self.previewingSelection {
                self.thumbnailPreview.image = image; self.emptyPlayer.isHidden = image != nil
                self.emptyPlayer.stringValue = image == nil ? "Thumbnail unavailable — Import Video to open" : ""
            }
        }
        updateControlAvailability()
        rateObservation = player.observe(\.rate, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updatePlaySymbol() }
        }
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self, !self.previewingSelection else { return }
            let value = time.seconds
            guard value.isFinite else { return }
            if !self.seekBusy { self.timeline.current = value }
            self.timeline.needsDisplay = true
            self.timeLabel.stringValue = "\(stamp(value)) / \(stamp(self.duration))"
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.window.isKeyWindow,
                  !((self.window.firstResponder as? NSTextView)?.isEditable ?? false),
                  event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                  !self.exporting, !self.loading, !self.previewingSelection, self.asset != nil else { return event }
            switch event.keyCode {
            case 49: self.playPause(); return nil
            case 123: self.step(-1); return nil
            case 124: self.step(1); return nil
            default: break
            }
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "m": self.mark(); return nil
            case "a": self.addClip(); return nil
            default: return event
            }
        }
        playbackFailure = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: nil, queue: .main) { [weak self] note in
            self?.alert("Playback failed", (note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription ?? "macOS could not decode this video.")
        }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ notification: Notification) { queuedWindow?.close(); easterEggWindow?.close() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if exporting { alert("Export in progress", "Cancel the batch before closing TrimWasp."); return false }
        guard confirmDiscard() else { return false }; dirty = false; return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if exporting { alert("Export in progress", "Cancel the batch before quitting TrimWasp."); return .terminateCancel }
        return confirmDiscard() ? .terminateNow : .terminateCancel
    }
    func applicationWillTerminate(_ notification: Notification) {
        filmstripGenerator.cancel()
        thumbnails.shutdown()
        rateObservation?.invalidate()
        if let observer = observer { player.removeTimeObserver(observer) }
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
        if let playbackFailure = playbackFailure { NotificationCenter.default.removeObserver(playbackFailure) }
    }
    func makeMenu() {
        let bar = NSMenu()
        let appItem = NSMenuItem(); bar.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About TrimWasp", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit TrimWasp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let fileItem = NSMenuItem(); bar.addItem(fileItem)
        let fileMenu = NSMenu(title: "File"); fileItem.submenu = fileMenu
        for (title, action, key) in [("Load Files…", #selector(loadFiles), "o"), ("Save Clip List…", #selector(saveProject), "s"), ("Open Clip List…", #selector(openProject), "l"), ("Export Clips", #selector(exportAll), "e")] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; fileMenu.addItem(item)
        }
        let editItem = NSMenuItem(); bar.addItem(editItem)
        let edit = NSMenu(title: "Edit"); editItem.submenu = edit
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = bar
    }
    func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action); b.bezelStyle = .rounded; controls.append(b); return b
    }
    func cancelButton() -> NSButton {
        cancelExportButton.target = self; cancelExportButton.action = #selector(cancelExport)
        cancelExportButton.bezelStyle = .rounded; cancelExportButton.contentTintColor = accent
        cancelExportButton.isEnabled = false
        return cancelExportButton
    }
    func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views); stack.orientation = .horizontal; stack.distribution = .fill; stack.spacing = 8; stack.alignment = .centerY; return stack
    }
    func label(_ title: String, accentColor: Bool = false) -> NSTextField {
        let v = NSTextField(labelWithString: title); v.font = .systemFont(ofSize: 12, weight: .semibold)
        v.identifier = NSUserInterfaceItemIdentifier(accentColor ? "theme.accent" : "theme.primary"); return v
    }
    func spacer() -> NSView {
        let v = NSView(); v.setContentHuggingPriority(.defaultLow, for: .horizontal); return v
    }
    func panel(_ body: NSView) -> NSView {
        let shell = NSView(); shell.identifier = NSUserInterfaceItemIdentifier("theme.panel"); shell.wantsLayer = true; shell.layer?.backgroundColor = panelColor.cgColor; shell.layer?.cornerRadius = 9; shell.layer?.masksToBounds = true
        body.translatesAutoresizingMaskIntoConstraints = false; shell.addSubview(body)
        NSLayoutConstraint.activate([body.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14), body.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -14), body.topAnchor.constraint(equalTo: shell.topAnchor, constant: 12), body.bottomAnchor.constraint(equalTo: shell.bottomAnchor, constant: -12)])
        return shell
    }
    func column(_ views: [NSView], spacing: CGFloat = 12) -> NSStackView {
        let v = NSStackView(views: views); v.orientation = .vertical; v.distribution = .fill; v.alignment = .leading; v.spacing = spacing; return v
    }
    func makeWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1260, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "TrimWasp"; window.minSize = NSSize(width: 1120, height: 800); window.center(); window.delegate = self
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = themeColor(.window)
        let root = column([], spacing: 8); root.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!; content.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10), root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10), root.topAnchor.constraint(equalTo: content.topAnchor, constant: 8), root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8)])

        mode.contentTintColor = accent
        mode.addItems(withTitles: ["Fast • Original Quality (.mov)", "Fast • Original Quality (.mp4)", "Precise • Re-Encode (.mp4)"]); controls.append(mode)
        let export = button("Export Clips", #selector(exportAll)); export.contentTintColor = accent; sourceControls.append(export)
        let logo = NSButton(title: appDisplayName, target: self, action: #selector(developerLogoClick))
        logo.isBordered = false; logo.font = .systemFont(ofSize: 12, weight: .semibold); logo.identifier = NSUserInterfaceItemIdentifier("theme.logo")
        let toolbar = row([logo, button("Open Clip List…", #selector(openProject)), button("Save Clip List…", #selector(saveProject)), spacer(), mode, export, cancelButton()])
        root.addArrangedSubview(toolbar)
        let loadButton = button("Load Files", #selector(loadFiles)); loadButton.contentTintColor = accent
        let sortButton = button("", #selector(showSortMenu(_:)))
        sortButton.image = NSImage(systemSymbolName: "line.3.horizontal.decrease", accessibilityDescription: "Sort by")
        sortButton.imagePosition = .imageOnly; sortButton.contentTintColor = accent; sortButton.toolTip = "Sort by…"
        sortButton.setAccessibilityLabel("Sort by")
        for b in [loadButton, sortButton] { b.controlSize = .small; b.font = .systemFont(ofSize: 11) }
        mediaFolder.font = .systemFont(ofSize: 11); mediaFolder.identifier = NSUserInterfaceItemIdentifier("theme.secondary"); mediaFolder.lineBreakMode = .byTruncatingMiddle
        mediaCount.font = .systemFont(ofSize: 10); mediaCount.identifier = NSUserInterfaceItemIdentifier("theme.secondary")
        let flow = NSCollectionViewFlowLayout(); flow.itemSize = NSSize(width: 122, height: 104); flow.minimumInteritemSpacing = 8; flow.minimumLineSpacing = 10
        flow.sectionInset = NSEdgeInsets(top: 4, left: 0, bottom: 8, right: 0)
        media.frame = NSRect(x: 0, y: 0, width: 272, height: 310); media.autoresizingMask = [.width]
        media.collectionViewLayout = flow; media.isSelectable = true; media.allowsMultipleSelection = false; media.backgroundColors = [panelColor]
        media.dataSource = self; media.delegate = self; media.register(MediaCard.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("media"))
        let mediaScroll = NSScrollView(); mediaScroll.documentView = media; mediaScroll.hasVerticalScroller = true; mediaScroll.autohidesScrollers = true; mediaScroll.drawsBackground = false
        importVideoButton.target = self; importVideoButton.action = #selector(importSelectedVideo)
        importVideoButton.bezelStyle = .rounded; importVideoButton.contentTintColor = accent; importVideoButton.isEnabled = false
        importVideoButton.controlSize = .small; importVideoButton.font = .systemFont(ofSize: 11)
        mediaCount.stringValue = "0 MP4s Ready"
        let mediaFooter = row([mediaCount, spacer(), importVideoButton])
        let mediaBody = column([row([label("Media", accentColor: true), spacer()]), row([loadButton, spacer(), sortButton]), mediaFolder, mediaScroll, mediaFooter], spacing: 10)
        let mediaPanel = panel(mediaBody)
        for v in mediaBody.arrangedSubviews { v.widthAnchor.constraint(equalTo: mediaBody.widthAnchor).isActive = true }
        video.player = player; video.controlsStyle = .none; video.videoGravity = .resizeAspect
        video.identifier = NSUserInterfaceItemIdentifier("theme.videoBackground"); video.wantsLayer = true; video.layer?.backgroundColor = themeColor(.videoBackground).cgColor
        let preview = NSView(); preview.identifier = NSUserInterfaceItemIdentifier("theme.videoBackground"); preview.wantsLayer = true; preview.layer?.backgroundColor = themeColor(.videoBackground).cgColor
        video.translatesAutoresizingMaskIntoConstraints = false; preview.addSubview(video)
        thumbnailPreview.translatesAutoresizingMaskIntoConstraints = false; thumbnailPreview.imageScaling = .scaleProportionallyUpOrDown
        thumbnailPreview.isHidden = true; preview.addSubview(thumbnailPreview)
        NSLayoutConstraint.activate([thumbnailPreview.leadingAnchor.constraint(equalTo: preview.leadingAnchor), thumbnailPreview.trailingAnchor.constraint(equalTo: preview.trailingAnchor), thumbnailPreview.topAnchor.constraint(equalTo: preview.topAnchor), thumbnailPreview.bottomAnchor.constraint(equalTo: preview.bottomAnchor)])
        emptyPlayer.translatesAutoresizingMaskIntoConstraints = false; emptyPlayer.identifier = NSUserInterfaceItemIdentifier("theme.secondary"); emptyPlayer.font = .systemFont(ofSize: 13); preview.addSubview(emptyPlayer)
        NSLayoutConstraint.activate([video.leadingAnchor.constraint(equalTo: preview.leadingAnchor), video.trailingAnchor.constraint(equalTo: preview.trailingAnchor), video.topAnchor.constraint(equalTo: preview.topAnchor), video.bottomAnchor.constraint(equalTo: preview.bottomAnchor), emptyPlayer.centerXAnchor.constraint(equalTo: preview.centerXAnchor), emptyPlayer.centerYAnchor.constraint(equalTo: preview.centerYAnchor), preview.heightAnchor.constraint(greaterThanOrEqualToConstant: 180)])
        playerTitle.font = .systemFont(ofSize: 12, weight: .semibold); playerTitle.lineBreakMode = .byTruncatingMiddle
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        playButton.target = self; playButton.action = #selector(playPause); playButton.bezelStyle = .rounded
        playButton.imagePosition = .imageOnly; playButton.contentTintColor = accent; controls.append(playButton)
        let previous = button("", #selector(previousFrame)), next = button("", #selector(nextFrame))
        previous.image = NSImage(systemSymbolName: "backward.end.fill", accessibilityDescription: "Previous Frame")
        next.image = NSImage(systemSymbolName: "forward.end.fill", accessibilityDescription: "Next Frame")
        for b in [previous, playButton, next] { b.widthAnchor.constraint(equalToConstant: 32).isActive = true; b.contentTintColor = accent }
        sourceControls.append(contentsOf: [previous, playButton, next])
        previous.toolTip = "Previous Frame (←)"; next.toolTip = "Next Frame (→)"
        let transport = NSView()
        timeLabel.translatesAutoresizingMaskIntoConstraints = false; timeLabel.alignment = .left
        timeLabel.lineBreakMode = .byTruncatingMiddle
        timeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        transport.addSubview(timeLabel)
        let transportButtons = row([previous, playButton, next]); transportButtons.translatesAutoresizingMaskIntoConstraints = false; transport.addSubview(transportButtons)
        speedBox.addItems(withObjectValues: ["0.25×", "0.5×", "0.75×", "1×", "1.25×", "1.5×", "2×", "3×", "4×", "8×"])
        speedBox.stringValue = "1×"; speedBox.isEditable = true; speedBox.completes = false
        speedBox.target = self; speedBox.action = #selector(changePlaybackSpeed); speedBox.delegate = self
        speedBox.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        speedBox.toolTip = "Playback speed: choose or type 0.1×–8×. Changes preview only."
        speedBox.setAccessibilityLabel("Playback speed")
        speedBox.translatesAutoresizingMaskIntoConstraints = false; transport.addSubview(speedBox); controls.append(speedBox); sourceControls.append(speedBox)
        NSLayoutConstraint.activate([
            timeLabel.leadingAnchor.constraint(equalTo: transport.leadingAnchor), timeLabel.centerYAnchor.constraint(equalTo: transport.centerYAnchor),
            timeLabel.trailingAnchor.constraint(lessThanOrEqualTo: transportButtons.leadingAnchor, constant: -8), timeLabel.heightAnchor.constraint(equalToConstant: 16),
            transport.heightAnchor.constraint(equalToConstant: 28), transportButtons.centerXAnchor.constraint(equalTo: transport.centerXAnchor), transportButtons.centerYAnchor.constraint(equalTo: transport.centerYAnchor),
            speedBox.trailingAnchor.constraint(equalTo: transport.trailingAnchor), speedBox.centerYAnchor.constraint(equalTo: transport.centerYAnchor), speedBox.widthAnchor.constraint(equalToConstant: 72),
            speedBox.leadingAnchor.constraint(greaterThanOrEqualTo: transportButtons.trailingAnchor, constant: 8)
        ])
        let playerBody = NSView()
        for v in [playerTitle, preview, transport] as [NSView] { v.translatesAutoresizingMaskIntoConstraints = false; playerBody.addSubview(v) }
        NSLayoutConstraint.activate([
            playerTitle.topAnchor.constraint(equalTo: playerBody.topAnchor), playerTitle.leadingAnchor.constraint(equalTo: playerBody.leadingAnchor), playerTitle.trailingAnchor.constraint(equalTo: playerBody.trailingAnchor), playerTitle.heightAnchor.constraint(equalToConstant: 16),
            preview.topAnchor.constraint(equalTo: playerTitle.bottomAnchor, constant: 8), preview.leadingAnchor.constraint(equalTo: playerBody.leadingAnchor), preview.trailingAnchor.constraint(equalTo: playerBody.trailingAnchor), preview.bottomAnchor.constraint(equalTo: transport.topAnchor, constant: -8),
            transport.leadingAnchor.constraint(equalTo: playerBody.leadingAnchor), transport.trailingAnchor.constraint(equalTo: playerBody.trailingAnchor), transport.bottomAnchor.constraint(equalTo: playerBody.bottomAnchor)
        ])
        let playerPanel = panel(playerBody)
        detailsText.isEditable = false; detailsText.isSelectable = true; detailsText.drawsBackground = false
        detailsText.font = .systemFont(ofSize: 11); detailsText.textColor = .labelColor
        detailsText.textContainerInset = NSSize(width: 0, height: 4)
        detailsText.frame = NSRect(x: 0, y: 0, width: 232, height: 280)
        detailsText.minSize = .zero; detailsText.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        detailsText.textContainer?.containerSize = NSSize(width: 232, height: CGFloat.greatestFiniteMagnitude)
        detailsText.isVerticallyResizable = true; detailsText.isHorizontallyResizable = false
        detailsText.autoresizingMask = [.width]; detailsText.textContainer?.widthTracksTextView = true
        detailsText.string = "Select a video to view its details."
        let detailScroll = DetailsScrollView(); detailScroll.contentView = VerticalClipView()
        detailScroll.documentView = detailsText; detailScroll.hasVerticalScroller = true; detailScroll.hasHorizontalScroller = false
        detailScroll.horizontalScrollElasticity = .none; detailScroll.verticalScrollElasticity = .none
        detailScroll.scrollerStyle = .overlay; detailScroll.autohidesScrollers = true; detailScroll.drawsBackground = false
        detailsText.textContainer?.lineFragmentPadding = 0
        let detailsBody = column([label("Details", accentColor: true), detailScroll], spacing: 8)
        for v in detailsBody.arrangedSubviews { v.widthAnchor.constraint(equalTo: detailsBody.widthAnchor).isActive = true }
        let detailsPanel = panel(detailsBody)
        detailsSplit.isVertical = true; detailsSplit.dividerStyle = .thin; detailsSplit.delegate = self
        detailsSplit.frame = NSRect(x: 0, y: 0, width: 939, height: 380)
        playerPanel.frame = NSRect(x: 0, y: 0, width: 678, height: 380)
        detailsPanel.frame = NSRect(x: 679, y: 0, width: 260, height: 380)
        detailsSplit.addSubview(playerPanel); detailsSplit.addSubview(detailsPanel)
        let workspace = detailsSplit
        workspaceSplit.isVertical = true; workspaceSplit.dividerStyle = .thin; workspaceSplit.delegate = self
        workspaceSplit.frame = NSRect(x: 0, y: 0, width: 1240, height: 380)
        mediaPanel.frame = NSRect(x: 0, y: 0, width: 300, height: 380)
        workspace.frame = NSRect(x: 301, y: 0, width: 939, height: 380)
        workspaceSplit.addSubview(mediaPanel); workspaceSplit.addSubview(workspace)
        sourceControls.append(contentsOf: [inField, outField])
        for field in [inField, outField] { field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular); field.widthAnchor.constraint(equalToConstant: 114).isActive = true; field.delegate = self; controls.append(field) }
        inField.placeholderString = "First / Start"; outField.placeholderString = "End"
        let markerButton = button("Mark [M]", #selector(mark)), remove = button("Remove Selected", #selector(removeClip))
        clipActionButton.target = self; clipActionButton.action = #selector(addClip); clipActionButton.bezelStyle = .rounded
        controls.append(clipActionButton); sourceControls.append(contentsOf: [markerButton, clipActionButton, remove])
        let trim = row([label("Timeline", accentColor: true), spacer(), markerButton, inField, outField, clipActionButton, remove])
        timeline.frame = NSRect(x: 0, y: 0, width: 1000, height: 154); timeline.autoresizingMask = [.width]
        timelineScroll.contentView = VerticalClipView(); timelineScroll.documentView = timeline
        timelineScroll.hasVerticalScroller = false; timelineScroll.hasHorizontalScroller = false; timelineScroll.autohidesScrollers = false
        timelineScroll.scrollerStyle = .overlay; timelineScroll.horizontalScrollElasticity = .none; timelineScroll.verticalScrollElasticity = .none; timelineScroll.drawsBackground = false
        timelineScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        timeline.onSeek = { [weak self] t, exact in self?.seek(t, exact: exact) }
        timeline.onMoveMark = { [weak self] index, t in
            guard let self = self, !self.exporting, !self.loading, !self.previewingSelection else { return }
            self.timeline.selection.move(index, to: t, duration: self.duration); self.refreshMarks()
            if self.editingClipIndex != nil { self.status.stringValue = "Editing existing clip length" }
        }
        timeline.onAddMark = { [weak self] t in self?.placeMarker(t) }
        timeline.onSelectClip = { [weak self] index in self?.editClip(at: index) }
        let editBody = column([trim, timelineScroll], spacing: 8)
        for v in editBody.arrangedSubviews { v.widthAnchor.constraint(equalTo: editBody.widthAnchor).isActive = true }
        let timelinePanel = panel(editBody)
        editorSplit.onDragBegan = { [weak self] in
            guard let self = self else { return }; self.timelineDividerDragging = true; self.timelineScroll.hasVerticalScroller = false
        }
        editorSplit.onDragEnded = { [weak self] in
            guard let self = self else { return }; self.timelineDividerDragging = false; self.resizeTimeline(scrollToTop: false)
        }
        editorSplit.isVertical = false; editorSplit.dividerStyle = .thin; editorSplit.delegate = self
        editorSplit.frame = NSRect(x: 0, y: 0, width: 1240, height: 620)
        workspaceSplit.frame = NSRect(x: 0, y: 0, width: 1240, height: 400)
        timelinePanel.frame = NSRect(x: 0, y: 406, width: 1240, height: 214)
        editorSplit.addSubview(workspaceSplit); editorSplit.addSubview(timelinePanel)
        root.addArrangedSubview(editorSplit)
        prepareQueueWindow()
        root.addArrangedSubview(progress); progress.heightAnchor.constraint(equalToConstant: 4).isActive = true
        status.font = .systemFont(ofSize: 10); status.lineBreakMode = .byTruncatingMiddle
        root.addArrangedSubview(status)
        let hint = NSTextField(labelWithString: "Space: Play/Pause    ← →: Frame    M: Mark    Double-Click: Mark    A: Add/Update    Drag Markers to Adjust")
        hint.font = .systemFont(ofSize: 10); hint.identifier = NSUserInterfaceItemIdentifier("theme.secondary"); detailQueue.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold); detailQueue.identifier = NSUserInterfaceItemIdentifier("theme.accent")
        let footer = row([hint, spacer(), detailQueue, queueViewButton()]); root.addArrangedSubview(footer)
        for v in root.arrangedSubviews { v.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true }
    }
    @objc func developerLogoClick() {
        let now = ProcessInfo.processInfo.systemUptime
        if developerClickCount == 0 || now - developerClickStart > 3 { developerClickCount = 0; developerClickStart = now }
        developerClickCount += 1
        if developerClickCount == 5 { developerClickCount = 0; showEasterEgg() }
    }
    func showEasterEgg() {
        if easterEggWindow == nil {
            let egg = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 160),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            egg.title = "TrimWasp"; egg.isReleasedWhenClosed = false
            egg.backgroundColor = themeColor(.panel)
            let message = NSTextField(wrappingLabelWithString: "woah, you found an easter egg! nice job! i hope you enjoy my app!")
            message.font = .systemFont(ofSize: 16)
            message.textColor = themeColor(.primaryText); message.alignment = .center
            message.translatesAutoresizingMaskIntoConstraints = false
            egg.contentView!.addSubview(message)
            NSLayoutConstraint.activate([
                message.leadingAnchor.constraint(equalTo: egg.contentView!.leadingAnchor, constant: 32),
                message.trailingAnchor.constraint(equalTo: egg.contentView!.trailingAnchor, constant: -32),
                message.centerYAnchor.constraint(equalTo: egg.contentView!.centerYAnchor)
            ])
            egg.center(); easterEggWindow = egg
        }
        easterEggWindow?.makeKeyAndOrderFront(nil)
    }
    func applyTheme() {
        guard window != nil else { return }
        window.backgroundColor = themeColor(.window)
        func visit(_ view: NSView) {
            let tag = view.identifier?.rawValue
            if tag == "theme.panel" { view.layer?.backgroundColor = themeColor(.panel).cgColor }
            if tag == "theme.videoBackground" { view.layer?.backgroundColor = themeColor(.videoBackground).cgColor }
            if let button = view as? NSButton { button.contentTintColor = themeColor(tag == "theme.logo" ? .accentText : .button) }
            if let text = view as? NSTextField {
                if text.isEditable {
                    text.textColor = themeColor(.inputText); text.backgroundColor = themeColor(.inputBackground); text.drawsBackground = true
                } else { text.textColor = themeColor(tag == "theme.accent" ? .accentText : (tag == "theme.secondary" ? .secondaryText : .primaryText)) }
            }
            if let text = view as? NSTextView { text.textColor = themeColor(.primaryText) }
            if let collection = view as? NSCollectionView { collection.backgroundColors = [themeColor(.panel)] }
            if let table = view as? NSTableView { table.backgroundColor = themeColor(.panel) }
            if tag == "theme.panel" || tag == "theme.videoBackground" || view is NSSplitView {
                view.wantsLayer = true; view.layer?.borderWidth = 0; view.layer?.borderColor = themeColor(.marker).cgColor
            }
            view.needsDisplay = true
            for child in view.subviews { visit(child) }
        }
        if let root = window.contentView { visit(root) }
        if let root = queuedWindow?.contentView { visit(root) }
        for case let card as MediaCard in media.visibleItems() { card.updateSelection() }
        table.enumerateAvailableRowViews { row, _ in row.needsDisplay = true }
        timeline.needsDisplay = true; progress.needsDisplay = true
    }
    func queueViewButton() -> NSButton {
        let button = NSButton(title: "View Queued Clips", target: self, action: #selector(showQueuedClips)); button.bezelStyle = .rounded
        return button
    }
    func prepareQueueWindow() {
        let list = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 360), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        list.title = "Queued Clips"; list.minSize = NSSize(width: 500, height: 240); list.isReleasedWhenClosed = false; list.appearance = NSAppearance(named: .darkAqua)
        queuedWindow = list
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip")); col.title = "Queued clips"; col.width = 620; table.addTableColumn(col)
        table.headerView = nil; table.rowHeight = 28; table.backgroundColor = panelColor; table.style = .plain
        table.dataSource = self; table.delegate = self; table.target = self; table.doubleAction = #selector(loadClip)
        scroll.documentView = table
        queuedSource.font = .systemFont(ofSize: 12, weight: .semibold); queuedSource.lineBreakMode = .byTruncatingMiddle
        let hint = NSTextField(labelWithString: "Double-click a clip to load its markers for editing."); hint.font = .systemFont(ofSize: 11); hint.identifier = NSUserInterfaceItemIdentifier("theme.secondary")
        let body = column([queuedSource, scroll, hint], spacing: 10); let shell = panel(body)
        shell.translatesAutoresizingMaskIntoConstraints = false; list.contentView!.addSubview(shell)
        NSLayoutConstraint.activate([shell.leadingAnchor.constraint(equalTo: list.contentView!.leadingAnchor), shell.trailingAnchor.constraint(equalTo: list.contentView!.trailingAnchor), shell.topAnchor.constraint(equalTo: list.contentView!.topAnchor), shell.bottomAnchor.constraint(equalTo: list.contentView!.bottomAnchor)])
        for v in body.arrangedSubviews { v.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true }
    }
    @objc func showQueuedClips() {
        queuedSource.stringValue = "\(source?.lastPathComponent ?? "No imported video") · \(clips.count) queued clips"
        queuedWindow?.title = "Queued Clips (\(clips.count))"; table.reloadData()
        if queuedWindow?.isVisible != true { queuedWindow?.center() }
        queuedWindow?.makeKeyAndOrderFront(nil); applyTheme()
    }
    func resizeTimeline(scrollToTop: Bool = true) {
        guard !updatingTimelineViewport else { return }; updatingTimelineViewport = true
        defer { updatingTimelineViewport = false }
        window.contentView?.layoutSubtreeIfNeeded()
        let viewport = timelineScroll.contentSize
        guard viewport.width > 0, viewport.height > 0 else { return }
        let topOffset = max(0, timeline.frame.height - timeline.visibleRect.maxY)
        let plan = timelineViewportPlan(requiredHeight: Double(timeline.requiredHeight), viewportHeight: Double(viewport.height), topOffset: scrollToTop ? 0 : Double(topOffset), dragging: timelineDividerDragging)
        if timelineScroll.hasVerticalScroller != plan.showsScrollbar { timelineScroll.hasVerticalScroller = plan.showsScrollbar }
        let height = CGFloat(plan.documentHeight)
        if abs(timeline.frame.width - viewport.width) > 0.01 || abs(timeline.frame.height - height) > 0.01 {
            timeline.setFrameSize(NSSize(width: viewport.width, height: height))
        }
        timelineScroll.contentView.scroll(to: NSPoint(x: 0, y: CGFloat(plan.offsetY))); timelineScroll.reflectScrolledClipView(timelineScroll.contentView)
    }
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if splitView === editorSplit { return 320 }
        return splitView === workspaceSplit ? 210 : 340
    }
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if splitView === editorSplit { return max(320, splitView.bounds.height - 150 - splitView.dividerThickness) }
        return splitView === workspaceSplit ? max(210, splitView.bounds.width - 530) : max(340, splitView.bounds.width - 180)
    }
    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        guard splitView.subviews.count == 2 else { return }
        let width = splitView.bounds.width, height = splitView.bounds.height
        if splitView === editorSplit {
            let lower = min(max(150, splitView.subviews[1].frame.height), max(150, height - 320 - splitView.dividerThickness))
            let upper = max(0, height - lower - splitView.dividerThickness)
            splitView.subviews[0].frame = NSRect(x: 0, y: 0, width: width, height: upper)
            splitView.subviews[1].frame = NSRect(x: 0, y: upper + splitView.dividerThickness, width: width, height: lower)
            return
        }
        let left: CGFloat
        if splitView === workspaceSplit {
            left = min(max(210, splitView.subviews[0].frame.width), max(210, width - 530))
        } else {
            let right = min(max(180, splitView.subviews[1].frame.width), max(180, width - 340 - splitView.dividerThickness))
            left = max(0, width - right - splitView.dividerThickness)
        }
        splitView.subviews[0].frame = NSRect(x: 0, y: 0, width: left, height: height)
        splitView.subviews[1].frame = NSRect(x: left + splitView.dividerThickness, y: 0, width: max(0, width - left - splitView.dividerThickness), height: height)
    }
    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard (notification.object as? NSSplitView) === editorSplit else { return }
        guard !timelineResizeScheduled else { return }; timelineResizeScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }; self.timelineResizeScheduled = false; self.resizeTimeline(scrollToTop: false)
        }
    }
    @objc func showSortMenu(_ sender: NSButton) {
        guard !exporting else { return }
        let menu = NSMenu(); menu.autoenablesItems = false
        let heading = NSMenuItem(title: "Sort by…", action: nil, keyEquivalent: ""); heading.isEnabled = false; menu.addItem(heading)
        for key in MediaSort.allCases {
            let item = NSMenuItem(title: key.title, action: #selector(chooseSort(_:)), keyEquivalent: "")
            item.target = self; item.tag = key.rawValue; item.state = key == sortKey ? .on : .off; menu.addItem(item)
        }
        menu.addItem(.separator())
        for (title, descending) in [("Ascending", false), ("Descending", true)] {
            let item = NSMenuItem(title: title, action: #selector(chooseSortOrder(_:)), keyEquivalent: "")
            item.target = self; item.tag = descending ? 1 : 0; item.state = descending == sortDescending ? .on : .off; menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
    }
    @objc func chooseSort(_ sender: NSMenuItem) { sortKey = MediaSort(rawValue: sender.tag) ?? .name; sortGallery() }
    @objc func chooseSortOrder(_ sender: NSMenuItem) { sortDescending = sender.tag == 1; sortGallery() }
    func sortGallery() {
        sorting = true; sortGeneration += 1
        let generation = sortGeneration, files = mediaFiles, information = mediaInformation
        let key = sortKey, descending = sortDescending
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let sorted = sortedMediaFiles(files, info: information, by: key, descending: descending)
            DispatchQueue.main.async {
                guard let self = self, self.sortGeneration == generation else { return }
                self.sorting = false; self.mediaFiles = sorted; self.media.reloadData(); self.syncMediaSelection()
            }
        }
    }
    func mergeMedia(_ urls: [URL], title: String, note: String = "") {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var information: [URL: MediaFileInfo] = [:]
            for url in urls { if let value = try? readMediaFileInfo(url) { information[url] = value } }
            DispatchQueue.main.async {
                guard let self = self else { return }; self.scanning = false
                let newFiles = Array(Set(urls).subtracting(Set(self.mediaFiles)))
                self.mediaFiles = Array(Set(self.mediaFiles + urls))
                self.thumbnails.prepare(newFiles)
                self.mediaInformation.merge(information) { _, new in new }
                self.mediaFolder.stringValue = title; self.mediaFolder.toolTip = title
                self.mediaCount.stringValue = "\(self.mediaFiles.count) MP4s Ready" + note
                self.sortGallery()
            }
        }
    }
    @objc func loadFiles() {
        guard !exporting, !loading, !scanning else { return }
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.mpeg4Movie]; panel.prompt = "Load Files"
        let preference = "TrimWasp.HideLoadFilesHelp"
        let checkbox = NSButton(checkboxWithTitle: "Do not show this message again", target: nil, action: nil)
        if !UserDefaults.standard.bool(forKey: preference) {
            panel.message = "You can select individual files to load, or you can select a folder and load all MP4s inside."
            panel.accessoryView = checkbox
        }
        let result = panel.runModal()
        if checkbox.state == .on { UserDefaults.standard.set(true, forKey: preference) }
        guard result == .OK else { return }
        let selections = panel.urls
        scanning = true; mediaCount.stringValue = "Preparing files…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let scan = collectMP4Selections(selections)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.mergeMedia(scan.files, title: "Loaded files and folders", note: scan.unreadableEntries > 0 ? " · some entries unreadable" : "")
                if scan.files.isEmpty { self.alert("No MP4 files found", "The selected files and folders contain no readable MP4 videos.") }
            }
        }
    }
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { mediaFiles.count }
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("media"), for: indexPath) as! MediaCard
        let url = mediaFiles[indexPath.item]; item.configure(url, image: thumbnails.image(for: url)); return item
    }
    func collectionView(_ collectionView: NSCollectionView, shouldSelectItemsAt indexPaths: Set<IndexPath>) -> Set<IndexPath> {
        return exporting || loading || sorting ? [] : indexPaths
    }
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard !exporting, !loading, !sorting, let path = indexPaths.first, mediaFiles.indices.contains(path.item) else { return }
        previewMedia(mediaFiles[path.item])
    }
    func syncMediaSelection() {
        if let selected = selectedMedia, let i = mediaFiles.firstIndex(of: selected.standardizedFileURL) { media.selectionIndexPaths = [IndexPath(item: i, section: 0)] }
        else { media.selectionIndexPaths = [] }
    }
    func updateControlAvailability() {
        for control in controls { control.isEnabled = !exporting && !loading }
        let ready = asset != nil && !previewingSelection && !exporting && !loading
        for control in sourceControls { control.isEnabled = ready }
        timeline.editingEnabled = ready
        importVideoButton.isEnabled = selectedMedia != nil && !exporting && !loading
        cancelExportButton.isEnabled = exporting && !cancelled
    }
    func previewMedia(_ url: URL) {
        guard !exporting, !loading else { return }
        selectedMedia = url.standardizedFileURL; pendingRestoredClips = nil; previewingSelection = true
        player.pause(); pendingSeek = nil
        video.isHidden = true; thumbnailPreview.isHidden = false
        thumbnailPreview.image = thumbnails.image(for: url)
        emptyPlayer.isHidden = thumbnailPreview.image != nil; emptyPlayer.stringValue = "Preparing thumbnail…"
        playerTitle.stringValue = url.lastPathComponent; window.title = "TrimWasp — \(url.lastPathComponent) (Preview)"
        status.stringValue = "Click Import Video to load the selected video for clipping."
        detailsText.string = "Reading details…"
        updateControlAvailability(); syncMediaSelection(); thumbnails.request(url, priority: true)
        if thumbnailPreview.image == nil, !thumbnails.isPending(url) { emptyPlayer.stringValue = "Thumbnail unavailable — Import Video to open" }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let text = fileDetails(url)
            DispatchQueue.main.async {
                guard let self = self, self.selectedMedia == url.standardizedFileURL else { return }
                self.detailsText.string = text; self.detailsText.scrollToBeginningOfDocument(nil)
            }
        }
    }
    @objc func importSelectedVideo() {
        guard let url = selectedMedia, !exporting, !loading else { return }
        if url == source?.standardizedFileURL, pendingRestoredClips == nil, asset != nil {
            previewingSelection = false; video.isHidden = false; thumbnailPreview.isHidden = true; emptyPlayer.isHidden = true
            window.title = "TrimWasp — \(url.lastPathComponent)"; updateControlAvailability()
            status.stringValue = "Video imported. Press M or double-click the timeline to mark a clip."; return
        }
        guard confirmDiscard() else { return }
        load(url, restored: pendingRestoredClips ?? [])
    }
    var minimumClip: Double { min(duration, 1 / max(1, fps)) }
    func alert(_ title: String, _ message: String) { let a = NSAlert(); a.messageText = title; a.informativeText = message; a.runModal() }
    func confirmDiscard() -> Bool {
        let editedRange = timeline.selection.bounds
        let unconfirmed = editingClipIndex.map { i in clips.indices.contains(i) && editedRange.map { abs($0.start - clips[i].start) > 0.000001 || abs($0.end - clips[i].end) > 0.000001 } == true } ?? false
        guard dirty || unconfirmed else { return true }
        let a = NSAlert(); a.messageText = "Discard unsaved clip list?"; a.informativeText = "Save the clip list from the File menu if you want to keep editing it later. Exported videos are already saved."; a.addButton(withTitle: "Discard"); a.addButton(withTitle: "Cancel")
        return a.runModal() == .alertFirstButtonReturn
    }
    @objc func about() { alert(appDisplayName, "A small native video clipper. Uses AppKit, AVKit and AVFoundation. No network access, media uploads or third-party runtime. macOS 13 or newer.") }
    func load(_ url: URL, restored: [Clip] = []) {
        filmstripGenerator.cancel()
        player.pause(); pendingSeek = nil; loading = true; updateControlAvailability(); status.stringValue = "Opening \(url.lastPathComponent)…"
        let candidate = AVURLAsset(url: url)
        candidate.loadValuesAsynchronously(forKeys: ["duration", "tracks", "playable"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }; self.loading = false
                defer { self.updateControlAvailability() }
                var error: NSError?
                for key in ["duration", "tracks", "playable"] {
                    guard candidate.statusOfValue(forKey: key, error: &error) == .loaded else {
                        self.syncMediaSelection(); self.status.stringValue = "Could not open video."; self.alert("Cannot open video", error?.localizedDescription ?? "Video information could not be loaded."); return
                    }
                }
                let d = candidate.duration.seconds
                guard candidate.isPlayable, d.isFinite, d > 0, let track = candidate.tracks(withMediaType: .video).first else {
                    self.syncMediaSelection(); self.alert("Unsupported video", "Select a playable video with a finite duration."); return
                }
                self.asset = candidate; self.source = url; self.duration = d; self.fps = max(1, Double(track.nominalFrameRate))
                let item = AVPlayerItem(asset: candidate); item.audioTimePitchAlgorithm = .spectral
                self.player.replaceCurrentItem(with: item)
                self.timeline.fallbackThumbnail = self.thumbnails.image(for: url)
                self.timeline.filmstrip = Array(repeating: nil, count: TimelineFilmstrip.frameCount)
                self.filmstripGenerator.prepare(candidate, duration: d) { [weak self] index, image in
                    guard let self = self, self.asset === candidate, self.timeline.filmstrip.indices.contains(index) else { return }
                    self.timeline.filmstrip[index] = image; self.timeline.needsDisplay = true
                }
                self.selectedMedia = url.standardizedFileURL; self.previewingSelection = false; self.pendingRestoredClips = nil
                self.video.isHidden = false; self.thumbnailPreview.isHidden = true
                self.emptyPlayer.isHidden = true; self.playerTitle.stringValue = url.lastPathComponent
                self.syncMediaSelection()
                self.editingClipIndex = nil
                self.clips = restored.filter { $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.end <= d + 0.001 && $0.end - $0.start >= self.minimumClip - 0.001 }.map { Clip(start: $0.start, end: min(d, $0.end)) }
                self.dirty = false; self.timeline.duration = d; self.timeline.current = 0; self.timeline.selection.clear()
                self.refreshMarks(); self.refreshList(); self.window.title = "TrimWasp — \(url.lastPathComponent)"
                self.status.stringValue = "\(url.lastPathComponent) • \(Int(abs(track.naturalSize.width)))×\(Int(abs(track.naturalSize.height))) • \(String(format: "%.2f", self.fps)) fps • \(stamp(d))"
                if self.clips.count != restored.count { self.alert("Some ranges were skipped", "The clip list contained ranges outside this video's duration.") }
            }
        }
    }
    func updatePlaySymbol() {
        let playing = player.rate != 0
        playButton.image = NSImage(systemSymbolName: playing ? "pause.fill" : "play.fill", accessibilityDescription: playing ? "Pause" : "Play")
        playButton.toolTip = playing ? "Pause (Space)" : "Play (Space)"
        playButton.setAccessibilityLabel(playing ? "Pause" : "Play")
    }
    @objc func changePlaybackSpeed() {
        guard let rate = parsePlaybackSpeed(speedBox.stringValue) else {
            speedBox.stringValue = String(format: "%g×", playbackSpeed)
            status.stringValue = "Enter a playback speed from 0.1× to 8×."; return
        }
        playbackSpeed = rate; speedBox.stringValue = String(format: "%g×", rate)
        if player.rate != 0 { player.rate = rate }
    }
    func comboBoxSelectionDidChange(_ notification: Notification) {
        if let selected = speedBox.objectValueOfSelectedItem as? String { speedBox.stringValue = selected }
        changePlaybackSpeed()
    }
    func comboBoxDidDismiss(_ notification: Notification) { window.makeFirstResponder(video) }
    @objc func playPause() {
        guard asset != nil, !previewingSelection, !loading, !exporting else { return }
        if player.rate != 0 { player.pause() }
        else {
            if player.currentTime().seconds >= duration - minimumClip / 2 { seek(0, exact: true) }
            player.playImmediately(atRate: playbackSpeed)
        }
    }
    @objc func previousFrame() { step(-1) }
    @objc func nextFrame() { step(1) }
    func step(_ direction: Int) { guard asset != nil, !previewingSelection, !exporting, !loading else { return }; player.pause(); player.currentItem?.step(byCount: direction) }
    func seek(_ time: Double, exact: Bool) {
        guard asset != nil, !previewingSelection, !loading, !exporting else { return }
        player.pause(); timeline.current = min(duration, max(0, time)); timeline.needsDisplay = true
        pendingSeek = (timeline.current, exact); drainSeek()
    }
    func drainSeek() {
        guard !seekBusy, let request = pendingSeek else { return }
        pendingSeek = nil; seekBusy = true
        let tolerance = request.1 ? CMTime.zero : CMTime(seconds: 0.05, preferredTimescale: 60000)
        player.seek(to: CMTime(seconds: request.0, preferredTimescale: 60000), toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
            DispatchQueue.main.async { guard let self = self else { return }; self.seekBusy = false; self.drainSeek() }
        }
    }
    @objc func mark() {
        guard asset != nil, !previewingSelection, !exporting, !loading else { return }
        placeMarker(seekBusy ? timeline.current : min(duration, max(0, player.currentTime().seconds)))
    }
    func placeMarker(_ time: Double) {
        guard asset != nil, !previewingSelection, !exporting, !loading else { return }
        if editingClipIndex != nil { status.stringValue = "Editing existing clip length"; return }
        guard timeline.selection.add(time, duration: duration) else {
            status.stringValue = "Two markers are already placed. Drag either to adjust, then Add Clip [A]."; return
        }
        refreshMarks()
        status.stringValue = timeline.selection.points.count == 1 ? "Marker 1 of 2 placed. Press M or double-click for the second marker." : "Two markers placed. Add Clip [A] to queue the range and clear the markers."
    }
    func refreshMarks() {
        let ordered = timeline.selection.ordered
        inField.stringValue = ordered.first.map(stamp) ?? ""
        outField.stringValue = ordered.count == 2 ? stamp(ordered[1]) : ""
        clipActionButton.title = editingClipIndex == nil ? "Add Clip [A]" : "Update Clip"
        refreshTimelinePreview()
    }
    func controlTextDidEndEditing(_ obj: Notification) {
        if (obj.object as? NSComboBox) === speedBox { changePlaybackSpeed() }
        else { _ = readFields() }
    }
    @discardableResult func readFields() -> Bool {
        guard asset != nil, !previewingSelection, !loading, !exporting else { return false }
        guard let a = parseTime(inField.stringValue), let b = parseTime(outField.stringValue),
              a >= 0, b >= 0, max(a,b) <= duration + 0.0006, abs(b-a) >= minimumClip - 0.0006,
              timeline.selection.set([min(duration,a), min(duration,b)], duration: duration) else {
            refreshMarks(); status.stringValue = editingClipIndex == nil ? "Place two markers at least one frame apart using M or a timeline double-click." : "Editing existing clip length — markers must be at least one frame apart."; return false
        }
        refreshMarks(); return true
    }
    @objc func addClip() {
        guard asset != nil, !previewingSelection, !exporting, !loading, readFields(), let range = timeline.selection.bounds else { return }
        let edited = editingClipIndex
        if let i = edited, clips.indices.contains(i) { clips[i] = Clip(start: range.start, end: range.end) }
        else { clips.append(Clip(start: range.start, end: range.end)) }
        dirty = true; editingClipIndex = nil; timeline.selection.clear(); refreshMarks(); refreshList()
        let row = edited ?? (clips.count - 1)
        if clips.indices.contains(row) { table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
        window.makeFirstResponder(timeline)
        status.stringValue = edited == nil ? "Clip added. Mark the next range with M or double-click the timeline." : "Clip updated. Markers cleared."
    }
    @objc func removeClip() {
        let i = table.selectedRow; guard !previewingSelection, !exporting, !loading, clips.indices.contains(i) else { return }
        clips.remove(at: i)
        if let edited = editingClipIndex {
            if edited == i { editingClipIndex = nil; timeline.selection.clear() }
            else if edited > i { editingClipIndex = edited - 1 }
        }
        dirty = true; refreshMarks(); refreshList()
        status.stringValue = editingClipIndex == nil ? "Clip removed." : "Editing existing clip length"
    }
    @objc func loadClip() {
        let i = table.clickedRow >= 0 ? table.clickedRow : table.selectedRow
        editClip(at: i)
    }
    func editClip(at i: Int) {
        guard !previewingSelection, !exporting, !loading, clips.indices.contains(i) else { return }
        table.selectRowIndexes(IndexSet(integer: i), byExtendingSelection: false)
        guard timeline.selection.set([clips[i].start, clips[i].end], duration: duration) else { return }
        editingClipIndex = i; refreshMarks(); seek(clips[i].start, exact: true)
        status.stringValue = "Editing existing clip length"
        window.makeKeyAndOrderFront(nil); window.makeFirstResponder(timeline)
    }
    func refreshTimelinePreview() {
        timeline.clips = clipPreview(clips, editingIndex: editingClipIndex, selection: timeline.selection); resizeTimeline(scrollToTop: false); timeline.needsDisplay = true
    }
    func refreshList() {
        detailQueue.stringValue = "Pending Clips: \(clips.count)"; refreshTimelinePreview(); resizeTimeline(); table.reloadData()
        queuedSource.stringValue = "\(source?.lastPathComponent ?? "No imported video") · \(clips.count) queued clips"
        queuedWindow?.title = "Queued Clips (\(clips.count))"
    }
    func numberOfRows(in tableView: NSTableView) -> Int { clips.count }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { ClipRow() }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let c = clips[row]; let label = NSTextField(labelWithString: String(format: "%03d", row + 1) + "    " + stamp(c.start) + "  →  " + stamp(c.end) + "    (" + stamp(c.end - c.start) + ")")
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular); label.textColor = themeColor(.primaryText); return label
    }
    @objc func saveProject() {
        guard let source = source, !exporting, !loading else { return }
        guard editingClipIndex == nil else { status.stringValue = "Click Update Clip to confirm the edit before saving the clip list."; return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = source.deletingPathExtension().lastPathComponent + "-clips.json"
        if panel.runModal() == .OK, let url = panel.url {
            do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try encoder.encode(Project(sourcePath: source.path, clips: clips)).write(to: url, options: .atomic); dirty = false; status.stringValue = "Clip list saved." }
            catch { alert("Save failed", error.localizedDescription) }
        }
    }
    @objc func openProject() {
        guard !exporting, !loading else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let project = try JSONDecoder().decode(Project.self, from: Data(contentsOf: url))
            guard project.version == 1 else { alert("Unsupported clip list", "This clip list uses a newer format."); return }
            var videoURL = URL(fileURLWithPath: project.sourcePath)
            if !FileManager.default.fileExists(atPath: videoURL.path) {
                let locate = NSOpenPanel(); locate.message = "Locate the original video: \(videoURL.lastPathComponent)"; locate.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
                guard locate.runModal() == .OK, let replacement = locate.url else { return }; videoURL = replacement
            }
            let normalized = videoURL.standardizedFileURL
            mergeMedia([normalized], title: normalized.deletingLastPathComponent().path)
            previewMedia(normalized); pendingRestoredClips = project.clips
            status.stringValue = "Clip list selected. Click Import Video to restore it."
        } catch { alert("Cannot open clip list", error.localizedDescription) }
    }
    @objc func exportAll() {
        guard editingClipIndex == nil else { status.stringValue = "Click Update Clip to confirm the edit before exporting."; return }
        guard !previewingSelection, !exporting, !loading, asset != nil, !clips.isEmpty else { if clips.isEmpty { status.stringValue = "Add at least one clip before exporting." }; return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true; panel.prompt = "Export Here"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        do {
            guard let source = source else { return }
            let baseName = "TrimWasp-Clips-" + source.deletingPathExtension().lastPathComponent
            var destination = folder.appendingPathComponent(baseName, isDirectory: true)
            var suffix = 2
            while FileManager.default.fileExists(atPath: destination.path) {
                destination = folder.appendingPathComponent("\(baseName) (\(suffix))", isDirectory: true)
                suffix += 1
            }
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            player.pause(); exporting = true; cancelled = false; cancelExportButton.isEnabled = true; finished = 0; failures = []; progress.doubleValue = 0
            thumbnails.suspend(true); updateControlAvailability()
            exportNext(index: 0, folder: destination, format: mode.indexOfSelectedItem)
        } catch { alert("Cannot create export folder", error.localizedDescription) }
    }
    func exportNext(index: Int, folder: URL, format: Int) {
        guard !cancelled, index < clips.count, let asset = asset else { finishBatch(folder); return }
        let clip = clips[index]
        let precise = format == 2
        let preset = precise ? AVAssetExportPresetHighestQuality : AVAssetExportPresetPassthrough
        guard let job = AVAssetExportSession(asset: asset, presetName: preset) else { failures.append("Clip \(index + 1): export mode unavailable."); exportNext(index: index + 1, folder: folder, format: format); return }
        let fileType: AVFileType = format == 0 ? .mov : .mp4
        guard job.supportedFileTypes.contains(fileType) else { failures.append("Clip \(index + 1): selected format unsupported; try Fast MOV or Precise Re-Encode."); exportNext(index: index + 1, folder: folder, format: format); return }
        let stem = source!.deletingPathExtension().lastPathComponent
        let output = folder.appendingPathComponent("TrimWasp-Clip-\(index + 1)-\(stem)").appendingPathExtension(format == 0 ? "mov" : "mp4")
        session = job; job.outputURL = output; job.outputFileType = fileType
        job.timeRange = CMTimeRange(start: CMTime(seconds: clip.start, preferredTimescale: 60000), end: CMTime(seconds: clip.end, preferredTimescale: 60000))
        job.shouldOptimizeForNetworkUse = false
        status.stringValue = "Exporting \(index + 1) of \(clips.count)…"
        exportTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self, weak job] _ in
            guard let self = self else { return }; self.progress.doubleValue = (Double(index) + Double(job?.progress ?? 0)) / Double(max(1, self.clips.count))
        }
        job.exportAsynchronously { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }; self.exportTimer?.invalidate(); self.exportTimer = nil; self.session = nil
                if job.status == .completed { self.finished += 1 }
                else {
                    try? FileManager.default.removeItem(at: output)
                    if job.status != .cancelled { self.failures.append("Clip \(index + 1): \(job.error?.localizedDescription ?? "Export failed")") }
                }
                self.exportNext(index: index + 1, folder: folder, format: format)
            }
        }
    }
    @objc func cancelExport() { guard exporting, !cancelled else { return }; cancelExportButton.isEnabled = false; cancelled = true; session?.cancelExport(); status.stringValue = "Cancelling…" }
    func finishBatch(_ folder: URL) {
        exporting = false; cancelExportButton.isEnabled = false; thumbnails.suspend(false); updateControlAvailability()
        progress.doubleValue = cancelled ? Double(finished) / Double(max(1, clips.count)) : 1
        status.stringValue = "\(cancelled ? "Cancelled" : "Finished"): \(finished) saved, \(failures.count) failed."
        if !failures.isEmpty { alert("Some clips could not be exported", failures.joined(separator: "\n") + "\n\nTry Fast MOV or Precise Re-Encode if Fast MP4 is unsupported. Completed clips were kept.") }
        if finished > 0 { NSWorkspace.shared.open(folder) }
    }
}
let application = NSApplication.shared
let delegate = App()
application.setActivationPolicy(.regular)
application.delegate = delegate
application.run()
