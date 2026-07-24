# Lead Management Platform

A lead-management application a small sales team could actually use: a **public
lead-capture form** plus an **authenticated app** with **admin** and **member**
roles, a full **lead lifecycle** (status pipeline, assignment, timestamped
notes, activity trail), and a **documented JSON API** with pagination and
filtering.

Built as **one coherent product, end-to-end Dart**:

| Layer    | Tech                                                    |
|----------|---------------------------------------------------------|
| Frontend | Flutter Web · Riverpod · go_router                      |
| API      | Dart Frog — JSON API, self-managed JWT auth (bcrypt)    |
| Database | Postgres (Supabase)                                     |

```
Flutter Web  ──HTTPS / JSON──▶  Dart Frog API  ──▶  Postgres
 role-based UI                  JWT + role guards      (data)
```

Permissions are enforced **on both the client and the server**. The Flutter app
hides controls a role may not use; the API independently rejects unauthorized
requests — the server is the source of truth.

---

## Live demo & credentials

| | URL |
|---|---|
| **App (Flutter web)** | _added after deployment_ |
| **API** | _added after deployment_ |

| Role | Email | Password |
|------|-------|----------|
| Admin | `admin@demo.test` | `Admin123!` |
| Member | `member@demo.test` | `Member123!` |

> The public capture form is the app's landing page (`/`). "Team login" (top
> right) leads to the authenticated app.

---

## Repository layout

```
lead-platform/
├── backend/                 # Dart Frog API
│   ├── db/schema.sql        # database schema (idempotent)
│   ├── bin/
│   │   ├── migrate.dart     # apply schema
│   │   └── seed.dart        # seed demo users + sample leads
│   ├── lib/src/
│   │   ├── config/          # env loading
│   │   ├── db/              # connection pool
│   │   ├── models/          # User, Lead, Note, Activity
│   │   ├── repositories/    # data access
│   │   ├── services/        # transactional lead operations
│   │   ├── auth/            # JWT, password hashing, principals, access rules
│   │   └── http/            # error type, guards, request/response helpers
│   ├── routes/              # file-based API routes (see below)
│   └── test/                # auth-rule + core-flow integration tests
├── frontend/                # Flutter web client
│   ├── lib/src/
│   │   ├── api/             # ApiClient + typed ApiService
│   │   ├── models.dart
│   │   ├── state/           # Riverpod auth controller
│   │   └── pages/           # capture, login, leads, detail, users
│   └── test/                # widget + model tests
└── .github/workflows/ci.yaml
```

---

## Data model

```
users                     leads                         lead_notes
─────                     ─────                         ──────────
id (uuid, pk)             id (uuid, pk)                 id (uuid, pk)
email (unique)            name, email, phone,           lead_id  → leads (cascade)
password_hash               company, source             author_id→ users (set null)
name                      status  (enum, see below)     body
role  (admin|member)      assigned_to → users           created_at
created_at                created_by  → users
                          created_at, updated_at        activities
                                                        ──────────
                                                        id (uuid, pk)
                                                        lead_id  → leads (cascade)
                                                        actor_id → users (set null)
                                                        type (enum)
                                                        metadata (jsonb)
                                                        created_at
```

**Status pipeline:** `new → contacted → qualified → proposal → won / lost`

**Activity types:** `created`, `status_changed`, `assigned`, `note_added`,
`updated`. Every lead mutation writes an activity row in the **same transaction**
as the change, so the trail can never drift from the data.

Schema: [`backend/db/schema.sql`](backend/db/schema.sql).

---

## Permission model

| Action | Public | Member | Admin |
|---|:--:|:--:|:--:|
| Submit capture form (`POST /leads`) | ✅ | ✅ | ✅ |
| List leads | ❌ | own assigned only | all |
| View a lead / its notes / activity | ❌ | if assigned | any |
| Change status · add note | ❌ | if assigned | any |
| Assign / reassign a lead | ❌ | ❌ | ✅ |
| Delete a lead | ❌ | ❌ | ✅ |
| List / create users | ❌ | ❌ | ✅ |

Members are scoped to their own leads at the query level: `GET /leads` ignores
any `assigned_to` a member supplies and always filters to themselves. Accessing
a lead that exists but isn't theirs returns **403**; a lead that doesn't exist
returns **404**.

---

## API documentation

Base URL: the deployed API root (local: `http://localhost:8080`).
All responses are JSON. Authenticated requests send `Authorization: Bearer <token>`.

### Conventions

**Auth:** obtain a token from `POST /auth/login`, then send it as a bearer token.

**Pagination** (list endpoints) returns:

```json
{
  "data": [ /* items */ ],
  "pagination": { "page": 1, "limit": 20, "total": 57, "totalPages": 3 }
}
```

**Errors** use a consistent envelope:

```json
{ "error": { "message": "You do not have permission to perform this action", "code": "forbidden" } }
```

**Status codes**

| Code | Meaning |
|------|---------|
| 200 | OK |
| 201 | Created |
| 204 | No content (successful delete) |
| 400 | Validation error / malformed JSON |
| 401 | Missing or invalid token |
| 403 | Authenticated but not allowed |
| 404 | Resource not found |
| 405 | Method not allowed |
| 409 | Conflict (e.g. duplicate email) |
| 500 | Unexpected server error |

### Endpoints

