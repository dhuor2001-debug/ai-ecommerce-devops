#!/usr/bin/env bash
# Deploy the application.
# Usage:
#   deploy.sh compose [--tag TAG]                  local/VM deployment with Docker Compose
#   deploy.sh k8s [--tag TAG] [--env dev|prod]     Kubernetes deployment via Helm (rolling update)
#   deploy.sh rollback                             roll back the Helm release to the previous revision
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MODE="${1:-}"; shift || true
TAG="${IMAGE_TAG:-latest}"
ENVIRONMENT="dev"
NAMESPACE="${NAMESPACE:-ecommerce}"
RELEASE="${RELEASE:-ecommerce}"
REGISTRY="${REGISTRY:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="$2"; shift 2 ;;
    --env) ENVIRONMENT="$2"; shift 2 ;;
    *) die "Unknown option: $1" ;;
  esac
done

case "$MODE" in
  compose)
    require_cmd docker
    load_env
    export IMAGE_TAG="$TAG"
    log "Deploying with Docker Compose (tag: $TAG)"
    compose up -d --build --remove-orphans
    "$(dirname "${BASH_SOURCE[0]}")/health-check.sh" -u "http://localhost:${WEB_PORT:-8080}"
    log "Compose deployment succeeded"
    ;;
  k8s)
    require_cmd helm; require_cmd kubectl
    VALUES_FILE="$REPO_ROOT/helm/ecommerce/values-${ENVIRONMENT}.yaml"
    [[ -f "$VALUES_FILE" ]] || die "No values file for env '$ENVIRONMENT': $VALUES_FILE"
    log "Deploying release '$RELEASE' to namespace '$NAMESPACE' (tag: $TAG, env: $ENVIRONMENT)"
    # --atomic: wait for readiness and automatically roll back if the rollout fails.
    helm upgrade --install "$RELEASE" "$REPO_ROOT/helm/ecommerce" \
      --namespace "$NAMESPACE" --create-namespace \
      -f "$VALUES_FILE" \
      ${REGISTRY:+--set image.registry="$REGISTRY"} \
      --set image.tag="$TAG" \
      --atomic --wait --timeout 5m
    kubectl -n "$NAMESPACE" rollout status deployment/backend --timeout=120s
    kubectl -n "$NAMESPACE" rollout status deployment/frontend --timeout=120s
    log "Kubernetes deployment succeeded"
    ;;
  rollback)
    require_cmd helm
    log "Rolling back release '$RELEASE' in namespace '$NAMESPACE'"
    helm rollback "$RELEASE" --namespace "$NAMESPACE" --wait --timeout 5m
    ;;
  *)
    sed -n '2,7p' "$0"; exit 2 ;;
esac
