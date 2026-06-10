#!/bin/bash
# ─── EC2 User Data Bootstrap Script ─────────────────────────────────────────
# Runs automatically on first boot.
# Installs: Docker, k3s, ArgoCD, UFW, fail2ban

set -euo pipefail
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Bootstrap started at $(date) ==="

# ── 1. System Update ──────────────────────────────────────────────────────────
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget git unzip jq ca-certificates gnupg lsb-release

# ── 2. Add 2GB Swap (CRITICAL for t2.micro — only 1GB RAM) ───────────────────
# Without swap, k3s + ArgoCD + all pods will OOM kill on t2.micro
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
# Reduce swap aggressiveness (prefer RAM over swap)
echo 'vm.swappiness=10' >> /etc/sysctl.conf
sysctl -p
echo "✅ Swap: $(free -h | grep Swap)"

# ── 2. Install Docker ─────────────────────────────────────────────────────────
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker
echo "✅ Docker installed"

# ── 3. Install k3s (Lightweight Kubernetes) ────────────────────────────────
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --node-name hudocafe-node-1

# Wait for k3s to be ready
sleep 30
kubectl get nodes
echo "✅ k3s installed"

# ── 4. Configure kubectl for ubuntu user ─────────────────────────────────────
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
sed -i "s/127.0.0.1/$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)/g" \
  /home/ubuntu/.kube/config

echo 'export KUBECONFIG=/home/ubuntu/.kube/config' >> /home/ubuntu/.bashrc
echo "✅ kubectl configured"

# ── 5. Install ArgoCD ─────────────────────────────────────────────────────────
kubectl create namespace argocd || true
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Patch ArgoCD server to NodePort for external access
kubectl patch svc argocd-server -n argocd \
  -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":30080}]}}'

echo "✅ ArgoCD installed (UI → http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):30080)"

# ── 6. Install Helm ───────────────────────────────────────────────────────────
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "✅ Helm installed"

# ── 7. Create Production Namespace ───────────────────────────────────────────
kubectl create namespace production || true
echo "✅ Namespace 'production' created"

# ── 8. UFW Firewall ───────────────────────────────────────────────────────────
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   comment 'SSH'
ufw allow 80/tcp   comment 'HTTP'
ufw allow 443/tcp  comment 'HTTPS'
ufw allow 30080/tcp comment 'ArgoCD NodePort'
ufw allow 6443/tcp  comment 'k3s API'
ufw --force enable
echo "✅ UFW firewall configured"

# ── 9. fail2ban ───────────────────────────────────────────────────────────────
apt-get install -y fail2ban
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF
systemctl enable fail2ban
systemctl start fail2ban
echo "✅ fail2ban configured"

# ── 10. App directory setup ───────────────────────────────────────────────────
mkdir -p /home/ubuntu/app
chown -R ubuntu:ubuntu /home/ubuntu/app

# ── 11. Log rotation for docker ──────────────────────────────────────────────
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
systemctl restart docker

echo "=== Bootstrap completed at $(date) ==="
echo "🚀 Server is ready! Run: ssh ubuntu@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
