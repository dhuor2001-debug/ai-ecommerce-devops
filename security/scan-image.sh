#!/usr/bin/env bash
# Container image scan with Trivy.
# Usage: scan-image.sh IMAGE[:TAG]      FAIL_ON_VULNS=true|false (default true)
# A missing scanner FAILS the gate: a skipped security check must never look like a pass.
set -euo pipefail
IMAGE="${1:?usage: scan-image.sh IMAGE[:TAG]}"
FAIL="${FAIL_ON_VULNS:-true}"

command -v trivy >/dev/null 2>&1 || { echo "[image] trivy is not installed - cannot scan $IMAGE" >&2; exit 2; }

EXIT=0; [[ "$FAIL" == "true" ]] && EXIT=1
echo "[image] scanning $IMAGE (fail on HIGH/CRITICAL: $FAIL)"
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code "$EXIT" --no-progress "$IMAGE"
echo "[image] $IMAGE passed"
