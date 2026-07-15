import SwiftUI

struct GX430TPairingView: View {
    @EnvironmentObject private var model: GX430TiPhoneModel
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: Field?

    private enum Field {
        case host
        case code
        case name
    }

    private var cleanCode: String {
        model.pairingCode.filter(\.isNumber)
    }

    private var canPair: Bool {
        !model.hostAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        cleanCode.count == 6 &&
        !model.deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.isBusy
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GX430TBrandHeader(compact: true)

                    introduction
                    pairingCard
                    privacyCard

                    if !model.message.isEmpty {
                        messageCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 130)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if model.connection != nil {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomAction
            }
        }
        .onChange(of: model.pairingCode) { _, newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(6))

            if digits != newValue {
                model.pairingCode = digits
            }
        }
        .onAppear {
            if model.hostAddress.isEmpty {
                focusedField = .host
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                model.connection == nil
                    ? "Connect once. Print anytime."
                    : "Manage this trusted connection."
            )
            .font(.title2.weight(.bold))

            Text(
                "Your iPhone communicates privately with the Mac connected to the Zebra printer. Both devices must be on the same trusted Wi-Fi network."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pairingCard: some View {
        VStack(spacing: 0) {
            fieldRow(
                title: "Work Mac",
                subtitle: "Host address",
                systemImage: "desktopcomputer"
            ) {
                TextField(
                    "Midia-iMac.local:43043",
                    text: $model.hostAddress
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .textContentType(.URL)
                .submitLabel(.next)
                .focused($focusedField, equals: .host)
                .onSubmit {
                    focusedField = .code
                }
            }

            Divider()
                .padding(.leading, 54)

            fieldRow(
                title: "Pairing code",
                subtitle: "Six digits shown by the Mac",
                systemImage: "number.square.fill"
            ) {
                TextField(
                    "000000",
                    text: $model.pairingCode
                )
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .focused($focusedField, equals: .code)
            }

            Divider()
                .padding(.leading, 54)

            fieldRow(
                title: "This iPhone",
                subtitle: "Name visible to the work Mac",
                systemImage: "iphone"
            ) {
                TextField(
                    "Device name",
                    text: $model.deviceName
                )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focusedField, equals: .name)
                .onSubmit {
                    focusedField = nil
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private func fieldRow<Content: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                content()
                    .font(.body)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 3) {
                Text("Private workplace connection")
                    .font(.subheadline.weight(.semibold))

                Text(
                    "The printer and Print Host remain inside your local network. The pairing code is used once and replaced after successful pairing."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var messageCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(
                systemName: model.connection == nil
                    ? "info.circle.fill"
                    : "checkmark.circle.fill"
            )
            .foregroundStyle(
                model.connection == nil
                    ? Color.secondary
                    : Color.green
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

    private var bottomAction: some View {
        VStack(spacing: 10) {
            Button {
                focusedField = nil

                Task {
                    await model.pair()
                }
            } label: {
                HStack(spacing: 9) {
                    if model.isBusy {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "link.badge.plus")
                    }

                    Text(model.isBusy ? "Connecting…" : "Connect iPhone")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canPair)

            if model.connection != nil {
                Button("Remove trusted connection", role: .destructive) {
                    model.removePairing()
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }
}
