# todos-with-obsidian

Connects your **Gmail, Google Calendar, and Notion** to your **Obsidian vault** — generating a personalised daily note every morning with everything you need: today's events, unread emails, open tasks, and a reading list curated to your interests.

No AI API key needed. No database IDs to copy. One command to set up.

---

## What you get each morning

```markdown
# Daily Note — Tuesday, April 7 2026

## Calendar — Today's Events
- 10:30–11:15 :: NLP HW5, submit
- 19:00–20:00 :: Call with Arya

## Email — Action Items
- [ ] Re: Q2 proposal *(from: alice@company.com)*

## Notion Tasks
- [ ] Write architecture doc · Due: Apr 10 · [Open](https://notion.so/...)

## Open Obsidian Tasks
- [ ] Publish Substack piece *(from: [[writing for the sake of writing]])*

## Reading — Today's Links
- [Rashomon Memory: Argumentation-Driven Retrieval for Agent Memory](https://arxiv.org/...) *(arXiv AI)*
- [Chrome finally adds a better way to deal with too many tabs](https://techcrunch.com/...) *(TechCrunch)*
```

The reading list is personalised — it reads your vault tags, note titles, and folder names to figure out what you care about, then ranks today's articles from Hacker News, arXiv, TechCrunch, and others accordingly. No configuration needed.

---

## Setup — one command

```bash
git clone https://github.com/Sushanti99/todos-with-obsidian.git
cd todos-with-obsidian
pip install -r requirements.txt
python setup.py
```

`setup.py` opens a browser for each service and saves your credentials to `.env`. It handles:
- **Google** — opens Cloud Console, watches for `credentials.json`, then runs the OAuth browser flow automatically
- **Notion** — opens the integrations page, you paste one key, done

Each integration is optional. If you skip one, that section just says *"not connected"* in your daily note.

---

## Run it

```bash
python main.py daily
```

That's it. Open Obsidian and your note is there.

**To run it every morning automatically**, add a cron job:

```bash
# open crontab
crontab -e

# add this line — runs at 8am daily
0 8 * * * cd /path/to/todos-with-obsidian && python main.py daily
```

**To use a different vault:**

```bash
python main.py daily --vault /path/to/your/vault
```

---

## Personalising your reading list

The reading list works out of the box with no config — it learns your interests from your vault.

To add custom RSS feeds, add this to your `.env`:

```env
NEWS_FEEDS=https://yourblog.com/rss,https://somepodcast.com/feed
```

Default sources: Hacker News · TechCrunch · The Verge · arXiv AI · VentureBeat · MIT Technology Review

---

## Google setup (if you get stuck)

After running `setup.py`, if you see a 403 error about APIs not enabled:

1. [Enable Gmail API](https://console.cloud.google.com/apis/library/gmail.googleapis.com)
2. [Enable Google Calendar API](https://console.cloud.google.com/apis/library/calendar-json.googleapis.com)
3. Wait 60 seconds, run `python main.py daily` again

---

## Project structure

```
setup.py             One-command setup (opens browser for each integration)
main.py              Entry point — run `python main.py daily`
obsidian_reader.py   Reads and parses the Obsidian vault
gmail_client.py      Gmail OAuth2 integration
calendar_client.py   Google Calendar integration
notion_client.py     Notion API — reads all pages and databases shared with integration
news_client.py       Fetches and ranks articles from RSS/HN by vault interests
context_builder.py   Aggregates all sources into one bundle
daily_note.py        Renders and writes the daily markdown note
config.py            Central config, reads from .env
```

---

## Contributing

PRs welcome. The codebase is intentionally flat and simple — no frameworks, no async, no vector DBs. Each integration is a single file that fails independently, so adding new sources (Linear, GitHub Issues, Spotify, etc.) is straightforward.

---

## License

MIT
