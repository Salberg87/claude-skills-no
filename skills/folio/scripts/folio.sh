#!/usr/bin/env bash
# folio.sh — thin curl wrapper for the Folio API (https://api.folio.no/v2)
# Read + bookkeeping only. No payment commands by design (and a read/bookkeeping
# API key has no payment scope anyway).
#
# Auth: export FOLIO_API_KEY=... in your environment. Optionally point
# FOLIO_ENV at a file that defines it (export FOLIO_ENV=~/.config/folio/.env).
set -euo pipefail

BASE="https://api.folio.no/v2"
if [ -z "${FOLIO_API_KEY:-}" ] && [ -n "${FOLIO_ENV:-}" ] && [ -f "$FOLIO_ENV" ]; then
  set -a; . "$FOLIO_ENV"; set +a
fi
case "${1:-}" in ""|-h|--help|help) ;; *)  # help works without credentials
  : "${FOLIO_API_KEY:?FOLIO_API_KEY not set — export it, or set FOLIO_ENV to a file that defines it}" ;;
esac

# Pretty-print JSON if jq is present, else passthrough.
_fmt() { if command -v jq >/dev/null 2>&1; then jq .; else cat; fi; }

_get() { # _get <path...>  -> JSON to stdout
  curl -fsS -H "Authorization: Bearer $FOLIO_API_KEY" -H "Accept: application/json" "$BASE$1"
}

_die() { echo "error: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
folio — Folio API helper (read + bookkeeping)

  accounts                                 List accounts (number, name, type, balance)
  balance <accountNumber> <YYYY-MM-DD>     Incoming/outgoing balance on a date
  transactions <start> [end] [opts]        Transactions in date range (YYYY-MM-DD)
        --account <n>                        ...for one account only
        --merchants                          include merchant info
  tx <id>                                  Single transaction by id
  events <start> [end] [opts]              Events (bookkeeping items) in date range
        --merchants --agents --cards         include extra info
  category <ledgerCategoryId>              Inspect a ledger category (vat, requirements)
  patch-event <eventId> [opts]            Update an event (bookkeeping fields)
        --purpose <t> --note <t> --participants <t> --category <ledgerCategoryId>
  complete <eventId>                       Mark event complete (bookført)
  uncomplete <eventId>                     Undo complete
  attach <eventId> <file.pdf|jpg|png>     Upload a receipt/attachment to an event
  download <attachmentId> <type> -o <f>   Download attachment
        type: original|cropped|128x128|256x256|512x512
  statement [YYYY MM | --range s e] -o f  Download account statement PDF
  raw <METHOD> <path> [jsonBody]          Escape hatch (e.g. raw GET /accounts)

Dates are YYYY-MM-DD. All output is JSON unless a PDF/file is downloaded.
EOF
}

