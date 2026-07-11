import SwiftUI
import GX430TKit

private enum GX430TiPhoneBrand {
    static let repositoryURL = URL(string: "https://github.com/midiakiasat/GX430T")!
}

struct GX430TiPhoneRootView: View {
    @EnvironmentObject private var model: GX430TiPhoneModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    statusCard
                    formatPicker
                    contentEditor
                    labelPreview
                    controls
                    resultCard
                    licenceFooter
                }
                .padding()
            }
            .navigationTitle("GX430T")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.showingPairing = true
                    } label: {
                        Image(systemName: "network")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await model.refreshStatus()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $model.showingPairing) {
                GX430TPairingView()
                    .environmentObject(model)
                    .interactiveDismissDisabled(model.connection == nil)
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        model.printerOnline
                            ? Color.green.opacity(0.14)
                            : Color.orange.opacity(0.14)
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "printer.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(
                        model.printerOnline ? .green : .orange
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(model.printerStatus)
                    .font(.headline)

                Text(
                    model.connection?.hostName
                    ?? "GX430T Print Host"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(model.printerOnline ? .green : .orange)
                .frame(width: 10, height: 10)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("FORMAT")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)

            HStack(spacing: 5) {
                ForEach(GX430TPrintKind.allCases) { kind in
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            model.kind = kind
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: kind.symbol)
                                .font(.system(size: 15, weight: .semibold))

                            Text(kind.title)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(model.kind == kind ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(model.kind == kind ? Color.accentColor : Color.clear)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var contentEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Label content", systemImage: "square.and.pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(model.value.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            TextField(
                "Type what you want to print",
                text: $model.value,
                axis: .vertical
            )
            .font(.title3.weight(.medium))
            .lineLimit(3...7)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var labelPreview: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 8)

            switch model.kind {
            case .text:
                Text(
                    model.value.isEmpty
                    ? "Your label preview"
                    : model.value
                )
                .font(.system(size: 26, weight: .semibold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.45)
                .padding()

            case .code128, .code39:
                Image(systemName: "barcode")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 125)

                Text(
                    model.value.isEmpty
                    ? "1234567890"
                    : model.value
                )
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.4)

            case .qr:
                Image(systemName: "qrcode")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 145, height: 145)

                Text(
                    model.value.isEmpty
                    ? "Your QR content"
                    : model.value
                )
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 250)
        .foregroundStyle(.black)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.black.opacity(0.1))
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            Stepper(
                "\(model.copies) \(model.copies == 1 ? "copy" : "copies")",
                value: $model.copies,
                in: 1...999
            )

            HStack(spacing: 12) {
                Button("Test") {
                    Task {
                        await model.printTest()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    Task {
                        await model.printCurrent()
                    }
                } label: {
                    HStack {
                        if model.isBusy {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "printer.fill")
                        }

                        Text(model.isBusy ? "Printing…" : "Print")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.canPrint)
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

            Spacer()
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var licenceFooter: some View {
        Link(destination: GX430TiPhoneBrand.repositoryURL) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.seal")
                Text("Licence")
                Text("·")
                Text("GitHub")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open GX430T licence and source repository")
    }
}
