import Foundation
import SwiftUI

public enum ProviderID: String, Codable, CaseIterable, Identifiable {
    case claude = "claude"
    case cursor = "cursor"
    case codex = "codex"
    case gemini = "gemini"
    case copilot = "copilot"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .cursor: return "Cursor"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        case .copilot: return "Copilot"
        }
    }

    public var iconName: String {
        switch self {
        case .claude: return "brain.head.profile"
        case .cursor: return "cursorarrow.rays"
        case .codex: return "sparkles"
        case .gemini: return "sun.max.fill"
        case .copilot: return "chevron.left.forwardslash.chevron.right"
        }
    }

    public var brandColor: Color {
        switch self {
        case .claude: return Color(red: 0.85, green: 0.45, blue: 0.25)
        case .cursor: return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .codex: return Color(red: 0.1, green: 0.75, blue: 0.5)
        case .gemini: return Color(red: 0.35, green: 0.5, blue: 0.95)
        case .copilot: return Color(red: 0.55, green: 0.35, blue: 0.85)
        }
    }
}

public enum ProviderStatus: String, Codable {
    case healthy = "healthy"
    case warning = "warning"
    case critical = "critical"
    case exhausted = "exhausted"

    public var color: Color {
        switch self {
        case .healthy: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .warning: return Color(red: 1.0, green: 0.65, blue: 0.0)
        case .critical, .exhausted: return Color(red: 1.0, green: 0.25, blue: 0.25)
        }
    }
}

public enum TaskType: String, Codable, CaseIterable, Identifiable {
    case quickEdit = "quick_edit"
    case refactor = "refactor"
    case boilerplate = "boilerplate"
    case architecture = "architecture"
    case general = "general"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .quickEdit: return "Quick Edit"
        case .refactor: return "Refactor"
        case .boilerplate: return "Boilerplate"
        case .architecture: return "Architecture"
        case .general: return "General"
        }
    }

    public var icon: String {
        switch self {
        case .quickEdit: return "pencil.tip"
        case .refactor: return "arrow.triangle.2.circlepath"
        case .boilerplate: return "doc.on.doc"
        case .architecture: return "square.stack.3d.up"
        case .general: return "command"
        }
    }
}

public struct ProviderQuota: Codable, Identifiable {
    public var id: String { provider_id.rawValue }
    public let provider_id: ProviderID
    public let name: String
    public let plan_name: String
    public var quota_remaining_percent: Double
    public let resets_in_seconds: Int
    public var status: ProviderStatus
    public var burn_rate_per_hour: Double
    public var estimated_minutes_to_exhaustion: Int?
    public var is_simulated: Bool
    public let icon_name: String
    public let last_updated: String

