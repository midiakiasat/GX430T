import Foundation
import SwiftUI
import UIKit
import GX430TKit

@MainActor
final class GX430TiPhoneModel: ObservableObject {
    @Published var value = ""
    @Published var kind: GX430TPrintKind = .code128
    @Published var copies = 1

    @Published var hostAddress = ""
    @Published var pairingCode = ""
    @Published var deviceName = UIDevice.current.name

    @Published var connection: GX430TStoredConnection?
    @Published var printerOnline = false
    @Published var printerStatus = "Not paired"
    @Published var message = "Pair this iPhone with the work Mac."
    @Published var isBusy = false
    @Published var showingPairing = false

    private let client = GX430TNetworkClient()
    private let connectionKey = "GX430TStoredConnection"

    init() {
        loadConnection()

        if connection != nil {
            Task {
                await refreshStatus()
            }
        } else {
            showingPairing = true
        }
    }

    var canPrint: Bool {
        connection != nil &&
        printerOnline &&
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (1...999).contains(copies) &&
        !isBusy
    }

    func pair() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let host = try await client.normalizeHost(hostAddress)

            _ = try await client.info(hostURL: host)

            let paired = try await client.pair(
                hostURL: host,
                pairingCode: pairingCode,
                deviceName: deviceName
            )

            connection = paired
            saveConnection(paired)
            pairingCode = ""
            showingPairing = false
            message = "iPhone paired with \(paired.hostName)."

            await refreshStatus()
        } catch {
            message = error.localizedDescription
        }
    }

    func refreshStatus() async {
        guard let connection else {
            printerOnline = false
            printerStatus = "Not paired"
            message = "Pair this iPhone with the work Mac."
            return
        }

        do {
            let response = try await client.status(connection: connection)
            printerOnline = response.printerOnline
            printerStatus = response.printerOnline
                ? "GX430t Online"
                : "GX430t Offline"
            message = response.printerOnline
                ? "Connected securely to \(connection.hostName)."
                : response.statusOutput
        } catch {
            printerOnline = false
            printerStatus = "Host unavailable"
            message = error.localizedDescription
        }
    }

    func printCurrent() async {
        guard let connection else {
            message = "Pair this iPhone first."
            showingPairing = true
            return
        }

        isBusy = true
        message = "Sending print job…"
        defer { isBusy = false }

        do {
            let response = try await client.print(
                connection: connection,
                request: GX430TPrintRequest(
                    kind: kind,
                    value: value,
                    copies: copies
                )
            )

            message = response.result.isEmpty
                ? "Print sent successfully."
                : response.result

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await refreshStatus()
        } catch {
            message = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    func printTest() async {
        value = "1234567890"
        kind = .code128
        copies = 1
        await printCurrent()
    }

    func removePairing() {
        connection = nil
        printerOnline = false
        printerStatus = "Not paired"
        UserDefaults.standard.removeObject(forKey: connectionKey)
        showingPairing = true
        message = "Pairing removed."
    }

    private func loadConnection() {
        guard
            let data = UserDefaults.standard.data(forKey: connectionKey),
            let decoded = try? JSONDecoder().decode(
                GX430TStoredConnection.self,
                from: data
            )
        else {
            return
        }

        connection = decoded
        hostAddress = decoded.hostURL.absoluteString
    }

    private func saveConnection(_ connection: GX430TStoredConnection) {
        guard let data = try? JSONEncoder().encode(connection) else {
            return
        }

        UserDefaults.standard.set(data, forKey: connectionKey)
    }
}
