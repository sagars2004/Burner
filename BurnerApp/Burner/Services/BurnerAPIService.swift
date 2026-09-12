import Foundation
import SwiftUI
import Combine

@MainActor
public class BurnerAPIService: ObservableObject {
    @Published public var providers: [ProviderQuota] = []
    @Published public var overallStatus: ProviderStatus = .healthy
    @Published public var activeRecommendation: RoutingRecommendation?
    @Published public var systemAlert: String?
    @Published public var detectedProviders: [ProviderDetectionInfo] = []
    @Published public var burnForecasts: [SprintBurnForecast] = []
    @Published public var latestOptimization: PromptOptimizationResponse?
    @Published public var isOptimizing: Bool = false
    @Published public var isServerConnected: Bool = false
    @Published public var isAnalyzing: Bool = false
    @Published public var selectedTaskType: TaskType = .general
    @Published public var lastUpdated: Date = Date()
    @Published public var chatMessages: [ChatMessagePayload] = [
        ChatMessagePayload(
            role: "assistant",
            content: "Hey! I'm your Gemini Quota Copilot. Ask me about model limits, token budgeting, or which tool to use next to prevent rate-limit lockouts."
        )
    ]
    @Published public var isChatLoading: Bool = false
    @Published public var chatEngine: String = "gemini-3.6-flash"

    private let baseURL = URL(string: "http://127.0.0.1:8000")!
    private var pollingCancellable: AnyCancellable?
    private var previousAlert: String?

    public init() {
        startPolling()
        Task {
            await fetchStatus()
            await fetchDetectedProviders()
        }
    }

