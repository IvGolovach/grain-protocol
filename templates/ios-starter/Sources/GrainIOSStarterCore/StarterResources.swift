import Foundation

public enum StarterResources {
    public static let trustAnchorID = "fixture:primary"

    public static var trustAnchorBundleURL: URL {
        guard let url = Bundle.module.url(
            forResource: "TRUST-ANCHOR-BUNDLE-0001",
            withExtension: "json"
        ) else {
            preconditionFailure("SDK_ERR_IOS_STARTER_TRUST_BUNDLE_MISSING")
        }
        return url
    }

    public static var sampleQrString: String {
        guard let url = Bundle.module.url(forResource: "SAMPLE-GR1", withExtension: "txt"),
              let value = try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return ""
        }
        return value
    }
}
