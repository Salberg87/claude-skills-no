---
name: folio
description: Query the Folio business-banking/accounting API (folio.no) — accounts, transactions, balances, bookkeeping events, receipts/attachments and statement PDFs. Use when the user mentions Folio, their Folio/bedriftskonto, or asks to pull transactions, check a balance, categorize/bokføre an event, upload a kvittering/receipt, or download a kontoutskrift/statement. Read + bookkeeping only — does NOT move money.
---

# Folio API

Norwegian business banking + bookkeeping. Base `https://api.folio.no/v2`, bearer auth via `$FOLIO_API_KEY`. All helper commands go through `scripts/folio.sh`.

**Setup (one-time):** export your API key, or put it in a file and point `FOLIO_ENV` at it. See the repo README for full instructions.

```bash
export FOLIO_API_KEY=...               # create at https://app.folio.no/til/api-tilgang
# or: export FOLIO_ENV=~/.config/folio/.env   (a file defining FOLIO_API_KEY)
```

**Scope:** read + bookkeeping only. There are deliberately **no payment commands** — a read/bookkeeping API key has no payment scope, and money movement is done manually in Folio.

## Quick start

```bash
F=~/.claude/skills/folio/scripts/folio.sh

bash "$F" accounts                            # list accounts
bash "$F" transactions 2026-01-01 2026-06-09  # transactions in range
bash "$F" help                                # all commands
```

Dates are `YYYY-MM-DD`. Output is JSON (piped through `jq` if available); statements/attachments download as files.

## Common workflows

**Pull transactions / reconcile**

```bash
bash "$F" transactions 2026-05-01 2026-05-31 --merchants
bash "$F" transactions 2026-05-01 2026-05-31 --account <accountNumber>   # one account
bash "$F" balance <accountNumber> 2026-05-31
```

**Bookkeeping an event** (events = bank events needing categorization/receipts)

1. List uncompleted events: `bash "$F" events 2026-05-01 2026-05-31`
2. Check what the target category requires (purpose? participants? attachment?):
   `bash "$F" category <ledgerCategoryId>`
3. Set fields: `bash "$F" patch-event <eventId> --purpose "Kundemøte" --participants "Navn" --category <ledgerCategoryId>`
4. Attach receipt: `bash "$F" attach <eventId> ~/Downloads/kvittering.pdf`
5. Mark done: `bash "$F" complete <eventId>` (undo: `uncomplete`)

> A `LedgerCategory` flags `requiresPurpose`, `requiresParticipants`, `requiresAttachment`, `requiresReview` and the VAT code/rate. Check these (step 2) before `complete`, or completion may be rejected.

**Statement PDF** (e.g. for regnskap)

```bash
bash "$F" statement 2026 05 -o ~/Downloads/folio-2026-05.pdf
bash "$F" statement --range 2026-01-01 2026-03-31 -o ~/Downloads/folio-q1.pdf
```

**Export to CSV** — pull JSON, shape with `jq`:

```bash
bash "$F" transactions 2026-01-01 2026-06-09 \
  | jq -r '.transactions.booked[] | [.bookingDate, .description, .transactionAmount.amount, .transactionAmount.currency] | @csv'
```

## Full reference

Endpoint list, query params, schemas and gotchas: see [REFERENCE.md](REFERENCE.md).
For anything not wrapped by the helper, use the escape hatch: `bash "$F" raw GET /some/path`.

---

Part of **claude-skills-no** by Fredrik Salberg ([Pifre AS](https://pifre.no)). Not affiliated with Folio.
