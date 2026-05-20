import Compression
import CryptoKit
import Foundation
import GrainFoodWallet

public enum FoodWalletProtocolQRCodeFactory {
    private static let gr1Prefix = "GR1:"
    private static let maxCoseBytes = 16 * 1024
    private static let base45Alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:".utf8)

    public static func qrText(recipe: SavedFoodRecipe) throws -> String {
        let payload = try FoodWalletQRFactory.payload(recipe: recipe)
        let payloadText = try FoodWalletQRFactory.payloadText(payload)
        return try issueGR1(
            title: recipe.title,
            servingGrams: recipe.totalGrams,
            kcal: recipe.totalKcal,
            varianceKcal: max(1, Int64((Double(recipe.totalKcal) * 0.08).rounded())),
            macronutrients: recipe.macronutrients,
            payloadText: payloadText
        )
    }

    public static func qrText(personalFood: PersonalFoodIngredient) throws -> String {
        let payload = try FoodWalletQRFactory.payload(personalFood: personalFood)
        let payloadText = try FoodWalletQRFactory.payloadText(payload)
        let servingGrams = max(1, Int64(personalFood.sourceServingGrams.rounded()))
        let scale = Double(servingGrams) / 100
        return try issueGR1(
            title: personalFood.name,
            servingGrams: servingGrams,
            kcal: personalFood.sourceServingKcal,
            varianceKcal: max(1, Int64((Double(personalFood.sourceServingKcal) * 0.08).rounded())),
            macronutrients: personalFood.macronutrientsPer100Grams.scaled(by: scale),
            payloadText: payloadText
        )
    }

    public static func payload(fromGR1 text: String) throws -> FoodWalletQRPayload {
        let decoded = try decodeMealMarkPayload(fromGR1: text)
        return try FoodWalletQRFactory.payload(from: decoded.payloadText)
    }

    private static func issueGR1(
        title: String,
        servingGrams: Int64,
        kcal: Int64,
        varianceKcal: Int64,
        macronutrients: MealMacronutrients,
        payloadText: String
    ) throws -> String {
        let signingKey = Curve25519.Signing.PrivateKey()
        let publicKey = signingKey.publicKey.rawRepresentation
        let trustPubB64 = publicKey.base64EncodedString()
        let kid = Data(SHA256.hash(data: publicKey).prefix(16))
        let protected = Cbor.map([
            (.unsigned(1), .negative(-19)),
            (.unsigned(4), .bytes(kid)),
        ])
        let protectedBytes = protected.encoded()
        let payload = servingOfferPayload(
            title: title,
            issuerKid: kid,
            servingGrams: servingGrams,
            kcal: kcal,
            varianceKcal: varianceKcal,
            macronutrients: macronutrients,
            payloadText: payloadText,
            trustPubB64: trustPubB64
        )
        let payloadBytes = payload.encoded()
        let sigStructure = Cbor.array([
            .text("Signature1"),
            .bytes(protectedBytes),
            .bytes(Data()),
            .bytes(payloadBytes),
        ]).encoded()
        let signature = try signingKey.signature(for: sigStructure)
        let cose = Cbor.array([
            .bytes(protectedBytes),
            .map([]),
            .bytes(payloadBytes),
            .bytes(signature),
        ]).encoded()
        let compressed = try zlib(cose, operation: COMPRESSION_STREAM_ENCODE, maxOutputBytes: maxCoseBytes * 2)
        return gr1Prefix + base45Encode(compressed)
    }

    private static func servingOfferPayload(
        title: String,
        issuerKid: Data,
        servingGrams: Int64,
        kcal: Int64,
        varianceKcal: Int64,
        macronutrients: MealMacronutrients,
        payloadText: String,
        trustPubB64: String
    ) -> Cbor {
        .map([
            (.text("v"), .unsigned(1)),
            (.text("t"), .text("ServingOffer")),
            (.text("issuer_kid"), .bytes(issuerKid)),
            (.text("serving_g"), .unsigned(UInt64(max(1, servingGrams)))),
            (.text("mean"), nutrients(
                kcal: kcal,
                fat: macronutrients.fatGrams,
                carbohydrate: macronutrients.carbohydrateGrams,
                protein: macronutrients.proteinGrams
            )),
            (.text("var"), nutrients(
                kcal: varianceKcal,
                fat: max(0, macronutrients.fatGrams * 0.1),
                carbohydrate: max(0, macronutrients.carbohydrateGrams * 0.1),
                protein: max(0, macronutrients.proteinGrams * 0.1)
            )),
            (.text("ext"), .map([
                (.text("mealmark"), .map([
                    (.text("schema"), .text("grain.food-wallet.qr.v1")),
                    (.text("issuer_label"), .text("MealMark self-issued")),
                    (.text("public_key_alg"), .text("ed25519")),
                    (.text("trust_pub_b64"), .text(trustPubB64)),
                    (.text("title"), .text(title)),
                    (.text("payload_json"), .text(payloadText)),
                ])),
            ])),
        ])
    }

