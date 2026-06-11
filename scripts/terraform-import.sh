#!/bin/bash
# ─── Terraform Import Script ──────────────────────────────────────────────────
# Run this when you get "AlreadyExists" errors on terraform apply.
# It imports existing AWS resources into Terraform state so apply can proceed.
#
# Usage: bash scripts/terraform-import.sh
# Run from: the terraform/ directory

set -euo pipefail

# Colors
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[IMPORT] $1${NC}"; }
warn() { echo -e "${YELLOW}[SKIP]   $1 (already in state or not found — OK)${NC}"; }
err()  { echo -e "${RED}[ERROR]  $1${NC}"; }

TFVARS="-var-file=terraform.tfvars"

echo ""
echo "============================================================"
echo " Terraform Import — Hudocafe Existing Resources"
echo " AWS Account: 652942059153 | Region: ap-south-1"
echo "============================================================"
echo ""

# ── Helper: import with graceful skip if already imported ────────────────────
tf_import() {
  local resource="$1"
  local id="$2"
  log "Importing: $resource → $id"
  if terraform import $TFVARS "$resource" "$id" 2>/dev/null; then
    log "✅ Imported: $resource"
  else
    warn "$resource (skipping — may already be in state)"
  fi
  echo ""
}

# ═══════════════════════════════════════════════════════════
# 1. EC2 KEY PAIR
# ═══════════════════════════════════════════════════════════
log "━━━ Importing EC2 Key Pair ━━━"
tf_import "aws_key_pair.devops" "hudocafe-key"

# ═══════════════════════════════════════════════════════════
# 2. IAM ROLE + POLICY + PROFILE
# ═══════════════════════════════════════════════════════════
log "━━━ Importing IAM Resources ━━━"
tf_import "aws_iam_role.ec2_role" "hudocafe-ec2-role"
tf_import "aws_iam_role_policy.ec2_policy" "hudocafe-ec2-role:hudocafe-ec2-policy"
tf_import "aws_iam_role_policy_attachment.ssm" \
  "hudocafe-ec2-role/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
tf_import "aws_iam_instance_profile.ec2_profile" "hudocafe-ec2-profile"

# ═══════════════════════════════════════════════════════════
# 3. ECR REPOSITORY + LIFECYCLE POLICY
# ═══════════════════════════════════════════════════════════
log "━━━ Importing ECR Repository ━━━"
tf_import "aws_ecr_repository.app" "hudocafe/api"
tf_import "aws_ecr_lifecycle_policy.app" "hudocafe/api"

# ═══════════════════════════════════════════════════════════
# 4. S3 BACKUP BUCKET + SUB-RESOURCES
# ═══════════════════════════════════════════════════════════
log "━━━ Importing S3 Bucket ━━━"
tf_import "aws_s3_bucket.backups" "hudocafe-backups"
tf_import "aws_s3_bucket_versioning.backups" "hudocafe-backups"
tf_import "aws_s3_bucket_server_side_encryption_configuration.backups" "hudocafe-backups"
tf_import "aws_s3_bucket_lifecycle_configuration.backups" "hudocafe-backups"

# ═══════════════════════════════════════════════════════════
# 5. SHOW CURRENT STATE SUMMARY
# ═══════════════════════════════════════════════════════════
echo ""
echo "============================================================"
log "Import complete! Resources now in Terraform state:"
echo "============================================================"
terraform state list
echo ""
echo "============================================================"
echo -e "${GREEN}✅ NOW RUN: terraform apply -var-file=terraform.tfvars${NC}"
echo "============================================================"
echo ""
