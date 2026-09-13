import SwiftUI

public struct DemoSimulationDrawer: View {
    @ObservedObject public var apiService: BurnerAPIService
    @State private var isExpanded: Bool = false

    public init(apiService: BurnerAPIService) {
        self.apiService = apiService
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10))
                    Text("Hackathon Simulation Controls")
                        .font(.system(size: 10, weight: .semibold))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    Text("Simulate live quota depletion to demonstrate threshold warnings & instant agent rerouting:")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        Button(action: {
                            Task { await apiService.simulateDelta(providerId: "claude", delta: -25.0) }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                Text("Burn Claude")
                            }
                            .font(.system(size: 9.5, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4.5)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.orange.opacity(0.3), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            Task { await apiService.simulateDelta(providerId: "cursor", delta: -25.0) }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "cursorarrow.rays")
                                Text("Burn Cursor")
                            }
                            .font(.system(size: 9.5, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4.5)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.blue.opacity(0.3), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            Task { await apiService.simulateDelta(providerId: "codex", delta: -25.0) }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "curlybraces")
                                Text("Burn Codex")
                            }
                            .font(.system(size: 9.5, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4.5)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.green.opacity(0.3), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            Task { await apiService.simulateDelta(providerId: "gemini", delta: -25.0) }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Burn Gemini")
                            }
                            .font(.system(size: 9.5, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4.5)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.purple.opacity(0.3), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            Task { await apiService.simulateDelta(providerId: "copilot", delta: -25.0) }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                Text("Burn Copilot")
                            }
                            .font(.system(size: 9.5, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4.5)
                            .background(Color.teal.opacity(0.2))
                            .foregroundColor(.teal)
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.teal.opacity(0.3), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            Task { await apiService.resetSimulation() }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset All")
                            }
                            .font(.system(size: 9.5, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4.5)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white.opacity(0.8))
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}
