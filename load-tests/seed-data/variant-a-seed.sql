-- Seed data for Variant A experimental runs
-- Run this before each experimental run to reset to a known state

-- Wipe existing data (cascades to order_items)
TRUNCATE TABLE order_items, orders, products, users RESTART IDENTITY CASCADE;

-- Insert 100 users with deterministic UUIDs (so JMeter can pick from a known set)
INSERT INTO users (id, name, email, created_at)
SELECT
    ('00000000-0000-0000-0000-' || LPAD(n::text, 12, '0'))::uuid,
    'User ' || n,
    'user' || n || '@example.com',
    NOW()
FROM generate_series(1, 100) n;

-- Insert 1000 products with deterministic UUIDs
INSERT INTO products (id, name, price, stock)
SELECT
    ('00000000-0000-0000-0000-' || LPAD((1000000 + n)::text, 12, '0'))::uuid,
    'Product ' || n,
    (RANDOM() * 99 + 1)::numeric(10,2),
    1000000  -- High stock so we never run out during experiments
FROM generate_series(1, 1000) n;