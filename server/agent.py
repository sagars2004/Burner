import os
import json
import logging
from typing import Dict, List, Optional, Tuple

# Suppress google-genai library info/warning messages
logging.getLogger("google_genai").setLevel(logging.ERROR)
logging.getLogger("google.genai").setLevel(logging.ERROR)
from .models import (
    ProviderID,
    ProviderQuota,
    ProviderStatus,
    RoutingRecommendation,
    TaskRequest,
    TaskType,
)


class BurnerAgent:
    """
    The reasoning layer of Burner.
    Combines task requirements, provider quota headroom, reset window cadences,
    and burn-rate trajectory into an actionable routing decision.
    Supports Google Gemini (via Google Cloud), NVIDIA NIM, and robust local heuristic fallback.
    """

    def __init__(self):
        self.gemini_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
        self.nvidia_key = os.getenv("NVIDIA_API_KEY")

        if not self.gemini_key:
            env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
            if os.path.exists(env_path):
                with open(env_path, "r") as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("GEMINI_API_KEY="):
                            self.gemini_key = line.split("=", 1)[1].strip().strip('"').strip("'")
                        elif line.startswith("NVIDIA_API_KEY="):
                            self.nvidia_key = line.split("=", 1)[1].strip().strip('"').strip("'")

    def recommend(self, task: TaskRequest, quotas: List[ProviderQuota]) -> RoutingRecommendation:
        # Step 1: Detect burn rate warnings across providers
        burn_warning = self._check_burn_rate_alerts(quotas)

        # Step 2: Try LLM reasoning (Gemini or NVIDIA NIM) if configured
        if self.gemini_key:
            rec = self._recommend_with_gemini(task, quotas, burn_warning)
            if rec:
                return rec

        if self.nvidia_key:
            rec = self._recommend_with_nvidia(task, quotas, burn_warning)
            if rec:
                return rec

        # Step 3: Fast, deterministic local heuristic engine (always available)
        return self._recommend_with_heuristic(task, quotas, burn_warning)

    def _check_burn_rate_alerts(self, quotas: List[ProviderQuota]) -> Optional[str]:
        for q in quotas:
            if q.status in (ProviderStatus.CRITICAL, ProviderStatus.EXHAUSTED):
                hours = max(1, q.resets_in_seconds // 3600)
                return f"{q.name} quota critical ({q.quota_remaining_percent}% left)! Resets in ~{hours}h."
            if q.estimated_minutes_to_exhaustion and q.estimated_minutes_to_exhaustion < 45:
                return f"Rapid burn detected on {q.name}: exhaustion projected in ~{q.estimated_minutes_to_exhaustion} min."
        return None

    def _recommend_with_heuristic(
        self,
        task: TaskRequest,
        quotas: List[ProviderQuota],
        burn_warning: Optional[str],
    ) -> RoutingRecommendation:
        quota_map: Dict[ProviderID, ProviderQuota] = {q.provider_id: q for q in quotas}

        # Calculate fitness scores for each provider
        scores: Dict[ProviderID, float] = {}

        for pid, q in quota_map.items():
            if q.quota_remaining_percent <= 5.0:
                scores[pid] = -100.0  # basically exhausted
                continue

            score = q.quota_remaining_percent * 0.5  # base score from headroom

            # Reset window bonus: if it resets within 45 min and has headroom, prioritize using it
            if q.resets_in_seconds < 45 * 60 and q.quota_remaining_percent > 25.0:
                score += 30.0

            # Task affinity bonuses
            if task.task_type == TaskType.QUICK_EDIT:
                # Small fixes: favor Cursor fast requests or Copilot
                if pid in (ProviderID.CURSOR, ProviderID.COPILOT):
                    score += 40.0
                elif pid in (ProviderID.CLAUDE, ProviderID.GEMINI):
                    score -= 20.0  # Don't waste heavy quota on quick fixes

            elif task.task_type in (TaskType.REFACTOR, TaskType.ARCHITECTURE):
                # Heavy reasoning: favor Claude 3.5 Sonnet and Gemini Pro
                if pid == ProviderID.CLAUDE:
                    score += 45.0
                elif pid == ProviderID.GEMINI:
                    score += 35.0
                elif pid in (ProviderID.CURSOR, ProviderID.COPILOT):
                    score -= 15.0

            elif task.task_type == TaskType.BOILERPLATE:
                # Tests and boilerplate: favor Codex or Copilot
                if pid in (ProviderID.CODEX, ProviderID.COPILOT):
                    score += 35.0
                elif pid == ProviderID.CURSOR:
                    score += 20.0

            scores[pid] = score

        sorted_providers = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        best_pid = sorted_providers[0][0]
        fallback_pid = sorted_providers[1][0] if len(sorted_providers) > 1 else ProviderID.CURSOR

        best_quota = quota_map[best_pid]
        fallback_quota = quota_map[fallback_pid]

        # Formulate human-centric reasoning
        headline, reasoning, model_name = self._generate_heuristic_narrative(
            task.task_type, best_quota, fallback_quota, burn_warning
        )

        return RoutingRecommendation(
            recommended_provider=best_pid,
            fallback_provider=fallback_pid,
            confidence=0.92,
            headline=headline,
            reasoning=reasoning,
            burn_rate_warning=burn_warning,
            suggested_model=model_name,
            reasoning_engine="burner-heuristic",
        )

    def _generate_heuristic_narrative(
        self,
        task_type: TaskType,
        best: ProviderQuota,
        fallback: ProviderQuota,
        burn_warning: Optional[str],
    ) -> Tuple[str, str, str]:
        best_name = best.name
        fallback_name = fallback.name
        best_pct = int(best.quota_remaining_percent)
        hours_to_reset = max(1, best.resets_in_seconds // 3600)

        model_map = {
            ProviderID.CLAUDE: "Claude 3.5 Sonnet",
            ProviderID.CURSOR: "Cursor Fast (Claude 3.5)",
            ProviderID.CODEX: "GPT-4o mini",
            ProviderID.GEMINI: "Gemini 1.5 Pro",
            ProviderID.COPILOT: "GitHub Copilot",
        }
        suggested_model = model_map.get(best.provider_id, "Standard")

        if task_type == TaskType.QUICK_EDIT:
            headline = f"Route to {best_name} ({best_pct}% headroom)"
            reasoning = (
                f"Quick bug fixes and snippet edits are best routed to {best_name} to preserve "
                f"high-context quotas like Claude for complex refactors. {fallback_name} is on standby."
            )

        elif task_type in (TaskType.REFACTOR, TaskType.ARCHITECTURE):
            if best.provider_id == ProviderID.CLAUDE:
                headline = f"Route to Claude (Sonnet 3.5) — {best_pct}% remaining"
                reasoning = (
                    f"Complex architectural refactors benefit from Claude's superior reasoning and context depth. "
                    f"You have {best_pct}% quota remaining before the next reset window."
                )
            else:
                headline = f"Route to {best_name} ({best_pct}% headroom)"
                reasoning = (
                    f"Claude is conserving quota ({fallback_name} has {int(fallback.quota_remaining_percent)}%). "
                    f"{best_name} offers the best context-to-headroom ratio for this refactor."
                )

        elif task_type == TaskType.BOILERPLATE:
            headline = f"Route to {best_name} for high-throughput code"
            reasoning = (
                f"Generating tests and boilerplate code is well-suited for {best_name}, which has {best_pct}% quota "
                f"reserving more complex models for logic."
            )

        else:
            headline = f"Route to {best_name} ({best_pct}% headroom)"
            reasoning = (
                f"{best_name} currently offers the best combination of remaining quota ({best_pct}%) "
                f"and reset timing (~{hours_to_reset}h). {fallback_name} is your backup."
            )

        if burn_warning and "critical" in burn_warning.lower():
            reasoning = f"⚠️ Limit Avoidance Triggered: {burn_warning} " + reasoning

        return headline, reasoning, suggested_model

    def _recommend_with_gemini(
        self, task: TaskRequest, quotas: List[ProviderQuota], burn_warning: Optional[str]
    ) -> Optional[RoutingRecommendation]:
        try:
            from google import genai
            from google.genai.models import Models
            Models._logged_afc_warning = True
            client = genai.Client(api_key=self.gemini_key)

            prompt = f"""
You are the Burner AI routing agent. Your job is to select the optimal AI coding provider for a developer's next task to prevent hitting free-tier rate limits.

Current Provider Quota State:
{json.dumps([q.model_dump() for q in quotas], indent=2)}

Incoming Task:
Type: {task.task_type.value}
Prompt Preview: {task.prompt_preview or "None provided"}
Estimated Context Tokens: {task.context_token_estimate}

Active Burn Warnings: {burn_warning or "None"}

Return a JSON object with:
- "recommended_provider": string ("claude", "cursor", "codex", "gemini", "copilot")
- "fallback_provider": string
- "confidence": float (0.8 to 0.99)
- "headline": short title (e.g. "Route to Cursor (84% Headroom)")
- "reasoning": 2 sentences explaining why based on quota, reset window, and task type
- "suggested_model": string (e.g. "Claude 3.5 Sonnet", "Gemini 1.5 Pro")
"""
            response = client.models.generate_content(
                model="gemini-3.6-flash",
                contents=prompt,
                config={"response_mime_type": "application/json"}
            )
            data = json.loads(response.text)
            return RoutingRecommendation(
                recommended_provider=ProviderID(data["recommended_provider"]),
                fallback_provider=ProviderID(data["fallback_provider"]),
                confidence=float(data.get("confidence", 0.95)),
                headline=data["headline"],
                reasoning=data["reasoning"],
                burn_rate_warning=burn_warning,
                suggested_model=data.get("suggested_model", "Default Model"),
                reasoning_engine="gemini-3.6-flash",
            )
        except Exception:
            return None

    def _recommend_with_nvidia(
        self, task: TaskRequest, quotas: List[ProviderQuota], burn_warning: Optional[str]
    ) -> Optional[RoutingRecommendation]:
        try:
            from openai import OpenAI
            client = OpenAI(
                base_url="https://integrate.api.nvidia.com/v1",
                api_key=self.nvidia_key,
            )
            prompt = f"""
Analyze this developer task and choose the best AI tool among: claude, cursor, codex, gemini, copilot.
Quotas: {json.dumps([q.model_dump() for q in quotas])}
Task Type: {task.task_type.value}
Respond in valid JSON only with keys: recommended_provider, fallback_provider, confidence, headline, reasoning, suggested_model.
"""
            completion = client.chat.completions.create(
                model="meta/llama-3.1-70b-instruct",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                response_format={"type": "json_object"}
            )
            data = json.loads(completion.choices[0].message.content)
            return RoutingRecommendation(
                recommended_provider=ProviderID(data["recommended_provider"]),
                fallback_provider=ProviderID(data["fallback_provider"]),
                confidence=float(data.get("confidence", 0.92)),
                headline=data["headline"],
                reasoning=data["reasoning"],
                burn_rate_warning=burn_warning,
                suggested_model=data.get("suggested_model", "Llama-3.1-70B"),
                reasoning_engine="nvidia-nim-llama3.1-70b",
            )
        except Exception:
            return None
