#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RG_GLOBS=(
  --hidden
  --glob '!.git/**'
  --glob '!.build/**'
  --glob '!dist/**'
  --glob '!release/**'
  --glob '!.swiftpm/**'
  --glob '!script/privacy_audit.sh'
)

failed=0

scan() {
  local label="$1"
  local pattern="$2"
  local matches

  matches="$(rg -n --no-messages --pcre2 "${RG_GLOBS[@]}" -- "$pattern" . || true)"
  if [[ -n "$matches" ]]; then
    echo "privacy audit failed: $label" >&2
    echo "$matches" >&2
    failed=1
  fi
}

scan "absolute macOS home path" '/Users/[^/[:space:]"'\''`]+'
scan "email address" '(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}'
scan "private workspace URL" '(?i)https?://(?:app\.notion\.com/(?:p/)?[0-9a-f]{20,}|[a-z0-9-]+\.chatgpt\.site)'
scan "credential-like token" '(?:github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16})'
scan "PEM private key" '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'

if (( failed != 0 )); then
  exit 1
fi

echo "privacy audit passed"
