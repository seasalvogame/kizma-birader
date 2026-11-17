-- Kızma Birader — 1/4 foundation: schemas, restricted game-server role,
-- server-managed configuration, player profiles and stats.
--
-- Security model (docs/architecture/SUPABASE_ARCHITECTURE.md, SECURITY_ARCHITECTURE.md):
--   * Clients (anon / authenticated) can only READ, and only their own rows (RLS).
--   * Every write goes through SECURITY DEFINER functions in schema `game`,
--     which only the restricted role `game_server` may call (K-59).
--   * The service role key is not used by the game.

-- ---------------------------------------------------------------- schemas
-- `game`: server-only functions (not exposed by the Data API).
create schema if not exists game;
revoke all on schema game from public;

-- `app_private`: helper functions used inside RLS policies (not exposed by the
-- Data API, but callable from policies evaluated for authenticated users).
create schema if not exists app_private;
revoke all on schema app_private from public;
grant usage on schema app_private to authenticated;

-- ------------------------------------------------- restricted server role (K-59)
-- Created WITHOUT login. When the Cloudflare server is connected (Phase 3.3),
-- the user enables LOGIN and sets the password in their own terminal or the
-- dashboard SQL editor; the password never appears in the repository.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'game_server') then
    create role game_server nologin noinherit;
  end if;
end
$$;
grant usage on schema game to game_server;
-- Allows `set role game_server` from the SQL console (tests, administration).
grant game_server to postgres;

-- New objects in public must not be readable or writable by clients unless
-- granted explicitly below (Supabase grants them by default).
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on functions from anon, authenticated, public;
alter default privileges for role postgres in schema game revoke all on functions from public;
alter default privileges for role postgres in schema app_private revoke all on functions from public;

-- --------------------------------------------------------- configuration
-- Server-managed values (no hard-coded economy numbers, GOLD_AND_DIAMOND_ECONOMY §3).
create table public.app_config (
  key        text primary key,
  value      jsonb not null,
  is_public  boolean not null default false,   -- readable by clients
  version    int not null default 1,
  updated_at timestamptz not null default now()
);
alter table public.app_config enable row level security;
create policy app_config_read_public on public.app_config
  for select to anon, authenticated using (is_public);

-- Development defaults (shared/config/economy_config.example.json). Not final values.
insert into public.app_config (key, value, is_public) values
  ('economy', '{
     "version": 1, "rake_percent": 10, "starting_gold": 1000, "daily_free_gold": 300,
     "bailout": {"below_gold": 100, "amount": 200, "per_day": 2},
     "tiers": [
       {"id": "lobby_100",  "entry_gold": 100,  "players": [2, 4], "shares_2p": [10000, 0], "shares_4p": [6000, 3000, 1000, 0], "min_level": 0,  "enabled": true},
       {"id": "lobby_500",  "entry_gold": 500,  "players": [2, 4], "shares_2p": [10000, 0], "shares_4p": [6000, 3000, 1000, 0], "min_level": 5,  "enabled": true},
       {"id": "lobby_2500", "entry_gold": 2500, "players": [2, 4], "shares_2p": [10000, 0], "shares_4p": [6000, 3000, 1000, 0], "min_level": 15, "enabled": true}
     ]}'::jsonb, true),
  -- Gold-entry matches stay OFF until the legal / store review (E-7, RISK_GOLD_ENTRY_MATCHES §5).
  ('features', '{"gold_matches_enabled": false, "store_enabled": false}'::jsonb, true)
on conflict (key) do nothing;

-- -------------------------------------------------------------- profiles
create table public.profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 3 and 16),
  tag          int  not null check (tag between 1000 and 99999),   -- Ayşe#4821 (K-46)
  avatar_id    text not null default 'default',
  frame_id     text,
  level        int    not null default 1 check (level >= 1),
  xp           bigint not null default 0 check (xp >= 0),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create unique index profiles_name_tag_uq on public.profiles (lower(display_name), tag);
alter table public.profiles enable row level security;
create policy profiles_read_own on public.profiles
  for select to authenticated using (user_id = (select auth.uid()));

create table public.player_stats (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  matches_2p   int not null default 0 check (matches_2p >= 0),
  wins_2p      int not null default 0 check (wins_2p >= 0),
  matches_4p   int not null default 0 check (matches_4p >= 0),
  wins_4p      int not null default 0 check (wins_4p >= 0),
  leaves       int not null default 0 check (leaves >= 0),
  updated_at   timestamptz not null default now()
);
alter table public.player_stats enable row level security;
create policy player_stats_read_own on public.player_stats
  for select to authenticated using (user_id = (select auth.uid()));

-- Clients read only; no client write privilege at all.
revoke all on public.app_config, public.profiles, public.player_stats from anon, authenticated;
grant select on public.app_config to anon, authenticated;
grant select on public.profiles, public.player_stats to authenticated;
