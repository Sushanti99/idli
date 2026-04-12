import pytest

from brain.app_config import default_app_config
from brain.daily import generate_daily_note, render_daily_note
from brain.env_config import load_env_config
from brain.models import DailyContext, ObsidianNote


def test_render_daily_note_includes_sections():
    note = ObsidianNote(
        path=None,
        relative_path="core/example.md",
        title="Example",
        content="- [ ] task",
        raw_content="- [ ] task",
        frontmatter={},
        tags=[],
        links=[],
        tasks=[{"done": False, "text": "task", "line": 1}],
        folder="core",
    )
    bundle = DailyContext(
        today="2026-04-11",
        vault_notes=[note],
        calendar_events=[{"all_day": False, "start": "09:00", "end": "10:00", "title": "Standup", "location": ""}],
        email_items=[{"subject": "Follow up", "from": "alice@example.com"}],
        notion_tasks=[{"title": "Ship feature", "due": "2026-04-12", "url": "https://example.com"}],
        reading_list=[{"title": "Article", "url": "https://example.com/article", "source": "Test"}],
    )

    content = render_daily_note(bundle)

    obsidian_index = content.index("## Open Obsidian Tasks")
    calendar_index = content.index("## Calendar — Today's Events")
    email_index = content.index("## Email — Action Items")
    notion_index = content.index("## Notion Tasks")
    reading_index = content.index("## Reading — Today's Links")

    assert obsidian_index < calendar_index < email_index < notion_index < reading_index
    assert "sources: [obsidian, calendar, gmail, notion, news]" in content


def test_generate_daily_note_refuses_overwrite_by_default(tmp_path, monkeypatch):
    app_cfg = default_app_config(tmp_path / "vault")
    env_cfg = load_env_config()
    daily_dir = app_cfg.vault.path / app_cfg.vault.daily_folder
    daily_dir.mkdir(parents=True)
    existing = daily_dir / "2026-04-11.md"
    existing.write_text("already here", encoding="utf-8")

    monkeypatch.setattr("brain.daily._today", lambda: "2026-04-11")
    monkeypatch.setattr("brain.daily.build_daily_context", lambda app_cfg, env_cfg: DailyContext(today="2026-04-11"))

    with pytest.raises(FileExistsError):
        generate_daily_note(app_cfg, env_cfg, force=False)
