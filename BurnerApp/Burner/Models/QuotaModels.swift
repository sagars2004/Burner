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
        case .healthy: return .green
        case .warning: return .orange
        case .critical, .exhausted: return .red
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
    public var is_simulated: bool_or_false
    public let icon_name: String
    public let last_updated: String

    public typealias bool_or_false = Bool

    public var formattedCountdown: String {
        let hours = resets_in_seconds / 3600
        let minutes = (resets_in_seconds % 3600) / 60
        if hours >= 24 {
            let days = hours / 24
            return "Resets in \(days)d"
        } else if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }
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

public struct StatusResponse: Codable {
    public let providers: [ProviderQuota]
    public let overall_status: ProviderStatus
    public let active_recommendation: RoutingRecommendation?
    public let system_alert: String?
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
