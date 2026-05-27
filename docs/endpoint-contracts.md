# Endpoint Contracts

These contracts define the HTTP API both Variant A (monolith) and Variant B
(microservices) must implement identically. Any difference in request shape,
response shape, status codes, or business behaviour invalidates the comparison.

## Domain model

Three entities:
- **User**: id (UUID), name, email, createdAt
- **Product**: id (UUID), name, price (decimal), stock (integer)
- **Order**: id (UUID), userId, items (list of {productId, quantity, unitPrice}),
  totalAmount, status, createdAt

## Endpoints

### Users

#### POST /users
Create a new user.

Request body:
```json
{
  "name": "string, required, 2-100 chars",
  "email": "string, required, valid email format"
}
```

Response 201 Created:
```json
{
  "id": "uuid",
  "name": "string",
  "email": "string",
  "createdAt": "ISO-8601 timestamp"
}
```

Response 400 Bad Request: validation failure
Response 409 Conflict: email already exists

#### GET /users/{id}
Fetch a user by ID.

Response 200 OK: same shape as POST response
Response 404 Not Found: no user with that ID

---

### Products

#### POST /products
Create a product.

Request body:
```json
{
  "name": "string, required, 2-100 chars",
  "price": "decimal, required, > 0",
  "stock": "integer, required, >= 0"
}
```

Response 201 Created:
```json
{
  "id": "uuid",
  "name": "string",
  "price": "decimal",
  "stock": "integer"
}
```

Response 400 Bad Request: validation failure

#### GET /products/{id}
Fetch a product.

Response 200 OK: same shape as POST response
Response 404 Not Found

---

### Orders

#### POST /orders
Create an order. This is the interesting endpoint because it touches all three
entities. In Variant B, this is the endpoint that exercises inter-service REST
communication: the Order service calls User to validate, and Product to look
up prices and check stock.

Request body:
```json
{
  "userId": "uuid, required",
  "items": [
    {
      "productId": "uuid, required",
      "quantity": "integer, required, > 0"
    }
  ]
}
```

Response 201 Created:
```json
{
  "id": "uuid",
  "userId": "uuid",
  "items": [
    {
      "productId": "uuid",
      "quantity": "integer",
      "unitPrice": "decimal"
    }
  ],
  "totalAmount": "decimal",
  "status": "CREATED",
  "createdAt": "ISO-8601 timestamp"
}
```

Response 400 Bad Request: validation failure, empty items list
Response 404 Not Found: user or any product not found
Response 409 Conflict: insufficient stock for any item

#### GET /orders/{id}
Fetch an order.

Response 200 OK: same shape as POST response
Response 404 Not Found

---

## Cross-cutting rules

- All timestamps in UTC, ISO-8601 format.
- All decimals serialised as JSON numbers (not strings), 2 decimal places.
- UUIDs are version 4, lowercase, with hyphens.
- Both variants must produce byte-identical JSON responses for identical inputs
  (excluding generated IDs and timestamps).
- No authentication for this study. Adding auth would add latency that isn't
  the variable we're measuring.

## What's deliberately excluded

- Pagination, filtering, sorting on GETs. Adds complexity without testing
  architecture differences.
- Update and delete endpoints. POST and GET are enough to exercise the
  architecture.
- More than three entities. The simpler the domain, the cleaner the comparison.