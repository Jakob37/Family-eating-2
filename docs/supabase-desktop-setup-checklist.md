# Supabase Desktop Setup Checklist

Use this when continuing Supabase setup from a desktop browser.

## 1. Collect project values

In the Supabase dashboard, copy:

- `Project URL`
- `Publishable key`

Depending on the current dashboard UI, these are usually under either:

- `Connect`
- `Settings > API Keys`

The project URL should look like:

```text
https://YOUR_PROJECT_ID.supabase.co
```

## 2. Enable email sign-in

Go to:

- `Authentication > Providers`

Enable:

- `Email`

Keep passwordless email sign-in enabled.

## 3. Add the mobile redirect URL

Go to:

- `Authentication > URL Configuration`

Add this redirect URL exactly:

```text
io.supabase.familyeating://login-callback/
```

## 4. Create the database tables

Open:

- `SQL Editor`

Run this SQL:

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

## 5. Enable Row Level Security

Run:

```sql
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_invites enable row level security;
alter table public.household_snapshots enable row level security;
```

## 6. Add RLS policies

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

## 7. Enable Realtime for snapshots

Run:

```sql
alter publication supabase_realtime add table public.household_snapshots;
```

## 8. Add local Flutter config

Create a local file in the repo root named `supabase.dev.json`:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_ID.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_PUBLISHABLE_KEY",
  "SUPABASE_REDIRECT_URL": "io.supabase.familyeating://login-callback/"
}
```

## 9. Run the app with Supabase enabled

```bash
flutter run --dart-define-from-file=supabase.dev.json
```

## 10. Test the first account

In the app:

- Open `Settings`
- Open `Cloud & sync`
- Enter your email
- Tap `Send sign-in link`
- Open the email link on the same phone
- Return to the app
- Create a household

## 11. Test the second account

On the first device:

- Open `Settings > Cloud & sync`
- Tap `Create invite code`

On the second device:

- Sign in with email
- Use `Join household`
- Enter the invite code

## 12. If something fails

Capture the exact SQL error or auth error and continue from there. The most likely setup issues are:

- wrong redirect URL
- missing RLS policies
- missing Realtime publication on `household_snapshots`
- app launched without `--dart-define-from-file=supabase.dev.json`
