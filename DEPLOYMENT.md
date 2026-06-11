# Step-by-Step Deployment Guide — Docker Compose Setup

This guide provides the exact commands you need to run to deploy the FastAPI + PostgreSQL + Redis + Nginx stack on your manually created EC2 instance using Route 53 and Application Load Balancer (ALB).

---

## Phase 1: Deploy ALB & Route 53 (via WSL)

Run these commands inside your local WSL terminal under the `terraform/` directory to setup routing and SSL termination:

```bash
# 1. Navigate to the terraform directory
cd ~/b/Devops-Project-2026/terraform

# 2. Copy the example variable file
cp terraform.tfvars.example terraform.tfvars

# 3. Edit terraform.tfvars to insert your manual EC2 instance ID and domain name:
#    domain_name          = "hudocafe.com"
#    existing_instance_id = "i-yourmanualinstanceid"
nano terraform.tfvars

# 4. Initialize Terraform
terraform init

# 5. Review the plan
terraform plan

# 6. Apply configuration (updates Route 53 and provisions ALB)
terraform apply -auto-approve
```

Note the output values:
- `alb_dns_name`: The DNS address of your load balancer.
- `alb_security_group_id`: The security group of your ALB.

---

## Phase 2: Configure your manual EC2 Server

SSH into your manual EC2 server and run these commands to install Docker and prepare the folder structure:

```bash
# 1. SSH into the server
ssh -i ~/.ssh/id_rsa ubuntu@your-ec2-public-ip

# 2. Update package list and install system dependencies
sudo apt-get update
sudo apt-get install -y docker.io awscli

# 3. Enable and start Docker service
sudo systemctl enable --now docker

# 4. Add the ubuntu user to the docker group (so you don't need sudo for docker)
sudo usermod -aG docker ubuntu

# 5. Install Docker Compose (V2)
sudo mkdir -p /usr/local/lib/docker/cli-plugins/
sudo curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# 6. Log out and log back in to apply docker group permissions
exit
ssh -i ~/.ssh/id_rsa ubuntu@your-ec2-public-ip

# 7. Verify installations
docker --version
docker compose version
aws --version

# 8. Create the application directory
mkdir -p ~/app/nginx
```

### 🔒 Security Group configuration (Crucial)
In your AWS EC2 Console, go to your manually created EC2 instance, select its Security Group, and add this Inbound Rule:
- **Type**: HTTP (Port 80)
- **Source**: Custom -> Select the **ALB Security Group** ID (output from Phase 1)
*This guarantees that traffic only enters your EC2 instance through the ALB.*

---

## Phase 3: Setup GitHub Repository Secrets

Add the following Secrets under **Settings > Secrets and variables > Actions** in your GitHub repository:

| Secret Name | Description / Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | Your IAM user secret access key |
| `EC2_HOST` | The **Public IP** of your manual EC2 instance |
| `EC2_SSH_KEY` | The contents of your private SSH key (`~/.ssh/id_rsa`) |
| `AWS_ACCOUNT_ID` | `652942059153` |
| `DB_NAME` | `app_db` (or custom name) |
| `DB_USER` | `app_user` (or custom username) |
| `DB_PASSWORD` | A strong password for your PostgreSQL database |

---

## Phase 4: Deploy (via Git)

Whenever you commit and push to the `main` branch, GitHub Actions will build the container, push it to ECR, copy the configuration files to your EC2 instance, and deploy the stack:

```bash
git add .
git commit -m "deploy: switch to simple docker-compose stack"
git push origin main
```

---

## Phase 5: Troubleshooting, Logs, & Backups

### 1. View Application Logs on the EC2 Server
```bash
# View backend logs (FastAPI)
docker compose -f ~/app/docker-compose.yml logs -f web

# View Nginx access/error logs
docker compose -f ~/app/docker-compose.yml logs -f nginx

# View database logs
docker compose -f ~/app/docker-compose.yml logs -f postgres
```

### 2. Check Service Health
```bash
# Verify containers are running and healthy
docker ps

# Test local endpoint directly on EC2
curl http://localhost/health
```

### 3. Database Backup & Recovery

#### Create a PostgreSQL Backup:
Run this command to dump the database to a `.sql` backup file:
```bash
docker exec -t production_db pg_dump -U app_user -d app_db > ~/app/db_backup_$(date +%Y%m%d_%H%M%S).sql
```

#### Restore the Database:
Run this command to restore a `.sql` backup:
```bash
docker exec -i production_db psql -U app_user -d app_db < ~/app/db_backup_XXXXXXXX.sql
```

#### Automate Backups (Cron Job):
Add a cron job to automatically backup the database every night at 2:00 AM:
```bash
# Run on the EC2 server:
crontab -e

# Paste this line at the bottom:
0 2 * * * docker exec -t production_db pg_dump -U app_user -d app_db > ~/app/db_backup_\$(date +\%Y\%m\%d).sql
```
