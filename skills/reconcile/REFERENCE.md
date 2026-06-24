# Reconcile — Reference

`scripts/reconcile.py` is a pure, offline planner: two JSON inputs in, a plan out. No network, no writes. All state changes happen later through the `fiken` / `folio` skills.

## Inputs

| Flag                    | Required | Meaning                                                                                                                            |
| ----------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `--events <file>`       | yes      | Folio events JSON — output of `folio events <start> <end>`. Accepts `{"events":[...]}` or a bare array.                            |
| `--purchases <file>`    | yes      | Fiken purchases JSON — output of `fiken purchases <start> <end>`.                                                                  |
| `--rules <file>`        | no       | Vendor classification rules (see below). Without it, everything with a non-zero amount and no match becomes `needs_review`.        |
| `--card-account <code>` | no       | Fiken account the card is paid from (e.g. `1949`). Scopes dedup to payments on that account and adds a payment line to each draft. |
| `--json`                | no       | Emit the full plan as JSON (for scripting draft creation) instead of the human table.                                              |

## Rules file

```json
{
  "vendors": [
    { "keyword": "ANTHROPIC", "account": "6553", "name": "Anthropic" }
  ],
  "goods_accounts": ["1200", "6800"]
}
```

- **vendors** — first rule whose `keyword` is a case-insensitive substring of the Folio charge description wins. `account` is the Fiken cost account; `name` becomes the draft line text.
- **goods_accounts** — accounts that represent physical goods. A foreign charge booked to one of these gets `vatType NONE` (import VAT handled at customs) instead of the reverse-charge service type.

Keep a real `rules.json` outside the repo (e.g. `~/.config/reconcile/rules.json`); only `rules.example.json` is committed.

## Plan entry schema (`--json`)

```jsonc
{
  "eventId": "…",            // Folio event id
  "date": "2026-05-03",      // event date (time[:10])
  "amount_ore": 25000,        // absolute amount in øre
  "amount_nok": 250.00,
  "currency": "NOK",
  "description": "*1234 03.05 NOK ANTHROPIC",
  "status": "already_booked | proposed | needs_review",
  "reason": "…",             // for already_booked / needs_review
  "vendor": "Anthropic",     // proposed only
  "account": "6553",         // proposed only
  "vatType": "HIGH",         // proposed only
  "draft": { … }              // proposed only — a ready fiken draft-purchase body
}
```

The `draft` object is exactly the body `fiken draft-purchase` expects: `{cash, paid, currency, invoiceIssueDate, lines:[{text, vatType, incomeAccount, net, gross}], payments?}`.

## Matching & dedup

- An event is **already_booked** if some Fiken purchase has the same `(date, amount_øre)`. Matching is **count-based**: two identical charges on the same day need two matching purchases to both be skipped (a `set` would wrongly skip the second).
- A purchase contributes its `payments[].amount` keys (optionally filtered by `--card-account`); if it has no payment rows, the sum of its line `gross` values is used instead.
- Completed Folio events (`complete: true`) are ignored entirely.

## Edge cases

- **Zero / unparseable amount** → `needs_review`.
- **No vendor rule** → `needs_review` (never guesses an account).
- **Currency** is read from `cardAuthorization.currency`, else a 3-letter code in the transaction description, else the event amount's currency, else `NOK`.
- **Amounts** — Folio sends strings in NOK (`"-438.00"`); the planner takes the absolute value in øre. Fiken purchase amounts are already øre.
- The planner does **not** know the FX rate for foreign charges — `gross` is the NOK amount Folio actually charged, which is what you book.

## What this script deliberately does NOT do

- No API calls, no auth, no writes.
- No posting drafts to the ledger.
- No completing Folio events.
- No payments.

Those are all manual/gated steps via the `fiken` and `folio` skills, by design.