cmd="${1:-}"; shift || true
case "$cmd" in
  accounts) _get "/accounts" | _fmt ;;

  balance)
    [ $# -ge 2 ] || _die "usage: balance <accountNumber> <YYYY-MM-DD>"
    _get "/accounts/$1/balance/$2" | _fmt ;;

  transactions)
    [ $# -ge 1 ] || _die "usage: transactions <start> [end] [--account n] [--merchants]"
    start="$1"; shift; end=""; acct=""; q=""
    while [ $# -gt 0 ]; do case "$1" in
      --account) acct="$2"; shift 2;;
      --merchants) q="${q}&includeMerchants=true"; shift;;
      *) end="$1"; shift;;
    esac; done
    qs="startDate=$start"; [ -n "$end" ] && qs="$qs&endDate=$end"; qs="$qs$q"
    if [ -n "$acct" ]; then _get "/accounts/$acct/transactions?$qs" | _fmt
    else _get "/transactions?$qs" | _fmt; fi ;;

  tx) [ $# -ge 1 ] || _die "usage: tx <id>"; _get "/transactions/$1" | _fmt ;;

  events)
    [ $# -ge 1 ] || _die "usage: events <start> [end] [--merchants --agents --cards]"
    start="$1"; shift; end=""; q=""
    while [ $# -gt 0 ]; do case "$1" in
      --merchants) q="${q}&includeMerchants=true"; shift;;
      --agents) q="${q}&includeAgents=true"; shift;;
      --cards) q="${q}&includeCards=true"; shift;;
      *) end="$1"; shift;;
    esac; done
    qs="startDate=$start"; [ -n "$end" ] && qs="$qs&endDate=$end"; qs="$qs$q"
    _get "/events?$qs" | _fmt ;;

  category) [ $# -ge 1 ] || _die "usage: category <id>"; _get "/categories/$1" | _fmt ;;

  patch-event)
    [ $# -ge 1 ] || _die "usage: patch-event <eventId> [--purpose t --note t --participants t --category id]"
    id="$1"; shift; body="{}"
    while [ $# -gt 0 ]; do case "$1" in
      --purpose) body=$(echo "$body" | jq --arg v "$2" '.purpose=$v'); shift 2;;
      --note) body=$(echo "$body" | jq --arg v "$2" '.note=$v'); shift 2;;
      --participants) body=$(echo "$body" | jq --arg v "$2" '.participants=$v'); shift 2;;
      --category) body=$(echo "$body" | jq --arg v "$2" '.ledgerCategoryId=$v'); shift 2;;
      *) _die "unknown arg: $1";;
    esac; done
    curl -fsS -X PATCH -H "Authorization: Bearer $FOLIO_API_KEY" \
      -H "Content-Type: application/json" -d "$body" "$BASE/events/$id" -w "\nHTTP %{http_code}\n" ;;

  complete) [ $# -ge 1 ] || _die "usage: complete <eventId>"
    curl -fsS -X POST -H "Authorization: Bearer $FOLIO_API_KEY" "$BASE/events/$1/complete" -w "HTTP %{http_code}\n" ;;
  uncomplete) [ $# -ge 1 ] || _die "usage: uncomplete <eventId>"
    curl -fsS -X DELETE -H "Authorization: Bearer $FOLIO_API_KEY" "$BASE/events/$1/complete" -w "HTTP %{http_code}\n" ;;

  attach)
    [ $# -ge 2 ] || _die "usage: attach <eventId> <file.pdf|jpg|png>"
    id="$1"; file="$2"; [ -f "$file" ] || _die "no such file: $file"
    case "$file" in
      *.pdf) ct="application/pdf";; *.jpg|*.jpeg) ct="image/jpeg";; *.png) ct="image/png";;
      *) _die "unsupported type (pdf/jpg/png only): $file";;
    esac
    fn=$(basename "$file")
    curl -fsS -X POST -H "Authorization: Bearer $FOLIO_API_KEY" \
      -H "Content-Type: $ct" -H "Content-Disposition: attachment; filename=\"$fn\"" \
      --data-binary @"$file" "$BASE/events/$id/attachments" -w "\nHTTP %{http_code}\n" | _fmt ;;

  download)
    [ $# -ge 4 ] || _die "usage: download <attachmentId> <type> -o <file>  (type: original|cropped|128x128|256x256|512x512)"
    aid="$1"; type="$2"; shift 2; out=""
    while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2;; *) shift;; esac; done
    [ -n "$out" ] || _die "missing -o <file>"
    curl -fsS -H "Authorization: Bearer $FOLIO_API_KEY" "$BASE/attachments/$aid/$type" -o "$out"
    echo "saved $out" ;;

  statement)
    out=""; year=""; month=""; rstart=""; rend=""
    while [ $# -gt 0 ]; do case "$1" in
      -o) out="$2"; shift 2;;
      --range) rstart="$2"; rend="$3"; shift 3;;
      *) if [ -z "$year" ]; then year="$1"; else month="$1"; fi; shift;;
    esac; done
    [ -n "$out" ] || _die "missing -o <file.pdf>"
    if [ -n "$rstart" ]; then
      curl -fsS -H "Authorization: Bearer $FOLIO_API_KEY" "$BASE/statement?startDate=$rstart&endDate=$rend" -o "$out"
    else
      [ -n "$year" ] && [ -n "$month" ] || _die "usage: statement <YYYY> <MM> -o f  |  statement --range s e -o f"
      curl -fsS -H "Authorization: Bearer $FOLIO_API_KEY" "$BASE/statement/$year/$month" -o "$out"
    fi
    echo "saved $out" ;;

  raw)
    [ $# -ge 2 ] || _die "usage: raw <METHOD> <path> [jsonBody]"
    m="$1"; path="$2"; data="${3:-}"
    if [ -n "$data" ]; then
      curl -fsS -X "$m" -H "Authorization: Bearer $FOLIO_API_KEY" -H "Content-Type: application/json" -d "$data" "$BASE$path" | _fmt
    else
      curl -fsS -X "$m" -H "Authorization: Bearer $FOLIO_API_KEY" -H "Accept: application/json" "$BASE$path" | _fmt
    fi ;;

  ""|-h|--help|help) usage ;;
  *) _die "unknown command: $cmd (try: folio help)" ;;
esac
