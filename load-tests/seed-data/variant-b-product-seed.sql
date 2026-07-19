-- Seed data for Variant B product-service

TRUNCATE TABLE products RESTART IDENTITY CASCADE;

INSERT INTO products (id, name, price, stock)
SELECT
    ('00000000-0000-0000-0000-' || LPAD((1000000 + n)::text, 12, '0'))::uuid,
    'Product ' || n,
    (RANDOM() * 99 + 1)::numeric(10,2),
    1000000
FROM generate_series(1, 1000) n;