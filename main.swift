import Cocoa

// Claude usage menu bar app. Pure ASCII source; Chinese via \u{} escapes.
// Data from usage_helper.py (official /usage endpoint, with per-model cache).

let refreshInterval: TimeInterval = 5 * 60
let staleThreshold = 600   // 秒；超過才標「快取」

// ---- Chinese labels ----
let T_TITLE   = "Claude \u{7528}\u{91CF}"
let T_5H      = "5 \u{5C0F}\u{6642}\u{7528}\u{91CF}"
let T_7D_ALL  = "\u{9031}\u{7528}\u{91CF}\u{FF08}\u{6574}\u{9AD4}\u{FF09}"
let T_WEEK    = "\u{9031}\u{7528}\u{91CF}"
let T_RESET   = "\u{91CD}\u{7F6E}\u{FF1A}"
let T_REMAIN  = "\u{9084}\u{5269}"
let T_DAY     = "\u{5929}"
let T_HOUR    = "\u{5C0F}\u{6642}"
let T_MIN     = "\u{5206}"
let T_UPDATED = "\u{66F4}\u{65B0}\u{65BC} "
let T_REFRESH = "\u{7ACB}\u{5373}\u{91CD}\u{65B0}\u{6574}\u{7406}"
let T_QUIT    = "\u{7D50}\u{675F}"
let T_FAIL    = "\u{8B80}\u{53D6}\u{5931}\u{6557}"
let T_CACHE   = "\u{5FEB}\u{53D6}"
let T_AGO     = "\u{524D}"

struct ModelUsage { let name: String; let percent: Int; let resetsAt: String?; let staleSeconds: Int }

struct Usage {
    var fiveHour: Int?
    var sevenDay: Int?
    var models: [ModelUsage] = []
    var resets: [String: String] = [:]
    var ok: Bool = false
    var error: String?
}

func usageColor(_ v: Int) -> NSColor {
    if v >= 80 { return NSColor.systemRed }
    if v >= 50 { return NSColor.systemOrange }
    return NSColor.systemGreen
}

func writeRenderLog(_ s: String) {
    let path = NSString(string: "~/ClaudeUsage/last_render.log").expandingTildeInPath
    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let line = df.string(from: Date()) + " " + s + "\n"
    if let data = line.data(using: .utf8) {
        if let fh = FileHandle(forWritingAtPath: path) {
            fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

final class UsageRowView: NSView {
    let title: String
    let value: Int?
    let subLine: String?
    init(title: String, value: Int?, subLine: String?, width: CGFloat) {
        self.title = title; self.value = value; self.subLine = subLine
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: subLine == nil ? 44 : 58))
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let pad: CGFloat = 16
        let w = bounds.width
        let v = value ?? 0
        let color = usageColor(v)
        let titleY = bounds.height - 24
        (title as NSString).draw(at: NSPoint(x: pad, y: titleY), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor])
        let pctStr = value == nil ? "-" : "\(v)%"
        let pctAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: color]
        let pctSize = (pctStr as NSString).size(withAttributes: pctAttr)
        (pctStr as NSString).draw(at: NSPoint(x: w - pad - pctSize.width, y: titleY), withAttributes: pctAttr)
        let barH: CGFloat = 6
        let barY = titleY - 13
        let barW = w - pad * 2
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: pad, y: barY, width: barW, height: barH),
                     xRadius: barH/2, yRadius: barH/2).fill()
        let ratio = CGFloat(min(100, max(0, v))) / 100.0
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: pad, y: barY, width: max(barH, barW*ratio), height: barH),
                     xRadius: barH/2, yRadius: barH/2).fill()
        if let rl = subLine {
            (rl as NSString).draw(at: NSPoint(x: pad, y: barY - 19), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor])
        }
    }
}

final class HeaderView: NSView {
    let text: String
    init(text: String, width: CGFloat) {
        self.text = text
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 34))
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        (text as NSString).draw(at: NSPoint(x: 16, y: 9), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.labelColor])
    }
}

