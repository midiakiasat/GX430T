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

    @Published var queueState: GX430TQueueState?
    @Published var queueMessage = "Pair this iPhone to use the queue."
    @Published var queueBusy = false

    private let client = GX430TNetworkClient()
    private let connectionKey = "GX430TStoredConnection"

    init() {
        loadConnection()

        if connection != nil {
            Task {
                await refreshStatus()
                await refreshQueue()
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
            await refreshQueue()
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

    func refreshQueue() async {
        guard let connection else {
            queueState = nil
            queueMessage = "Pair this iPhone to use the queue."
            return
        }

        guard !queueBusy else { return }

        queueBusy = true
        queueMessage = "Refreshing queue…"
        defer { queueBusy = false }

        do {
            queueState = try await client.queueState(
                connection: connection
            )
            queueMessage = "Queue refreshed securely from \(connection.hostName)."
        } catch {
            queueMessage = error.localizedDescription
        }
    }

    func uploadQueueFile(_ url: URL) async {
        guard let connection else {
            queueMessage = "Pair this iPhone first."
            showingPairing = true
            return
        }

        guard !queueBusy else { return }

        let accessed = url.startAccessingSecurityScopedResource()

        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        queueBusy = true
        queueMessage = "Uploading \(url.lastPathComponent)…"
        defer { queueBusy = false }

        do {
            let data = try Data(contentsOf: url)

            let response = try await client.uploadQueueFile(
                connection: connection,
                fileName: url.lastPathComponent,
                contentType: queueContentType(for: url),
                data: data
            )

            queueState = try await client.queueState(
                connection: connection
            )

            queueMessage = "Uploaded \(response.labels) \(response.labels == 1 ? "label" : "labels") from \(response.file)."

            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)
        } catch {
            queueMessage = error.localizedDescription

            UINotificationFeedbackGenerator()
                .notificationOccurred(.error)
        }
    }

    func printNextQueueLabel() async {
        guard let connection else {
            queueMessage = "Pair this iPhone first."
            showingPairing = true
            return
        }

        guard !queueBusy else { return }

        queueBusy = true
        queueMessage = "Printing next queued label…"
        defer { queueBusy = false }

        do {
            let response = try await client.printNextQueueLabel(
                connection: connection
            )

            queueState = try await client.queueState(
                connection: connection
            )

            queueMessage = response.message
                ?? (
                    response.printed == 0
                    ? "Queue is empty."
                    : "Next queued label was submitted."
                )

            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)
        } catch {
            queueMessage = error.localizedDescription

            UINotificationFeedbackGenerator()
                .notificationOccurred(.error)
        }
    }

    func printAllQueueLabels() async {
        guard let connection else {
            queueMessage = "Pair this iPhone first."
            showingPairing = true
            return
        }

        guard !queueBusy else { return }

        queueBusy = true
        queueMessage = "Printing all queued labels…"
        defer { queueBusy = false }

        do {
            let response = try await client.printAllQueueLabels(
                connection: connection
            )

            if let responseState = response.state {
                queueState = responseState
            } else {
                queueState = try await client.queueState(
                    connection: connection
                )
            }

            let printed = response.printed ?? 0

            queueMessage = "Submitted \(printed) \(printed == 1 ? "label" : "labels") from the queue."

            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)
        } catch {
            queueMessage = error.localizedDescription

            UINotificationFeedbackGenerator()
                .notificationOccurred(.error)
        }
    }

    func clearQueue() async {
        guard let connection else {
            queueMessage = "Pair this iPhone first."
            showingPairing = true
            return
        }

        guard !queueBusy else { return }

        queueBusy = true
        queueMessage = "Clearing queue…"
        defer { queueBusy = false }

        do {
            _ = try await client.clearQueue(
                connection: connection
            )

            queueState = try await client.queueState(
                connection: connection
            )

            queueMessage = "Queue cleared."

            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)
        } catch {
            queueMessage = error.localizedDescription

            UINotificationFeedbackGenerator()
                .notificationOccurred(.error)
        }
    }

    func removePairing() {
        connection = nil
        printerOnline = false
        printerStatus = "Not paired"
        queueState = nil
        queueMessage = "Pair this iPhone to use the queue."
        UserDefaults.standard.removeObject(forKey: connectionKey)
        showingPairing = true
        message = "Pairing removed."
    }

    private func queueContentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "csv":
            return "text/csv"
        case "tsv":
            return "text/tab-separated-values"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ods":
            return "application/vnd.oasis.opendocument.spreadsheet"
        default:
            return "text/plain"
        }
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
