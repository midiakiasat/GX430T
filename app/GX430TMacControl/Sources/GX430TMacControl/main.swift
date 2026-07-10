import SwiftUI
import Foundation

@main
struct GX430TMacControlApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 760, minHeight: 560)
        }
        .windowStyle(.titleBar)
    }
}

struct ContentView: View {
    @State private var value: String = "1234567890"
    @State private var copies: String = "1"
    @State private var output: String = "GX430T Mac Control ready."

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GX430T Mac Control")
                .font(.largeTitle)
                .bold()

            Text("Native macOS control surface for Zebra GX430t local USB and colleague shared printing.")
                .foregroundStyle(.secondary)

            HStack {
                TextField("Barcode value", text: $value)
                    .textFieldStyle(.roundedBorder)

                TextField("Copies", text: $copies)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            HStack {
                Button("Discover") {
                    run(["discover"])
                }

                Button("Status") {
                    run(["status"])
                }

                Button("Install Local") {
                    run(["install-local"])
                }

                Button("Share On") {
                    run(["share-on"])
                }
            }

            HStack {
                Button("Print Code 128") {
                    run(["print-code128", value, copies])
                }

                Button("Print Code 39") {
                    run(["print-code39", value, copies])
                }

                Button("Print QR") {
                    run(["print-qr", value, copies])
                }

                Button("Diagnose") {
                    run(["diagnose"])
                }
            }

            Text("Output")
                .font(.headline)

            ScrollView {
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding()
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(24)
    }

    private func run(_ args: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/gx430tctl")
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            output = "$ gx430tctl \(args.joined(separator: " "))\n\n\(text)"
        } catch {
            output = "GX430T_APP_COMMAND_FAILED=true\n\(error.localizedDescription)"
        }
    }
}
