from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .models import (
    ProviderID,
    ProviderStatus,
    RoutingRecommendation,
    SimulateRequest,
    StatusResponse,
    TaskRequest,
    TaskType,
)
from .store import BurnerStore
from .adapters.adapter_manager import AdapterManager
from .agent import BurnerAgent

app = FastAPI(
    title="Burner Agent API",
    description="Local AI quota tracking, burn-rate prediction, and agentic routing layer.",
    version="1.0.0",
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


@app.get("/health")
def health_check():
    return {"status": "ok", "service": "Burner Agent Backend", "version": "1.0.0"}


@app.get("/api/status", response_model=StatusResponse)
def get_status():
    quotas = adapter_manager.get_all_quotas()

    # Determine overall status
    overall = ProviderStatus.HEALTHY
    if any(q.status == ProviderStatus.EXHAUSTED for q in quotas):
        overall = ProviderStatus.CRITICAL
    elif any(q.status == ProviderStatus.CRITICAL for q in quotas):
        overall = ProviderStatus.CRITICAL
    elif any(q.status == ProviderStatus.WARNING for q in quotas):
        overall = ProviderStatus.WARNING

    # Generate default general recommendation
    default_task = TaskRequest(task_type=TaskType.GENERAL)
    active_rec = agent.recommend(default_task, quotas)

    # Check for overall system alert
    alert = active_rec.burn_rate_warning

    return StatusResponse(
        providers=quotas,
        overall_status=overall,
        active_recommendation=active_rec,
        system_alert=alert,
    )


@app.post("/api/recommend", response_model=RoutingRecommendation)
def recommend_tool(task: TaskRequest):
    quotas = adapter_manager.get_all_quotas()
    return agent.recommend(task, quotas)


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
