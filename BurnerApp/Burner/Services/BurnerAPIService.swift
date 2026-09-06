import Foundation
import SwiftUI
import Combine

@MainActor
public class BurnerAPIService: ObservableObject {
    @Published public var providers: [ProviderQuota] = []
    @Published public var overallStatus: ProviderStatus = .healthy
    @Published public var activeRecommendation: RoutingRecommendation?
    @Published public var systemAlert: String?
    @Published public var isServerConnected: Bool = false
    @Published public var isAnalyzing: Bool = false
    @Published public var selectedTaskType: TaskType = .general
    @Published public var lastUpdated: Date = Date()

    private let baseURL = URL(string: "http://127.0.0.1:8000")!
    private var pollingCancellable: AnyCancellable?
    private var previousAlert: String?

    public init() {
        startPolling()
        Task {
            await fetchStatus()
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
            self.isServerConnected = true
            self.lastUpdated = Date()

            // Trigger notification on critical alerts
            if let alert = statusResponse.system_alert, alert != self.previousAlert {
                self.previousAlert = alert
                NotificationManager.shared.sendAlert(
                    title: "Burner Quota Alert",
                    subtitle: "AI Headroom Threshold Crossed",
                    body: alert,
                    identifier: "burner-alert"
                )
            }
        } catch {
            self.isServerConnected = false
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
}
