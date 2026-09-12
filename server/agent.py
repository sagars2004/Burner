import os
import json
import logging
from typing import Dict, List, Optional, Tuple

# Suppress google-genai library info/warning messages
logging.getLogger("google_genai").setLevel(logging.ERROR)
logging.getLogger("google.genai").setLevel(logging.ERROR)

from .models import (
    ChatMessage,
    ChatRequest,
    ChatResponse,
    HandoffCapsuleRequest,
    HandoffCapsuleResponse,
    ProviderID,
    ProviderQuota,
    ProviderStatus,
    RoutingRecommendation,
    PromptOptimizationRequest,
    PromptOptimizationResponse,
    TaskRequest,
    TaskType,
)


class BurnerAgent:
    """
    The reasoning layer of Burner.
    Combines task requirements, provider quota headroom, reset window cadences,
    and burn-rate trajectory into an actionable routing decision.
    Also provides active Prompt Optimization and Token Budgeting for real-world developer workflows.
    Supports Google Gemini (via Google AI Studio Free Tier), NVIDIA NIM, and robust local heuristic fallback.
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

        # Step 3: Fast, deterministic local heuristic engine (always available, 0ms, zero keys needed)
        return self._recommend_with_heuristic(task, quotas, burn_warning)

    def optimize_prompt(
        self, req: PromptOptimizationRequest, quotas: List[ProviderQuota]
    ) -> PromptOptimizationResponse:
        """
        AI Prompt Optimizer & Context Window Budgeter.
        Transforms raw, unoptimized coding tasks into high-precision, token-budgeted prompts
        specifically tailored to the recommended provider's architecture and remaining headroom.
        """
        if self.gemini_key:
            res = self._optimize_with_gemini(req, quotas)
            if res:
                return res

        return self._optimize_with_heuristic(req, quotas)

    def chat(self, req: ChatRequest, quotas: List[ProviderQuota]) -> ChatResponse:
        """
        Gemini-powered interactive quota copilot and AI strategy chatbot.
        Informs developers of live quota statuses, rate-limit avoidance tactics,
        and optimal model distribution for their coding tasks.
        """
        if self.gemini_key:
            res = self._chat_with_gemini(req, quotas)
            if res:
                return res

        return self._chat_with_fallback(req, quotas)

    def generate_handoff_capsule(
        self, req: HandoffCapsuleRequest, quotas: List[ProviderQuota]
    ) -> HandoffCapsuleResponse:
        """
        Cross-tool Hot-Swap Handoff Capsule generator.
        When a developer hits a rate-limit wall or wants to transition tasks between models,
        synthesizes code context, active bugs, and pending steps into a recipient-optimized prompt.
        """
        if self.gemini_key:
            res = self._handoff_with_gemini(req, quotas)
            if res:
                return res

        return self._handoff_with_fallback(req, quotas)

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
        if not quotas:
            return RoutingRecommendation(
                recommended_provider=ProviderID.CLAUDE,
                fallback_provider=ProviderID.CURSOR,
                confidence=0.8,
                headline="No active providers detected",
                reasoning="Enable at least one provider in settings.",
                suggested_model="Claude 3.5 Sonnet",
                reasoning_engine="burner-heuristic",
            )

        quota_map: Dict[ProviderID, ProviderQuota] = {q.provider_id: q for q in quotas}
        scores: Dict[ProviderID, float] = {}

        for pid, q in quota_map.items():
            if q.quota_remaining_percent <= 5.0:
                scores[pid] = -100.0  # essentially exhausted
                continue

            score = q.quota_remaining_percent * 0.5  # base score from headroom

            # Reset window bonus: if resetting within 45 min and has headroom, prioritize spending it
            if q.resets_in_seconds < 45 * 60 and q.quota_remaining_percent > 25.0:
                score += 30.0

            # Task affinity bonuses
            if task.task_type == TaskType.QUICK_EDIT:
                if pid in (ProviderID.CURSOR, ProviderID.COPILOT):
                    score += 40.0
                elif pid in (ProviderID.CLAUDE, ProviderID.GEMINI):
                    score -= 20.0

            elif task.task_type in (TaskType.REFACTOR, TaskType.ARCHITECTURE):
                if pid == ProviderID.CLAUDE:
                    score += 45.0
                elif pid == ProviderID.GEMINI:
                    score += 35.0
                elif pid in (ProviderID.CURSOR, ProviderID.COPILOT):
                    score -= 15.0

            elif task.task_type == TaskType.BOILERPLATE:
                if pid in (ProviderID.CODEX, ProviderID.COPILOT):
                    score += 35.0
                elif pid == ProviderID.CURSOR:
                    score += 20.0

            scores[pid] = score

        sorted_providers = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        best_pid = sorted_providers[0][0]
        fallback_pid = sorted_providers[1][0] if len(sorted_providers) > 1 else best_pid

        best_quota = quota_map[best_pid]
        fallback_quota = quota_map[fallback_pid]

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

    def _optimize_with_heuristic(
        self, req: PromptOptimizationRequest, quotas: List[ProviderQuota]
    ) -> PromptOptimizationResponse:
        quota_dict = {q.provider_id: q for q in quotas}

        # Select target provider
        if req.target_provider and req.target_provider in quota_dict:
            target_pid = req.target_provider
        else:
            # Route to highest headroom or best fit
            default_task = TaskRequest(task_type=req.task_type, prompt_preview=req.prompt)
            rec = self.recommend(default_task, quotas)
            target_pid = rec.recommended_provider

        target_quota = quota_dict.get(
            target_pid,
            ProviderQuota(
                provider_id=target_pid,
                name=target_pid.value.capitalize(),
                quota_remaining_percent=100.0,
                resets_in_seconds=3600,
                status=ProviderStatus.HEALTHY,
            ),
        )

        words = req.prompt.strip().split()
        word_count = len(words)
        est_input_tokens = max(40, int(word_count * 1.35) + 120)
        est_output_tokens = 650 if req.task_type in (TaskType.QUICK_EDIT, TaskType.BOILERPLATE) else 1200

        # Formulate tailored optimized prompt based on target provider's strength
        raw = req.prompt.strip()
        if target_pid == ProviderID.CLAUDE:
            model = "Claude 3.5 Sonnet"
            launch = "Claude"
            optimized = (
                f"You are an expert systems architect and engineer. Implement the following task with precision:\n\n"
                f"### Context & Objective\n{raw}\n\n"
                f"### Requirements\n"
                f"1. Provide a clean, minimal code diff or complete replacement functions.\n"
                f"2. Handle edge cases, nil safety, and boundary conditions explicitly.\n"
                f"3. Do not omit code with placeholders or '// ... remaining code'.\n"
                f"4. Add unit test assertions verifying correctness."
            )
            explanation = "Structured with explicit diff constraints, edge-case coverage, and zero-truncation directives for Claude 3.5 Sonnet."

        elif target_pid == ProviderID.CURSOR:
            model = "Cursor Fast (Claude 3.5)"
            launch = "Cursor"
            optimized = (
                f"// TASK: {raw}\n"
                f"// RULES:\n"
                f"// - Make targeted in-place edits only.\n"
                f"// - Preserve existing signatures, imports, and docstrings.\n"
                f"// - Avoid conversational commentary; output production-ready code directly."
            )
            explanation = "Formatted with concise inline cursor-directive syntax to save tokens and minimize completion latency."

        elif target_pid == ProviderID.CODEX:
            model = "GPT-4o mini"
            launch = "ChatGPT"
            optimized = (
                f"Write robust, typed Python/TypeScript code for the following specification:\n\n"
                f"{raw}\n\n"
                f"Include docstrings, type annotations, and full pytest/jest test coverage."
            )
            explanation = "Optimized for GPT-4o with rigorous typing and full automated test suite boilerplate."

        elif target_pid == ProviderID.GEMINI:
            model = "Gemini 1.5 Pro"
            launch = "https://aistudio.google.com"
            optimized = (
                f"Analyze and implement the following full-stack task within a large repository context:\n\n"
                f"{raw}\n\n"
                f"Provide an architectural breakdown, step-by-step implementation, and integration test strategy."
            )
            explanation = "Structured for Gemini's deep 2M-token context window and multi-file architectural reasoning."

        else:
            model = "GitHub Copilot"
            launch = "Visual Studio Code"
            optimized = f"// Implementation: {raw}\n// Ensure strict types and clean error handling."
            explanation = "Tailored for inline Copilot generation in VS Code."

        # Token budget calculation
        headroom = target_quota.quota_remaining_percent
        pct_cost = round((est_input_tokens + est_output_tokens) / 80000.0 * 100.0, 2)
        budget_rec = f"Consumes ~{pct_cost}% of {target_quota.name} window ({headroom}% headroom remaining)."

        return PromptOptimizationResponse(
            recommended_provider=target_pid,
            original_prompt=req.prompt,
            optimized_prompt=optimized,
            suggested_model=model,
            estimated_input_tokens=est_input_tokens,
            estimated_output_tokens=est_output_tokens,
            token_budget_recommendation=budget_rec,
            provider_quota_headroom_pct=headroom,
            launch_target=launch,
            explanation=explanation,
        )

    def _optimize_with_gemini(
        self, req: PromptOptimizationRequest, quotas: List[ProviderQuota]
    ) -> Optional[PromptOptimizationResponse]:
        try:
            from google import genai
            from google.genai.models import Models
            Models._logged_afc_warning = True
            client = genai.Client(api_key=self.gemini_key)

            system_prompt = f"""
