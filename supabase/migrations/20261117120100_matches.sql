-- Kızma Birader — 2/4 match records (written only by the game server through
-- game.start_match / game.finish_match / game.void_match, see 3/4).

create table public.matches (
  id                     uuid primary key,                 -- same id as the MatchRoom Durable Object
  mode                   text not null check (mode in ('quick', 'private')),
  players                int  not null check (players in (2, 4)),
  ruleset                jsonb not null,
  economy_tier           text not null default 'free',
  entry_fee              bigint not null default 0 check (entry_fee >= 0),   -- gold only (Gems never)
  economy_config_version int,
  status                 text not null check (status in ('playing', 'finished', 'void')),
  started_at             timestamptz not null default now(),
  ended_at               timestamptz,
  end_reason             text,
  actions                text          -- compact action log (r6 m0 ...), replayable (COST_AND_SCALING §4)
);
create index matches_playing_idx on public.matches (started_at) where status = 'playing';

create table public.match_players (
  match_id    uuid not null references public.matches (id) on delete cascade,
  seat        int  not null check (seat between 0 and 3),
  user_id     uuid references auth.users (id) on delete set null,   -- null: bot, or deleted account
  color       text not null check (color in ('red', 'green', 'yellow', 'blue')),
  is_bot      boolean not null default false,
  rank        int check (rank between 1 and 4),
  left_match  boolean not null default false,
  payout      bigint not null default 0 check (payout >= 0),
  primary key (match_id, seat),
  unique (match_id, color)
);
create index match_players_user_idx on public.match_players (user_id, match_id);

-- RLS helper: is the current user a player of this match? SECURITY DEFINER so
-- that the policy on match_players does not recurse into itself.
create or replace function app_private.is_match_participant(p_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.match_players mp
    where mp.match_id = p_match_id and mp.user_id = (select auth.uid())
  );
$$;
revoke all on function app_private.is_match_participant(uuid) from public;
grant execute on function app_private.is_match_participant(uuid) to authenticated;

alter table public.matches enable row level security;
create policy matches_read_participant on public.matches
  for select to authenticated using (app_private.is_match_participant(id));

alter table public.match_players enable row level security;
create policy match_players_read_participant on public.match_players
  for select to authenticated using (app_private.is_match_participant(match_id));

revoke all on public.matches, public.match_players from anon, authenticated;
grant select on public.matches, public.match_players to authenticated;
