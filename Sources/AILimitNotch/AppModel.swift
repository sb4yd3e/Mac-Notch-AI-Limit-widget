import Foundation
import SwiftUI

extension Font {
    static func sukhumvit(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .semibold, .bold, .heavy, .black:
            return .custom("SukhumvitSet-SemiBold", size: size)
        case .medium:
            return .custom("SukhumvitSet-Medium", size: size)
        default:
            return .custom("SukhumvitSet-Text", size: size)
        }
    }
}

enum ProviderID: String, CaseIterable, Identifiable, Codable {
    case claudeCode
    case codex
    case antigravity
    case cursor

    var id: String { rawValue }

    var name: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .antigravity: "Antigravity"
        case .cursor: "Cursor"
        }
    }

    var assetName: String {
        switch self {
        case .claudeCode: "claudecode"
        case .codex: "codex"
        case .antigravity: "antigravity"
        case .cursor: "cursor"
        }
    }

    var tint: Color {
        switch self {
        case .claudeCode: .orange
        case .codex: .indigo
        case .antigravity: .purple
        case .cursor: .blue
        }
    }

    var statusFeedURL: URL? {
        switch self {
        case .claudeCode: URL(string: "https://status.claude.com/history.rss")
        case .codex: URL(string: "https://status.openai.com/feed.rss")
        case .antigravity, .cursor: nil
        }
    }

    var miniMetricID: String {
        switch self {
        case .codex: "week"
        case .claudeCode, .antigravity, .cursor: "5h"
        }
    }
}

enum ServerStatus: Sendable {
    case operational
    case incident
    case unknown

    var color: Color {
        switch self {
        case .operational: .green
        case .incident: .orange
        case .unknown: .gray
        }
    }

    func label(_ language: String) -> String {
        switch self {
        case .operational: language == "th" ? "ปกติ" : "Operational"
        case .incident: language == "th" ? "มีปัญหา" : "Incident"
        case .unknown: language == "th" ? "ไม่ทราบสถานะ" : "Unknown"
        }
    }
}

struct LimitMetric: Identifiable, Sendable {
    let id: String
    let label: String
    let usedPercent: Int
    let resetText: String?
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var language: String {
        didSet { save() }
    }
    @Published var enabledProviderIDs: Set<String> {
        didSet { saveAndNotify() }
    }
    @Published var providerOrder: [ProviderID] {
        didSet { saveAndNotify() }
    }
    @Published var miniItemCount: Int {
        didSet { saveAndNotify() }
    }
    @Published var colorMode: String {
        didSet { save() }
    }
    @Published var autoWakeClaudeWhenUnavailable: Bool {
        didSet {
            save()
            guard !isLoading, autoWakeClaudeWhenUnavailable else { return }
            UsageStore.shared.refresh()
        }
    }

    private let defaults = UserDefaults.standard
    private var isLoading = true

    private init() {
        language = defaults.string(forKey: "language") ?? "th"
        let savedEnabled = defaults.stringArray(forKey: "enabledProviders")
        enabledProviderIDs = Set(savedEnabled ?? [ProviderID.claudeCode.rawValue, ProviderID.codex.rawValue])
        let savedOrder = defaults.stringArray(forKey: "providerOrder")?
            .compactMap(ProviderID.init(rawValue:)) ?? ProviderID.allCases
        providerOrder = savedOrder + ProviderID.allCases.filter { !savedOrder.contains($0) }
        miniItemCount = min(3, max(1, defaults.object(forKey: "miniItemCount") as? Int ?? 2))
        colorMode = defaults.string(forKey: "colorMode") ?? "color"
        autoWakeClaudeWhenUnavailable = defaults.bool(forKey: "autoWakeClaudeWhenUnavailable")
        isLoading = false
    }

    var enabledProviders: [ProviderID] {
        providerOrder.filter { enabledProviderIDs.contains($0.rawValue) }
    }

    var miniProviders: [ProviderID] {
        Array(enabledProviders.prefix(miniItemCount))
    }

    var isMonochrome: Bool { colorMode == "monochrome" }

    func isEnabled(_ provider: ProviderID) -> Bool {
        enabledProviderIDs.contains(provider.rawValue)
    }

    func setEnabled(_ enabled: Bool, provider: ProviderID) {
        if enabled {
            enabledProviderIDs.insert(provider.rawValue)
        } else if enabledProviderIDs.count > 1 {
            enabledProviderIDs.remove(provider.rawValue)
        }
    }

    func moveProvider(_ provider: ProviderID, direction: Int) {
        guard let index = providerOrder.firstIndex(of: provider) else { return }
        let target = index + direction
        guard providerOrder.indices.contains(target) else { return }
        providerOrder.swapAt(index, target)
    }