    private static func nutrients(kcal: Int64, fat: Double, carbohydrate: Double, protein: Double) -> Cbor {
        .map([
            (.text("kcal"), .unsigned(UInt64(max(0, kcal)))),
            (.text("fat_g"), .unsigned(UInt64(max(0, fat.rounded())))),
            (.text("carb_g"), .unsigned(UInt64(max(0, carbohydrate.rounded())))),
            (.text("protein_g"), .unsigned(UInt64(max(0, protein.rounded())))),
        ])
    }

    private static func decodeMealMarkPayload(fromGR1 text: String) throws -> (payloadText: String, trustPubB64: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(gr1Prefix) else {
            throw FoodWalletQRImportError.invalidPayload
        }
        let encoded = String(trimmed.dropFirst(gr1Prefix.count))
        let compressed = try base45Decode(encoded)
        let coseBytes = try zlib(compressed, operation: COMPRESSION_STREAM_DECODE, maxOutputBytes: maxCoseBytes)
        var coseParser = CborParser(data: coseBytes)
        let cose = try coseParser.parseSingle()
        guard case let .array(coseItems) = cose,
              coseItems.count == 4,
              case let .bytes(protectedBytes) = coseItems[0],
              case .map = coseItems[1],
              case let .bytes(payloadBytes) = coseItems[2],
              case let .bytes(signatureBytes) = coseItems[3] else {
            throw FoodWalletQRImportError.invalidPayload
        }
        var protectedParser = CborParser(data: protectedBytes)
        let protected = try protectedParser.parseSingle()
        guard protected.mapValue(for: Cbor.unsigned(1)) == Cbor.negative(-19),
              case let .bytes(protectedKid)? = protected.mapValue(for: Cbor.unsigned(4)) else {
            throw FoodWalletQRImportError.invalidPayload
        }
        var payloadParser = CborParser(data: payloadBytes)
        let payload = try payloadParser.parseSingle()
        guard case let .bytes(payloadKid)? = payload.mapValue(for: Cbor.text("issuer_kid")),
              payloadKid == protectedKid,
              case let .map(ext)? = payload.mapValue(for: Cbor.text("ext")),
              let mealmark = Cbor.map(ext).mapValue(for: Cbor.text("mealmark")),
              mealmark.mapValue(for: Cbor.text("schema")) == Cbor.text("grain.food-wallet.qr.v1"),
              case let .text(trustPubB64)? = mealmark.mapValue(for: Cbor.text("trust_pub_b64")),
              case let .text(payloadText)? = mealmark.mapValue(for: Cbor.text("payload_json")) else {
            throw FoodWalletQRImportError.protocolServingOfferRequiresTrust
        }
        guard let publicKeyBytes = Data(base64Encoded: trustPubB64),
              publicKeyBytes.count == 32,
              Data(SHA256.hash(data: publicKeyBytes).prefix(16)) == protectedKid else {
            throw FoodWalletQRImportError.integrityMismatch
        }
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyBytes)
        let sigStructure = Cbor.array([
            .text("Signature1"),
            .bytes(protectedBytes),
            .bytes(Data()),
            .bytes(payloadBytes),
        ]).encoded()
        guard publicKey.isValidSignature(signatureBytes, for: sigStructure) else {
            throw FoodWalletQRImportError.integrityMismatch
        }
        return (payloadText, trustPubB64)
    }

    private static func zlib(_ data: Data, operation: compression_stream_operation, maxOutputBytes: Int) throws -> Data {
        var srcByte: UInt8 = 0
        var dstByte: UInt8 = 0
        var stream = withUnsafeMutablePointer(to: &dstByte) { dst in
            withUnsafePointer(to: &srcByte) { src in
                compression_stream(dst_ptr: dst, dst_size: 0, src_ptr: src, src_size: 0, state: nil)
            }
        }
        let status = compression_stream_init(&stream, operation, COMPRESSION_ZLIB)
        guard status != COMPRESSION_STATUS_ERROR else {
            throw FoodWalletQRImportError.invalidPayload
        }
        defer {
            compression_stream_destroy(&stream)
        }

        return try data.withUnsafeBytes { sourceBuffer in
            guard let source = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return Data()
            }
            stream.src_ptr = source
            stream.src_size = data.count
            var output = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let result = buffer.withUnsafeMutableBufferPointer { destination in
                    stream.dst_ptr = destination.baseAddress!
                    stream.dst_size = destination.count
                    return compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                }
                let written = buffer.count - stream.dst_size
                output.append(buffer, count: written)
                if output.count > maxOutputBytes {
                    throw FoodWalletQRImportError.invalidPayload
                }
                switch result {
                case COMPRESSION_STATUS_OK:
                    continue
                case COMPRESSION_STATUS_END:
                    return output
                default:
                    throw FoodWalletQRImportError.invalidPayload
                }
            }
        }
    }

    private static func base45Encode(_ data: Data) -> String {
        var output = [UInt8]()
        var index = 0
        let bytes = Array(data)
        while index + 1 < bytes.count {
            let value = Int(bytes[index]) * 256 + Int(bytes[index + 1])
            output.append(base45Alphabet[value % 45])
            output.append(base45Alphabet[(value / 45) % 45])
            output.append(base45Alphabet[value / (45 * 45)])
            index += 2
        }
        if index < bytes.count {
            let value = Int(bytes[index])
            output.append(base45Alphabet[value % 45])
            output.append(base45Alphabet[value / 45])
        }
        return String(decoding: output, as: UTF8.self)
    }

    private static func base45Decode(_ text: String) throws -> Data {
        var reverse: [UInt8: Int] = [:]
        for (index, character) in base45Alphabet.enumerated() {
            reverse[character] = index
        }
        let bytes = Array(text.utf8)
        guard bytes.count % 3 != 1 else {
            throw FoodWalletQRImportError.invalidPayload
        }
        var output = Data()
        var index = 0
        while index < bytes.count {
            if index + 2 < bytes.count {
                guard let c0 = reverse[bytes[index]],
                      let c1 = reverse[bytes[index + 1]],
                      let c2 = reverse[bytes[index + 2]] else {
                    throw FoodWalletQRImportError.invalidPayload
                }
                let value = c0 + c1 * 45 + c2 * 45 * 45
                guard value <= 0xffff else {
                    throw FoodWalletQRImportError.invalidPayload
                }
                output.append(UInt8(value / 256))
                output.append(UInt8(value % 256))
                index += 3
            } else {
                guard let c0 = reverse[bytes[index]],
                      let c1 = reverse[bytes[index + 1]] else {
                    throw FoodWalletQRImportError.invalidPayload
                }
                let value = c0 + c1 * 45
                guard value <= 0xff else {
                    throw FoodWalletQRImportError.invalidPayload
                }
                output.append(UInt8(value))
                index += 2
            }
        }
        return output
    }
}

