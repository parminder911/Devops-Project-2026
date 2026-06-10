# 🚀 DEPLOYMENT.md — Complete Step-by-Step Guide
## Hudocafe DevOps Project | AWS Mumbai (ap-south-1) | CLI Only

> **Your Setup:**
> - AWS Account ID: `652942059153`
> - Domain: `hudocafe.com`
> - ACM Certificate ARN: `arn:aws:acm:ap-south-1:652942059153:certificate/a7ff8bf3-39f9-41fd-99e8-4968443c9c33`
> - ECR Repository: `652942059153.dkr.ecr.ap-south-1.amazonaws.com/hudocafe/api`
> - DB Name: `hudocafedb` | DB User: `hudocafe_user` | DB Password: `HudoCafe@Secure2026!`

**All commands run in WSL as root** (`root@DESKTOP-QG8TGKP`)

---

## ✅ Pre-Check (You Already Have These)

```bash
# Verify terraform
terraform --version
```
**Expected output:**
```
Terraform v1.12.2
on linux_amd64
```

```bash
# Verify AWS CLI
aws --version
```
**Expected output:**
```
aws-cli/2.34.58 Python/3.14.5 Linux/4.4.0-19041-Microsoft exe/x86_64.ubuntu.24
```

```bash
# Verify AWS is configured to correct region
aws configure get region
```
**Expected output:**
```
ap-south-1
```

```bash
# Verify AWS credentials work and show YOUR account
aws sts get-caller-identity
```
**Expected output:**
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "652942059153",
    "Arn": "arn:aws:iam::652942059153:user/your-username"
}
```

```bash
# Verify SSH key exists
ls -la /root/.ssh/id_rsa*
```
**Expected output:**
```
-rw------- 1 root root 3326 Jun 10 2026 /root/.ssh/id_rsa
-rw-r--r-- 1 root root  743 Jun 10 2026 /root/.ssh/id_rsa.pub
```

```bash
# Verify ACM certificate is ISSUED (your existing cert)
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:ap-south-1:652942059153:certificate/a7ff8bf3-39f9-41fd-99e8-4968443c9c33 \
  --region ap-south-1 \
  --query 'Certificate.Status' \
  --output text
```
**Expected output:**
```
ISSUED
```

---

## PHASE 1 — Terraform: Build AWS Infrastructure

### Step 1.1 — Go to terraform directory

```bash
cd /mnt/c/Users/Devloper/Desktop/DevOps-project/terraform
```

### Step 1.2 — Create your tfvars file

```bash
cp terraform.tfvars.example terraform.tfvars
cat terraform.tfvars
```
**Expected output — verify these values:**
```
aws_region         = "ap-south-1"
project_name       = "hudocafe"
environment        = "production"
instance_type      = "t3.medium"
public_key_path    = "/root/.ssh/id_rsa.pub"
domain_name        = "hudocafe.com"
app_subdomain      = "api"
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
allowed_ssh_cidr   = "0.0.0.0/0"
```

### Step 1.3 — Initialize Terraform

```bash
terraform init
```
**Expected output:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...
- Installed hashicorp/aws v5.x.x (signed by HashiCorp)

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure.
```

### Step 1.4 — Preview what Terraform will create

```bash
terraform plan -var-file=terraform.tfvars
```
**Expected output (trimmed):**
```
Plan: 22 to add, 0 to change, 0 to destroy.

Resources to be created:
  + aws_eip.app_eip
  + aws_ecr_lifecycle_policy.app
  + aws_ecr_repository.app             (hudocafe/api)
  + aws_iam_instance_profile.ec2_profile
  + aws_iam_role.ec2_role
  + aws_iam_role_policy.ec2_policy
  + aws_iam_role_policy_attachment.ssm
  + aws_instance.app_server            (t3.medium, Ubuntu 22.04)
  + aws_internet_gateway.igw
  + aws_key_pair.devops                (hudocafe-key)
  + aws_route53_record.app_api
  + aws_route53_record.app_root
  + aws_route53_record.app_www
  + aws_route53_record.argocd
  + aws_route53_zone.primary           (hudocafe.com)
  + aws_s3_bucket.backups              (hudocafe-backups)
  + aws_s3_bucket_lifecycle_configuration.backups
  + aws_s3_bucket_server_side_encryption_configuration.backups
  + aws_s3_bucket_versioning.backups
  + aws_security_group.app_sg
  + aws_subnet.public
  + aws_vpc.main

Data sources to be read:
  ~ data.aws_acm_certificate.app_cert  (reads your existing ISSUED cert)
  ~ data.aws_ami.ubuntu                (latest Ubuntu 22.04)
```

