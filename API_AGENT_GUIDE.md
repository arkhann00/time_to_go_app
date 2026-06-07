# Backend API Guide for Mobile AI Agent

This file is the authoritative API contract for mobile app integration.
Use it as the single source of truth for endpoints, auth, request/response shapes, and business rules.

## Base

- Base URL (local): `http://127.0.0.1:8000`
- Swagger UI: `http://127.0.0.1:8000/docs`
- Content-Type: `application/json` (except avatar upload which is `multipart/form-data`)

---

## Authentication

### Token type

- `access_token` is a JWT bearer token.
- Send in header: `Authorization: Bearer <access_token>`.
- Access token lifetime: **7 days**.
- Expired or invalid token → `401`.

### Refresh logic

- `POST /auth/refresh` accepts the current **valid** access token and returns a new one.
- If the token is already expired, `/auth/refresh` will return `401` → user must log in again.
- There is no separate refresh token entity.

### Public endpoints (no bearer required)

- `GET /`
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `GET /believers/all`
- `GET /believers/testimony-of-day`
- `GET /believers/stats/accepted-jesus-count`
- `GET /believers/latest`
- `GET /outreach-statistics/all`

### Protected endpoints (bearer required)

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
- `POST /outreach-statistics`
- `GET /outreach-statistics/me`
- `GET /outreach-statistics/{statistics_id}`
- `PATCH /outreach-statistics/{statistics_id}`
- `DELETE /outreach-statistics/{statistics_id}`

---

## Data Models

### Stage enum (`Believer.stage`)

| Value             | Meaning            |
| ----------------- | ------------------ |
| `interested`      | Проявил интерес    |
| `receivedJesus`   | Принял Иисуса      |
| `joinedCommunity` | Влился в общину    |
| `baptised`        | Крещён             |
| `evangelist`      | Сам евангелизирует |

### User

```json
{
  "id": 1,
  "name": "John",
  "email": "john@example.com",
  "avatar_url": "/uploads/avatars/user_1_abc123.jpg",
  "about": "Serving in campus ministry"
}
```

- `avatar_url` — relative path served at `<base_url>/uploads/avatars/<filename>`, or `null`
- `about` — free-text bio, or `null`

### Evangelism Method

```json
{ "id": 1, "name": "4 знака", "is_default": true }
```

Default methods seeded in DB:

- `4 знака`
- `Иисус у двери`

Custom methods belong to a user (`is_default: false`). Name is unique per user.

### Believer

Create/update fields:

| Field          | Type           | Required | Notes                             |
| -------------- | -------------- | -------- | --------------------------------- |
| `name`         | string         | yes      |                                   |
| `telegram`     | string \| null | no       |                                   |
| `phone_number` | string \| null | no       |                                   |
| `met_at`       | `YYYY-MM-DD`   | yes      | Date the person was met           |
| `stage`        | enum string    | yes      | See stage enum above              |
| `method_id`    | integer        | yes      | Must be available to current user |
| `note`         | string \| null | no       |                                   |
| `testimony`    | string \| null | no       | Their testimony text              |
| `latitude`     | number         | yes      |                                   |
| `longitude`    | number         | yes      |                                   |

`BelieverResponse` includes all of the above plus:

- `id`: integer
- `method`: `{ id, name, is_default }`

Public list endpoints (`GET /believers/all`, `GET /believers/latest`, `GET /believers/testimony-of-day`) return `BelieverWithOwnerResponse` which adds:

- `owner`: `{ id, name, avatar_url }`

### Outreach Statistics

Each user can have **multiple** outreach statistics records, one per outreach event/day.
The `outreach_date` is set manually by the user and identifies when the outreach took place.

Create/update fields:

| Field                          | Type         | Required on create | Notes                                      |
| ------------------------------ | ------------ | ------------------ | ------------------------------------------ |
| `outreach_date`                | `YYYY-MM-DD` | yes                | Date of the outreach event                 |
| `gospels_told`                 | integer ≥ 0  | no (default `0`)   | Number of gospel presentations             |
| `salvation_prayed_unreachable` | integer ≥ 0  | no (default `0`)   | Prayed for salvation but later unreachable |
| `scriptures_distributed`       | integer ≥ 0  | no (default `0`)   | NT / Gospel of John copies given out       |
| `healings_deliverances`        | integer ≥ 0  | no (default `0`)   | People who received healing or deliverance |

