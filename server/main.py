import subprocess
from typing import List, Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from .models import (
    ChatMessage,
    ChatRequest,
    ChatResponse,
    CodeTrimRequest,
    CodeTrimResponse,
    HandoffCapsuleRequest,
    HandoffCapsuleResponse,
    ProviderID,
    ProviderStatus,
    ProviderDetectionInfo,
    ProviderToggleRequest,
    SprintBurnForecast,
    PromptOptimizationRequest,
    PromptOptimizationResponse,
    RoutingRecommendation,
    SimulateRequest,
    SprintPlanRequest,
    SprintPlanResponse,
    StatusResponse,
    TaskRequest,
    TaskType,
)
from .store import BurnerStore
from .adapters.adapter_manager import AdapterManager
from .agent import BurnerAgent

app = FastAPI(
    title="Burner Agent API",
    description="Local AI quota tracking, burn-rate prediction, auto-discovery, and agentic routing layer.",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

store = BurnerStore()
adapter_manager = AdapterManager(store=store)
agent = BurnerAgent()


class LaunchRequest(BaseModel):
    provider_id: Optional[ProviderID] = None
    target: Optional[str] = None


@app.get("/health")
def health_check():
    return {"status": "ok", "service": "Burner Agent Backend", "version": "2.0.0"}


@app.get("/api/status", response_model=StatusResponse)
def get_status():
    quotas = adapter_manager.get_all_quotas(only_enabled=True)
    detected = adapter_manager.get_detected_providers()
    enabled = adapter_manager.get_enabled_providers()
    forecasts = adapter_manager.get_sprint_burn_forecasts()

    # Determine overall status
    overall = ProviderStatus.HEALTHY
    if any(q.status == ProviderStatus.EXHAUSTED for q in quotas):
        overall = ProviderStatus.CRITICAL
    elif any(q.status == ProviderStatus.CRITICAL for q in quotas):
        overall = ProviderStatus.CRITICAL
    elif any(q.status == ProviderStatus.WARNING for q in quotas):
        overall = ProviderStatus.WARNING

    # Generate default general recommendation (uses cache or heuristic during frequent background status polling)
    default_task = TaskRequest(task_type=TaskType.GENERAL)
    active_rec = agent.recommend(default_task, quotas, force_refresh=False)

    # Check for overall system alert
    alert = active_rec.burn_rate_warning

    return StatusResponse(
        providers=quotas,
        overall_status=overall,
        active_recommendation=active_rec,
        system_alert=alert,
        detected_providers=detected,
        enabled_providers=enabled,
        burn_forecasts=forecasts,
    )


@app.get("/api/providers/detected", response_model=List[ProviderDetectionInfo])
def get_detected_providers():
    return adapter_manager.get_detection_summary()


@app.post("/api/providers/toggle")
def toggle_provider(req: ProviderToggleRequest):
    adapter_manager.set_provider_enabled(req.provider_id, req.enabled)
    enabled = adapter_manager.get_enabled_providers()
    return {
        "provider_id": req.provider_id.value,
        "enabled": req.enabled,
        "active_enabled_providers": [p.value for p in enabled],
    }


@app.post("/api/recommend", response_model=RoutingRecommendation)
def recommend_tool(task: TaskRequest):
    quotas = adapter_manager.get_all_quotas(only_enabled=True)
    return agent.recommend(task, quotas, force_refresh=True)


@app.post("/api/optimize-prompt", response_model=PromptOptimizationResponse)
def optimize_prompt(req: PromptOptimizationRequest):
    quotas = adapter_manager.get_all_quotas(only_enabled=True)
    return agent.optimize_prompt(req, quotas)


@app.post("/api/chat", response_model=ChatResponse)
def chat_with_agent(req: ChatRequest):
    quotas = adapter_manager.get_all_quotas(only_enabled=True)
    return agent.chat(req, quotas)


@app.post("/api/handoff-capsule", response_model=HandoffCapsuleResponse)
def generate_handoff_capsule(req: HandoffCapsuleRequest):
    quotas = adapter_manager.get_all_quotas(only_enabled=True)
    return agent.generate_handoff_capsule(req, quotas)


@app.post("/api/trim-code", response_model=CodeTrimResponse)
def trim_code(req: CodeTrimRequest):
    return agent.trim_code(req)


@app.post("/api/sprint-plan", response_model=SprintPlanResponse)
def plan_sprint(req: SprintPlanRequest):
    quotas = adapter_manager.get_all_quotas(only_enabled=True)
    return agent.plan_sprint(req, quotas)


@app.get("/api/forecast", response_model=List[SprintBurnForecast])
def get_forecast():
    return adapter_manager.get_sprint_burn_forecasts()


@app.post("/api/launch")
def launch_provider(req: LaunchRequest):
    target = req.target
    if not target and req.provider_id:
        target_map = {
            ProviderID.CLAUDE: "Claude",
            ProviderID.CURSOR: "Cursor",
            ProviderID.CODEX: "ChatGPT",
            ProviderID.COPILOT: "Visual Studio Code",
            ProviderID.GEMINI: "https://aistudio.google.com",
        }
        target = target_map.get(req.provider_id)

    if not target:
        raise HTTPException(status_code=400, detail="Missing launch target")

    try:
        if target.startswith("http://") or target.startswith("https://"):
            subprocess.Popen(["open", target])
        else:
            subprocess.Popen(["open", "-a", target])
        return {"status": "launched", "target": target}
    except Exception as e:
        return {"status": "error", "message": str(e), "target": target}


@app.post("/api/simulate")
def simulate_event(req: SimulateRequest):
    if req.reset:
        adapter_manager.reset_simulations()
        return {"message": "All simulations reset to local state", "status": "reset"}

    if req.set_quota is not None:
        adapter_manager.set_simulation_quota(req.provider_id, req.set_quota)
        return {
            "message": f"Set {req.provider_id.value} quota to {req.set_quota}%",
            "provider_id": req.provider_id.value,
            "new_quota": req.set_quota,
        }

    if req.quota_delta is not None:
        new_val = adapter_manager.simulate_delta(req.provider_id, req.quota_delta)
        return {
            "message": f"Adjusted {req.provider_id.value} by {req.quota_delta}%",
            "provider_id": req.provider_id.value,
            "new_quota": new_val,
        }

    raise HTTPException(status_code=400, detail="Must specify set_quota, quota_delta, or reset=True")
