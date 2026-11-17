-- Kızma Birader — Phase 6.2: daily and weekly quests.
--
-- Quests are assigned per player and period (TR day / TR week starting Monday 00:00,
-- UTC+3), chosen deterministically from the templates in app_config 'quests' (source:
-- shared/config/quests_config.json; one quest per group, so no two "win" quests).
-- Progress comes ONLY from recorded online matches (game._after_match) and, for
-- login days, from the daily login claim (6.3). Clients read their quests and claim
-- completed ones; a claim is a single row update (exactly once, also under concurrent
-- requests) followed by gold (wallet ledger, idempotency key) and XP (xp_events).
--
-- Anti-farming (ECONOMY_AND_PROGRESSION §4.3): private-room matches advance only the
-- "play with a friend" metric; a player who left a match gets no progress.

insert into public.app_config (key, value, is_public) values ('quests', '{
  "version": 1, "day_offset_hours": 3, "daily_count": 3, "weekly_count": 4,
  "daily": [
    {"id": "d_play_1",   "group": "play",   "metric": "matches",        "target": 1,  "gold": 60,  "xp": 15},
    {"id": "d_play_3",   "group": "play",   "metric": "matches",        "target": 3,  "gold": 120, "xp": 30},
    {"id": "d_win_1",    "group": "win",    "metric": "wins",           "target": 1,  "gold": 120, "xp": 30},
    {"id": "d_win_2",    "group": "win",    "metric": "wins",           "target": 2,  "gold": 200, "xp": 45},
    {"id": "d_rolls_40", "group": "rolls",  "metric": "rolls",          "target": 40, "gold": 80,  "xp": 20},
    {"id": "d_2p_1",     "group": "mode",   "metric": "matches_2p",     "target": 1,  "gold": 80,  "xp": 20},
    {"id": "d_4p_1",     "group": "mode",   "metric": "matches_4p",     "target": 1,  "gold": 100, "xp": 25},
    {"id": "d_friend_1", "group": "friend", "metric": "friend_matches", "target": 1,  "gold": 120, "xp": 30}
  ],
  "weekly": [
    {"id": "w_play_10",  "group": "play",   "metric": "matches",        "target": 10, "gold": 500, "xp": 100},
    {"id": "w_win_5",    "group": "win",    "metric": "wins",           "target": 5,  "gold": 600, "xp": 120},
    {"id": "w_login_3",  "group": "login",  "metric": "login_days",     "target": 3,  "gold": 300, "xp": 60},
    {"id": "w_4p_5",     "group": "mode",   "metric": "matches_4p",     "target": 5,  "gold": 500, "xp": 100},
    {"id": "w_friend_3", "group": "friend", "metric": "friend_matches", "target": 3,  "gold": 400, "xp": 80}
  ]
}'::jsonb, true)
on conflict (key) do update set value = excluded.value, version = public.app_config.version + 1, updated_at = now();

create table public.player_quests (
  user_id     uuid not null references auth.users (id) on delete cascade,
  period      text not null check (period in ('daily', 'weekly')),
  period_key  date not null,                       -- TR day, or the Monday of the TR week
  quest_id    text not null,
  metric      text not null,
  target      int  not null check (target > 0),
  progress    int  not null default 0 check (progress >= 0),
  gold        int  not null default 0 check (gold >= 0),
  xp          int  not null default 0 check (xp >= 0),
  completed_at timestamptz,
  claimed_at   timestamptz,
  created_at   timestamptz not null default now(),
  primary key (user_id, period, period_key, quest_id),
  check (claimed_at is null or completed_at is not null)
);
create index player_quests_open_idx on public.player_quests (user_id, period_key) where claimed_at is null;
alter table public.player_quests enable row level security;
create policy player_quests_read_own on public.player_quests for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.player_quests from anon, authenticated;
grant select on public.player_quests to authenticated;

-- ------------------------------------------------------------------- periods
-- TR calendar day / week (Monday) of a moment, from the configured offset.
create or replace function app_private.tr_day(p_at timestamptz)
returns date language sql stable set search_path = '' as $$
  select ((p_at at time zone 'UTC') + make_interval(hours => coalesce(
           (select (value->>'day_offset_hours')::int from public.app_config where key = 'quests'), 3)))::date;
$$;

