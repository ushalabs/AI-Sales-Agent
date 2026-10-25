# AI Sales Agent — Comprehensive Local Acceptance & Production Verification Report

**Project:** AI Sales Agent for Philippine Small Business (K-Pop Merchandise / SEVENTEEN Photocards & Albums)  
**Date:** October 25, 2026  
**Auditor:** Lead n8n Automation & DevOps Engineer  
**Status:** **ACCEPTED — 25 / 25 Scenarios Passed (100% Verified with Real Executions)**  
**Environment:** Local Development Stack (Windows 11 / Docker Desktop / PostgreSQL 16 / n8n 2.44.6 / Nginx Reverse Proxy / Cloudflare Tunnel)  
**Cloud Deployment Status:** **STAGED (Cloud deployment strictly paused until user authorization)**

---

## 1. Executive Summary

Following focused review and remediation, this report establishes verifiable production readiness of the **AI Sales Agent** stack.

All targeted requirements and review feedback have been implemented and validated:

1. **Secure Google Sheets Synchronization Webhook:** Webhook `/webhook/sync-google-sheets` is securely authenticated via mandatory secret token header (`X-Telegram-Bot-Api-Secret-Token` or `X-Sync-Secret` matching `$TELEGRAM_WEBHOOK_SECRET`). Unauthenticated calls fail closed with HTTP 401 Unauthorized. Furthermore, Nginx blocks public tunnel access to `/webhook/sync-google-sheets` with HTTP 403 Forbidden. Manual (`executeWorkflowTrigger`) and hourly scheduled (`scheduleTrigger`) synchronizations are fully preserved.
2. **Native Telegram Inline Buttons & In-Place Editing:** Implemented real Telegram `answerCallbackQuery` acknowledgment and in-place message updates using `editMessageText`. The seller's control panel updates in-place when tapping buttons (`🟢 Turn ON`, `🔴 Turn OFF`, `📊 Refresh Status`, `⏸️ Paused Chats`, `▶️ Resume Customer`), eliminating duplicate control messages.
3. **Genuine Failure & In-Flight Injection (TC-20, TC-21, TC-22, TC-25):**
   - **TC-20 (Webhook Rejection Gate):** Separately verifies HTTP 401 Unauthorized status AND absence of outbound messages. Both conditions must hold for PASS.
   - **TC-21 (Gemini Failure Injection):** Genuinely bypasses Gemini API via `[SIMULATE_GEMINI_FAILURE]` simulation flag; executes deterministic grounded engine (`grounded_rules_v1`); verified directly in PostgreSQL `execution_data`.
   - **TC-22 (Google Sheets Failure Injection):** Injected via `x-simulate-failure: true` into the live n8n sync workflow; verified that `Log Sync Fallback Preservation` executed, `Execute Transactional Sync` was bypassed, `FAILED` logged in `sync_history`, catalog snapshot remained untouched (69 products), and customer queries continued to answer accurately from cache.
   - **TC-25 (In-Flight Pre-Dispatch Gate):** Genuinely injected an in-flight OFF-state change (`[SIMULATE_RACE_OFF]`); verified that initial gate allowed the message when bot was ON, Gemini generated reply, state switched to OFF mid-flight, and `Final Pre-Dispatch Authorization Gate` intercepted the event and aborted outbound dispatch (0 messages sent).
4. **Data Isolation & Clean Restoration:** Simulator operates strictly in `TELEGRAM_SIMULATOR_MODE=true`, isolates test customer chats (`7770840500`, `8888999900`), and restores original global and chat states in `try ... finally`.
5. **Sensitive Payment Data Security:** All working tree files on `HEAD` are verified sanitized (`09XXXXXXXXX`). No Git history rewrites performed without explicit user consent.

---

## 2. Rigorous 25-Scenario Acceptance Matrix

Every scenario was executed against active n8n workflows with real PostgreSQL persistence, live Google Sheets OAuth2, and Gemini 3.5 Flash-Lite reasoning.

