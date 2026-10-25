# Production Deployment Guide — Oracle Cloud Infrastructure (ARM64)

This document provides a production-ready guide to deploying the **AI Sales Agent** on **Oracle Cloud Infrastructure (OCI) Always Free Tier** using an ARM64 Ampere A1 compute instance.

---

## 1. Architecture Overview

```
                                      [ Internet ]
                                           │
                        ┌──────────────────┴──────────────────┐
                        │                                     │
                        ▼ (Port 443 HTTPS / Port 80 HTTP)     ▼ (Port 22 SSH)
          ┌──────────────────────────────────────────────────────────────┐
          │                    Oracle Cloud ARM64 VM                     │
          │                                                              │
          │  ┌────────────────────────────────────────────────────────┐  │
          │  │                  Caddy Reverse Proxy                   │  │
          │  │           (Automated Let's Encrypt TLS)                │  │
          │  │                                                        │  │
          │  │  Allowed Endpoints:                                    │  │
          │  │   • /webhook/*                                         │  │
          │  │   • /webhook-test/*                                    │  │
          │  │   • /rest/oauth2-credential/callback                  │  │
          │  │                                                        │  │
          │  │  Blocked Endpoints (HTTP 403 Forbidden):               │  │
          │  │   • / (Admin UI)                                       │  │
          │  │   • /workflow/*, /settings/*, etc.                     │  │
          │  └────────────────────────┬───────────────────────────────┘  │
          │                           │ (internal bridge)                │
          │                           ▼                                  │
          │  ┌────────────────────────────────────────────────────────┐  │
          │  │                     n8n Container                      │  │
          │  │                 (Port 5678 internal)                   │  │
          │  │    • Telegram Webhook Handler                          │  │
          │  │    • Gemini 3.5 Flash-Lite Subworkflow                 │  │
          │  │    • Knowledge Retrieval Subworkflow                   │  │
          │  │    • Human Takeover & Owner Controls                   │  │
          │  └──────────────┬─────────────────────────▲───────────────┘  │
          │                 │                         │                  │
          │                 ▼ (internal port 5432)    │ SSH Local Tunnel │
          │  ┌─────────────────────────────────────┐  │ (localhost:5678) │
          │  │         PostgreSQL 16 Database      │  │                  │
          │  │    • Inventory & Shipping Cache     │  │                  │
          │  │    • Deduplication Table            │  │                  │
          │  │    • Agent Control & Chat State     │  │                  │
          │  └─────────────────────────────────────┘  │                  │
          └───────────────────────────────────────────┼──────────────────┘
                                                      │
                                                      ▼
                                       Developer Workstation
                                      (http://localhost:5678)
```

### Security Principles
- **No Public Admin Interface**: n8n's administrative UI and settings are never exposed to the public internet. Access is strictly granted via SSH tunneling (`ssh -N -L 5678:localhost:5678 opc@<IP>`).
- **No Public Database**: PostgreSQL (`5432`) is isolated entirely within the Docker private bridge network.
- **Automated TLS**: Caddy provides zero-maintenance Let's Encrypt TLS renewal, HTTP $\rightarrow$ HTTPS redirection, and strict HTTP header hardening.
- **Multi-Architecture**: All container images are pinned and explicitly compatible with `linux/arm64` (Ampere A1).

---

## 2. Step 1: Provision Oracle Cloud Compute Instance

