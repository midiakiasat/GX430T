import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers

enum GX430TBrand {
    static let repositoryURL = URL(string: "https://github.com/midiakiasat/GX430T")!
    static let productName = "GX430T"
    static let productSubtitle = "Professional label control"
}

struct GX430TLicenseFooter: View {
    var compact = false

    var body: some View {
        Link(destination: GX430TBrand.repositoryURL) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.seal")
                Text("Licence")
                Text("·")
                Text("GitHub")
            }
            .font(compact ? .caption2 : .caption)
            .foregroundStyle(.tertiary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open GX430T licence and source repository")
    }
}

enum GX430TConnectionMode: String {
    case local = "USB Host"
    case remote = "Network Client"
    case unavailable = "Unavailable"

    var symbol: String {
        switch self {
        case .local: return "cable.connector"
        case .remote: return "network"
        case .unavailable: return "exclamationmark.triangle"
        }
    }
}

enum GX430TMainSection: String {
    case quickPrint
    case uploadQueue
    case history
}

struct GX430TQueueCounts: Codable {
    let queued: Int
    let printed: Int
    let error: Int
}

struct GX430TQueueJob: Codable, Identifiable {
    let rawID: Int?
    let created: Double
    let position: Double
    let sourceFile: String?
    let sourceRow: Int?
    let barcode: String
    let title: String?
    let status: String
    let printed: Double?
    let lastError: String?

    var id: String {
        if let rawID {
            return "job-\(rawID)"
        }

        return [
            sourceFile ?? "queue",
            String(sourceRow ?? 0),
            barcode,
            String(position)
        ].joined(separator: "|")
    }

    enum CodingKeys: String, CodingKey {
        case rawID = "id"
        case created
        case position
        case sourceFile = "source_file"
        case sourceRow = "source_row"
        case barcode
        case title
        case status
        case printed
        case lastError = "last_error"
    }
}

struct GX430TQueueState: Codable {
    let ok: Bool
    let version: String
    let counts: GX430TQueueCounts
    let jobs: [GX430TQueueJob]
}

enum PrintKind: String, CaseIterable, Identifiable, Codable {
    case text = "Text"
    case code128 = "Code 128"
    case code39 = "Code 39"
    case qr = "QR"

    var id: String { rawValue }

    var command: String {
        switch self {
        case .text: return "print-text"
        case .code128: return "print-code128"
        case .code39: return "print-code39"
        case .qr: return "print-qr"
        }
    }

    var symbol: String {
        switch self {
        case .text: return "textformat"
        case .code128, .code39: return "barcode"
        case .qr: return "qrcode"
        }
    }
}

struct PrintHistoryItem: Codable, Identifiable {
    let id: UUID
    let value: String
    let kind: PrintKind
    let copies: Int
    let date: Date
    let succeeded: Bool
}

@MainActor
final class GX430TModel: ObservableObject {
    @Published var value = ""
    @Published var kind: PrintKind = .code128
    @Published var copies = 1
    @Published var printerStatus = "Checking printer…"
    @Published var printerOnline = false
    @Published var isPrinting = false
    @Published var message = "Ready"
    @Published var history: [PrintHistoryItem] = []
    @Published var connectionMode: GX430TConnectionMode = .unavailable
    @Published var hostURL = ""
    @Published var pairingCode = ""
    @Published var clientName = Host.current().localizedName ?? "GX430T Mac"
    @Published var isPairing = false
    @Published var hostAddress = ""
    @Published var hostPairingCode = ""
    @Published var connectionMessageIsError = false

    @Published var mainSection: GX430TMainSection = .quickPrint
    @Published var queueState: GX430TQueueState?
    @Published var queueMessage = "Queue ready."
    @Published var queueLastOutput = ""
    @Published var queueBusy = false

    private let historyKey = "GX430TPrintHistory"
    private let cli = "/usr/local/bin/gx430tctl"

    init() {
        loadHistory()
        refreshStatus()
    }