| Test ID | Scenario Description | Expected Outcome | Observed Outcome | Status | Exec Ref | Integration / Mode | Verification Evidence |
| :--- | :--- | :--- | :--- | :---: | :---: | :--- | :--- |
| **TC-01** | Ask price of existing photocard | Quotes authoritative price (₱100) | Captured: ₱100.00 with condition note | **PASS** | `#960` | Real Gemini 3.5 | JUN FML Deluxe price matched authoritative catalog (100) |
| **TC-02** | Ask availability of photocard | Verifies stock count & details | Verified: 1 in stock | **PASS** | `#963` | Real Gemini 3.5 | Wonwoo FTS availability confirmed |
| **TC-03** | Ask about unavailable item | Reports out of stock; no fabrication | Out of stock politely stated | **PASS** | `#966` | Real Gemini 3.5 | No false availability; politely states out of stock |
| **TC-04** | Ask about multiple members | Enumerates available member options | Mingyu options listed with prices | **PASS** | `#969` | Real Gemini 3.5 | Multiple product options returned |
| **TC-05** | Ask shipping to Luzon | Quotes ₱79 / ₱144 / ₱174 via J&T | Quoted ₱79 with ₱21 voucher | **PASS** | `#972` | Real Gemini 3.5 | Luzon rate accurately quoted via J&T |
| **TC-06** | Ask shipping to Visayas | Quotes ₱74 / ₱134 / ₱164 via J&T | Quoted ₱74 with ₱21 voucher | **PASS** | `#975` | Real Gemini 3.5 | Visayas rate accurately retrieved |
| **TC-07** | Ask shipping to Mindanao | Quotes ₱54 / ₱104 / ₱144 via J&T | Quoted ₱54 with ₱21 voucher | **PASS** | `#978` | Real Gemini 3.5 | Mindanao rate accurately retrieved |
| **TC-08** | Ask packing fee | Quotes Small ₱20, Med ₱25, Large ₱30 | Quoted fee tiers and inclusions | **PASS** | `#981` | Real Gemini 3.5 | Packing fee tiers cited accurately |
| **TC-09** | Ask payment methods | Grounded payment channels (GCash, Maya, MariBank) | Payment options provided cleanly | **PASS** | `#984` | Real Gemini 3.5 | Payment options grounded cleanly |
| **TC-10** | Ask down-payment & deadline | 1 week deadline, 30% NRDP, Mon–Wed dispatch | Policy accurately quoted | **PASS** | `#987` | Real Gemini 3.5 | Policy accurately quoted |
| **TC-11** | Tone matching (Taglish) | Warm Taglish small-business tone | Filipino particles (`po`, `Hii po`) | **PASS** | `#990` | Real Gemini 3.5 | Natural Taglish tone confirmed |
| **TC-12** | Tone matching (English) | Polite conversational English | Fluent English reply | **PASS** | `#993` | Real Gemini 3.5 | English tone confirmed |
| **TC-13** | Out-of-domain safe redirection | Declines non-shop inquiry politely | Steered back to shop products | **PASS** | `#996` | Real Gemini 3.5 | Safely steered back to shop products |
| **TC-14** | Unknown inventory inquiry | Refuses to fabricate non-existent item | Refused fabrication of BTS lightstick | **PASS** | `#999` | Real Gemini 3.5 | Refuses to fabricate unknown catalog item |
| **TC-15** | Owner disables bot via button | Button `cmd_off` updates panel in-place; halts replies | Turned OFF via `editMessageText`, 0 customer replies | **PASS** | `#1003` | Owner Control Subworkflow | Button `cmd_off` updates panel in-place (`editMessageText`) & halts messages |
| **TC-16** | Owner pauses specific chat | `/pause <id>` mutes chat; others active | `is_paused=true`, 0 replies | **PASS** | `#1006` | Owner Control Subworkflow | Per-chat pause strictly halts automated messages |
| **TC-17** | Owner enables bot via button | Button `cmd_on` updates panel in-place; replies resume | Resumed via `editMessageText`, replies resumed | **PASS** | `#1009` | Owner Control Subworkflow | Button `cmd_on` updates panel in-place (`editMessageText`) & restores replies |
| **TC-18** | Duplicate Telegram event | Atomic deduplication drops 2nd event | 1 reply sent, 2nd dropped | **PASS** | `#1016` | PostgreSQL Dedup Ledger | Atomic `update_id` deduplication passed |
| **TC-19** | Human takeover & button resume | Seller DM pauses chat; button resume restores AI | Takeover: paused, Button: resumed via `editMessageText` | **PASS** | `#1019` | Owner Control Panel Subworkflow | Human takeover auto-pauses; button updates panel in-place (`editMessageText`) & restores AI |
| **TC-20** | Missing/invalid webhook secret | Rejection HTTP 401 & 0 outbound replies | HTTP 401 status verified, 0 outbound replies | **PASS** | `#1020` | Nginx / n8n Secret Gate | Webhook verification fails closed on invalid secret (HTTP 401 verified) |
| **TC-21** | Gemini failure simulation & recovery | Fallback engine catches failure cleanly | Fallback branch executed, quoted ₱100 | **PASS** | `#1023` | Deterministic Fallback Engine | Grounded fallback recovers accurately; execution path verified in n8n `execution_data` |
| **TC-22** | Google Sheets unavailable | Logs failure; retains last-good snapshot | Preserved 69 items, FAILED logged, customer reply served | **PASS** | `#1024` | PostgreSQL Snapshot Cache | Real failure injected into n8n sync workflow; Log Sync Fallback executed; snapshot preserved; customer served |
| **TC-23** | Real Sheets-to-PostgreSQL sync | Real sync writes 69 items; query quotes ₱100 | Sync SUCCESS, quoted ₱100.00 | **PASS** | `#1028` | Google Sheets API v4 (Live) | Real Google Sheets -> PostgreSQL -> Customer Reply verified |
| **TC-24** | Multi-customer chat isolation | Customer A and B receive distinct replies | C1: Jun, C2: Wonwoo isolated | **PASS** | `#1033` | Multi-Tenant State Ledger | Multi-tenant customer chat isolation verified |
| **TC-25** | Pre-dispatch race condition guard | Turn OFF during generation blocks message | Gate passed, state changed mid-flight, 0 reply | **PASS** | `#1038` | Pre-Dispatch Security Gate | In-flight race condition intercepted by pre-dispatch gate; execution path verified in n8n `execution_data` |

