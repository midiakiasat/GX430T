import SwiftUI
import GX430TKit

private enum GX430TiPhoneLicence {
    static let repositoryURL = URL(
        string: "https://github.com/midiakiasat/GX430T"
    )!
}

struct GX430TiPhoneRootView: View {
    @EnvironmentObject private var model: GX430TiPhoneModel
    @FocusState private var contentFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GX430TBrandHeader()

                    statusCard
                    composerCard
                    previewCard
                    resultCard
                    licenceFooter
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("GX430T")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.showingPairing = true
                    } label: {
                        Image(systemName: "link")
                    }
                    .accessibilityLabel("Connection")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await model.refreshStatus()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh printer")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        contentFocused = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                printBar
            }
            .sheet(isPresented: $model.showingPairing) {
                GX430TPairingView()
                    .environmentObject(model)
                    .interactiveDismissDisabled(model.connection == nil)
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        model.printerOnline
                            ? Color.green.opacity(0.13)
                            : Color.orange.opacity(0.13)
                    )

                Image(systemName: "printer.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        model.printerOnline ? .green : .orange
                    )
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.printerStatus)
                    .font(.headline)

                Text(
                    model.connection?.hostName
                    ?? "Connect to the work Mac"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            Circle()
                .fill(model.printerOnline ? .green : .orange)
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)
        }
        .padding(15)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Create label")
                .font(.title3.weight(.bold))

            Picker("Format", selection: $model.kind) {
                ForEach(GX430TPrintKind.allCases) { kind in
                    Text(kind.title)
                        .tag(kind)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Content", systemImage: model.kind.symbol)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text("\(model.value.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                TextField(
                    contentPlaceholder,
                    text: $model.value,
                    axis: .vertical
                )
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .lineLimit(2...5)
                .focused($contentFocused)
                .submitLabel(.done)
                .padding(14)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack {
                Label("Copies", systemImage: "square.on.square")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Stepper(
                    value: $model.copies,
                    in: 1...999
                ) {
                    Text("\(model.copies)")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .frame(minWidth: 34)
                }
                .fixedSize()
            }
        }
        .padding(17)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Spacer(minLength: 8)

                switch model.kind {
                case .text:
                    Text(
                        model.value.isEmpty
                            ? "Your label"
                            : model.value
                    )
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.35)
                    .padding(.horizontal)

                case .code128, .code39:
                    Image(systemName: "barcode")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 250, maxHeight: 92)

                    Text(
                        model.value.isEmpty
                            ? "1234567890"
                            : model.value
                    )
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)

                case .qr:
                    Image(systemName: "qrcode")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 125, height: 125)

                    Text(
                        model.value.isEmpty
                            ? "QR content"
                            : model.value
                    )
                    .font(.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                }

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, minHeight: 205)
            .padding()
            .foregroundStyle(.black)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.black.opacity(0.09), lineWidth: 1)
            }
        }
    }

    private var resultCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(
                systemName: model.printerOnline
                    ? "checkmark.circle.fill"
                    : "info.circle.fill"
            )
            .foregroundStyle(
                model.printerOnline ? .green : .secondary
            )

            Text(model.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var printBar: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await model.printTest()
                }
            } label: {
                Image(systemName: "testtube.2")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(model.connection == nil || model.isBusy)
            .accessibilityLabel("Print test label")

            Button {
                contentFocused = false

                Task {
                    await model.printCurrent()
                }
            } label: {
                HStack(spacing: 9) {
                    if model.isBusy {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "printer.fill")
                    }

                    Text(
                        model.isBusy
                            ? "Printing…"
                            : "Print \(model.copies == 1 ? "Label" : "\(model.copies) Labels")"
                    )
                    .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!model.canPrint)
        }
        .padding(.horizontal, 18)
        .padding(.top, 11)
        .padding(.bottom, 9)
        .background(.ultraThinMaterial)
    }

    private var licenceFooter: some View {
        Link(destination: GX430TiPhoneLicence.repositoryURL) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.seal")
                Text("Licence and source")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }

    private var contentPlaceholder: String {
        switch model.kind {
        case .text:
            return "Type label text"
        case .code128:
            return "Enter Code 128 value"
        case .code39:
            return "Enter Code 39 value"
        case .qr:
            return "Enter text or URL"
        }
    }
}


