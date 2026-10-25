# AI Sales Agent

> **Autonomous AI Sales Assistant for Telegram Connected Business Accounts, powered by n8n, Google Gemini 3.5 Flash-Lite, and PostgreSQL.**

[![n8n Community](https://img.shields.io/badge/n8n-2.44.6-EA4B71?logo=n8n&logoColor=white)](https://n8n.io)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Google Gemini](https://img.shields.io/badge/Gemini-3.5--Flash--Lite-4285F4?logo=google&logoColor=white)](https://ai.google.dev/)
[![Docker](https://img.shields.io/badge/Docker-ARM64%20%7C%20AMD64-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Overview

The **AI Sales Agent** enables small businesses to automate customer inquiries directly within their **existing personal Telegram account** via the **Telegram Connected Business Bot** API. Customers chat directly with the seller's account—never an impersonal bot handle—while the agent provides instant, verified stock, pricing, shipping, and payment information in polite Filipino Taglish.

### Key Capabilities

- **Direct DM Operation**: Uses Telegram Business connections to read and reply on behalf of the seller in the customer's personal DM thread.
- **Zero-Hallucination Catalog Engine**: Real-time product retrieval and fuzzy matching across 69 items and 13 members in PostgreSQL, strictly quoting Philippine Pesos (`₱`).
- **Grounded AI Conversations**: Powered by **Gemini 3.5 Flash-Lite** with strict safety boundaries, packaging fee tiers, shipping rate math, and automated disclosure tags.
- **Human Takeover & Control**: Automatically pauses AI when the seller sends a manual message in a customer DM. Full seller control via `/on`, `/off`, `/status`, and `/pause` commands.
- **Production Hardening**: Reverse proxy routing that protects the n8n admin UI with HTTP 403, atomic update deduplication in PostgreSQL, and infinite loop suppression.

---

## Architecture

```mermaid
flowchart LR
    Customer([Customer]) <-->|Personal DM| SellerTG([Seller Telegram Account])
    SellerTG <-->|Telegram Business API| Proxy[Reverse Proxy]
    
    subgraph Core [n8n Automation Engine]
        Proxy -->|/webhook/* only| Master[Master Orchestrator]
        Master <--> Dedupe[(PostgreSQL 16)]
        Master --> Controls[Owner Controls]
        Master --> Catalog[Knowledge Engine]
        Master --> Gemini[Gemini 3.5 Flash-Lite]
    end

    Gemini --> Master
    Master -->|Reply on behalf of seller| SellerTG
```

---

## Owner Control Panel & Commands

The seller manages the bot directly through a private conversation with `@sashtt_bot`.

### Native Telegram Inline Keyboard Buttons
When the seller opens the control panel via `/status`, `/panel`, or `/start`, the bot renders interactive inline buttons:
- `[ 🟢 Turn ON ]` / `[ 🔴 Turn OFF ]` — Instantly toggle automated customer replies globally.
- `[ 📊 Refresh Status ]` — Update live control panel status and active catalog metrics.
- `[ ⏸️ Paused Chats ]` — Review all chats currently paused under human takeover.
- `[ ▶️ Resume Customer <chat_id> ]` — Dynamic one-click button to resume automated AI replies for specific customers.

### Text Commands & Human Takeover Lifecycle
| Command / Action | Scope | Description |
| :--- | :--- | :--- |
| `/status` / `/panel` | Global | Opens or refreshes the interactive Control Panel with status buttons. |
| `/on` | Global | Enables automated replies for incoming inquiries. |
| `/off` | Global | Instantly disables automated replies. |
| `/pause [chat_id]` | Per-Chat | Mutes AI for a specific customer without affecting other chats. |
| `/resume [chat_id]`| Per-Chat | Unmutes AI for a specific customer. |
| *Seller Manual Typing* | Per-Chat | **Human Takeover**: If the seller sends a manual DM to a customer, AI automatically pauses for that chat. The seller can resume the customer at any time via the Control Panel button or `/resume`. |

---

## Quickstart (Local Development)

### Prerequisites
- [Docker Desktop](https://www.docker.com/) (running on Windows, macOS, or Linux)
- Git and PowerShell 5.1+ (Windows) or Bash (macOS/Linux)

### 1. Initialize Configuration
```bash
cp .env.example .env
```
Fill in `.env`:
- `TELEGRAM_BOT_TOKEN`: From `@BotFather`
- `TELEGRAM_SELLER_USER_ID`: Numeric Telegram ID
- `GEMINI_API_KEY`: From Google AI Studio
- `GEMINI_MODEL`: `gemini-3.5-flash-lite`

### 2. Start Services & Setup Credentials
```powershell
# Start PostgreSQL, n8n, Nginx proxy, and Cloudflare Tunnel
powershell -ExecutionPolicy Bypass -File ./scripts/start-local.ps1

# Import native PostgreSQL credentials into n8n
powershell -ExecutionPolicy Bypass -File ./scripts/setup-credentials.ps1
```

### 3. Run Acceptance Test Suite (25 Scenarios)
```powershell
# Execute complete local simulator acceptance test suite
powershell -ExecutionPolicy Bypass -File ./scripts/run-simulator.ps1
```
All 25 scenarios (product search, stock validation, shipping & packing rates, payment policies, language & tone matching, owner `/on`/`/off`/`/pause` controls, human takeover auto-pause, webhook token verification, and fail-safe fallback) are verified automatically. See the full audit report in [**`docs/LOCAL_ACCEPTANCE_REPORT.md`**](docs/LOCAL_ACCEPTANCE_REPORT.md).

### 4. Stop Services Gracefully
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/stop-local.ps1
```

---

## Production Deployment

The project includes ready-to-run configurations for **Oracle Cloud Always Free ARM64** instances (`VM.Standard.A1.Flex`):

- **Automated TLS**: Caddy reverse proxy handles automated Let's Encrypt certificates.
- **Security**: n8n admin port `5678` is bound to `127.0.0.1` and accessed privately via SSH tunnel (`ssh -N -L 5678:localhost:5678 user@ip`).
- **One-Click Deploy**: Run `./scripts/deploy-oracle.sh`.

See the complete production setup guide in [**`DEPLOYMENT.md`**](DEPLOYMENT.md).

---

## Verification & Testing Matrix

| Test Suite | Scope | Status | Details |
| :--- | :--- | :---: | :--- |
| **Local Acceptance (E2E)** | 25 Automated Simulator Scenarios | `PASS (25/25)` | 100% pass rate across catalog, safety gates, owner controls & policies |
| **Phase 3** | Docker Infrastructure & PostgreSQL | `PASS` | Healthy containers with persistent volumes |
| **Phase 4** | Webhook Proxy Security | `PASS` | `/webhook/*` routed; admin endpoints return 403 |
| **Phase 5** | Knowledge Base Retrieval | `PASS` | 6/6 tests passed (exact match, aliases, typos, OOS) |
| **Phase 6** | Gemini 3.5 Sales Dialogue | `PASS` | 5/5 multi-turn scenarios passed with zero hallucination |
| **Phase 7** | Owner Controls & Human Takeover | `PASS` | 6/6 tests passed (`/on`, `/off`, `/pause`, manual typing) |
| **Phase 8** | Reliability & Deduplication | `PASS` | Atomic database constraint & loop prevention |

---

## Backup & Maintenance

- **Create Backup**: `./scripts/backup.sh` (or `.\scripts\backup.ps1`)
- **Restore Database**: `./scripts/restore.sh backups/<backup_file>.sql`
- **View Logs**: `docker compose logs -f n8n`

---

## License

This project is licensed under the MIT License.
