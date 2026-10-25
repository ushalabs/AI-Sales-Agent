-- scripts/enhance-database.sql
-- Enhancements for local-first testing, synchronization logging, and simulation capture

-- 1. Sync History Table
CREATE TABLE IF NOT EXISTS sync_history (
    id SERIAL PRIMARY KEY,
    sync_type VARCHAR(50) NOT NULL DEFAULT 'GOOGLE_SHEETS',
    status VARCHAR(20) NOT NULL, -- 'SUCCESS', 'FAILED', 'PARTIAL'
    products_synced INT DEFAULT 0,
    rates_synced INT DEFAULT 0,
    error_message TEXT,
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Telegram Simulated Outbound Capture Table
CREATE TABLE IF NOT EXISTS telegram_simulated_outbound (
    id SERIAL PRIMARY KEY,
    business_connection_id VARCHAR(100),
    chat_id BIGINT NOT NULL,
    message_text TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'CAPTURED',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Ensure proper indexes for high performance
CREATE INDEX IF NOT EXISTS idx_sim_outbound_chat_id ON telegram_simulated_outbound(chat_id);
CREATE INDEX IF NOT EXISTS idx_chat_conv_state_paused ON chat_conversation_state(chat_id, is_paused);
CREATE INDEX IF NOT EXISTS idx_sync_history_synced_at ON sync_history(synced_at DESC);