Response fields:

- All fields above plus:
  - `id`: integer
  - `user_id`: integer
  - `created_at`: ISO 8601 datetime
  - `updated_at`: ISO 8601 datetime

List-all response (`/outreach-statistics/all`) additionally includes:

- `user`: full `User` object (`id`, `name`, `email`, `avatar_url`, `about`)

---

## Endpoint Contracts

### `GET /`

Response `200`:

```json
{ "status": "success" }
```

---

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

- Password max size: **72 bytes** (UTF-8 encoded). Longer passwords → `422`.

Response `200`: User object.

Errors:

- `409` — email already registered

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

Errors:

- `401` — wrong email or password

### `POST /auth/refresh`

Request:

```json
{ "access_token": "<existing-valid-jwt>" }
```

Response `200`:

```json
{
  "access_token": "<new-jwt>",
  "token_type": "bearer"
}
```

Errors:

- `401` — token invalid or already expired (must re-login)

### `GET /auth/me` (protected)

Response `200`: User object.

### `PATCH /auth/me` (protected)

Partial update. Only `name` and `about` can be changed.

Request:

```json
{
  "name": "John Updated",
  "about": "Serving in campus ministry"
}
```

Response `200`: User object.

### `POST /auth/me/avatar` (protected)

Upload avatar as `multipart/form-data`.

Form field: `avatar` (file)

Allowed types: `image/jpeg`, `image/png`, `image/webp`, `image/gif`, `image/heic`, `image/heif`

Max file size: `5 MB`

Behavior: replaces the previous avatar file if one existed.

Response `200`: User object with updated `avatar_url`.

Errors:

- `400` — unsupported format or empty file
- `413` — file exceeds 5 MB

---

## Methods

### `GET /methods` (protected)

Returns default methods + current user's custom methods.

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

- `400` — empty name
- `409` — user already has a method with that name

---

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

Response `201`: Believer response.

Errors:

- `404` — method_id not found or not available to current user

### `GET /believers` (protected)

Returns only believers of the authenticated user, sorted by `met_at` descending.

### `GET /believers/my` (protected)

Same as `GET /believers`. Both return only current user's believers.

### `GET /believers/all` (public)

Returns believers of all users, sorted by `met_at` descending.

### `GET /believers/latest` (public)

Query params:

- `date_from` — optional, `YYYY-MM-DD`
- `date_to` — optional, `YYYY-MM-DD`

Returns max **20** believers sorted by `met_at` descending, filtered by the date range if provided.

### `GET /believers/testimony-of-day` (public)

Query params:

- `day` — optional, `YYYY-MM-DD` (defaults to today on the server)

Returns one deterministic believer for the day. Only believers with a non-empty `testimony` are eligible. Selection rotates daily.

Errors:

- `404` — no believers with testimony exist

### `GET /believers/stats/accepted-jesus-count` (public)

Response:

```json
{ "count": 123 }
```

Counts believers with `stage` ≠ `interested` (i.e. `receivedJesus`, `joinedCommunity`, `baptised`, `evangelist`).

### `GET /believers/{believer_id}` (protected)

Returns the believer only if it belongs to the current user.

Errors: `404` if not found or not owned.

### `PATCH /believers/{believer_id}` (protected)

Partial update. Only the owner can update. If `method_id` is included, it must be a default or user-owned method.

Response `200`: Believer response.

### `DELETE /believers/{believer_id}` (protected)

Deletes the believer. Only the owner can delete.

Response `204`.

---

## Outreach Statistics

Each user accumulates **a list** of outreach statistics records, one per outreach event.
`outreach_date` is set manually by the user.

### `POST /outreach-statistics` (protected)

Create a new statistics record for the authenticated user.

Request example:

