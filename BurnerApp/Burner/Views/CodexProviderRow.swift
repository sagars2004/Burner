import SwiftUI

public struct CodexProviderRow: View {
    public let provider: ProviderQuota
    public let forecast: SprintBurnForecast?
    public let onLaunch: () -> Void

    @State private var isExpanded: Bool = false
    @State private var isHovered: Bool = false

    public init(
        provider: ProviderQuota,
        forecast: SprintBurnForecast? = nil,
        onLaunch: @escaping () -> Void = {}
    ) {
        self.provider = provider
        self.forecast = forecast
        self.onLaunch = onLaunch
    }

    private var statusGradient: LinearGradient {
        let base = provider.status.color
        return LinearGradient(
            colors: [base.opacity(0.85), base],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Main Compact Row
            HStack(alignment: .center, spacing: 10) {
                // Brand Icon
                ZStack {
                    Circle()
                        .fill(provider.provider_id.brandColor.opacity(0.2))
                        .frame(width: 30, height: 30)

                    Image(systemName: provider.icon_name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(provider.provider_id.brandColor)
                }

                // Provider Name & Plan
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(provider.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)

                        if provider.is_simulated {
                            Text("DEMO")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple.opacity(0.3))
                                .foregroundColor(.purple)
                                .cornerRadius(3)
                        }
                    }

                    Text(provider.plan_name)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                // Percentage and Reset Pill
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(Int(provider.quota_remaining_percent))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(provider.status.color)

                        Text("left")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                    }

                    Text(provider.formattedCountdown)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                }

                // Quick Launch Button
                Button(action: onLaunch) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isHovered ? .white : .gray.opacity(0.8))
                        .padding(5)
                        .background(isHovered ? Color.white.opacity(0.15) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Launch \(provider.name)")
            }

            // CodexBar-Style Thin Segmented Usage Meter
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: geo.size.width, height: 4)

                    // Fill Bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(statusGradient)
                        .frame(
                            width: max(4, geo.size.width * CGFloat(provider.quota_remaining_percent / 100.0)),
                            height: 4
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: provider.quota_remaining_percent)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 4)

            // Sub-metrics row
            HStack {
                if let f = forecast, f.safe_prompts_remaining > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green.opacity(0.8))
                        Text("\(f.safe_prompts_remaining) safe prompts")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text(provider.status == .healthy ? "Optimal headroom" : "Conserve quota")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.gray)
                }

                Spacer()

                if provider.burn_rate_per_hour > 0.1 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                        Text("\(String(format: "%.1f", provider.burn_rate_per_hour))%/hr")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.9))
                    }
                } else {
                    Text("Idle cadence")
                        .font(.system(size: 9.5))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .padding(.top, 1)

            // Optional Lockout Warning banner if burning fast
            if let warning = forecast?.lockout_warning {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                        .padding(.top, 1)
                    Text(warning)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.yellow.opacity(0.95))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.12))
                .cornerRadius(5)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.04), lineWidth: 1)
        )
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hover
            }
        }
    }
}