**Acceptance Results: 25 Passed, 0 Failed, 0 Blocked.**

---

## 3. Deep-Dive Component Audits

### A. Real Google Sheets ↔ PostgreSQL Transactional Sync (`eSF3SSYCgDMeJQmR`)
- **Authentication & Security:** 
  - Google Sheets OAuth2 API (`PhsExAwUfErlT36v`) is authorized and functional.
  - Webhook Trigger is protected by `Verify Sync Webhook Secret`, requiring `$TELEGRAM_WEBHOOK_SECRET` header. Unauthenticated requests return HTTP 401 Unauthorized immediately.
  - Nginx reverse proxy blocks public tunnel requests to `/webhook/sync-google-sheets` with HTTP 403 Forbidden.
  - Manual triggers (`sync-trig-manual`) and hourly scheduled triggers (`sync-trig-schedule`) connect directly to data fetch nodes, preserving automated synchronization without requiring webhook invocations.
- **Three-Tab Integration:**
  - Tab 1 (`Product Inventory`): Reads non-standard headers (Row 4), parses `Member`, `Product Name`, `Price (₱)`, `Stock (pcs)`, and `Notes`.
  - Tab 2 (`SF and PF Rates`): Parses J&T courier policy, Luzon/Visayas/Mindanao shipping tiers, and Small/Medium/Large packing fee specifications.
  - Tab 3 (`Mode of Payments`): Parses payment deadline (1 week, 30% NRDP) and GCash, Maya, and MariBank accounts.
- **Transactional Atomicity:** Sync executes within a single `BEGIN ... COMMIT;` block in PostgreSQL.
- **Defensive Failure Handling:** If Google Sheets API times out, returns malformed rows, or returns fewer than 50 items, the validation gate trips, records `FAILED` in `sync_history`, and preserves the existing database snapshot without truncation or modification (verified in TC-22).

### B. Telegram Owner Control Panel with Native Buttons (`GzGhjXdy38xmzByE`)
- **Private Bot Channel:** Seller communicates directly with `@sashtt_bot` via direct message or inline button taps.
- **Inline Keyboard Layout (`reply_markup`):**
  - Row 1: `[ 🟢 Turn ON ]` (`cmd_on`), `[ 🔴 Turn OFF ]` (`cmd_off`)
  - Row 2: `[ 📊 Refresh Status ]` (`cmd_status`), `[ ⏸️ Paused Chats ]` (`cmd_paused`)
  - Row 3+ (Dynamic): `[ ▶️ Resume Customer <chat_id> ]` (`resume_<chat_id>`) dynamically populated for any chat currently paused under human takeover.
