# claude-skills-no

**Let your AI agent read your Norwegian accounting and bank — without ever being able to touch the money.**

Plug-and-play **Agent Skills** for [Claude Code](https://claude.com/claude-code) and compatible agents. A growing collection wrapping the tools Norwegian small businesses actually run on:

| Skill                     | What it does                                                                                                                                | Scope                                                                     |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| [**folio**](skills/folio) | The [Folio](https://folio.no) business-banking API — accounts, transactions, balances, bookkeeping events, receipts, statement PDFs         | Read + bookkeeping only · **money movement is impossible**                |
| [**fiken**](skills/fiken) | The [Fiken](https://fiken.no) accounting API — costs/result reports, balances, transactions, purchases, sales, invoices, contacts, receipts | Read freely · writes are **drafts only** · posting to the ledger is gated |

Thin, auditable `curl` wrappers (bash + a little stdlib Python). No SDK, no daemon, no telemetry — you can read every line in a minute. The agent reads `SKILL.md`, runs one script, gets clean JSON or a formatted report.

## Why this exists

- **Covers Folio, not just Fiken.** If you bank with Folio and want an AI agent to see your transactions and help with bookkeeping, the `folio` skill does exactly that — accounts, transactions, events, receipts, statements.
- **Safety is enforced in code, not asked for in a prompt.** Most AI-accounting tools wave a "⚠️ please confirm" comment at the model and hope. Here the guardrails are in the scripts: a payment is not a command that exists, and posting to the ledger physically refuses to run without an explicit flag. An agent that goes rogue still cannot move your money or silently book an entry.
- **Built for the regnskap reality, not just the API.** `costs` and `result` are computed from general-ledger movement (the authoritative figure), pagination is automatic, amounts are converted from øre — the things you'd otherwise get wrong.

## Safety model

These skills touch live accounting and banking data, so the guardrails are baked into the scripts, not just the prompts:

- **Reads are free.** Anything that only fetches data runs without confirmation.
- **Folio cannot move money — at all.** There is deliberately no payment command in the wrapper, and the API key it uses has no payment scope. Even a compromised or confused agent has no path to a transfer.
- **Fiken writes create drafts (kladd) only.** Posting a draft to the ledger (`bokføring`) is irreversible — it's gated behind an explicit `--confirm` flag enforced in the script _and_ the skill instructs the agent to get your OK first. No flag, no booking.

## Install

Each skill is a self-contained folder under `skills/`. Drop the ones you want into your agent's skills directory.

**Claude Code (per-user):**

```bash
git clone https://github.com/Salberg87/claude-skills-no.git
cp -r claude-skills-no/skills/fiken ~/.claude/skills/fiken
cp -r claude-skills-no/skills/folio ~/.claude/skills/folio
```

(For a single project instead, copy into `.claude/skills/` inside the project.)

## Setup

Each skill needs credentials in the environment. Export them in your shell, or keep them in a file and point an env var at it (the scripts auto-load it).

**Fiken** — personal API token from _Fiken → Innstillinger → API_:

```bash
export FIKEN_API_TOKEN=...
export FIKEN_COMPANY_SLUG=your-company-as
# or: cp skills/fiken/env.example ~/.config/fiken/.env && export FIKEN_ENV=~/.config/fiken/.env
```

**Folio** — API key from <https://app.folio.no/til/api-tilgang>:

```bash
export FOLIO_API_KEY=...
# or: cp skills/folio/env.example ~/.config/folio/.env && export FOLIO_ENV=~/.config/folio/.env
```

Requires `curl`, `python3`, and (optional, for pretty output) `jq`.

## Quick check

```bash
FIKEN_API_TOKEN=... FIKEN_COMPANY_SLUG=your-company-as \
  bash skills/fiken/scripts/fiken.sh whoami

FOLIO_API_KEY=... bash skills/folio/scripts/folio.sh accounts
```

Each script also has built-in help: `bash skills/fiken/scripts/fiken.sh help`.

## Author

Built by **Fredrik Salberg** — [Pifre AS](https://pifre.no), Oslo. Made because running a Norwegian AS shouldn't mean clicking through three dashboards to answer "what did I spend last month."

Not affiliated with or endorsed by Fiken or Folio. "Fiken" and "Folio" are the trademarks of their respective owners; these skills just call their public APIs.

## Status

Private/early. Use at your own risk on your own accounting data — read the scripts before you run writes. Feedback and ideas for more Norwegian-business skills welcome.

## License

[Apache License 2.0](LICENSE) — © 2026 Fredrik Salberg / Pifre AS. See [NOTICE](NOTICE).
