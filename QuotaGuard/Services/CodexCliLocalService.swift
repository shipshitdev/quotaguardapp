import Foundation
import AppKit
import Combine

/// Service for fetching Codex CLI usage data from https://chatgpt.com/backend-api/wham/usage
/// Reads authentication token from browser cookies/keychain and calls the Codex CLI usage API.
/// Similar to ClaudeCodeLocalService, but for Codex CLI usage tracking.
/// 
/// The API endpoint returns usage data with:
/// - Primary window: 5-hour limit (18000 seconds)
/// - Secondary window: 7-day limit (604800 seconds)
/// - Code review rate limit: 7-day limit for code review features
class CodexCliLocalService: ObservableObject {
    static let shared = CodexCliLocalService()

    // API endpoint for Codex CLI usage
    private let usageEndpoint = "https://chatgpt.com/backend-api/wham/usage"
    
    private let keychainService = "chatgpt.com-codex-credentials"

    // URLSession with timeout configuration
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()

    @Published private(set) var hasAccess: Bool = false
    @Published private(set) var lastError: ServiceError?

    private init() {
        // Check if we have Codex CLI credentials on init
        checkAccess()
    }

    // MARK: - Keychain Access

    /// Get OAuth/session token from chatgpt.com keychain storage
    /// This reads the authentication token stored by the browser or Codex CLI
    /// 
    /// To get the token:
    /// 1. Open Safari and navigate to https://chatgpt.com/codex/settings/usage
    /// 2. Log in to your account
    /// 3. Open Developer Tools (Cmd+Option+I)
    /// 4. Go to Storage > Cookies > chatgpt.com
    /// 5. Find the session token cookie (common names:
    ///    - __Secure-next-auth.session-token
    ///    - __Secure-authjs.session-token
    ///    - chatgpt_session)
    /// 6. Copy the cookie value
    /// 7. Save it using saveAuthToken() method
    func getAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "codex_cli_token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    /// Alternative: Read session cookie from Safari cookies
    /// This attempts to read the session cookie directly from Safari's cookie storage
    private func getSessionCookieFromSafari() -> String? {
        // Safari stores cookies in ~/Library/Cookies/Cookies.binarycookies
        // However, accessing Safari cookies directly requires private APIs
        // For now, we'll rely on manual cookie extraction or keychain storage
        // Users can extract cookies manually from Safari DevTools and store them
        
        // TODO: Implement Safari cookie reading if needed
        // This would require using private APIs or cookie extraction tools
        return nil
    }

    /// Save authentication token to keychain
    /// Users can extract this token from chatgpt.com cookies (see getAuthToken help)
    func saveAuthToken(_ token: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else {
            return false
        }
        
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "codex_cli_token"
        ]
        
        // Delete existing item first
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "codex_cli_token",
            kSecValueData as String: tokenData
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        let success = status == errSecSuccess
        
        if success {
            checkAccess()
        }
        
