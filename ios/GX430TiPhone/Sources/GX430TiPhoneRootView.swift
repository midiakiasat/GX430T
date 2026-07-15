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
