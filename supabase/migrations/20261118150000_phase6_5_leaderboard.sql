-- Kızma Birader — Phase 6.5: weekly leaderboard.
--
-- Weekly points come only from recorded QUICK matches (private rooms and test matches do
-- not count; ECONOMY_AND_PROGRESSION §8), by place: 2P 10 / 2, 4P 15 / 8 / 4 / 1; a player
-- who left or a match cut short gives 0; at most `daily_points_cap` points per TR day.
-- The week is the TR week (Monday 00:00 UTC+3). Ranking: points desc, wins desc, fewer
-- matches first, then who reached the score first. Closed weeks stay stored.
-- End of week: game.leaderboard_maintenance() (Cloudflare cron, hourly, role game_server)
-- closes every finished week once and pays the configured rewards through the wallet
-- ledger (idempotency key per week and player) — gold and badges only, no gameplay edge.

insert into public.app_config (key, value, is_public) values ('leaderboard', '{
  "version": 1, "points_2p": [10, 2], "points_4p": [15, 8, 4, 1], "daily_points_cap": 300, "page_size_max": 100,
  "rewards": [
    {"from": 1,  "to": 1,   "gold": 2000, "badge": "weekly_champion"},
    {"from": 2,  "to": 10,  "gold": 1000, "badge": "weekly_top10"},
    {"from": 11, "to": 100, "gold": 500}
  ]
}'::jsonb, true)
on conflict (key) do update set value = excluded.value, version = public.app_config.version + 1, updated_at = now();

-- the ledger gets a reason for weekly rewards
alter table public.wallet_transactions drop constraint wallet_transactions_reason_check;
alter table public.wallet_transactions add constraint wallet_transactions_reason_check check (reason in (
  'starting_gold', 'match_entry', 'match_payout', 'match_refund',
  'iap_gold', 'iap_gems', 'refund_clawback', 'debt_settlement',
  'daily_free_gold', 'bailout', 'daily_login', 'quest', 'achievement',
  'level_up', 'store_purchase', 'ad_reward', 'compensation', 'admin_adjust', 'leaderboard'));

create table public.leaderboard_weeks (
  week_key    date primary key,                  -- Monday of the TR week
  status      text not null default 'open' check (status in ('open', 'rewarded')),
  players     int,
  rewarded_at timestamptz
);

create table public.leaderboard_scores (
  week_key   date not null,
  user_id    uuid not null references auth.users (id) on delete cascade,
  points     int not null default 0 check (points >= 0),
  wins       int not null default 0,
  matches    int not null default 0,
  reached_at timestamptz not null default now(),   -- when the current points were reached (tie-break)
  primary key (week_key, user_id)
);
create index leaderboard_scores_rank_idx on public.leaderboard_scores (week_key, points desc, wins desc, matches, reached_at);

create table public.leaderboard_daily (
  user_id uuid not null references auth.users (id) on delete cascade,
  day     date not null,
  points  int not null default 0,
  primary key (user_id, day)
);

create table public.leaderboard_rewards (
  week_key   date not null,
  user_id    uuid not null references auth.users (id) on delete cascade,
  rank       int not null,
  points     int not null,
  gold       int not null default 0,
  badge      text,
  created_at timestamptz not null default now(),
  primary key (week_key, user_id)
);

alter table public.leaderboard_weeks enable row level security;
alter table public.leaderboard_scores enable row level security;
alter table public.leaderboard_daily enable row level security;
alter table public.leaderboard_rewards enable row level security;
create policy leaderboard_rewards_read_own on public.leaderboard_rewards for select to authenticated using (user_id = (select auth.uid()));
-- scores are read through the leaderboard functions (names and levels joined there)
revoke all on public.leaderboard_weeks, public.leaderboard_scores, public.leaderboard_daily, public.leaderboard_rewards from anon, authenticated;
grant select on public.leaderboard_rewards to authenticated;

