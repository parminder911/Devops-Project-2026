# ─── Makefile ─────────────────────────────────────────────────────────────────
# Run these from WSL in the project root directory.
# Usage: make <target>

.PHONY: help tf-init tf-plan tf-apply tf-destroy \
        dev-up dev-down dev-logs \
        k8s-apply k8s-delete k8s-status \
        argocd-apply argocd-password backup

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Terraform ────────────────────────────────────────────────────────────────
tf-init:  ## Initialize Terraform
	cd terraform && terraform init

tf-plan:  ## Show Terraform plan
	cd terraform && terraform plan -var-file=terraform.tfvars

tf-apply:  ## Apply Terraform (creates EC2, DNS, ACM)
	cd terraform && terraform apply -var-file=terraform.tfvars -auto-approve

tf-destroy:  ## DANGER: Destroy all infrastructure
	cd terraform && terraform destroy -var-file=terraform.tfvars

tf-output:  ## Show Terraform outputs (EC2 IP, SSH command, URLs)
	cd terraform && terraform output

# ─── Local Development (Docker Compose) ──────────────────────────────────────
dev-up:  ## Start all services locally with Docker Compose
	cp .env.example .env 2>/dev/null || true
	docker compose up -d --build
	@echo "✅ App running: http://localhost"
	@echo "   API Docs:    http://localhost/docs"
	@echo "   Health:      http://localhost/health"

dev-down:  ## Stop local services
	docker compose down

dev-logs:  ## Tail all container logs
	docker compose logs -f

dev-clean:  ## Remove all containers and volumes
	docker compose down -v --remove-orphans

# ─── Kubernetes ───────────────────────────────────────────────────────────────
k8s-apply:  ## Apply all K8s manifests to cluster
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/configmap.yaml
	kubectl apply -f k8s/secrets.yaml
	kubectl apply -f k8s/postgres/
	kubectl apply -f k8s/redis/
	kubectl apply -f k8s/app/
	kubectl apply -f k8s/ingress/

k8s-status:  ## Check pod status in production namespace
	kubectl get pods,svc,ingress -n production

k8s-logs:  ## Stream FastAPI pod logs
	kubectl logs -f -l app=api -n production

k8s-delete:  ## Delete all K8s resources
	kubectl delete -f k8s/ -n production --ignore-not-found

# ─── ArgoCD ───────────────────────────────────────────────────────────────────
argocd-apply:  ## Apply ArgoCD Application manifest
	kubectl apply -f argocd/project.yaml
	kubectl apply -f argocd/application.yaml

argocd-password:  ## Get initial ArgoCD admin password
	kubectl -n argocd get secret argocd-initial-admin-secret \
	  -o jsonpath="{.data.password}" | base64 -d && echo

argocd-sync:  ## Force ArgoCD sync
	argocd app sync hudocafe-app

# ─── Ops ─────────────────────────────────────────────────────────────────────
backup:  ## Run database backup manually
	bash scripts/backup.sh

health:  ## Check application health endpoint
	curl -s https://api.hudocafe.com/health | python3 -m json.tool