    var canPrint: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        copies > 0 &&
        !isPrinting
    }

    func refreshStatus() {
        execute(arguments: ["status"]) { [weak self] code, output in
            guard let self else { return }

            let localOnline = output.contains("GX430T_STATUS=ONLINE")
            let localPrinting = output.contains("GX430T_STATUS=PRINTING")

            if code == 0 && (localOnline || localPrinting) {
                self.connectionMode = .local
                self.printerOnline = true
                self.printerStatus = localPrinting ? "GX430t Printing" : "GX430t Online"
                self.message = "Connected directly through this Mac."
                self.connectionMessageIsError = false
                self.refreshHostDetails()
                return
            }

            self.execute(arguments: ["client-status"]) { [weak self] remoteCode, remoteOutput in
                guard let self else { return }

                let remoteOnline = remoteOutput.contains("GX430T_REMOTE_STATUS=ONLINE")

                if remoteCode == 0 && remoteOnline {
                    self.connectionMode = .remote
                    self.printerOnline = true
                    self.printerStatus = "GX430t Online via Host"
                    self.message = "Connected securely to the GX430T Print Host."
                    self.connectionMessageIsError = false
                } else {
                    self.connectionMode = .unavailable
                    self.printerOnline = false

                    if output.contains("GX430T_STATUS=OFFLINE") {
                        self.printerStatus = "GX430t Offline"
                    } else if output.contains("GX430T_STATUS=NOT_CONFIGURED") {
                        self.printerStatus = "GX430t Not Configured"
                    } else {
                        self.printerStatus = "GX430t Unavailable"
                    }

                    self.message = "Connect this Mac to the printer by USB or pair it with a GX430T Print Host."
                }
            }
        }
    }

    func printCurrent() {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanValue.isEmpty else {
            message = "Enter something to print."
            NSSound.beep()
            return
        }

        guard copies >= 1 && copies <= 999 else {
            message = "Copies must be between 1 and 999."
            NSSound.beep()
            return
        }

        isPrinting = true
        message = "Sending \(copies) \(copies == 1 ? "label" : "labels")…"

        let arguments: [String]

        switch connectionMode {
        case .local:
            arguments = [kind.command, cleanValue, String(copies)]
        case .remote:
            let remoteKind: String
            switch kind {
            case .text: remoteKind = "text"
            case .code128: remoteKind = "code128"
            case .code39: remoteKind = "code39"
            case .qr: remoteKind = "qr"
            }
            arguments = ["client-print", remoteKind, cleanValue, String(copies)]
        case .unavailable:
            isPrinting = false
            message = "GX430t is unavailable. Connect USB or pair with the print host."
            NSSound.beep()
            return
        }

        execute(arguments: arguments) { [weak self] code, output in
            guard let self else { return }

            self.isPrinting = false
            let succeeded = code == 0

            self.history.insert(
                PrintHistoryItem(
                    id: UUID(),
                    value: cleanValue,
                    kind: self.kind,
                    copies: self.copies,
                    date: Date(),
                    succeeded: succeeded
                ),
                at: 0
            )

            self.history = Array(self.history.prefix(100))
            self.saveHistory()

            if succeeded {
                self.message = output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Print sent successfully."
                    : output.trimmingCharacters(in: .whitespacesAndNewlines)
                NSSound(named: "Glass")?.play()
            } else {
                self.message = output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Print failed."
                    : output.trimmingCharacters(in: .whitespacesAndNewlines)
                NSSound.beep()
            }

            self.refreshStatus()
        }
    }

    func refreshHostDetails() {
        execute(arguments: ["host-info"]) { [weak self] code, output in
            guard let self else { return }

            guard code == 0 else {
                self.hostAddress = ""
                self.hostPairingCode = ""
                return
            }

            for line in output.split(whereSeparator: \.isNewline) {
                let value = String(line)

                if value.hasPrefix("GX430T_HOST_URL=") {
                    self.hostAddress = String(
                        value.dropFirst("GX430T_HOST_URL=".count)
                    )
                }

                if value.hasPrefix("GX430T_PAIRING_CODE=") {
                    self.hostPairingCode = String(
                        value.dropFirst("GX430T_PAIRING_CODE=".count)
                    )
                }
            }
        }
    }

    func pairWithHost(completion: @escaping (Bool) -> Void) {
        let cleanHost = hostURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCode = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = clientName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanHost.isEmpty else {
            message = "Enter the print-host address."
            connectionMessageIsError = true
            completion(false)
            return
        }

        guard cleanCode.count == 6, cleanCode.allSatisfy({ $0.isNumber }) else {
            message = "Enter the current six-digit pairing code shown on the work Mac."
            connectionMessageIsError = true
            completion(false)
            return
        }

        isPairing = true
        connectionMessageIsError = false
        message = "Pairing with GX430T Print Host…"

        execute(arguments: ["client-pair", cleanHost, cleanCode, cleanName]) { [weak self] code, output in
            guard let self else { return }

            self.isPairing = false

            if code == 0 && output.contains("GX430T_CLIENT_PAIRED=true") {
                self.connectionMode = .remote
                self.pairingCode = ""
                self.connectionMessageIsError = false
                self.message = "Mac paired successfully."
                self.refreshStatus()
                completion(true)
            } else {
                self.connectionMessageIsError = true

                if output.contains("invalid_pairing_code") {
                    self.message = "The pairing code is invalid or expired. Open Connection on the work Mac and use its current six-digit code."
                } else {
                    let cleanOutput = output.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                    self.message = cleanOutput.isEmpty
                        ? "Pairing failed. Confirm the host address and current six-digit code."
                        : cleanOutput
                }

                NSSound.beep()
                completion(false)
            }
        }
    }

    func enableAppAutostart() {
        execute(arguments: ["app-autostart-on"]) { [weak self] code, output in
            guard let self else { return }
            self.message = output.trimmingCharacters(in: .whitespacesAndNewlines)

            if code != 0 {
                NSSound.beep()
            }
        }
    }

    func disableAppAutostart() {
        execute(arguments: ["app-autostart-off"]) { [weak self] code, output in
            guard let self else { return }
            self.message = output.trimmingCharacters(in: .whitespacesAndNewlines)

            if code != 0 {
                NSSound.beep()
            }
        }
    }

    func restartPrintHost() {
        execute(arguments: ["host-restart"]) { [weak self] code, output in
            guard let self else { return }
            self.message = output.trimmingCharacters(in: .whitespacesAndNewlines)

            if code == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.refreshStatus()
                }
            } else {
                NSSound.beep()
            }
        }
    }

    func removeClientPairing() {
        execute(arguments: ["client-remove"]) { [weak self] _, output in
            guard let self else { return }
            self.connectionMode = .unavailable
            self.printerOnline = false
            self.message = output.trimmingCharacters(in: .whitespacesAndNewlines)
            self.refreshStatus()
        }
    }

    func useHistory(_ item: PrintHistoryItem) {
        value = item.value
        kind = item.kind
        copies = item.copies
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func printTest() {
        value = "1234567890"
        kind = .code128
        copies = 1
        printCurrent()
    }

    func refreshQueue(
        successMessage: String? = nil
    ) {
        queueBusy = true

        if successMessage == nil {
            queueMessage = "Refreshing queue…"
        }

        execute(arguments: ["queue-status"]) { [weak self] code, output in
            guard let self else { return }

            self.queueLastOutput = output

            guard code == 0 else {
                self.queueBusy = false
                self.queueMessage = self.queueFailureMessage(
                    output,
                    fallback: "Queue status is unavailable."
                )
                NSSound.beep()
                return
            }

            guard
                let data = output.data(using: .utf8),
                let state = try? JSONDecoder().decode(
                    GX430TQueueState.self,
                    from: data
                )
            else {
                self.queueBusy = false
                self.queueMessage = "Queue returned an invalid response."
                NSSound.beep()
                return
            }

            self.queueState = state
            self.queueBusy = false
            self.queueMessage = successMessage ?? "Queue refreshed."
        }
    }

    func uploadQueueFile(_ sourceURL: URL) {
        guard !queueBusy else { return }

        let accessed = sourceURL.startAccessingSecurityScopedResource()

        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let importDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "GX430TQueueImports",
                isDirectory: true
            )

        let stagedURL = importDirectory.appendingPathComponent(
            "\(UUID().uuidString)-\(sourceURL.lastPathComponent)"
        )

        do {
            try FileManager.default.createDirectory(
                at: importDirectory,
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(atPath: stagedURL.path) {
                try FileManager.default.removeItem(at: stagedURL)
            }

            try FileManager.default.copyItem(
                at: sourceURL,
                to: stagedURL
            )
        } catch {
            queueMessage = "Could not prepare the selected file: \(error.localizedDescription)"
            NSSound.beep()
            return
        }

        queueBusy = true
        queueMessage = "Uploading \(sourceURL.lastPathComponent)…"

        execute(
            arguments: [
                "upload",
                stagedURL.path
            ]
        ) { [weak self] code, output in
            try? FileManager.default.removeItem(at: stagedURL)

            guard let self else { return }

            self.queueLastOutput = output

            guard code == 0 else {
                self.queueBusy = false
                self.queueMessage = self.queueFailureMessage(
                    output,
                    fallback: "Queue upload failed."
                )
                NSSound.beep()
                return
            }

            self.queueBusy = false
            self.refreshQueue(
                successMessage: "Uploaded \(sourceURL.lastPathComponent)."
            )
        }
    }

    func printNextQueueLabel() {
        performQueueAction(
            command: "print-next",
            progress: "Printing next queued label…",
            success: "Print Next completed."
        )
    }

    func printAllQueueLabels() {
        performQueueAction(
            command: "print-all",
            progress: "Printing all queued labels…",
            success: "Print All completed."
        )
    }

    func clearQueue() {
        performQueueAction(
            command: "clear",
            progress: "Clearing queue…",
            success: "Queue cleared."
        )
    }

    func openMainWindow(
        section: GX430TMainSection? = nil
    ) {
        if let section {
            mainSection = section
        }

        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func performQueueAction(
        command: String,
        progress: String,
        success: String
    ) {
        guard !queueBusy else { return }

        queueBusy = true
        queueMessage = progress

        execute(arguments: [command]) { [weak self] code, output in
            guard let self else { return }

            self.queueLastOutput = output

            guard code == 0 else {
                self.queueBusy = false
                self.queueMessage = self.queueFailureMessage(
                    output,
                    fallback: "\(command) failed."
                )
                NSSound.beep()
                return
            }

            self.queueBusy = false
            self.refreshQueue(successMessage: success)
        }
    }

    private func queueFailureMessage(
        _ output: String,
        fallback: String
    ) -> String {
        let clean = output.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return clean.isEmpty ? fallback : clean
    }

    private func execute(
        arguments: [String],
        completion: @escaping @MainActor (Int32, String) -> Void
    ) {
        let executable = cli

        DispatchQueue.global(qos: .userInitiated).async {
            guard FileManager.default.isExecutableFile(atPath: executable) else {
                Task { @MainActor in
                    completion(127, "GX430T command backend is not installed.")
                }
                return
            }

            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                Task { @MainActor in
                    completion(process.terminationStatus, output)
                }
            } catch {
                Task { @MainActor in
                    completion(1, error.localizedDescription)
                }
            }
        }
    }

    private func loadHistory() {
        guard
            let data = UserDefaults.standard.data(forKey: historyKey),
            let decoded = try? JSONDecoder().decode([PrintHistoryItem].self, from: data)
        else {
            return
        }

        history = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }
}