    public var formattedCountdown: String {
        let hours = resets_in_seconds / 3600
        let minutes = (resets_in_seconds % 3600) / 60
        if hours >= 24 {
            let days = hours / 24
            return "\(days)d reset"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

public struct ProviderDetectionInfo: Codable, Identifiable {
    public var id: String { provider_id.rawValue }
    public let provider_id: ProviderID
    public let name: String
    public let is_detected: Bool
    public var is_enabled: Bool
    public let detection_reasons: [String]
    public let launch_target: String?
}

public struct SprintBurnForecast: Codable, Identifiable {
    public var id: String { provider_id.rawValue }
    public let provider_id: ProviderID
    public let prompts_last_hour: Int
    public let burn_rate_per_hour: Double
    public let estimated_lockout_time: String?
    public let minutes_until_lockout: Int?
    public let lockout_warning: String?
    public let safe_prompts_remaining: Int
}

public struct RoutingRecommendation: Codable {
    public let recommended_provider: ProviderID
    public let fallback_provider: ProviderID
    public let confidence: Double
    public let headline: String
    public let reasoning: String
    public let burn_rate_warning: String?
    public let suggested_model: String
    public let reasoning_engine: String
    public let created_at: String
}

public struct PromptOptimizationRequestPayload: Codable {
    public let prompt: String
    public let target_provider: String?
    public let task_type: TaskType
}

public struct PromptOptimizationResponse: Codable {
    public let recommended_provider: ProviderID
    public let original_prompt: String
    public let optimized_prompt: String
    public let suggested_model: String
    public let estimated_input_tokens: Int
    public let estimated_output_tokens: Int
    public let token_budget_recommendation: String
    public let provider_quota_headroom_pct: Double
    public let launch_target: String?
    public let explanation: String
}

public struct ProviderTogglePayload: Codable {
    public let provider_id: String
    public let enabled: Bool
}

public struct LaunchPayload: Codable {
    public let provider_id: String?
    public let target: String?
}

public struct StatusResponse: Codable {
    public let providers: [ProviderQuota]
    public let overall_status: ProviderStatus
    public let active_recommendation: RoutingRecommendation?
    public let system_alert: String?
    public let detected_providers: [ProviderID]?
    public let enabled_providers: [ProviderID]?
    public let burn_forecasts: [SprintBurnForecast]?
    public let updated_at: String
}

public struct TaskRequestPayload: Codable {
    public let task_type: TaskType
    public let prompt_preview: String?
    public let context_token_estimate: Int?
}

public struct SimulatePayload: Codable {
    public let provider_id: String
    public let quota_delta: Double?
    public let set_quota: Double?
    public let reset: Bool
}

public struct ChatMessagePayload: Codable, Identifiable {
    public var id: String
    public let role: String
    public let content: String
    public let timestamp: String?

    public init(id: String = UUID().uuidString, role: String, content: String, timestamp: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case timestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.role = try container.decode(String.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
        self.timestamp = try? container.decode(String.self, forKey: .timestamp)
    }
}

public struct ChatRequestPayload: Codable {
    public let messages: [ChatMessagePayload]
    public let task_context: String?

    public init(messages: [ChatMessagePayload], task_context: String? = nil) {
        self.messages = messages
        self.task_context = task_context
    }
}

public struct ChatResponsePayload: Codable {
    public let message: ChatMessagePayload
    public let engine: String
    public let suggested_actions: [String]?
}

public struct HandoffCapsuleRequestPayload: Codable {
    public let source_provider: ProviderID
    public let target_provider: ProviderID?
    public let task_summary: String
    public let code_snippet: String?
    public let unresolved_issues: String?

    public init(
        source_provider: ProviderID,
        target_provider: ProviderID? = nil,
        task_summary: String,
        code_snippet: String? = nil,
        unresolved_issues: String? = nil
    ) {
        self.source_provider = source_provider
        self.target_provider = target_provider
        self.task_summary = task_summary
        self.code_snippet = code_snippet
        self.unresolved_issues = unresolved_issues
    }
}

public struct HandoffCapsuleResponsePayload: Codable {
    public let source_provider: ProviderID
    public let target_provider: ProviderID
    public let capsule_prompt: String
    public let estimated_token_savings: Int
    public let target_quota_headroom_pct: Double
    public let launch_target: String
    public let explanation: String
}

public enum CompressionMode: String, Codable, CaseIterable, Identifiable {
    case balanced = "balanced"
    case aggressive = "aggressive"
    case diffOnly = "diff_only"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .balanced: return "Balanced (-65%)"
        case .aggressive: return "Aggressive (-80%)"
        case .diffOnly: return "Diff Only (-85%)"
        }
    }
}

public struct CodeTrimRequestPayload: Codable {
    public let raw_code: String
    public let language: String?
    public let mode: CompressionMode
    public let task_focus: String?

    public init(
        raw_code: String,
        language: String? = "python",
        mode: CompressionMode = .balanced,
        task_focus: String? = nil
    ) {
        self.raw_code = raw_code
        self.language = language
        self.mode = mode
        self.task_focus = task_focus
    }
}

public struct CodeTrimResponsePayload: Codable {
    public let original_token_count: Int
    public let trimmed_token_count: Int
    public let compression_ratio_pct: Double
    public let trimmed_code: String
    public let safe_prompts_gained: Int
    public let explanation: String
    public let engine: String
}

public struct SprintStagePayload: Codable, Identifiable {
    public var id: Int { stage_number }
    public let stage_number: Int
    public let stage_name: String
    public let assigned_provider: ProviderID
    public let suggested_model: String
    public let prompt_template: String
    public let estimated_tokens: Int
    public let rationale: String
}

public struct SprintPlanRequestPayload: Codable {
    public let task_description: String
    public let target_hours: Double?

    public init(task_description: String, target_hours: Double? = nil) {
        self.task_description = task_description
        self.target_hours = target_hours
    }
}

public struct SprintPlanResponsePayload: Codable {
    public let task_description: String
    public let total_estimated_tokens: Int
    public let tokens_saved_vs_monolith: Int
    public let claude_prompts_preserved: Int
    public let stages: [SprintStagePayload]
    public let explanation: String
    public let engine: String
}



