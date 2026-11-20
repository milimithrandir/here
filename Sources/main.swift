import AppKit
import SwiftUI

// MARK: - Overlay window

final class ClickHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class OverlayPanel: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class MomentState: ObservableObject { @Published var leaving = false }

struct MomentRoot: View {
    @ObservedObject var state: MomentState
    let content: AnyView
    var body: some View {
        content
            .opacity(state.leaving ? 0 : 1)
            .scaleEffect(state.leaving ? 1.03 : 1)
            .animation(.easeOut(duration: 0.9), value: state.leaving)
    }
}

final class OverlayManager {
    private var panel: OverlayPanel?
    private var state: MomentState?
    private var motionTimer: Timer?
    private var timeout: Timer?
    private var recent: [Kind] = []
    var onNoticed: (() -> Void)?
    var isShowing: Bool { panel != nil }

    private func pickKind() -> Kind {
        let pool = Kind.allCases.filter { !recent.contains($0) }
        let total = pool.reduce(0) { $0 + $1.weight }
        var r = Double.random(in: 0..<total)
        for k in pool { r -= k.weight; if r < 0 { return k } }
        return pool.last!
    }

    func show(_ forced: Kind? = nil) {
        guard panel == nil else { return }
        let kind = forced ?? pickKind()
        recent.append(kind)
        if recent.count > 5 { recent.removeFirst() }

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main!
        let frame = screen.frame
        let ctx = Ctx.make(kind: kind, frame: frame)
        let st = MomentState()
        let content = momentView(kind, ctx)
        let tap: () -> Void = { [weak self] in self?.finish(noticed: true) }

        let root: AnyView
        let pframe: NSRect
        let floatSize: CGFloat = 150
        if kind.floating {
            pframe = NSRect(x: 0, y: 0, width: floatSize, height: floatSize)
            root = AnyView(MomentRoot(state: st, content: AnyView(
                content.frame(width: floatSize, height: floatSize)
                    .contentShape(Circle())
                    .onTapGesture(perform: tap))))
        } else {
            pframe = frame
            root = AnyView(MomentRoot(state: st, content: AnyView(
                ZStack { Color.black.opacity(0.012); content }
                    .frame(width: frame.width, height: frame.height)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: tap))))
        }

        let p = OverlayPanel(frame: pframe)
        p.contentView = ClickHostingView(rootView: root)
        panel = p
        state = st

        if let motion = momentMotion(kind) {
            let place = {
                let c = motion(ctx, Date().timeIntervalSince(ctx.start))
                p.setFrameOrigin(NSPoint(x: frame.minX + c.x - floatSize / 2,
                                         y: frame.maxY - c.y - floatSize / 2))
            }
            place()
            let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { _ in place() }
            RunLoop.main.add(timer, forMode: .common)
            motionTimer = timer
        }

        p.orderFrontRegardless()
        timeout = Timer.scheduledTimer(withTimeInterval: 180, repeats: false) { [weak self] _ in
            self?.finish(noticed: false)
        }
    }

    func finish(noticed: Bool) {
        guard let p = panel, let st = state, !st.leaving else { return }
        st.leaving = true
        timeout?.invalidate()
        if noticed { onNoticed?() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.motionTimer?.invalidate()
            self?.motionTimer = nil
            p.orderOut(nil)
            p.close()
            self?.panel = nil
            self?.state = nil
        }
    }
}

// MARK: - Scheduler

final class Scheduler {
    private(set) var next = Date().addingTimeInterval(Scheduler.gap())
    var pausedUntil: Date?
    var onFire: (() -> Void)?
    var isBusy: () -> Bool = { false }
    private var timer: Timer?

    /// 8–44 min, peaked around ~26 min. Never the same twice.
    static func gap() -> TimeInterval {
        (8 + Double.random(in: 0...18) + Double.random(in: 0...18)) * 60
    }

