-- Kızma Birader — Phase 6.4: achievements and profile badges.
--
-- Achievements are long-term goals on per-player counters that the server updates in
-- the same transaction that records a match (game._after_match). Definitions live in
-- app_config 'achievements' (shared/config/achievements_config.json): adding one is a
-- config change. A reached achievement is stored once (player_achievements); its reward
-- (gold via the ledger, XP, optional badge) is collected exactly once by the player.
-- Anti-farming as for quests: matches cut short by a leave count for nothing; private
-- rooms advance only the social counter (friend matches).
-- Badges: unlocked badges (player_unlocks) can be shown on the profile (profiles.badge_id).

insert into public.app_config (key, value, is_public) values ('achievements', '{
  "version": 1,
  "achievements": [
    {"id": "first_match",  "category": "match",  "metric": "quick_matches",   "target": 1,   "gold": 50,   "xp": 20},
    {"id": "first_win",    "category": "match",  "metric": "quick_wins",      "target": 1,   "gold": 100,  "xp": 30},
    {"id": "matches_10",   "category": "match",  "metric": "quick_matches",   "target": 10,  "gold": 150,  "xp": 50},
    {"id": "matches_50",   "category": "match",  "metric": "quick_matches",   "target": 50,  "gold": 400,  "xp": 100},
    {"id": "matches_100",  "category": "match",  "metric": "quick_matches",   "target": 100, "gold": 800,  "xp": 200, "badge": "veteran"},
    {"id": "wins_10",      "category": "match",  "metric": "quick_wins",      "target": 10,  "gold": 200,  "xp": 60},
    {"id": "wins_50",      "category": "match",  "metric": "quick_wins",      "target": 50,  "gold": 1000, "xp": 200, "badge": "champion"},
    {"id": "streak_3",     "category": "skill",  "metric": "best_win_streak", "target": 3,   "gold": 300,  "xp": 80},
    {"id": "streak_5",     "category": "skill",  "metric": "best_win_streak", "target": 5,   "gold": 600,  "xp": 150, "badge": "unstoppable"},
    {"id": "wins_2p_25",   "category": "skill",  "metric": "wins_2p",         "target": 25,  "gold": 500,  "xp": 120},
    {"id": "first_4p_win", "category": "skill",  "metric": "firsts_4p",       "target": 1,   "gold": 300,  "xp": 80},
    {"id": "friends_10",   "category": "social", "metric": "friend_matches",  "target": 10,  "gold": 300,  "xp": 80,  "badge": "social"}
  ]
}'::jsonb, true)
on conflict (key) do update set value = excluded.value, version = public.app_config.version + 1, updated_at = now();

-- ------------------------------------------------------------------ tables
create table public.player_counters (
  user_id         uuid primary key references auth.users (id) on delete cascade,
  quick_matches   int not null default 0,
  quick_wins      int not null default 0,     -- 2P win or 4P first place, quick matches
  wins_2p         int not null default 0,
  firsts_4p       int not null default 0,
  win_streak      int not null default 0,     -- current run of quick wins
  best_win_streak int not null default 0,
  friend_matches  int not null default 0,     -- matches with a friend (quick or private)
  updated_at      timestamptz not null default now()
);

create table public.player_achievements (
  user_id        uuid not null references auth.users (id) on delete cascade,
  achievement_id text not null,
  completed_at   timestamptz not null default now(),
  claimed_at     timestamptz,
  primary key (user_id, achievement_id)
);

alter table public.profiles add column badge_id text;   -- badge shown on the profile (must be unlocked)

alter table public.player_counters enable row level security;
alter table public.player_achievements enable row level security;
create policy player_counters_read_own on public.player_counters for select to authenticated using (user_id = (select auth.uid()));
create policy player_achievements_read_own on public.player_achievements for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.player_counters, public.player_achievements from anon, authenticated;
grant select on public.player_counters, public.player_achievements to authenticated;

-- Backfill from matches recorded before this phase (quick, not left): counts only, no streaks.
insert into public.player_counters (user_id, quick_matches, quick_wins, wins_2p, firsts_4p)
select mp.user_id,
       count(*) filter (where m.mode = 'quick'),
       count(*) filter (where m.mode = 'quick' and mp.rank = 1),
       count(*) filter (where m.mode = 'quick' and mp.rank = 1 and m.players = 2),
       count(*) filter (where m.mode = 'quick' and mp.rank = 1 and m.players = 4)
  from public.match_players mp join public.matches m on m.id = mp.match_id
 where mp.user_id is not null and not mp.left_match and m.status = 'finished'
 group by mp.user_id
on conflict (user_id) do nothing;