struct GX430TBrandMark: View {
    var size: CGFloat = 48

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "printer.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.18)
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(.primary)
        .onAppear {
            guard
                let url = Bundle.main.url(
                    forResource: "ZEBRAGX430TLOGO",
                    withExtension: "svg"
                ),
                let loaded = NSImage(contentsOf: url)
            else {
                return
            }

            loaded.isTemplate = true
            image = loaded
        }
    }
}

struct GX430TFormatSelector: View {
    @Binding var selection: PrintKind

    var body: some View {
        HStack(spacing: 5) {
            ForEach(PrintKind.allCases) { kind in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        selection = kind
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 12, weight: .semibold))

                        Text(kind.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(selection == kind ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(selection == kind ? Color.accentColor : Color.clear)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.quaternary.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.primary.opacity(0.07), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Print format")
    }
}

struct LabelPreview: View {
    let value: String
    let kind: PrintKind

    private var previewValue: String {
        value.isEmpty ? "Your label preview" : value
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 10)

            switch kind {
            case .text:
                Text(previewValue)
                    .font(.system(size: 28, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.35)
                    .padding(.horizontal)

            case .code128, .code39:
                BarcodePreview(value: previewValue)
                Text(previewValue)
                    .font(.system(size: 16, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)

            case .qr:
                Image(systemName: "qrcode")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 145, height: 145)

                Text(previewValue)
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            }

            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .foregroundStyle(.black)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.black.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        .padding(.vertical, 8)
    }
}

struct BarcodePreview: View {
    let value: String

    private var bars: [CGFloat] {
        let seed = value.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return (0..<56).map { index in
            let mixed = abs(seed &+ index &* 17 &+ index &* index &* 3)
            return CGFloat((mixed % 4) + 1)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 1.5) {
            ForEach(Array(bars.enumerated()), id: \.offset) { index, width in
                Rectangle()
                    .frame(width: width, height: index.isMultiple(of: 7) ? 130 : 116)
            }
        }
        .frame(maxWidth: 430)
        .clipped()
        .padding(.horizontal, 24)
    }
}

struct QuickPrintView: View {
    @EnvironmentObject private var model: GX430TModel
    @State private var showingConnection = false

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        GX430TBrandMark(size: 48)
                            .foregroundStyle(.primary)

                        Text("GX430T")
                            .font(.system(size: 26, weight: .bold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer(minLength: 0)
                    }

                    Label(
                        model.printerStatus,
                        systemImage: model.printerOnline ? "printer.fill" : "printer"
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(model.printerOnline ? .green : .secondary)
                    .lineLimit(2)
                }

                Divider()

                Button {
                    model.mainSection = .quickPrint
                } label: {
                    Label("Quick Print", systemImage: "bolt.fill")
                }
                .buttonStyle(.plain)

                Button {
                    model.mainSection = .uploadQueue
                    model.refreshQueue()
                } label: {
                    Label("Upload Queue", systemImage: "tray.and.arrow.up.fill")
                }
                .buttonStyle(.plain)

                Button {
                    model.mainSection = .history
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.plain)

                Button {
                    showingConnection = true
                } label: {
                    Label("Connection", systemImage: model.connectionMode.symbol)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    model.refreshStatus()
                } label: {
                    Label("Refresh Printer", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Native GX430T control")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    GX430TLicenseFooter(compact: true)
                }
            }
            .padding(22)
            .navigationSplitViewColumnWidth(min: 230, ideal: 250, max: 280)
        } detail: {
            switch model.mainSection {
            case .quickPrint:
                quickPrint
            case .uploadQueue:
                UploadQueueView()
            case .history:
                HistoryView()
            }
        }
        .frame(minWidth: 920, minHeight: 650)
        .sheet(isPresented: $showingConnection) {
            ConnectionView()
                .environmentObject(model)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.mainSection == .quickPrint {
                    Button {
                        model.refreshStatus()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Button {
                        model.printCurrent()
                    } label: {
                        Label("Print", systemImage: "printer.fill")
                    }
                    .disabled(!model.canPrint)
                }

                if model.mainSection == .uploadQueue {
                    Button {
                        model.refreshQueue()
                    } label: {
                        Label("Refresh Queue", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.queueBusy)

                    Button {
                        model.printNextQueueLabel()
                    } label: {
                        Label("Print Next", systemImage: "printer.fill")
                    }
                    .disabled(
                        model.queueBusy ||
                        (model.queueState?.counts.queued ?? 0) == 0
                    )
                }
            }
        }
    }

    private var quickPrint: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Print")
                            .font(.system(size: 34, weight: .bold))
                        Text("Type, preview and print.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if model.isPrinting {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("FORMAT")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.9)
                        .foregroundStyle(.secondary)

                    GX430TFormatSelector(selection: $model.kind)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Label content", systemImage: "square.and.pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(model.value.count) characters")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    TextEditor(text: $model.value)
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 96, maxHeight: 135)
                }
                .padding(16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.primary.opacity(0.09), lineWidth: 1)
                }