private indirect enum Cbor: Equatable {
    case unsigned(UInt64)
    case negative(Int64)
    case bytes(Data)
    case text(String)
    case array([Cbor])
    case map([(Cbor, Cbor)])

    static func == (left: Cbor, right: Cbor) -> Bool {
        switch (left, right) {
        case let (.unsigned(leftValue), .unsigned(rightValue)):
            return leftValue == rightValue
        case let (.negative(leftValue), .negative(rightValue)):
            return leftValue == rightValue
        case let (.bytes(leftValue), .bytes(rightValue)):
            return leftValue == rightValue
        case let (.text(leftValue), .text(rightValue)):
            return leftValue == rightValue
        case let (.array(leftValues), .array(rightValues)):
            return leftValues == rightValues
        case let (.map(leftEntries), .map(rightEntries)):
            guard leftEntries.count == rightEntries.count else {
                return false
            }
            return zip(leftEntries, rightEntries).allSatisfy { leftEntry, rightEntry in
                leftEntry.0 == rightEntry.0 && leftEntry.1 == rightEntry.1
            }
        default:
            return false
        }
    }

    func encoded() -> Data {
        var output = Data()
        encode(into: &output)
        return output
    }

    func mapValue(for key: Cbor) -> Cbor? {
        guard case let .map(entries) = self else {
            return nil
        }
        return entries.first { $0.0 == key }?.1
    }

    private func encode(into output: inout Data) {
        switch self {
        case let .unsigned(value):
            encodeMajor(0, value, into: &output)
        case let .negative(value):
            encodeMajor(1, UInt64(-1 - value), into: &output)
        case let .bytes(data):
            encodeMajor(2, UInt64(data.count), into: &output)
            output.append(data)
        case let .text(text):
            let data = Data(text.utf8)
            encodeMajor(3, UInt64(data.count), into: &output)
            output.append(data)
        case let .array(items):
            encodeMajor(4, UInt64(items.count), into: &output)
            for item in items {
                item.encode(into: &output)
            }
        case let .map(entries):
            encodeMajor(5, UInt64(entries.count), into: &output)
            let encodedEntries = entries.map { key, value in
                (key.encoded(), value.encoded())
            }.sorted { left, right in
                if left.0.count != right.0.count {
                    return left.0.count < right.0.count
                }
                return left.0.lexicographicallyPrecedes(right.0)
            }
            for (keyData, valueData) in encodedEntries {
                output.append(keyData)
                output.append(valueData)
            }
        }
    }

    private func encodeMajor(_ major: UInt8, _ value: UInt64, into output: inout Data) {
        let prefix = major << 5
        if value < 24 {
            output.append(prefix | UInt8(value))
        } else if value <= UInt8.max {
            output.append(prefix | 24)
            output.append(UInt8(value))
        } else if value <= UInt16.max {
            output.append(prefix | 25)
            output.append(UInt8((value >> 8) & 0xff))
            output.append(UInt8(value & 0xff))
        } else if value <= UInt32.max {
            output.append(prefix | 26)
            for shift in stride(from: 24, through: 0, by: -8) {
                output.append(UInt8((value >> UInt64(shift)) & 0xff))
            }
        } else {
            output.append(prefix | 27)
            for shift in stride(from: 56, through: 0, by: -8) {
                output.append(UInt8((value >> UInt64(shift)) & 0xff))
            }
        }
    }
}

