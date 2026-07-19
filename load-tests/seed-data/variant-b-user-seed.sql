-- Seed data for Variant B user-service
-- Same UUIDs as Variant A so JMeter plan doesn't need changes

TRUNCATE TABLE users RESTART IDENTITY CASCADE;

INSERT INTO users (id, name, email, created_at)
SELECT
    ('00000000-0000-0000-0000-' || LPAD(n::text, 12, '0'))::uuid,
    'User ' || n,
    'user' || n || '@example.com',
    NOW()
FROM generate_series(1, 100) n;