#!/usr/bin/env bash
# Secret detection. Uses gitleaks when installed; otherwise falls back to a built-in pattern scan
# so the gate still works on a bare machine. Exit 1 on any finding.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if command -v gitleaks >/dev/null 2>&1; then
  echo "[secrets] running gitleaks"
  gitleaks detect --source . --config security/.gitleaks.toml --no-banner --redact --exit-code 1
  echo "[secrets] gitleaks: no leaks found"
  exit 0
fi

echo "[secrets] gitleaks not installed - using built-in pattern scan (install gitleaks for full coverage)"
PATTERNS='AKIA[0-9A-Z]{16}|-----BEGIN ((RSA|EC|OPENSSH|DSA|PGP) )?PRIVATE KEY-----|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|(password|passwd|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'$ {}]{8,}["'"'"']'

hits=$(grep -rEIn --exclude-dir={.git,node_modules,docs,.terraform} \
        --exclude={.env.example,secret.yaml,package-lock.json,scan-secrets.sh,.gitleaks.toml,*.tfvars.example} \
        -e "$PATTERNS" . 2>/dev/null || true)

# Real .env / key files must never be present in the tree being built
files=$(find . \( -path ./node_modules -o -path ./.git -o -path '*/node_modules' \) -prune -o \
        \( -name '.env' -o -name '*.pem' -o -name 'id_rsa' -o -name '*.tfstate' \) -type f -print)

if [[ -n "$hits$files" ]]; then
  echo "[secrets] POTENTIAL SECRETS FOUND:" >&2
  [[ -n "$hits" ]] && echo "$hits" | sed -E 's/(:[0-9]+:).*/\1 <line redacted>/' >&2
  if [[ -n "$files" ]]; then while IFS= read -r f; do echo " sensitive file: $f" >&2; done <<< "$files"; fi
  exit 1
fi
echo "[secrets] no secrets found"
