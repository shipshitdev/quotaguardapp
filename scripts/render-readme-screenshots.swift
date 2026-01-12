import AppKit
import Foundation
import SwiftUI

struct UsageLimit: Equatable {
    let used: Double
    let total: Double
    let resetTime: Date?

    var percentage: Double {
        guard total > 0 else { return 0 }
        return min(100, max(0, (used / total) * 100))
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
        }
        return .good
    }
}

enum UsageStatus {
    case good
    case warning
    case critical

    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

enum ServiceType: String, CaseIterable, Identifiable {
    case claudeCode = "Claude Code"
    case openai = "OpenAI"
    case cursor = "Cursor"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .claudeCode: return "terminal"
        case .openai: return "brain"
        case .cursor: return "cursorarrow.click"
        }
    }
}

struct UsageMetrics: Identifiable {
    let id = UUID()
    let service: ServiceType
    let sessionLimit: UsageLimit?
    let weeklyLimit: UsageLimit?
    let codeReviewLimit: UsageLimit?
    let lastUpdated: Date

    var overallStatus: UsageStatus {
        let limits = [sessionLimit, weeklyLimit, codeReviewLimit].compactMap { $0 }
        guard !limits.isEmpty else { return .good }

        if limits.contains(where: { $0.isAtLimit }) {
            return .critical
        } else if limits.contains(where: { $0.isNearLimit }) {
            return .warning
        }
        return .good
    }
}

struct WallpaperView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.23, blue: 0.42),
                    Color(red: 0.16, green: 0.44, blue: 0.62),
                    Color(red: 0.58, green: 0.47, blue: 0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 220, height: 220)
                .offset(x: -100, y: -120)
                .blur(radius: 10)

            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 260, height: 260)
                .offset(x: 120, y: 130)
                .blur(radius: 12)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State

    init(
        material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
    }
}

struct MacOSPopoverBackground: View {
    var body: some View {
        VisualEffectView(material: .popover)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 8)
    }
}

struct MacOSCardBackground: View {
    var body: some View {
        VisualEffectView(material: .contentBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct MacOSWidgetBackground: View {
    var body: some View {
        VisualEffectView(material: .sidebar)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 8)
    }
}

struct MenuBarSnapshotView: View {
    let claudeCodeMetrics: UsageMetrics
    let openAIMetrics: UsageMetrics
    let cursorMetrics: UsageMetrics

    var body: some View {
        ZStack {
            MacOSPopoverBackground()
            VStack(spacing: 0) {
                header
                Divider()
                VStack(spacing: 12) {
                    ClaudeCodeSnapshotRow(metrics: claudeCodeMetrics, subscriptionLabel: "Max")
                    ServiceSnapshotRow(metrics: openAIMetrics)
                    CursorSnapshotRow(metrics: cursorMetrics, subscriptionLabel: "Pro")
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                Divider()
                footer
            }
        }
        .frame(width: 320, height: 500)
    }

    private var header: some View {
        HStack {
            Text("Quota Guard")
                .font(.headline)
            Spacer()
            Image(systemName: "arrow.clockwise")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(VisualEffectView(material: .headerView))
    }

    private var footer: some View {
        HStack {
            Button("Quit") {}
                .buttonStyle(.bordered)
                .foregroundColor(.red)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(VisualEffectView(material: .menu))
    }
}

struct ServiceSnapshotRow: View {
    let metrics: UsageMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: metrics.service.iconName)
                    .foregroundColor(metrics.overallStatus.color)
                Text(metrics.service.displayName)
                    .font(.headline)
                Spacer()
                StatusIndicator(status: metrics.overallStatus)
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        .background(MacOSCardBackground())
    }
}

struct ClaudeCodeSnapshotRow: View {
    let metrics: UsageMetrics
    let subscriptionLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: metrics.service.iconName)
                    .foregroundColor(metrics.overallStatus.color)
                Text(metrics.service.displayName)
                    .font(.headline)
                Spacer()
                StatusIndicator(status: metrics.overallStatus)
                Image(systemName: "chevron.up")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            if let sessionLimit = metrics.sessionLimit {
                LimitRow(title: "Session (5h)", limit: sessionLimit)
            }

            if let weeklyLimit = metrics.weeklyLimit {
                LimitRow(title: "All Models (7d)", limit: weeklyLimit)
            }

            if let sonnetLimit = metrics.codeReviewLimit {
                LimitRow(title: "Sonnet (7d)", limit: sonnetLimit)
            }

            HStack {
                Text(subscriptionLabel)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(4)
                Spacer()
                Text("Updated: \(formatDate(metrics.lastUpdated))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(MacOSCardBackground())
    }
}

struct CursorSnapshotRow: View {
    let metrics: UsageMetrics
    let subscriptionLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: metrics.service.iconName)
                    .foregroundColor(.blue)
                Text(metrics.service.displayName)
                    .font(.headline)
                Spacer()
                StatusIndicator(status: metrics.overallStatus)
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            if let sessionLimit = metrics.sessionLimit {
                LimitRow(title: "Session", limit: sessionLimit)
            }

            if let weeklyLimit = metrics.weeklyLimit {
                LimitRow(title: "Monthly", limit: weeklyLimit)
            }

            if let additionalLimit = metrics.codeReviewLimit {
                LimitRow(title: "Additional", limit: additionalLimit)
            }

            HStack {
                Text(subscriptionLabel)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
                Spacer()
                Text("Updated: \(formatDate(metrics.lastUpdated))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(MacOSCardBackground())
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

            UsageProgressBar(progress: limit.total > 0 ? limit.used / limit.total : 0, tint: limit.statusColor.color)

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
}

struct StatusIndicator: View {
    let status: UsageStatus

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
    }
}

struct WidgetMediumSnapshotView: View {
    let metrics: [UsageMetrics]

    var body: some View {
        ZStack {
            MacOSWidgetBackground()
            VStack(alignment: .leading, spacing: 12) {
                Text("Quota Guard")
                    .font(.headline)

                ForEach(metrics) { entry in
                    WidgetServiceCompactView(metrics: entry)
                }
            }
            .padding()
        }
        .frame(width: 340, height: 170, alignment: .topLeading)
    }
}

struct WidgetServiceCompactView: View {
    let metrics: UsageMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: metrics.service.iconName)
                    .foregroundColor(metrics.overallStatus.color)
                Text(metrics.service.displayName)
                    .font(.subheadline)
                    .bold()
                Spacer()
                WidgetStatusIndicator(status: metrics.overallStatus)
            }

            if let weeklyLimit = metrics.weeklyLimit {
                HStack {
                    UsageProgressBar(progress: weeklyLimit.total > 0 ? weeklyLimit.used / weeklyLimit.total : 0, tint: weeklyLimit.statusColor.color)
                    Text("\(Int(weeklyLimit.percentage))%")
                        .font(.caption)
                }
            }
        }
    }
}

