"""Daily note generation."""

from __future__ import annotations

from datetime import datetime
from pathlib import Path

from brain.models import AppConfig, DailyContext, EnvConfig
from brain.vault import resolve_vault_paths, write_text_file


def daily_note_exists_for_today(app_cfg: AppConfig) -> bool:
    vault_paths = resolve_vault_paths(app_cfg)
    return (vault_paths.daily / f"{_today()}.md").exists()


def generate_daily_note(app_cfg: AppConfig, env_cfg: EnvConfig, *, force: bool = False) -> Path:
    context = build_daily_context(app_cfg, env_cfg)
    content = render_daily_note(context)
    return write_daily_note(app_cfg, content, force=force)


def render_daily_note(bundle: DailyContext) -> str:
    sources = (
        (["obsidian"] if bundle.vault_notes else [])
        + (["calendar"] if bundle.calendar_events else [])
        + (["gmail"] if bundle.email_items else [])
        + (["notion"] if bundle.notion_tasks else [])
        + (["news"] if bundle.reading_list else [])
    )

    day_label = datetime.now().strftime("%A, %B %d %Y")
    generated_at = datetime.now().strftime("%H:%M")

    lines = [
        "---",
        f"date: {bundle.today}",
        "type: daily",
        "generated: true",
        f"sources: [{', '.join(sources)}]",
        "---",
        "",
        f"# Daily Note — {day_label}",
        "",
        "## Open Obsidian Tasks",
        "",
    ]

    open_vault_tasks = [
        (note.relative_path, task["text"])
        for note in bundle.vault_notes
        for task in note.tasks
        if not task["done"]
    ]
    if open_vault_tasks:
        for relative_path, text in open_vault_tasks:
            lines.append(f"- [ ] {text} *(from: [[{Path(relative_path).stem}]])*")
    else:
        lines.append("*No open tasks in vault.*")

    lines += ["", "## Calendar — Today's Events", ""]
    if bundle.calendar_events:
        for event in bundle.calendar_events:
            if event["all_day"]:
                lines.append(f"- All-day :: {event['title']}")
            else:
                line = f"- {event['start']}–{event['end']} :: {event['title']}"
                if event.get("location"):
                    line += f" @ {event['location']}"
                lines.append(line)
    else:
        lines.append("*No events today.*")

    lines += ["", "## Email — Action Items", ""]
    if bundle.email_items:
        for email in bundle.email_items:
            lines.append(f"- [ ] {email['subject']} *(from: {email['from']})*")
    else:
        lines.append("*No unread emails in the last 24 hours.*")

    lines += ["", "## Notion Tasks", ""]
    if bundle.notion_tasks:
        for task in bundle.notion_tasks:
            line = f"- [ ] {task['title']}"
            if task.get("due"):
                line += f" · Due: {task['due']}"
            if task.get("url"):
                line += f" · [Open]({task['url']})"
            lines.append(line)
    else:
        lines.append("*No open Notion tasks.*")

    lines += ["", "## Reading — Today's Links", ""]
    if bundle.reading_list:
        for article in bundle.reading_list:
            source = f" *({article['source']})*" if article.get("source") else ""
            lines.append(f"- [{article['title']}]({article['url']}){source}")
    else:
        lines.append("*No articles fetched.*")

    lines += ["", "---", f"*Generated at {generated_at} by brain*"]
    return "\n".join(lines)


def write_daily_note(app_cfg: AppConfig, content: str, *, force: bool = False) -> Path:
    vault_paths = resolve_vault_paths(app_cfg)
    daily_path = vault_paths.daily / f"{_today()}.md"
    if daily_path.exists() and not force:
        raise FileExistsError(f"Refusing to overwrite existing daily note: {daily_path}")
    return write_text_file(daily_path, content, overwrite=True)


def _today() -> str:
    return datetime.now().date().isoformat()


def build_daily_context(app_cfg: AppConfig, env_cfg: EnvConfig) -> DailyContext:
    from brain.integration_context import build_daily_context as _build_daily_context

    return _build_daily_context(app_cfg, env_cfg)
