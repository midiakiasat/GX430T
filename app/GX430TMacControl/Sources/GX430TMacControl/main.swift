import Cocoa
import Foundation

final class GX430TAppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var window: NSWindow!

    var mainRoot: NSView!
    var quickView: NSView!
    var queueView: NSView!

    var contentText: NSTextView!
    var statusLabel: NSTextField!
    var charCount: NSTextField!
    var previewTitle: NSTextField!
    var previewCode: NSTextField!
    var modeControl: NSSegmentedControl!
    var copiesField: NSTextField!
    var queueLog: NSTextView!
    var queueStatus: NSTextField!
    var uploadButton: NSButton!
    var mode: String = "Code 128"

    let port = "9430"

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
        window.title = "GX430T Mac Control v0.3.1"
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

        let quick = btn("⚡  Quick Print", #selector(showQuickPrint))
        quick.frame = NSRect(x: 30, y: 498, width: 220, height: 36)
        sidebar.addSubview(quick)

        let batch = btn("⇪  Upload Queue", #selector(showUploadQueue))
        batch.frame = NSRect(x: 30, y: 454, width: 220, height: 36)
        sidebar.addSubview(batch)

        sidebarItem(sidebar, y: 410, icon: "↺", label: "History")
        sidebarItem(sidebar, y: 368, icon: "⚠", label: "Connection")

        let refresh = btn("↻  Refresh Printer", #selector(refreshPrinterAction))
        refresh.frame = NSRect(x: 30, y: 74, width: 220, height: 34)
        sidebar.addSubview(refresh)

        let sideFoot = text("Native GX430T control\nLicence · GitHub", 11, .gray, .regular)
        sideFoot.frame = NSRect(x: 32, y: 24, width: 220, height: 36)
        sideFoot.maximumNumberOfLines = 2
        sidebar.addSubview(sideFoot)

        mainRoot = NSView(frame: NSRect(x: 285, y: 0, width: 895, height: 760))
        mainRoot.autoresizingMask = [.width, .height]
        mainRoot.wantsLayer = true
        mainRoot.layer?.backgroundColor = NSColor(calibratedWhite: 0.075, alpha: 1).cgColor

        quickView = buildQuickPrintView()
        queueView = buildUploadQueueView()
        queueView.isHidden = true

        mainRoot.addSubview(quickView)
        mainRoot.addSubview(queueView)

        root.addSubview(sidebar)
        root.addSubview(mainRoot)
        window.contentView = root
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        updatePreview()
    }

    func buildQuickPrintView() -> NSView {
        let main = NSView(frame: NSRect(x: 0, y: 0, width: 895, height: 760))
        main.autoresizingMask = [.width, .height]

        let mainTitle = text("GX430T", 18, .white, .bold)
        mainTitle.frame = NSRect(x: 26, y: 704, width: 240, height: 30)
        main.addSubview(mainTitle)

        let h = text("Quick Print", 38, .white, .bold)
        h.frame = NSRect(x: 38, y: 638, width: 440, height: 50)
        main.addSubview(h)

        let sub = text("Type, preview and print.", 16, .lightGray, .semibold)
        sub.frame = NSRect(x: 40, y: 612, width: 420, height: 28)
        main.addSubview(sub)

        let format = text("FORMAT", 13, .gray, .bold)
        format.frame = NSRect(x: 40, y: 566, width: 180, height: 24)
        main.addSubview(format)

        modeControl = NSSegmentedControl(labels: ["Aa  Text", "▥  Code 128", "▥  Code 39", "⌗  QR"], trackingMode: .selectOne, target: self, action: #selector(modeChanged))
        modeControl.frame = NSRect(x: 38, y: 524, width: 812, height: 46)
        modeControl.selectedSegment = 1
        main.addSubview(modeControl)

        let inputCard = panel(NSRect(x: 38, y: 338, width: 812, height: 164), radius: 18)
        main.addSubview(inputCard)

        let labelContent = text("↗  Label content", 14, .lightGray, .semibold)
        labelContent.frame = NSRect(x: 58, y: 470, width: 260, height: 24)
        main.addSubview(labelContent)

        charCount = text("0 characters", 12, .gray, .regular)
        charCount.alignment = .right
        charCount.frame = NSRect(x: 650, y: 470, width: 180, height: 24)
        main.addSubview(charCount)

        contentText = NSTextView(frame: NSRect(x: 58, y: 358, width: 772, height: 92))
        contentText.font = NSFont.systemFont(ofSize: 22, weight: .medium)
        contentText.textColor = .white
        contentText.backgroundColor = .clear
        contentText.insertionPointColor = .systemBlue
        contentText.delegate = self
        main.addSubview(contentText)

        let previewCard = NSView(frame: NSRect(x: 38, y: 92, width: 812, height: 210))
        previewCard.wantsLayer = true
        previewCard.layer?.backgroundColor = NSColor.white.cgColor
        previewCard.layer?.cornerRadius = 20
        main.addSubview(previewCard)

        previewCode = text("||||||||||||||||||||||||||||||||||||||||", 48, .black, .regular)
        previewCode.font = NSFont.monospacedSystemFont(ofSize: 46, weight: .regular)
        previewCode.alignment = .center
        previewCode.frame = NSRect(x: 118, y: 184, width: 652, height: 62)
        main.addSubview(previewCode)

        previewTitle = text("Your label preview", 24, .black, .bold)
        previewTitle.alignment = .center
        previewTitle.frame = NSRect(x: 118, y: 148, width: 652, height: 34)
        main.addSubview(previewTitle)

        let copies = text("Copies:", 15, .white, .semibold)
        copies.alignment = .right
        copies.frame = NSRect(x: 92, y: 38, width: 115, height: 28)
        main.addSubview(copies)

        copiesField = NSTextField(string: "1")
        copiesField.frame = NSRect(x: 214, y: 36, width: 50, height: 30)
        copiesField.alignment = .center
        main.addSubview(copiesField)

        let test = btn("Test Label", #selector(testLabel))
        test.frame = NSRect(x: 602, y: 34, width: 110, height: 34)
        main.addSubview(test)

        let print = btn("🖨  Print", #selector(printLabel))
        print.frame = NSRect(x: 730, y: 34, width: 120, height: 34)
        main.addSubview(print)

        return main
    }

    func buildUploadQueueView() -> NSView {
        let main = NSView(frame: NSRect(x: 0, y: 0, width: 895, height: 760))
        main.autoresizingMask = [.width, .height]

        let mainTitle = text("GX430T", 18, .white, .bold)
        mainTitle.frame = NSRect(x: 26, y: 704, width: 240, height: 30)
        main.addSubview(mainTitle)

        let h = text("Upload Queue", 38, .white, .bold)
        h.frame = NSRect(x: 38, y: 638, width: 520, height: 50)
        main.addSubview(h)

        let sub = text("Excel / CSV batch printing in ordered queue.", 16, .lightGray, .semibold)
        sub.frame = NSRect(x: 40, y: 612, width: 520, height: 28)
        main.addSubview(sub)

        let topCard = panel(NSRect(x: 38, y: 508, width: 812, height: 84), radius: 18)
        main.addSubview(topCard)

        uploadButton = btn("Choose Excel / CSV", #selector(uploadSpreadsheet))
        uploadButton.frame = NSRect(x: 58, y: 532, width: 178, height: 36)
        main.addSubview(uploadButton)

        let openQueue = btn("Open Queue", #selector(openQueueBrowser))
        openQueue.frame = NSRect(x: 252, y: 532, width: 130, height: 36)
        main.addSubview(openQueue)

        let refresh = btn("Refresh Queue", #selector(refreshQueueStatus))
        refresh.frame = NSRect(x: 398, y: 532, width: 140, height: 36)
        main.addSubview(refresh)

        let printNext = btn("Print Next", #selector(queuePrintNext))
        printNext.frame = NSRect(x: 554, y: 532, width: 120, height: 36)
        main.addSubview(printNext)

        let printAll = btn("Print All", #selector(queuePrintAll))
        printAll.frame = NSRect(x: 690, y: 532, width: 120, height: 36)
        main.addSubview(printAll)

        queueStatus = text("Queue ready. Upload .xlsx or .csv.", 15, .lightGray, .semibold)
        queueStatus.frame = NSRect(x: 46, y: 474, width: 804, height: 26)
        main.addSubview(queueStatus)

        let logCard = panel(NSRect(x: 38, y: 74, width: 812, height: 388), radius: 18)
        main.addSubview(logCard)

        queueLog = NSTextView(frame: NSRect(x: 58, y: 94, width: 772, height: 348))
        queueLog.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        queueLog.textColor = .white
        queueLog.backgroundColor = .clear
        queueLog.isEditable = false
        queueLog.string = "Native Upload Queue\n\nAccepted columns:\nbarcode, sku, style code, item code, codice, EAN, quantity, qty, qta, description, brand, order, ordine, sequence\n\nRows print in file order. Quantity expands one row into multiple labels."
        main.addSubview(queueLog)

        return main
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

    @objc func showQuickPrint() {
        quickView.isHidden = false
        queueView.isHidden = true
    }

    @objc func showUploadQueue() {
        quickView.isHidden = true
        queueView.isHidden = false
        startQueueHost()
        refreshQueueStatus()
    }

    @objc func modeChanged() {
        let labels = ["Text", "Code 128", "Code 39", "QR"]
        mode = labels[max(0, modeControl.selectedSegment)]
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
        let result = run("/usr/bin/lpstat", ["-p"])
        if result.uppercased().contains("GX430") || result.uppercased().contains("ZEBRA") {
            statusLabel.stringValue = "🖨  GX430T Ready"
            statusLabel.textColor = .systemGreen
        } else {
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

        let copies = max(1, Int(copiesField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1)
        for _ in 0..<copies {
            _ = run("/usr/bin/lp", ["-o", "raw", temp.path])
        }
    }

    @objc func uploadSpreadsheet() {
        startQueueHost()

        let panel = NSOpenPanel()
        panel.title = "Choose Excel or CSV"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["csv", "txt", "xlsx"]

        if panel.runModal() == .OK, let url = panel.url {
            queueStatus.stringValue = "Uploading \(url.lastPathComponent)…"
            let output = runGX(["upload", url.path])
            queueLog.string = "UPLOAD RESULT\n\n\(output)\n\n" + queueLog.string
            refreshQueueStatus()
        }
    }

    @objc func refreshQueueStatus() {
        startQueueHost()
        let output = runGX(["status"])
        queueLog.string = "QUEUE STATUS\n\n\(output)"
        if output.contains("\"queued\"") {
            queueStatus.stringValue = "Queue refreshed."
            queueStatus.textColor = .systemGreen
        } else {
            queueStatus.stringValue = "Queue status unavailable. Check local host."
            queueStatus.textColor = .systemOrange
        }
    }

    @objc func queuePrintNext() {
        startQueueHost()
        let output = runGX(["print-next"])
        queueLog.string = "PRINT NEXT\n\n\(output)\n\n" + queueLog.string
        refreshQueueStatus()
    }

    @objc func queuePrintAll() {
        startQueueHost()
        let output = runGX(["print-all"])
        queueLog.string = "PRINT ALL\n\n\(output)\n\n" + queueLog.string
        refreshQueueStatus()
    }

    @objc func openQueueBrowser() {
        startQueueHost()
        if let url = URL(string: "http://127.0.0.1:\(port)") {
            NSWorkspace.shared.open(url)
        }
    }

    func startQueueHost() {
        _ = runGX(["start-bg"])
    }

    func gxRoot() -> String {
        let bundle = Bundle.main.bundleURL.path
        let repoRoot = URL(fileURLWithPath: bundle)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        return repoRoot
    }

    func gxctlPath() -> String {
        let candidates = [
            "/usr/local/gx430t/bin/gx430tctl",
            "\(gxRoot())/bin/gx430tctl"
        ]
        for c in candidates {
            if FileManager.default.isExecutableFile(atPath: c) {
                return c
            }
        }
        return "\(gxRoot())/bin/gx430tctl"
    }

    func runGX(_ args: [String]) -> String {
        return run(gxctlPath(), args)
    }

    func run(_ launchPath: String, _ args: [String]) -> String {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "ERROR: \(error.localizedDescription)\nPATH: \(launchPath)\nARGS: \(args.joined(separator: " "))"
        }
    }
}

let app = NSApplication.shared
let delegate = GX430TAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