    func start() {
        let t = Timer(timeInterval: 20, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func reschedule() { next = Date().addingTimeInterval(Scheduler.gap()) }

    private func tick() {
        let now = Date()
        if let p = pausedUntil {
            if now < p { return }
            pausedUntil = nil
            reschedule()
            return
        }
        guard now >= next, !isBusy() else { return }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                           eventType: CGEventType(rawValue: UInt32.max)!)
        if idle > 90 || Scheduler.screenLocked() {
            // You're away: catch you a little while after you come back.
            next = now.addingTimeInterval(Double.random(in: 60...240))
            return
        }
        onFire?()
        reschedule()
    }

    static func screenLocked() -> Bool {
        guard let d = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (d["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var status: NSStatusItem!
    private let scheduler = Scheduler()
    private let overlay = OverlayManager()
    private let countItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at login", action: #selector(toggleLogin), keyEquivalent: "")
    private let defaults = UserDefaults.standard

    private var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/fun.here.awareness.plist")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let img = NSImage(systemSymbolName: "circle.dotted", accessibilityDescription: "Here")
        img?.isTemplate = true
        status.button?.image = img

        let menu = NSMenu()
        menu.delegate = self
        countItem.isEnabled = false
        menu.addItem(countItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "A moment now", action: #selector(showNow), keyEquivalent: "").target = self

        let preview = NSMenu()
        for k in Kind.allCases {
            let it = NSMenuItem(title: k.title, action: #selector(showKind(_:)), keyEquivalent: "")
            it.representedObject = k.rawValue
            it.target = self
            preview.addItem(it)
        }
        let previewItem = NSMenuItem(title: "Try a specific moment", action: nil, keyEquivalent: "")
        previewItem.submenu = preview
        menu.addItem(previewItem)
        menu.addItem(.separator())

        pauseItem.target = self
        pauseItem.action = #selector(togglePause)
        menu.addItem(pauseItem)
        menu.addItem(withTitle: "Pause until tomorrow", action: #selector(pauseTomorrow), keyEquivalent: "").target = self
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(withTitle: "Quit Here", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu

        overlay.onNoticed = { [weak self] in self?.recordNoticed() }
        scheduler.isBusy = { [weak self] in self?.overlay.isShowing ?? false }
        scheduler.onFire = { [weak self] in self?.overlay.show() }
        scheduler.start()

        if CommandLine.arguments.contains("--now") { overlay.show() }
    }

    func menuWillOpen(_ menu: NSMenu) {
        rollDay()
        let today = defaults.integer(forKey: "today"), total = defaults.integer(forKey: "total")
        countItem.title = "Awake \(today)× today  ·  \(total) in all"
        if let p = scheduler.pausedUntil, p > Date() {
            let f = DateFormatter(); f.timeStyle = .short
            pauseItem.title = "Paused until \(f.string(from: p)) — resume"
        } else {
            pauseItem.title = "Pause for an hour"
        }
        loginItem.state = FileManager.default.fileExists(atPath: agentURL.path) ? .on : .off
    }

    private func rollDay() {
        let day = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        if defaults.double(forKey: "day") != day {
            defaults.set(day, forKey: "day")
            defaults.set(0, forKey: "today")
        }
    }

    private func recordNoticed() {
        rollDay()
        defaults.set(defaults.integer(forKey: "today") + 1, forKey: "today")
        defaults.set(defaults.integer(forKey: "total") + 1, forKey: "total")
    }

    @objc private func showNow() { overlay.show() }

    @objc private func showKind(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let k = Kind(rawValue: raw) { overlay.show(k) }
    }

    @objc private func togglePause() {
        if let p = scheduler.pausedUntil, p > Date() {
            scheduler.pausedUntil = nil
            scheduler.reschedule()
        } else {
            scheduler.pausedUntil = Date().addingTimeInterval(3600)
        }
    }

    @objc private func pauseTomorrow() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        scheduler.pausedUntil = cal.date(byAdding: .hour, value: 7, to: tomorrow)
    }

    @objc private func toggleLogin() {
        let fm = FileManager.default
        if fm.fileExists(atPath: agentURL.path) {
            try? fm.removeItem(at: agentURL)
            return
        }
        guard let exe = Bundle.main.executablePath else { return }
        let plist: [String: Any] = [
            "Label": "fun.here.awareness",
            "ProgramArguments": [exe],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
        ]
        try? fm.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        (plist as NSDictionary).write(to: agentURL, atomically: true)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