create or replace function app_private.tr_week(p_at timestamptz)
returns date language sql stable set search_path = '' as $$
  select date_trunc('week', app_private.tr_day(p_at)::timestamp)::date;
$$;

-- Start of the next TR day / week as a timestamp (for "renews in ..." on the client).
create or replace function app_private.tr_next_reset(p_period text, p_at timestamptz)
returns timestamptz language sql stable set search_path = '' as $$
  select ((case when p_period = 'daily' then app_private.tr_day(p_at) + 1 else app_private.tr_week(p_at) + 7 end)::timestamp
          - make_interval(hours => coalesce((select (value->>'day_offset_hours')::int from public.app_config where key = 'quests'), 3)))
         at time zone 'UTC';
$$;

-- --------------------------------------------------------------- assignment
-- Creates the player's quests for the current day and week if they do not exist yet.
create or replace function app_private.ensure_quests(p_user uuid, p_at timestamptz)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  v_cfg jsonb := (select value from public.app_config where key = 'quests');
  per text;
  v_key date;
  v_count int;
begin
  foreach per in array array['daily', 'weekly'] loop
    v_key := case when per = 'daily' then app_private.tr_day(p_at) else app_private.tr_week(p_at) end;
    if exists (select 1 from public.player_quests where user_id = p_user and period = per and period_key = v_key) then
      continue;
    end if;
    v_count := (v_cfg->>(per || '_count'))::int;
    insert into public.player_quests (user_id, period, period_key, quest_id, metric, target, gold, xp)
    select p_user, per, v_key, q->>'id', q->>'metric', (q->>'target')::int, (q->>'gold')::int, (q->>'xp')::int
      from (
        select q, row_number() over (partition by q->>'group' order by md5(p_user::text || v_key::text || (q->>'id'))) as rn,
               md5(p_user::text || v_key::text || 'group' || (q->>'group')) as g
          from jsonb_array_elements(v_cfg->per) q
      ) pick
     where rn = 1
     order by g
     limit v_count
    on conflict do nothing;
  end loop;
end;
$$;

-- Adds progress to the player's open quests of the current day / week for one metric.
create or replace function game._quest_add(p_user uuid, p_metric text, p_amount int, p_at timestamptz)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if p_amount is null or p_amount <= 0 then return; end if;
  perform app_private.ensure_quests(p_user, p_at);
  update public.player_quests
     set progress = least(target, progress + p_amount),
         completed_at = coalesce(completed_at, case when progress + p_amount >= target then now() end)
   where user_id = p_user and metric = p_metric and completed_at is null
     and ((period = 'daily' and period_key = app_private.tr_day(p_at))
       or (period = 'weekly' and period_key = app_private.tr_week(p_at)));
end;
$$;