    private func saveAndNotify() {
        save()
        guard !isLoading else { return }
        NotificationCenter.default.post(name: .notchSettingsChanged, object: nil)
    }

    private func save() {
        guard !isLoading else { return }
        defaults.set(language, forKey: "language")
        defaults.set(Array(enabledProviderIDs), forKey: "enabledProviders")
        defaults.set(providerOrder.map(\.rawValue), forKey: "providerOrder")
        defaults.set(miniItemCount, forKey: "miniItemCount")
        defaults.set(colorMode, forKey: "colorMode")
        defaults.set(autoWakeClaudeWhenUnavailable, forKey: "autoWakeClaudeWhenUnavailable")
    }
}

@MainActor
final class NotchState: ObservableObject {
    static let shared = NotchState()
    @Published var isExpanded = false
}

@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()

    @Published private(set) var liveLimits: [ProviderID: [LimitMetric]] = [:]
    private var timer: Timer?
    private var isRefreshing = false

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func limits(for provider: ProviderID) -> [LimitMetric] {
        liveLimits[provider] ?? []
    }

    func isLive(_ provider: ProviderID) -> Bool {
        liveLimits[provider] != nil
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task.detached(priority: .utility) {
            let codex = Self.readLatestCodexLimits()
            let claude = Self.readClaudeStatusLineCache()
            await MainActor.run { [weak self] in
                self?.apply(codex: codex, claude: claude)
                self?.isRefreshing = false
            }
        }
    }

    private func apply(codex: [LimitMetric]?, claude: [LimitMetric]?) {
        liveLimits[.codex] = codex        // assigning nil removes the key
        liveLimits[.claudeCode] = claude
        liveLimits.removeValue(forKey: .antigravity)
        liveLimits.removeValue(forKey: .cursor)

        let settings = AppSettings.shared
        let hasClaudeFiveHour = claude?.contains(where: { $0.id == "5h" }) == true
        if settings.autoWakeClaudeWhenUnavailable,
           settings.isEnabled(.claudeCode),
           !hasClaudeFiveHour {
            ClaudeWakeController.shared.wakeIfNeeded()
        }
    }

    private nonisolated static func readLatestCodexLimits() -> [LimitMetric]? {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var newestURL: URL?
        var newestDate = Date.distantPast
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true, let date = values?.contentModificationDate, date > newestDate else { continue }
            newestDate = date
            newestURL = url
        }
        guard let newestURL, let handle = try? FileHandle(forReadingFrom: newestURL) else { return nil }
        defer { try? handle.close() }

        let end = (try? handle.seekToEnd()) ?? 0
        let start = end > 2_000_000 ? end - 2_000_000 : 0
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd() else { return nil }
        // Tail read may start mid-character; decode lossily so a split UTF-8 byte doesn't drop the whole file.
        let text = String(decoding: data, as: UTF8.self)

        var weeklyLimit: LimitMetric?
        for line in text.split(separator: "\n").reversed().prefix(800) {
            guard let lineData = line.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let payload = root["payload"] as? [String: Any],
                  let limits = payload["rate_limits"] as? [String: Any] else { continue }

            for key in ["primary", "secondary"] {
                guard let window = limits[key] as? [String: Any],
                      let used = (window["used_percent"] as? NSNumber)?.doubleValue,
                      let minutes = (window["window_minutes"] as? NSNumber)?.intValue else { continue }
                guard minutes > 300, weeklyLimit == nil else { continue }
                weeklyLimit = LimitMetric(
                    id: "week",
                    label: "Weekly limit",
                    usedPercent: min(100, max(0, Int(used.rounded()))),
                    resetText: resetText(window["resets_at"])
                )
            }
            if weeklyLimit != nil { break }
        }
        return weeklyLimit.map { [$0] }
    }

    private struct ClaudeLimitWindow: Equatable {
        let source: String
        let id: String
        let label: String
        let usedPercentage: Double
        let resetsAt: Double?

        var metric: LimitMetric {
            LimitMetric(
                id: id,
                label: label,
                usedPercent: min(100, max(0, Int(usedPercentage.rounded()))),
                resetText: resetText(resetsAt)
            )
        }
    }

    private nonisolated static func readClaudeStatusLineCache() -> [LimitMetric]? {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AILimitNotch", isDirectory: true)
        let liveURL = directory.appendingPathComponent("claude-usage.json")
        let commandURL = directory.appendingPathComponent("claude-usage-command.json")
        let fallbackURL = directory.appendingPathComponent("claude-usage-last-good.json")

        // Claude Code omits rate_limits before the first API response and may omit
        // either window independently. Preserve only still-valid official values.
        var windows = readClaudeWindows(from: fallbackURL, requireFutureReset: true)
        var latestWindows: [String: ClaudeLimitWindow] = [:]
        let liveURLs = [liveURL, commandURL].sorted {
            modificationDate(of: $0) < modificationDate(of: $1)
        }
        for url in liveURLs {
            for (source, window) in readClaudeWindows(from: url, requireFutureReset: false) {
                latestWindows[source] = window
            }
        }
        for (source, window) in latestWindows {
            windows[source] = window
        }

        if !latestWindows.isEmpty {
            persistClaudeWindows(windows, to: fallbackURL)
        }

        let orderedSources = ["five_hour", "seven_day"]
        let result = orderedSources.compactMap { windows[$0]?.metric }
        return result.isEmpty ? nil : result
    }

    private nonisolated static func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast
    }

    private nonisolated static func readClaudeWindows(
        from url: URL,
        requireFutureReset: Bool
    ) -> [String: ClaudeLimitWindow] {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimits = root["rate_limits"] as? [String: Any] else { return [:] }

        let definitions = [("five_hour", "5h", "5-hour limit"), ("seven_day", "week", "Weekly limit")]
        let now = Date().timeIntervalSince1970
        var result: [String: ClaudeLimitWindow] = [:]

        for (source, id, label) in definitions {
            guard let window = rateLimits[source] as? [String: Any],
                  let used = (window["used_percentage"] as? NSNumber)?.doubleValue,
                  used.isFinite else { continue }
            let resetsAt = (window["resets_at"] as? NSNumber)?.doubleValue
            if let resetsAt, resetsAt <= now { continue }
            if requireFutureReset, resetsAt == nil { continue }
            result[source] = ClaudeLimitWindow(
                source: source,
                id: id,
                label: label,
                usedPercentage: used,
                resetsAt: resetsAt
            )
        }
        return result
    }

    private nonisolated static func persistClaudeWindows(
        _ windows: [String: ClaudeLimitWindow],
        to url: URL
    ) {
        let now = Date().timeIntervalSince1970
        let validWindows = windows.values.filter { window in
            guard let resetsAt = window.resetsAt else { return false }
            return resetsAt > now
        }
        guard !validWindows.isEmpty else { return }
        let validBySource = Dictionary(uniqueKeysWithValues: validWindows.map { ($0.source, $0) })
        let existing = readClaudeWindows(from: url, requireFutureReset: true)
        guard existing != validBySource else { return }

        let rateLimits = Dictionary(uniqueKeysWithValues: validWindows.map { window in
            (
                window.source,
                [
                    "used_percentage": window.usedPercentage,
                    "resets_at": window.resetsAt as Any
                ] as [String: Any]
            )
        })
        let payload: [String: Any] = [
            "saved_at": now,
            "rate_limits": rateLimits
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }

    private nonisolated static func resetText(_ raw: Any?) -> String? {
        guard let timestamp = (raw as? NSNumber)?.doubleValue else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return "Resets " + formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}

@MainActor
final class StatusStore: ObservableObject {
    static let shared = StatusStore()

    @Published private(set) var statuses: [ProviderID: ServerStatus] = [:]
    private var timer: Timer?

    private init() {
        refresh()
        // Status pages change slowly; poll every 5 minutes.
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func status(for provider: ProviderID) -> ServerStatus {
        statuses[provider] ?? .unknown
    }

    func refresh() {
        for provider in ProviderID.allCases {
            guard let url = provider.statusFeedURL else { continue }
            Task { [weak self] in
                let status = await Self.fetchStatus(url)
                self?.statuses[provider] = status
            }
        }
    }

    // Both feeds list incidents newest-first. The newest incident's earliest status
    // keyword is its current state: "Resolved" means the page is operational again,
    // anything else means an incident is still open.
    private nonisolated static func fetchStatus(_ url: URL) async -> ServerStatus {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return .unknown }
        let xml = String(decoding: data, as: UTF8.self)
        guard let itemStart = xml.range(of: "<item>") else { return .unknown }
        let tail = xml[itemStart.upperBound...]
        let item = tail.range(of: "</item>").map { String(tail[..<$0.lowerBound]) } ?? String(tail)
        let lower = item.lowercased()

        var earliest: (index: Int, resolved: Bool)?
        for (keyword, resolved) in [("resolved", true), ("investigating", false), ("identified", false), ("monitoring", false)] {
            guard let range = lower.range(of: keyword) else { continue }
            let index = lower.distance(from: lower.startIndex, to: range.lowerBound)
            if earliest == nil || index < earliest!.index {
                earliest = (index, resolved)
            }
        }
        guard let earliest else { return .unknown }
        return earliest.resolved ? .operational : .incident
    }
}

extension Notification.Name {
    static let notchSettingsChanged = Notification.Name("notchSettingsChanged")
}
