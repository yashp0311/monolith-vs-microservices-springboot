# Variant C Design: Microservices with Shared Redis Cache

**Purpose:** Design document for the Redis caching strategy in Variant C,
sent to supervisor for review before implementation begins.

**Author:** Yash Madhukar Patil (25297651)

**Supervisor:** Dr. Andrew Le Gear

**Date:** 20 / 08 / 2026

## Background

Variant B (REST microservices) established that inter-service HTTP calls
introduce ~10ms of fixed overhead per request at low concurrency, growing
to hundreds of milliseconds under load. The Order service makes two REST
calls per order-create request: one to User service (validate user exists)
and one to Product service (fetch price and stock, then decrement stock).
These calls are the dominant cost above 100 concurrent users.

Variant C aims to reduce this cost by replacing REST reads with Redis cache
reads for the two most-called operations: `GET /users/{id}` and
`GET /products/{id}`. Writes (order creation, stock decrement) continue to
go through REST, since the source of truth remains each service's
PostgreSQL database.

## What we cache

Two entities, read operations only:

**1. User cache**
- Cache key: `users::{userId}`
- Value: full User DTO (id, name, email, createdAt)
- Populated: on first `GET /users/{id}` call from Order service
- Read pattern: check cache first; on miss, fetch via REST from User
  service and populate cache

**2. Product cache**
- Cache key: `products::{productId}`
- Value: full Product DTO (id, name, price, stock)
- Populated: on first `GET /products/{id}` call from Order service
- Read pattern: same as User

We do NOT cache:
- Order data (Order service owns it, always reads from its own DB)
- Write operations (POST /users, POST /products, PATCH /products/{id}/stock)
- Any listing or search operations (not part of the experiment workload)

## Invalidation strategy

The workload for the experiment is read-heavy on Users and Products, with
stock decrements happening on every order. This affects the caching strategy:

**Users:** Effectively immutable during the experiment. Seed script creates
100 users at the start of each run and no writes happen after. TTL of 5
minutes is sufficient; the experiment runs 10 minutes with the first 60s
discarded as warm-up, so cache entries live the whole run.

**Products (name, price):** Also effectively immutable during the experiment.
Same TTL.

**Products (stock):** This is the tricky one. Stock changes on every order.
If we cache stock and don't invalidate, Order service reads stale stock
and either rejects valid orders or accepts orders that should fail.

Design decision: **cache Product without stock**. The Product cache stores
only `{id, name, price}`. Stock check happens via a lightweight REST call
to Product service. This keeps the cache correct and still eliminates most
of the REST overhead (price lookup is the dominant cost; stock check is a
single indexed read).

An alternative is to cache the full Product including stock, then invalidate
on every stock update. This is closer to production practice but adds
complexity and a failure mode (network partition between cache and Product
service causes stale stock). For the experiment, keeping stock out of cache
is cleaner and easier to reason about.

## TTL and scope

- All cache entries: 5 minutes TTL
- Redis runs as a single container, shared by all three services
- No cache clustering, no replication (not needed at experiment scale)
- Redis exposed on port 6379, standard config

## Failure modes

- **Redis down at startup:** Order service fails fast on startup. Same
  behaviour as if Postgres is down. Acceptable for experiment; in production
  you'd have a circuit breaker.
- **Redis down mid-experiment:** Spring Cache will throw an exception on
  each cache access. We configure a cache resolver that falls back to REST
  on cache exceptions. This adds resilience without changing the happy path.
- **Cache miss under load:** First few requests per key take the REST path
  and populate cache. After warm-up, hit rate should stabilise at ~99% for
  Users (all 100 users hit early) and ~99% for Products (all 1000 products
  hit within first 60s given random selection).

## Expected cache hit rate

Given 100 users randomly selected per request, at 500 concurrent users the
cache warms up in seconds. Products similarly (1000 products, random
selection, high request rate). Steady-state hit rate will be effectively
100% for User cache and >99% for Product cache.

This is higher than the 70-80% we discussed as "realistic," which reflects
the fact that our workload is deliberately uniform (random selection from
a fixed set). This is worth noting in the discussion section: production
workloads with skewed access patterns would see lower hit rates and
therefore less benefit from caching.

To simulate a more realistic workload we could:
- Restrict the working set (e.g. only 500 of the 1000 products get accessed)
- Add cache eviction pressure by setting a smaller Redis max memory
- Deliberately not cache some fraction of requests

For iteration 1, we'll measure the actual hit rate and report it. If it's
"unrealistically high" we can add one of these adjustments in iteration 2.

## Implementation approach

Spring Boot has first-class Redis integration via Spring Cache. Two
dependencies added to Order service's pom.xml:

    spring-boot-starter-cache
    spring-boot-starter-data-redis

Configuration:

    @EnableCaching on the main application class
    RedisCacheManager bean with 5-minute default TTL
    RedisConnectionFactory pointing at localhost:6379

Cache invocation via annotations on UserClient and ProductClient methods:

    @Cacheable(value = "users", key = "#id")
    public UserDto getUser(UUID id) { ... }

    @Cacheable(value = "products", key = "#id")
    public ProductDto getProductWithoutStock(UUID id) { ... }

Stock check remains a direct REST call:

    public int getStock(UUID productId) { ... }  // not cached

## What changes in the Order service

The `createOrder` flow currently makes two REST calls per line item plus
one for the user. In Variant C:

- User validation: cache lookup (hit) or REST call (miss)
- Product price fetch: cache lookup (hit) or REST call (miss)
- Product stock check: REST call (always)
- Stock decrement: REST call (always)

So under warmed-up conditions, an order-create still makes ~2 REST calls
(one for stock check, one for stock decrement per line item), but the user
validation and price fetch become cache lookups. On a typical order with 1-3
items this reduces REST calls from ~4-8 down to ~2-4.

## What we'll measure

Beyond the standard four metrics (response time, throughput, CPU, memory),
Variant C adds:

- Cache hit rate (Redis INFO commandstats)
- Redis memory usage
- Distribution of "cache hit" vs "cache miss" latency for cache-bound
  operations

The cache hit rate specifically is required to justify the results — if
hit rate is low, Variant C won't show much improvement over B, and that's
a finding worth discussing rather than something to hide.

