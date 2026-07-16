import Cocoa
import Foundation

final class GX430TAppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var window: NSWindow!
    var contentText: NSTextView!
    var statusLabel: NSTextField!
    var charCount: NSTextField!
    var previewTitle: NSTextField!
    var previewCode: NSTextField!
    var modeControl: NSSegmentedControl!
    var copiesField: NSTextField!
    var mode: String = "Code 128"

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        refreshPrinter()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func buildWindow() {
        let frame = NSRect(x: 0, y: 0, width: 1180, height: 760)
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "GX430T Mac Control v0.3.0"
        window.minSize = NSSize(width: 980, height: 640)

        let root = NSView(frame: frame)
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedWhite: 0.075, alpha: 1).cgColor

        let sidebar = panel(NSRect(x: 0, y: 0, width: 285, height: 760), radius: 0)
        sidebar.autoresizingMask = [.height, .maxXMargin]
        sidebar.layer?.backgroundColor = NSColor(calibratedWhite: 0.105, alpha: 1).cgColor

        let icon = text("🦓", 44, .white, .bold)
        icon.frame = NSRect(x: 34, y: 606, width: 62, height: 62)
        sidebar.addSubview(icon)

        let title = text("GX430T", 30, .white, .bold)
        title.frame = NSRect(x: 95, y: 624, width: 160, height: 42)
        sidebar.addSubview(title)

        statusLabel = text("🖨  GX430T Offline", 16, .lightGray, .semibold)
        statusLabel.frame = NSRect(x: 34, y: 578, width: 225, height: 28)
        sidebar.addSubview(statusLabel)

        let rule = NSBox(frame: NSRect(x: 32, y: 552, width: 220, height: 1))
        rule.boxType = .separator
        sidebar.addSubview(rule)

        sidebarItem(sidebar, y: 500, icon: "⚡", label: "Quick Print")
        sidebarItem(sidebar, y: 458, icon: "↺", label: "History")
        sidebarItem(sidebar, y: 416, icon: "⚠", label: "Connection")

        let upload = btn("Upload Queue", #selector(openUploadQueue))
        upload.frame = NSRect(x: 30, y: 344, width: 220, height: 36)
        sidebar.addSubview(upload)

        let refresh = btn("↻  Refresh Printer", #selector(refreshPrinterAction))
        refresh.frame = NSRect(x: 30, y: 74, width: 220, height: 34)
        sidebar.addSubview(refresh)

        let sideFoot = text("Native GX430T control\nLicence · GitHub", 11, .gray, .regular)
        sideFoot.frame = NSRect(x: 32, y: 24, width: 220, height: 36)
        sideFoot.maximumNumberOfLines = 2
        sidebar.addSubview(sideFoot)

        let main = NSView(frame: NSRect(x: 285, y: 0, width: 895, height: 760))
        main.autoresizingMask = [.width, .height]
        main.wantsLayer = true
        main.layer?.backgroundColor = NSColor(calibratedWhite: 0.075, alpha: 1).cgColor

        let mainTitle = text("GX430T", 18, .white, .bold)
        mainTitle.frame = NSRect(x: 26, y: 704, width: 240, height: 30)
        main.addSubview(mainTitle)

        modeControl = NSSegmentedControl(labels: ["Aa  Text", "▥  Code 128", "▥  Code 39", "⌗  QR"], trackingMode: .selectOne, target: self, action: #selector(modeChanged))
        modeControl.frame = NSRect(x: 38, y: 662, width: 812, height: 44)
        modeControl.selectedSegment = 1
        main.addSubview(modeControl)

        let inputCard = panel(NSRect(x: 38, y: 472, width: 812, height: 164), radius: 18)
        main.addSubview(inputCard)

        let labelContent = text("↗  Label content", 14, .lightGray, .semibold)
        labelContent.frame = NSRect(x: 58, y: 604, width: 260, height: 24)
        main.addSubview(labelContent)

        charCount = text("0 characters", 12, .gray, .regular)
        charCount.alignment = .right
        charCount.frame = NSRect(x: 650, y: 604, width: 180, height: 24)
        main.addSubview(charCount)

        contentText = NSTextView(frame: NSRect(x: 58, y: 492, width: 772, height: 92))
        contentText.font = NSFont.systemFont(ofSize: 22, weight: .medium)
        contentText.textColor = .white
        contentText.backgroundColor = .clear
        contentText.insertionPointColor = .systemBlue
        contentText.delegate = self
        main.addSubview(contentText)

        let previewCard = NSView(frame: NSRect(x: 38, y: 172, width: 812, height: 240))
        previewCard.wantsLayer = true
        previewCard.layer?.backgroundColor = NSColor.white.cgColor
        previewCard.layer?.cornerRadius = 20
        main.addSubview(previewCard)

        previewCode = text("||||||||||||||||||||||||||||||||||||||||", 48, .black, .regular)
        previewCode.font = NSFont.monospacedSystemFont(ofSize: 48, weight: .regular)
        previewCode.alignment = .center
        previewCode.frame = NSRect(x: 118, y: 282, width: 652, height: 72)
        main.addSubview(previewCode)

        previewTitle = text("Your label preview", 22, .black, .regular)
        previewTitle.font = NSFont.monospacedSystemFont(ofSize: 22, weight: .regular)
        previewTitle.alignment = .center
        previewTitle.frame = NSRect(x: 118, y: 240, width: 652, height: 34)
        main.addSubview(previewTitle)

        let copies = text("Copies:", 15, .white, .semibold)
        copies.alignment = .right
        copies.frame = NSRect(x: 90, y: 116, width: 115, height: 28)
        main.addSubview(copies)

        copiesField = NSTextField(string: "1")
        copiesField.frame = NSRect(x: 212, y: 114, width: 50, height: 30)
        copiesField.alignment = .center
        main.addSubview(copiesField)

        let test = btn("Test Label", #selector(testLabel))
        test.frame = NSRect(x: 602, y: 112, width: 110, height: 34)
        main.addSubview(test)

        let print = btn("🖨  Print", #selector(printLabel))
        print.frame = NSRect(x: 730, y: 112, width: 120, height: 34)
        main.addSubview(print)

        let hint = text("ⓘ  Connect this Mac to the printer by USB or pair it with a GX430T Print Host.", 13, .lightGray, .regular)
        hint.frame = NSRect(x: 58, y: 56, width: 760, height: 28)
        main.addSubview(hint)

        let product = text("GX430T Mac Control", 11, .gray, .regular)
        product.alignment = .right
        product.frame = NSRect(x: 660, y: 22, width: 190, height: 24)
        main.addSubview(product)

        root.addSubview(sidebar)
        root.addSubview(main)
        window.contentView = root
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        updatePreview()
    }

    func panel(_ frame: NSRect, radius: CGFloat) -> NSView {
        let v = NSView(frame: frame)
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1).cgColor
        v.layer?.borderColor = NSColor(calibratedWhite: 0.20, alpha: 1).cgColor
        v.layer?.borderWidth = 1
        v.layer?.cornerRadius = radius
        return v
    }

    func text(_ string: String, _ size: CGFloat, _ color: NSColor, _ weight: NSFont.Weight) -> NSTextField {
        let f = NSTextField(labelWithString: string)
        f.font = NSFont.systemFont(ofSize: size, weight: weight)
        f.textColor = color
        f.backgroundColor = .clear
        f.isBezeled = false
        f.isEditable = false
        return f
    }

    func btn(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        return b
    }

    func sidebarItem(_ parent: NSView, y: CGFloat, icon: String, label: String) {
        let item = text("\(icon)  \(label)", 15, .lightGray, .semibold)
        item.frame = NSRect(x: 34, y: y, width: 210, height: 28)
        parent.addSubview(item)
    }

    @objc func modeChanged() {
        let labels = ["Text", "Code 128", "Code 39", "QR"]
        let index = max(0, modeControl.selectedSegment)
        mode = labels[index]
        updatePreview()
    }

    func textDidChange(_ notification: Notification) {
        updatePreview()
    }

    func updatePreview() {
        let value = contentText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        charCount.stringValue = "\(value.count) characters"
        if value.isEmpty {
            previewTitle.stringValue = "Your label preview"
            previewCode.stringValue = "||||||||||||||||||||||||||||||||||||||||"
            return
        }
        previewTitle.stringValue = value
        if mode == "QR" {
            previewCode.stringValue = "▦ ▦ ▦ ▦ ▦"
        } else if mode == "Text" {
            previewCode.stringValue = value
        } else {
            previewCode.stringValue = "||||||||||||||||||||||||||||||||||||||||"
        }
    }

    @objc func refreshPrinterAction() {
        refreshPrinter()
    }

    func refreshPrinter() {
        let task = Process()
        task.launchPath = "/usr/bin/lpstat"
        task.arguments = ["-p"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8) ?? ""
            if out.uppercased().contains("GX430") || out.uppercased().contains("ZEBRA") {
                statusLabel.stringValue = "🖨  GX430T Ready"
                statusLabel.textColor = .systemGreen
            } else {
                statusLabel.stringValue = "🖨  GX430T Offline"
                statusLabel.textColor = .lightGray
            }
        } catch {
            statusLabel.stringValue = "🖨  GX430T Offline"
            statusLabel.textColor = .lightGray
        }
    }

    func labelZPL() -> String {
        let raw = contentText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = raw.isEmpty ? "TEST" : raw
        let safe = value.replacingOccurrences(of: "^", with: " ").replacingOccurrences(of: "~", with: " ")
        if mode == "QR" {
            return "^XA\n^CI28\n^FO170,35^BQN,2,8^FDQA,\(safe)^FS\n^FO40,170^A0N,24,24^FD\(safe)^FS\n^XZ\n"
        }
        if mode == "Text" {
            return "^XA\n^CI28\n^FO35,70^A0N,42,42^FD\(safe)^FS\n^XZ\n"
        }
        if mode == "Code 39" {
            return "^XA\n^CI28\n^FO35,45^BY2,3,90^B3N,N,90,Y,N^FD\(safe)^FS\n^XZ\n"
        }
        return "^XA\n^CI28\n^FO35,45^BY2,2.7,90^BCN,90,Y,N,N^FD\(safe)^FS\n^XZ\n"
    }

    @objc func testLabel() {
        contentText.string = "GX430T TEST"
        updatePreview()
    }

    @objc func printLabel() {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("gx430t-label.zpl")
        try? labelZPL().write(to: temp, atomically: true, encoding: .utf8)

        let task = Process()
        task.launchPath = "/usr/bin/lp"
        task.arguments = ["-o", "raw", temp.path]
        do {
            try task.run()
        } catch {
            NSSound.beep()
        }
    }

    @objc func openUploadQueue() {
        let candidates = [
            "/usr/local/gx430t/bin/gx430tctl",
            "\(FileManager.default.currentDirectoryPath)/bin/gx430tctl"
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
        if let url = URL(string: "http://127.0.0.1:9430") {
            NSWorkspace.shared.open(url)
        }
    }
}

let app = NSApplication.shared
let delegate = GX430TAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