-- ---------------------------------------------------------------- scoring
create or replace function game._leaderboard_add(p_user uuid, p_players int, p_rank int, p_at timestamptz)
returns int language plpgsql volatile security definer set search_path = '' as $$
declare
  v_cfg jsonb := (select value from public.app_config where key = 'leaderboard');
  v_pts int;
  v_day date := app_private.tr_day(p_at);
  v_used int;
begin
  v_pts := coalesce(((v_cfg->(case when p_players = 2 then 'points_2p' else 'points_4p' end))->>(p_rank - 1))::int, 0);
  select coalesce(points, 0) into v_used from public.leaderboard_daily where user_id = p_user and day = v_day;
  v_pts := greatest(0, least(v_pts, (v_cfg->>'daily_points_cap')::int - coalesce(v_used, 0)));
  insert into public.leaderboard_daily (user_id, day, points) values (p_user, v_day, v_pts)
  on conflict (user_id, day) do update set points = public.leaderboard_daily.points + excluded.points;
  insert into public.leaderboard_weeks (week_key) values (app_private.tr_week(p_at)) on conflict do nothing;
  insert into public.leaderboard_scores (week_key, user_id, points, wins, matches, reached_at)
  values (app_private.tr_week(p_at), p_user, v_pts, case when p_rank = 1 then 1 else 0 end, 1, now())
  on conflict (week_key, user_id) do update set
    points = public.leaderboard_scores.points + excluded.points,
    wins = public.leaderboard_scores.wins + excluded.wins,
    matches = public.leaderboard_scores.matches + 1,
    reached_at = case when excluded.points > 0 then now() else public.leaderboard_scores.reached_at end;
  return v_pts;
end;
$$;

-- _after_match v5: v4 (XP, quests, counters, achievements) + weekly points.
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
  v_pts int;
  out jsonb := '{}'::jsonb;
begin
  select * into m from public.matches where id = p_match_id;
  if m.mode = 'test' then return out; end if;
  v_valid := not (m.end_reason = 'left' and coalesce(m.action_count, 0) < v_min);
  for p in select * from public.match_players where match_id = p_match_id and not is_bot and user_id is not null loop
    perform 1 from public.profiles where user_id = p.user_id for update;
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
    v_pts := 0;
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
        v_pts := game._leaderboard_add(p.user_id, m.players, p.rank, m.ended_at);   -- 6.5
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
    out := out || jsonb_build_object(p.user_id::text, r || jsonb_build_object('counted', v_valid, 'achievements', v_new, 'points', v_pts));
  end loop;
  return out;
end;
$$;

-- ---------------------------------------------------------- end of week
-- Closes every finished week that is not rewarded yet: ranks, rewards (ledger), badges.
-- Safe to call any number of times, also concurrently (week row lock + unique keys).
create or replace function game.leaderboard_maintenance()
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_cfg jsonb := (select value from public.app_config where key = 'leaderboard');
  w record;
  s record;
  t jsonb;
  v_closed int := 0;
  v_paid int := 0;
begin
  insert into public.leaderboard_weeks (week_key) values (app_private.tr_week(now())) on conflict do nothing;
  for w in select * from public.leaderboard_weeks
            where status = 'open' and week_key < app_private.tr_week(now())
            order by week_key for update skip locked loop
    for s in select user_id, points, rank() over (order by points desc, wins desc, matches, reached_at) as rnk
               from (select * from public.leaderboard_scores where week_key = w.week_key and points > 0) x
              order by rnk loop
      t := null;
      select x.value into t from jsonb_array_elements(v_cfg->'rewards') x
       where s.rnk between (x.value->>'from')::int and (x.value->>'to')::int limit 1;
      exit when t is null and s.rnk > 100;
      if t is null then continue; end if;
      insert into public.leaderboard_rewards (week_key, user_id, rank, points, gold, badge)
      values (w.week_key, s.user_id, s.rnk, s.points, coalesce((t->>'gold')::int, 0), t->>'badge')
      on conflict do nothing;
      if found then
        if coalesce((t->>'gold')::int, 0) > 0 then
          perform game._apply(s.user_id, 'gold', (t->>'gold')::int, 'leaderboard', format('lb:%s:%s', w.week_key, s.user_id), 'week', w.week_key::text);
        end if;
        if t ? 'badge' then
          insert into public.player_unlocks (user_id, kind, item_id, source)
          values (s.user_id, 'badge', t->>'badge', 'leaderboard:' || w.week_key) on conflict do nothing;
        end if;
        v_paid := v_paid + 1;
      end if;
    end loop;
    update public.leaderboard_weeks
       set status = 'rewarded', rewarded_at = now(),
           players = (select count(*) from public.leaderboard_scores where week_key = w.week_key and points > 0)
     where week_key = w.week_key;
    v_closed := v_closed + 1;
  end loop;
  return jsonb_build_object('closed_weeks', v_closed, 'rewards', v_paid);
