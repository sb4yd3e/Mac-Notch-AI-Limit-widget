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
}

struct LimitMetric: Identifiable {
    let id: String
    let label: String
    let usedPercent: Int
    let resetText: String?
}

extension ProviderID {
    var limits: [LimitMetric] {
        switch self {
        case .claudeCode:
            [
                LimitMetric(id: "session", label: "Current session", usedPercent: 0, resetText: nil),
                LimitMetric(id: "week", label: "Current week (all models)", usedPercent: 38, resetText: "Resets Jul 15 at 1 PM"),
                LimitMetric(id: "fable", label: "Current week (Fable)", usedPercent: 54, resetText: "Resets Jul 15 at 1 PM")
            ]
        case .codex:
            [
                LimitMetric(id: "5h", label: "5-hour limit", usedPercent: 22, resetText: "Resets in 2h 14m"),
                LimitMetric(id: "week", label: "Weekly limit", usedPercent: 1, resetText: "Resets Jul 20")
            ]
        case .antigravity:
            [LimitMetric(id: "5h", label: "5-hour limit", usedPercent: 0, resetText: "Waiting for connection")]
        case .cursor:
            [LimitMetric(id: "usage", label: "Plan usage", usedPercent: 0, resetText: "Waiting for connection")]
        }
    }

    var primaryMiniLimit: LimitMetric { limits.first(where: { $0.id == "5h" }) ?? limits[0] }
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

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func limits(for provider: ProviderID) -> [LimitMetric] {
        guard let live = liveLimits[provider] else { return provider.limits }
        var merged = provider.limits
        for metric in live {
            if let index = merged.firstIndex(where: { $0.id == metric.id }) {
                merged[index] = metric
            } else {
                merged.append(metric)
            }
        }
        return merged
    }

    func isLive(_ provider: ProviderID) -> Bool {
        liveLimits[provider] != nil
    }

    func refresh() {
        if let codex = Self.readLatestCodexLimits() {
            liveLimits[.codex] = codex
        }
        if let claude = Self.readClaudeStatusLineCache() {
            liveLimits[.claudeCode] = claude
        }
    }

    private static func readLatestCodexLimits() -> [LimitMetric]? {
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
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return nil }

        var found: [String: LimitMetric] = [:]
        for line in text.split(separator: "\n").reversed().prefix(800) {
            guard let lineData = line.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let payload = root["payload"] as? [String: Any],
                  let limits = payload["rate_limits"] as? [String: Any] else { continue }

            for key in ["primary", "secondary"] {
                guard let window = limits[key] as? [String: Any],
                      let used = (window["used_percent"] as? NSNumber)?.doubleValue,
                      let minutes = (window["window_minutes"] as? NSNumber)?.intValue else { continue }
                let id = minutes <= 300 ? "5h" : "week"
                guard found[id] == nil else { continue }
                found[id] = LimitMetric(
                    id: id,
                    label: id == "5h" ? "5-hour limit" : "Weekly limit",
                    usedPercent: min(100, max(0, Int(used.rounded()))),
                    resetText: resetText(window["resets_at"])
                )
            }
            if found.count == 2 { break }
        }
        let result = [found["5h"], found["week"]].compactMap { $0 }
        return result.isEmpty ? nil : result
    }

    private static func readClaudeStatusLineCache() -> [LimitMetric]? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AILimitNotch/claude-usage.json")
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimits = root["rate_limits"] as? [String: Any] else { return nil }

        let definitions = [("five_hour", "5h", "5-hour limit"), ("seven_day", "week", "Weekly limit")]
        return definitions.compactMap { source, id, label in
            guard let window = rateLimits[source] as? [String: Any],
                  let used = (window["used_percentage"] as? NSNumber)?.doubleValue else { return nil }
            return LimitMetric(
                id: id,
                label: label,
                usedPercent: min(100, max(0, Int(used.rounded()))),
                resetText: resetText(window["resets_at"])
            )
        }
    }

    private static func resetText(_ raw: Any?) -> String? {
        guard let timestamp = (raw as? NSNumber)?.doubleValue else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return "Resets " + formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}

extension Notification.Name {
    static let notchSettingsChanged = Notification.Name("notchSettingsChanged")
}
