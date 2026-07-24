-- ════════════════════════════════════════════════════════════════
-- Lead Management Platform — database schema
-- Idempotent: safe to run repeatedly (CREATE ... IF NOT EXISTS).
-- ════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;  -- for gen_random_uuid()

-- ── users ───────────────────────────────────────────────────────
create table if not exists users (
  id            uuid primary key default gen_random_uuid(),
  email         text unique not null,
  password_hash text not null,
  name          text not null,
  role          text not null check (role in ('admin', 'member')),
  created_at    timestamptz not null default now()
);

-- ── leads ───────────────────────────────────────────────────────
create table if not exists leads (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  email       text not null,
  phone       text,
  company     text,
  source      text,
  status      text not null default 'new'
                check (status in ('new','contacted','qualified','proposal','won','lost')),
  assigned_to uuid references users(id) on delete set null,
  created_by  uuid references users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_leads_status      on leads(status);
create index if not exists idx_leads_assigned_to  on leads(assigned_to);
create index if not exists idx_leads_created_at    on leads(created_at desc);

-- ── lead_notes (timestamped notes) ──────────────────────────────
create table if not exists lead_notes (
  id         uuid primary key default gen_random_uuid(),
  lead_id    uuid not null references leads(id) on delete cascade,
  author_id  uuid references users(id) on delete set null,
  body       text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_notes_lead on lead_notes(lead_id, created_at desc);

-- ── activities (activity trail / audit log) ─────────────────────
create table if not exists activities (
  id         uuid primary key default gen_random_uuid(),
  lead_id    uuid not null references leads(id) on delete cascade,
  actor_id   uuid references users(id) on delete set null,
  type       text not null
               check (type in ('created','status_changed','assigned','note_added','updated')),
  metadata   jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_activities_lead on activities(lead_id, created_at desc);
