-- Seed for Variant B order-service: truncate previous run's data

TRUNCATE TABLE order_items, orders RESTART IDENTITY CASCADE;
