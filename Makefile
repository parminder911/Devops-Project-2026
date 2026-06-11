# ─── Makefile ─────────────────────────────────────────────────────────────────
# Run these from WSL in the project root directory.
# Usage: make <target>

.PHONY: help tf-init tf-plan tf-apply tf-destroy \
        dev-up dev-down dev-logs dev-clean \
        backup health

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Terraform ────────────────────────────────────────────────────────────────
tf-init:  ## Initialize Terraform
	cd terraform && terraform init

tf-plan:  ## Show Terraform plan
	cd terraform && terraform plan

tf-apply:  ## Apply Terraform (creates ALB, DNS records)
	cd terraform && terraform apply -auto-approve

tf-destroy:  ## DANGER: Destroy ALB and Route 53 records
	cd terraform && terraform destroy -auto-approve

tf-output:  ## Show Terraform outputs (ALB DNS)
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

# ─── Database Ops ────────────────────────────────────────────────────────────
backup:  ## Create a database backup (runs locally for testing)
	docker exec -t production_db pg_dump -U app_user -d app_db > db_backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "✅ Database backup created successfully"

health:  ## Check application health endpoint
	curl -s https://hudocafe.com/health || curl -s http://localhost/health
