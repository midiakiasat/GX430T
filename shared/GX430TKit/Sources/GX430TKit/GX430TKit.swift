import Foundation

public enum GX430TPrintKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case code128
    case code39
    case qr

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .text: return "Text"
        case .code128: return "Code 128"
        case .code39: return "Code 39"
        case .qr: return "QR"
        }
    }

    public var symbol: String {
        switch self {
        case .text: return "textformat"
        case .code128, .code39: return "barcode"
        case .qr: return "qrcode"
        }
    }
}

public struct GX430THostInfo: Codable, Sendable {
    public let service: String
    public let protocolVersion: Int
    public let hostName: String
    public let port: Int
    public let authentication: String
    public let pairingEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case service
        case protocolVersion = "protocol"
        case hostName
        case port
        case authentication
        case pairingEnabled
    }
}

public struct GX430TStatusResponse: Codable, Sendable {
    public let service: String
    public let protocolVersion: Int
    public let printerOnline: Bool
    public let statusOutput: String

    enum CodingKeys: String, CodingKey {
        case service
        case protocolVersion = "protocol"
        case printerOnline
        case statusOutput
    }
}

public struct GX430TPairResponse: Codable, Sendable {
    public let paired: Bool
    public let protocolVersion: Int
    public let hostName: String
    public let token: String

    enum CodingKeys: String, CodingKey {
        case paired
        case protocolVersion = "protocol"
        case hostName
        case token
    }
}

public struct GX430TPrintResponse: Codable, Sendable {
    public let jobId: String
    public let accepted: Bool
    public let result: String
}

public struct GX430TPrintRequest: Codable, Sendable {
    public let kind: GX430TPrintKind
    public let value: String
    public let copies: Int

    public init(kind: GX430TPrintKind, value: String, copies: Int) {
        self.kind = kind
        self.value = value
        self.copies = copies
    }
}

public struct GX430TStoredConnection: Codable, Sendable {
    public let hostURL: URL
    public let hostName: String
    public let token: String
    public let protocolVersion: Int
    public let deviceName: String

    public init(
        hostURL: URL,
        hostName: String,
        token: String,
        protocolVersion: Int,
        deviceName: String
    ) {
        self.hostURL = hostURL
        self.hostName = hostName
        self.token = token
        self.protocolVersion = protocolVersion
        self.deviceName = deviceName
    }
}

public enum GX430TClientError: LocalizedError {
    case invalidHost
    case invalidPairingCode
    case invalidContent
    case invalidCopies
    case protocolMismatch
    case unauthorized
    case server(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidHost:
            return "Enter a valid GX430T Print Host address."
        case .invalidPairingCode:
            return "Enter the six-digit pairing code."
        case .invalidContent:
            return "Enter something to print."
        case .invalidCopies:
            return "Copies must be between 1 and 999."
        case .protocolMismatch:
            return "The app and Print Host versions are incompatible."
        case .unauthorized:
            return "This device is not authorized. Pair it again."
        case .server(let message):
            return message
        case .invalidResponse:
            return "The Print Host returned an invalid response."
        }
    }
}

public actor GX430TNetworkClient {
    public static let protocolVersion = 1

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func normalizeHost(_ value: String) throws -> URL {
        var clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            throw GX430TClientError.invalidHost
        }

        if !clean.contains("://") {
            clean = "http://\(clean)"
        }

        guard var components = URLComponents(string: clean) else {
            throw GX430TClientError.invalidHost
        }

        if components.port == nil {
            components.port = 43043
        }

        guard
            let url = components.url,
            let scheme = url.scheme,
            ["http", "https"].contains(scheme.lowercased())
        else {
            throw GX430TClientError.invalidHost
        }

        return url
    }

    public func info(hostURL: URL) async throws -> GX430THostInfo {
        let request = URLRequest(url: hostURL.appending(path: "v1/info"))
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let info = try decoder.decode(GX430THostInfo.self, from: data)

        guard info.protocolVersion == Self.protocolVersion else {
            throw GX430TClientError.protocolMismatch
        }

        return info
    }

    public func pair(
        hostURL: URL,
        pairingCode: String,
        deviceName: String
    ) async throws -> GX430TStoredConnection {
        let cleanCode = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanCode.count == 6, cleanCode.allSatisfy(\.isNumber) else {
            throw GX430TClientError.invalidPairingCode
        }

        var request = URLRequest(url: hostURL.appending(path: "v1/pair"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode([
            "pairingCode": cleanCode,
            "clientName": deviceName
        ])

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let payload = try decoder.decode(GX430TPairResponse.self, from: data)

        guard payload.paired else {
            throw GX430TClientError.invalidResponse
        }

        guard payload.protocolVersion == Self.protocolVersion else {
            throw GX430TClientError.protocolMismatch
        }

        guard payload.token.count == 64 else {
            throw GX430TClientError.invalidResponse
        }

        return GX430TStoredConnection(
            hostURL: hostURL,
            hostName: payload.hostName,
            token: payload.token,
            protocolVersion: payload.protocolVersion,
            deviceName: deviceName
        )
    }

    public func status(
        connection: GX430TStoredConnection
    ) async throws -> GX430TStatusResponse {
        var request = URLRequest(
            url: connection.hostURL.appending(path: "v1/status")
        )
        request.setValue(
            "Bearer \(connection.token)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let payload = try decoder.decode(
            GX430TStatusResponse.self,
            from: data
        )

        guard payload.protocolVersion == Self.protocolVersion else {
            throw GX430TClientError.protocolMismatch
        }

        return payload
    }

    public func print(
        connection: GX430TStoredConnection,
        request printRequest: GX430TPrintRequest
    ) async throws -> GX430TPrintResponse {
        let cleanValue = printRequest.value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanValue.isEmpty else {
            throw GX430TClientError.invalidContent
        }

        guard (1...999).contains(printRequest.copies) else {
            throw GX430TClientError.invalidCopies
        }

        let sanitized = GX430TPrintRequest(
            kind: printRequest.kind,
            value: cleanValue,
            copies: printRequest.copies
        )

        var request = URLRequest(
            url: connection.hostURL.appending(path: "v1/print")
        )
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(
            "Bearer \(connection.token)",
            forHTTPHeaderField: "Authorization"
        )
        request.httpBody = try encoder.encode(sanitized)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let payload = try decoder.decode(
            GX430TPrintResponse.self,
            from: data
        )

        guard payload.accepted else {
            throw GX430TClientError.server(payload.result)
        }

        return payload
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GX430TClientError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            return
        case 401:
            throw GX430TClientError.unauthorized
        default:
            if
                let object = try? JSONSerialization.jsonObject(with: data),
                let dictionary = object as? [String: Any],
                let detail = dictionary["detail"] as? String
            {
                throw GX430TClientError.server(detail)
            }

            if
                let object = try? JSONSerialization.jsonObject(with: data),
                let dictionary = object as? [String: Any],
                let error = dictionary["error"] as? String
            {
                throw GX430TClientError.server(error)
            }

            throw GX430TClientError.server(
                "Print Host returned HTTP \(http.statusCode)."
            )
        }
    }
}