struct GX430TiPhoneRootWithQueueView: View {
    var body: some View {
        TabView {
            GX430TiPhoneRootView()
                .tabItem { Label("Print", systemImage: "printer") }

            GX430TiPhoneUploadQueueView()
                .tabItem { Label("Queue", systemImage: "tray.and.arrow.up") }
        }
    }
}


import UniformTypeIdentifiers

struct GX430TiPhoneUploadQueueView: View {
    @State private var host: String = UserDefaults.standard.string(forKey: "GX430T_HOST") ?? "http://127.0.0.1:9430"
    @State private var status: String = "Ready"
    @State private var log: String = "Upload CSV/XLSX, refresh queue, print next, or print all.\n\nFor iPhone, set host to the Mac Print Host LAN address, for example:\nhttp://192.168.1.20:9430"
    @State private var showImporter = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Print Host")) {
                    TextField("http://Mac-IP:9430", text: $host)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    Button("Save Host") {
                        UserDefaults.standard.set(host, forKey: "GX430T_HOST")
                        status = "Host saved"
                    }
                }

                Section(header: Text("Upload Queue")) {
                    Button("Choose Excel / CSV") {
                        showImporter = true
                    }
                    Button("Refresh Queue") {
                        request(path: "/api/state")
                    }
                    Button("Print Next") {
                        post(path: "/api/print-next")
                    }
                    Button("Print All") {
                        post(path: "/api/print-all")
                    }
                }

                Section(header: Text("Status")) {
                    Text(status)
                        .font(.headline)
                    ScrollView {
                        Text(log)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 220)
                }
            }
            .navigationTitle("Upload Queue")
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [
                UTType.commaSeparatedText,
                UTType(filenameExtension: "csv")!,
                UTType(filenameExtension: "txt")!,
                UTType(filenameExtension: "xlsx")!
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                upload(url: url)
            case .failure(let error):
                status = "Import failed"
                log = error.localizedDescription
            }
        }
    }

    func normalizedHost() -> String {
        var h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !h.hasPrefix("http://") && !h.hasPrefix("https://") {
            h = "http://" + h
        }
        return h.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func request(path: String) {
        guard let url = URL(string: normalizedHost() + path) else {
            status = "Bad host"
            return
        }
        status = "Requesting…"
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    status = "Failed"
                    log = error.localizedDescription
                    return
                }
                status = "OK"
                log = String(data: data ?? Data(), encoding: .utf8) ?? ""
            }
        }.resume()
    }

    func post(path: String) {
        guard let url = URL(string: normalizedHost() + path) else {
            status = "Bad host"
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        status = "Sending…"
        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    status = "Failed"
                    log = error.localizedDescription
                    return
                }
                status = "OK"
                log = String(data: data ?? Data(), encoding: .utf8) ?? ""
            }
        }.resume()
    }

    func upload(url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else {
            status = "Could not read file"
            return
        }

        guard let endpoint = URL(string: normalizedHost() + "/api/upload") else {
            status = "Bad host"
            return
        }

        let boundary = "GX430TBoundary\(UUID().uuidString)"
        var body = Data()
        let filename = url.lastPathComponent
        let contentType = filename.lowercased().hasSuffix(".xlsx")
            ? "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            : "text/csv"

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        status = "Uploading \(filename)…"
        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    status = "Upload failed"
                    log = error.localizedDescription
                    return
                }
                status = "Uploaded"
                log = String(data: data ?? Data(), encoding: .utf8) ?? ""
            }
        }.resume()
    }
}