### Step 1.5 — Apply Terraform (takes ~5 minutes)

```bash
terraform apply -var-file=terraform.tfvars
```
Type `yes` when prompted.

**Expected output after completion:**
```
Apply complete! Resources: 22 added, 0 changed, 0 destroyed.

Outputs:

acm_certificate_arn = "arn:aws:acm:ap-south-1:652942059153:certificate/a7ff8bf3-39f9-41fd-99e8-4968443c9c33"

ec2_instance_id = "i-0abcd1234efgh5678"

ec2_public_ip = "13.235.XX.XX"

ecr_repository_uri = "652942059153.dkr.ecr.ap-south-1.amazonaws.com/hudocafe/api"

route53_nameservers = toset([
  "ns-XXX.awsdns-XX.co.uk",
  "ns-XXX.awsdns-XX.com",
  "ns-XXX.awsdns-XX.net",
  "ns-XXX.awsdns-XX.org",
])

s3_backup_bucket = "hudocafe-backups"

setup_instructions = <<EOT
  =============================================
  NEXT STEPS:
  1. SSH: ssh -i /root/.ssh/id_rsa ubuntu@13.235.XX.XX
  2. Wait ~5 min for bootstrap, then: sudo tail -f /var/log/user-data.log
  3. Check k3s: kubectl get nodes
  4. Check ArgoCD: kubectl get pods -n argocd
  5. Update nameservers at your registrar: ns-XXX.awsdns-XX.com, ...
  ECR URI: 652942059153.dkr.ecr.ap-south-1.amazonaws.com/hudocafe/api
  =============================================
EOT

ssh_command = "ssh -i /root/.ssh/id_rsa ubuntu@13.235.XX.XX"
```

> ⚠️ **SAVE the EC2 IP from the output.** You'll use it in all following steps.

### Step 1.6 — Verify EC2 instance is running

```bash
# Replace XX.XX with your actual IP from terraform output
EC2_IP=$(terraform output -raw ec2_public_ip)
echo "Your EC2 IP: $EC2_IP"

# Verify instance is running in AWS
aws ec2 describe-instances \
  --region ap-south-1 \
  --filters "Name=tag:Project,Values=hudocafe" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,InstanceType]' \
  --output table
```
**Expected output:**
```
----------------------------------------------------------
|                    DescribeInstances                   |
+---------------------+----------+---------------+----------+
| i-0abcd1234efgh5678 | running  | 13.235.XX.XX  | t3.medium|
+---------------------+----------+---------------+----------+
```

### Step 1.7 — Verify ECR repository was created

```bash
aws ecr describe-repositories \
  --region ap-south-1 \
  --query 'repositories[*].[repositoryName,repositoryUri]' \
  --output table
```
**Expected output:**
```
----------------------------------------------------------------------------------
|                          DescribeRepositories                                  |
+---------------+----------------------------------------------------------------+
| hudocafe/api  | 652942059153.dkr.ecr.ap-south-1.amazonaws.com/hudocafe/api    |
+---------------+----------------------------------------------------------------+
```

### Step 1.8 — Verify S3 backup bucket

```bash
aws s3 ls | grep hudocafe
```
**Expected output:**
```
2026-06-10 xx:xx:xx hudocafe-backups
```

### Step 1.9 — Verify Route53 zone was created

```bash
aws route53 list-hosted-zones \
  --query 'HostedZones[*].[Name,Id,Config.PrivateZone]' \
  --output table
```
**Expected output:**
```
-----------------------------------------------
|              ListHostedZones                |
+--------------+-------------------+----------+
| hudocafe.com.| /hostedzone/XXXXX | False    |
+--------------+-------------------+----------+
```

```bash
# Get the nameservers you need to set at your domain registrar
terraform output route53_nameservers
```
**Expected output:**
```
toset([
  "ns-1234.awsdns-12.co.uk",
  "ns-567.awsdns-34.com",
  "ns-890.awsdns-56.net",
  "ns-012.awsdns-78.org",
])
```

> 🔴 **ACTION REQUIRED**: Go to your domain registrar (where you bought hudocafe.com) and update the nameservers to these 4 values. This makes hudocafe.com point to AWS Route 53.

---

## PHASE 2 — EC2 Server: Verify Bootstrap

### Step 2.1 — SSH into EC2

