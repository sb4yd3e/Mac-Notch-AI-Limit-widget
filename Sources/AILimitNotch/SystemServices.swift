import AppKit
import ServiceManagement
import Sparkle
import SwiftUI

@MainActor
final class ClaudeWakeController {
    static let shared = ClaudeWakeController()

    private let defaults = UserDefaults.standard
    private let cooldown: TimeInterval = 30 * 60
    private var process: Process?

    private init() {}

    func wakeIfNeeded() {
        guard process == nil else { return }
        let lastAttempt = defaults.object(forKey: "lastClaudeWakeAttempt") as? Date ?? .distantPast
        guard Date().timeIntervalSince(lastAttempt) >= cooldown else { return }
        defaults.set(Date(), forKey: "lastClaudeWakeAttempt")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "claude",
            "-p",
            "/usage",
            "--no-session-persistence",
            "--tools",
            "",
            "--output-format",
            "json"
        ]
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let searchPaths = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            environment["PATH"] ?? "/usr/bin:/bin"
        ]
        environment["PATH"] = searchPaths.joined(separator: ":")
        process.environment = environment
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { process in
            let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if process.terminationStatus == 0 {
                Self.persistUsageResult(output)
            }
            Task { @MainActor [weak self] in
                self?.process = nil
                UsageStore.shared.refresh()
            }
        }

        do {
            try process.run()
            self.process = process
            DispatchQueue.main.asyncAfter(deadline: .now() + 90) { [weak self, weak process] in
                guard let self, let process, self.process === process, process.isRunning else { return }
                process.terminate()
            }
        } catch {
            self.process = nil
        }
    }

    private nonisolated static func persistUsageResult(_ data: Data) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? String else { return }

        let definitions = [
            (prefix: "Current session:", source: "five_hour"),
            (prefix: "Current week (all models):", source: "seven_day")
        ]
        var rateLimits: [String: [String: Any]] = [:]

        for definition in definitions {
            guard let line = result.split(separator: "\n")
                .map(String.init)
                .first(where: { $0.hasPrefix(definition.prefix) }),
                  let parsed = parseUsageLine(line, prefix: definition.prefix) else { continue }
            rateLimits[definition.source] = [
                "used_percentage": parsed.usedPercentage,
                "resets_at": parsed.resetsAt
            ]
        }
        guard !rateLimits.isEmpty else { return }

        let payload: [String: Any] = [
            "fetched_at": Date().timeIntervalSince1970,
            "rate_limits": rateLimits
        ]
        guard let encoded = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AILimitNotch/claude-usage-command.json")
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? encoded.write(to: url, options: .atomic)
    }

    private nonisolated static func parseUsageLine(
        _ line: String,
        prefix: String
    ) -> (usedPercentage: Double, resetsAt: Double)? {
        let escapedPrefix = NSRegularExpression.escapedPattern(for: prefix)
        let pattern = "^\(escapedPrefix)\\s+([0-9]+(?:\\.[0-9]+)?)% used · resets (.+) \\(([^)]+)\\)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: line,
                range: NSRange(line.startIndex..., in: line)
              ),
              let percentRange = Range(match.range(at: 1), in: line),
              let resetRange = Range(match.range(at: 2), in: line),
              let zoneRange = Range(match.range(at: 3), in: line),
              let usedPercentage = Double(line[percentRange]) else { return nil }

        let zoneID = String(line[zoneRange])
        guard let timeZone = TimeZone(identifier: zoneID) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = Date()
        let year = calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d 'at' h:mma yyyy"
        guard var resetDate = formatter.date(from: "\(line[resetRange]) \(year)") else { return nil }
        if resetDate < now.addingTimeInterval(-24 * 60 * 60),
           let nextYear = calendar.date(byAdding: .year, value: 1, to: resetDate) {
            resetDate = nextYear
        }
        return (usedPercentage, resetDate.timeIntervalSince1970)
    }
}

@MainActor
final class LaunchAtLoginController: ObservableObject {
    static let shared = LaunchAtLoginController()

    @Published private(set) var isEnabled: Bool
    @Published private(set) var statusMessage: String?

    private let service = SMAppService.mainApp

    private init() {
        isEnabled = service.status == .enabled || service.status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            isEnabled = false
            statusMessage = "Available after installing the .app"
            return
        }

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            isEnabled = service.status == .enabled || service.status == .requiresApproval
            statusMessage = service.status == .requiresApproval ? "Allow in System Settings › Login Items" : nil
        } catch {
            isEnabled = service.status == .enabled || service.status == .requiresApproval
            statusMessage = error.localizedDescription
        }
    }
}

@MainActor
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateController()

    static let appcastURL = "https://github.com/sb4yd3e/Mac-Notch-AI-Limit-widget/releases/latest/download/appcast.xml"

    @Published private(set) var automaticallyChecksForUpdates: Bool
    @Published private(set) var statusMessage: String?

    private var updaterController: SPUStandardUpdaterController?
    private let defaults = UserDefaults.standard

    private override init() {
        automaticallyChecksForUpdates = defaults.object(forKey: "automaticallyChecksForUpdates") as? Bool ?? true
        super.init()

        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        updaterController = controller
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        Self.appcastURL
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        automaticallyChecksForUpdates = enabled
        defaults.set(enabled, forKey: "automaticallyChecksForUpdates")
        updaterController?.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        guard let updaterController else {
            statusMessage = "Available after installing the .app"
            return
        }
        statusMessage = nil
        updaterController.checkForUpdates(nil)
    }
}
