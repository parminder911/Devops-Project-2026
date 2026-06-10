#!/bin/bash
# ─── Server Security Hardening Script ─────────────────────────────────────────
# Run once on fresh EC2 instance (already handled by user_data.sh during boot)
# Safe to re-run for drift correction.

set -euo pipefail
echo "=== Hardening started at $(date) ==="

# ── 1. System Update ──────────────────────────────────────────────────────────
apt-get update -y && apt-get upgrade -y

# ── 2. UFW Firewall ───────────────────────────────────────────────────────────
apt-get install -y ufw

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    comment 'SSH'
ufw allow 80/tcp    comment 'HTTP'
ufw allow 443/tcp   comment 'HTTPS'
ufw allow 30080/tcp comment 'ArgoCD'

ufw --force enable
ufw status verbose
echo "✅ UFW configured"

# ── 3. fail2ban ───────────────────────────────────────────────────────────────
apt-get install -y fail2ban

cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime   = 1h
findtime  = 10m
maxretry  = 5
ignoreip  = 127.0.0.1/8

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 24h
EOF

systemctl enable fail2ban
systemctl restart fail2ban
echo "✅ fail2ban configured (3 failed SSH attempts = 24h ban)"

# ── 4. SSH Hardening ──────────────────────────────────────────────────────────
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/'  /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/'                /etc/ssh/sshd_config

systemctl restart sshd
echo "✅ SSH hardened (no password auth, no root login)"

# ── 5. Automatic Security Updates ────────────────────────────────────────────
apt-get install -y unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "false";' \
  >> /etc/apt/apt.conf.d/50unattended-upgrades
dpkg-reconfigure -pmedium unattended-upgrades
echo "✅ Automatic security updates enabled"

echo "=== Hardening complete! ==="
