import SwiftUI
import AppKit

struct MenuBarView: View {
    @StateObject private var dataManager = UsageDataManager.shared
    @StateObject private var authManager = AuthenticationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Usage Tracker")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task {
                        await dataManager.refreshAll()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Service Cards - Always show all three services
            ScrollView {
                VStack(spacing: 12) {
                    // Claude
                    ServiceRowView(
                        service: .claude,
                        isAuthenticated: authManager.isClaudeAuthenticated,
                        metrics: dataManager.metrics[.claude]
                    )

                    // OpenAI
                    ServiceRowView(
                        service: .openai,
                        isAuthenticated: authManager.isOpenAIAuthenticated,
                        metrics: dataManager.metrics[.openai]
                    )

                    // Cursor - Special case: No API available
                    CursorServiceRow()
                }
                .padding()
            }

            Divider()

            // Footer Actions
            VStack(spacing: 8) {
                Button("Settings") {
                    if #available(macOS 13.0, *) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } else {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .frame(width: 320, height: 500)
    }
}

// MARK: - Service Row View

struct ServiceRowView: View {
    let service: ServiceType
    let isAuthenticated: Bool
    let metrics: UsageMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: service.iconName)
                    .foregroundColor(headerColor)
                Text(service.displayName)
                    .font(.headline)
                Spacer()

                if isAuthenticated {
                    if let metrics = metrics {
                        StatusIndicator(status: metrics.overallStatus)
                    }
                } else {
                    Button(action: openSettings) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                            Text("Configure")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if isAuthenticated, let metrics = metrics {
                Divider()

                // Show usage data
                if let sessionLimit = metrics.sessionLimit {
                    LimitRow(title: "Session", limit: sessionLimit)
                }

                if let weeklyLimit = metrics.weeklyLimit {
                    LimitRow(title: "Weekly", limit: weeklyLimit)
                }

                if let codeReviewLimit = metrics.codeReviewLimit {
                    LimitRow(title: "Code Review", limit: codeReviewLimit)
                }

                Text("Updated: \(formatDate(metrics.lastUpdated))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !isAuthenticated {
                Text("Not configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var headerColor: Color {
        if isAuthenticated, let metrics = metrics {
            return colorForStatus(metrics.overallStatus)
        }
        return .gray
    }

    private func colorForStatus(_ status: UsageStatus) -> Color {
        switch status {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func openSettings() {
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

// MARK: - Cursor Service Row (Special - No API)

struct CursorServiceRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: ServiceType.cursor.iconName)
                    .foregroundColor(.gray)
                Text(ServiceType.cursor.displayName)
                    .font(.headline)
                Spacer()

                Button(action: {
                    CursorService.shared.openTweetRequest()
                }) {
                    HStack(spacing: 4) {
                        Text("𝕏")
                            .font(.system(size: 12, weight: .bold))
                        Text("Post")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Post on X to request Cursor usage API")
            }

            HStack {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.orange)
                Text("Not available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Cursor doesn't provide a usage API yet")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Reusable Components

struct ServiceCard: View {
    let metrics: UsageMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: metrics.service.iconName)
                    .foregroundColor(colorForStatus(metrics.overallStatus))
                Text(metrics.service.displayName)
                    .font(.headline)
                Spacer()
                StatusIndicator(status: metrics.overallStatus)
            }

            Divider()

            if let sessionLimit = metrics.sessionLimit {
                LimitRow(title: "Session", limit: sessionLimit)
            }

            if let weeklyLimit = metrics.weeklyLimit {
                LimitRow(title: "Weekly", limit: weeklyLimit)
            }

            if let codeReviewLimit = metrics.codeReviewLimit {
                LimitRow(title: "Code Review", limit: codeReviewLimit)
            }

            Text("Updated: \(formatDate(metrics.lastUpdated))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func colorForStatus(_ status: UsageStatus) -> Color {
        switch status {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct LimitRow: View {
    let title: String
    let limit: UsageLimit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(limit.percentage))%")
                    .font(.subheadline)
                    .bold()
            }

            ProgressView(value: limit.used, total: limit.total)
                .tint(colorForStatus(limit.statusColor))

            HStack {
                Text("\(formatNumber(limit.used)) / \(formatNumber(limit.total))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let resetTime = limit.resetTime {
                    Text("Resets: \(formatResetTime(resetTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
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

    private func formatNumber(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }

    private func formatResetTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StatusIndicator: View {
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
