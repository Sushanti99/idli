"""Daily-note integration context collection."""

from __future__ import annotations

import importlib
import importlib.util
import os
import sys
from datetime import date
from pathlib import Path

from brain.models import AppConfig, DailyContext, EnvConfig
from brain.vault import read_vault


def build_daily_context(app_cfg: AppConfig, env_cfg: EnvConfig) -> DailyContext:
    legacy_config = _load_legacy_module("config")
    _configure_legacy_modules(legacy_config, app_cfg, env_cfg)
    bundle = DailyContext(today=date.today().isoformat())

    try:
        all_notes = read_vault(app_cfg.vault.path)
        bundle.vault_notes = [note for note in all_notes if not note.frontmatter.get("generated")]
    except Exception:
        bundle.vault_notes = []

    try:
        calendar_client = _load_legacy_module("calendar_client")
        bundle.calendar_events = calendar_client.get_todays_events()
    except Exception:
        bundle.calendar_events = []

    try:
        gmail_client = _load_legacy_module("gmail_client")
        bundle.email_items = gmail_client.get_action_items()
    except Exception:
        bundle.email_items = []

    try:
        notion_client = _load_legacy_module("notion_client")
        bundle.notion_tasks = notion_client.get_open_tasks()
    except Exception:
        bundle.notion_tasks = []

    if token := os.getenv("GITHUB_TOKEN"):
        bundle.github_items = _fetch_github_items(token)

    if token := os.getenv("SLACK_BOT_TOKEN"):
        bundle.slack_items = _fetch_slack_items(token)

    try:
        news_client = _load_legacy_module("news_client")
        bundle.reading_list = news_client.get_reading_list(bundle.vault_notes)
    except Exception:
        bundle.reading_list = []

    return bundle


def _fetch_github_items(token: str) -> list[dict]:
    try:
        import httpx
        headers = {"Authorization": f"token {token}", "Accept": "application/vnd.github+json"}
        items = []
        prs = httpx.get("https://api.github.com/search/issues?q=is:pr+is:open+author:@me&per_page=10", headers=headers, timeout=10).json()
        for i in (prs.get("items") or []):
            items.append({"type": "pr", "title": i["title"], "url": i["html_url"], "repo": i["repository_url"].split("/")[-1]})
        issues = httpx.get("https://api.github.com/search/issues?q=is:issue+is:open+assignee:@me&per_page=10", headers=headers, timeout=10).json()
        for i in (issues.get("items") or []):
            items.append({"type": "issue", "title": i["title"], "url": i["html_url"], "repo": i["repository_url"].split("/")[-1]})
        return items
    except Exception:
        return []


def _fetch_slack_items(token: str) -> list[dict]:
    try:
        import httpx
        headers = {"Authorization": f"Bearer {token}"}
        channels = httpx.get("https://slack.com/api/conversations.list?limit=10&exclude_archived=true", headers=headers, timeout=10).json()
        items = []
        for ch in (channels.get("channels") or [])[:5]:
            hist = httpx.get(f"https://slack.com/api/conversations.history?channel={ch['id']}&limit=3", headers=headers, timeout=10).json()
            for msg in (hist.get("messages") or []):
                text = msg.get("text", "").strip()
                if text:
                    items.append({"channel": ch["name"], "text": text[:140]})
        return items
    except Exception:
        return []


def _configure_legacy_modules(legacy_config, app_cfg: AppConfig, env_cfg: EnvConfig) -> None:
    legacy_config.VAULT_PATH = app_cfg.vault.path
    legacy_config.DAILY_FOLDER = app_cfg.vault.daily_folder
    legacy_config.GOOGLE_CREDENTIALS_FILE = env_cfg.google_credentials_file
    legacy_config.GOOGLE_TOKEN_FILE = env_cfg.google_token_file
    legacy_config.NOTION_API_KEY = env_cfg.notion_api_key
    legacy_config.NEWS_FEEDS = ",".join(env_cfg.news_feeds)


def _load_legacy_module(module_name: str):
    if module_name in sys.modules:
        return sys.modules[module_name]

    try:
        return importlib.import_module(module_name)
    except ModuleNotFoundError:
        module_path = _legacy_module_path(module_name)
        spec = importlib.util.spec_from_file_location(module_name, module_path)
        if spec is None or spec.loader is None:
            raise
        module = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = module
        spec.loader.exec_module(module)
        return module


def _legacy_module_path(module_name: str) -> Path:
    project_root = Path(__file__).resolve().parent.parent
    return project_root / f"{module_name}.py"