struct WidgetStatusIndicator: View {
    let status: UsageStatus

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 6, height: 6)
    }
}

struct UsageProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(NSColor.separatorColor).opacity(0.25))
                RoundedRectangle(cornerRadius: 3)
                    .fill(tint)
                    .frame(width: geometry.size.width * CGFloat(max(0, min(progress, 1))))
            }
        }
        .frame(height: 6)
    }
}

func formatNumber(_ value: Double) -> String {
    if value >= 1000 {
        return String(format: "%.1fk", value / 1000)
    }
    return String(format: "%.0f", value)
}

func formatResetTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

func formatDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

enum SnapshotError: Error {
    case renderFailed(String)
    case outputFailed(String)
}

@MainActor
func renderSnapshot<V: View>(view: V, size: CGSize, to url: URL, scale: CGFloat = 2) throws {
    let rootView = ZStack {
        WallpaperView()
        view
    }
    let hostingView = NSHostingView(rootView: rootView.environment(\.colorScheme, .light))
    hostingView.frame = NSRect(origin: .zero, size: size)
    hostingView.wantsLayer = true

    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.isReleasedWhenClosed = false
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.appearance = NSAppearance(named: .aqua)
    window.contentView = hostingView
    window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
    window.orderFront(nil)

    hostingView.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width * scale),
        pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw SnapshotError.renderFailed("Failed to allocate bitmap for \(url.lastPathComponent)")
    }

    rep.size = size
    hostingView.cacheDisplay(in: hostingView.bounds, to: rep)

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw SnapshotError.outputFailed("Failed to encode \(url.lastPathComponent)")
    }

    try data.write(to: url)
    window.orderOut(nil)
}

@main
struct SnapshotRenderer {
    @MainActor
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let outputDir = URL(fileURLWithPath: "docs/screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let now = Date()

        let claudeCodeMetrics = UsageMetrics(
            service: .claudeCode,
            sessionLimit: UsageLimit(used: 42, total: 100, resetTime: now.addingTimeInterval(2 * 60 * 60)),
            weeklyLimit: UsageLimit(used: 78, total: 100, resetTime: now.addingTimeInterval(3 * 24 * 60 * 60)),
            codeReviewLimit: UsageLimit(used: 91, total: 100, resetTime: now.addingTimeInterval(3 * 24 * 60 * 60)),
            lastUpdated: now.addingTimeInterval(-18 * 60)
        )

        let openAIMetrics = UsageMetrics(
            service: .openai,
            sessionLimit: UsageLimit(used: 1200, total: 5000, resetTime: now.addingTimeInterval(5 * 60 * 60)),
            weeklyLimit: UsageLimit(used: 6200, total: 10000, resetTime: now.addingTimeInterval(6 * 24 * 60 * 60)),
            codeReviewLimit: nil,
            lastUpdated: now.addingTimeInterval(-42 * 60)
        )

        let cursorMetrics = UsageMetrics(
            service: .cursor,
            sessionLimit: UsageLimit(used: 180, total: 500, resetTime: now.addingTimeInterval(3 * 60 * 60)),
            weeklyLimit: UsageLimit(used: 760, total: 1000, resetTime: now.addingTimeInterval(12 * 24 * 60 * 60)),
            codeReviewLimit: UsageLimit(used: 140, total: 200, resetTime: now.addingTimeInterval(12 * 24 * 60 * 60)),
            lastUpdated: now.addingTimeInterval(-95 * 60)
        )

        let menuBarView = MenuBarSnapshotView(
            claudeCodeMetrics: claudeCodeMetrics,
            openAIMetrics: openAIMetrics,
            cursorMetrics: cursorMetrics
        )

        try renderSnapshot(
            view: menuBarView,
            size: CGSize(width: 320, height: 500),
            to: outputDir.appendingPathComponent("menubar.png")
        )

        let widgetView = WidgetMediumSnapshotView(metrics: [claudeCodeMetrics, openAIMetrics, cursorMetrics])

        try renderSnapshot(
            view: widgetView,
            size: CGSize(width: 340, height: 170),
            to: outputDir.appendingPathComponent("widget-medium.png")
        )
    }
}
