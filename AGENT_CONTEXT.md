# AGENT CONTEXT (Time To Go)

This file captures the current implementation context for future agents.

## Project Overview

- App: Christian evangelism app **Time To Go / Время идти**.
- Stack: Flutter (single large file `lib/main.dart` + API client `lib/backend_api.dart`).
- Persistence:
  - Local: `SharedPreferences`.
  - Remote: custom backend from `API_AGENT_GUIDE.md`.

## Backend Integration Status

- Base URL source:
  - `API_BASE_URL` via `--dart-define`.
  - fallback: `http://127.0.0.1:8000`.
- Token handling:
  - stored in `SharedPreferences` key `api_access_token_v1`.
  - auth screen supports login/register.
- Implemented endpoints in `BackendApi`:
  - `GET /`
  - `POST /auth/register`
  - `POST /auth/login`
  - `POST /auth/refresh`
  - `GET /auth/me`
  - `PATCH /auth/me`
  - `POST /auth/me/avatar`
  - `GET /methods`
  - `POST /methods`
  - `POST /believers`
  - `GET /believers/my`
  - `PATCH /believers/{id}`
  - `DELETE /believers/{id}`
  - `GET /believers/all`
  - `GET /believers/latest`
  - `GET /believers/testimony-of-day`
  - `GET /believers/stats/accepted-jesus-count`

## Main UX Decisions Already Implemented

- `Home` tab redesigned:
  - shows only:
    - Testimony of the day,
    - total people heard gospel (global),
    - people accepted Jesus (global).
  - no old dashboard sections/recent cards.
- Global stats on Home use only public backend data.
- Profile tab redesigned:
  - now account-focused (server profile), old local profile UI removed from flow.
  - if not authenticated: prompt to sign in.
  - if authenticated: shows account info from `/auth/me`.
  - sign out button includes confirmation dialog.
  - account edit flow exists (name/about/avatar upload).

## Believer Model / Forms

- `NewBeliever` includes:
  - `name`, `telegram`, `phone`, `note`, `testimony`,
  - `evangelismMethod`, `customEvangelismMethod`,
  - stage/date/location fields.
- Telegram/phone are optional (only name required).
- Add believer form contains separate `testimony` field.
- Believer payload sends `testimony` to backend.
- Card and map preview display testimony text.
- Map preview intentionally hides telegram/phone for privacy.

## Sync Behavior

- If user registers from app:
  - local believers are migrated to server (best effort).
- If user logs in:
  - local list is replaced by server list.
- CRUD sync:
  - create/update stage/delete attempt backend sync, with local fallback.

## App Naming / Icons

- App icon generated from `assets/time_to_go_icon.png`.
- Display names:
  - RU: `Время идти`
  - non-RU: `Time To Go`

## Current Technical Caveats

- `lib/main.dart` is still very large and should be modularized later.
- `flutter analyze` currently reports many info-level deprecation warnings (`withOpacity`, some form `value` usage), mostly pre-existing style debt.
- Workspace is not a git repo (`git` ops not applicable in this folder).

## Useful Files

- Backend contract: `API_AGENT_GUIDE.md`
- API client: `lib/backend_api.dart`
- Main app/UI logic: `lib/main.dart`
- Dependency config: `pubspec.yaml`
