# Lead Management Platform

A small lead-management application a sales team could actually use: a public
lead-capture form plus an authenticated app with **admin** and **member** roles,
a full lead lifecycle (status pipeline, assignment, timestamped notes, activity
trail), and a documented JSON API.

**One coherent product, end-to-end Dart:**

| Layer    | Tech                                             |
|----------|--------------------------------------------------|
| Frontend | Flutter Web (Riverpod)                           |
| API      | Dart Frog — JSON API, self-managed JWT auth      |
| Database | Supabase Postgres                                |

```
Flutter Web  ──HTTPS/JSON──▶  Dart Frog API  ──▶  Supabase Postgres
 role-based UI                JWT + role guards       (data)
```

## Repository layout

```
lead-platform/
├── backend/    # Dart Frog API (auth, leads, notes, activities)
├── frontend/   # Flutter web client
└── README.md
```

## Status

🚧 Under construction — see build progress. Sections below are filled in as the
project is completed.

## Live demo & credentials

_TBD — added after deployment._

## Local development

_TBD._

## API documentation

_TBD._

## Permission model

_TBD._

## Tests

_TBD._

## Deployment

_TBD._