```bash
# Get IP from terraform output
EC2_IP=$(cd /mnt/c/Users/Devloper/Desktop/DevOps-project/terraform && terraform output -raw ec2_public_ip)

# SSH (user is always 'ubuntu' for Ubuntu AMI)
ssh -i /root/.ssh/id_rsa ubuntu@$EC2_IP
```
**Expected first-time SSH output:**
```
The authenticity of host '13.235.XX.XX (13.235.XX.XX)' can't be established.
ED25519 key fingerprint is SHA256:XXXXXXXXXXXXXXXXXXXXXXXX.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '13.235.XX.XX' (ED25519) to the list of known hosts.
Welcome to Ubuntu 22.04.x LTS (GNU/Linux 5.15.0-xxxx-aws x86_64)
ubuntu@ip-10-0-1-xxx:~$
```

### Step 2.2 — Watch bootstrap logs (wait for completion)

```bash
# Run this immediately after SSH — bootstrap runs automatically
sudo tail -f /var/log/user-data.log
```
**Expected output (watch until you see this):**
```
=== Bootstrap started at Tue Jun 10 2026 ===
✅ Docker installed
✅ k3s installed
✅ kubectl configured
✅ ArgoCD installed (UI → http://13.235.XX.XX:30080)
✅ Helm installed
✅ Namespace 'production' created
✅ UFW firewall configured
✅ fail2ban configured
=== Bootstrap completed at Tue Jun 10 2026 ===
🚀 Server is ready! Run: ssh ubuntu@13.235.XX.XX
```
Press `Ctrl+C` to stop watching when you see "Bootstrap completed".

### Step 2.3 — Verify k3s Kubernetes is running

```bash
kubectl get nodes
```
**Expected output:**
```
NAME               STATUS   ROLES                  AGE   VERSION
hudocafe-node-1    Ready    control-plane,master   5m    v1.30.x+k3s1
```

### Step 2.4 — Verify all system namespaces

```bash
kubectl get namespaces
```
**Expected output:**
```
NAME              STATUS   AGE
default           Active   5m
kube-system       Active   5m
kube-public       Active   5m
kube-node-lease   Active   5m
argocd            Active   4m
production        Active   4m
```

### Step 2.5 — Verify ArgoCD is running

```bash
kubectl get pods -n argocd
```
**Expected output:**
```
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                    1/1     Running   0          4m
argocd-applicationset-controller-xxxx              1/1     Running   0          4m
argocd-dex-server-xxxx                             1/1     Running   0          4m
argocd-notifications-controller-xxxx               1/1     Running   0          4m
argocd-redis-xxxx                                  1/1     Running   0          4m
argocd-repo-server-xxxx                            1/1     Running   0          4m
argocd-server-xxxx                                 1/1     Running   0          4m
```
> All pods should show `1/1 Running`. If any show `0/1`, wait 2 more minutes and retry.

### Step 2.6 — Get ArgoCD admin password (SAVE THIS!)

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```
**Expected output:**
```
RandomGeneratedP@ssword123
```
> 📌 Copy this password — you'll need it for GitHub Actions secrets and ArgoCD CLI.

### Step 2.7 — Verify Docker is installed

```bash
docker --version
docker ps
```
**Expected output:**
```
Docker version 27.x.x, build xxxxxxx
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

---

## PHASE 3 — ECR: Push Your First Docker Image

