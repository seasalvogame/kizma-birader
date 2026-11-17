-- Kızma Birader — Phase 6.1: XP and levels.
--
-- XP is granted ONLY by the server, in the same transaction that records a finished
-- online match (game.record_match -> game._after_match), once per player and match
-- (unique key in xp_events). The amount depends on mode, player count and place —
-- never on match length — and a player who left gets nothing. Test matches and
-- offline practice give no XP. Level-ups grant gold through the wallet ledger
-- (game._apply, idempotency key per level) and unlock badges (player_unlocks).
-- All numbers live in app_config 'progression' (source: shared/config/progression_config.json).

-- --------------------------------------------------------------- configuration
insert into public.app_config (key, value, is_public) values ('progression', '{
  "version": 1,
  "xp": {
    "quick_2p": [40, 15],
    "quick_4p": [50, 35, 25, 15],
    "private_percent": 50,
    "left": 0
  },
  "level_curve": {"base": 100, "step": 25, "flat_from": 50, "max_level": 100},
  "level_gold": {"base": 50, "per_level": 10, "max": 300},
  "level_unlocks": {
    "5":   [{"kind": "badge", "id": "level_5"}],
    "10":  [{"kind": "badge", "id": "level_10"}],
    "25":  [{"kind": "badge", "id": "level_25"}],
    "50":  [{"kind": "badge", "id": "level_50"}],
    "100": [{"kind": "badge", "id": "level_100"}]
  }
}'::jsonb, true)
on conflict (key) do update set value = excluded.value, version = public.app_config.version + 1, updated_at = now();

-- ---------------------------------------------------------------------- tables
-- XP ledger: one row per (player, match, reason) -> a match never gives XP twice.
create table public.xp_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  amount      int not null check (amount > 0),
  reason      text not null check (reason in ('match', 'quest', 'achievement', 'daily_login', 'admin_adjust')),
  ref_id      text not null,                      -- match id, quest id, ...
  level_after int not null,
  created_at  timestamptz not null default now(),
  unique (user_id, reason, ref_id)
);
create index xp_events_user_idx on public.xp_events (user_id, created_at desc);

-- Badges and (later) cosmetics a player has unlocked. Items without content yet are
-- only recorded; there is no store and nothing to buy.
create table public.player_unlocks (
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null check (kind in ('badge', 'avatar', 'frame', 'dice', 'pawns', 'board')),
  item_id    text not null,
  source     text not null,                       -- 'level:10', 'achievement:first_win', ...
  created_at timestamptz not null default now(),
  primary key (user_id, kind, item_id)
);

alter table public.match_players
  add column rolls    int not null default 0,     -- dice the player rolled (not auto rolls)
  add column sixes    int not null default 0,
  add column captures int not null default 0,
  add column finished int not null default 0,     -- pawns brought home
  add column xp_gained int not null default 0,
  add column level_after int;

alter table public.xp_events enable row level security;
alter table public.player_unlocks enable row level security;
create policy xp_events_read_own on public.xp_events for select to authenticated using (user_id = (select auth.uid()));
create policy player_unlocks_read_own on public.player_unlocks for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.xp_events, public.player_unlocks from anon, authenticated;
grant select on public.xp_events, public.player_unlocks to authenticated;

-- ---------------------------------------------------------------- level curve
-- XP needed to go from level L to L+1: base + step*(L-1), constant from `flat_from` on.
create or replace function app_private.xp_to_next(p_level int, p_cfg jsonb)
returns int language sql immutable set search_path = '' as $$
  select (p_cfg->'level_curve'->>'base')::int
       + (p_cfg->'level_curve'->>'step')::int
         * (least(p_level, (p_cfg->'level_curve'->>'flat_from')::int) - 1);
$$;

-- Total XP at which a level starts (level 1 = 0).
create or replace function app_private.xp_at_level(p_level int, p_cfg jsonb)
returns bigint language sql immutable set search_path = '' as $$
  select coalesce(sum(app_private.xp_to_next(l, p_cfg)), 0)::bigint from generate_series(1, p_level - 1) l;
