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

            // Upper Scrollable Tools & Simulation Controls
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
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
                .padding(14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().background(Color.white.opacity(0.12))

            // Fixed-Height Gemini Chatbot Section at the Bottom
            GeminiChatView(apiService: apiService)
                .frame(height: 250)
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

// MARK: - Gemini Chat View Component

struct GeminiChatView: View {
    @ObservedObject var apiService: BurnerAPIService
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.35, green: 0.5, blue: 0.95), Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Gemini Quota Copilot")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)

                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)

                Spacer()

                Text(apiService.chatEngine)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.25))

            Divider().background(Color.white.opacity(0.06))

            // Scrollable Messages Container (Inner scrolling strictly contained)
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 8) {
                        ForEach(apiService.chatMessages) { msg in
                            ChatBubbleRow(msg: msg)
                        }

                        if apiService.isChatLoading {
                            HStack {
                                HStack(spacing: 5) {
                                    Text("Gemini is thinking")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.gray)
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 12, height: 12)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(10)
                                Spacer()
                            }
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("CHAT_BOTTOM")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: apiService.chatMessages.count) { _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("CHAT_BOTTOM", anchor: .bottom)
                    }
                }
                .onChange(of: apiService.isChatLoading) { loading in
                    if loading {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("CHAT_BOTTOM", anchor: .bottom)
                        }
                    }
                }
            }

            // Quick Prompt Suggestion Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    QuickChip(title: "Save Claude quota", icon: "flame.fill") {
                        sendQuickMessage("How can I save my Claude quota right now?")
                    }
                    QuickChip(title: "Best tool for refactor", icon: "arrow.triangle.2.circlepath") {
                        sendQuickMessage("Which tool should I use for a large code refactor?")
                    }
                    QuickChip(title: "Check reset timing", icon: "clock.fill") {
                        sendQuickMessage("When do my provider limits reset?")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            // Input Field & Send Button
            HStack(spacing: 8) {
                TextField("Ask Gemini about quota strategy...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .onSubmit {
                        submit()
                    }

                Button(action: { submit() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(canSubmit ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.gray.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .padding(.top, 4)
        }
        .background(Color.black.opacity(0.2))
    }

    private var canSubmit: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !apiService.isChatLoading
    }

    private func submit() {
        guard canSubmit else { return }
        let text = inputText
        inputText = ""
        Task {
            await apiService.sendChatMessage(text)
        }
    }

    private func sendQuickMessage(_ text: String) {
        guard !apiService.isChatLoading else { return }
        Task {
            await apiService.sendChatMessage(text)
        }
    }
}

// MARK: - Chat Bubble Row Component

struct ChatBubbleRow: View {
    let msg: ChatMessagePayload

    var isUser: Bool {
        msg.role.lowercased() == "user"
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isUser {
                Spacer(minLength: 32)
                Text(msg.content)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color(red: 0.0, green: 0.48, blue: 1.0)) // iMessage Blue
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            } else {
                Text(msg.content)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12)) // Semi-transparent gray
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                Spacer(minLength: 32)
            }
        }
    }
}

// MARK: - Quick Chip Component

struct QuickChip: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8.5))
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.75))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

