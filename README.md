# 🚀 Hudocafe — Production DevOps Project

**FastAPI + PostgreSQL + Redis + NGINX | Terraform + K8s + ArgoCD + GitHub Actions**

> **Domain**: hudocafe.com | **Region**: AWS Mumbai (ap-south-1)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Public Internet                       │
└──────────────────────┬──────────────────────────────────┘
                       │ HTTPS
              ┌────────▼────────┐
              │   Route 53      │ hudocafe.com A → EC2 EIP
              │   (DNS)         │ api.hudocafe.com
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │   ACM Cert      │ *.hudocafe.com (SSL)
              └────────┬────────┘
                       │
     ┌─────────────────▼──────────────────────┐
     │       EC2 t3.medium (Mumbai)            │
     │       Ubuntu 22.04 + k3s               │
     │                                         │
     │  ┌─────────────────────────────────┐   │
     │  │  NGINX Ingress (port 80/443)    │   │
     │  └──────────────┬──────────────────┘   │
     │                 │                       │
     │  ┌──────────────▼──────────────────┐   │
     │  │  FastAPI (2 pods, HPA 2-5)      │   │
     │  │  /health /ready /v1/predict     │   │
     │  └────────┬─────────────┬──────────┘   │
     │           │             │               │
     │  ┌────────▼──┐  ┌───────▼──────────┐  │
     │  │  Redis 7  │  │  PostgreSQL 15   │  │
     │  │  (cache)  │  │  (StatefulSet)   │  │
     │  └───────────┘  └──────────────────┘  │
     │                                         │
     │  ┌─────────────────────────────────┐   │
     │  │  ArgoCD (GitOps Controller)     │   │
     │  │  Watches: k8s/ → auto-deploys   │   │
     │  └─────────────────────────────────┘   │
     └─────────────────────────────────────────┘

GitHub Actions CI ──► ECR (Docker Image) ──► Update k8s/app/deployment.yaml
                                                         │
                                              ArgoCD detects Git change
                                                         │
                                              Zero-downtime Rolling Deploy
```

---

## 📂 Directory Structure

```
DevOps-project/
├── .github/workflows/
│   ├── ci.yml              # Build & push Docker image to ECR
│   └── cd.yml              # ArgoCD sync after CI
├── app/
│   ├── main.py             # FastAPI app
│   ├── requirements.txt
│   └── Dockerfile          # Multi-stage production build
├── nginx/
│   └── default.conf        # NGINX reverse proxy config
├── terraform/
│   ├── main.tf             # EC2 + provider
│   ├── vpc.tf              # VPC + SG
│   ├── acm.tf              # ACM certificate
│   ├── route53.tf          # DNS records
│   ├── iam.tf              # IAM roles + ECR + S3
│   ├── variables.tf
│   ├── outputs.tf
│   └── user_data.sh        # EC2 bootstrap (auto-installs everything)
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── postgres/           # StatefulSet + PVC + Service
│   ├── redis/              # Deployment + Service
│   ├── app/                # Deployment + Service + HPA
│   └── ingress/            # NGINX Ingress
├── argocd/
│   ├── application.yaml    # ArgoCD app definition
│   └── project.yaml        # ArgoCD project
├── scripts/
│   ├── backup.sh           # PostgreSQL → S3 backup
│   ├── bootstrap-k3s.sh    # k3s + ArgoCD install
│   └── setup-server.sh     # UFW + fail2ban hardening
├── docker-compose.yml      # Local development
├── .env.example
├── Makefile
└── README.md
```

---

## ⚡ Deployment Roadmap (Step-by-Step)

### Prerequisites (WSL / Linux)
```bash
# Install tools in WSL
sudo apt-get update

# Terraform
wget https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip
unzip terraform_1.8.5_linux_amd64.zip && sudo mv terraform /usr/local/bin/

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Configure AWS credentials
aws configure
# AWS Access Key ID: <from IAM>
# AWS Secret Access Key: <from IAM>
# Default region: ap-south-1
# Default output: json

# Generate SSH key (if not exists)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

---

### Phase 1 — Terraform (Provision AWS Infrastructure)

```bash
# 1. Enter terraform directory
cd terraform/

# 2. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit: set allowed_ssh_cidr to YOUR_IP/32

# 3. Initialize Terraform
terraform init

# 4. Preview what will be created
terraform plan -var-file=terraform.tfvars

# 5. APPLY — creates EC2, VPC, SG, ACM cert, Route53, ECR, S3, IAM
terraform apply -var-file=terraform.tfvars
# Type: yes
```

