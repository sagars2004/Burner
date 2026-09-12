from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field
from datetime import datetime


class ProviderID(str, Enum):
    CLAUDE = "claude"
    CURSOR = "cursor"
    CODEX = "codex"
    GEMINI = "gemini"
    COPILOT = "copilot"


class ProviderStatus(str, Enum):
    HEALTHY = "healthy"       # > 40%
    WARNING = "warning"       # 20% - 40%
    CRITICAL = "critical"     # < 20%
    EXHAUSTED = "exhausted"   # 0%


class TaskType(str, Enum):
    QUICK_EDIT = "quick_edit"       # Short bug fix, typo, single function tweak
    REFACTOR = "refactor"           # Multi-file refactor, large architectural shift
    BOILERPLATE = "boilerplate"     # Writing tests, models, boilerplate code
    ARCHITECTURE = "architecture"   # System design, high-level planning, complex reasoning
    GENERAL = "general"             # General coding assistance


class ProviderQuota(BaseModel):
    provider_id: ProviderID
    name: str
    plan_name: str = "Free Tier"
    quota_remaining_percent: float = Field(..., ge=0.0, le=100.0)
    resets_in_seconds: int = Field(..., ge=0)
    status: ProviderStatus
    burn_rate_per_hour: float = 0.0  # Estimated % consumed per hour
    estimated_minutes_to_exhaustion: Optional[int] = None
    is_simulated: bool = False
    icon_name: str = "bolt.fill"
    last_updated: str = Field(default_factory=lambda: datetime.utcnow().isoformat())


class ProviderDetectionInfo(BaseModel):
    provider_id: ProviderID
    name: str
    is_detected: bool
    is_enabled: bool
    detection_reasons: List[str] = Field(default_factory=list)
    launch_target: Optional[str] = None


class ProviderToggleRequest(BaseModel):
    provider_id: ProviderID
    enabled: bool


class SprintBurnForecast(BaseModel):
    provider_id: ProviderID
    prompts_last_hour: int = 0
    burn_rate_per_hour: float = 0.0
    estimated_lockout_time: Optional[str] = None
    minutes_until_lockout: Optional[int] = None
    lockout_warning: Optional[str] = None
    safe_prompts_remaining: int = 0


class TaskRequest(BaseModel):
    task_type: TaskType = TaskType.GENERAL
    prompt_preview: Optional[str] = ""
    context_token_estimate: Optional[int] = 1500


class RoutingRecommendation(BaseModel):
    recommended_provider: ProviderID
    fallback_provider: ProviderID
    confidence: float = Field(0.9, ge=0.0, le=1.0)
    headline: str
    reasoning: str
    burn_rate_warning: Optional[str] = None
    suggested_model: str
    reasoning_engine: str = "burner-heuristic"
    created_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())


class PromptOptimizationRequest(BaseModel):
    prompt: str
    target_provider: Optional[ProviderID] = None
    task_type: TaskType = TaskType.GENERAL


class PromptOptimizationResponse(BaseModel):
    recommended_provider: ProviderID
    original_prompt: str
    optimized_prompt: str
    suggested_model: str
    estimated_input_tokens: int
    estimated_output_tokens: int
    token_budget_recommendation: str
    provider_quota_headroom_pct: float
    launch_target: Optional[str] = None
    explanation: str


class StatusResponse(BaseModel):
    providers: List[ProviderQuota]
    overall_status: ProviderStatus
    active_recommendation: Optional[RoutingRecommendation] = None
    system_alert: Optional[str] = None
    detected_providers: List[ProviderID] = Field(default_factory=list)
    enabled_providers: List[ProviderID] = Field(default_factory=list)
    burn_forecasts: List[SprintBurnForecast] = Field(default_factory=list)
    updated_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())


class SimulateRequest(BaseModel):
    provider_id: ProviderID
    quota_delta: Optional[float] = None
    set_quota: Optional[float] = None
    reset: bool = False


class ChatMessage(BaseModel):
    id: Optional[str] = None
    role: str = "user"  # "user" | "assistant" | "system"
    content: str
    timestamp: Optional[str] = Field(default_factory=lambda: datetime.utcnow().isoformat())


class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    task_context: Optional[str] = None


class ChatResponse(BaseModel):
    message: ChatMessage
    engine: str = "gemini-3.6-flash"
    suggested_actions: List[str] = Field(default_factory=list)


class HandoffCapsuleRequest(BaseModel):
    source_provider: ProviderID
    target_provider: Optional[ProviderID] = None
    task_summary: str
    code_snippet: Optional[str] = ""
    unresolved_issues: Optional[str] = ""


class HandoffCapsuleResponse(BaseModel):
    source_provider: ProviderID
    target_provider: ProviderID
    capsule_prompt: str
    estimated_token_savings: int
    target_quota_headroom_pct: float
    launch_target: str
    explanation: str


