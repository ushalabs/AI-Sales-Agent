# AI Sales Agent — Telegram Business + n8n + Gemini + Google Sheets

[![n8n Community](https://img.shields.io/badge/n8n-2.44.6-EA4B71?logo=n8n)](https://n8n.io)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16--alpine-336791?logo=postgresql)](https://www.postgresql.org/)
[![Google Gemini](https://img.shields.io/badge/Gemini-2.5--Flash--Lite-8E75B2?logo=google)](https://ai.google.dev/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://www.docker.com/)
[![Architecture](https://img.shields.io/badge/Arch-ARM64%20%7C%20AMD64-0078D4)](DEPLOYMENT.md)

An enterprise-grade, privacy-respecting AI Sales Agent designed for a Philippine small business selling K-pop merchandise (SEVENTEEN photocards and albums). 

The agent operates directly inside the seller's **existing personal Telegram account** via the **Telegram Connected Business Bot** API. Customers never interact with an impersonal public bot handle; every verified, polite, Taglish response is posted seamlessly inside the seller's personal direct message thread.

---

## 1. System Architecture

```mermaid
flowchart TD
    Customer([Customer]) <-->|Direct Message| SellerTG([Seller Personal Telegram DM])
    SellerTG <-->|Telegram Business Connection| TGServer[Telegram Bot API]

    subgraph Infrastructure [Self-Hosted Production Stack]
        subgraph Ingress [Reverse Proxy & Security Filtering]
            Proxy[Nginx / Caddy Proxy]
        end

        subgraph Core [n8n Automation Engine]
            MasterWF[Master Workflow: telegram_business_agent]
            OwnerWF[Subworkflow: Owner Controls & Takeover]
            KnowledgeWF[Subworkflow: Knowledge Retrieval]
            GeminiWF[Subworkflow: Gemini Sales Agent]
        end

        subgraph Storage [PostgreSQL 16 Engine]
            DB[(PostgreSQL Database)]
        end
    end

    TGServer -->|HTTPS Webhook + Secret Token| Proxy
    Proxy -->|Allowed: /webhook/* only (Admin 403)| MasterWF
    MasterWF <-->|Atomic Deduplication| DB
    MasterWF -->|Check Owner Command or Takeover| OwnerWF
    OwnerWF <-->|Read / Write State| DB
    MasterWF -->|Query Products / Rates / Policies| KnowledgeWF
    KnowledgeWF <-->|Structured Fuzzy Match| DB
    MasterWF -->|Grounded Prompt + Context| GeminiWF
    GeminiWF -->|Grounded Taglish Response| MasterWF
    MasterWF -->|Reply via business_connection_id| TGServer
```

### Complete Inbound Message Lifecycle

```
[Customer DM in Telegram]
         │
         ▼
[Telegram Bot API: business_message]
         │ (HTTPS POST + X-Telegram-Bot-Api-Secret-Token)
         ▼
[Caddy / Nginx Reverse Proxy]
         │ (Blocks /admin paths; passes /webhook/* only)
         ▼
[telegram_business_agent (Master)]
         │
         ├──> [1. Deduplication Check] ──> Duplicate update_id? ──> [Stop / Discard]
         │
         ├──> [2. Outgoing Loop Check] ──> From seller ID? ──> [Record Human Takeover & Pause Chat]
         │
         ├──> [3. Global Switch Check] ──> agent_control_state.is_enabled == false? ──> [Stop]
         │
         ├──> [4. Chat Pause Check]   ──> chat_conversation_state.is_paused == true? ──> [Stop]
         │
         ├──> [5. Knowledge Engine]   ──> Query 69 products, shipping, packing, and payment rules
         │
         ├──> [6. Gemini 2.5 Flash]   ──> Draft polite Taglish response with automated disclosure
         │
         ▼
[Telegram API: sendMessage on behalf of seller]
         │
         ▼
[Reply appears in customer's personal DM thread]
```

---

## 2. Repository Layout

```
.
├── .env.example                       # Local development environment template
├── .env.production.example            # Production environment template (Oracle ARM64)
├── .gitignore                         # Strict exclusion for secrets, dumps, and credentials
├── DEPLOYMENT.md                      # Oracle Cloud Always Free ARM64 deployment guide
├── Product Info.csv                   # Reference product sheet
├── README.md                          # Master documentation and operations manual
├── docker-compose.yml                 # Local development multi-container orchestration
├── docker-compose.prod.yml            # Production container orchestration (Caddy + n8n + PG)
├── backups/                           # Automated database and workflow backups
├── data/
│   └── knowledge_base.json            # Parsed 69-product fixture, shipping rates, and policies
├── proxy/
│   ├── Caddyfile.prod                 # Production Caddy config (Automated TLS + path filter)
│   ├── nginx.conf                     # Local development Nginx reverse proxy
│   └── nginx.prod.conf                # Production Nginx reverse proxy alternative
├── scripts/
│   ├── backup.ps1 / .sh               # Database dump and workflow exporter
│   ├── deploy-oracle.sh               # One-click Oracle Cloud ARM64 deployment script
│   ├── import-workflow.ps1 / .sh      # Workflow importer
│   ├── init-control-db.sql            # State schema (global toggle and per-chat pause)
│   ├── init-db.sql                    # Core schema (deduplication and business connection)
│   ├── init-env.ps1                   # Environment generator
│   ├── init-knowledge-db.sql          # Product catalog and rates database schema
│   ├── register-webhook.ps1 / .sh     # Webhook registration with Telegram API
│   ├── restore.ps1 / .sh              # Database and workflow restoration script
│   ├── start-tunnel.ps1 / .sh         # Cloudflare Quick Tunnel manager
│   ├── sync-knowledge.ps1             # Synchronizes Google Sheets / fixtures to Postgres
│   ├── test-acceptance-suite.ps1      # Phase 10 master acceptance test suite
│   ├── test-phase5.ps1                # Knowledge base retrieval test suite
│   ├── test-phase6.ps1                # Gemini AI sales dialogue simulation suite
│   ├── test-phase7.ps1                # Owner controls and human takeover test suite
│   ├── test-phase8.ps1                # Reliability, deduplication, and safety test suite
│   ├── verify-oracle-connectivity.sh  # Production outbound API connectivity verifier
│   ├── verify-phase3.ps1              # Infrastructure health verification
│   └── verify-phase4.ps1              # Telegram integration verification
└── workflows/
    ├── README.md                      # Detailed workflow architecture and IDs
    ├── simulated_customer_test.json   # Simulation test harness
    ├── subworkflow_gemini_agent.json  # Grounded Gemini prompt and persona
    ├── subworkflow_knowledge_retrieval.json # PostgreSQL catalog lookup
    ├── subworkflow_owner_controls.json# Commands and human takeover router
    └── telegram_business_agent.json   # Master orchestrator workflow
```

---

## 3. Owner Operations & Control Commands

The seller controls the AI assistant at any time by sending commands directly to their Telegram bot or typing inside the customer DM.

| Command | Action | Scope | Description |
| :--- | :--- | :--- | :--- |
| `/status` | View Status | Global | Reports AI status (`ON`/`OFF`), active paused chats, and total inventory products. |
| `/on` | Enable AI | Global | Activates automated responses for authorized customer inquiries. |
| `/off` | Disable AI | Global | Instantly disables all automated customer replies. |
| `/pause [chat_id]` | Pause Chat | Per-Chat | Silences AI for a specific customer without affecting other chats. |
| `/resume [chat_id]`| Resume Chat | Per-Chat | Unpauses AI for that customer. |
| *Manual Seller Typing* | Human Takeover | Per-Chat | When the seller sends any message in a customer DM, the system **automatically pauses** the AI for that chat. |

---

## 4. Business Knowledge & Shop Policies

All pricing and answers adhere strictly to the shop's verified catalog and policies:

- **Currency**: Philippine Pesos (`₱` / `PHP`) default on all items.
- **Product Catalog**: 69 authentic items across 13 SEVENTEEN members (S.Coups, Jeonghan, Joshua, Jun, Hoshi, Wonwoo, Woozi, DK, Mingyu, The8, Seungkwan, Vernon, Dino).
- **Courier & Shipping Rates**: J&T Express only.
  - Metro Manila: ₱74 (₱95 standard minus ₱21 shop voucher).
  - Luzon: ₱99 (₱120 standard minus ₱21 shop voucher).
  - Visayas: ₱114 (₱135 standard minus ₱21 shop voucher).
  - Mindanao: ₱124 (₱145 standard minus ₱21 shop voucher).
  - Island: ₱134 (₱155 standard minus ₱21 shop voucher).
- **Packing Fees (PF)**:
  - Small pouch / box: ₱20
  - Medium pouch / box: ₱25
  - Large box: ₱30
- **Dispatch Days**: Strictly **Monday to Wednesday only**.
- **Payment Methods**:
  - GCash: `09976111139` (Account: `F. M. A.`)
  - Maya: `09976111139` (Account: `F. M. A.`)
  - MariBank: `13296983960` (Account: `F. M. A.`)
- **Payment Terms**: 1 week payment deadline with an initial **30% non-refundable downpayment**.

---

## 5. Local Development Quickstart

### Prerequisites
- Docker Desktop running on Windows, macOS, or Linux.
- PowerShell 5.1+ (Windows) or Bash (macOS/Linux).

### Step 1: Initialize Configuration
```powershell
./scripts/init-env.ps1
```
Edit `.env` with your `TELEGRAM_BOT_TOKEN`, `TELEGRAM_SELLER_USER_ID`, and `GEMINI_API_KEY`.

### Step 2: Start Containers & Apply Database Schemas
```powershell
docker compose up -d
./scripts/sync-knowledge.ps1
```

### Step 3: Run Acceptance Test Suite
```powershell
./scripts/test-acceptance-suite.ps1
```
Expected output:
```
[PASS] Phase 3 - PostgreSQL Container Health
[PASS] Phase 3 - n8n Container Health
[PASS] Phase 4 - Nginx Webhook Proxy
[PASS] Phase 4 - Admin Route Public Block
[PASS] Phase 5 - Knowledge Base and Match Engine
[PASS] Phase 6 - Gemini Sales Dialogue and Policies
[PASS] Phase 7 - Owner Commands and Human Takeover
[PASS] Phase 8 - Deduplication and Safety Gates
Results: 8 Passed, 0 Failed.
```

---

## 6. Production Deployment (Oracle Cloud ARM64)

Complete step-by-step production instructions are detailed in [`DEPLOYMENT.md`](DEPLOYMENT.md).

### Quick Deployment Summary:
1. Provision an **Oracle Cloud Always Free Ampere A1 VM** (ARM64, Ubuntu 24.04).
2. Open ports `80` and `443` in OCI Security Lists and host `iptables`.
3. Point your DNS A record (e.g. `agent.yourdomain.com`) to the reserved public IP.
4. Clone the repository and configure `.env.production`.
5. Run the deployment script:
   ```bash
   ./scripts/deploy-oracle.sh
   ```
6. Access n8n securely via SSH tunnel:
   ```bash
   ssh -N -L 5678:localhost:5678 ubuntu@<YOUR_ORACLE_IP>
   ```
   Open `http://localhost:5678` in your workstation browser to configure credentials.

---

## 7. Production Acceptance Matrix

| Requirement / Test | Verification Type | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Container & DB Health** | Automated Script | **PASS (Locally Verified)** | Postgres 16 and n8n healthy on persistent volumes |
| **Admin Route Protection** | Automated Script | **PASS (Locally Verified)** | Reverse proxy strictly blocks `/` with 403 Forbidden |
| **Catalog Exact Match** | Unit & Integration | **PASS (Locally Verified)** | S.Coups, Mingyu, Wonwoo, Dino items retrieved accurately |
| **Alias & Typo Match** | Unit & Integration | **PASS (Locally Verified)** | Matches *Cheol*, *Hao*, *Dokyeom*, and spelling variations |
| **Out-of-Stock Handling** | Unit & Integration | **PASS (Locally Verified)** | Clearly states OOS and suggests in-stock member variants |
| **Shipping & Packing Math** | Unit & Integration | **PASS (Locally Verified)** | Quotes J&T rates (-₱21 voucher) + tiered packing fee |
| **Payment Method Grounding** | Unit & Integration | **PASS (Locally Verified)** | Only cites GCash, Maya, MariBank (F. M. A.) with 30% DP |
| **Automated Disclosure** | Unit & Integration | **PASS (Locally Verified)** | Replies carry `[Automated Response: Shop AI Assistant]` |
| **Global `/on` and `/off`** | Unit & Integration | **PASS (Locally Verified)** | Global gate rejects messages when `is_enabled=false` |
| **Per-Chat `/pause`** | Unit & Integration | **PASS (Locally Verified)** | Selective silencing by chat ID |
| **Human Takeover** | Unit & Integration | **PASS (Locally Verified)** | Seller replying in customer DM auto-pauses AI for that chat |
| **Atomic Deduplication** | Unit & Integration | **PASS (Locally Verified)** | Re-sent update IDs discarded via PostgreSQL constraint |
| **Loop Prevention** | Unit & Integration | **PASS (Locally Verified)** | Seller messages dropped to avoid infinite reply loops |
| **ARM64 Compatibility** | Config Validation | **PASS (Locally Verified)** | All images validated for `linux/arm64` |
| **Live Telegram DM Reply** | Live Network | **DEFERRED** | Blocked on local ISP; verified via mock fixtures; runs on Oracle |
| **Live Google Sheets OAuth** | OAuth Flow | **DEFERRED** | Offline PostgreSQL fixture populated; live OAuth ready on Oracle |

---

## 8. Troubleshooting & Maintenance

### Logs
To view container logs:
```bash
docker compose logs -f n8n
docker compose logs -f postgres
```

### Backups
Run a manual backup at any time:
```bash
./scripts/backup.sh
# or on Windows:
./scripts/backup.ps1
```
Backups are archived in the `backups/` directory.

### Restoring Backups
```bash
./scripts/restore.sh backups/n8n_db_YYYYMMDD_HHMMSS.sql
# or on Windows:
./scripts/restore.ps1 -BackupFile backups\n8n_db_YYYYMMDD_HHMMSS.sql
```