You are the Burner AI Prompt Optimizer & Context Window Budgeting Agent.
A developer submitted this raw coding task:
"{req.prompt}"

Task Category: {req.task_type.value}
Target Provider Request: {req.target_provider.value if req.target_provider else "Auto-Select Optimal"}

Current Connected Quotas:
{json.dumps([q.model_dump() for q in quotas], indent=2)}

Your task:
1. Select the optimal provider from (claude, cursor, codex, gemini, copilot) based on task complexity and remaining quota headroom.
2. Rewrite the prompt into a high-precision, production-grade prompt specifically tailored for that model to succeed in ONE single turn (avoiding costly back-and-forth prompt burning).
3. Estimate input tokens and output tokens.
4. Provide a token budget recommendation relative to remaining quota headroom.

Return JSON only:
{{
  "recommended_provider": "claude" | "cursor" | "codex" | "gemini" | "copilot",
  "suggested_model": string,
  "optimized_prompt": string,
  "estimated_input_tokens": integer,
  "estimated_output_tokens": integer,
  "token_budget_recommendation": string,
  "launch_target": string,
  "explanation": string
}}
"""
            response = client.models.generate_content(
                model="gemini-3.6-flash",
                contents=system_prompt,
                config={"response_mime_type": "application/json"}
            )
            data = json.loads(response.text)
            rec_pid = ProviderID(data["recommended_provider"])
            target_quota = next((q for q in quotas if q.provider_id == rec_pid), None)
            headroom = target_quota.quota_remaining_percent if target_quota else 100.0

            return PromptOptimizationResponse(
                recommended_provider=rec_pid,
                original_prompt=req.prompt,
                optimized_prompt=data["optimized_prompt"],
                suggested_model=data.get("suggested_model", "Optimal Model"),
                estimated_input_tokens=int(data.get("estimated_input_tokens", 150)),
                estimated_output_tokens=int(data.get("estimated_output_tokens", 800)),
                token_budget_recommendation=data.get(
                    "token_budget_recommendation", f"Safe: {headroom}% headroom available"
                ),
                provider_quota_headroom_pct=headroom,
                launch_target=data.get("launch_target", rec_pid.value.capitalize()),
                explanation=data.get("explanation", "Optimized with Gemini 3.6 Flash for maximum first-turn accuracy."),
            )
        except Exception:
            return None

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

    def _chat_with_gemini(
        self, req: ChatRequest, quotas: List[ProviderQuota]
    ) -> Optional[ChatResponse]:
        try:
            from google import genai
            from google.genai.models import Models
            Models._logged_afc_warning = True
            client = genai.Client(api_key=self.gemini_key)

            quota_lines = []
            for q in quotas:
                mins = max(1, q.resets_in_seconds // 60)
                quota_lines.append(
                    f"- {q.name} ({q.provider_id.value}): {q.quota_remaining_percent:.0f}% remaining, resets in ~{mins}m, status: {q.status.value}"
                )
            quota_str = "\n".join(quota_lines)

            history = []
            for msg in req.messages[-6:]:
                history.append(f"{msg.role.upper()}: {msg.content}")
            conv_str = "\n".join(history)

            system_instruction = f"""You are Burner Copilot, a tactical AI pair-programming advisor built into the Burner macOS status bar app.
