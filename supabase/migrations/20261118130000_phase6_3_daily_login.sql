-- Kızma Birader — Phase 6.3: daily login reward (7-day cycle).
--
-- Rules (ECONOMY_AND_PROGRESSION §6, decision K-74):
--  - one claim per player and TR calendar day (UTC+3), decided by the SERVER clock
--    (the device clock is never used); the claim is one insert with a unique key
--    (player, day) -> repeated or concurrent claims pay once;
--  - the 7-day cycle never resets: after a missed day the player continues with the
--    next day of the cycle; only the consecutive-day streak goes back to 1;
--  - day 7 also unlocks the "login_week" badge (first time) and starts a new cycle;
--  - every claim advances the weekly "log in on N days" quest.
-- Rewards: app_config 'daily_login' (shared/config/daily_login_config.json).

insert into public.app_config (key, value, is_public) values ('daily_login', '{
  "version": 1, "missed_day": "cycle_continues_streak_resets",
  "cycle": [
    {"day": 1, "xp": 30}, {"day": 2, "gold": 100}, {"day": 3, "xp": 50}, {"day": 4, "gold": 200},
    {"day": 5, "xp": 80}, {"day": 6, "gold": 300}, {"day": 7, "gold": 500, "xp": 100, "badge": "login_week"}
  ]
}'::jsonb, true)
on conflict (key) do update set value = excluded.value, version = public.app_config.version + 1, updated_at = now();

create table public.player_login (
  user_id        uuid primary key references auth.users (id) on delete cascade,
  next_cycle_day int  not null default 1 check (next_cycle_day between 1 and 7),
  streak         int  not null default 0 check (streak >= 0),
  best_streak    int  not null default 0 check (best_streak >= 0),
  cycles         int  not null default 0 check (cycles >= 0),
  total_claims   int  not null default 0 check (total_claims >= 0),
  last_claim_day date,
  updated_at     timestamptz not null default now()
);

create table public.login_claims (
  user_id    uuid not null references auth.users (id) on delete cascade,
  claim_day  date not null,                         -- TR day of the claim (server clock)
  cycle_day  int  not null check (cycle_day between 1 and 7),
  gold       int  not null default 0,
  xp         int  not null default 0,
  created_at timestamptz not null default now(),
  primary key (user_id, claim_day)
);

alter table public.player_login enable row level security;
alter table public.login_claims enable row level security;
create policy player_login_read_own on public.player_login for select to authenticated using (user_id = (select auth.uid()));
create policy login_claims_read_own on public.login_claims for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.player_login, public.login_claims from anon, authenticated;
grant select on public.player_login, public.login_claims to authenticated;

-- Status for the login popup: can I claim today, which day of the cycle, streak, the cycle.
create or replace function public.daily_login_status()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_cfg jsonb := (select value from public.app_config where key = 'daily_login');
  v_today date := app_private.tr_day(now());
  p record;
  v_next int := 1;
  v_streak int := 0;
  v_can boolean := true;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into p from public.player_login where user_id = v_me;
  if found then
    v_next := p.next_cycle_day;
    v_can := p.last_claim_day is distinct from v_today;
    -- the streak shown today: kept if the last claim was today or yesterday
    v_streak := case when p.last_claim_day >= v_today - 1 then p.streak else 0 end;
  end if;
  return jsonb_build_object(
    'can_claim', v_can,
    'next_day', v_next,                       -- the cycle day that is (or will be) claimed next
    'claimed_today_day', case when v_can then null else (case when v_next = 1 then 7 else v_next - 1 end) end,
    'streak', v_streak, 'best_streak', coalesce(p.best_streak, 0), 'cycles', coalesce(p.cycles, 0),
    'cycle', v_cfg->'cycle',
    'today', v_today,
    'resets_at', app_private.tr_next_reset('daily', now()),
    'server_time', now());
end;
$$;

create or replace function public.claim_daily_login()
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_cfg jsonb := (select value from public.app_config where key = 'daily_login');
  v_now timestamptz := now();
  v_today date := app_private.tr_day(v_now);
  p record;
  v_day int;
  v_streak int;
  v_reward jsonb;
  v_gold int;
  v_xp int;
  r jsonb := '{}'::jsonb;
  v_badge boolean := false;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  insert into public.player_login (user_id) values (v_me) on conflict do nothing;
  select * into p from public.player_login where user_id = v_me for update;     -- one claim at a time per player
  if p.last_claim_day = v_today then raise exception 'ALREADY_CLAIMED'; end if;
  v_day := p.next_cycle_day;
  v_reward := (select c from jsonb_array_elements(v_cfg->'cycle') c where (c->>'day')::int = v_day);
  v_gold := coalesce((v_reward->>'gold')::int, 0);
  v_xp := coalesce((v_reward->>'xp')::int, 0);
  v_streak := case when p.last_claim_day = v_today - 1 then p.streak + 1 else 1 end;
  insert into public.login_claims (user_id, claim_day, cycle_day, gold, xp) values (v_me, v_today, v_day, v_gold, v_xp);
  update public.player_login
     set next_cycle_day = case when v_day >= 7 then 1 else v_day + 1 end,
         cycles = cycles + case when v_day >= 7 then 1 else 0 end,
         streak = v_streak, best_streak = greatest(best_streak, v_streak),
         total_claims = total_claims + 1, last_claim_day = v_today, updated_at = v_now
   where user_id = v_me;
  if v_gold > 0 then
    perform game._apply(v_me, 'gold', v_gold, 'daily_login', format('login:%s:%s', v_me, v_today), 'login', v_today::text);
  end if;
  r := game._grant_xp(v_me, v_xp, 'daily_login', v_today::text);
  if v_reward ? 'badge' then
    insert into public.player_unlocks (user_id, kind, item_id, source)
    values (v_me, 'badge', v_reward->>'badge', 'daily_login') on conflict do nothing;
    v_badge := found;
  end if;
  perform game._quest_add(v_me, 'login_days', 1, v_now);
  return jsonb_build_object('day', v_day, 'gold', v_gold, 'xp', coalesce((r->>'xp')::int, 0), 'streak', v_streak,
                            'badge', case when v_badge then v_reward->>'badge' end,
                            'level_before', (r->>'level_before')::int, 'level_after', (r->>'level_after')::int,
                            'level_gold', coalesce((r->>'gold')::int, 0));
end;
$$;

revoke all on function public.daily_login_status(), public.claim_daily_login() from public, anon;
grant execute on function public.daily_login_status(), public.claim_daily_login() to authenticated;