final class AppController: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    var timer: Timer?
    var lastUpdated: Date?
    let menuWidth: CGFloat = 260

    var helperPath: String {
        if let res = Bundle.main.resourcePath {
            let p = (res as NSString).appendingPathComponent("usage_helper.py")
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        return NSString(string: "~/ClaudeUsage/usage_helper.py").expandingTildeInPath
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let btn = statusItem.button {
            // Apple HIG: menu bar status icons are template SF Symbols, sized to the menu
            // bar font so they optically align with text and neighbouring system glyphs.
            let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            let img = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "Claude usage")?
                .withSymbolConfiguration(cfg)
            img?.isTemplate = true
            btn.image = img
            btn.imagePosition = .imageLeading
            btn.title = " ..."
        }
        statusItem.menu = menu
        writeRenderLog("LAUNCH")
        buildMenu(Usage())
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let usage = self.runHelper()
            DispatchQueue.main.async {
                self.lastUpdated = Date()
                self.render(usage)
            }
        }
    }

    func runHelper() -> Usage {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["python3", helperPath]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch {
            var u = Usage(); u.ok = false; u.error = "cannot start helper"; return u
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            var u = Usage(); u.ok = false; u.error = "no response from helper"; return u
        }
        var u = Usage()
        u.ok = (obj["ok"] as? Bool) ?? false
        if !u.ok { u.error = obj["error"] as? String ?? "unknown error"; return u }
        u.fiveHour = obj["five_hour"] as? Int
        u.sevenDay = obj["seven_day"] as? Int
        if let r = obj["resets"] as? [String: Any] {
            for (k, val) in r { if let s = val as? String { u.resets[k] = s } }
        }
        if let ms = obj["models"] as? [[String: Any]] {
            for m in ms {
                if let name = m["name"] as? String, let pct = m["percent"] as? Int {
                    u.models.append(ModelUsage(name: name, percent: pct,
                                               resetsAt: m["resets_at"] as? String,
                                               staleSeconds: (m["stale_seconds"] as? Int) ?? 0))
                }
            }
        }
        return u
    }

    func render(_ u: Usage) {
        if u.ok {
            let mstr = u.models.map { "\($0.name):\($0.percent)" }.joined(separator: ",")
            writeRenderLog("OK 5h=\(u.fiveHour ?? -1) 7d=\(u.sevenDay ?? -1) models=[\(mstr)]")
        } else {
            writeRenderLog("ERR " + (u.error ?? "unknown"))
        }
        if let btn = statusItem.button {
            if u.ok {
                var parts: [String] = []
                if let f = u.fiveHour { parts.append("5H \(f)%") }
                if let w = u.sevenDay { parts.append("W \(w)%") }
                if let fable = u.models.first(where: { $0.name == "Fable" }) {
                    parts.append("F \(fable.percent)%")
                }
                btn.title = " " + parts.joined(separator: " | ")
            } else {
                btn.title = " !"
            }
        }
        buildMenu(u)
    }

    func resetLine(_ iso: String?) -> String? {
        guard let iso = iso else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = fmt.date(from: iso)
        if date == nil {
            fmt.formatOptions = [.withInternetDateTime]
            date = fmt.date(from: iso)
        }
        guard let d = date else { return nil }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "Asia/Taipei")
        df.dateFormat = "M/d HH:mm"
        let when = df.string(from: d)
        let secs = d.timeIntervalSinceNow
        if secs <= 0 { return T_RESET + when }
        let h = Int(secs) / 3600
        var remain: String
        if h >= 24 { remain = "\(T_REMAIN) \(h/24) \(T_DAY)" }
        else if h > 0 { remain = "\(T_REMAIN) \(h) \(T_HOUR)" }
        else { remain = "\(T_REMAIN) \(Int(secs)/60) \(T_MIN)" }
        return "\(T_RESET)\(when)  \(remain)"
    }

    func staleNote(_ secs: Int) -> String {
        let mins = secs / 60
        let ago = mins >= 60 ? "\(mins/60) \(T_HOUR)" : "\(mins) \(T_MIN)"
        return "\u{FF08}\(T_CACHE) \(ago)\(T_AGO)\u{FF09}"   // （快取 X 分前）
    }

    func addRow(_ title: String, _ value: Int?, _ subLine: String?) {
        let item = NSMenuItem()
        item.view = UsageRowView(title: title, value: value, subLine: subLine, width: menuWidth)
        menu.addItem(item)
    }

    func addHeader(_ text: String) {
        let item = NSMenuItem()
        item.view = HeaderView(text: text, width: menuWidth)
        menu.addItem(item)
    }

    func buildMenu(_ u: Usage) {
        menu.removeAllItems()
        addHeader(T_TITLE)
        menu.addItem(NSMenuItem.separator())
        if !u.ok {
            let item = NSMenuItem(title: "  " + T_FAIL, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            if let e = u.error {
                let sub = NSMenuItem(title: "  " + e, action: nil, keyEquivalent: "")
                sub.isEnabled = false
                menu.addItem(sub)
            }
            menu.addItem(NSMenuItem.separator())
            addFooter()
            return
        }
        addRow(T_5H, u.fiveHour, resetLine(u.resets["five_hour"]))
        addRow(T_7D_ALL, u.sevenDay, resetLine(u.resets["seven_day"]))
        for m in u.models {
            var line = resetLine(m.resetsAt)
            if m.staleSeconds > staleThreshold {
                let note = staleNote(m.staleSeconds)
                line = (line.map { $0 + "  " } ?? "") + note
            }
            addRow("\(m.name) \(T_WEEK)", m.percent, line)
        }
        menu.addItem(NSMenuItem.separator())
        addFooter()
    }

    func addFooter() {
        if let t = lastUpdated {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(identifier: "Asia/Taipei")
            df.dateFormat = "HH:mm:ss"
            let item = NSMenuItem(title: "  " + T_UPDATED + df.string(from: t), action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        let r = NSMenuItem(title: T_REFRESH, action: #selector(manualRefresh), keyEquivalent: "r")
        r.target = self
        r.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        menu.addItem(r)
        let q = NSMenuItem(title: T_QUIT, action: #selector(quit), keyEquivalent: "q")
        q.target = self
        q.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(q)
    }

    @objc func manualRefresh() { statusItem.button?.title = " ..."; refresh() }
    @objc func quit() { NSApplication.shared.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = AppController()
app.delegate = controller
app.run()