-- ------------------------------------------------------------ _after_match v2
create or replace function game._after_match(p_match_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_cfg jsonb := (select value from public.app_config where key = 'progression');
  m record;
  p record;
  v_xp int;
  r jsonb;
  v_friend boolean;
  out jsonb := '{}'::jsonb;
begin
  select * into m from public.matches where id = p_match_id;
  if m.mode = 'test' then return out; end if;
  for p in select * from public.match_players where match_id = p_match_id and not is_bot and user_id is not null loop
    -- 6.1 XP and level
    v_xp := app_private.match_xp(m.mode, m.players, p.rank, p.left_match, v_cfg);
    r := game._grant_xp(p.user_id, v_xp, 'match', p_match_id::text);
    update public.match_players set xp_gained = (r->>'xp')::int, level_after = (r->>'level_after')::int
     where match_id = p_match_id and seat = p.seat;
    out := out || jsonb_build_object(p.user_id::text, r);
    -- 6.2 quests (server-side metrics of this match; nothing for a player who left)
    if not p.left_match then
      v_friend := exists (select 1 from public.match_players o
                           where o.match_id = p_match_id and o.user_id is not null and o.user_id <> p.user_id
                             and app_private.are_friends(p.user_id, o.user_id));
      if v_friend then perform game._quest_add(p.user_id, 'friend_matches', 1, m.ended_at); end if;
      if m.mode = 'quick' then
        perform game._quest_add(p.user_id, 'matches', 1, m.ended_at);
        perform game._quest_add(p.user_id, case when m.players = 2 then 'matches_2p' else 'matches_4p' end, 1, m.ended_at);
        if p.rank = 1 then perform game._quest_add(p.user_id, 'wins', 1, m.ended_at); end if;
        perform game._quest_add(p.user_id, 'rolls', p.rolls, m.ended_at);
      end if;
    end if;
  end loop;
  return out;
end;
$$;

-- -------------------------------------------------------------- client side
create or replace function public.my_quests()
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_now timestamptz := now();
  v jsonb;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  perform app_private.ensure_quests(v_me, v_now);
  select jsonb_build_object(
    'daily', coalesce((select jsonb_agg(jsonb_build_object('period', period, 'period_key', period_key, 'quest_id', quest_id, 'metric', metric,
                 'target', target, 'progress', progress, 'gold', gold, 'xp', xp, 'completed', completed_at is not null, 'claimed', claimed_at is not null)
                 order by quest_id)
               from public.player_quests where user_id = v_me and period = 'daily' and period_key = app_private.tr_day(v_now)), '[]'::jsonb),
    'weekly', coalesce((select jsonb_agg(jsonb_build_object('period', period, 'period_key', period_key, 'quest_id', quest_id, 'metric', metric,
                 'target', target, 'progress', progress, 'gold', gold, 'xp', xp, 'completed', completed_at is not null, 'claimed', claimed_at is not null)
                 order by quest_id)
               from public.player_quests where user_id = v_me and period = 'weekly' and period_key = app_private.tr_week(v_now)), '[]'::jsonb),
    -- completed in an earlier period but not collected yet: still claimable
    'unclaimed_old', coalesce((select jsonb_agg(jsonb_build_object('period', period, 'period_key', period_key, 'quest_id', quest_id, 'metric', metric,
                 'target', target, 'progress', progress, 'gold', gold, 'xp', xp, 'completed', true, 'claimed', false) order by period_key desc)
               from (select * from public.player_quests
                      where user_id = v_me and completed_at is not null and claimed_at is null
                        and not ((period = 'daily' and period_key = app_private.tr_day(v_now))
                              or (period = 'weekly' and period_key = app_private.tr_week(v_now)))
                      order by period_key desc limit 20) o), '[]'::jsonb),
    'daily_resets_at', app_private.tr_next_reset('daily', v_now),
    'weekly_resets_at', app_private.tr_next_reset('weekly', v_now),
    'server_time', v_now)
  into v;
  return v;
end;
$$;

-- Collects the reward of one completed quest, exactly once.
create or replace function public.claim_quest(p_period text, p_period_key date, p_quest_id text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  q record;
  v_ref text;
  r jsonb;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  update public.player_quests set claimed_at = now()
   where user_id = v_me and period = p_period and period_key = p_period_key and quest_id = p_quest_id
     and completed_at is not null and claimed_at is null
  returning * into q;
  if not found then
    if exists (select 1 from public.player_quests where user_id = v_me and period = p_period and period_key = p_period_key
                 and quest_id = p_quest_id and claimed_at is not null) then
      raise exception 'ALREADY_CLAIMED';
    elsif exists (select 1 from public.player_quests where user_id = v_me and period = p_period and period_key = p_period_key
                    and quest_id = p_quest_id) then
      raise exception 'NOT_COMPLETED';
    end if;
    raise exception 'QUEST_NOT_FOUND';
  end if;
  v_ref := format('quest:%s:%s:%s', p_period, p_period_key, p_quest_id);
  if q.gold > 0 then perform game._apply(v_me, 'gold', q.gold, 'quest', v_me::text || ':' || v_ref, 'quest', v_ref); end if;
  r := game._grant_xp(v_me, q.xp, 'quest', v_ref);
  return jsonb_build_object('gold', q.gold, 'xp', (r->>'xp')::int, 'level_before', (r->>'level_before')::int,
                            'level_after', (r->>'level_after')::int, 'level_gold', (r->>'gold')::int);
end;
$$;

revoke all on function app_private.tr_day(timestamptz), app_private.tr_week(timestamptz), app_private.tr_next_reset(text, timestamptz),
  app_private.ensure_quests(uuid, timestamptz) from public, anon, authenticated;
revoke all on function game._quest_add(uuid, text, int, timestamptz), game._after_match(uuid) from public, anon, authenticated;
revoke all on function public.my_quests(), public.claim_quest(text, date, text) from public, anon;
grant execute on function public.my_quests(), public.claim_quest(text, date, text) to authenticated;
