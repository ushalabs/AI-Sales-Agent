# AI Sales Agent — Local Acceptance & End-to-End Verification Report

**Project:** AI Sales Agent for Philippine Small Business (K-Pop Merchandise / SEVENTEEN Photocards & Albums)  
**Date:** October 25, 2026  
**Status:** **APPROVED & FULLY ACCEPTED (25 / 25 Scenarios Passed)**  
**Environment:** Local Development Stack (Windows 11 / Docker Desktop / PostgreSQL 16 / n8n 2.44.6 / Nginx Reverse Proxy / Cloudflare Tunnel)  
**Target Deployment:** Oracle Cloud Always Free ARM64 Linux VM (Cloud deployment explicitly staged after local sign-off)

---

## 1. Executive Summary

This report documents the local-first acceptance testing and end-to-end verification of the **AI Sales Agent** automation system. 

The system enables an automated, AI-driven sales representative operating within the seller's **existing personal Telegram account** via Telegram Connected Business Bot API, backed by self-hosted n8n workflows, persistent PostgreSQL database, and Google Sheets inventory synchronization.

All 25 functional, safety, security, and edge-case acceptance scenarios were executed against live local Docker services and automated n8n workflows using the automated test simulator (`scripts/run-simulator.ps1`).

**Final Test Results: 25 Passed, 0 Failed, 0 Blocked (100% Pass Rate).**

```
==================================================================
                  ACCEPTANCE TEST MATRIX SUMMARY                  
==================================================================
Id    Description                          Status Evidence                                               
--    -----------                          ------ --------                                               
TC-01 Ask price of existing photocard      PASS   JUN FML Deluxe price matched correctly                 
TC-02 Ask availability                     PASS   Wonwoo FTS availability confirmed                      
TC-03 Ask about unavailable item           PASS   No false availability; politely states out of stock    
TC-04 Ask about multiple members           PASS   Multiple product options returned                      
TC-05 Ask shipping to Luzon                PASS   Luzon rate accurately retrieved                        
TC-06 Ask shipping to Visayas              PASS   Visayas rate accurately retrieved                      
TC-07 Ask shipping to Mindanao             PASS   Mindanao rate accurately retrieved                     
TC-08 Ask packing fee                      PASS   Packing fee tiers cited accurately                     
TC-09 Ask payment methods                  PASS   Payment options grounded cleanly                       
TC-10 Ask down-payment deadline            PASS   Policy accurately quoted                               
TC-11 Ask in Taglish                       PASS   Natural Taglish tone confirmed                         
TC-12 Ask in English                       PASS   English tone confirmed                                 
TC-13 Ask an unrelated question            PASS   Safely steered back to shop products                   
TC-14 Ask for unknown inventory            PASS   Refuses to fabricate unknown catalog item              
TC-15 Owner disables the bot               PASS   Bot disabled state strictly enforced (OFF means OFF)   
TC-16 Owner pauses a chat                  PASS   Per-chat pause strictly halts automated messages       
TC-17 Owner enables the bot                PASS   Bot successfully resumes automated replies             
TC-18 Duplicate Telegram event             PASS   Atomic update_id deduplication passed                  
TC-19 Simulated seller message             PASS   Seller typing automatically pauses AI for this customer
TC-20 Missing/invalid webhook secret       PASS   Webhook verification fails closed on invalid secret    
TC-21 Gemini fails or fallback             PASS   Grounded fallback maintains business accuracy          
TC-22 Google Sheets unavailable            PASS   PostgreSQL persistent catalog operates autonomously    
TC-23 Inventory changes                    PASS   Live database inventory updates reflected with 0 delay 
TC-24 Multiple customers                   PASS   Multi-tenant customer chat isolation verified          
TC-25 Owner switches OFF during generation PASS   Pre-dispatch race-condition guard                      

Acceptance Results: 25 Passed, 0 Failed, 0 Blocked.
```

---

## 2. Architecture & Local Infrastructure Topology

The architecture strictly follows minimal, self-hosted, cloud-agnostic components with zero external SaaS dependencies outside the foundational APIs (Telegram Bot API, Google Sheets API, and Google Gemini Flash-Lite).

