import SwiftUI

public struct AgentRecommendationDeck: View {
    @ObservedObject public var apiService: BurnerAPIService
    @State private var hasCopied: Bool = false

    public init(apiService: BurnerAPIService) {
        self.apiService = apiService
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text("AGENT ROUTING ENGINE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let rec = apiService.activeRecommendation {
                    HStack(spacing: 3) {
                        Image(systemName: rec.reasoning_engine.contains("gemini") ? "sparkles" : "cpu")
                        Text(rec.reasoning_engine.contains("gemini") ? "Gemini 2.0" : "Local Heuristic")
                    }
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
                }
            }

            // Task Type Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach([TaskType.general, TaskType.quickEdit, TaskType.refactor, TaskType.boilerplate, TaskType.architecture]) { type in
                        Button(action: {
                            Task {
                                await apiService.requestRecommendation(taskType: type)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 9))
                                Text(type.title)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(apiService.selectedTaskType == type ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                            .foregroundColor(apiService.selectedTaskType == type ? .white : .primary)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Active Recommendation Card
            if apiService.isAnalyzing {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing quota headroom & task weight...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 10)
            } else if let rec = apiService.activeRecommendation {
                VStack(alignment: .leading, spacing: 6) {
                    // Recommendation Headline
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 13))

                        Text(rec.headline)
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)

                        Spacer()

                        Text(rec.suggested_model)
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }

                    // Reasoning Details
                    Text(rec.reasoning)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Burn Rate Warning (if present)
                    if let warning = rec.burn_rate_warning {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text(warning)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    }

                    // Action Buttons (Handoff / Copy)
                    HStack {
                        Spacer()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(
                                "[\(rec.headline)]\n\(rec.reasoning)\nSuggested: \(rec.suggested_model)",
                                forType: .string
                            )
                            hasCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                hasCopied = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                                Text(hasCopied ? "Copied to Clipboard!" : "Copy Advice")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(hasCopied ? .green : .accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
                .padding(10)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(11)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.7))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
