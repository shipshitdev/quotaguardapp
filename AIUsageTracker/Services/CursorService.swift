import Foundation
import AppKit

class CursorService {
    static let shared = CursorService()

    private init() {}

    // Cursor does not provide a public usage API
    // This service provides a way to request the feature via Twitter

    static let repoURL = "https://github.com/agenticindiedev/ai-usage-tracker"
    static let tweetText = "Hey @cursor_ai I'm using this open-source AI usage tracker and would love to track my Cursor usage too! Any plans to expose a billing/usage API?"

    static var tweetURL: URL? {
        guard let encodedText = tweetText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedURL = repoURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://twitter.com/intent/tweet?text=\(encodedText)&url=\(encodedURL)")
    }

    func openTweetRequest() {
        guard let url = CursorService.tweetURL else { return }
        NSWorkspace.shared.open(url)
    }

    // This method exists for compatibility but will always throw
    func fetchUsageMetrics() async throws -> UsageMetrics {
        throw ServiceError.apiError("Cursor does not provide a public usage API. Please tweet @cursor_ai to request this feature!")
    }
}
