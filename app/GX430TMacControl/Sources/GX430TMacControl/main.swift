import Cocoa
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        startHost()
        buildWindow()
        openLocalUI()
    }

    func startHost() {
        let root = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().path
        let candidates = [
            "/usr/local/gx430t/bin/gx430tctl",
            "\(root)/bin/gx430tctl"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                let task = Process()
                task.launchPath = path
                task.arguments = ["start-bg"]
                try? task.run()
                break
            }
        }
    }

    func openLocalUI() {
        if let url = URL(string: "http://127.0.0.1:9430") {
            NSWorkspace.shared.open(url)
        }
    }

    func buildWindow() {
        let rect = NSRect(x: 0, y: 0, width: 640, height: 420)
        window = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.center()
        window.title = "GX430T Mac Control v0.2.9"
        window.isReleasedWhenClosed = false

        let view = NSView(frame: rect)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor

        let title = NSTextField(labelWithString: "GX430T MAC CONTROL")
        title.font = NSFont.boldSystemFont(ofSize: 30)
        title.textColor = .white
        title.frame = NSRect(x: 34, y: 310, width: 560, height: 42)

        let subtitle = NSTextField(labelWithString: "Excel / CSV → Ordered Print Queue")
        subtitle.font = NSFont.systemFont(ofSize: 18)
        subtitle.textColor = .lightGray
        subtitle.frame = NSRect(x: 34, y: 270, width: 560, height: 30)

        let url = NSTextField(labelWithString: "http://127.0.0.1:9430")
        url.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .medium)
        url.textColor = .white
        url.frame = NSRect(x: 34, y: 224, width: 560, height: 28)

        let button = NSButton(title: "Open Upload Queue Print OS", target: self, action: #selector(openButton))
        button.frame = NSRect(x: 34, y: 160, width: 270, height: 44)
        button.bezelStyle = .rounded

        let footer = NSTextField(labelWithString: "Powered by Midia Kiasat · Local GX430T print host")
        footer.textColor = .gray
        footer.frame = NSRect(x: 34, y: 36, width: 560, height: 24)

        view.addSubview(title)
        view.addSubview(subtitle)
        view.addSubview(url)
        view.addSubview(button)
        view.addSubview(footer)
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openButton() {
        openLocalUI()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
