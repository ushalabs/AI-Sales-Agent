-- PostgreSQL Schema for Phase 5 Knowledge Base

CREATE TABLE IF NOT EXISTS inventory_products (
    id SERIAL PRIMARY KEY,
    member VARCHAR(100) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    price_php NUMERIC(10, 2) NOT NULL DEFAULT 0,
    stock INT NOT NULL DEFAULT 0,
    notes TEXT,
    keywords TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventory_member ON inventory_products(member);
CREATE INDEX IF NOT EXISTS idx_inventory_product_name ON inventory_products(product_name);

CREATE TABLE IF NOT EXISTS shipping_rates (
    id SERIAL PRIMARY KEY,
    region VARCHAR(50) NOT NULL UNIQUE,
    small NUMERIC(10, 2) NOT NULL,
    medium NUMERIC(10, 2) NOT NULL,
    large NUMERIC(10, 2) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS packing_fees (
    id SERIAL PRIMARY KEY,
    size VARCHAR(50) NOT NULL UNIQUE,
    price_php NUMERIC(10, 2) NOT NULL,
    capacity VARCHAR(100),
    inclusions TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payment_methods (
    id SERIAL PRIMARY KEY,
    method_name VARCHAR(100) NOT NULL UNIQUE,
    account_number VARCHAR(100) NOT NULL,
    account_name VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shop_policies (
    policy_key VARCHAR(100) PRIMARY KEY,
    policy_value TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