                LabelPreview(value: model.value, kind: model.kind)

                HStack(spacing: 18) {
                    Stepper("Copies: \(model.copies)", value: $model.copies, in: 1...999)
                        .frame(width: 180)

                    Spacer()

                    Button("Test Label") {
                        model.printTest()
                    }

                    Button {
                        model.printCurrent()
                    } label: {
                        Label(
                            model.isPrinting ? "Printing…" : "Print",
                            systemImage: "printer.fill"
                        )
                        .frame(minWidth: 110)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!model.canPrint)
                }

                HStack(spacing: 8) {
                    Image(systemName: model.printerOnline ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(model.printerOnline ? .green : .secondary)

                    Text(model.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Spacer()
                }
                .padding(12)
                .background(.quaternary.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    GX430TLicenseFooter()
                    Spacer()
                    Text("GX430T Mac Control")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 2)
            }
            .padding(30)
        }
    }
}

struct UploadQueueView: View {
    @EnvironmentObject private var model: GX430TModel

    @State private var showingImporter = false
    @State private var confirmingClear = false

    private var supportedTypes: [UTType] {
        [
            "csv",
            "tsv",
            "xlsx",
            "ods",
            "txt"
        ].compactMap {
            UTType(filenameExtension: $0)
        }
    }

    private var jobs: [GX430TQueueJob] {
        model.queueState?.jobs ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upload Queue")
                        .font(.system(size: 34, weight: .bold))

                    Text("Import ordered sheet files and control label delivery.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if model.queueBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 10) {
                Button {
                    showingImporter = true
                } label: {
                    Label(
                        "Choose Sheet File",
                        systemImage: "doc.badge.plus"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.queueBusy)

                Button {
                    model.refreshQueue()
                } label: {
                    Label(
                        "Refresh",
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(model.queueBusy)

                Spacer()

                Button {
                    model.printNextQueueLabel()
                } label: {
                    Label(
                        "Print Next",
                        systemImage: "printer"
                    )
                }
                .disabled(
                    model.queueBusy ||
                    (model.queueState?.counts.queued ?? 0) == 0
                )

                Button {
                    model.printAllQueueLabels()
                } label: {
                    Label(
                        "Print All",
                        systemImage: "printer.fill"
                    )
                }
                .disabled(
                    model.queueBusy ||
                    (model.queueState?.counts.queued ?? 0) == 0
                )

                Button(role: .destructive) {
                    confirmingClear = true
                } label: {
                    Label(
                        "Clear",
                        systemImage: "trash"
                    )
                }
                .disabled(model.queueBusy || jobs.isEmpty)
            }

            HStack(spacing: 12) {
                queueSummaryCard(
                    title: "Queued",
                    count: model.queueState?.counts.queued ?? 0,
                    symbol: "tray.full"
                )

                queueSummaryCard(
                    title: "Printed",
                    count: model.queueState?.counts.printed ?? 0,
                    symbol: "checkmark.circle"
                )

                queueSummaryCard(
                    title: "Errors",
                    count: model.queueState?.counts.error ?? 0,
                    symbol: "exclamationmark.triangle"
                )
            }

            if jobs.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "tray")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundStyle(.secondary)

                    Text("Queue Empty")
                        .font(.title2.weight(.semibold))

                    Text("Choose a CSV, TSV, XLSX, ODS, or text file to create ordered label jobs.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 440)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                List(jobs) { job in
                    HStack(spacing: 14) {
                        Image(
                            systemName: statusSymbol(job.status)
                        )
                        .foregroundStyle(
                            statusColor(job.status)
                        )
                        .frame(width: 22)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(job.barcode)
                                .font(
                                    .system(
                                        .headline,
                                        design: .monospaced
                                    )
                                )
                                .lineLimit(1)

                            if
                                let title = job.title,
                                !title.isEmpty,
                                title != job.barcode
                            {
                                Text(title)
                                    .font(.callout)
                                    .lineLimit(1)
                            }

                            HStack(spacing: 6) {
                                if let sourceFile = job.sourceFile {
                                    Text(sourceFile)
                                }

                                if let sourceRow = job.sourceRow {
                                    Text("row \(sourceRow)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(job.status.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(
                                    statusColor(job.status)
                                )

                            Text("#\(job.id)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .listStyle(.inset)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(
                    systemName: model.queueBusy
                        ? "arrow.triangle.2.circlepath"
                        : "info.circle"
                )
                .foregroundStyle(.secondary)

                Text(model.queueMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Spacer()

                Text("Port 43043 · Protocol 1")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.quaternary.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(30)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    model.queueMessage = "No file was selected."
                    return
                }

                model.uploadQueueFile(url)

            case .failure(let error):
                model.queueMessage = "File selection failed: \(error.localizedDescription)"
                NSSound.beep()
            }
        }
        .confirmationDialog(
            "Clear all queue jobs?",
            isPresented: $confirmingClear,
            titleVisibility: .visible
        ) {
            Button(
                "Clear Queue",
                role: .destructive
            ) {
                model.clearQueue()
            }

            Button(
                "Cancel",
                role: .cancel
            ) {}
        } message: {
            Text(
                "Queued, printed, and failed queue records will be removed."
            )
        }
        .onAppear {
            model.refreshQueue()
        }
    }

    private func queueSummaryCard(
        title: String,
        count: Int,
        symbol: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                .primary.opacity(0.08),
                lineWidth: 1
            )
        }
    }

    private func statusSymbol(_ status: String) -> String {
        switch status.lowercased() {
        case "printed":
            return "checkmark.circle.fill"
        case "error":
            return "exclamationmark.triangle.fill"
        default:
            return "tray.full.fill"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "printed":
            return .green
        case "error":
            return .red
        default:
            return .blue
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var model: GX430TModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Print History")
                        .font(.system(size: 34, weight: .bold))
                    Text("Your latest 100 print jobs.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Clear History", role: .destructive) {
                    model.clearHistory()
                }
                .disabled(model.history.isEmpty)
            }

            if model.history.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "printer")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundStyle(.secondary)

                    Text("No Print History")
                        .font(.title2.weight(.semibold))

                    Text("Completed print jobs will appear here.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                List(model.history) { item in
                    HStack(spacing: 14) {
                        Image(systemName: item.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(item.succeeded ? .green : .red)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.value)
                                .lineLimit(1)
                                .font(.headline)

                            Text("\(item.kind.rawValue) · \(item.copies) \(item.copies == 1 ? "copy" : "copies") · \(item.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Use Again") {
                            model.useHistory(item)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .listStyle(.inset)
            }
        }
        .padding(30)
    }
}

struct ConnectionView: View {
    @EnvironmentObject private var model: GX430TModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.blue.opacity(0.12))
                        .frame(width: 54, height: 54)

                    Image(systemName: model.connectionMode.symbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("GX430T Connection")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(model.connectionMode.rawValue)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if model.connectionMode == .local {
                Label(
                    "This Mac is the USB Print Host.",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)

                Text("Use these details on another Mac or iPhone. The pairing code rotates after every successful pairing.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("HOST ADDRESS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        Text(
                            model.hostAddress.isEmpty
                                ? "Loading host address…"
                                : model.hostAddress
                        )
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("CURRENT PAIRING CODE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(
                                model.hostPairingCode.isEmpty
                                    ? "------"
                                    : model.hostPairingCode
                            )
                            .font(
                                .system(
                                    size: 30,
                                    weight: .bold,
                                    design: .monospaced
                                )
                            )
                            .tracking(5)
                            .textSelection(.enabled)

                            Spacer()

                            Button {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(
                                    model.hostPairingCode,
                                    forType: .string
                                )
                            } label: {
                                Label("Copy Code", systemImage: "doc.on.doc")
                            }
                            .disabled(model.hostPairingCode.isEmpty)
                        }
                    }
                }
                .padding(16)
                .background(.regularMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                )

                HStack {
                    Button {
                        model.refreshHostDetails()
                    } label: {
                        Label("Refresh Pairing Details", systemImage: "arrow.clockwise")
                    }

                    Button {
                        model.enableAppAutostart()
                    } label: {
                        Label("Launch at Login", systemImage: "power")
                    }

                    Button {
                        model.restartPrintHost()
                    } label: {
                        Label("Restart Print Host", systemImage: "bolt.horizontal")
                    }

                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pair with the work Mac")
                        .font(.headline)

                    TextField("Host address — for example 192.168.1.5:43043", text: $model.hostURL)
                        .textFieldStyle(.roundedBorder)

                    TextField("Six-digit pairing code", text: $model.pairingCode)
                        .textFieldStyle(.roundedBorder)

                    TextField("This Mac name", text: $model.clientName)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        if model.connectionMode == .remote {
                            Button("Remove Pairing", role: .destructive) {
                                model.removeClientPairing()
                            }
                        }

                        Spacer()

                        Button("Cancel") {
                            dismiss()
                        }

                        Button {
                            model.pairWithHost { succeeded in
                                if succeeded {
                                    dismiss()
                                }
                            }
                        } label: {
                            if model.isPairing {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 90)
                            } else {
                                Text("Pair Mac")
                                    .frame(width: 90)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isPairing)
                    }
                }
            }

            Divider()

            HStack {
                Image(
                    systemName: model.connectionMessageIsError
                        ? "xmark.circle.fill"
                        : (
                            model.printerOnline
                                ? "checkmark.circle.fill"
                                : "info.circle.fill"
                        )
                )
                .foregroundStyle(
                    model.connectionMessageIsError
                        ? .red
                        : (
                            model.printerOnline
                                ? .green
                                : .secondary
                        )
                )

                Text(model.message)
                    .font(.callout)
                    .foregroundStyle(
                        model.connectionMessageIsError
                            ? .red
                            : .secondary
                    )
                    .textSelection(.enabled)

                Spacer()
            }
        }
        .padding(24)
        .frame(width: 560)
        .onAppear {
            if model.connectionMode == .local {
                model.refreshHostDetails()
            }
        }
    }
}

