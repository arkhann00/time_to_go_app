# Backend API Guide for Mobile AI Agent

This file is a practical API contract for integrating the mobile app with the backend.
Use it as the source of truth for endpoints, auth, request/response shapes, and business rules.

## Base

- Base URL (local): `http://127.0.0.1:8000`
- Swagger UI: `http://127.0.0.1:8000/docs`
- Content-Type: `application/json`

## Authentication

### Token type

- `access_token` is JWT bearer token.
- Send in header: `Authorization: Bearer <access_token>`.
- Access token lifetime: 7 days.
- If token expired or invalid -> `401`.

### Public endpoints (no bearer token required)

- `GET /`
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh` (token is passed in request body)
- `GET /believers/all`
- `GET /believers/testimony-of-day`
- `GET /believers/stats/accepted-jesus-count`
- `GET /believers/latest`

### Protected endpoints (bearer token required)

- `GET /auth/me`
- `PATCH /auth/me`
- `POST /auth/me/avatar`
- `GET /methods`
- `POST /methods`
- `POST /believers`
- `GET /believers`
- `GET /believers/my`
- `GET /believers/{believer_id}`
- `PATCH /believers/{believer_id}`
- `DELETE /believers/{believer_id}`

---

## Data Models

### Stage enum (`Believer.stage`)

Allowed values:

- `interested`
- `receivedJesus`
- `joinedCommunity`
- `baptised`
- `evangelist`

### User

- `id`: integer
- `name`: string (required)
- `email`: string (required, unique)
- `avatar_url`: string | null
- `about`: string | null

### Evangelism Method

- `id`: integer
- `name`: string
- `is_default`: boolean

Default methods created by backend:

- `4 знака`
- `Иисус у двери`

### Believer (create/update fields)

- `name`: string (required)
- `telegram`: string | null (optional)
- `phone_number`: string | null (optional)
- `met_at`: date string `YYYY-MM-DD` (required)
- `stage`: enum value (required)
- `method_id`: integer (required)
- `note`: string | null
- `testimony`: string | null
- `latitude`: number (required)
- `longitude`: number (required)

Important:

- `telegram` and `phone_number` can both be empty/null.
- Only `name` is mandatory among these contact/name fields.

### Believer response model

- All believer fields above plus:
  - `id`: integer
  - `method`: object `{ id, name, is_default }`

---

## Endpoint Contracts

## Health

### `GET /`

Response `200`:

```json
{ "status": "success" }
```

## Auth

### `POST /auth/register`

Request:

```json
{
  "name": "John",
  "email": "john@example.com",
  "password": "secret123"
}
```

Response `200`:

```json
{
  "id": 1,
  "name": "John",
  "email": "john@example.com",
  "avatar_url": null,
  "about": null
}
```

### `POST /auth/login`

Request:

```json
{
  "email": "john@example.com",
  "password": "secret123"
}
```

Response `200`:

```json
{
  "access_token": "<jwt>",
  "token_type": "bearer"
}
```

### `POST /auth/refresh`

Request:

```json
{
  "access_token": "<existing-jwt>"
}
```

Response `200`:

```json
{
  "access_token": "<new-jwt>",
  "token_type": "bearer"
}
```

Notes:

- This works only if provided token is still valid.
- If expired/invalid -> `401`.

### `GET /auth/me` (protected)

Response `200`: same shape as register response.

### `PATCH /auth/me` (protected)

Partial update of current user's profile fields.

Request example:

```json
{
  "name": "John Updated",
  "about": "Serving in campus ministry"
}
```

Response `200`:

```json
{
  "id": 1,
  "name": "John Updated",
  "email": "john@example.com",
  "avatar_url": "/uploads/avatars/user_1_xxx.jpg",
  "about": "Serving in campus ministry"
}
```

### `POST /auth/me/avatar` (protected)

Uploads avatar as `multipart/form-data`.

Form field:

- `avatar`: file

Response `200`: same shape as user response, with updated `avatar_url`.

Avatar rules:

- Allowed content types: `image/jpeg`, `image/png`, `image/webp`, `image/gif`
- Max file size: `5MB`
- If user had previous local avatar, it is replaced

## Methods

### `GET /methods` (protected)

Returns current user's custom methods + default methods.

Response `200`:

```json
[
  { "id": 1, "name": "4 знака", "is_default": true },
  { "id": 2, "name": "Иисус у двери", "is_default": true },
  { "id": 7, "name": "Street talk", "is_default": false }
]
```

### `POST /methods` (protected)

Request:

```json
{ "name": "Street talk" }
```

Response `201`:

```json
{ "id": 7, "name": "Street talk", "is_default": false }
```

Errors:

- `400` if name is empty
- `409` if duplicate name for same user

## Believers

### `POST /believers` (protected)

Request example:

```json
{
  "name": "Alex",
  "telegram": "alex_tg",
  "phone_number": null,
  "met_at": "2026-05-14",
  "stage": "receivedJesus",
  "method_id": 1,
  "note": "Met near metro",
  "testimony": "He opened his heart during prayer",
  "latitude": 50.4501,
  "longitude": 30.5234
}
```

Response `201`: full `BelieverResponse`.

### `GET /believers` (protected)

- Returns only believers of current authenticated user.

### `GET /believers/my` (protected)

- Also returns only believers of current authenticated user.

### `GET /believers/all` (public)

- Returns believers of all users in the system.

### `GET /believers/latest` (public)

Query params:

- `date_from` (optional, `YYYY-MM-DD`)
- `date_to` (optional, `YYYY-MM-DD`)

Behavior:

- Returns max 20 believers.
- Sorted by `met_at` descending (latest first).
- Applies date filter to `met_at`.

### `GET /believers/testimony-of-day` (public)

Query params:

- `day` optional (`YYYY-MM-DD`)

Behavior:

- Selects one deterministic believer for the day.
- Only from believers where `testimony` is not empty.
- If `day` missing, backend uses today.
- If no testimonies exist -> `404`.

### `GET /believers/stats/accepted-jesus-count` (public)

Response:

```json
{ "count": 123 }
```

Count logic:

- Counts believers with stage not equal to `interested`.
- Included stages: `receivedJesus`, `joinedCommunity`, `baptised`, `evangelist`.

### `GET /believers/{believer_id}` (protected)

- Returns believer only if it belongs to current user.
- Otherwise `404`.

### `PATCH /believers/{believer_id}` (protected)

- Partial update.
- Only believer owner can update.
- If `method_id` provided, method must be available for current user (default or own).

### `DELETE /believers/{believer_id}` (protected)

- Deletes believer only if it belongs to current user.
- Response `204`.

---

## Error behavior (important for mobile AI agent)

- `401`:
  - missing/invalid/expired bearer token on protected endpoints
  - invalid token in `/auth/refresh`
- `404`:
  - believer not found or not owned by user on protected believer endpoints
  - evangelism method not found/not available for this user
  - no testimony found for testimony-of-day endpoint
- `409`:
  - register with existing email
  - creating duplicate custom method name
- `422`:
  - invalid request shape/type (FastAPI validation)

---

## Recommended mobile flow

1. Register (`/auth/register`) or login (`/auth/login`).
2. Save `access_token` in secure mobile storage.
3. Load methods (`/methods`) and cache IDs for believer creation.
4. Create and manage own believers via protected endpoints.
5. Use public analytics endpoints for app-wide widgets:
   - `/believers/all`
   - `/believers/latest`
   - `/believers/testimony-of-day`
   - `/believers/stats/accepted-jesus-count`
6. Before token expiry, call `/auth/refresh` with current valid token.

