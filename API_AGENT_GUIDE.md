# Backend API Guide for Mobile AI Agent

This file is the authoritative API contract for mobile app integration.
Use it as the single source of truth for endpoints, auth, request/response shapes, and business rules.

> **BREAKING CHANGES (2026-06-07)** — Outreach Statistics were fully redesigned.
> See the [Breaking changes](#breaking-changes-2026-06-07) section before integrating.
>
> **CHANGE (2026-06-08)** — `testimonies` в ответе изменён с `list[string]` на `list[{id, text}]`.
> `PATCH /outreach-statistics/me` теперь поддерживает удаление свидетельства через `delete_testimony_id`.
>
> **CHANGE (2026-06-09)** — Добавлено поле `fathers_letters_distributed` (Раздано Писем Отца) во все endpoints статистики.
> `GET /outreach-statistics/summary` теперь возвращает `total_saved` и `fathers_letters_distributed`.

## Base

- Base URL (production): `https://api.time.to.go.xn--80a6ad.space` ✅ HTTPS
- Base URL (local): `http://127.0.0.1:8000`
- Swagger UI: `https://api.time.to.go.xn--80a6ad.space/docs`
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
- `GET /uploads/{path}` — статические файлы (аватарки и другие загрузки)
- `GET /believers/all`
- `GET /believers/testimony-of-day`
- `GET /believers/testimonies`
- `GET /believers/stats/accepted-jesus-count`
- `GET /believers/latest`
- `GET /outreach-statistics/all`
- `GET /outreach-statistics/summary`

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
- `GET /outreach-statistics/me`
- `POST /outreach-statistics/add`
- `PATCH /outreach-statistics/me`
- `POST /outreach-statistics/reset`

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

### Outreach Statistics ⚠️ REDESIGNED

Each user has **exactly one** cumulative statistics record. There is no list of records.
`outreach_date` no longer exists.

Fields:

| Field                          | Type               | Notes                                       |
| ------------------------------ | ------------------ | ------------------------------------------- |
| `id`                           | integer            |                                             |
| `user_id`                      | integer            | unique — one record per user                |
| `gospels_told`                 | integer ≥ 0        | running total                               |
| `salvation_prayed_unreachable` | integer ≥ 0        | running total                               |
| `scriptures_distributed`       | integer ≥ 0        | Раздано Евангелие от Иоана                  |
| `fathers_letters_distributed`  | integer ≥ 0        | Раздано Писем Отца                          |
| `healings_deliverances`        | integer ≥ 0        | running total                               |
| `testimonies`                  | `list[{id, text}]` | list of testimonies added by the evangelist |
| `created_at`                   | ISO 8601 datetime  |                                             |
| `updated_at`                   | ISO 8601 datetime  |                                             |

`/outreach-statistics/all` additionally returns `user: { id, name, email, avatar_url, about }` per record.

### Testimony (unified response)

Used by `GET /believers/testimony-of-day` and `GET /believers/testimonies`.
Combines testimonies from both `Believer` records and `OutreachStatistics` records.

```json
{
  "source": "believer",
  "testimony": "He opened his heart during prayer",
  "owner": { "id": 1, "name": "John", "avatar_url": null },
  "believer_name": "Alex",
  "met_at": "2026-05-14"
}
```

```json
{
  "source": "outreach",
  "testimony": "God healed three people today",
  "owner": {
    "id": 2,
    "name": "Maria",
    "avatar_url": "/uploads/avatars/user_2.jpg"
  },
  "believer_name": null,
  "met_at": null
}
```

| Field           | Type                         | Notes                                    |
| --------------- | ---------------------------- | ---------------------------------------- |
| `source`        | `"believer"` \| `"outreach"` | origin of the testimony                  |
| `testimony`     | string                       | testimony text                           |
| `owner`         | `{ id, name, avatar_url }`   | user who added it                        |
| `believer_name` | string \| null               | non-null only when `source = "believer"` |
| `met_at`        | `YYYY-MM-DD` \| null         | non-null only when `source = "believer"` |

### Summary Statistics (new)

Aggregated view combining Believer counts and Outreach Statistics totals.

| Field                         | Meaning                                                                           |
| ----------------------------- | --------------------------------------------------------------------------------- |
| `total_heard_gospel`          | `count(believers)` + `sum(gospels_told)`                                          |
| `total_saved`                 | `count(believers where stage ≠ interested)` + `sum(salvation_prayed_unreachable)` |
| `heard_gospel_no_contact`     | `sum(gospels_told)` + `count(believers with no phone AND no telegram)`            |
| `heard_gospel_has_contact`    | `count(believers with phone OR telegram)`                                         |
| `scriptures_distributed`      | `sum(scriptures_distributed)` — Раздано Евангелие от Иоана                        |
| `fathers_letters_distributed` | `sum(fathers_letters_distributed)` — Раздано Писем Отца                           |
| `healings_deliverances`       | `sum(healings_deliverances)` — Исцеления / Освобождение                           |

---

## Endpoint Contracts

### `GET /`

Response `200`:

```json
{ "status": "success" }
```

---

## Static Files

### `GET /uploads/{path}` (public)

Отдаёт загруженные файлы (аватарки и прочие медиа). Никакой авторизации не требует.

Путь формируется автоматически из поля `avatar_url` в объекте пользователя:

```
avatar_url: "/uploads/avatars/user_1_abc123.jpg"
full URL:   "http://127.0.0.1:8000/uploads/avatars/user_1_abc123.jpg"
```

То есть полный URL = `<base_url>` + `avatar_url`.

Если `avatar_url` равен `null` — у пользователя нет аватарки.

Response `200`: бинарный файл с правильным `Content-Type`.

Errors:

- `404` — файл не найден

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

Returns one `TestimonyResponse` for the day. Pools testimonies from both `Believer` records and `OutreachStatistics` records. Selection rotates daily by `day.toordinal() % pool_size`.

Response `200`: `TestimonyResponse` (see Data Models).

Errors:

- `404` — no testimonies exist in either source

### `GET /believers/testimonies` (public)

Returns all testimonies from believers and outreach statistics combined, sorted by source then id.

Response `200`: `list[TestimonyResponse]`

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

## Outreach Statistics ⚠️ REDESIGNED

> Previous endpoints `POST /outreach-statistics`, `GET /outreach-statistics/{id}`,
> `PATCH /outreach-statistics/{id}`, `DELETE /outreach-statistics/{id}` **no longer exist**.
> Remove all calls to them. See new endpoints below.

Each user now has **exactly one** cumulative record. Adding statistics accumulates values on top of the existing totals. `outreach_date` is gone.

### `GET /outreach-statistics/summary` (public)

Main screen aggregated statistics. Combines believer data and outreach statistics totals.

Query params:

- `type` — `personal` or `general` (default: `general`)
  - `personal` — only data created by the authenticated user
  - `general` — data from all users

Response `200`:

```json
{
  "total_heard_gospel": 150,
  "total_saved": 35,
  "heard_gospel_no_contact": 120,
  "heard_gospel_has_contact": 30,
  "scriptures_distributed": 45,
  "fathers_letters_distributed": 20,
  "healings_deliverances": 12
}
```

Field definitions:

| Field                         | Formula                                                                           |
| ----------------------------- | --------------------------------------------------------------------------------- |
| `total_heard_gospel`          | `count(believers)` + `sum(gospels_told)`                                          |
| `total_saved`                 | `count(believers where stage ≠ interested)` + `sum(salvation_prayed_unreachable)` |
| `heard_gospel_no_contact`     | `sum(gospels_told)` + `count(believers with no phone AND no telegram)`            |
| `heard_gospel_has_contact`    | `count(believers with phone OR telegram)`                                         |
| `scriptures_distributed`      | `sum(scriptures_distributed)` — Раздано Евангелие от Иоана                        |
| `fathers_letters_distributed` | `sum(fathers_letters_distributed)` — Раздано Писем Отца                           |
| `healings_deliverances`       | `sum(healings_deliverances)` — Исцеления / Освобождение                           |

Note: `personal` requires a valid bearer token. `general` works without auth too.

### `GET /outreach-statistics/me` (protected)

Returns the current user's single statistics record.
Auto-creates a zeroed record if none exists yet.

Response `200`:

```json
{
  "id": 1,
  "user_id": 1,
  "gospels_told": 42,
  "salvation_prayed_unreachable": 5,
  "scriptures_distributed": 20,
  "fathers_letters_distributed": 10,
  "healings_deliverances": 8,
  "testimonies": [
    { "id": 1, "text": "God healed three people today" },
    { "id": 2, "text": "Two people gave their lives to Jesus" }
  ],
  "created_at": "2026-06-01T10:00:00+00:00",
  "updated_at": "2026-06-07T14:30:00+00:00"
}
```

### `POST /outreach-statistics/add` (protected)

Accumulates values on top of the user's current totals.
Use this when the user fills in an outreach form — the new values are **added** to existing ones.
Auto-creates the record if it does not exist yet.

Request:

```json
{
  "gospels_told": 5,
  "salvation_prayed_unreachable": 1,
  "scriptures_distributed": 10,
  "fathers_letters_distributed": 3,
  "healings_deliverances": 2,
  "testimony": "God healed three people today"
}
```

Numeric fields default to `0` if omitted. `testimony` is optional — if provided, a **new entry is appended** to the user's testimonies list (not replaced).

Response `200`: OutreachStatistics record with updated totals.

### `PATCH /outreach-statistics/me` (protected)

Directly sets (overwrites) specific numeric fields on the current user's record.
Also supports deleting a single testimony by ID.
Use this for the "edit statistics" UI where the user manually corrects values or removes a testimony.

Request (all fields optional):

```json
{
  "gospels_told": 100,
  "scriptures_distributed": 50,
  "fathers_letters_distributed": 20,
  "delete_testimony_id": 3
}
```

- Numeric fields — overwrite if provided, leave unchanged if omitted.
- `delete_testimony_id` — if provided, deletes the `Testimony` record with that ID (must belong to the current user). The numeric statistics are not affected.

Response `200`: OutreachStatistics record.

Errors:

- `404` — testimony with `delete_testimony_id` not found or does not belong to current user

### `POST /outreach-statistics/reset` (protected)

Resets all counters to `0` for the current user.

No request body required.

Response `200`: OutreachStatistics record with all fields set to `0`.

### `GET /outreach-statistics/all` (public)

Returns one statistics record per user (everyone in the system).
Each record includes the full user object.

Response `200`:

```json
[
  {
    "id": 1,
    "user_id": 1,
    "gospels_told": 42,
    "salvation_prayed_unreachable": 5,
    "scriptures_distributed": 20,
    "fathers_letters_distributed": 10,
    "healings_deliverances": 8,
    "testimonies": [{ "id": 1, "text": "God healed three people today" }],
    "created_at": "2026-06-01T10:00:00+00:00",
    "updated_at": "2026-06-07T14:30:00+00:00",
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

## Breaking changes (2026-06-07)

The entire Outreach Statistics API was redesigned. If the mobile app has any of the following integrations, they must be updated:

### Removed endpoints — delete all calls

| Old endpoint                       | Replacement                       |
| ---------------------------------- | --------------------------------- |
| `POST /outreach-statistics`        | `POST /outreach-statistics/add`   |
| `GET /outreach-statistics/{id}`    | `GET /outreach-statistics/me`     |
| `PATCH /outreach-statistics/{id}`  | `PATCH /outreach-statistics/me`   |
| `DELETE /outreach-statistics/{id}` | `POST /outreach-statistics/reset` |

### Changed response shape

- `GET /outreach-statistics/me` now returns a **single object**, not an array.
- The `outreach_date` field no longer exists in any response.

### Changed data model

- Each user has exactly **one** statistics record (unique constraint on `user_id`).
- Statistics are cumulative totals, not per-event records.
- `salvation_prayed_unreachable` is included in the summary as part of `total_saved`.

### New main screen endpoint

Replace any existing stats aggregation logic on the mobile side with:

```
GET /outreach-statistics/summary?type=general   // community-wide
GET /outreach-statistics/summary?type=personal  // current user only (requires auth)
```

---

## Recommended mobile integration flow

1. Register (`POST /auth/register`) or login (`POST /auth/login`). Save `access_token` in secure storage.
2. On app start, call `GET /auth/me` to restore session.
3. Load methods (`GET /methods`) and cache them for believer creation.
4. Create and manage own believers via protected endpoints.
5. **Main screen stats**: call `GET /outreach-statistics/summary?type=general` (no auth needed). Switch to `?type=personal` for the personal tab.
6. **Add outreach results**: call `POST /outreach-statistics/add` with the form values — they accumulate into the user's running total.
7. **View own stats**: `GET /outreach-statistics/me` — returns a single record.
8. **Edit stats**: `PATCH /outreach-statistics/me` — directly set field values.
9. **Reset stats**: `POST /outreach-statistics/reset` — zeros all counters.
10. Use public endpoints for community-wide widgets:
    - `GET /believers/all` — all believers in system
    - `GET /believers/latest` — recent believers with date filter
    - `GET /believers/testimony-of-day` — daily rotating testimony
    - `GET /believers/stats/accepted-jesus-count` — total who accepted Jesus
    - `GET /outreach-statistics/all` — one record per user with user info
11. Before token expiry (7 days), call `POST /auth/refresh` with the current valid token.
    If token already expired, re-login is required.
