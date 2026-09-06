import SwiftUI

public struct AgentRecommendationDeck: View {
    @ObservedObject public var apiService: BurnerAPIService
    @State private var hasCopied: Bool = false
    @State private var promptText: String = ""
    @State private var showPromptInput: Bool = false

    public init(apiService: BurnerAPIService) {
        self.apiService = apiService
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text("AI AGENT ROUTING")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let rec = apiService.activeRecommendation {
                    HStack(spacing: 4) {
                        Image(systemName: rec.reasoning_engine.contains("gemini") ? "sparkles" : "cpu")
                        Text(rec.reasoning_engine.contains("gemini") ? "Google Gemini" : "Local Heuristic")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .cornerRadius(5)
                }
            }

            // Task Type Selector Tabs
            HStack(spacing: 6) {
                ForEach([TaskType.general, TaskType.quickEdit, TaskType.refactor, TaskType.boilerplate, TaskType.architecture]) { type in
                    Button(action: {
                        Task {
                            await apiService.requestRecommendation(taskType: type, prompt: promptText)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.system(size: 9))
                            Text(type.title)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(apiService.selectedTaskType == type ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                        .foregroundColor(apiService.selectedTaskType == type ? .white : .primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Optional Prompt Input Toggle
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPromptInput.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showPromptInput ? "chevron.down" : "plus.circle")
                        Text(showPromptInput ? "Hide prompt analysis" : "Analyze specific prompt / task...")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if showPromptInput {
                HStack(spacing: 6) {
                    TextField("e.g. Refactor authentication module to OAuth2", text: $promptText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))

                    Button("Evaluate") {
                        Task {
                            await apiService.requestRecommendation(taskType: apiService.selectedTaskType, prompt: promptText)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.top, 2)
            }

            // Active Recommendation Card
            if apiService.isAnalyzing {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing multi-provider quotas & token cost...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if let rec = apiService.activeRecommendation {
                VStack(alignment: .leading, spacing: 8) {
                    // Recommendation Headline (No truncation!)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 15))
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.headline)
                                .font(.system(size: 13, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 6) {
                                Text("Suggested: \(rec.suggested_model)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.accentColor)

                                Text("•")
                                    .foregroundColor(.secondary)

                                Text("Backup: \(rec.fallback_provider.displayName)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }

                    // Full Reasoning Details
                    Text(rec.reasoning)
                        .font(.system(size: 11.5))
                        .foregroundColor(.primary.opacity(0.85))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Burn Rate Warning Banner (if present)
                    if let warning = rec.burn_rate_warning {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text(warning)
                                .font(.system(size: 11, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundColor(.orange)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(6)
                    }

                    // Action Buttons (Copy / Handoff)
                    HStack {
                        Spacer()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(
                                "[\(rec.headline)]\n\(rec.reasoning)\nModel: \(rec.suggested_model)",
                                forType: .string
                            )
                            hasCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                hasCopied = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                                Text(hasCopied ? "Copied!" : "Copy Advice")
                            }
                            .font(.system(size: 10.5, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .foregroundColor(hasCopied ? .green : .accentColor)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(11)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.7))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