**All commands on EC2 (still SSH'd in)**

### Step 3.1 — Login to ECR

```bash
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS \
  --password-stdin 652942059153.dkr.ecr.ap-south-1.amazonaws.com
```
**Expected output:**
```
WARNING! Your password will be stored unencrypted in /home/ubuntu/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```

### Step 3.2 — Clone your GitHub repo

```bash
git clone https://github.com/YOUR_USERNAME/DevOps-project ~/app
cd ~/app
```
> Replace `YOUR_USERNAME` with your GitHub username.

### Step 3.3 — Build and push the Docker image

```bash
cd ~/app

# Build image
docker build -t hudocafe-api:latest ./app/

# Tag for ECR
docker tag hudocafe-api:latest \
  652942059153.dkr.ecr.ap-south-1.amazonaws.com/hudocafe/api:latest

# Push to ECR
docker push 652942059153.dkr.ecr.ap-south-1.amazonaws.com/hudocafe/api:latest
```
**Expected output:**
```
Using default tag: latest
latest: Pushing to 652942059153.dkr.ecr.ap-south-1.amazonaws.com/hudocafe/api
xxxx: Layer already exists
xxxx: Pushed
latest: digest: sha256:xxxxxxxxxxxxxxxxxxxxxxxxxx size: 1234
```

### Step 3.4 — Verify image is in ECR

```bash
aws ecr list-images \
  --repository-name hudocafe/api \
  --region ap-south-1 \
  --output table
```
**Expected output:**
```
----------------------------------------------------------
|                      ListImages                        |
+----------------------+---------+-----------------------+
|       imageDigest    | imageTag|                       |
+----------------------+---------+-----------------------+
| sha256:xxxxxxxxxx    | latest  |                       |
+----------------------+---------+-----------------------+
```

### Step 3.5 — Create ECR pull secret in Kubernetes

```bash
# This lets K8s pull images from your ECR
kubectl create secret docker-registry ecr-secret \
  --docker-server=652942059153.dkr.ecr.ap-south-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region ap-south-1) \
  --namespace=production
```
**Expected output:**
```
secret/ecr-secret created
```

```bash
# Verify the secret was created
kubectl get secret ecr-secret -n production
```
**Expected output:**
```
NAME         TYPE                             DATA   AGE
ecr-secret   kubernetes.io/dockerconfigjson   1      5s
```

---

## PHASE 4 — Kubernetes: Deploy All Services

**All commands on EC2**

### Step 4.1 — Install NGINX Ingress Controller

```bash
# Add ingress-nginx helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress (HostNetwork mode for single-node k3s)
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.hostNetwork=true \
  --set controller.hostPort.enabled=true \
  --set controller.service.type=ClusterIP \
  --wait --timeout=300s
```
**Expected output:**
```
Release "nginx-ingress" does not exist. Installing it now.
NAME: nginx-ingress
LAST DEPLOYED: Tue Jun 10 2026 xx:xx:xx
NAMESPACE: ingress-nginx
STATUS: deployed
REVISION: 1
```

```bash
# Verify ingress controller is running
kubectl get pods -n ingress-nginx
```
**Expected output:**
```
NAME                                            READY   STATUS    RESTARTS   AGE
nginx-ingress-controller-xxxx                  1/1     Running   0          2m
```

### Step 4.2 — Apply all Kubernetes manifests

```bash
cd ~/app

# 1. Namespace (already exists but safe to re-apply)
kubectl apply -f k8s/namespace.yaml
```
**Expected:**
```
namespace/production configured
```

```bash
# 2. ConfigMap (env vars)
kubectl apply -f k8s/configmap.yaml
```
**Expected:**
```
configmap/app-config created
```

```bash
# 3. Secrets (DB credentials)
kubectl apply -f k8s/secrets.yaml
```
**Expected:**
```
secret/app-secrets created
```

```bash
# 4. PostgreSQL (PVC + StatefulSet + Service)
kubectl apply -f k8s/postgres/
```
**Expected:**
```
persistentvolumeclaim/postgres-pvc created
statefulset.apps/postgres created
service/postgres-service created
```

```bash
# 5. Redis (Deployment + Service)
kubectl apply -f k8s/redis/
```
**Expected:**
```
deployment.apps/redis created
service/redis-service created
```

```bash
# 6. FastAPI App (Deployment + Service + HPA)
kubectl apply -f k8s/app/
```
**Expected:**
```
deployment.apps/api created
service/api-service created
horizontalpodautoscaler.autoscaling/api-hpa created
```

```bash
# 7. Ingress (NGINX routing)
kubectl apply -f k8s/ingress/
```
**Expected:**
```
ingress.networking.k8s.io/app-ingress created
```

### Step 4.3 — Wait for all pods to be Running

```bash
kubectl get pods -n production -w
```
**Expected output (wait ~3 minutes for all Running):**
```
NAME                     READY   STATUS              RESTARTS   AGE
postgres-0               0/1     ContainerCreating   0          10s
redis-xxxxx              0/1     ContainerCreating   0          8s
api-xxxxx                0/1     Init:0/1            0          5s
...
# After ~3 minutes:
postgres-0               1/1     Running             0          3m
redis-xxxxx              1/1     Running             0          3m
api-xxxxx                1/1     Running             0          2m
api-yyyyy                1/1     Running             0          2m
```
Press `Ctrl+C` when all show `Running`.

### Step 4.4 — Check full status of everything

```bash
kubectl get all -n production
```
**Expected output:**
```
NAME                       READY   STATUS    RESTARTS   AGE
pod/postgres-0             1/1     Running   0          5m
pod/redis-xxxxx            1/1     Running   0          5m
pod/api-xxxxx              1/1     Running   0          4m
pod/api-yyyyy              1/1     Running   0          4m

NAME                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/postgres-service   ClusterIP   10.43.x.x       <none>        5432/TCP   5m
service/redis-service      ClusterIP   10.43.x.x       <none>        6379/TCP   5m
service/api-service        ClusterIP   10.43.x.x       <none>        80/TCP     4m

NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/redis  1/1     1            1           5m
deployment.apps/api    2/2     2            2           4m

NAME                                        REFERENCE        TARGETS              MINPODS   MAXPODS   REPLICAS
horizontalpodautoscaler.autoscaling/api-hpa Deployment/api   cpu: <unknown>/70%   2         5         2
```

### Step 4.5 — Test health endpoint (via EC2 IP directly)

```bash
EC2_IP="13.235.XX.XX"   # replace with your actual IP

curl http://$EC2_IP/health
```
**Expected output:**
```json
{
  "status": "healthy",
  "timestamp": "2026-06-10T08:00:00Z",
  "checks": {
    "redis": "UP",
    "postgres": "UP"
  }
}
```

```bash
# Test the AI predict endpoint
curl -X POST http://$EC2_IP/v1/predict \
  -H "Content-Type: application/json" \
  -d '{"text": "What is DevOps?"}'
```
**Expected output:**
```json
{
  "response": "[AI Response] Analyzed: 'What is DevOps?' — confidence: 0.97, category: general",
  "source": "llm_model",
  "cached": false
}
```

```bash
# Call again to test Redis cache
curl -X POST http://$EC2_IP/v1/predict \
  -H "Content-Type: application/json" \
  -d '{"text": "What is DevOps?"}'
```
**Expected output (notice "cached": true now):**
```json
{
  "response": "[AI Response] Analyzed: 'What is DevOps?' — confidence: 0.97, category: general",
  "source": "cache",
  "cached": true
}
```

### Step 4.6 — Check ingress is configured

```bash
kubectl get ingress -n production
```
**Expected output:**
```
NAME          CLASS   HOSTS                               ADDRESS        PORTS     AGE
app-ingress   nginx   hudocafe.com,api.hudocafe.com       13.235.XX.XX   80, 443   5m
```

### Step 4.7 — Check logs from FastAPI pods

```bash
# Get logs from one pod
kubectl logs -l app=api -n production --tail=20
```
**Expected output (JSON logs):**
```
{"timestamp":"2026-06-10T08:00:01Z","level":"INFO","service":"fastapi-backend","message":"🚀 Application starting up..."}
{"timestamp":"2026-06-10T08:00:02Z","level":"INFO","service":"fastapi-backend","message":"Database table 'predictions' ensured."}
{"timestamp":"2026-06-10T08:00:05Z","level":"INFO","service":"fastapi-backend","message":"GET /health → 200 (45.23ms)"}
```

---

## PHASE 5 — ArgoCD: Setup GitOps

**All commands on EC2**

### Step 5.1 — Install ArgoCD CLI

```bash
curl -sSL -o argocd \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

argocd version --client
```
**Expected output:**
```
argocd: v2.x.x
  BuildDate: 2026-xx-xxTxx:xx:xxZ
  GitCommit: xxxxxxxxx
  ...
```

### Step 5.2 — Get ArgoCD admin password (if you didn't save it earlier)

```bash
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASS"
```

### Step 5.3 — Login to ArgoCD via CLI

```bash
argocd login localhost:30080 \
  --username admin \
  --password "$ARGOCD_PASS" \
  --insecure
```
**Expected output:**
```
'admin:login' logged in successfully
Context 'localhost:30080' updated
```

### Step 5.4 — Update your GitHub repo URL in ArgoCD manifest

```bash
# Edit the application.yaml before applying
# Replace YOUR_USERNAME with your actual GitHub username
sed -i 's|YOUR_USERNAME|parminder911|g' ~/app/argocd/application.yaml
sed -i 's|YOUR_USERNAME|parminder911|g' ~/app/argocd/project.yaml

# Verify the change
grep "repoURL" ~/app/argocd/application.yaml
```
**Expected output:**
```
    repoURL: https://github.com/parminder911/DevOps-project
```

### Step 5.5 — Add your GitHub repo to ArgoCD

```bash
# You need a GitHub Personal Access Token (PAT)
# Create one at: https://github.com/settings/tokens
# Permissions needed: repo (full access)

argocd repo add https://github.com/parminder911/DevOps-project \
  --username parminder911 \
  --password YOUR_GITHUB_PAT

# Verify repo was added
argocd repo list
```
**Expected output:**
```
TYPE  NAME  REPO                                              INSECURE  OCI    LFS    CREDS  STATUS      MESSAGE
git         https://github.com/parminder911/DevOps-project   false     false  false  true   Successful
```

### Step 5.6 — Apply ArgoCD Application

```bash
kubectl apply -f ~/app/argocd/project.yaml
kubectl apply -f ~/app/argocd/application.yaml
```
**Expected output:**
```
appproject.argoproj.io/hudocafe created
application.argoproj.io/hudocafe-app created
```

### Step 5.7 — Check ArgoCD app status

```bash
argocd app get hudocafe-app
```
**Expected output:**
```
Name:               argocd/hudocafe-app
Project:            hudocafe
Server:             https://kubernetes.default.svc
Namespace:          production
URL:                https://localhost:30080/applications/hudocafe-app
Repo:               https://github.com/parminder911/DevOps-project
Target:             main
Path:               k8s
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to main (xxxxxxx)
Health Status:      Healthy

GROUP              KIND         NAMESPACE   NAME               STATUS   HEALTH   HOOK  MESSAGE
                   ConfigMap    production  app-config         Synced   
apps               Deployment   production  api                Synced   Healthy
apps               Deployment   production  redis              Synced   Healthy
apps               StatefulSet  production  postgres           Synced   Healthy
                   Service      production  api-service        Synced   Healthy
                   Service      production  postgres-service   Synced   Healthy
                   Service      production  redis-service      Synced   Healthy
networking.k8s.io  Ingress      production  app-ingress        Synced   Healthy
autoscaling        HorizontalPodAutoscaler  production  api-hpa  Synced  Healthy
```

### Step 5.8 — Force a manual sync to verify GitOps works

```bash
argocd app sync hudocafe-app
```
**Expected output:**
```
TIMESTAMP                  GROUP        KIND        NAMESPACE  NAME              STATUS   HEALTH   HOOK  MESSAGE
2026-06-10T08:00:00+00:00  apps         Deployment  production api               Running  Healthy
2026-06-10T08:00:00+00:00             ConfigMap   production app-config         Synced
...
Message: successfully synced (all tasks run)
```

```bash
# List all ArgoCD apps
argocd app list
```
**Expected output:**
```
NAME            CLUSTER                         NAMESPACE   PROJECT   STATUS  HEALTH   SYNCPOLICY  CONDITIONS
hudocafe-app    https://kubernetes.default.svc  production  hudocafe  Synced  Healthy  Auto-Prune  <none>
```

---

## PHASE 6 — GitHub Actions: Setup CI/CD Pipeline

### Step 6.1 — Add GitHub Secrets

In your browser, go to:
`https://github.com/parminder911/DevOps-project/settings/secrets/actions`

Add these secrets (click **New repository secret** for each):

| Secret Name | Value |
|-------------|-------|
| `AWS_ACCESS_KEY_ID` | Get from: `aws configure get aws_access_key_id` |
| `AWS_SECRET_ACCESS_KEY` | Get from: `aws configure get aws_secret_access_key` |
| `EC2_HOST` | Your EC2 Elastic IP (e.g. `13.235.XX.XX`) |
| `ARGOCD_SERVER` | `13.235.XX.XX:30080` |
| `ARGOCD_PASSWORD` | The password from Step 2.6 |

**Get your AWS credentials from WSL:**
```bash
aws configure get aws_access_key_id
aws configure get aws_secret_access_key
```

### Step 6.2 — Trigger the first CI/CD run

```bash
# From WSL (not EC2)
cd /mnt/c/Users/Devloper/Desktop/DevOps-project

# Make a small code change to trigger pipeline
echo "# $(date)" >> app/main.py

# Commit and push
git add .
git commit -m "ci: trigger first CI/CD pipeline run"
git push origin main
```

### Step 6.3 — Monitor CI/CD run

Visit: `https://github.com/parminder911/DevOps-project/actions`

**Expected: CI pipeline runs:**
```
✅ Checkout Source
✅ Configure AWS Credentials
✅ Login to Amazon ECR
✅ Set up Docker Buildx
✅ Build and Push Docker Image
✅ Update K8s Deployment Image Tag
✅ Scan image for vulnerabilities (Trivy)
```

**Then CD pipeline automatically:**
```
✅ Checkout Source
✅ Install ArgoCD CLI
✅ Login to ArgoCD
✅ Sync ArgoCD Application
✅ Wait for Application Healthy
✅ Verify Health Endpoint
✅ Deployment Summary
```

### Step 6.4 — Verify new image was deployed (on EC2)

```bash
# Check that the deployment has a new image tag
kubectl get deployment api -n production -o jsonpath='{.spec.template.spec.containers[0].image}' && echo

# Should show the git commit SHA tag, not :latest
```
**Expected output:**
```
652942059153.dkr.ecr.ap-south-1.amazonaws.com/hudocafe/api:abc123def456
```

---

## PHASE 7 — DNS: Point Domain to EC2

### Step 7.1 — Verify Route53 A records were created

```bash
# Get the hosted zone ID
ZONE_ID=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='hudocafe.com.'].Id" \
  --output text | cut -d'/' -f3)

echo "Zone ID: $ZONE_ID"

# List all DNS records
aws route53 list-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --query 'ResourceRecordSets[*].[Name,Type,TTL,ResourceRecords[0].Value]' \
  --output table
```
**Expected output:**
```
-----------------------------------------------------------------------
|                      ListResourceRecordSets                         |
+--------------------+------+-----+-----------------------------------+
| api.hudocafe.com.  | A    | 300 | 13.235.XX.XX                      |
| argocd.hudocafe.com| A    | 300 | 13.235.XX.XX                      |
| hudocafe.com.      | A    | 300 | 13.235.XX.XX                      |
| hudocafe.com.      | NS   | 172800 | ns-XXX.awsdns-XX.co.uk        |
| hudocafe.com.      | SOA  | 900  | ns-XXX.awsdns-XX.com.           |
| www.hudocafe.com.  | A    | 300 | 13.235.XX.XX                      |
+--------------------+------+-----+-----------------------------------+
```

### Step 7.2 — Check DNS propagation after updating nameservers

```bash
# After updating nameservers at registrar, check propagation:
dig hudocafe.com +short
```
**Expected output (once propagated):**
```
13.235.XX.XX
```

```bash
# Test HTTPS after DNS propagates
curl https://hudocafe.com/health
curl https://api.hudocafe.com/health
```
**Expected output:**
```json
{"status":"healthy","timestamp":"2026-06-10T08:00:00Z","checks":{"redis":"UP","postgres":"UP"}}
```

---

## PHASE 8 — Backup: Setup Daily Database Backups

**All commands on EC2**

### Step 8.1 — Test backup script manually

```bash
bash ~/app/scripts/backup.sh
```
**Expected output:**
```
[2026-06-10T08:00:00Z] Found postgres pod: postgres-0
[2026-06-10T08:00:01Z] Starting backup: db_backup_20260610_080001.sql.gz
[2026-06-10T08:00:05Z] Backup created: /opt/backups/postgres/db_backup_20260610_080001.sql.gz (4.0K)
[2026-06-10T08:00:06Z] Uploading to S3: s3://hudocafe-backups/postgres/db_backup_20260610_080001.sql.gz
[2026-06-10T08:00:08Z] Upload complete: s3://hudocafe-backups/postgres/db_backup_20260610_080001.sql.gz
[2026-06-10T08:00:08Z] Cleaned local backups older than 7 days
[2026-06-10T08:00:08Z] ✅ Backup completed successfully: db_backup_20260610_080001.sql.gz
```

### Step 8.2 — Verify backup is in S3

```bash
aws s3 ls s3://hudocafe-backups/postgres/ --human-readable
```
**Expected output:**
```
2026-06-10 08:00:08    4.0 KiB db_backup_20260610_080001.sql.gz
```

### Step 8.3 — Schedule daily automatic backups

```bash
# Open crontab
crontab -e

# Add this line (backup every day at midnight):
0 0 * * * /bin/bash /home/ubuntu/app/scripts/backup.sh >> /var/log/backup.log 2>&1
```
**Verify cron was added:**
```bash
crontab -l
```
**Expected output:**
```
0 0 * * * /bin/bash /home/ubuntu/app/scripts/backup.sh >> /var/log/backup.log 2>&1
```

---

## PHASE 9 — Verification: Full Health Check

Run these commands as a final verification on EC2:

```bash
echo "=== K8s Nodes ===" && kubectl get nodes
echo ""
echo "=== All Production Pods ===" && kubectl get pods -n production
echo ""
echo "=== Services ===" && kubectl get svc -n production
echo ""
echo "=== Ingress ===" && kubectl get ingress -n production
echo ""
echo "=== ArgoCD App Status ===" && argocd app get hudocafe-app --output wide
echo ""
echo "=== Health Endpoint ===" && curl -s http://localhost/health | python3 -m json.tool
echo ""
echo "=== Docker Images in ECR ===" && aws ecr list-images --repository-name hudocafe/api --region ap-south-1 --output table
echo ""
echo "=== S3 Backups ===" && aws s3 ls s3://hudocafe-backups/postgres/
```

**Expected final output:**
```
=== K8s Nodes ===
NAME              STATUS   ROLES                  AGE   VERSION
hudocafe-node-1   Ready    control-plane,master   1h    v1.30.x+k3s1

=== All Production Pods ===
NAME             READY   STATUS    RESTARTS   AGE
api-xxxxx        1/1     Running   0          30m
api-yyyyy        1/1     Running   0          30m
postgres-0       1/1     Running   0          45m
redis-xxxxx      1/1     Running   0          45m

=== Services ===
NAME               TYPE        CLUSTER-IP   PORT(S)    AGE
api-service        ClusterIP   10.43.x.x    80/TCP     45m
postgres-service   ClusterIP   10.43.x.x    5432/TCP   45m
redis-service      ClusterIP   10.43.x.x    6379/TCP   45m

=== Ingress ===
NAME          CLASS   HOSTS                              ADDRESS          PORTS
app-ingress   nginx   hudocafe.com,api.hudocafe.com      13.235.XX.XX     80, 443

=== Health Endpoint ===
{
    "status": "healthy",
    "timestamp": "2026-06-10T08:00:00Z",
    "checks": {
        "redis": "UP",
        "postgres": "UP"
    }
}

=== Docker Images in ECR ===
...(shows your pushed images)...

=== S3 Backups ===
2026-06-10 08:00:08    4096 db_backup_20260610_080001.sql.gz
```

---

## 🔧 Troubleshooting: Common Issues & Fixes

### ❌ Pod stuck in `ImagePullBackOff`
```bash
kubectl describe pod <pod-name> -n production | grep -A5 "Events"
# Fix: ECR secret might have expired (24h token)
kubectl delete secret ecr-secret -n production
kubectl create secret docker-registry ecr-secret \
  --docker-server=652942059153.dkr.ecr.ap-south-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region ap-south-1) \
  --namespace=production
```

### ❌ Pod stuck in `CrashLoopBackOff`
```bash
# View the actual error
kubectl logs <pod-name> -n production --previous
# Common fix: DB not ready yet, wait 2 min and check postgres pod first
kubectl get pods -n production
```

### ❌ Terraform: `Error: no matching ACM certificate found`
```bash
# Verify your cert exists and is ISSUED
aws acm list-certificates --region ap-south-1 \
  --query 'CertificateSummaryList[*].[DomainName,Status,CertificateArn]' \
  --output table
```

### ❌ ArgoCD login fails
```bash
# Check ArgoCD server is running
kubectl get pods -n argocd | grep argocd-server
# Restart if needed
kubectl rollout restart deployment/argocd-server -n argocd
# Wait 30s then try login again
```

### ❌ `curl health` returns connection refused
```bash
# Check NGINX ingress is running
kubectl get pods -n ingress-nginx
# Check if ingress is configured
kubectl describe ingress app-ingress -n production
# Check api pods are healthy
kubectl get pods -n production -l app=api
```

---

## 📋 Final Assignment Checklist

| Requirement | Status | How to Verify |
|-------------|--------|---------------|
| Dockerized FastAPI | ✅ | `docker build ./app` |
| Docker Compose | ✅ | `docker compose up -d` |
| PostgreSQL | ✅ | `kubectl get pods -n production \| grep postgres` |
| Redis | ✅ | `kubectl get pods -n production \| grep redis` |
| NGINX reverse proxy | ✅ | `kubectl get pods -n ingress-nginx` |
| Environment variables | ✅ | `kubectl get configmap app-config -n production -o yaml` |
| SSL (ACM) | ✅ | `aws acm describe-certificate --certificate-arn ...` |
| Server security (UFW) | ✅ | `sudo ufw status verbose` |
| Server security (fail2ban) | ✅ | `sudo fail2ban-client status sshd` |
| GitHub Actions CI | ✅ | GitHub → Actions tab |
| GitHub Actions CD (ArgoCD) | ✅ | `argocd app get hudocafe-app` |
| Health endpoint | ✅ | `curl http://EC2_IP/health` |
| JSON logging | ✅ | `kubectl logs -l app=api -n production` |
| Backup strategy | ✅ | `bash scripts/backup.sh` |
| **BONUS**: ArgoCD GitOps | ✅ | `argocd app list` |
| **BONUS**: HPA autoscaling | ✅ | `kubectl get hpa -n production` |
| **BONUS**: Terraform IaC | ✅ | `terraform show` |
| **BONUS**: AI endpoint | ✅ | `curl -X POST .../v1/predict` |
| **BONUS**: S3 backups | ✅ | `aws s3 ls s3://hudocafe-backups/` |
| **BONUS**: Zero-downtime deploy | ✅ | Rolling update in K8s |
