# Troubleshooting

| Symptom | Check | Fix |
|---|---|---|
| `/ready` returns 503 | `kubectl -n ecommerce logs deploy/backend`; look for "database connection timeout" | Verify postgres pod Ready, `ecommerce-secrets`, NetworkPolicy `allow-postgres` |
| Pods `ImagePullBackOff` | `kubectl describe pod`; does the tag exist in the registry? | Re-run pipeline (Push stage); recreate pull secret |
| Pods `CrashLoopBackOff` | `kubectl logs --previous <pod>` | `./scripts/deploy.sh rollback`, fix startup error |
| `OOMKilled` | `kubectl describe pod`, Grafana memory panel | Raise memory limit, find the leak |
| Jenkins "trivy is not installed" | Agent tooling | Install trivy on the agent. The gate intentionally fails closed |
| Jenkins secret-scan stage fails | Output lists file:line (values redacted) | Remove and **rotate** the secret; never allowlist a real one |
| Elasticsearch won't start | `vm.max_map_count` | `sudo sysctl -w vm.max_map_count=262144` |
| No metrics in Grafana | Prometheus -> Status -> Targets | Compose: backend must be on `ecommerce_backend_net`. K8s: pod needs `prometheus.io/scrape` annotation |
| `terraform apply` rejected | `admin_cidrs` | Must not contain `0.0.0.0/0` (validation rule) |
| Ansible SSH timeout | Security group / your IP changed | Update `admin_cidrs`, `terraform apply` |

## AI-assisted triage

```bash
kubectl -n ecommerce logs deploy/backend --tail=500 | python3 ai/incident-analysis/analyze.py --offline
export ANTHROPIC_API_KEY=...        # optional: use Claude instead of the rule set
python3 ai/incident-analysis/analyze.py --es-url http://localhost:9200 --minutes 30
```
Output is advisory. Logs are redacted (secrets, emails, IPs, DB URLs) before being sent anywhere.
