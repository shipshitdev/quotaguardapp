import SwiftUI
import AppKit

struct MenuBarView: View {
    @StateObject private var dataManager = UsageDataManager.shared
    @StateObject private var authManager = AuthenticationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quota Guard")
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
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 320, height: 500)
    }
}

// MARK: - Service Row View

struct ServiceRowView: View {
    let service: ServiceType
    let isAuthenticated: Bool
    let metrics: UsageMetrics?

    @StateObject private var authManager = AuthenticationManager.shared
    @State private var isExpanded: Bool = false
    @State private var apiKeyInput: String = ""

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

                    // Show gear button to manage key when authenticated
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "gearshape")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                } else {
                    Button(action: { isExpanded.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: isExpanded ? "chevron.up" : "gearshape")
                            Text(isExpanded ? "Close" : "Configure")
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
            } else if !isAuthenticated && !isExpanded {
                Text("Not configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Inline settings section
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    if isAuthenticated {
                        // Show masked key and remove button
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API Key configured")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Button(action: {
                            removeApiKey()
                            isExpanded = false
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove Key")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    } else {
                        // Show input field for new key
                        Text(keyPlaceholder)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        SecureField("Paste API key here...", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)

                        HStack {
                            Button(action: {
                                saveApiKey()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Save")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(apiKeyInput.isEmpty)

                            Button(action: {
                                openHelpUrl()
                            }) {
                                HStack {
                                    Image(systemName: "questionmark.circle")
                                    Text("Help")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
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

    private var keyPlaceholder: String {
        switch service {
        case .claude:
            return "Admin API Key (sk-ant-admin...)"
        case .openai:
            return "Admin API Key"
        case .cursor:
            return ""
        }
    }

    private func saveApiKey() {
        switch service {
        case .claude:
            _ = authManager.setClaudeAdminKey(apiKeyInput)
        case .openai:
            _ = authManager.setOpenAIAdminKey(apiKeyInput)
        case .cursor:
            break
        }
        apiKeyInput = ""
        isExpanded = false
    }

    private func removeApiKey() {
        switch service {
        case .claude:
            authManager.removeClaudeAdminKey()
        case .openai:
            authManager.removeOpenAIAdminKey()
        case .cursor:
            break
        }
    }

    private func openHelpUrl() {
        let urlString: String
        switch service {
        case .claude:
            urlString = "https://console.anthropic.com/settings/admin-keys"
        case .openai:
            urlString = "https://platform.openai.com/settings/organization/admin-keys"
        case .cursor:
            return
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
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

// MARK: - Cursor Service Row (Special - No API)

struct CursorServiceRow: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Disabled card content with opacity
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: ServiceType.cursor.iconName)
                        .foregroundColor(.gray)
                    Text(ServiceType.cursor.displayName)
                        .font(.headline)
                    Spacer()
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
            .opacity(0.5)

            // Tweet button at full opacity
            Button(action: {
                CursorService.shared.openTweetRequest()
            }) {
                HStack(spacing: 4) {
                    Text("𝕏")
                        .font(.system(size: 12, weight: .bold))
                    Text("Request API")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help("Post on X to request Cursor usage API")
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
