import SwiftUI
import AppKit
import Foundation

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
            self.printerOnline = code == 0 && output.localizedCaseInsensitiveContains("idle")
            self.printerStatus = self.printerOnline ? "GX430t Online" : "GX430t Unavailable"
            if !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.message = output.trimmingCharacters(in: .whitespacesAndNewlines)
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

        execute(arguments: [kind.command, cleanValue, String(copies)]) { [weak self] code, output in
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

    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
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
    @State private var showingHistory = false

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GX430T")
                        .font(.system(size: 30, weight: .bold))

                    Label(model.printerStatus, systemImage: model.printerOnline ? "printer.fill" : "printer")
                        .foregroundStyle(model.printerOnline ? .green : .secondary)
                }

                Divider()

                Button {
                    showingHistory = false
                } label: {
                    Label("Quick Print", systemImage: "bolt.fill")
                }
                .buttonStyle(.plain)

                Button {
                    showingHistory = true
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    model.refreshStatus()
                } label: {
                    Label("Refresh Printer", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)

                Text("Native GX430t control")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(22)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
        } detail: {
            if showingHistory {
                HistoryView()
            } else {
                quickPrint
            }
        }
        .frame(minWidth: 920, minHeight: 650)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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

                Picker("Format", selection: $model.kind) {
                    ForEach(PrintKind.allCases) { kind in
                        Label(kind.rawValue, systemImage: kind.symbol)
                            .tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                TextEditor(text: $model.value)
                    .font(.system(size: 20, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .padding(14)
                    .frame(minHeight: 110, maxHeight: 150)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.primary.opacity(0.1))
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
            }
            .padding(30)
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
                ContentUnavailableView(
                    "No Print History",
                    systemImage: "printer",
                    description: Text("Completed print jobs will appear here.")
                )
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
                        .frame(width: 42, height: 42)

                    Image(systemName: model.printerOnline ? "printer.fill" : "printer")
                        .font(.system(size: 19, weight: .semibold))
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

                Picker("Format", selection: $model.kind) {
                    ForEach(PrintKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

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

                Spacer()

                Menu {
                    Button("Print Test Label") {
                        model.printTest()
                    }

                    Button("Refresh Status") {
                        model.refreshStatus()
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
        }
        .padding(16)
        .frame(width: 390)
        .onAppear {
            model.refreshStatus()
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
