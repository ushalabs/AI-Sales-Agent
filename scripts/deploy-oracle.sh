#!/usr/bin/env bash
# ==============================================================================
# AI Sales Agent - Automated Deployment Script for Oracle Cloud ARM64 VM
# ==============================================================================
# Supported OS: Oracle Linux 8/9, Ubuntu 22.04/24.04 LTS (aarch64 / ARM64)
# ==============================================================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "=================================================================="
echo "    AI SALES AGENT - ORACLE CLOUD ARM64 PRODUCTION DEPLOYMENT    "
echo "=================================================================="

# 1. Environment File Check
ENV_PROD="$PROJECT_ROOT/.env.production"
if [ ! -f "$ENV_PROD" ]; then
    echo "ERROR: Production environment file .env.production was not found."
    echo "Please create it from .env.production.example:"
    echo "  cp .env.production.example .env.production"
    echo "  nano .env.production"
    exit 1
fi

# Load variables safely
# shellcheck disable=SC1090
source "$ENV_PROD"

if [ -z "$DOMAIN_NAME" ] || [ "$DOMAIN_NAME" == "agent.yourdomain.com" ]; then
    echo "ERROR: Please configure a real DOMAIN_NAME in .env.production"
    exit 1
fi

if [ -z "$N8N_ENCRYPTION_KEY" ] || [[ "$N8N_ENCRYPTION_KEY" == *"CHANGE_ME"* ]]; then
    echo "ERROR: Please set a secure N8N_ENCRYPTION_KEY in .env.production"
    exit 1
fi

# 2. Oracle Host Firewall (iptables / firewalld) Check
echo "[1/6] Configuring OS-level firewall for HTTP (80) & HTTPS (443)..."
if command -v firewall-cmd &>/dev/null; then
    echo "Configuring firewalld (Oracle Linux)..."
    sudo firewall-cmd --permanent --add-service=http 2>/dev/null || true
    sudo firewall-cmd --permanent --add-service=https 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
elif command -v iptables &>/dev/null; then
    echo "Configuring iptables rules..."
    sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
    sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
    if command -v netfilter-persistent &>/dev/null; then
        sudo netfilter-persistent save 2>/dev/null || true
    fi
fi

# 3. Pull Multi-Arch Container Images
echo "[2/6] Pulling ARM64 compatible Docker images..."
docker compose -f docker-compose.prod.yml --env-file "$ENV_PROD" pull

# 4. Start Production Containers
echo "[3/6] Starting production Docker Compose services..."
docker compose -f docker-compose.prod.yml --env-file "$ENV_PROD" up -d

# 5. Wait for Services to become Healthy
echo "[4/6] Waiting for PostgreSQL and n8n to become healthy..."
MAX_ATTEMPTS=30
ATTEMPT=0
until [ "$ATTEMPT" -ge "$MAX_ATTEMPTS" ]; do
    DB_STATUS=$(docker inspect --format='{{json .State.Health.Status}}' sales_agent_postgres_prod 2>/dev/null || echo "unhealthy")
    N8N_STATUS=$(docker inspect --format='{{json .State.Health.Status}}' sales_agent_n8n_prod 2>/dev/null || echo "unhealthy")
    
    if [[ "$DB_STATUS" == *"healthy"* ]] && [[ "$N8N_STATUS" == *"healthy"* ]]; then
        echo "PostgreSQL and n8n are healthy!"
        break
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
    echo "Waiting for services ($ATTEMPT/$MAX_ATTEMPTS)... DB: $DB_STATUS, n8n: $N8N_STATUS"
    sleep 5
done

if [ "$ATTEMPT" -ge "$MAX_ATTEMPTS" ]; then
    echo "ERROR: Services failed to report healthy within timeout."
    docker compose -f docker-compose.prod.yml ps
    exit 1
fi

# 6. Apply Database Schemas & Initial Knowledge Base
echo "[5/6] Applying database schemas and initial knowledge base..."
docker compose -f docker-compose.prod.yml exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$PROJECT_ROOT/scripts/init-db.sql"
docker compose -f docker-compose.prod.yml exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$PROJECT_ROOT/scripts/init-control-db.sql"
docker compose -f docker-compose.prod.yml exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$PROJECT_ROOT/scripts/init-knowledge-db.sql"

# 7. Import n8n Workflows
echo "[6/6] Importing production n8n workflows..."
for wf in "$PROJECT_ROOT"/workflows/*.json; do
    if [ -f "$wf" ] && [[ "$wf" != *"workflows_"* ]]; then
        echo "Importing: $(basename "$wf")"
        docker compose -f docker-compose.prod.yml cp "$wf" sales_agent_n8n_prod:/tmp/import_wf.json
        docker compose -f docker-compose.prod.yml exec -T -u node sales_agent_n8n_prod n8n import:workflow --input=/tmp/import_wf.json || true
        docker compose -f docker-compose.prod.yml exec -T -u node sales_agent_n8n_prod rm -f /tmp/import_wf.json || true
    fi
done

echo "=================================================================="
echo "    DEPLOYMENT COMPLETED SUCCESSFULLY!                           "
echo "=================================================================="
echo "Public Webhook URL: https://${DOMAIN_NAME}/webhook/telegram-business-sales-agent"
echo ""
echo "Secure Access to n8n Editor:"
echo "n8n port 5678 is NOT exposed publicly. To view or configure n8n:"
echo "  ssh -N -L 5678:localhost:5678 opc@<YOUR_ORACLE_IP>"
echo "Then open in your browser: http://localhost:5678"
echo "=================================================================="
