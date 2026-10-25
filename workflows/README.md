# n8n Production Workflows

This directory contains version-controlled, sanitized JSON exports of all n8n workflows powering the **AI Sales Agent**.

---

## Workflow Inventory & Architecture

```
                                [ Incoming Telegram Business Update ]
                                                 │
                                                 ▼
                             ┌───────────────────────────────────────┐
                             │    telegram_business_agent.json       │
                             │         (Master Orchestrator)         │
                             └───────────────────┬───────────────────┘
                                                 │
                   ┌─────────────────────────────┼─────────────────────────────┐
                   │                             │                             │
                   ▼                             ▼                             ▼
       ┌───────────────────────┐     ┌───────────────────────┐     ┌───────────────────────┐
       │ subworkflow_owner_    │     │ subworkflow_knowledge_│     │ subworkflow_gemini_   │
       │ controls.json         │     │ retrieval.json        │     │ agent.json            │
       │                       │     │                       │     │                       │
       │ • /on, /off, /status  │     │ • 69 SEVENTEEN items  │     │ • Gemini 2.5 Flash-   │
       │ • /pause, /resume     │     │ • SF & PF Rates       │     │   Lite via HTTP       │
       │ • Human takeover      │     │ • Payment Methods     │     │ • Grounded Taglish    │
       │   detection           │     │ • Fuzzy matching      │     │ • Safety guardrails   │
       └───────────────────────┘     └───────────────────────┘     └───────────────────────┘
```

### 1. `telegram_business_agent.json` (Master Orchestrator)
- **Workflow ID**: `ktvkVp0E0z2blc4n`
- **Trigger**: Webhook `/webhook/telegram-business-sales-agent` (POST)
- **Role**:
  - Verifies `X-Telegram-Bot-Api-Secret-Token` header.
  - Normalizes Telegram update payload (`business_connection_id`, `chat_id`, `message_id`, `text`).
  - Performs atomic update deduplication via PostgreSQL (`telegram_processed_updates`).
  - Dispatches to `subworkflow_owner_controls` for seller commands or human takeover detection.
  - Calls `subworkflow_knowledge_retrieval` to obtain verified catalog details.
  - Invokes `subworkflow_gemini_agent` to draft grounded responses.
  - Sends final replies through Telegram Business connection (`business_connection_id`).

### 2. `subworkflow_knowledge_retrieval.json` (Knowledge Retrieval Engine)
- **Workflow ID**: `0cGbWSPG0Z14h3So`
- **Role**:
  - Matches customer queries against 69 products across 13 SEVENTEEN members.
  - Queries `inventory_products`, `shipping_rates`, `packing_fees`, and `payment_methods`.
  - Normalizes aliases (e.g., *Cheol* $\rightarrow$ *S.Coups*, *Hao* $\rightarrow$ *The8*, *Kwan* $\rightarrow$ *Seungkwan*).
  - Handles typos, fuzzy matches, and out-of-stock items without hallucinating.

### 3. `subworkflow_gemini_agent.json` (Grounded AI Sales Agent)
- **Workflow ID**: `wMZ3vsdPji1oSAr0`
- **Role**:
  - Direct HTTP calls to Google Gemini (`gemini-2.5-flash-lite`).
  - Adheres strictly to retrieved product attributes, shop policies, and packing fees.
  - Discloses automated status: `[Automated Response: Shop AI Assistant]`.
  - Taglish polite persona with deterministic fallback if API is unavailable.

### 4. `subworkflow_owner_controls.json` (Owner Control Router & Takeover)
- **Workflow ID**: `GzGhjXdy38xmzByE`
- **Role**:
  - Handles seller commands: `/on`, `/off`, `/status`, `/pause <chat_id>`, `/resume <chat_id>`.
  - Detects seller replies in active customer DMs and pauses the AI for that chat automatically.

### 5. `simulated_customer_test.json` (Integration Test Harness)
- **Workflow ID**: `SvR0dvQXJSh53R4M`
- **Role**:
  - Standalone testing workflow executing 5 customer scenarios without needing external Telegram API connectivity.

---

## Workflow Export & Import

### Automated Backup & Export:
```powershell
./scripts/backup.ps1
```
or on Linux:
```bash
./scripts/backup.sh
```

### Manual Workflow Import into Docker Container:
```bash
docker compose exec -u node n8n n8n import:workflow --input=/tmp/your_workflow.json
```
