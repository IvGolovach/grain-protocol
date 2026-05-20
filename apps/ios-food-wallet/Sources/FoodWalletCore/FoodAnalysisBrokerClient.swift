import Foundation

public enum FoodAnalysisBrokerClientError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidPayload(String)
    case invalidResponse
    case httpStatus(Int)
    case brokerError(code: String, message: String, status: Int)
    case requestTimedOut
    case networkUnavailable
    case unsafeCandidate(String)

    public var description: String {
        switch self {
        case .invalidPayload(let reason):
            return "invalid payload: \(reason)"
        case .invalidResponse:
            return "invalid response"
        case .httpStatus(let statusCode):
            return "broker returned HTTP \(statusCode)"
        case let .brokerError(code, message, status):
            return "broker returned \(code) HTTP \(status): \(message)"
        case .requestTimedOut:
            return "analysis request timed out"
        case .networkUnavailable:
            return "network unavailable"
        case .unsafeCandidate(let reason):
            return "unsafe candidate: \(reason)"
        }
    }
}

public struct FoodAnalysisBrokerClient: FoodAnalysisClient, BrokerFoodSearchClient {
    private let analysisEndpoint: URL
    private let searchEndpoint: URL
    private let session: URLSession

    public init(endpoint: URL, session: URLSession = .shared) {
        self.analysisEndpoint = endpoint
        self.searchEndpoint = Self.derivedSearchEndpoint(from: endpoint)
        self.session = session
    }

    public init(analysisEndpoint: URL, searchEndpoint: URL, session: URLSession = .shared) {
        self.analysisEndpoint = analysisEndpoint
        self.searchEndpoint = searchEndpoint
        self.session = session
    }

    public init(baseURL: URL, session: URLSession = .shared) {
        self.analysisEndpoint = Self.analysisEndpoint(from: baseURL)
        self.searchEndpoint = Self.searchEndpoint(from: baseURL)
        self.session = session
    }

    public func estimate(example: FoodCaptureExample) async throws -> FoodAnalysisCandidate {
        throw FoodAnalysisBrokerClientError.invalidPayload("broker analysis requires a transient photo payload")
    }

    public func estimate(photo: CapturedMealPhoto) async throws -> FoodAnalysisCandidate {
        throw FoodAnalysisBrokerClientError.invalidPayload("broker analysis requires JPEG bytes for photo \(photo.id)")
    }

    public func estimate(photoPayload: TransientMealPhotoPayload) async throws -> FoodAnalysisCandidate {
        try validate(photoPayload: photoPayload)

        var request = URLRequest(url: analysisEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(Self.requestEnvelope(photoPayload: photoPayload))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Self.mapTransportError(error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisBrokerClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw Self.decodeBrokerError(from: data, status: httpResponse.statusCode)
        }

        let candidate = try decodeCandidate(from: data)
        guard candidate.userConfirmationRequired else {
            throw FoodAnalysisBrokerClientError.unsafeCandidate("broker response must require user confirmation")
        }
        return candidate
    }

    public func searchFood(_ request: BrokerFoodSearchRequest) async throws -> [BrokerFoodSearchResult] {
        var urlRequest = URLRequest(url: searchEndpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 20
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw Self.mapTransportError(error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisBrokerClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw Self.decodeBrokerError(from: data, status: httpResponse.statusCode)
        }

        let envelope = try JSONDecoder().decode(BrokerFoodSearchEnvelope.self, from: data)
        guard envelope.ok else {
            throw FoodAnalysisBrokerClientError.invalidResponse
        }
        for result in envelope.results where !result.userConfirmationRequired {
            throw FoodAnalysisBrokerClientError.unsafeCandidate("broker search result must require user confirmation")
        }
        return envelope.results
    }

    private func validate(photoPayload: TransientMealPhotoPayload) throws {
        guard photoPayload.photo.contentType == "image/jpeg" else {
            throw FoodAnalysisBrokerClientError.invalidPayload("content type must be image/jpeg")
        }
        guard photoPayload.byteCount > 0 else {
            throw FoodAnalysisBrokerClientError.invalidPayload("JPEG bytes are empty")
        }
    }

    private static func requestEnvelope(photoPayload: TransientMealPhotoPayload) -> BrokerRequestEnvelope {
        let encoded = photoPayload.withJPEGData { jpegData in
            jpegData.base64EncodedString()
        }
        return BrokerRequestEnvelope(
            request_id: UUID().uuidString,
            capture_id: photoPayload.photo.id,
            client: BrokerClient(platform: "ios"),
            photo: BrokerPhoto(
                media_type: photoPayload.photo.contentType,
                bytes_b64: encoded,
                metadata: photoPayload.photo
            )
        )
    }

    private func decodeCandidate(from data: Data) throws -> FoodAnalysisCandidate {
        let decoder = JSONDecoder()
        if let candidate = try? decoder.decode(FoodAnalysisCandidate.self, from: data) {
            return candidate
        }

        let envelope = try decoder.decode(BrokerResponseEnvelope.self, from: data)
        guard envelope.ok, let candidate = envelope.candidate else {
            throw FoodAnalysisBrokerClientError.invalidResponse
        }
        return candidate
    }

    private static func decodeBrokerError(from data: Data, status: Int) -> FoodAnalysisBrokerClientError {
        if let envelope = try? JSONDecoder().decode(BrokerErrorEnvelope.self, from: data) {
            return .brokerError(code: envelope.error.code, message: envelope.error.message, status: status)
        }
        return .httpStatus(status)
    }

    private static func mapTransportError(_ error: Error) -> FoodAnalysisBrokerClientError {
        guard let urlError = error as? URLError else {
            return .invalidResponse
        }
        switch urlError.code {
        case .timedOut:
            return .requestTimedOut
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .networkUnavailable
        default:
            return .invalidResponse
        }
    }

    private static func analysisEndpoint(from endpoint: URL) -> URL {
        if endpoint.path == "" || endpoint.path == "/" {
            return endpoint.appendingPathComponent("v1/food/analyze-photo")
        }
        return endpoint
    }

    private static func searchEndpoint(from endpoint: URL) -> URL {
        if endpoint.path == "" || endpoint.path == "/" {
            return endpoint.appendingPathComponent("v1/food/search")
        }
        return endpoint
    }

    private static func derivedSearchEndpoint(from endpoint: URL) -> URL {
        let path = endpoint.path
        guard path.hasSuffix("/analyze-photo") else {
            return searchEndpoint(from: endpoint)
        }
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.path = String(path.dropLast("/analyze-photo".count)) + "/search"
        return components?.url ?? endpoint
    }
}

private struct BrokerRequestEnvelope: Encodable {
    var request_id: String
    var capture_id: String
    var client: BrokerClient
    var photo: BrokerPhoto
}

private struct BrokerClient: Encodable {
    var platform: String
}

private struct BrokerPhoto: Encodable {
    var media_type: String
    var bytes_b64: String
    var metadata: CapturedMealPhoto
}

private struct BrokerResponseEnvelope: Decodable {
    var ok: Bool
    var candidate: FoodAnalysisCandidate?
}

private struct BrokerErrorEnvelope: Decodable {
    var ok: Bool
    var error: BrokerErrorBody
}

private struct BrokerErrorBody: Decodable {
    var code: String
    var message: String
}
