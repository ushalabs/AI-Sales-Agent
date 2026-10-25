-- PostgreSQL Schema for Phase 7: Owner Controls and Human Takeover State

CREATE TABLE IF NOT EXISTS agent_control_state (
    id INT PRIMARY KEY DEFAULT 1,
    is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    sleep_mode_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    updated_by BIGINT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure default singleton row exists with is_enabled = FALSE
INSERT INTO agent_control_state (id, is_enabled, sleep_mode_enabled, updated_at)
VALUES (1, FALSE, FALSE, NOW())
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS chat_conversation_state (
    chat_id BIGINT PRIMARY KEY,
    is_paused BOOLEAN NOT NULL DEFAULT FALSE,
    last_message_from VARCHAR(50) DEFAULT 'customer',
    pause_reason VARCHAR(255),
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_paused ON chat_conversation_state(is_paused);
