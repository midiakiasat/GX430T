import SwiftUI
import UniformTypeIdentifiers
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
                .tabItem {
                    Label(
                        "Print",
                        systemImage: "printer"
                    )
                }

            GX430TiPhoneUploadQueueView()
                .tabItem {
                    Label(
                        "Queue",
                        systemImage: "tray.and.arrow.up"
                    )
                }
        }
    }
}

struct GX430TiPhoneUploadQueueView: View {
    @EnvironmentObject private var model: GX430TiPhoneModel

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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GX430TBrandHeader()

                    connectionCard
                    queueSummary
                    queueControls
                    queueJobs
                    queueResult
                    licenceFooter
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(
                Color(uiColor: .systemGroupedBackground)
            )
            .navigationTitle("Upload Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button {
                        model.showingPairing = true
                    } label: {
                        Image(systemName: "link")
                    }
                    .accessibilityLabel("Connection")
                }

                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button {
                        Task {
                            await model.refreshQueue()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(
                        model.connection == nil ||
                        model.queueBusy
                    )
                    .accessibilityLabel("Refresh queue")
                }
            }
            .sheet(
                isPresented: $model.showingPairing
            ) {
                GX430TPairingView()
                    .environmentObject(model)
                    .interactiveDismissDisabled(
                        model.connection == nil
                    )
            }
        }
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

                Task {
                    await model.uploadQueueFile(url)
                }

            case .failure(let error):
                model.queueMessage = error.localizedDescription
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
                Task {
                    await model.clearQueue()
                }
            }

            Button(
                "Cancel",
                role: .cancel
            ) {}
        } message: {
            Text(
                "Queued, printed, and failed records will be removed."
            )
        }
        .task {
            if model.connection != nil {
                await model.refreshQueue()
            }
        }
    }

    private var connectionCard: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
                .fill(
                    model.connection == nil
                        ? Color.orange.opacity(0.13)
                        : Color.green.opacity(0.13)
                )

                Image(
                    systemName: model.connection == nil
                        ? "link.badge.plus"
                        : "lock.shield.fill"
                )
                .font(
                    .system(
                        size: 22,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    model.connection == nil
                        ? .orange
                        : .green
                )
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(
                    model.connection == nil
                        ? "Pair iPhone"
                        : "Authenticated Queue"
                )
                .font(.headline)

                Text(
                    model.connection?.hostName
                    ?? "Connect to the work Mac"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if let connection = model.connection {
                    Text(
                        "\(connection.hostURL.host ?? "Print Host"):43043 · Protocol \(connection.protocolVersion)"
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                }
            }

            Spacer()

            if model.connection == nil {
                Button("Pair") {
                    model.showingPairing = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel(
                        "Authenticated connection"
                    )
            }
        }
        .padding(15)
        .background(
            Color(
                uiColor: .secondarySystemGroupedBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                .primary.opacity(0.06),
                lineWidth: 1
            )
        }
    }

    private var queueSummary: some View {
        HStack(spacing: 10) {
            summaryCard(
                title: "Queued",
                count: model.queueState?.counts.queued ?? 0,
                symbol: "tray.full.fill"
            )

            summaryCard(
                title: "Printed",
                count: model.queueState?.counts.printed ?? 0,
                symbol: "checkmark.circle.fill"
            )

            summaryCard(
                title: "Errors",
                count: model.queueState?.counts.error ?? 0,
                symbol: "exclamationmark.triangle.fill"
            )
        }
    }

    private var queueControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Queue control")
                    .font(.title3.weight(.bold))

                Spacer()

                if model.queueBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Queue label format")
                    .font(.subheadline.weight(.semibold))

                Picker(
                    "Queue label format",
                    selection: $model.queueKind
                ) {
                    ForEach(GX430TPrintKind.allCases) { kind in
                        Text(kind.title)
                            .tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                Text(
                    "Choose how every queued value is encoded before Print Next or Print All."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Button {
                showingImporter = true
            } label: {
                Label(
                    "Choose Sheet File",
                    systemImage: "doc.badge.plus"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(
                model.connection == nil ||
                model.queueBusy
            )

            HStack {
                Button {
                    Task {
                        await model.printNextQueueLabel()
                    }
                } label: {
                    Label(
                        "Print Next",
                        systemImage: "printer"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(
                    model.connection == nil ||
                    model.queueBusy ||
                    (model.queueState?.counts.queued ?? 0) == 0
                )

                Button {
                    Task {
                        await model.printAllQueueLabels()
                    }
                } label: {
                    Label(
                        "Print All",
                        systemImage: "printer.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    model.connection == nil ||
                    model.queueBusy ||
                    (model.queueState?.counts.queued ?? 0) == 0
                )
            }

            Button(role: .destructive) {
                confirmingClear = true
            } label: {
                Label(
                    "Clear Queue",
                    systemImage: "trash"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(
                model.connection == nil ||
                model.queueBusy ||
                jobs.isEmpty
            )

            Text(
                "Supports CSV, TSV, XLSX, ODS, headerless barcode sheets, quantity expansion, and ordered printing."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(17)
        .background(
            Color(
                uiColor: .secondarySystemGroupedBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                .primary.opacity(0.06),
                lineWidth: 1
            )
        }
    }

    @ViewBuilder
    private var queueJobs: some View {
        if jobs.isEmpty {
            VStack(spacing: 13) {
                Image(systemName: "tray")
                    .font(
                        .system(
                            size: 40,
                            weight: .regular
                        )
                    )
                    .foregroundStyle(.secondary)

                Text("Queue Empty")
                    .font(.title3.weight(.semibold))

                Text(
                    model.connection == nil
                        ? "Pair this iPhone with the work Mac to access the shared queue."
                        : "Choose a sheet file to create ordered label jobs."
                )
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .padding(.horizontal, 18)
            .background(
                Color(
                    uiColor: .secondarySystemGroupedBackground
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Queue jobs")
                    .font(.title3.weight(.bold))

                ForEach(jobs) { job in
                    HStack(spacing: 12) {
                        Image(
                            systemName: statusSymbol(
                                job.status
                            )
                        )
                        .foregroundStyle(
                            statusColor(
                                job.status
                            )
                        )
                        .frame(width: 24)

                        VStack(
                            alignment: .leading,
                            spacing: 3
                        ) {
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
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }

                            HStack(spacing: 5) {
                                if let file = job.sourceFile {
                                    Text(file)
                                }

                                if let row = job.sourceRow {
                                    Text("row \(row)")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(
                            alignment: .trailing,
                            spacing: 3
                        ) {
                            Text(job.status.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(
                                    statusColor(
                                        job.status
                                    )
                                )

                            Text("#\(job.id)")
                                .font(
                                    .caption2.monospacedDigit()
                                )
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 8)

                    if job.id != jobs.last?.id {
                        Divider()
                    }
                }
            }
            .padding(17)
            .background(
                Color(
                    uiColor: .secondarySystemGroupedBackground
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
            )
        }
    }

    private var queueResult: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(
                systemName: model.queueBusy
                    ? "arrow.triangle.2.circlepath"
                    : "lock.shield"
            )
            .foregroundStyle(.secondary)

            Text(model.queueMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            Spacer()
        }
        .padding(14)
        .background(
            Color(
                uiColor: .secondarySystemGroupedBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }

    private var licenceFooter: some View {
        Link(
            destination:
                GX430TiPhoneLicence.repositoryURL
        ) {
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

    private func summaryCard(
        title: String,
        count: Int,
        symbol: String
    ) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("\(count)")
                .font(.title2.weight(.bold))
                .monospacedDigit()

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            Color(
                uiColor: .secondarySystemGroupedBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
        )
    }

    private func statusSymbol(
        _ status: String
    ) -> String {
        switch status.lowercased() {
        case "printed":
            return "checkmark.circle.fill"
        case "error":
            return "exclamationmark.triangle.fill"
        default:
            return "tray.full.fill"
        }
    }

    private func statusColor(
        _ status: String
    ) -> Color {
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