    public func startPolling() {
        pollingCancellable = Timer.publish(every: 8.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.fetchStatus()
                }
            }
    }

    public func stopPolling() {
        pollingCancellable?.cancel()
    }

    public func fetchStatus() async {
        let endpoint = baseURL.appendingPathComponent("/api/status")
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 3.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.isServerConnected = false
                return
            }

            let decoder = JSONDecoder()
            let statusResponse = try decoder.decode(StatusResponse.self, from: data)

            self.providers = statusResponse.providers
            self.overallStatus = statusResponse.overall_status
            if self.activeRecommendation == nil || self.selectedTaskType == .general {
                self.activeRecommendation = statusResponse.active_recommendation
            }
            self.systemAlert = statusResponse.system_alert
            if let forecasts = statusResponse.burn_forecasts {
                self.burnForecasts = forecasts
            }
            self.isServerConnected = true
            self.lastUpdated = Date()

            // Trigger notification on critical alerts
            if let alert = statusResponse.system_alert, alert != self.previousAlert {
                self.previousAlert = alert
                NotificationManager.shared.sendAlert(
                    title: "Burner Quota Alert",
                    subtitle: "AI Limit Wall Approaching",
                    body: alert,
                    identifier: "burner-alert"
                )
            }
        } catch {
            self.isServerConnected = false
        }
    }

    public func fetchDetectedProviders() async {
        let endpoint = baseURL.appendingPathComponent("/api/providers/detected")
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 3.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            let decoder = JSONDecoder()
            self.detectedProviders = try decoder.decode([ProviderDetectionInfo].self, from: data)
        } catch {
            print("Failed to fetch detected providers: \(error)")
        }
    }

    public func toggleProvider(providerId: ProviderID, enabled: Bool) async {
        let endpoint = baseURL.appendingPathComponent("/api/providers/toggle")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ProviderTogglePayload(provider_id: providerId.rawValue, enabled: enabled)
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            _ = try await URLSession.shared.data(for: request)
            await fetchStatus()
            await fetchDetectedProviders()
        } catch {
            print("Failed to toggle provider: \(error)")
        }
    }

    public func requestRecommendation(taskType: TaskType, prompt: String = "") async {
        self.selectedTaskType = taskType
        self.isAnalyzing = true
        defer { self.isAnalyzing = false }

        let endpoint = baseURL.appendingPathComponent("/api/recommend")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0

        let payload = TaskRequestPayload(
            task_type: taskType,
            prompt_preview: prompt.isEmpty ? nil : prompt,
            context_token_estimate: taskType == .architecture ? 4000 : 1500
        )

        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }

            let decoder = JSONDecoder()
            self.activeRecommendation = try decoder.decode(RoutingRecommendation.self, from: data)
        } catch {
            print("Failed to fetch recommendation: \(error)")
        }
    }

    public func optimizePrompt(prompt: String, taskType: TaskType, targetProvider: ProviderID? = nil) async -> PromptOptimizationResponse? {
        self.isOptimizing = true
        defer { self.isOptimizing = false }

        let endpoint = baseURL.appendingPathComponent("/api/optimize-prompt")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0

        let payload = PromptOptimizationRequestPayload(
            prompt: prompt,
            target_provider: targetProvider?.rawValue,
            task_type: taskType
        )

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            let decoder = JSONDecoder()
            let res = try decoder.decode(PromptOptimizationResponse.self, from: data)
            self.latestOptimization = res
            return res
        } catch {
            print("Failed to optimize prompt: \(error)")
            return nil
        }
    }

    public func launchTarget(providerId: ProviderID? = nil, target: String? = nil) async {
        let endpoint = baseURL.appendingPathComponent("/api/launch")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = LaunchPayload(provider_id: providerId?.rawValue, target: target)
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to launch target: \(error)")
        }
    }

    public func simulateDelta(providerId: String, delta: Double) async {
        let endpoint = baseURL.appendingPathComponent("/api/simulate")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = SimulatePayload(provider_id: providerId, quota_delta: delta, set_quota: nil, reset: false)
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            _ = try await URLSession.shared.data(for: request)
            await fetchStatus()
            await requestRecommendation(taskType: selectedTaskType)
        } catch {
            print("Simulation failed: \(error)")
        }
    }

    public func resetSimulation() async {
        let endpoint = baseURL.appendingPathComponent("/api/simulate")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = SimulatePayload(provider_id: "claude", quota_delta: nil, set_quota: nil, reset: true)
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            _ = try await URLSession.shared.data(for: request)
            await fetchStatus()
            await requestRecommendation(taskType: selectedTaskType)
        } catch {
            print("Reset simulation failed: \(error)")
        }
    }

    public var menuBarIcon: String {
        switch overallStatus {
        case .healthy: return "flame.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical, .exhausted: return "bell.badge.fill"
        }
    }

    public var menuBarColor: Color {
        overallStatus.color
    }

    public var lowestQuotaWarning: String? {
        if let criticalProvider = providers.first(where: { $0.status == .critical || $0.status == .exhausted }) {
            return "\(criticalProvider.name): \(Int(criticalProvider.quota_remaining_percent))%"
        }
        return nil
    }

    public func forecastFor(providerId: ProviderID) -> SprintBurnForecast? {
        burnForecasts.first(where: { $0.provider_id == providerId })
    }

    public func sendChatMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMsg = ChatMessagePayload(role: "user", content: trimmed)
        chatMessages.append(userMsg)
        isChatLoading = true

        let endpoint = baseURL.appendingPathComponent("/api/chat")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12.0

        let payload = ChatRequestPayload(messages: chatMessages)
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                appendFallbackChatError()
                isChatLoading = false
                return
            }

            let decoder = JSONDecoder()
            let chatRes = try decoder.decode(ChatResponsePayload.self, from: data)
            chatMessages.append(chatRes.message)
            chatEngine = chatRes.engine
        } catch {
            appendFallbackChatError()
        }
        isChatLoading = false
    }

    private func appendFallbackChatError() {
        let top = providers.sorted(by: { $0.quota_remaining_percent > $1.quota_remaining_percent }).first
        let topName = top?.name ?? "Codex"
        let topPct = top != nil ? "\(Int(top!.quota_remaining_percent))%" : "high"
        chatMessages.append(
            ChatMessagePayload(
                role: "assistant",
                content: "I'm having trouble connecting to Gemini, but your live quotas show \(topName) currently has the safest headroom (\(topPct)). Route your next task there!"
            )
        )
    }
}

