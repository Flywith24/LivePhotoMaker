import Foundation

struct UpdateCheckResult: Sendable {
    let currentVersion: String
    let latestVersion: String
    let releaseURL: URL?

    var hasUpdate: Bool {
        Self.compareVersions(latestVersion, currentVersion) == .orderedDescending
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0

            if leftValue > rightValue { return .orderedDescending }
            if leftValue < rightValue { return .orderedAscending }
        }

        return .orderedSame
    }
}

enum UpdateCheckError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        "无法检查更新。"
    }
}

final class UpdateChecker: Sendable {
    func check() async throws -> UpdateCheckResult {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let url = URL(string: "https://api.github.com/repos/Flywith24/LivePhotoMaker/releases/latest")!
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else {
            throw UpdateCheckError.invalidResponse
        }

        let releaseURL = (json["html_url"] as? String).flatMap(URL.init(string:))
        return UpdateCheckResult(
            currentVersion: currentVersion,
            latestVersion: tagName,
            releaseURL: releaseURL
        )
    }
}
