import SwiftUI
import AppKit

public struct PromptOptimizerView: View {
    @ObservedObject public var apiService: BurnerAPIService
    @Binding public var isPresented: Bool

    @State private var inputPrompt: String = ""
    @State private var selectedTaskType: TaskType = .refactor
    @State private var selectedProvider: ProviderID? = nil
    @State private var copied: Bool = false
    @State private var launched: Bool = false

    public init(apiService: BurnerAPIService, isPresented: Binding<Bool>) {
        self.apiService = apiService
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.cyan)

                    Text("AI Prompt Optimizer & Context Budgeter")
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
                VStack(alignment: .leading, spacing: 14) {
                    // Task Type Selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TASK INTENT")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.gray)

                        HStack(spacing: 6) {
                            ForEach([TaskType.quickEdit, TaskType.refactor, TaskType.boilerplate, TaskType.architecture]) { t in
                                Button(action: {
                                    selectedTaskType = t
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: t.icon)
                                            .font(.system(size: 10))
                                        Text(t.title)
                                            .font(.system(size: 11, weight: selectedTaskType == t ? .semibold : .regular))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(selectedTaskType == t ? Color.cyan.opacity(0.25) : Color.white.opacity(0.05))
                                    .foregroundColor(selectedTaskType == t ? .cyan : .white.opacity(0.8))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedTaskType == t ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Input Prompt Area
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR TASK OR RAW PROMPT")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.gray)

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $inputPrompt)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(8)
                                .frame(height: 80)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )

                            if inputPrompt.isEmpty {
                                Text("e.g., Refactor the user auth flow to use OAuth2 and biometrics...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(12)
                                    .allowsHitTesting(false)
                            }
                        }
                    }

                    // Optimize Button
                    Button(action: {
                        Task {
                            _ = await apiService.optimizePrompt(
                                prompt: inputPrompt.isEmpty ? "Write unit tests and refactor module" : inputPrompt,
                                taskType: selectedTaskType,
                                targetProvider: selectedProvider
                            )
                        }
                    }) {
                        HStack(spacing: 6) {
                            if apiService.isOptimizing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 14, height: 14)
                                Text("Analyzing Headroom & Rewriting...")
                                    .font(.system(size: 12, weight: .semibold))
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Optimize Prompt for Optimal Provider")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(apiService.isOptimizing)

                    // Optimization Output
                    if let result = apiService.latestOptimization {
                        VStack(alignment: .leading, spacing: 10) {
                            // Target Tool & Token Budget Card
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: result.recommended_provider.iconName)
                                            .font(.system(size: 12))
                                            .foregroundColor(result.recommended_provider.brandColor)

                                        Text(result.suggested_model)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }

                                    Spacer()

                                    Text("\(Int(result.provider_quota_headroom_pct))% headroom")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }

                                // Token Budget Callout
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Est. Input")
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                        Text("~\(result.estimated_input_tokens) tokens")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.white)
                                    }

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Est. Output")
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                        Text("~\(result.estimated_output_tokens) tokens")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.white)
                                    }

                                    Spacer()
                                }

                                Text(result.token_budget_recommendation)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(.cyan.opacity(0.9))

                                Text(result.explanation)
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )

                            // Optimized Code Prompt
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("OPTIMIZED PROMPT")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("Ready for 1-Turn Execution")
                                        .font(.system(size: 9))
                                        .foregroundColor(.green)
                                }

                                ScrollView {
                                    Text(result.optimized_prompt)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(height: 110)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }

                            // Action Row: Copy vs Copy & Launch
                            HStack(spacing: 8) {
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(result.optimized_prompt, forType: .string)
                                    copied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        copied = false
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 11))
                                        Text(copied ? "Copied!" : "Copy Prompt")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(result.optimized_prompt, forType: .string)
                                    Task {
                                        await apiService.launchTarget(providerId: result.recommended_provider, target: result.launch_target)
                                    }
                                    launched = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        launched = false
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: launched ? "checkmark.circle.fill" : "arrow.up.forward.app.fill")
                                            .font(.system(size: 11))
                                        Text(launched ? "Launched!" : "Copy & Launch \(result.launch_target ?? "Tool")")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(Color.green.opacity(0.85))
                                    .foregroundColor(.black)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
    }
}
