import SwiftUI

struct GX430TPairingView: View {
    @EnvironmentObject private var model: GX430TiPhoneModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            GX430TBrandHeader(compact: true)

        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Host address",
                        text: $model.hostAddress
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                    TextField(
                        "Six-digit pairing code",
                        text: $model.pairingCode
                    )
                    .keyboardType(.numberPad)

                    TextField(
                        "Device name",
                        text: $model.deviceName
                    )
                } header: {
                    Text("Connect to work Mac")
                } footer: {
                    Text(
                        "The work Mac must be running GX430T Print Host and connected to the Zebra printer by USB."
                    )
                }

                Section {
                    Button {
                        Task {
                            await model.pair()
                        }
                    } label: {
                        HStack {
                            Spacer()

                            if model.isBusy {
                                ProgressView()
                            } else {
                                Label(
                                    "Pair iPhone",
                                    systemImage: "link"
                                )
                            }

                            Spacer()
                        }
                    }
                    .disabled(model.isBusy)
                }

                if model.connection != nil {
                    Section {
                        Button(
                            "Remove Pairing",
                            role: .destructive
                        ) {
                            model.removePairing()
                        }
                    }
                }

                Section {
                    Text(model.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("GX430T Pairing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.connection != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
        }
}