**After apply — Terraform outputs:**
```
ec2_public_ip    = "13.235.x.x"
ssh_command      = "ssh -i ~/.ssh/id_rsa ubuntu@13.235.x.x"
app_url          = "https://api.hudocafe.com"
argocd_url       = "https://argocd.hudocafe.com"
route53_nameservers = ["ns-xxx.awsdns-xx.com", ...]
acm_certificate_arn = "arn:aws:acm:..."
```

> ⚠️ **Important**: Copy the `route53_nameservers` values and update them at your domain registrar (where you bought hudocafe.com). DNS propagation takes 5-30 minutes.

---

### Phase 2 — Verify EC2 is Ready

```bash
# SSH into EC2
ssh -i ~/.ssh/id_rsa ubuntu@<EC2_IP>

# Check bootstrap logs (user_data.sh runs automatically)
sudo tail -f /var/log/user-data.log

# Verify k3s is running
kubectl get nodes
# Expected: hudocafe-node-1   Ready    ...

# Verify ArgoCD pods
kubectl get pods -n argocd
# All pods should be Running

# Get ArgoCD initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

> Bootstrap takes ~5 minutes. Access ArgoCD UI: `http://<EC2_IP>:30080`

---

### Phase 3 — ECR Repository Setup

```bash
# On your local WSL

# Get ECR login (run on EC2 for k8s to pull images)
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS \
  --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com

# Create ECR pull secret in K8s (run on EC2)
kubectl create secret docker-registry ecr-secret \
  --docker-server=<ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region ap-south-1) \
  --namespace=production
```

---

### Phase 4 — Configure GitHub Secrets

In your GitHub repo → **Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `EC2_HOST` | Elastic IP from terraform output |
| `ARGOCD_SERVER` | `<EC2_IP>:30080` |
| `ARGOCD_PASSWORD` | From Phase 2 above |

---

### Phase 5 — Register Your Repo in ArgoCD (on EC2)

```bash
# SSH into EC2
ssh -i ~/.ssh/id_rsa ubuntu@<EC2_IP>

# Clone your repo
git clone https://github.com/YOUR_USERNAME/DevOps-project ~/app
cd ~/app

# Update argocd/application.yaml with your repo URL
nano argocd/application.yaml
# Change: repoURL: https://github.com/YOUR_USERNAME/DevOps-project

# Login to ArgoCD
argocd login localhost:30080 \
  --username admin \
  --password <ARGOCD_PASSWORD> \
  --insecure

# Add GitHub repo
argocd repo add https://github.com/YOUR_USERNAME/DevOps-project \
  --username YOUR_GITHUB_USERNAME \
  --password YOUR_GITHUB_PAT   # Create at: github.com → Settings → Developer Settings → PAT

# Apply secrets (update DB_PASSWORD first!)
nano k8s/secrets.yaml
kubectl apply -f k8s/secrets.yaml

# Apply ArgoCD application
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/application.yaml
```

---

### Phase 6 — Verify GitOps is Working

```bash
# Watch ArgoCD sync
argocd app get hudocafe-app

# Check all pods
kubectl get pods -n production
# NAME                     READY   STATUS    RESTARTS
# postgres-0               1/1     Running   0
# redis-xxx                1/1     Running   0
# api-xxx                  1/1     Running   0
# api-yyy                  1/1     Running   0

# Test health endpoint
curl http://<EC2_IP>/health
# {"status":"healthy","checks":{"redis":"UP","postgres":"UP"}}

# After DNS propagates (~30 min after nameserver update):
curl https://api.hudocafe.com/health
```

---

### Phase 7 — Enable CI/CD Pipeline

```bash
# Make a code change and push to main
git add . && git commit -m "feat: initial deploy" && git push origin main

# Watch GitHub Actions:
# 1. CI: builds Docker image → pushes to ECR → updates k8s/app/deployment.yaml
# 2. CD: ArgoCD CLI syncs → rolling zero-downtime update
# 3. Both show green ✅
```

---

## 🔄 GitOps Flow

```
You push code to main branch
         │
         ▼
GitHub Actions CI triggers
  ├── Build Docker image (multi-stage)
  ├── Push to ECR (hudocafe/api:sha)
  ├── Update k8s/app/deployment.yaml image tag
  └── Commit & push manifest back to Git
         │
         ▼
ArgoCD detects change in k8s/app/deployment.yaml
         │
         ▼
GitHub Actions CD triggers ArgoCD sync
  └── kubectl rolling update (zero-downtime)
         │
         ▼
New pods start → readiness probe passes → old pods terminate
```

