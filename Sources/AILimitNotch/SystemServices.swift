import AppKit
import ServiceManagement
import Sparkle
import SwiftUI

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