struct MenuBarContent: View {
    @EnvironmentObject private var model: GX430TModel
    @FocusState private var inputFocused: Bool

    private var statusColor: Color {
        model.printerOnline ? .green : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(statusColor.opacity(0.14))
                        .frame(width: 46, height: 46)

                    GX430TBrandMark(size: 38)
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("GX430T")
                        .font(.system(size: 18, weight: .bold))

                    HStack(spacing: 5) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)

                        Text(model.printerStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    model.refreshStatus()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh printer status")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Print")
                    .font(.headline)

                TextField("Type what you want to print", text: $model.value, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .focused($inputFocused)
                    .onSubmit {
                        if model.canPrint {
                            model.printCurrent()
                        }
                    }

                GX430TFormatSelector(selection: $model.kind)

                HStack {
                    Stepper(value: $model.copies, in: 1...999) {
                        Text("\(model.copies) \(model.copies == 1 ? "copy" : "copies")")
                            .font(.callout)
                    }

                    Spacer()

                    Button {
                        model.printCurrent()
                    } label: {
                        HStack(spacing: 7) {
                            if model.isPrinting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "printer.fill")
                            }

                            Text(model.isPrinting ? "Printing…" : "Print")
                                .fontWeight(.semibold)
                        }
                        .frame(minWidth: 86)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!model.canPrint)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Upload Queue")
                        .font(.headline)

