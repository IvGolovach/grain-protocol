import Foundation

public enum FoodAnalysisBrokerClientError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidPayload(String)
    case invalidResponse
    case httpStatus(Int)
    case unsafeCandidate(String)

    public var description: String {
        switch self {
        case .invalidPayload(let reason):
            return "invalid payload: \(reason)"
        case .invalidResponse:
            return "invalid response"
        case .httpStatus(let statusCode):
            return "broker returned HTTP \(statusCode)"
        case .unsafeCandidate(let reason):
            return "unsafe candidate: \(reason)"
        }
    }
}

public struct FoodAnalysisBrokerClient: FoodAnalysisClient {
    private let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
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

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(Self.requestEnvelope(photoPayload: photoPayload))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodAnalysisBrokerClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FoodAnalysisBrokerClientError.httpStatus(httpResponse.statusCode)
        }

        let candidate = try decodeCandidate(from: data)
        guard candidate.userConfirmationRequired else {
            throw FoodAnalysisBrokerClientError.unsafeCandidate("broker response must require user confirmation")
        }
        return candidate
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
