#!/usr/bin/env bash
set -uo pipefail
fail=0
step() { echo ">> $1"; shift; "$@" || { echo "!! FAILED: $*"; fail=1; }; }

step "apt: shellcheck" bash -c 'sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck'
step "pip: ansible-core, yamllint" pip install --quiet ansible-core yamllint
step "npm: backend dependencies" bash -c 'cd application/backend && npm ci --no-audit --no-fund'
step "trivy" bash -c 'curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin'
step "gitleaks" bash -c 'v=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep -oP "\"tag_name\": \"v\K[^\"]+") && curl -sL "https://github.com/gitleaks/gitleaks/releases/download/v${v}/gitleaks_${v}_linux_x64.tar.gz" | sudo tar -xz -C /usr/local/bin gitleaks'

chmod +x scripts/*.sh security/*.sh
echo; [[ $fail -eq 0 ]] && echo "Dev environment ready." || echo "Finished with some failed steps (see !! lines above)."
