#!/usr/bin/env bash
# Dependency vulnerability scan (npm audit, production dependencies only).
# AUDIT_LEVEL: low|moderate|high|critical  (default: high)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/application/backend"
LEVEL="${AUDIT_LEVEL:-high}"
echo "[deps] npm audit --omit=dev --audit-level=$LEVEL"
npm audit --omit=dev --audit-level="$LEVEL"
echo "[deps] no vulnerabilities at or above '$LEVEL'"
