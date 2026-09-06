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
                VStack(spacing: 6) {
                    Text("Simulate live quota depletion to demonstrate threshold warnings & instant agent rerouting:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Button(action: {
                            Task {
                                await apiService.simulateDelta(providerId: "claude", delta: -25.0)
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                Text("Burn Claude (-25%)")
                            }
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.18))
                            .foregroundColor(.orange)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            Task {
                                await apiService.simulateDelta(providerId: "cursor", delta: -25.0)
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "cursorarrow.rays")
                                Text("Burn Cursor (-25%)")
                            }
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.18))
                            .foregroundColor(.blue)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button(action: {
                            Task {
                                await apiService.resetSimulation()
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.18))
                            .foregroundColor(.secondary)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .cornerRadius(6)
    }
}