                    Spacer()

                    if model.queueBusy {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button {
                            model.refreshQueue()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Refresh upload queue")
                    }
                }

                HStack(spacing: 14) {
                    Label(
                        "\(model.queueState?.counts.queued ?? 0) queued",
                        systemImage: "tray.full"
                    )

                    Label(
                        "\(model.queueState?.counts.error ?? 0) errors",
                        systemImage: "exclamationmark.triangle"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack {
                    Button {
                        model.openMainWindow(
                            section: .uploadQueue
                        )
                    } label: {
                        Label(
                            "Open Queue",
                            systemImage: "macwindow"
                        )
                    }

                    Spacer()

                    Button("Print Next") {
                        model.printNextQueueLabel()
                    }
                    .disabled(
                        model.queueBusy ||
                        (model.queueState?.counts.queued ?? 0) == 0
                    )

                    Button("Print All") {
                        model.printAllQueueLabels()
                    }
                    .disabled(
                        model.queueBusy ||
                        (model.queueState?.counts.queued ?? 0) == 0
                    )
                }
            }

            if !model.message.isEmpty {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: model.printerOnline ? "checkmark.circle.fill" : "info.circle.fill")
                        .foregroundStyle(model.printerOnline ? .green : .secondary)

                    Text(model.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    Spacer()
                }
                .padding(10)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            if !model.history.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Recent")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }

                    ForEach(Array(model.history.prefix(3))) { item in
                        Button {
                            model.useHistory(item)
                            inputFocused = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: item.kind.symbol)
                                    .frame(width: 17)
                                    .foregroundStyle(.secondary)

                                Text(item.value)
                                    .lineLimit(1)

                                Spacer()

                                Text("×\(item.copies)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            HStack {
                Button {
                    model.openMainWindow()
                } label: {
                    Label("Open App", systemImage: "macwindow")
                }

                Text(model.connectionMode.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Menu {
                    Button("Print Test Label") {
                        model.printTest()
                    }

                    Button("Refresh Status") {
                        model.refreshStatus()
                    }

                    Button("Launch at Login") {
                        model.enableAppAutostart()
                    }

                    if model.connectionMode == .local {
                        Button("Restart Print Host") {
                            model.restartPrintHost()
                        }
                    }

                    Divider()

                    Button("Quit GX430T", role: .destructive) {
                        NSApp.terminate(nil)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            GX430TLicenseFooter(compact: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(width: 390)
        .onAppear {
            model.refreshStatus()
            model.refreshQueue()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                inputFocused = true
            }
        }
    }
}

@main
struct GX430TMacControlApp: App {
    @StateObject private var model = GX430TModel()

    var body: some Scene {
        WindowGroup("GX430T") {
            QuickPrintView()
                .environmentObject(model)
        }
        .defaultSize(width: 1060, height: 720)
        .windowStyle(.titleBar)

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(model)
        } label: {
            Image(systemName: model.printerOnline ? "printer.fill" : "printer")
        }
        .menuBarExtraStyle(.window)
    }
}
