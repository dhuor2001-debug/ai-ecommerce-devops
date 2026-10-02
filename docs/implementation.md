# Implementation guide - report section to code

| Report section | Where | Notes |
|---|---|---|
| s.7 Linux environment | `scripts/setup.sh`, `ansible/roles/common`, `security/audit-host.sh` | Host checks, users, SSH/sysctl/UFW hardening, audit script |
| s.8 Git & GitHub | `.gitignore`, `.github/`, branch model below | `main` <- `develop` <- `feature/*` |
| s.9 Bash automation | `scripts/{setup,deploy,health-check,backup,cleanup}.sh` | `lib.sh` holds shared helpers; all pass `shellcheck` |
| s.10 Reverse proxy | `docker/nginx/default.conf`, `helm/.../ingress.yaml` | Security headers, access/error logs to stdout |
| s.11 Containerization | `docker/Dockerfile`, `docker/docker-compose.yml`, `.dockerignore` | Multi-stage, non-root, healthchecks, read-only FS, dropped capabilities |
| s.12 CI/CD | `jenkins/Jenkinsfile`, `.github/workflows/ci.yml` | Every box of the report's pipeline diagram: trigger = `githubPush()`, 10 stages, success = `post { success }` |
| s.13 Terraform | `terraform/` | VPC, SG, EC2, ECR; modules `network`, `compute`, `registry`; per-env tfvars |
| s.14 Ansible | `ansible/` | Roles `common`, `docker`, `k3s`, `app_dirs`; only `ansible.builtin` modules |
| s.15 Kubernetes | `kubernetes/` | Namespace, Deployments, Services, ConfigMap, Secret template, Ingress, HPA, NetworkPolicies |
| s.16 Helm | `helm/ecommerce/` | Chart.yaml, values (+dev/prod), templates for each resource |
| s.17-18 Monitoring | `monitoring/` | Prometheus, alert rules, Grafana dashboard (availability, CPU, memory, pods, nodes, resources) |
| s.19 Logging | `logging/elk/` | Filebeat -> Logstash -> Elasticsearch -> Kibana (Compose) and Filebeat -> ES -> Kibana (K8s) |
| s.20 Deployment strategy | Rolling in Deployment/Helm; Blue-Green/Canary in `docs/deployment.md` | Rolling is automated; the other two are documented procedures |
| s.21 DevSecOps | `security/` | Secret scan, dependency scan, image scan, host audit, K8s Secrets, NetworkPolicy, non-root pods |
| s.22 AI analysis | `ai/incident-analysis/` | Rule-based offline mode + Claude mode, redaction, schema validation |
| s.23 Cloud | `terraform/` + `ansible/` + Jenkins deploy | Same pipeline targets the cloud cluster via kubeconfig |

## Git branching model (s.8)

```
main      production-ready; Jenkins deploys here (with manual approval)
develop   integration branch; Jenkins deploys to dev
feature/* short-lived branches, PR into develop, reviewed before merge
```

Workflow: `git switch -c feature/my-change develop` -> commit -> push -> open PR to `develop` (template in `.github/`) -> review + CI -> merge -> later PR `develop` -> `main`.

## Application contract (s.4)

| Item | Value |
|---|---|
| Backend port | 3000 (`PORT`) |
| Frontend port | 8080 (Nginx, unprivileged) |
| Database | PostgreSQL 16, `DATABASE_URL`; falls back to in-memory if unset |
| Env vars | `PORT`, `LOG_LEVEL`, `APP_VERSION`, `DATABASE_URL`, `POSTGRES_*` |
| Health | `/health`, `/ready` (checks DB) |
| Metrics | `/metrics` (Prometheus) |
| API | `GET /api/products`, `GET /api/products/:id`, `POST /api/orders`, `GET /api/orders` |
| Logs | JSON lines on stdout |
