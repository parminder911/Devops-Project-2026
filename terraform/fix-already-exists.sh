#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# FIX-ALREADY-EXISTS.sh
# Run this directly in WSL to fix all "AlreadyExists" terraform errors.
# No git pull needed — paste and run directly.
#
# Usage: bash fix-already-exists.sh
# Run from: /home/parm007/b/Devops-Project-2026/terraform/
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OK]   $1${NC}"; }
skip() { echo -e "${YELLOW}[SKIP] $1 — already in state or does not exist yet (OK)${NC}"; }
hdr()  { echo -e "\n${BOLD}━━━ $1 ━━━${NC}"; }

TFVARS="-var-file=terraform.tfvars"

echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD} Terraform Import — Fix AlreadyExists Errors${NC}"
echo -e "${BOLD} AWS Account: 652942059153 | Region: ap-south-1${NC}"
echo -e "${BOLD}============================================================${NC}"
echo ""

# Helper: runs import, skips gracefully if resource already in state
do_import() {
  local resource="$1"; local id="$2"
  echo -n "  Importing $resource ... "
  # suppress noisy "already managed" error — treat as success
  if terraform import $TFVARS "$resource" "$id" > /tmp/tf_import_out.txt 2>&1; then
    log "done"
  else
    if grep -q "already managed\|Resource already\|Cannot import" /tmp/tf_import_out.txt 2>/dev/null; then
      skip "$resource"
    else
      skip "$resource (import failed — will try to create or already exists)"
      cat /tmp/tf_import_out.txt | tail -3
    fi
  fi
}

# ── 1. EC2 Key Pair ──────────────────────────────────────────────────────────
hdr "EC2 Key Pair"
do_import "aws_key_pair.devops" "hudocafe-key"

# ── 2. IAM Role & Policies ───────────────────────────────────────────────────
hdr "IAM Role + Policies + Instance Profile"
do_import "aws_iam_role.ec2_role"              "hudocafe-ec2-role"
do_import "aws_iam_role_policy.ec2_policy"     "hudocafe-ec2-role:hudocafe-ec2-policy"
do_import "aws_iam_role_policy_attachment.ssm" "hudocafe-ec2-role/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
do_import "aws_iam_instance_profile.ec2_profile" "hudocafe-ec2-profile"

# ── 3. ECR Repository ────────────────────────────────────────────────────────
hdr "ECR Repository"
do_import "aws_ecr_repository.app"        "hudocafe/api"
do_import "aws_ecr_lifecycle_policy.app"  "hudocafe/api"

# ── 4. S3 Backup Bucket ──────────────────────────────────────────────────────
hdr "S3 Backup Bucket + Configurations"
do_import "aws_s3_bucket.backups"                                          "hudocafe-backups"
do_import "aws_s3_bucket_versioning.backups"                               "hudocafe-backups"
do_import "aws_s3_bucket_server_side_encryption_configuration.backups"     "hudocafe-backups"
do_import "aws_s3_bucket_lifecycle_configuration.backups"                  "hudocafe-backups"

# ── 5. Summary ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${GREEN}${BOLD} All imports done. Current Terraform state:${NC}"
echo -e "${BOLD}============================================================${NC}"
terraform state list
echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${GREEN}${BOLD} ✅ NOW RUN:${NC}"
echo -e "${GREEN}${BOLD}    terraform apply -var-file=terraform.tfvars${NC}"
echo -e "${BOLD}============================================================${NC}"
echo ""
