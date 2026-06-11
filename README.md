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



<table>
<tr>
<td width="50%">
<img src="https://github.com/user-attachments/assets/08f341cd-6a4d-49e5-b256-cdd2b2d06d12" width="100%">
</td>
<td width="50%">
<img src="https://github.com/user-attachments/assets/dcb10de0-e4e9-4acc-857a-1f8ad7e83fcf" width="100%">
</td>
</tr>

<tr>
<td width="50%">
<img src="https://github.com/user-attachments/assets/7df05a8c-b80f-428c-9877-a36a40b70626" width="100%">
</td>
<td width="50%">
<img src="https://github.com/user-attachments/assets/7122f3b0-6b26-452a-ade3-46c2c5763b07" width="100%">
</td>
</tr>

<tr>
<td width="50%">
<img src="https://github.com/user-attachments/assets/02316a08-ba01-4ba1-9397-ebf8eff77496" width="100%">
</td>
<td width="50%">
<img src="https://github.com/user-attachments/assets/fad27dad-26be-4fbf-a997-b78342e623c5" width="100%">
</td>
</tr>

<tr>
<td width="50%">
<img src="https://github.com/user-attachments/assets/605abdc5-c5ca-49a7-8635-e064f67c4587" width="100%">
</td>
<td width="50%">
<img src="https://github.com/user-attachments/assets/727b3ff2-340b-4a9c-89fe-73830769222d" width="100%">
</td>
</tr>

<tr>
<td width="50%">
<img src="https://github.com/user-attachments/assets/4fb15228-87b5-496c-a444-623bc7b3f23f" width="100%">
</td>
<td width="50%">
<img src="https://github.com/user-attachments/assets/9960f9b1-3879-4eb6-b459-b60f2da47aa4" width="100%">
</td>
</tr>

<tr>
<td width="50%">
<img src="https://github.com/user-attachments/assets/ffea1aea-79e1-4edf-8221-989a9ca85bcf" width="100%">
</td>
<td width="50%">
<img src="https://github.com/user-attachments/assets/b33575a5-b5e9-4c27-ba46-5f54ff1b53c5" width="100%">
</td>
</tr>

<tr>
<td width="50%">
<img src="https://github.com/user-attachments/assets/bbabd85f-ca84-472e-aa97-211a76dd69c0" width="100%">
</td>
<td width="50%">
<img src="https://github.com/user-attachments/assets/018c74df-8a1b-4a5f-ad14-4589b1e4a4c8" width="100%">
</td>
</tr>

<tr>
<td width="50%">
<img src="https://github.com/user-attachments/assets/56d262fa-26a7-48ac-a14d-4a7acd86cac1" width="100%">
</td>
<td width="50%">
<img src="https://github.com/user-attachments/assets/37418397-60b5-48b7-aaff-656e6a5e23aa" width="100%">
</td>
</tr>

<tr>
<td width="50%">
<img src="https://github.com/user-attachments/assets/8907a37b-1cad-45db-8439-c5516e31c7ab" width="100%">
</td>
<td width="50%">
<img src="https://github.com/user-attachments/assets/6f1f0b5c-8e8b-4eac-8d95-f85d3b84f470" width="100%">
</td>
</tr>

<tr>
<td colspan="2" align="center">
<img src="https://github.com/user-attachments/assets/1eec192f-aa51-4483-9529-480eb08ba842" width="70%">
</td>
</tr>
</table>
![Uploading ec3 i nf.PNG…]()


---

## ⚡ Deployment & CI/CD

Refer to the complete, step-by-step commands in the **[DEPLOYMENT.md](file:///c:/Users/Devloper/Desktop/DevOps-project/DEPLOYMENT.md)** file to:
1. Provision the ALB and Route 53 alias records using Terraform.
2. Bootstrap the EC2 server with Docker.
3. Configure the GitHub Actions Secrets to trigger automated SSH deployment on push.
