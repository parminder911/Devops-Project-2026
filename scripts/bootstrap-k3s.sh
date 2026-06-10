#!/bin/bash
# ─── k3s + ArgoCD Bootstrap Script ───────────────────────────────────────────
# Run this on the EC2 instance AFTER Terraform applies.
# This is also automatically run via user_data.sh on first boot.
# Use this script if you need to reinstall or verify.

set -euo pipefail
echo "=== k3s Bootstrap started at $(date) ==="

# ── 1. Install k3s ───────────────────────────────────────────────────────────
if ! command -v k3s &> /dev/null; then
  echo "Installing k3s..."
  curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --node-name hudocafe-node-1
  sleep 30
fi

echo "k3s status:"
k3s kubectl get nodes

# ── 2. Configure kubectl ──────────────────────────────────────────────────────
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc

# ── 3. Install Helm ───────────────────────────────────────────────────────────
if ! command -v helm &> /dev/null; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# ── 4. Install NGINX Ingress Controller ───────────────────────────────────────
echo "Installing NGINX Ingress..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=80 \
  --set controller.service.nodePorts.https=443 \
  --set controller.hostNetwork=true \
  --wait

echo "✅ NGINX Ingress installed"

# ── 5. Install ArgoCD ─────────────────────────────────────────────────────────
kubectl create namespace argocd 2>/dev/null || true

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s

# Expose ArgoCD via NodePort
kubectl patch svc argocd-server -n argocd \
  -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":30080,"name":"https"}]}}'

# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "✅ ArgoCD installed!"
echo "   UI: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):30080"
echo "   Username: admin"
echo "   Password: $ARGOCD_PASSWORD"
echo "   (Save this password! It's only shown once)"

# ── 6. Create Production Namespace ───────────────────────────────────────────
kubectl create namespace production 2>/dev/null || true

# ── 7. Register GitHub Repo in ArgoCD ────────────────────────────────────────
echo ""
echo "=== NEXT STEPS ==="
echo "1. Install ArgoCD CLI:  curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && chmod +x argocd && sudo mv argocd /usr/local/bin/"
echo "2. Login: argocd login localhost:30080 --username admin --password '$ARGOCD_PASSWORD' --insecure"
echo "3. Add repo: argocd repo add https://github.com/YOUR_USERNAME/DevOps-project --username YOUR_GITHUB_USER --password YOUR_PAT"
echo "4. Apply ArgoCD app: kubectl apply -f ~/app/argocd/application.yaml"
echo ""
echo "=== Bootstrap complete at $(date) ==="