end;
$$;

-- --------------------------------------------------------------- client reads
-- Top of a week (default: current), paged (at most page_size_max rows per call).
create or replace function public.leaderboard_top(p_week date default null, p_limit int default 50, p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_week date := coalesce(p_week, app_private.tr_week(now()));
  v_max int := coalesce((select (value->>'page_size_max')::int from public.app_config where key = 'leaderboard'), 100);
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_offset < 0 or p_offset >= 1000 then raise exception 'BAD_PAGE'; end if;
  return jsonb_build_object(
    'week', v_week,
    'ends_at', (v_week + 7 - make_interval(hours => 3))::timestamp at time zone 'UTC',
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object('rank', rnk, 'user_id', x.user_id, 'display_name', p.display_name, 'tag', p.tag,
               'avatar_id', p.avatar_id, 'level', p.level, 'badge_id', p.badge_id, 'points', x.points, 'wins', x.wins,
               'matches', x.matches, 'me', x.user_id = v_me) order by rnk, x.reached_at)
        from (select s.*, rank() over (order by points desc, wins desc, matches, reached_at) as rnk
                from public.leaderboard_scores s where week_key = v_week and points > 0
               order by rnk limit least(greatest(p_limit, 1), v_max) offset p_offset) x
        join public.profiles p on p.user_id = x.user_id), '[]'::jsonb));
end;
$$;

-- My place in a week and my reward of the last closed week.
create or replace function public.leaderboard_me(p_week date default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_week date := coalesce(p_week, app_private.tr_week(now()));
  s record;
  v_rank int;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into s from public.leaderboard_scores where week_key = v_week and user_id = v_me;
  if found and s.points > 0 then
    select count(*) + 1 into v_rank from public.leaderboard_scores o
     where o.week_key = v_week and o.points > 0
       and (o.points, o.wins, -o.matches, -extract(epoch from o.reached_at))
         > (s.points, s.wins, -s.matches, -extract(epoch from s.reached_at));
  end if;
  return jsonb_build_object(
    'week', v_week,
    'rank', v_rank, 'points', coalesce(s.points, 0), 'wins', coalesce(s.wins, 0), 'matches', coalesce(s.matches, 0),
    'players', (select count(*) from public.leaderboard_scores where week_key = v_week and points > 0),
    'ends_at', (v_week + 7 - make_interval(hours => 3))::timestamp at time zone 'UTC',
    'last_reward', (select to_jsonb(r) - 'user_id' from public.leaderboard_rewards r where r.user_id = v_me order by week_key desc limit 1),
    'previous_week', v_week - 7);
end;
$$;

revoke all on function game._leaderboard_add(uuid, int, int, timestamptz), game._after_match(uuid), game.leaderboard_maintenance()
  from public, anon, authenticated;
grant execute on function game.leaderboard_maintenance() to game_server;
revoke all on function public.leaderboard_top(date, int, int), public.leaderboard_me(date) from public, anon;
grant execute on function public.leaderboard_top(date, int, int), public.leaderboard_me(date) to authenticated;