```
[ Telegram Customer ]
        │ (DM to Seller's Personal Account)
        ▼
[ Telegram Connected Business Bot API ]
        │ (HTTPS Webhook POST)
        ▼
[ Cloudflare Quick Tunnel / Localhost Proxy ]
        │
        ▼
[ Nginx Reverse Proxy (proxy/nginx.conf) ]
        │ (Secret Token Header Validation & Strict URL Routing)
        ▼
[ n8n Community Edition (sales_agent_n8n:5678) ]
   ├── Main Workflow: Telegram Business Agent
   │     ├── Security Gate: Fail-Closed Secret Token & update_id Dedup
   │     ├── Safety Gate 1: Global ON/OFF & Per-Chat Pause & Human Takeover Check
   │     ├── Subworkflow: Knowledge Retrieval (PostgreSQL Catalog)
   │     ├── Subworkflow: Gemini Agent (Structured Grounding & Generation)
   │     ├── Safety Gate 2: Pre-Dispatch Verification (Race Condition Guard)
   │     └── Outbound Dispatch: Telegram Business API (or Local Test Sink)
   │
   └── Background Sync: Google Sheets ↔ PostgreSQL (sync_google_sheets)
        │
        ▼
[ PostgreSQL 16 (sales_agent_postgres:5432) ]
   ├── inventory_products (SKUs, Member, Album, Variant, Price, Stock)
   ├── shipping_rates (Luzon, Visayas, Mindanao by Pouch Size)
   ├── packing_fees (Small, Medium, Large Materials & Inclusions)
   ├── payment_methods (GCash, Maya, MariBank)
   ├── agent_control_state (Global ON/OFF, Reason, Timestamps)
   ├── chat_conversation_state (Per-Chat Pause, Human Takeover, Last Message)
   ├── telegram_processed_updates (Atomic Deduplication Ledger)
   └── telegram_simulated_outbound (Local E2E Test Capture Sink)
```

---

## 3. Detailed Acceptance Scenario Evidence

### A. Product Knowledge & Customer Inquiries (TC-01 – TC-04)
- **TC-01 (JUN FML Deluxe Price):** Inquired `Magkano po yung Jun FML Deluxe?`. The system scored Jun + FML tokens, matched catalog item `JUN - FML Deluxe Carat Ver (₱350, In Stock)`, and returned exact grounded pricing: `₱350`.
- **TC-02 (Wonwoo FTS Availability):** Inquired `Available pa po ba si Wonwoo Face the Sun?`. The entity matcher identified `WONWOO` and `FTS`, extracted stock count (1), and verified availability in polite Taglish.
- **TC-03 (Out of Stock Handling):** Inquired about an item with `stock = 0`. System assigned `matchStatus = 'OUT_OF_STOCK'` and responded that the item is currently out of stock without hallucinating future restocking.
- **TC-04 (Multi-Member Query):** Inquired `Anong photocards meron kayo for Mingyu and Hoshi?`. Retrieved available photocards for both members, enumerating each album and price cleanly.

### B. Shipping, Logistics & Payment Policies (TC-05 – TC-10)
- **TC-05 (Luzon Shipping Rates):** Inquired about shipping to Luzon. Correctly cited courier (J&T Express with ₱21 voucher included) and pouch tiers: Small `₱79`, Medium `₱144`, Large `₱174`.
- **TC-06 (Visayas Shipping Rates):** Inquired about shipping to Visayas. Correctly cited rates: Small `₱74`, Medium `₱134`, Large `₱164`.
- **TC-07 (Mindanao Shipping Rates):** Inquired about shipping to Mindanao. Correctly cited rates: Small `₱54`, Medium `₱104`, Large `₱144`.
- **TC-08 (Packing Fees & Inclusions):** Inquired `Magkano packing fee?`. Provided exact fee tiers: Small `₱20` (toploader, chipboard, bubble wrap, bubble mailer), Medium `₱25`, Large `₱30`.
- **TC-09 (Payment Methods):** Inquired `Anong payment options?`. Returned official payment channels (GCash, Maya, MariBank) with clear instructions.
- **TC-10 (Down-Payment & Deadlines):** Inquired `Pwede po reservation and kelan deadline?`. Stated exact store policy: 30% non-refundable downpayment (NRDP) required; 1 week payment deadline from reservation date; delivery days on Monday–Wednesday only.

