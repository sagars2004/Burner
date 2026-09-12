import os
import shutil
from typing import Dict, List, Optional, Tuple
from ..models import ProviderID, ProviderDetectionInfo


class SystemDetector:
    """
    Auto-discovers installed AI developer tools and CLI sessions on macOS.
    Allows Burner to display only the tools the user actually has installed,
    mimicking CodexBar's privacy-first auto-detection and zero-hardcoded-key setup.
    """

    @staticmethod
    def detect_claude() -> Tuple[bool, List[str], Optional[str]]:
        reasons = []
        launch_target = "Claude"
        app_paths = [
            "/Applications/Claude.app",
            os.path.expanduser("~/Applications/Claude.app"),
        ]
        for p in app_paths:
            if os.path.exists(p):
                reasons.append(f"Desktop app installed: {p}")
                launch_target = p
                break

        data_paths = [
            os.path.expanduser("~/Library/Application Support/Claude/plan-usage-history.json"),
            os.path.expanduser("~/Library/Application Support/Claude"),
            os.path.expanduser("~/.claude.json"),
        ]
        for p in data_paths:
            if os.path.exists(p):
                reasons.append(f"Session data: {os.path.basename(p)}")

        cli = shutil.which("claude")
        if cli:
            reasons.append(f"CLI binary: {cli}")

        return (len(reasons) > 0, reasons, launch_target)

    @staticmethod
    def detect_cursor() -> Tuple[bool, List[str], Optional[str]]:
        reasons = []
        launch_target = "Cursor"
        app_paths = [
            "/Applications/Cursor.app",
            os.path.expanduser("~/Applications/Cursor.app"),
        ]
        for p in app_paths:
            if os.path.exists(p):
                reasons.append(f"Desktop app installed: {p}")
                launch_target = p
                break

        data_paths = [
            os.path.expanduser("~/Library/Application Support/Cursor/User/globalStorage/state.vscdb"),
            os.path.expanduser("~/Library/Application Support/Cursor"),
            os.path.expanduser("~/.cursor"),
        ]
        for p in data_paths:
            if os.path.exists(p):
                reasons.append(f"Workspace state: {os.path.basename(p)}")

        cli = shutil.which("cursor")
        if cli:
            reasons.append(f"CLI binary: {cli}")

        return (len(reasons) > 0, reasons, launch_target)

    @staticmethod
    def detect_copilot() -> Tuple[bool, List[str], Optional[str]]:
        reasons = []
        launch_target = "Visual Studio Code"
        gh_cli = shutil.which("gh")
        if gh_cli:
            reasons.append(f"GitHub CLI: {gh_cli}")

        gh_hosts = os.path.expanduser("~/.config/gh/hosts.yml")
        if os.path.exists(gh_hosts):
            reasons.append("GitHub auth session (~/.config/gh/hosts.yml)")

        vscode_copilot = os.path.expanduser(
            "~/Library/Application Support/Code/User/globalStorage/github.copilot"
        )
        if os.path.exists(vscode_copilot):
            reasons.append("VS Code Copilot extension state found")

        vscode_app = "/Applications/Visual Studio Code.app"
        if os.path.exists(vscode_app):
            reasons.append(f"Editor installed: {vscode_app}")

        return (len(reasons) > 0, reasons, launch_target)

    @staticmethod
    def detect_gemini() -> Tuple[bool, List[str], Optional[str]]:
        reasons = []
        launch_target = "https://aistudio.google.com"

        if os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY"):
            reasons.append("Gemini Studio Key configured in environment")

        gcloud_creds = os.path.expanduser("~/.config/gcloud/credentials.db")
        if os.path.exists(gcloud_creds):
            reasons.append("Google Cloud SDK credentials (~/.config/gcloud/)")

        gcloud_cli = shutil.which("gcloud")
        if gcloud_cli:
            reasons.append(f"gcloud CLI binary: {gcloud_cli}")

        gemini_cli = shutil.which("gemini")
        if gemini_cli:
            reasons.append(f"Gemini CLI binary: {gemini_cli}")

        return (len(reasons) > 0, reasons, launch_target)

    @staticmethod
    def detect_codex() -> Tuple[bool, List[str], Optional[str]]:
        reasons = []
        launch_target = "ChatGPT"
        app_paths = [
            "/Applications/ChatGPT.app",
            os.path.expanduser("~/Applications/ChatGPT.app"),
        ]
        for p in app_paths:
            if os.path.exists(p):
                reasons.append(f"ChatGPT desktop app: {p}")
                launch_target = p
                break

        cfg = os.path.expanduser("~/.config/openai")
        if os.path.exists(cfg):
            reasons.append("OpenAI config found (~/.config/openai)")

        if os.getenv("OPENAI_API_KEY"):
            reasons.append("OpenAI API key configured in environment")

        return (len(reasons) > 0, reasons, launch_target)

    @classmethod
    def get_all_detections(cls) -> Dict[ProviderID, Tuple[bool, List[str], Optional[str]]]:
        return {
            ProviderID.CLAUDE: cls.detect_claude(),
            ProviderID.CURSOR: cls.detect_cursor(),
            ProviderID.COPILOT: cls.detect_copilot(),
            ProviderID.GEMINI: cls.detect_gemini(),
            ProviderID.CODEX: cls.detect_codex(),
        }

    @classmethod
    def get_detected_provider_ids(cls) -> List[ProviderID]:
        detections = cls.get_all_detections()
        detected = [pid for pid, (is_detected, _, _) in detections.items() if is_detected]
        # Always return at least 1 provider (default to CLAUDE and CURSOR if system is blank)
        if not detected:
            return [ProviderID.CLAUDE, ProviderID.CURSOR]
        return detected

    @classmethod
    def get_detection_info_list(cls, enabled_ids: List[ProviderID]) -> List[ProviderDetectionInfo]:
        detections = cls.get_all_detections()
        names = {
            ProviderID.CLAUDE: "Anthropic Claude",
            ProviderID.CURSOR: "Cursor AI",
            ProviderID.COPILOT: "GitHub Copilot",
            ProviderID.GEMINI: "Google Gemini",
            ProviderID.CODEX: "OpenAI Codex / ChatGPT",
        }
        res = []
        for pid, (is_detected, reasons, launch_target) in detections.items():
            res.append(
                ProviderDetectionInfo(
                    provider_id=pid,
                    name=names.get(pid, pid.value.capitalize()),
                    is_detected=is_detected,
                    is_enabled=pid in enabled_ids,
                    detection_reasons=reasons,
                    launch_target=launch_target,
                )
            )
        return res