        return success
    }
    
    /// Remove authentication token from keychain
    func removeAuthToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "codex_cli_token"
        ]
        
        SecItemDelete(query as CFDictionary)
        checkAccess()
    }

    /// Check and update access status
    func checkAccess() {
        if let _ = getAuthToken() {
            hasAccess = true
        } else {
            hasAccess = false
        }
    }

    // MARK: - Usage Fetching

    func fetchUsageMetrics() async throws -> UsageMetrics {
        guard let token = getAuthToken() else {
            let error = ServiceError.notAuthenticated
            await MainActor.run {
                self.lastError = error
                self.hasAccess = false
            }
            throw error
        }

        // The actual endpoint: https://chatgpt.com/backend-api/wham/usage
        guard let url = URL(string: usageEndpoint) else {
            throw ServiceError.apiError("Invalid usage endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Use Cookie header for authentication
        // The token should be the session cookie value from chatgpt.com
        // Common cookie names:
        // - __Secure-next-auth.session-token
        // - __Secure-authjs.session-token
        // Users should extract the full cookie string including name=value
        // If they only provide the value, we'll try common cookie names
        let cookieHeader: String
        if token.contains("=") {
            // User provided full cookie string (name=value)
            cookieHeader = token
        } else {
            // User provided just the value, try common cookie names
            cookieHeader = "__Secure-next-auth.session-token=\(token)"
        }
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        
        // Set user agent to match browser
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServiceError.apiError("Invalid response type")
            }

            print("[CodexCliLocalService] Usage response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                await MainActor.run {
                    self.hasAccess = false
                    self.lastError = ServiceError.notAuthenticated
                }
                throw ServiceError.notAuthenticated
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("[CodexCliLocalService] Usage error: \(errorMessage.prefix(200))")
                throw ServiceError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage.prefix(100))")
            }

            // Parse the response
            let rawResponse = String(data: data, encoding: .utf8) ?? "{}"
            print("[CodexCliLocalService] Raw response: \(rawResponse.prefix(500))")

            let decoder = JSONDecoder()
            // Note: Codex CLI API uses Unix timestamps (Int64), not ISO8601 dates
            
            // Decode the actual Codex CLI usage response
            let usageResponse = try decoder.decode(CodexCliUsageResponse.self, from: data)

            await MainActor.run {
                self.lastError = nil
                self.hasAccess = true
            }

            // Map the response to UsageMetrics
            // Primary window (5 hours = 18000 seconds) = session limit
            let primaryWindow = usageResponse.rateLimit.primaryWindow
            let sessionLimit = UsageLimit(
                used: primaryWindow.usedPercent,
                total: 100.0,
                resetTime: Date(timeIntervalSince1970: Double(primaryWindow.resetAt))
            )

            // Secondary window (7 days = 604800 seconds) = weekly limit
            let secondaryWindow = usageResponse.rateLimit.secondaryWindow
            let weeklyLimit = UsageLimit(
                used: secondaryWindow?.usedPercent ?? 0.0,
                total: 100.0,
                resetTime: secondaryWindow != nil ? Date(timeIntervalSince1970: Double(secondaryWindow!.resetAt)) : Date()
            )

            // Code review rate limit (7 days window) = code review limit
            var codeReviewLimit: UsageLimit? = nil
            if let codeReviewPrimary = usageResponse.codeReviewRateLimit?.primaryWindow {
                codeReviewLimit = UsageLimit(
                    used: codeReviewPrimary.usedPercent,
                    total: 100.0,
                    resetTime: Date(timeIntervalSince1970: Double(codeReviewPrimary.resetAt))
                )
            }

            return UsageMetrics(
                service: .openai, // Using .openai for now - may need to add .codexCli to ServiceType
                sessionLimit: sessionLimit,
                weeklyLimit: weeklyLimit,
                codeReviewLimit: codeReviewLimit
            )
        } catch let urlError as URLError {
            let errorMessage: String
            switch urlError.code {
            case .notConnectedToInternet:
                errorMessage = "No internet connection"
            case .cannotFindHost, .dnsLookupFailed:
                errorMessage = "DNS lookup failed"
            case .timedOut:
                errorMessage = "Request timed out"
            default:
                errorMessage = urlError.localizedDescription
            }
            let error = ServiceError.apiError(errorMessage)
            await MainActor.run { self.lastError = error }
            throw error
        } catch let error as ServiceError {
            throw error
        } catch let decodingError as DecodingError {
            print("[CodexCliLocalService] Decoding error: \(decodingError)")
            // If decoding fails, the API structure might be different
            // Log the raw response for debugging
            if let data = try? Data(contentsOf: URL(string: usageEndpoint)!) {
                let rawResponse = String(data: data, encoding: .utf8) ?? "{}"
                print("[CodexCliLocalService] Failed to decode response. Raw JSON: \(rawResponse)")
            }
            let serviceError = ServiceError.parsingError
            await MainActor.run { self.lastError = serviceError }
            throw serviceError
        } catch {
            let serviceError = ServiceError.parsingError
            await MainActor.run { self.lastError = serviceError }
            throw serviceError
        }
    }
}

// MARK: - Response Models

/// Response structure for Codex CLI usage API from https://chatgpt.com/backend-api/wham/usage
struct CodexCliUsageResponse: Codable {
    let planType: String
    let rateLimit: RateLimit
    let codeReviewRateLimit: CodeReviewRateLimit?
    let credits: Credits

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case codeReviewRateLimit = "code_review_rate_limit"
        case credits
    }
}

struct RateLimit: Codable {
    let allowed: Bool
    let limitReached: Bool
    let primaryWindow: LimitWindow
    let secondaryWindow: LimitWindow?

    enum CodingKeys: String, CodingKey {
        case allowed
        case limitReached = "limit_reached"
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

struct CodeReviewRateLimit: Codable {
    let allowed: Bool
    let limitReached: Bool
    let primaryWindow: LimitWindow
    let secondaryWindow: LimitWindow?

    enum CodingKeys: String, CodingKey {
        case allowed
        case limitReached = "limit_reached"
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

struct LimitWindow: Codable {
    let usedPercent: Double
    let limitWindowSeconds: Int
    let resetAfterSeconds: Int
    let resetAt: Int64

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case resetAfterSeconds = "reset_after_seconds"
        case resetAt = "reset_at"
    }
}

struct Credits: Codable {
    let hasCredits: Bool
    let unlimited: Bool
    let balance: Double?
    let approxLocalMessages: Int?
    let approxCloudMessages: Int?

    enum CodingKeys: String, CodingKey {
        case hasCredits = "has_credits"
        case unlimited
        case balance
        case approxLocalMessages = "approx_local_messages"
        case approxCloudMessages = "approx_cloud_messages"
    }
}
