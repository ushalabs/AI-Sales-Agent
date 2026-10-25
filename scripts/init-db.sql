-- PostgreSQL Schema for Telegram Business Integration
-- Phase 4: State Tracking and Deduplication

CREATE TABLE IF NOT EXISTS telegram_processed_updates (
    update_id BIGINT PRIMARY KEY,
    business_connection_id VARCHAR(255),
    chat_id BIGINT,
    message_id BIGINT,
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_processed_updates_chat ON telegram_processed_updates(chat_id);
CREATE INDEX IF NOT EXISTS idx_processed_updates_time ON telegram_processed_updates(processed_at);

CREATE TABLE IF NOT EXISTS telegram_business_connections (
    business_connection_id VARCHAR(255) PRIMARY KEY,
    user_id BIGINT NOT NULL,
    user_chat_id BIGINT NOT NULL,
    can_reply BOOLEAN DEFAULT TRUE,
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
