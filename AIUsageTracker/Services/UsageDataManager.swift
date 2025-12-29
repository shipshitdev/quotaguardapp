import Foundation
import Combine

@MainActor
class UsageDataManager: ObservableObject {
    static let shared = UsageDataManager()

    @Published var metrics: [ServiceType: UsageMetrics] = [:]
    @Published var isLoading: Bool = false
    @Published var lastError: Error?

    private let claudeService = ClaudeService.shared
    private let openaiService = OpenAIService.shared
    private let authManager = AuthenticationManager.shared

    private var refreshTimer: Timer?
    private let cacheKey = "cached_usage_metrics"
    private let sharedStore = SharedDataStore.shared

    private init() {
        loadCachedData()
        setupAutoRefresh()
    }

    func refreshAll() async {
        isLoading = true
        lastError = nil

        var newMetrics: [ServiceType: UsageMetrics] = [:]

        // Fetch Claude metrics
        if authManager.isClaudeAuthenticated {
            do {
                let metrics = try await claudeService.fetchUsageMetrics()
                newMetrics[.claude] = metrics
            } catch {
                lastError = error
                print("Failed to fetch Claude metrics: \(error)")
            }
        }

        // Fetch OpenAI metrics
        if authManager.isOpenAIAuthenticated {
            do {
                let metrics = try await openaiService.fetchUsageMetrics()
                newMetrics[.openai] = metrics
            } catch {
                lastError = error
                print("Failed to fetch OpenAI metrics: \(error)")
            }
        }

        // Note: Cursor doesn't have an API, so we don't fetch metrics for it

        metrics = newMetrics
        saveCachedData()
        sharedStore.saveMetrics(newMetrics)
        isLoading = false
    }

    func refresh(service: ServiceType) async {
        isLoading = true
        lastError = nil

        do {
            let newMetrics: UsageMetrics

            switch service {
            case .claude:
                guard authManager.isClaudeAuthenticated else {
                    throw ServiceError.notAuthenticated
                }
                newMetrics = try await claudeService.fetchUsageMetrics()
            case .openai:
                guard authManager.isOpenAIAuthenticated else {
                    throw ServiceError.notAuthenticated
                }
                newMetrics = try await openaiService.fetchUsageMetrics()
            case .cursor:
                throw ServiceError.apiError("Cursor does not provide a usage API")
            }

            metrics[service] = newMetrics
            saveCachedData()
            sharedStore.saveMetrics(metrics)
        } catch {
            lastError = error
            print("Failed to fetch \(service.displayName) metrics: \(error)")
        }

        isLoading = false
    }

    private func loadCachedData() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: UsageMetrics].self, from: data) else {
            return
        }

        metrics = decoded.reduce(into: [ServiceType: UsageMetrics]()) { result, pair in
            if let service = ServiceType(rawValue: pair.key) {
                result[service] = pair.value
            }
        }
    }

    private func saveCachedData() {
        let encoded = metrics.reduce(into: [String: UsageMetrics]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }

        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func setupAutoRefresh() {
        // Refresh every 15 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAll()
            }
        }
    }

    func getNextRefreshTime() -> Date? {
        // Find the earliest reset time across all metrics
        let resetTimes = metrics.values.compactMap { metrics -> Date? in
            let times = [
                metrics.sessionLimit?.resetTime,
                metrics.weeklyLimit?.resetTime,
                metrics.codeReviewLimit?.resetTime
            ].compactMap { $0 }
            return times.min()
        }

        return resetTimes.min()
    }
}
