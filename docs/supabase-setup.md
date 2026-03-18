# Supabase Setup

This app can keep working fully locally. Supabase is optional and only used when the app is built with the required environment variables.

Official references:
- https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- https://supabase.com/docs/reference/dart/auth-signinwithotp
- https://supabase.com/docs/guides/database/postgres/row-level-security

## 1. Create a Supabase project

1. Create a new project in the Supabase dashboard.
2. Wait for the database to be provisioned.
3. Copy:
   - Project URL
   - Project API key (`anon` / publishable key)

## 2. Enable email auth

1. Open `Authentication` -> `Providers`.
2. Enable `Email`.
3. Use OTP / magic link login.
4. In `Authentication` -> `URL Configuration`, add redirect URLs for your app.

Recommended redirect URL used by the current Flutter code:

```text
io.supabase.familyeating://login-callback/
```

For web builds, also add your local/dev URL, for example:

```text
http://localhost:3000
http://localhost:8080
```

## 3. Create the database tables

Run this in the Supabase SQL editor:

```sql
create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  household_id uuid not null references public.households (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

create table if not exists public.household_invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  code text not null unique,
  created_by uuid not null references auth.users (id) on delete cascade,
  expires_at timestamptz,
  used_by uuid references auth.users (id) on delete set null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.household_snapshots (
  household_id uuid primary key references public.households (id) on delete cascade,
  data_json jsonb not null,
  version bigint not null default 1,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null
);
```

## 4. Enable Row Level Security

Run:

```sql
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_invites enable row level security;
alter table public.household_snapshots enable row level security;
```

## 5. Add minimal RLS policies

Run:

```sql
create policy "members can read households"
on public.households
for select
to authenticated
using (
  exists (
    select 1
    from public.household_members members
    where members.household_id = households.id
      and members.user_id = auth.uid()
  )
);

create policy "authenticated users can create households"
on public.households
for insert
to authenticated
with check (created_by = auth.uid());

create policy "members can read household members"
on public.household_members
for select
to authenticated
using (
  exists (
    select 1
    from public.household_members members
    where members.household_id = household_members.household_id
      and members.user_id = auth.uid()
  )
);

create policy "authenticated users can add themselves to a household"
on public.household_members
for insert
to authenticated
with check (user_id = auth.uid());

create policy "members can read invites"
on public.household_invites
for select
to authenticated
using (
  exists (
    select 1
    from public.household_members members
    where members.household_id = household_invites.household_id
      and members.user_id = auth.uid()
  )
);

create policy "members can create invites"
on public.household_invites
for insert
to authenticated
with check (
  created_by = auth.uid()
  and exists (
    select 1
    from public.household_members members
    where members.household_id = household_invites.household_id
      and members.user_id = auth.uid()
  )
);

create policy "members can read snapshots"
on public.household_snapshots
for select
to authenticated
using (
  exists (
    select 1
    from public.household_members members
    where members.household_id = household_snapshots.household_id
      and members.user_id = auth.uid()
  )
);

create policy "members can write snapshots"
on public.household_snapshots
for insert
to authenticated
with check (
  exists (
    select 1
    from public.household_members members
    where members.household_id = household_snapshots.household_id
      and members.user_id = auth.uid()
  )
);

create policy "members can update snapshots"
on public.household_snapshots
for update
to authenticated
using (
  exists (
    select 1
    from public.household_members members
    where members.household_id = household_snapshots.household_id
      and members.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.household_members members
    where members.household_id = household_snapshots.household_id
      and members.user_id = auth.uid()
  )
);
```

## 6. Build the app with Supabase enabled

Use `--dart-define` values when running or building:

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_PROJECT_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=SUPABASE_REDIRECT_URL=io.supabase.familyeating://login-callback/
```

Without these defines, the app stays in local-only mode.

## 7. Use the in-app flow

1. Open the cloud icon in the app bar.
2. Enter email and request a sign-in link.
3. Open the email link on the same device.
4. Create a household.
5. Use `Create invite code` and share the code with the other person.
6. On the second device, sign in and use `Join household` with that code.
7. Once a household is active, local saves will also push a shared household snapshot.

## 8. What is implemented right now

Current code supports:
- Optional Supabase initialization
- Email OTP sign-in
- Create household
- Create invite codes in the app
- Join household by invite code
- Pull latest household snapshot on app load
- Push the full app snapshot after local saves

Current limitations:
- Snapshot sync uses a simple whole-document overwrite strategy
- No conflict-resolution UI beyond local-first reloads
