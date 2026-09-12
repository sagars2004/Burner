import SwiftUI

public struct ManageProvidersSheet: View {
    @ObservedObject public var apiService: BurnerAPIService
    @Binding public var isPresented: Bool

    public init(apiService: BurnerAPIService, isPresented: Binding<Bool>) {
        self.apiService = apiService
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gray)

                    Text("Manage AI Providers")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.3))

            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Auto-Discovery Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DETECTED TOOLS ON THIS MAC")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.gray)

                        Text("Burner automatically scans local app installs and sessions. Toggle below to show or hide them in your menu bar.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))

                        VStack(spacing: 6) {
                            ForEach(apiService.detectedProviders) { info in
                                HStack(spacing: 10) {
                                    Image(systemName: info.provider_id.iconName)
                                        .font(.system(size: 12))
                                        .foregroundColor(info.provider_id.brandColor)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(info.name)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white)

                                            if info.is_detected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.green)
                                            }
                                        }

                                        if let firstReason = info.detection_reasons.first {
                                            Text(firstReason)
                                                .font(.system(size: 9.5))
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { info.is_enabled },
                                        set: { newVal in
                                            Task {
                                                await apiService.toggleProvider(providerId: info.provider_id, enabled: newVal)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .scaleEffect(0.75)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(8)
                            }
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Hackathon Simulation Deck
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11))
                                .foregroundColor(.purple)
                            Text("HACKATHON DEMO CONTROLS")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.gray)
                        }

                        Text("Test Burner's proactive rate-limit routing by simulating quota consumption.")
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.7))

                        HStack(spacing: 8) {
                            Button(action: {
                                Task {
                                    await apiService.simulateDelta(providerId: "claude", delta: -25.0)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame")
                                        .font(.system(size: 10))
                                    Text("Burn Claude -25%")
                                        .font(.system(size: 10.5, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                Task {
                                    await apiService.simulateDelta(providerId: "claude", delta: -50.0)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 10))
                                    Text("Critical Drop")
                                        .font(.system(size: 10.5, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                Task {
                                    await apiService.resetSimulation()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 10))
                                    Text("Reset Real Data")
                                        .font(.system(size: 10.5, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.1)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
    }
}