| Method | Path | Auth | Success |
|--------|------|------|---------|
| `POST` | `/auth/login` | public | 200 |
| `GET` | `/auth/me` | any | 200 |
| `POST` | `/leads` | public | 201 |
| `GET` | `/leads` | member/admin | 200 |
| `GET` | `/leads/:id` | member(if assigned)/admin | 200 |
| `PATCH` | `/leads/:id` | member(if assigned)/admin | 200 |
| `POST` | `/leads/:id/assign` | admin | 200 |
| `DELETE` | `/leads/:id` | admin | 204 |
| `GET` | `/leads/:id/notes` | member(if assigned)/admin | 200 |
| `POST` | `/leads/:id/notes` | member(if assigned)/admin | 201 |
| `GET` | `/leads/:id/activities` | member(if assigned)/admin | 200 |
| `GET` | `/users` | admin | 200 |
| `POST` | `/users` | admin | 201 |

#### `POST /auth/login`
```json
// request
{ "email": "admin@demo.test", "password": "Admin123!" }
// 200
{ "token": "eyJhbG..._jwt", "user": { "id": "...", "email": "...", "name": "...", "role": "admin", "createdAt": "..." } }
```
`401` on unknown email or wrong password (identical response for both).

#### `POST /leads`  (public capture)
```json
// request
{ "name": "Jane Buyer", "email": "jane@acme.io", "phone": "555-0100", "company": "Acme", "source": "public_form" }
// 201
{ "lead": { "id": "...", "status": "new", "assignedTo": null, "createdBy": null, "...": "..." } }
```
`400` if `name` is empty or `email` is invalid.

#### `GET /leads`  (list — paginated & filterable)
Query params:

| Param | Example | Notes |
|-------|---------|-------|
| `page` | `2` | default `1` |
| `limit` | `50` | default `20`, max `100` |
| `status` | `contacted` | one of the pipeline values |
| `q` | `acme` | search over name, email, company |
| `assigned_to` | `<userId>` | **admin only**; ignored for members |

```
GET /leads?status=contacted&q=acme&page=1&limit=20
```
Returns the pagination envelope above with `data: Lead[]`.

#### `PATCH /leads/:id`
Body may include any of `name`, `email`, `phone`, `company`, `source`, `status`.
Changing `status` records a `status_changed` activity with `{from, to}`.
```json
{ "status": "qualified" }   // -> 200 { "lead": { ... } }
```

#### `POST /leads/:id/assign`  (admin)
```json
{ "userId": "<uuid>" }   // or { "userId": null } to unassign  -> 200 { "lead": { ... } }
```

#### `POST /leads/:id/notes`
```json
{ "body": "Left a voicemail." }   // -> 201 { "note": { "id": "...", "authorName": "...", "createdAt": "..." } }
```

#### `POST /users`  (admin)
```json
{ "email": "sam@team.io", "name": "Sam", "password": "secret123", "role": "member" }
// 201 { "user": { ... } }  ·  409 if the email already exists
```

---

## Local development

**Prerequisites:** Flutter (Dart ≥ 3.11), and a Postgres database. The quickest
local database is Docker:

```bash
docker run -d --name leadapp-pg \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=leadapp \
  -p 5433:5432 postgres:16
```

### Backend

```bash
cd backend
cp .env.example .env          # then edit DATABASE_URL + JWT_SECRET
dart pub get
dart run bin/migrate.dart     # create tables
dart run bin/seed.dart        # seed demo users + sample leads
dart_frog dev                 # serves http://localhost:8080
```

For the Docker database above, set in `.env`:
```
DATABASE_URL=postgresql://postgres:postgres@localhost:5433/leadapp
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

---

## Tests

### Backend (integration — auth rules + two core flows)

Runs against a disposable Postgres pointed to by `TEST_DATABASE_URL`; the schema
is applied automatically and tables are truncated between tests.

```bash
cd backend
export TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5433/leadapp
dart test
```

Coverage:
- **Auth rules** — login success/failure (401); protected route without a token
  (401); member hitting an admin-only route (403); a member accessing a lead
  assigned to someone else (403) while the assignee and admins can (200);
  member list scoping.
- **Core flow 1** — public capture creates a `new` lead and logs a `created`
  activity.
- **Core flow 2** — admin assigns → member changes status → adds a note, and the
  activity trail records `created → assigned → status_changed → note_added`.

### Frontend (widget + model)

```bash
cd frontend
flutter test
```

Both suites run in CI on every push — see
[`.github/workflows/ci.yaml`](.github/workflows/ci.yaml) (Postgres service
container for the backend).

---

## Deployment

- **Database** — a Supabase Postgres project. Apply the schema and seed once
  with `dart run bin/migrate.dart` / `bin/seed.dart` against the project URL.
- **Backend** — Fly.io free tier (`dart_frog build` produces a Docker image).
  Set `DATABASE_URL` (use Supabase's **transaction pooler** string), `JWT_SECRET`
  and `CORS_ORIGINS` (your frontend URL) as secrets.
- **Frontend** — `flutter build web --dart-define=API_BASE_URL=https://<api-host>`
  and deploy the static `build/web` folder to Cloudflare Pages / Netlify.

Detailed, copy-pasteable deploy steps are added here once the app is live.

## Environment variables (backend)

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | Postgres connection string |
| `JWT_SECRET` | secret used to sign JWTs |
| `JWT_EXPIRES_MINUTES` | token lifetime (default 720) |
| `PORT` | server port (default 8080) |
| `CORS_ORIGINS` | comma-separated allowed origins, or `*` |