You have real-time access to the developer's local AI tool quotas:
{quota_str}

Your mission:
1. Help the developer navigate free-tier and subscription rate limits.
2. Recommend the best model/tool for their current coding task (Claude 3.5 Sonnet for deep architecture, Cursor for inline edits, Codex for boilerplate, Gemini 1.5/3 Flash for huge context).
3. Suggest ways to conserve token burn during sprints.
4. Keep answers punchy, practical, and under 3-4 sentences."""

            prompt = f"{system_instruction}\n\nConversation so far:\n{conv_str}\n\nReply as Burner Copilot:"

            response = client.models.generate_content(
                model="gemini-3.6-flash",
                contents=prompt
            )
            text = response.text.strip() if response and response.text else None
            if not text:
                return None

            return ChatResponse(
                message=ChatMessage(role="assistant", content=text),
                engine="gemini-3.6-flash",
                suggested_actions=["Check reset timing", "Optimize my prompt", "Save Claude quota"]
            )
        except Exception as e:
            logging.warning(f"Gemini chat failed, falling back to local strategist: {e}")
            return None

    def _chat_with_fallback(
        self, req: ChatRequest, quotas: List[ProviderQuota]
    ) -> ChatResponse:
        last_msg = req.messages[-1].content.lower() if req.messages else ""

        sorted_quotas = sorted(quotas, key=lambda q: q.quota_remaining_percent, reverse=True)
        top_quota = sorted_quotas[0] if sorted_quotas else None

        if "claude" in last_msg or "sonnet" in last_msg:
            claude_q = next((q for q in quotas if q.provider_id == ProviderID.CLAUDE), None)
            if claude_q:
                mins = max(1, claude_q.resets_in_seconds // 60)
                content = f"Claude Sonnet has {claude_q.quota_remaining_percent:.0f}% quota remaining (resets in ~{mins}m). For quick edits or boilerplate, switch to Cursor or Codex to preserve your Claude turns for complex logic."
            else:
                content = "Claude is currently disabled. Toggle it in detected tools to monitor Sonnet headroom."
        elif "reset" in last_msg or "time" in last_msg or "when" in last_msg:
            resets = [f"{q.name}: ~{max(1, q.resets_in_seconds // 60)}m" for q in quotas[:3]]
            content = f"Upcoming reset windows: {', '.join(resets)}. Your best headroom right now is {top_quota.name if top_quota else 'Codex'} at {top_quota.quota_remaining_percent if top_quota else 80:.0f}%."
        elif "which" in last_msg or "recommend" in last_msg or "refactor" in last_msg or "edit" in last_msg:
            if top_quota:
                content = f"I recommend using **{top_quota.name}** right now—it has the highest headroom at {top_quota.quota_remaining_percent:.0f}%. Use it for high-volume edits, and reserve Claude for complex architectural tasks."
            else:
                content = "Cursor and Codex currently offer the safest headroom for general coding."
        elif "quota" in last_msg or "limit" in last_msg or "save" in last_msg:
            content = f"To preserve quota, route small edits to Cursor/Codex ({top_quota.quota_remaining_percent if top_quota else 85:.0f}% headroom). Reserve Claude Sonnet specifically for multi-file refactoring and architecture."
        else:
            if top_quota:
                content = f"All systems operational! **{top_quota.name}** is your safest bet with {top_quota.quota_remaining_percent:.0f}% headroom. Budget ~15-20 prompts before your next reset window."
            else:
                content = "I'm monitoring your AI provider limits. Let me know what you're working on and I'll route you to the best model."

        return ChatResponse(
            message=ChatMessage(role="assistant", content=content),
            engine="burner-local-strategist",
            suggested_actions=["Check reset timing", "Optimize my prompt", "Save Claude quota"]
        )

    def _handoff_with_gemini(
        self, req: HandoffCapsuleRequest, quotas: List[ProviderQuota]
    ) -> Optional[HandoffCapsuleResponse]:
        try:
            from google import genai
            from google.genai.models import Models
            Models._logged_afc_warning = True
            client = genai.Client(api_key=self.gemini_key)

            target_pid = req.target_provider
            if not target_pid:
                candidates = [q for q in quotas if q.provider_id != req.source_provider]
                candidates.sort(key=lambda q: q.quota_remaining_percent, reverse=True)
                target_pid = candidates[0].provider_id if candidates else ProviderID.CURSOR

            target_quota = next((q for q in quotas if q.provider_id == target_pid), None)
            target_headroom = target_quota.quota_remaining_percent if target_quota else 85.0
            target_name = target_quota.name if target_quota else target_pid.value.capitalize()

            source_quota = next((q for q in quotas if q.provider_id == req.source_provider), None)
            source_name = source_quota.name if source_quota else req.source_provider.value.capitalize()

            prompt = f"""You are the Burner AI Hot-Swap Handoff Agent.