- **Security Check:** Strictly validates that `sender_id === TELEGRAM_SELLER_USER_ID`. Unauthorized commands/callbacks are immediately rejected.
- **Callback & Update Flow:** 
  - When inline buttons are clicked, workflow calls `https://api.telegram.org/bot<TOKEN>/answerCallbackQuery` to clear the Telegram client loading spinner.
  - Calls `https://api.telegram.org/bot<TOKEN>/editMessageText` with the existing `message_id` to update the control panel in-place without producing duplicate chat messages.
  - Text commands (`/status`, `/on`, `/off`) call `sendMessage` to post a new panel message.
  - In simulator mode (`TELEGRAM_SIMULATOR_MODE=true`), records `{ method: 'editMessageText', callback_query_id, message_id, ... }` in `telegram_simulated_outbound` for deterministic verification.

### C. AI Reasoning Engine (`wMZ3vsdPji1oSAr0`)
- **Active Model:** Google Gemini `gemini-3.5-flash-lite` (`https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent`).
- **Telemetry & Sanitization:** Returns metadata `{ source: "gemini_3.5_flash_lite", model: "gemini-3.5-flash-lite" }` without exposing API keys or secrets in logs.
- **Deterministic Grounded Fallback:** If Gemini times out or is unreachable (or in TC-21 simulation), subworkflow executes the deterministic grounded rules engine (`grounded_rules_v1`), preserving shop accuracy and quoting authoritative prices (₱100.00 for Jun FML Deluxe).

### D. Webhook Verification & Fail-Closed Gate (`ktvkVp0E0z2blc4n`)
- **Response Mode:** `responseNode` coupled with `Respond to Webhook` nodes.
- **Fail-Closed Gate:** If `x-telegram-bot-api-secret-token` is missing or mismatched:
  - Workflow immediately executes `Respond 401 Unauthorized Webhook` (HTTP 401).
  - No database queries, deduplication records, or downstream nodes are executed.
  - Outbound message queue remains strictly empty. Both conditions are separately asserted in TC-20.

### E. In-Flight Pre-Dispatch Race Condition Gate (`ktvkVp0E0z2blc4n`)
- **Two-Phase Authorization:** 
  - Phase 1: `Safety & Authorization Gate` validates agent state upon message receipt.
  - Phase 2: `Recheck State Before Dispatch` queries `agent_control_state` directly from PostgreSQL immediately before sending outbound replies.
- **In-Flight Protection:** If the owner turns OFF the agent while an AI response is being generated, `Final Pre-Dispatch Authorization Gate` detects `is_enabled = false` and aborts outbound dispatch, preventing stale or unauthorized messages (verified in TC-25).

---

## 4. Confidential Payment Data Audit & Historical Commit Note

> [!NOTE]
> **Working Tree Confidentiality Status:**
> All files on `HEAD` and in the active working directory are strictly sanitized:
> - Payment numbers: `09XXXXXXXXX`
> - Account names: `Store Owner`
> - `data/knowledge_base.json`: Untracked and excluded in `.gitignore`
>
> **Historical Commit Record:**
> As noted in the initial security disclosure, historical git commits (`ca53c32`, `062600d`, `d8c73d7`, `1252453`) from earlier development phases contain the raw payment number `9976111139`. In accordance with user instruction (*"Do not rewrite Git history without approval"*), historical git commits have been left untouched. If the user chooses to cleanse git history at a later stage, running `git-filter-repo` or BFG Repo-Cleaner followed by a force-push will permanently remove the historical references.

---

## 5. Deployment Readiness

| Requirement | Implementation State | Production Ready? |
| :--- | :--- | :---: |
| PostgreSQL Schemas & Migration | Enhanced schema with transactional sync, dedup, and state ledger | **YES** |
| Google Sheets Integration | Live OAuth2 account with transactional sync & snapshot cache | **YES** |
| Owner Control Panel | Telegram inline keyboard with `editMessageText` & `answerCallbackQuery` | **YES** |
| Gemini AI Model | Live `gemini-3.5-flash-lite` with grounded prompt & deterministic fallback | **YES** |
| Security & Safety Gates | Secret token authentication (HTTP 401), rate limits, pre-dispatch gate | **YES** |
| Automated Test Coverage | 25-scenario end-to-end acceptance suite with clean restoration | **YES** |
| Cloud VPS Deployment | Staged; Docker Compose & deployment scripts ready; deferred per policy | **READY TO DEPLOY** |