```json
{
  "outreach_date": "2026-06-01",
  "gospels_told": 12,
  "salvation_prayed_unreachable": 3,
  "scriptures_distributed": 25,
  "healings_deliverances": 4
}
```

- `outreach_date` is required.
- Counter fields default to `0` if omitted.
- A user may have **multiple** records (no uniqueness constraint).

Response `201`: OutreachStatistics response.

### `GET /outreach-statistics/me` (protected)

Returns **all** outreach statistics records for the current user, sorted by `outreach_date` descending (newest first).

Response `200`:

```json
[
  {
    "id": 3,
    "user_id": 1,
    "outreach_date": "2026-06-05",
    "gospels_told": 8,
    "salvation_prayed_unreachable": 1,
    "scriptures_distributed": 10,
    "healings_deliverances": 2,
    "created_at": "2026-06-05T18:00:00+00:00",
    "updated_at": "2026-06-05T18:00:00+00:00"
  }
]
```

Returns an empty array `[]` if no records exist.

### `GET /outreach-statistics/all` (public)

Returns outreach statistics of **all users**, sorted by `outreach_date` descending.
Each record includes the full user object.

Response `200`:

```json
[
  {
    "id": 3,
    "user_id": 1,
    "outreach_date": "2026-06-05",
    "gospels_told": 8,
    "salvation_prayed_unreachable": 1,
    "scriptures_distributed": 10,
    "healings_deliverances": 2,
    "created_at": "2026-06-05T18:00:00+00:00",
    "updated_at": "2026-06-05T18:00:00+00:00",
    "user": {
      "id": 1,
      "name": "John",
      "email": "john@example.com",
      "avatar_url": null,
      "about": null
    }
  }
]
```

### `GET /outreach-statistics/{statistics_id}` (protected)

Returns one record by id. Only the owner can access it.

Response `200`: OutreachStatistics response.

Errors: `404` if not found or not owned.

### `PATCH /outreach-statistics/{statistics_id}` (protected)

Partial update by id. Only the owner can update.

Request example:

```json
{
  "outreach_date": "2026-06-06",
  "gospels_told": 15
}
```

All fields are optional. Omitted fields are left unchanged.

Response `200`: OutreachStatistics response.

Errors: `404` if not found or not owned.

### `DELETE /outreach-statistics/{statistics_id}` (protected)

Deletes the record. Only the owner can delete.

Response `204`.

Errors: `404` if not found or not owned.

---

## Error reference

| Code  | When                                                                                                       |
| ----- | ---------------------------------------------------------------------------------------------------------- |
| `401` | Missing/invalid/expired bearer token; invalid token in `/auth/refresh`                                     |
| `404` | Resource not found or not owned by current user; method not available; no testimonies for testimony-of-day |
| `409` | Email already registered; duplicate custom method name                                                     |
| `413` | Avatar file exceeds 5 MB                                                                                   |
| `422` | Invalid request shape/type (FastAPI validation error)                                                      |

---

## Recommended mobile integration flow

1. Register (`POST /auth/register`) or login (`POST /auth/login`). Save `access_token` in secure storage.
2. On app start, call `GET /auth/me` to restore session.
3. Load methods (`GET /methods`) and cache them for believer creation.
4. Create and manage own believers via protected endpoints.
5. Create outreach statistics after each outreach event (`POST /outreach-statistics`), providing `outreach_date` manually.
6. Show own stats history via `GET /outreach-statistics/me` (list, newest first).
7. Edit a record via `PATCH /outreach-statistics/{id}`, delete via `DELETE /outreach-statistics/{id}`.
8. Use public endpoints for community-wide widgets:
   - `GET /believers/all` — all believers in system
   - `GET /believers/latest` — recent believers with date filter
   - `GET /believers/testimony-of-day` — daily rotating testimony
   - `GET /believers/stats/accepted-jesus-count` — total who accepted Jesus
   - `GET /outreach-statistics/all` — all outreach records with user info, newest first
9. Before token expiry (7 days), call `POST /auth/refresh` with the current valid token.
   If token already expired, re-login is required.
