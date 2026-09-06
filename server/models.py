from enum import Enum
from typing import List, Optional
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


class StatusResponse(BaseModel):
    providers: List[ProviderQuota]
    overall_status: ProviderStatus
    active_recommendation: Optional[RoutingRecommendation] = None
    system_alert: Optional[str] = None
    updated_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())


class SimulateRequest(BaseModel):
    provider_id: ProviderID
    quota_delta: Optional[float] = None
    set_quota: Optional[float] = None
    reset: bool = False
