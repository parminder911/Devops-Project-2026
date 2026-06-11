# 🚀 Hudocafe — Production-Grade DevOps Application

A modern, production-ready DevOps implementation deploying a FastAPI service with PostgreSQL caching/storage, Redis, and Nginx on a single EC2 instance, with SSL termination handled by an AWS Application Load Balancer (ALB) and DNS managed by Route 53.

---

## 🏗️ Architecture

```
                                  [ Public Internet ]
                                           │
                                  HTTPS    │ (Port 443)
                                           ▼
                            [ AWS Route 53 DNS Resolution ]
                             hudocafe.com  -->  ALB Alias
                                           │
                                           ▼
                      [ AWS Application Load Balancer (ALB) ]
                            SSL/TLS Termination (ACM Cert)
                                           │
                                  HTTP     │ (Port 80)
                                           ▼
                          [ Manually Launched EC2 Instance ]
                         Protected by Security Groups & UFW
                                           │
                                           ▼
                         ┌───────────────────────────────────┐
                         │          Docker Compose           │
                         │                                   │
                         │   ┌───────────────────────────┐   │
                         │   │   NGINX Reverse Proxy     │   │
                         │   │        (Port 80)          │   │
                         │   └─────────────┬─────────────┘   │
                         │                 │                 │
                         │   ┌─────────────▼─────────────┐   │
                         │   │      FastAPI Backend      │   │
                         │   │        (Port 8000)        │   │
                         │   └──────┬─────────────┬──────┘   │
                         │          │             │          │
                         │   ┌──────▼─────┐ ┌─────▼──────┐   │
                         │   │  Redis 7   │ │ Postgres 15│   │
                         │   │  (Caching) │ │ (Persistent│   │
                         │   │ (Internal) │ │  Storage)  │   │
                         │   └────────────┘ └────────────┘   │
                         └───────────────────────────────────┘
```

### 🔒 Security Design
1. **Network Isolation**: PostgreSQL and Redis are hosted on an internal, isolated Docker network (`backend_network`) and are never exposed to the host machine or public internet.
2. **Access Control**: The EC2 instance security group allows incoming HTTP traffic on port 80 **only** from the ALB security group, and SSH (port 22) only for authorized deployment.
3. **Nginx Hardening**: Nginx handles rate limiting (30 requests/minute), gzip compression, HTTP to HTTPS redirection, and strips/injects standard security headers (`X-Frame-Options`, `X-Content-Type-Options`, `Content-Security-Policy`).
4. **Client IP Integrity**: Nginx uses the `real_ip` module to parse the client's original IP from the ALB `X-Forwarded-For` header. This prevents the load balancer IP from being rate-limited.

---

## 📂 Directory Structure

```
DevOps-project/
├── .github/workflows/
│   └── deploy.yml          # GitHub Actions CI/CD (Build → ECR → SSH Deploy)
├── app/
│   ├── main.py             # FastAPI App (Health, Caching, DB, AI Simulation)
│   ├── requirements.txt
│   └── Dockerfile          # Multi-stage production build (Non-root user)
├── nginx/
│   └── default.conf        # Nginx reverse proxy configuration
├── terraform/
│   ├── main.tf             # ALB, Target Group, Route 53 setup
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── docker-compose.yml      # Multi-container local/production services
├── DEPLOYMENT.md           # Step-by-step commands from scratch
├── .env.example
└── README.md
```

---

## 🛠️ Features & Implementation Details

* **Docker Multi-Stage Build**: The backend `Dockerfile` uses a two-stage build to compile packages in a build container, copying only the final dependencies to the slim production runtime. The app runs under a non-privileged user (`appuser`) for security hardening.
* **Auto-Recovery**: Containers are configured with `restart: unless-stopped` so that the Docker daemon automatically brings up any service that crashes.
* **Structured Logging**: The FastAPI backend implements a custom JSON formatter to produce structured logs, making it ready for integration with cloud watch, Loki, or ELK.
* **Database Backup Strategy**: Daily backups of the PostgreSQL database are scheduled on a cron job, performing non-blocking database dumps.

---

## 🐳 Local Development

1. **Clone the repository**:
   ```bash
   git clone https://github.com/parminder911/Devops-Project-2026.git
   cd Devops-Project-2026
   ```

2. **Setup environment variables**:
   ```bash
   cp .env.example .env
   # Customize passwords or database names in .env
   ```

3. **Start local services**:
   ```bash
   docker compose up -d --build
   ```

4. **Verify operations**:
   - Backend API Docs: `http://localhost/docs`
   - Health check: `curl http://localhost/health`
     ```json
     {"status":"healthy","checks":{"redis":"UP","postgres":"UP"}}
     ```

5. **Stop local services**:
   ```bash
   docker compose down -v
   ```

---

## 🌐 API Endpoints

| Method | Endpoint | Description |
|:---|:---|:---|
| `GET` | `/` | API version information |
| `GET` | `/health` | Health Check (verifies Postgres & Redis) |
| `POST` | `/v1/predict` | Mock AI inference endpoint with Redis caching |
| `GET` | `/v1/predictions` | Retrieves recent prediction records from PostgreSQL |

---

## ⚡ Deployment & CI/CD

Refer to the complete, step-by-step commands in the **[DEPLOYMENT.md](file:///c:/Users/Devloper/Desktop/DevOps-project/DEPLOYMENT.md)** file to:
1. Provision the ALB and Route 53 alias records using Terraform.
2. Bootstrap the EC2 server with Docker.
3. Configure the GitHub Actions Secrets to trigger automated SSH deployment on push.