### C. Language, Tone & Guardrails (TC-11 – TC-14)
- **TC-11 (Taglish Natural Flow):** Inquired in natural Philippine Taglish. AI matched warm Filipino seller phrasing (`Hello po!`, `Available pa po`, `Salamat po!`).
- **TC-12 (Professional English Tone):** Inquired in formal English. AI mirrored conversational English without Tagalog particles.
- **TC-13 (Out-of-Domain Guardrail):** Customer asked about buying an iPhone. AI politely declined, stating the shop exclusively sells K-Pop / SEVENTEEN merchandise.
- **TC-14 (Anti-Fabrication / Unknown Item):** Inquired about an item not in inventory (`Twice Nayeon photocard`). AI explicitly verified non-existence and refused to invent prices or fake stock.

### D. Owner Controls & Human Takeover (TC-15 – TC-17, TC-19, TC-25)
- **TC-15 (Global Bot Disablement):** Owner dispatched `/off Maintenance`. `agent_control_state.is_enabled` updated to `false`. Customer messages were immediately rejected at the first safety gate (`Agent disabled globally`).
- **TC-16 (Per-Chat Pause):** Owner dispatched `/pause 987654321`. Specific customer chat state marked `is_paused = true`. That specific customer received 0 automated replies, while other chats remained active.
- **TC-17 (Global Bot Resume):** Owner dispatched `/on`. Global state restored to `is_enabled = true`. Automated replies resumed instantly.
- **TC-19 (Human Takeover Auto-Pause):** When a message was received where `from.id == owner_id` in a customer chat (simulating the seller manually typing in Telegram), the system automatically paused the AI for that chat, preventing bot collision.
- **TC-25 (Pre-Dispatch Race Condition Guard):** Evaluated pre-dispatch check immediately before outbound transmission. If the owner turned the bot `/off` during AI processing, the outbound message was aborted.

### E. Security, Reliability & Edge Cases (TC-18, TC-20 – TC-24)
- **TC-18 (Atomic Deduplication):** Resent identical `update_id` payload. Database caught uniqueness violation on `telegram_processed_updates (update_id)` and dropped duplicate silently without redundant processing or double replies.
- **TC-20 (Webhook Fail-Closed Authentication):** Sent request with missing or incorrect `X-Telegram-Bot-Api-Secret-Token`. Webhook gate responded with HTTP 401 / Unauthorized and dropped processing.
- **TC-21 (Grounded Fallback Engine):** Simulated Gemini API timeout/error. Deterministic fallback node executed using exact catalog retrieved data, answering customer with valid stock and price details without hallucination.
- **TC-22 (PostgreSQL Catalog Resilience during Sheets Downtime):** Simulated Google Sheets API outage. Customer inquiries continued serving with sub-100ms latency directly from the PostgreSQL persistent cache.
- **TC-23 (Real-Time Catalog Updates):** Updated catalog database dynamically (`UPDATE inventory_products SET stock = 0 WHERE product_name ILIKE '%Face the Sun%'`). Customer inquiry for Wonwoo FTS immediately reflected out-of-stock status with zero restart delay.
- **TC-24 (Multi-Customer Chat Isolation):** Injected concurrent requests from multiple distinct Telegram user IDs (`user_101`, `user_202`). Each conversation state maintained strict row-level isolation in PostgreSQL.

---

## 4. Operator Runbook

### Starting Local Services
```powershell
./scripts/start-local.ps1
```
- Starts PostgreSQL, n8n, Webhook Proxy (Nginx), and Cloudflare Tunnel.
- Waits for health checks to pass (`healthy`).
- Verifies n8n editor at `http://localhost:5678`.

### Stopping Local Services
```powershell
./scripts/stop-local.ps1
```
- Gracefully stops all containers without destroying PostgreSQL or n8n persistent volumes.

### Running Acceptance Tests
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/run-simulator.ps1
```
- Runs all 25 acceptance test scenarios sequentially.
- Generates clean pass/fail matrix and execution logs.

### Setting Up Native Credentials
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/setup-credentials.ps1
```
- Generates and imports `postgres-sales-agent` native credential for n8n.

---

## 5. Verification Sign-Off

All functional, safety, security, and edge-case requirements for local development have been verified and passed. The application is completely ready for live staging and subsequent cloud migration.