private struct CborParser {
    private let bytes: [UInt8]
    private var offset = 0

    init(data: Data) {
        self.bytes = Array(data)
    }

    mutating func parseSingle() throws -> Cbor {
        let value = try parseValue()
        guard offset == bytes.count else {
            throw FoodWalletQRImportError.invalidPayload
        }
        return value
    }

    private mutating func parseValue() throws -> Cbor {
        let initial = try readByte()
        let major = initial >> 5
        let additional = initial & 0x1f
        switch major {
        case 0:
            return .unsigned(try readLength(additional))
        case 1:
            let value = try readLength(additional)
            guard value <= UInt64(Int64.max) else {
                throw FoodWalletQRImportError.invalidPayload
            }
            return .negative(-1 - Int64(value))
        case 2:
            let length = try boundedLength(additional)
            return .bytes(try readData(length))
        case 3:
            let length = try boundedLength(additional)
            guard let text = String(data: try readData(length), encoding: .utf8) else {
                throw FoodWalletQRImportError.invalidPayload
            }
            return .text(text)
        case 4:
            let count = try boundedLength(additional)
            var values: [Cbor] = []
            values.reserveCapacity(count)
            for _ in 0..<count {
                values.append(try parseValue())
            }
            return .array(values)
        case 5:
            let count = try boundedLength(additional)
            var entries: [(Cbor, Cbor)] = []
            entries.reserveCapacity(count)
            for _ in 0..<count {
                let key = try parseValue()
                let value = try parseValue()
                entries.append((key, value))
            }
            return .map(entries)
        default:
            throw FoodWalletQRImportError.invalidPayload
        }
    }

    private mutating func boundedLength(_ additional: UInt8) throws -> Int {
        let value = try readLength(additional)
        guard value <= UInt64(Int.max) else {
            throw FoodWalletQRImportError.invalidPayload
        }
        return Int(value)
    }

    private mutating func readLength(_ additional: UInt8) throws -> UInt64 {
        switch additional {
        case 0...23:
            return UInt64(additional)
        case 24:
            return UInt64(try readByte())
        case 25:
            return try readFixed(count: 2)
        case 26:
            return try readFixed(count: 4)
        case 27:
            return try readFixed(count: 8)
        default:
            throw FoodWalletQRImportError.invalidPayload
        }
    }

    private mutating func readFixed(count: Int) throws -> UInt64 {
        guard offset + count <= bytes.count else {
            throw FoodWalletQRImportError.invalidPayload
        }
        var value: UInt64 = 0
        for _ in 0..<count {
            value = (value << 8) | UInt64(bytes[offset])
            offset += 1
        }
        return value
    }

    private mutating func readByte() throws -> UInt8 {
        guard offset < bytes.count else {
            throw FoodWalletQRImportError.invalidPayload
        }
        defer {
            offset += 1
        }
        return bytes[offset]
    }

    private mutating func readData(_ count: Int) throws -> Data {
        guard offset + count <= bytes.count else {
            throw FoodWalletQRImportError.invalidPayload
        }
        let slice = bytes[offset..<(offset + count)]
        offset += count
        return Data(slice)
    }
}