$$;

create or replace function app_private.level_for_xp(p_xp bigint, p_cfg jsonb)
returns int language plpgsql immutable set search_path = '' as $$
declare
  v_level int := 1;
  v_total bigint := 0;
  v_max int := (p_cfg->'level_curve'->>'max_level')::int;
begin
  loop
    exit when v_level >= v_max;
    exit when v_total + app_private.xp_to_next(v_level, p_cfg) > p_xp;
    v_total := v_total + app_private.xp_to_next(v_level, p_cfg);
    v_level := v_level + 1;
  end loop;
  return v_level;
end;
$$;

revoke all on function app_private.xp_to_next(int, jsonb), app_private.xp_at_level(int, jsonb),
  app_private.level_for_xp(bigint, jsonb) from public, anon, authenticated;

-- ------------------------------------------------------------------ granting XP
-- Adds XP once per (user, reason, ref); level-ups pay gold (ledger) and unlock badges.
-- Returns {xp, level_before, level_after, gold}.
create or replace function game._grant_xp(p_user uuid, p_amount int, p_reason text, p_ref text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_cfg jsonb := (select value from public.app_config where key = 'progression');
  v_before int;
  v_xp bigint;
  v_after int;
  v_gold bigint := 0;
  v_amount bigint;
  u jsonb;
begin
  if p_amount is null or p_amount <= 0 then
    select level into v_before from public.profiles where user_id = p_user;
    return jsonb_build_object('xp', 0, 'level_before', v_before, 'level_after', v_before, 'gold', 0);
  end if;
  select level, xp into v_before, v_xp from public.profiles where user_id = p_user for update;
  if not found then raise exception 'UNKNOWN_PLAYER'; end if;
  v_xp := v_xp + p_amount;
  v_after := app_private.level_for_xp(v_xp, v_cfg);
  insert into public.xp_events (user_id, amount, reason, ref_id, level_after)
  values (p_user, p_amount, p_reason, p_ref, v_after)
  on conflict (user_id, reason, ref_id) do nothing;
  if not found then                                   -- already granted for this ref
    return jsonb_build_object('xp', 0, 'level_before', v_before, 'level_after', v_before, 'gold', 0);
  end if;
  update public.profiles set xp = v_xp, level = greatest(level, v_after), updated_at = now() where user_id = p_user;
  for l in v_before + 1 .. v_after loop
    v_amount := least((v_cfg->'level_gold'->>'max')::int,
                      (v_cfg->'level_gold'->>'base')::int + (v_cfg->'level_gold'->>'per_level')::int * l);
    if v_amount > 0 then
      perform game._apply(p_user, 'gold', v_amount, 'level_up', format('level:%s:%s', p_user, l), 'level', l::text);
      v_gold := v_gold + v_amount;
    end if;
    for u in select * from jsonb_array_elements(coalesce(v_cfg->'level_unlocks'->(l::text), '[]'::jsonb)) loop
      insert into public.player_unlocks (user_id, kind, item_id, source)
      values (p_user, u->>'kind', u->>'id', format('level:%s', l)) on conflict do nothing;
    end loop;
  end loop;
  return jsonb_build_object('xp', p_amount, 'level_before', v_before, 'level_after', greatest(v_before, v_after), 'gold', v_gold);
end;
$$;

-- XP of one seat of a finished match (config; place-based, independent of match length).
create or replace function app_private.match_xp(p_mode text, p_players int, p_rank int, p_left boolean, p_cfg jsonb)
returns int language plpgsql immutable set search_path = '' as $$
declare v int;
begin
  if p_mode not in ('quick', 'private') or p_left then return 0; end if;
  v := coalesce(((p_cfg->'xp'->(case when p_players = 2 then 'quick_2p' else 'quick_4p' end))->>(p_rank - 1))::int, 0);
  if p_mode = 'private' then v := (v * (p_cfg->'xp'->>'private_percent')::int + 99) / 100; end if;   -- rounded up
  return v;
end;
$$;
revoke all on function app_private.match_xp(text, int, int, boolean, jsonb) from public, anon, authenticated;

-- Everything a recorded match changes for its players (called once, by record_match).
-- Phase 6.1: XP / levels. Later sub-phases add quests, achievements, leaderboard here.
create or replace function game._after_match(p_match_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_cfg jsonb := (select value from public.app_config where key = 'progression');
  m record;
  p record;
  v_xp int;
  r jsonb;
  out jsonb := '{}'::jsonb;
begin
  select * into m from public.matches where id = p_match_id;
  if m.mode = 'test' then return out; end if;
  for p in select * from public.match_players where match_id = p_match_id and not is_bot and user_id is not null loop
    v_xp := app_private.match_xp(m.mode, m.players, p.rank, p.left_match, v_cfg);
    r := game._grant_xp(p.user_id, v_xp, 'match', p_match_id::text);
    update public.match_players set xp_gained = (r->>'xp')::int, level_after = (r->>'level_after')::int
     where match_id = p_match_id and seat = p.seat;
    out := out || jsonb_build_object(p.user_id::text, r);
  end loop;
  return out;
end;
$$;

-- ------------------------------------------------------------ record_match v2
-- Same as Phase 4 plus per-seat counters and the progression hook (_after_match),
-- all in one transaction; a second call for the same match changes nothing.
create or replace function game.record_match(
  p_match_id uuid, p_mode text, p_ruleset jsonb, p_seats jsonb,
  p_started_at timestamptz, p_ended_at timestamptz, p_end_reason text,
  p_actions text, p_final_state_hash bigint, p_action_count int, p_server_version text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n      int;
  v_colors text[];
  v_ranks  int[];
  s        jsonb;
  v_user   uuid;
  v_bot    boolean;
  v_humans uuid[] := '{}';
  v_prof   record;
  v_progress jsonb := '{}'::jsonb;
begin
  if p_match_id is null then raise exception 'BAD_MATCH'; end if;
  if exists (select 1 from public.matches where id = p_match_id) then
    return jsonb_build_object('applied', false);          -- already recorded: nothing changes
  end if;
  if p_mode not in ('quick', 'private', 'test') then raise exception 'BAD_MODE'; end if;
  if p_seats is null or jsonb_typeof(p_seats) <> 'array' then raise exception 'BAD_SEATS'; end if;
  v_n := jsonb_array_length(p_seats);
  if v_n not in (2, 4) then raise exception 'BAD_SEATS'; end if;
  if p_started_at is null or p_ended_at is null or p_ended_at < p_started_at then raise exception 'BAD_TIMES'; end if;

  select array_agg(e->>'color' order by (e->>'seat')::int), array_agg((e->>'rank')::int order by (e->>'seat')::int)
    into v_colors, v_ranks from jsonb_array_elements(p_seats) e;
  if (select count(distinct (e->>'seat')::int) from jsonb_array_elements(p_seats) e
      where (e->>'seat')::int between 0 and v_n - 1) <> v_n then raise exception 'BAD_SEATS'; end if;
  if (select count(distinct c) from unnest(v_colors) c where c in ('red', 'green', 'yellow', 'blue')) <> v_n then
    raise exception 'BAD_COLORS';
  end if;
  if v_n = 2 and not (v_colors @> array['red', 'yellow'] or v_colors @> array['green', 'blue']) then
    raise exception 'COLOR_INVALID';
  end if;
  if (select count(distinct r) from unnest(v_ranks) r where r between 1 and v_n) <> v_n then
    raise exception 'BAD_RANKS';
  end if;

  insert into public.matches (id, mode, players, ruleset, economy_tier, entry_fee, status, started_at, ended_at,
                              end_reason, actions, server_version, final_state_hash, action_count)
  values (p_match_id, p_mode, v_n, coalesce(p_ruleset, '{}'::jsonb), 'free', 0, 'finished', p_started_at, p_ended_at,
          p_end_reason, p_actions, p_server_version, p_final_state_hash, p_action_count);

  for s in select * from jsonb_array_elements(p_seats) loop
    v_bot := coalesce((s->>'is_bot')::boolean, false);
    v_user := nullif(s->>'user_id', '')::uuid;
    if v_bot <> (v_user is null) then raise exception 'BAD_SEATS'; end if;
    if not v_bot then
      if v_user = any(v_humans) then raise exception 'BAD_SEATS'; end if;
      v_humans := v_humans || v_user;
      select display_name, tag into v_prof from public.profiles where user_id = v_user;
      if not found then raise exception 'UNKNOWN_PLAYER'; end if;
    end if;
    insert into public.match_players (match_id, seat, user_id, color, is_bot, rank, left_match, display_name, tag,
                                      rolls, sixes, captures, finished)
    values (p_match_id, (s->>'seat')::int, v_user, s->>'color', v_bot, (s->>'rank')::int,
            coalesce((s->>'left')::boolean, false),
            case when v_bot then left(coalesce(s->>'name', 'Bot'), 16) else v_prof.display_name end,
            case when v_bot then null else v_prof.tag end,
            greatest(0, least(coalesce((s->>'rolls')::int, 0), 10000)),
            greatest(0, least(coalesce((s->>'sixes')::int, 0), 10000)),
            greatest(0, least(coalesce((s->>'captures')::int, 0), 10000)),
            greatest(0, least(coalesce((s->>'finished')::int, 0), 4)));
  end loop;

  if p_mode <> 'test' then
    update public.player_stats ps
       set matches_2p = matches_2p + case when v_n = 2 then 1 else 0 end,
           matches_4p = matches_4p + case when v_n = 4 then 1 else 0 end,
           wins_2p    = wins_2p + case when v_n = 2 and mp.rank = 1 then 1 else 0 end,
           wins_4p    = wins_4p + case when v_n = 4 and mp.rank = 1 then 1 else 0 end,
           leaves     = leaves + case when mp.left_match then 1 else 0 end,
           last_match_at = p_ended_at,
           updated_at = now()
      from public.match_players mp
     where mp.match_id = p_match_id and mp.user_id = ps.user_id and not mp.is_bot;
    v_progress := game._after_match(p_match_id);
  end if;
  return jsonb_build_object('applied', true, 'progress', v_progress);
end;
$$;

revoke all on function game._grant_xp(uuid, int, text, text), game._after_match(uuid) from public, anon, authenticated;
revoke all on function game.record_match(uuid, text, jsonb, jsonb, timestamptz, timestamptz, text, text, bigint, int, text) from public, anon, authenticated;
grant execute on function game.record_match(uuid, text, jsonb, jsonb, timestamptz, timestamptz, text, text, bigint, int, text) to game_server;

-- --------------------------------------------------------------- client read
-- The player's progress: level, XP, progress inside the level, unlocked badges.
create or replace function public.my_progress()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_cfg jsonb := (select value from public.app_config where key = 'progression');
  p record;
  v_start bigint;
  v_next int;
  v_max int := (v_cfg->'level_curve'->>'max_level')::int;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  select level, xp into p from public.profiles where user_id = v_me;
  if not found then raise exception 'NO_PROFILE'; end if;
  v_start := app_private.xp_at_level(p.level, v_cfg);
  v_next := case when p.level >= v_max then 0 else app_private.xp_to_next(p.level, v_cfg) end;
  return jsonb_build_object(
    'level', p.level, 'xp', p.xp, 'max_level', v_max,
    'xp_in_level', p.xp - v_start, 'xp_for_next', v_next,
    'next_level_gold', case when p.level >= v_max then 0 else least((v_cfg->'level_gold'->>'max')::int,
        (v_cfg->'level_gold'->>'base')::int + (v_cfg->'level_gold'->>'per_level')::int * (p.level + 1)) end,
    'badges', coalesce((select jsonb_agg(item_id order by created_at) from public.player_unlocks
                         where user_id = v_me and kind = 'badge'), '[]'::jsonb));
end;
$$;
revoke all on function public.my_progress() from public, anon;
grant execute on function public.my_progress() to authenticated;
