import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var usage = UsageStore.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginController.shared
    @ObservedObject private var updates = UpdateController.shared

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            connectionsTab
                .tabItem { Label("Connections", systemImage: "link") }
            displayTab
                .tabItem { Label("Notch", systemImage: "rectangle.topthird.inset.filled") }
        }
        .padding(20)
        .frame(width: 560, height: 390)
        .environment(\.font, .sukhumvit(12))
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Picker("Language", selection: $settings.language) {
                    Text("ไทย").tag("th")
                    Text("English").tag("en")
                }
                .pickerStyle(.radioGroup)
            }
            .formStyle(.grouped)

            Divider()

            Toggle("Open at Login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))

            Toggle("Automatically check for updates", isOn: Binding(
                get: { updates.automaticallyChecksForUpdates },
                set: { updates.setAutomaticallyChecksForUpdates($0) }
            ))

            HStack {
                Button("Check for Updates…") { updates.checkForUpdates() }
                Spacer()
                if let message = launchAtLogin.statusMessage ?? updates.statusMessage {
                    Text(message)
                        .font(.sukhumvit(10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    private var connectionsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(ProviderID.allCases) { provider in
                HStack(spacing: 12) {
                    ProviderLogoImage(assetName: provider.assetName)
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(provider.name).font(.sukhumvit(13, weight: .semibold))
                            Circle()
                                .fill(usage.isLive(provider) ? Color.green : Color.secondary.opacity(0.5))
                                .frame(width: 6, height: 6)
                        }
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { settings.isEnabled(provider) },
                        set: { settings.setEnabled($0, provider: provider) }
                    ))
                    .labelsHidden()
                }
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }

            Toggle(
                "Refresh Claude usage when unavailable",
                isOn: $settings.autoWakeClaudeWhenUnavailable
            )
            .disabled(!settings.isEnabled(.claudeCode))
            .help("Runs claude -p \"/usage\" at most once every 30 minutes. The built-in usage command does not call the model or consume tokens.")

            Spacer()
        }
    }

    private var displayTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Appearance", selection: $settings.colorMode) {
                Text("Color").tag("color")
                Text("Black & White").tag("monochrome")
            }
            .pickerStyle(.segmented)

            Stepper("Items in mini Notch: \(settings.miniItemCount)", value: $settings.miniItemCount, in: 1...3)

            Text("Provider order")
                .font(.sukhumvit(13, weight: .semibold))

            ForEach(Array(settings.providerOrder.enumerated()), id: \.element) { index, provider in
                HStack {
                    ProviderLogoImage(assetName: provider.assetName)
                        .scaledToFill()
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    Text(provider.name)
                    Spacer()
                    Button { settings.moveProvider(provider, direction: -1) } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(index == 0)
                    Button { settings.moveProvider(provider, direction: 1) } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(index == settings.providerOrder.count - 1)
                }
                .padding(.vertical, 4)
            }
            Spacer()
        }
    }

}