1. Log into your [Oracle Cloud Console](https://cloud.oracle.com/).
2. Navigate to **Compute** $\rightarrow$ **Instances** $\rightarrow$ **Create Instance**.
3. **Configuration**:
   - **Name**: `ai-sales-agent-prod`
   - **Image**: `Canonical Ubuntu 24.04 LTS Minimal` or `Oracle Linux 8/9` (Ubuntu recommended).
   - **Shape**: **Ampere VM.Standard.A1.Flex** (Always Free Eligible):
     - **OCPUs**: 2 (up to 4 free)
     - **Memory**: 12 GB RAM (up to 24 GB free)
   - **Networking**:
     - Assign a public IPv4 address.
   - **SSH Keys**: Upload your personal public key (`id_ed25519.pub` or `id_rsa.pub`).
4. Click **Create** and wait for the instance state to become `RUNNING`.
5. Under **Networking** $\rightarrow$ **IP Addresses**, click **Reserved Public IPs** and assign a static Reserved IP to your instance.

---

## 3. Step 2: Configure Virtual Cloud Network (VCN) Security Lists

Oracle Cloud blocks all inbound traffic by default at the cloud firewall level.

1. In the Oracle Console, go to **Virtual Cloud Networks** $\rightarrow$ Click your VCN $\rightarrow$ Click **Security Lists** $\rightarrow$ **Default Security List**.
2. Click **Add Ingress Rules**:
   - **Source CIDR**: `0.0.0.0/0`
   - **IP Protocol**: `TCP`
   - **Destination Port Range**: `80,443`
   - **Description**: `Allow HTTP and HTTPS for Caddy Webhook Proxy`
3. Click **Add Ingress Rules**.

---

## 4. Step 3: Configure Host OS Firewall

Oracle Linux and Ubuntu on OCI have host-level firewall tables that block ports even if the VCN security list is open.

SSH into your Oracle instance:
```bash
ssh -i /path/to/private_key ubuntu@<YOUR_ORACLE_PUBLIC_IP>
# Or for Oracle Linux: ssh -i /path/to/private_key opc@<YOUR_ORACLE_PUBLIC_IP>
```

Open ports 80 and 443 at the OS level:

### For Ubuntu (iptables):
```bash
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save 2>/dev/null || sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

### For Oracle Linux (firewalld):
```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

---

## 5. Step 4: Configure DNS Domain

Create an **A Record** at your DNS provider (e.g. Cloudflare, Namecheap, Route53):
- **Type**: `A`
- **Name**: `agent` (or your subdomain)
- **Content**: `<YOUR_ORACLE_PUBLIC_IP>`
- **TTL**: Auto / 300 seconds
- **Proxy Status**: DNS Only (if using Cloudflare, turn off orange cloud proxy initially for Caddy Let's Encrypt validation).

---

## 6. Step 5: Install Docker Engine and Git

On the Oracle VM, run:
```bash
# Update repositories
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg git

# Install Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow ubuntu/opc user to run docker without sudo
sudo usermod -aG docker "$USER"
newgrp docker
```

---

## 7. Step 6: Clone Repository & Configure Production Environment

```bash
cd ~
git clone https://github.com/ushalabs/AI-Sales-Agent.git
cd AI-Sales-Agent

# Create production environment file from template
cp .env.production.example .env.production
chmod 600 .env.production
nano .env.production
```

Fill in the required configuration:
- `DOMAIN_NAME`: e.g. `agent.yourdomain.com`
- `POSTGRES_PASSWORD`: Strong password (generate via `openssl rand -base64 32`)
- `N8N_ENCRYPTION_KEY`: Strong hex key (generate via `openssl rand -hex 32`)
- `TELEGRAM_BOT_TOKEN`: Token obtained from `@BotFather`
- `TELEGRAM_WEBHOOK_SECRET`: Hex secret for payload verification
- `TELEGRAM_SELLER_USER_ID`: Seller's numerical Telegram ID
- `GEMINI_API_KEY`: API key from Google AI Studio
- `TELEGRAM_TEST_MODE`: `true` initially, switch to `false` when going live.

---

## 8. Step 7: Run Automated Deployment

Run the automated Oracle deployment script:
```bash
chmod +x scripts/*.sh
./scripts/deploy-oracle.sh
```

This script will:
1. Validate all environment variables.
2. Ensure OS firewall rules are active.
3. Pull ARM64-optimized container images.
4. Launch Postgres, n8n, and Caddy containers.
5. Wait for container health checks to report healthy.
6. Apply database schemas (`init-db.sql`, `init-control-db.sql`, `init-knowledge-db.sql`).
7. Import all production workflows into n8n.

---

## 9. Step 8: Verify Connectivity & Register Telegram Webhook

### Verify Outbound Connectivity
Check that the Oracle VM can reach Telegram, Gemini, and Google Sheets:
```bash
./scripts/verify-oracle-connectivity.sh
```

### Register Telegram Webhook
Register your production HTTPS webhook with Telegram Bot API:
```bash
./scripts/register-webhook.sh
```
Telegram should respond with:
```json
{"ok":true,"result":true,"description":"Webhook was set"}
```

---

## 10. Step 9: Secure Admin Access to n8n (SSH Tunnel)

Because n8n port `5678` is never published publicly, you access the editor from your workstation via an encrypted SSH tunnel.

From your local machine (Windows PowerShell or macOS/Linux Terminal):
```bash
ssh -N -L 5678:localhost:5678 ubuntu@<YOUR_ORACLE_PUBLIC_IP>
```

Keep that terminal open, then in your workstation browser navigate to:
```
http://localhost:5678
```

You can now:
- Manage n8n credentials securely.
- Monitor execution history.
- Activate the `Telegram Business Sales Agent (Master)` workflow.

---

## 11. Maintenance, Backups & Disaster Recovery

### Automated Backups
Set up a daily cron job on the Oracle VM:
```bash
crontab -e
```
Add:
```cron
0 3 * * * /home/ubuntu/AI-Sales-Agent/scripts/backup.sh > /dev/null 2>&1
```

### Manual Backup
```bash
./scripts/backup.sh
```
Backups are saved to `backups/n8n_db_<TIMESTAMP>.sql`.

### Restore Procedure
```bash
./scripts/restore.sh backups/n8n_db_YYYYMMDD_HHMMSS.sql
```

### Rollback Procedure
If an update causes an issue:
1. Stop the running containers:
   ```bash
   docker compose -f docker-compose.prod.yml down
   ```
2. Checkout the previous stable Git commit:
   ```bash
   git checkout <PREVIOUS_COMMIT_HASH>
   ```
3. Restore database snapshot:
   ```bash
   ./scripts/restore.sh backups/<STABLE_SNAPSHOT>.sql
   ```
4. Restart production stack:
   ```bash
   docker compose -f docker-compose.prod.yml up -d
   ```
