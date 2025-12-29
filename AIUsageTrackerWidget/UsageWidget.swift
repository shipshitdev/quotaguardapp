import WidgetKit
import SwiftUI

// MARK: - Shared Types (duplicated for Widget target)

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case claude = "Claude"
    case openai = "OpenAI"
    case cursor = "Cursor"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "OpenAI"
        case .cursor: return "Cursor"
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "sparkles"
        case .openai: return "brain"
        case .cursor: return "cursorarrow.click"
        }
    }
}

enum UsageStatus {
    case good
    case warning
    case critical
}

struct UsageLimit: Codable, Equatable {
    let used: Double
    let total: Double
    let resetTime: Date?

    var percentage: Double {
        guard total > 0 else { return 0 }
        return min(100, max(0, (used / total) * 100))
    }

    var remaining: Double {
        return max(0, total - used)
    }

    var isNearLimit: Bool {
        return percentage >= 80
    }

    var isAtLimit: Bool {
        return percentage >= 100
    }

    var statusColor: UsageStatus {
        if isAtLimit {
            return .critical
        } else if isNearLimit {
            return .warning
        } else {
            return .good
        }
    }
}

struct UsageMetrics: Codable, Identifiable {
    let id: UUID
    let service: ServiceType
    let sessionLimit: UsageLimit?
    let weeklyLimit: UsageLimit?
    let codeReviewLimit: UsageLimit?
    let lastUpdated: Date

    init(
        service: ServiceType,
        sessionLimit: UsageLimit? = nil,
        weeklyLimit: UsageLimit? = nil,
        codeReviewLimit: UsageLimit? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = UUID()
        self.service = service
        self.sessionLimit = sessionLimit
        self.weeklyLimit = weeklyLimit
        self.codeReviewLimit = codeReviewLimit
        self.lastUpdated = lastUpdated
    }

    var overallStatus: UsageStatus {
        let limits = [sessionLimit, weeklyLimit, codeReviewLimit].compactMap { $0 }
        guard !limits.isEmpty else { return .good }

        if limits.contains(where: { $0.isAtLimit }) {
            return .critical
        } else if limits.contains(where: { $0.isNearLimit }) {
            return .warning
        } else {
            return .good
        }
    }

    var hasData: Bool {
        return sessionLimit != nil || weeklyLimit != nil || codeReviewLimit != nil
    }
}

// MARK: - Shared Data Store (simplified for Widget)

class SharedDataStore {
    static let shared = SharedDataStore()

    private let suiteName = "group.com.agenticindiedev.aiusagetracker"
    private let metricsKey = "shared_metrics"

    private var defaults: UserDefaults? {
        return UserDefaults(suiteName: suiteName)
    }

    func loadMetrics() -> [ServiceType: UsageMetrics] {
        guard let defaults = defaults,
              let data = defaults.data(forKey: metricsKey) else {
            return [:]
        }

        do {
            let decoded = try JSONDecoder().decode([String: UsageMetrics].self, from: data)
            return decoded.reduce(into: [ServiceType: UsageMetrics]()) { result, pair in
                if let service = ServiceType(rawValue: pair.key) {
                    result[service] = pair.value
                }
            }
        } catch {
            return [:]
        }
    }
}

// MARK: - Widget

struct UsageWidget: Widget {
    let kind: String = "UsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageWidgetProvider()) { entry in
            UsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("AI Usage Tracker")
        .description("Track your Claude and OpenAI API usage")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct UsageWidgetEntry: TimelineEntry {
    let date: Date
    let metrics: [ServiceType: UsageMetrics]
}

struct UsageWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageWidgetEntry {
        UsageWidgetEntry(
            date: Date(),
            metrics: [:]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageWidgetEntry) -> Void) {
        let entry = UsageWidgetEntry(
            date: Date(),
            metrics: SharedDataStore.shared.loadMetrics()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageWidgetEntry>) -> Void) {
        let cachedMetrics = SharedDataStore.shared.loadMetrics()
        let entry = UsageWidgetEntry(
            date: Date(),
            metrics: cachedMetrics
        )

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct UsageWidgetEntryView: View {
    var entry: UsageWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: UsageWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Usage")
                .font(.headline)

            if let firstService = entry.metrics.keys.first,
               let metrics = entry.metrics[firstService] {
                ServiceCompactView(metrics: metrics)
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MediumWidgetView: View {
    let entry: UsageWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Usage Tracker")
                .font(.headline)

            if entry.metrics.isEmpty {
                Text("No services connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(entry.metrics.keys), id: \.self) { service in
                    if let metrics = entry.metrics[service] {
                        ServiceCompactView(metrics: metrics)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct LargeWidgetView: View {
    let entry: UsageWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Usage Tracker")
                .font(.title2)
                .bold()

            if entry.metrics.isEmpty {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("No services connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(Array(entry.metrics.keys), id: \.self) { service in
                    if let metrics = entry.metrics[service] {
                        ServiceDetailView(metrics: metrics)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ServiceCompactView: View {
    let metrics: UsageMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: metrics.service.iconName)
                    .foregroundColor(colorForStatus(metrics.overallStatus))
                Text(metrics.service.displayName)
                    .font(.subheadline)
                    .bold()
                Spacer()
                WidgetStatusIndicator(status: metrics.overallStatus)
            }

            if let weeklyLimit = metrics.weeklyLimit {
                HStack {
                    ProgressView(value: weeklyLimit.used, total: weeklyLimit.total)
                        .tint(colorForStatus(weeklyLimit.statusColor))
                    Text("\(Int(weeklyLimit.percentage))%")
                        .font(.caption)
                }
            }
        }
    }

    private func colorForStatus(_ status: UsageStatus) -> Color {
        switch status {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

struct ServiceDetailView: View {
    let metrics: UsageMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: metrics.service.iconName)
                    .foregroundColor(colorForStatus(metrics.overallStatus))
                Text(metrics.service.displayName)
                    .font(.headline)
                Spacer()
                WidgetStatusIndicator(status: metrics.overallStatus)
            }

            if let sessionLimit = metrics.sessionLimit {
                LimitDetailView(title: "Session", limit: sessionLimit)
            }

            if let weeklyLimit = metrics.weeklyLimit {
                LimitDetailView(title: "Weekly", limit: weeklyLimit)
            }

            if let codeReviewLimit = metrics.codeReviewLimit {
                LimitDetailView(title: "Code Review", limit: codeReviewLimit)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private func colorForStatus(_ status: UsageStatus) -> Color {
        switch status {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

struct LimitDetailView: View {
    let title: String
    let limit: UsageLimit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text("\(Int(limit.percentage))%")
                    .font(.caption)
                    .bold()
            }

            ProgressView(value: limit.used, total: limit.total)
                .tint(colorForStatus(limit.statusColor))

            Text("\(formatNumber(limit.used)) / \(formatNumber(limit.total))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func colorForStatus(_ status: UsageStatus) -> Color {
        switch status {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

struct WidgetStatusIndicator: View {
    let status: UsageStatus

    var body: some View {
        Circle()
            .fill(colorForStatus(status))
            .frame(width: 8, height: 8)
    }

    private func colorForStatus(_ status: UsageStatus) -> Color {
        switch status {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