-- ------------------------------------------------------------- functions
-- Stores newly reached achievements; returns their ids.
create or replace function game._achievements_check(p_user uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_cfg jsonb := (select value from public.app_config where key = 'achievements');
  c jsonb;
  a jsonb;
  out jsonb := '[]'::jsonb;
begin
  select to_jsonb(pc) into c from public.player_counters pc where user_id = p_user;
  if c is null then return out; end if;
  for a in select * from jsonb_array_elements(v_cfg->'achievements') loop
    if coalesce((c->>(a->>'metric'))::int, 0) >= (a->>'target')::int then
      insert into public.player_achievements (user_id, achievement_id) values (p_user, a->>'id') on conflict do nothing;
      if found then out := out || to_jsonb(a->>'id'); end if;
    end if;
  end loop;
  return out;
end;
$$;

-- _after_match v4: XP (6.1, cap under lock), quests (6.2), counters and achievements (6.4).
create or replace function game._after_match(p_match_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_cfg jsonb := (select value from public.app_config where key = 'progression');
  v_min int := coalesce((v_cfg->'xp'->>'min_actions_after_leave')::int, 0);
  v_cap int := coalesce((v_cfg->'xp'->>'daily_match_xp_cap')::int, 2147483647);
  m record;
  p record;
  v_xp int;
  v_today int;
  v_valid boolean;
  r jsonb;
  v_friend boolean;
  v_win boolean;
  v_new jsonb;
  out jsonb := '{}'::jsonb;
begin
  select * into m from public.matches where id = p_match_id;
  if m.mode = 'test' then return out; end if;
  v_valid := not (m.end_reason = 'left' and coalesce(m.action_count, 0) < v_min);
  for p in select * from public.match_players where match_id = p_match_id and not is_bot and user_id is not null loop
    -- one player's progress at a time (cap, counters): lock the profile row
    perform 1 from public.profiles where user_id = p.user_id for update;
    -- 6.1 XP and level (place based; capped per TR day)
    v_xp := case when v_valid then app_private.match_xp(m.mode, m.players, p.rank, p.left_match, v_cfg) else 0 end;
    if v_xp > 0 then
      select coalesce(sum(amount), 0) into v_today from public.xp_events
       where user_id = p.user_id and reason = 'match' and app_private.tr_day(created_at) = app_private.tr_day(m.ended_at);
      v_xp := greatest(0, least(v_xp, v_cap - v_today));
    end if;
    r := game._grant_xp(p.user_id, v_xp, 'match', p_match_id::text);
    update public.match_players set xp_gained = (r->>'xp')::int, level_after = (r->>'level_after')::int
     where match_id = p_match_id and seat = p.seat;
    v_friend := exists (select 1 from public.match_players o
                         where o.match_id = p_match_id and o.user_id is not null and o.user_id <> p.user_id
                           and app_private.are_friends(p.user_id, o.user_id));
    v_win := p.rank = 1 and not p.left_match;
    -- 6.2 quests and 6.4 counters: nothing for a player who left or from a match cut short
    insert into public.player_counters (user_id) values (p.user_id) on conflict do nothing;
    if p.left_match and m.mode = 'quick' then
      update public.player_counters set win_streak = 0, updated_at = now() where user_id = p.user_id;
    elsif v_valid and not p.left_match then
      if v_friend then perform game._quest_add(p.user_id, 'friend_matches', 1, m.ended_at); end if;
      if m.mode = 'quick' then
        perform game._quest_add(p.user_id, 'matches', 1, m.ended_at);
        perform game._quest_add(p.user_id, case when m.players = 2 then 'matches_2p' else 'matches_4p' end, 1, m.ended_at);
        if v_win then perform game._quest_add(p.user_id, 'wins', 1, m.ended_at); end if;
        perform game._quest_add(p.user_id, 'rolls', p.rolls, m.ended_at);
      end if;
      update public.player_counters set
        quick_matches  = quick_matches + case when m.mode = 'quick' then 1 else 0 end,
        quick_wins     = quick_wins + case when m.mode = 'quick' and v_win then 1 else 0 end,
        wins_2p        = wins_2p + case when m.mode = 'quick' and v_win and m.players = 2 then 1 else 0 end,
        firsts_4p      = firsts_4p + case when m.mode = 'quick' and v_win and m.players = 4 then 1 else 0 end,
        win_streak     = case when m.mode <> 'quick' then win_streak when v_win then win_streak + 1 else 0 end,
        best_win_streak = greatest(best_win_streak, case when m.mode = 'quick' and v_win then win_streak + 1 else 0 end),
        friend_matches = friend_matches + case when v_friend then 1 else 0 end,
        updated_at = now()
       where user_id = p.user_id;
    end if;
    v_new := game._achievements_check(p.user_id);
    out := out || jsonb_build_object(p.user_id::text, r || jsonb_build_object('counted', v_valid, 'achievements', v_new));
  end loop;
  return out;
end;
$$;

-- All achievements with my progress, completion and collection state.
create or replace function public.my_achievements()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_cfg jsonb := (select value from public.app_config where key = 'achievements');
  c jsonb;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  select to_jsonb(pc) into c from public.player_counters pc where user_id = v_me;
  c := coalesce(c, '{}'::jsonb);
  return jsonb_build_object('achievements', coalesce((
    select jsonb_agg(a || jsonb_build_object(
             'progress', least(coalesce((c->>(a->>'metric'))::int, 0), (a->>'target')::int),
             'completed', pa.achievement_id is not null,
             'claimed', pa.claimed_at is not null,
             'completed_at', pa.completed_at) order by ord)
      from jsonb_array_elements(v_cfg->'achievements') with ordinality as x(a, ord)
      left join public.player_achievements pa on pa.user_id = v_me and pa.achievement_id = a->>'id'), '[]'::jsonb),
    'counters', c - 'user_id' - 'updated_at');
end;
$$;

create or replace function public.claim_achievement(p_id text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_def jsonb := (select a from public.app_config cfg, jsonb_array_elements(cfg.value->'achievements') a
                   where cfg.key = 'achievements' and a->>'id' = p_id);
  v_gold int;
  v_xp int;
  r jsonb;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_def is null then raise exception 'ACHIEVEMENT_NOT_FOUND'; end if;
  update public.player_achievements set claimed_at = now()
   where user_id = v_me and achievement_id = p_id and claimed_at is null;
  if not found then
    if exists (select 1 from public.player_achievements where user_id = v_me and achievement_id = p_id) then
      raise exception 'ALREADY_CLAIMED';
    end if;
    raise exception 'NOT_COMPLETED';
  end if;
  v_gold := coalesce((v_def->>'gold')::int, 0);
  v_xp := coalesce((v_def->>'xp')::int, 0);
  if v_gold > 0 then perform game._apply(v_me, 'gold', v_gold, 'achievement', format('ach:%s:%s', v_me, p_id), 'achievement', p_id); end if;
  r := game._grant_xp(v_me, v_xp, 'achievement', p_id);
  if v_def ? 'badge' then
    insert into public.player_unlocks (user_id, kind, item_id, source)
    values (v_me, 'badge', v_def->>'badge', 'achievement:' || p_id) on conflict do nothing;
  end if;
  return jsonb_build_object('id', p_id, 'gold', v_gold, 'xp', coalesce((r->>'xp')::int, 0), 'badge', v_def->>'badge',
                            'level_before', (r->>'level_before')::int, 'level_after', (r->>'level_after')::int,
                            'level_gold', coalesce((r->>'gold')::int, 0));
end;
$$;

-- Shows one of my unlocked badges on my profile (null = none).
create or replace function public.set_profile_badge(p_badge text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_badge is not null and not exists (select 1 from public.player_unlocks where user_id = v_me and kind = 'badge' and item_id = p_badge) then
    raise exception 'BADGE_LOCKED';
  end if;
  update public.profiles set badge_id = p_badge, updated_at = now() where user_id = v_me;
  return jsonb_build_object('badge_id', p_badge);
end;
$$;

-- my_progress v2: + selected badge
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
  select level, xp, badge_id into p from public.profiles where user_id = v_me;
  if not found then raise exception 'NO_PROFILE'; end if;
  v_start := app_private.xp_at_level(p.level, v_cfg);
  v_next := case when p.level >= v_max then 0 else app_private.xp_to_next(p.level, v_cfg) end;
  return jsonb_build_object(
    'level', p.level, 'xp', p.xp, 'max_level', v_max, 'badge_id', p.badge_id,
    'xp_in_level', p.xp - v_start, 'xp_for_next', v_next,
    'next_level_gold', case when p.level >= v_max then 0 else least((v_cfg->'level_gold'->>'max')::int,
        (v_cfg->'level_gold'->>'base')::int + (v_cfg->'level_gold'->>'per_level')::int * (p.level + 1)) end,
    'badges', coalesce((select jsonb_agg(item_id order by created_at) from public.player_unlocks
                         where user_id = v_me and kind = 'badge'), '[]'::jsonb));
end;
$$;

-- another player's profile v2: + level and shown badge
create or replace function public.get_player_profile(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v jsonb;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_user <> v_me and app_private.blocked_between(v_me, p_user) then raise exception 'NOT_FOUND'; end if;
  select jsonb_build_object(
           'user_id', p.user_id, 'display_name', p.display_name, 'tag', p.tag, 'avatar_id', p.avatar_id,
           'level', p.level, 'badge_id', p.badge_id,
           'relation', app_private.relation(v_me, p.user_id),
           'matches_2p', coalesce(s.matches_2p, 0), 'wins_2p', coalesce(s.wins_2p, 0),
           'matches_4p', coalesce(s.matches_4p, 0), 'wins_4p', coalesce(s.wins_4p, 0),
           'friends_since', (select f.created_at from public.friendships f
                              where f.user_low = least(v_me, p.user_id) and f.user_high = greatest(v_me, p.user_id)))
    into v
    from public.profiles p left join public.player_stats s on s.user_id = p.user_id
   where p.user_id = p_user;
  if v is null then raise exception 'NOT_FOUND'; end if;
  return v;
end;
$$;

revoke all on function game._achievements_check(uuid), game._after_match(uuid) from public, anon, authenticated;
revoke all on function public.my_achievements(), public.claim_achievement(text), public.set_profile_badge(text) from public, anon;
grant execute on function public.my_achievements(), public.claim_achievement(text), public.set_profile_badge(text) to authenticated;
