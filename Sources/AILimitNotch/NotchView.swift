import AppKit
import SwiftUI

struct NotchView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var state: NotchState
    @ObservedObject private var usage = UsageStore.shared

    let onExpansionChanged: (Bool) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(radius: state.isExpanded ? 18 : 8)
                .fill(Color.black)

            if state.isExpanded {
                expandedContent
            } else {
                miniContent
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var miniContent: some View {
        HStack(spacing: 8) {
            ForEach(Array(settings.miniProviders.enumerated()), id: \.element) { index, provider in
                HStack(spacing: 4) {
                    ProviderLogoImage(assetName: provider.assetName, monochrome: settings.isMonochrome)
                        .scaledToFill()
                        .frame(width: 11, height: 11)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

                    Text("\(miniMetric(for: provider).usedPercent)%")
                        .font(.sukhumvit(10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.9))
                }
                .fixedSize()

                if index < settings.miniProviders.count - 1 {
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 1, height: 10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var expandedContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(Array(settings.enabledProviders.enumerated()), id: \.element) { index, provider in
                    ProviderLimitSection(
                        provider: provider,
                        metrics: usage.limits(for: provider),
                        language: settings.language,
                        monochrome: settings.isMonochrome
                    )

                    if index < settings.enabledProviders.count - 1 {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: settings.isMonochrome
                                        ? [.clear, .white.opacity(0.24), .clear]
                                        : [.clear, provider.tint.opacity(0.48), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.vertical, 2)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.never)
    }

    private func toggle() {
        state.isExpanded.toggle()
        onExpansionChanged(state.isExpanded)
    }

    private func miniMetric(for provider: ProviderID) -> LimitMetric {
        let metrics = usage.limits(for: provider)
        return metrics.first(where: { $0.id == "5h" }) ?? metrics[0]
    }
}

private struct ProviderLimitSection: View {
    let provider: ProviderID
    let metrics: [LimitMetric]
    let language: String
    let monochrome: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                ProviderLogoImage(assetName: provider.assetName, monochrome: monochrome)
                    .scaledToFill()
                    .frame(width: 17, height: 17)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                Text(provider.name)
                    .font(.sukhumvit(12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
            }

            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                LimitRow(
                    metric: metric,
                    tint: monochrome ? .white : provider.tint,
                    fillOpacity: monochrome ? [0.95, 0.70, 0.48][min(index, 2)] : 1,
                    language: language
                )
            }
        }
    }
}

private struct LimitRow: View {
    let metric: LimitMetric
    let tint: Color
    let fillOpacity: Double
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(localizedLabel)
                    .font(.sukhumvit(11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Text(language == "th" ? "ใช้แล้ว \(metric.usedPercent)%" : "\(metric.usedPercent)% used")
                    .font(.sukhumvit(11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(tint.gradient)
                        .opacity(fillOpacity)
                        .frame(width: geometry.size.width * CGFloat(metric.usedPercent) / 100)
                }
            }
            .frame(height: 6)

            if let resetText = metric.resetText {
                Text(language == "th" ? resetText.replacingOccurrences(of: "Resets", with: "รีเซ็ต") : resetText)
                    .font(.sukhumvit(9))
                    .foregroundStyle(.white.opacity(0.46))
            }
        }
    }

    private var localizedLabel: String {
        guard language == "th" else { return metric.label }
        switch metric.label {
        case "Current session": return "เซสชันปัจจุบัน"
        case "Current week (all models)": return "สัปดาห์นี้ (ทุกโมเดล)"
        case "Current week (Fable)": return "สัปดาห์นี้ (Fable)"
        case "5-hour limit": return "ลิมิต 5 ชั่วโมง"
        case "Weekly limit": return "ลิมิตรายสัปดาห์"
        case "Plan usage": return "การใช้งานแพ็กเกจ"
        default: return metric.label
        }
    }
}

struct ProviderLogoImage: View {
    let assetName: String
    var monochrome = false

    var body: some View {
        if let url = Bundle.module.url(forResource: assetName, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            if monochrome {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.white)
            } else {
                Image(nsImage: image)
                    .resizable()
            }
        } else {
            Color.clear
        }
    }
}

private struct NotchShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}
