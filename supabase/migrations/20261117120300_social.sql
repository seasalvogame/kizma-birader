-- Kızma Birader — 4/4 social: friendships, friend requests, blocks,
-- notifications (inbox) and the safe public profile card RPC.
-- Writes (requests, accept, block, invites) come in Phase 4 as game.* functions;
-- clients only read their own rows here. Realtime channels: Phase 4.

create table public.friendships (
  user_low   uuid not null references auth.users (id) on delete cascade,
  user_high  uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_low, user_high),
  check (user_low < user_high)                 -- one row per pair
);
create index friendships_high_idx on public.friendships (user_high);

create table public.friend_requests (
  id           bigint generated always as identity primary key,
  from_id      uuid not null references auth.users (id) on delete cascade,
  to_id        uuid not null references auth.users (id) on delete cascade,
  status       text not null check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  check (from_id <> to_id)
);
create unique index friend_requests_pending_uq on public.friend_requests (from_id, to_id) where status = 'pending';
create index friend_requests_to_idx on public.friend_requests (to_id, status);

create table public.blocks (
  blocker_id uuid not null references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index blocks_blocked_idx on public.blocks (blocked_id);

create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null check (kind in ('friend_request', 'friend_accepted', 'invite', 'reward_ready', 'system')),
  payload    jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at    timestamptz
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

alter table public.friendships enable row level security;
alter table public.friend_requests enable row level security;
alter table public.blocks enable row level security;
alter table public.notifications enable row level security;
create policy friendships_read_member on public.friendships for select to authenticated
  using ((select auth.uid()) in (user_low, user_high));
create policy friend_requests_read_party on public.friend_requests for select to authenticated
  using ((select auth.uid()) in (from_id, to_id));
-- Only blocks I made are visible; who blocked me is never visible.
create policy blocks_read_own on public.blocks for select to authenticated
  using (blocker_id = (select auth.uid()));
create policy notifications_read_own on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.friendships, public.friend_requests, public.blocks, public.notifications from anon, authenticated;
grant select on public.friendships, public.friend_requests, public.blocks, public.notifications to authenticated;

-- Other players' profiles: only safe columns, at most 100 ids, and never a user
-- who blocked the caller or whom the caller blocked (DATABASE_SCHEMA §4).
create or replace function public.get_profile_cards(p_ids uuid[])
returns table (user_id uuid, display_name text, tag int, avatar_id text, frame_id text, level int)
language sql
stable
security definer
set search_path = ''
as $$
  select p.user_id, p.display_name, p.tag, p.avatar_id, p.frame_id, p.level
    from public.profiles p
   where (select auth.uid()) is not null
     and cardinality(p_ids) <= 100
     and p.user_id = any(p_ids)
     and not exists (
       select 1 from public.blocks b
        where (b.blocker_id = p.user_id and b.blocked_id = (select auth.uid()))
           or (b.blocker_id = (select auth.uid()) and b.blocked_id = p.user_id));
$$;
revoke all on function public.get_profile_cards(uuid[]) from public, anon;
grant execute on function public.get_profile_cards(uuid[]) to authenticated;