A developer's AI session on {source_name} has hit low quota or rate limits.
Synthesize the session context into a crystal-clear, zero-loss "Handoff Capsule" prompt specifically formatted for the recipient tool: {target_name}.

Session Details:
- Source Provider (Depleted): {source_name}
- Target Provider (Headroom {target_headroom}%): {target_name}
- Task Objective: {req.task_summary}
- Current Code State / Snippet: {req.code_snippet or "None provided"}
- Unresolved Issues / Errors: {req.unresolved_issues or "None listed"}

Requirements:
1. Write a standalone prompt for {target_name} that allows it to continue coding immediately without asking the developer for clarifying questions.
2. Structure it cleanly with markdown.
3. Estimate input token savings (typically 1,500 to 4,000 tokens).

Return valid JSON only:
{{
  "capsule_prompt": string,
  "estimated_token_savings": integer,
  "explanation": string
}}"""

            response = client.models.generate_content(
                model="gemini-3.6-flash",
                contents=prompt,
                config={"response_mime_type": "application/json"}
            )
            data = json.loads(response.text)

            launch_map = {
                ProviderID.CLAUDE: "Claude",
                ProviderID.CURSOR: "Cursor",
                ProviderID.CODEX: "ChatGPT",
                ProviderID.COPILOT: "Visual Studio Code",
                ProviderID.GEMINI: "https://aistudio.google.com",
            }

            return HandoffCapsuleResponse(
                source_provider=req.source_provider,
                target_provider=target_pid,
                capsule_prompt=data["capsule_prompt"],
                estimated_token_savings=int(data.get("estimated_token_savings", 2400)),
                target_quota_headroom_pct=target_headroom,
                launch_target=launch_map.get(target_pid, "Cursor"),
                explanation=data.get("explanation", f"Hot-Swapped seamlessly to {target_name} with {target_headroom}% headroom."),
            )
        except Exception as e:
            logging.warning(f"Gemini handoff generation failed, falling back to local: {e}")
            return None

    def _handoff_with_fallback(
        self, req: HandoffCapsuleRequest, quotas: List[ProviderQuota]
    ) -> HandoffCapsuleResponse:
        target_pid = req.target_provider
        if not target_pid:
            candidates = [q for q in quotas if q.provider_id != req.source_provider]
            candidates.sort(key=lambda q: q.quota_remaining_percent, reverse=True)
            target_pid = candidates[0].provider_id if candidates else ProviderID.CURSOR

        target_quota = next((q for q in quotas if q.provider_id == target_pid), None)
        target_headroom = target_quota.quota_remaining_percent if target_quota else 85.0
        target_name = target_quota.name if target_quota else target_pid.value.capitalize()

        source_quota = next((q for q in quotas if q.provider_id == req.source_provider), None)
        source_name = source_quota.name if source_quota else req.source_provider.value.capitalize()

        launch_map = {
            ProviderID.CLAUDE: "Claude",
            ProviderID.CURSOR: "Cursor",
            ProviderID.CODEX: "ChatGPT",
            ProviderID.COPILOT: "Visual Studio Code",
            ProviderID.GEMINI: "https://aistudio.google.com",
        }

        code_block = f"\n```\n{req.code_snippet}\n```" if req.code_snippet else "*(Code context in active editor)*"
        issues_block = f"\n- {req.unresolved_issues}" if req.unresolved_issues else "None - proceed with next implementation step."

        if target_pid == ProviderID.CURSOR:
            capsule = f"""// 🔄 BURNER HOT-SWAP CAPSULE: {source_name} ──► Cursor
