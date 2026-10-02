# Deployment guide

## 1. Local (Docker Compose)

```bash
./scripts/setup.sh                      # creates .env with random passwords
./scripts/deploy.sh compose             # build + start + health check
open http://localhost:8080
./scripts/backup.sh                     # DB dump (verified, 7-day retention)
```

Optional observability on the same host:

```bash
docker compose -f monitoring/docker-compose.monitoring.yml --env-file .env up -d   # Prometheus :9090, Grafana :3001
sudo sysctl -w vm.max_map_count=262144
docker compose -f logging/elk/docker-compose.elk.yml up -d                          # Kibana :5601
```

Create the Kibana data view `ecommerce-logs-*` and search e.g. `log_level : "error"`.

## 2. Cloud (Terraform -> Ansible -> Kubernetes)

```bash
# Infrastructure
cd terraform
cp terraform.tfvars.example terraform.tfvars        # set admin_cidrs to YOUR ip/32
terraform init && terraform plan  -var-file=environments/dev/dev.tfvars
terraform apply -var-file=environments/dev/dev.tfvars
# writes ../ansible/inventory/dev.ini automatically

# Server configuration
cd ../ansible
ansible-playbook playbook.yml                       # hardening, Docker, k3s, Helm, ingress-nginx, cron jobs

# Fetch kubeconfig (replace IP)
ssh -i ../terraform/ecommerce-dev.pem ubuntu@<IP> sudo cat /etc/rancher/k3s/k3s.yaml \
  | sed 's/127.0.0.1/<IP>/' > ~/.kube/ecommerce-dev.yaml
```

## 3. Application on Kubernetes (Helm)

```bash
export KUBECONFIG=~/.kube/ecommerce-dev.yaml
helm lint helm/ecommerce -f helm/ecommerce/values-dev.yaml
helm template ecommerce helm/ecommerce -f helm/ecommerce/values-dev.yaml | kubectl apply --dry-run=server -f -
REGISTRY=<account>.dkr.ecr.<region>.amazonaws.com ./scripts/deploy.sh k8s --env dev --tag <tag>
```

Monitoring and logging on the cluster:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
kubectl create ns monitoring
kubectl -n monitoring create secret generic grafana-admin --from-literal=admin-user=admin --from-literal=admin-password="$(openssl rand -base64 18)"
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring -f monitoring/prometheus/values-kube-prometheus-stack.yaml
kubectl apply -f monitoring/prometheus/ecommerce-rules.yaml -f monitoring/grafana/dashboard-configmap.yaml
kubectl apply -f logging/elk/k8s/logging.yaml
```

## 4. Jenkins

1. Install plugins: Pipeline, Git, GitHub, Credentials Binding. Agent needs `node 22`, `docker`, `trivy`, `gitleaks`, `helm`, `kubectl`.
2. Add credentials `registry-creds` (username/password) and `kubeconfig` (secret file).
3. Edit `REGISTRY` in `jenkins/Jenkinsfile`; create a Multibranch Pipeline pointing at the GitHub repo (script path `jenkins/Jenkinsfile`); add the GitHub webhook `https://<jenkins>/github-webhook/`.
4. Push to `develop` -> deploys to dev. Merge to `main` -> waits for approval -> deploys to prod.

### Registry choice
`REGISTRY` in the Jenkinsfile defaults to GHCR. For the ECR repositories Terraform creates, set `REGISTRY=<account>.dkr.ecr.<region>.amazonaws.com`, store `AWS` / the output of `aws ecr get-login-password` as `registry-creds` (tokens last 12 h - automate refresh in Jenkins), and create a pull secret for the cluster:

```bash
kubectl -n ecommerce create secret docker-registry regcred --docker-server=<registry> --docker-username=<user> --docker-password=<token>
helm upgrade ... --set image.pullSecret=regcred
```

## 5. Release strategies (s.20)

### Rolling (implemented)
`maxSurge: 1, maxUnavailable: 0` + readiness probes: new pods must become Ready before old ones are removed. `helm --atomic` rolls back automatically if the rollout fails.

Demo:
```bash
./scripts/deploy.sh k8s --env dev --tag 1.0.1
kubectl -n ecommerce rollout status deploy/backend
helm history ecommerce -n ecommerce
./scripts/deploy.sh rollback                    # back to previous revision
```

### Blue-Green (documented procedure)
Deploy a second release (`helm install ecommerce-green ... --set image.tag=2.0.0`), run `scripts/health-check.sh` against it, then point the Ingress at the green Service and keep blue for instant rollback. Not automated in the pipeline.

### Canary (documented procedure)
Run a second Deployment with the same `app: backend` label and 1 replica next to 9 stable replicas (~10% traffic), watch the Grafana error-rate and latency panels, then scale up or delete it. Not automated in the pipeline.
