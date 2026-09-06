import SwiftUI

public struct ProviderTileView: View {
    public let provider: ProviderQuota

    public init(provider: ProviderQuota) {
        self.provider = provider
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Icon + Name/Plan + Percentage
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(provider.provider_id.brandColor.opacity(0.18))
                        .frame(width: 26, height: 26)
                    
                    Image(systemName: provider.icon_name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(provider.provider_id.brandColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(provider.name)
                            .font(.system(size: 13, weight: .semibold))
                        
                        if provider.is_simulated {
                            Text("DEMO")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(3)
                        }
                    }

                    Text(provider.plan_name)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Percentage Badge
                Text("\(Int(provider.quota_remaining_percent))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(provider.status.color)
            }

            // Progress Bar
            ProgressView(value: max(0.0, min(1.0, provider.quota_remaining_percent / 100.0)))
                .tint(provider.status.color)
                .scaleEffect(x: 1, y: 0.85, anchor: .center)

            // Sub-footer: Reset Countdown & Burn Rate
            HStack {
                Label(provider.formattedCountdown, systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                if provider.burn_rate_per_hour > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                        Text("-\(Int(provider.burn_rate_per_hour))%/h")
                        if let mins = provider.estimated_minutes_to_exhaustion {
                            Text("(~\(mins)m left)")
                        }
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(9)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(provider.status == .critical ? Color.red.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