// Quota Alert: Transferred from {source_name} (limit reached). Target headroom: {target_headroom:.0f}%
//
// TASK OBJECTIVE:
// {req.task_summary}
//
// UNRESOLVED ISSUES:
{issues_block}
//
// CURRENT STATE:
{req.code_snippet or "// Refer to open editor buffer"}
//
// DIRECTIVE: Continue implementation directly. Provide complete code without conversational preamble."""
        else:
            capsule = f"""# 🔄 HOT-SWAP CONTEXT HANDOFF: {source_name} ──► {target_name}
> **Transferred by Burner**: {source_name} quota depleted. Continuing session on {target_name} ({target_headroom:.0f}% headroom).

## 🎯 Task Objective
{req.task_summary}

## ⚡ Current Code State
{code_block}

## ⚠️ Unresolved Issues / Blockers
{issues_block}

## 🚀 Immediate Next Action
Please continue directly from the code state above and resolve the listed blockers. Do not repeat existing boilerplate or ask for re-explanation."""

        return HandoffCapsuleResponse(
            source_provider=req.source_provider,
            target_provider=target_pid,
            capsule_prompt=capsule,
            estimated_token_savings=2650,
            target_quota_headroom_pct=target_headroom,
            launch_target=launch_map.get(target_pid, "Cursor"),
            explanation=f"Seamlessly hot-swapped from {source_name} to {target_name} ({target_headroom:.0f}% headroom).",
        )