---

## 🐳 Local Development

```bash
# Copy env template
cp .env.example .env
# Edit .env with your values

# Start all services
docker compose up -d --build

# Check services
docker compose ps

# Test locally
curl http://localhost/health
curl -X POST http://localhost/v1/predict -H "Content-Type: application/json" \
     -d '{"text": "test AI prompt"}'

# View logs
docker compose logs -f web

# Stop
docker compose down
```

---

## 📊 Monitoring Setup (Future — Bonus)

```bash
# Install Prometheus + Grafana via Helm (on EC2)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=YourPassword \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Access Grafana (NodePort)
kubectl patch svc monitoring-grafana -n monitoring \
  -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":31000}]}}'
# URL: http://<EC2_IP>:31000 | admin / YourPassword
```

---

## 💾 Backup Strategy

```bash
# Manual backup
bash scripts/backup.sh

# Add to crontab (on EC2) for daily midnight backups
crontab -e
# Add: 0 0 * * * /bin/bash /home/ubuntu/app/scripts/backup.sh >> /var/log/backup.log 2>&1

# Backups stored:
# - Local: /opt/backups/postgres/ (7-day retention)
# - S3: s3://hudocafe-backups/postgres/ (30-day retention via lifecycle policy)
```

---

## 🔐 Security Measures

| Layer | Measure |
|-------|---------|
| Network | VPC + Security Group (ports 22, 80, 443, 30080 only) |
| SSH | Key-only auth, root login disabled |
| SSH | fail2ban (3 attempts → 24h ban) |
| Firewall | UFW (deny all incoming by default) |
| K8s Secrets | Base64 encoded, never in plain env vars |
| Containers | Non-root user (`uid=1001`) |
| NGINX | Security headers, rate limiting |
| Network | Backend network isolated (`internal: true`) |
| IAM | Least-privilege EC2 role (ECR pull, S3 backup only) |
| Images | ECR vulnerability scanning on push |
| Backups | AES256-encrypted S3 storage |

---

## 🌐 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Service info |
| GET | `/health` | Health check (Redis + PostgreSQL) |
| GET | `/ready` | Kubernetes readiness probe |
| GET | `/docs` | Swagger UI |
| POST | `/v1/predict` | AI mock inference with Redis caching |
| GET | `/v1/predictions` | List recent predictions from PostgreSQL |

### Example
```bash
# AI Predict
curl -X POST https://api.hudocafe.com/v1/predict \
  -H "Content-Type: application/json" \
  -d '{"text": "What is DevOps?"}'

# Response
{
  "response": "[AI Response] Analyzed: 'What is DevOps?' — confidence: 0.97",
  "source": "llm_model",
  "cached": false
}
```

---

## 🧑‍💻 GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `EC2_HOST` | EC2 Elastic IP |
| `ARGOCD_SERVER` | `<IP>:30080` |
| `ARGOCD_PASSWORD` | ArgoCD admin password |

---

## 📋 Assignment Checklist

- [x] ✅ Dockerized FastAPI application
- [x] ✅ Docker Compose (PostgreSQL + Redis + NGINX + FastAPI)
- [x] ✅ Environment variables (`.env.example`)
- [x] ✅ SSL setup (ACM + Route 53 for hudocafe.com)
- [x] ✅ Basic server security (UFW + fail2ban + SSH hardening)
- [x] ✅ CI/CD pipeline (GitHub Actions: build → ECR → ArgoCD deploy)
- [x] ✅ Health check endpoint (`/health`)
- [x] ✅ Logging strategy (structured JSON logs)
- [x] ✅ Backup/restart strategy (daily cron → S3)
- [x] ✅ **BONUS**: Monitoring setup (Grafana + Prometheus instructions)
- [x] ✅ **BONUS**: fail2ban firewall
- [x] ✅ **BONUS**: Zero-downtime deployments (K8s rolling update)
- [x] ✅ **BONUS**: AI/LLM endpoint (`/v1/predict`)
- [x] ✅ **BONUS**: Automated S3 backups
- [x] ✅ **BONUS**: ArgoCD GitOps

---

*Built with Terraform + k3s + ArgoCD + GitHub Actions | Domain: hudocafe.com | AWS Mumbai*
