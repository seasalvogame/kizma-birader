-- Phase 6 tests (6.1 XP and levels; later sub-phases append sections).
--   npx supabase db query --remote --yes -f supabase/tests/phase6_test.sql
-- One transaction that always ends with an exception (nothing is kept).
-- Expected final message: TESTS_PASSED <n>

do $$
declare
  a  uuid := '00000000-0000-4000-8000-0000000006a1';
  b  uuid := '00000000-0000-4000-8000-0000000006b1';
  c  uuid := '00000000-0000-4000-8000-0000000006c1';
  d  uuid := '00000000-0000-4000-8000-0000000006d1';
  e  uuid := '00000000-0000-4000-8000-0000000006e1';
  f  uuid := '00000000-0000-4000-8000-0000000006f1';
  cfg jsonb := (select value from public.app_config where key = 'progression');
  me text := current_user;
  rs jsonb := '{"id":"classic_v1"}';
  n  int := 0;
  v_i int;
  v_b bigint;
  v_j jsonb;
  mid uuid;
  seats2 jsonb;
  gold_before bigint;
  q record;
  v_exp int;
  v_cnt int;
  v_today date := app_private.tr_day(now());   -- computed as the test owner (clients cannot call it)
begin
  insert into auth.users (id, aud, role, is_anonymous, created_at, updated_at) values
    (a, 'authenticated', 'authenticated', true, now(), now()), (b, 'authenticated', 'authenticated', true, now(), now()),
    (c, 'authenticated', 'authenticated', true, now(), now()), (d, 'authenticated', 'authenticated', true, now(), now()),
    (e, 'authenticated', 'authenticated', true, now(), now()), (f, 'authenticated', 'authenticated', true, now(), now());
  seats2 := format('[{"seat":0,"color":"red","user_id":"%s","rank":1,"rolls":30,"sixes":5,"captures":2,"finished":4},{"seat":1,"color":"yellow","user_id":"%s","rank":2,"rolls":28}]', a, b)::jsonb;

  ------------------------------------------------------------- 1. level curve
  if app_private.level_for_xp(0, cfg) <> 1 or app_private.level_for_xp(99, cfg) <> 1 or app_private.level_for_xp(100, cfg) <> 2
     or app_private.level_for_xp(224, cfg) <> 2 or app_private.level_for_xp(225, cfg) <> 3 then
    raise exception 'FAIL 1.1 level thresholds';
  end if; n := n + 1;
  if app_private.xp_at_level(5, cfg) <> 550 or app_private.xp_at_level(10, cfg) <> 1800 then raise exception 'FAIL 1.2 totals (doc table)'; end if; n := n + 1;
  if app_private.xp_to_next(60, cfg) <> app_private.xp_to_next(50, cfg) then raise exception 'FAIL 1.3 flat after 50'; end if; n := n + 1;
  if app_private.level_for_xp(100000000, cfg) <> (cfg->'level_curve'->>'max_level')::int then raise exception 'FAIL 1.4 max level'; end if; n := n + 1;

  ------------------------------------------------------- 2. XP from matches
  set local role game_server;
  mid := gen_random_uuid();
  v_j := game.record_match(mid, 'quick', rs, seats2, now() - interval '8 minutes', now(), 'finished', '', 1, 300, 't');
  execute format('set local role %I', me);
  if (v_j->'progress'->a::text->>'xp')::int <> 40 or (v_j->'progress'->b::text->>'xp')::int <> 15 then raise exception 'FAIL 2.1 2p xp %', v_j; end if; n := n + 1;
  select xp into v_b from public.profiles where user_id = a;
  if v_b <> 40 then raise exception 'FAIL 2.2 profile xp %', v_b; end if; n := n + 1;
  select xp_gained * 1000 + rolls into v_i from public.match_players where match_id = mid and user_id = a;
  if v_i <> 40030 then raise exception 'FAIL 2.3 seat xp and counters %', v_i; end if; n := n + 1;
  set local role game_server;
  v_j := game.record_match(mid, 'quick', rs, seats2, now() - interval '8 minutes', now(), 'finished', '', 1, 300, 't');
  execute format('set local role %I', me);
  select xp into v_b from public.profiles where user_id = a;
  if (v_j->>'applied')::boolean or v_b <> 40 then raise exception 'FAIL 2.4 recorded twice'; end if; n := n + 1;
  select count(*) into v_i from public.xp_events where user_id = a;
  if v_i <> 1 then raise exception 'FAIL 2.5 xp events %', v_i; end if; n := n + 1;

  -- private: half XP, rounded up; leaver: nothing; test: nothing
  set local role game_server;
  v_j := game.record_match(gen_random_uuid(), 'private', rs, seats2, now() - interval '5 minutes', now(), 'finished', '', 1, 100, 't');
  if (v_j->'progress'->a::text->>'xp')::int <> 20 or (v_j->'progress'->b::text->>'xp')::int <> 8 then raise exception 'FAIL 2.6 private xp %', v_j; end if; n := n + 1;
  v_j := game.record_match(gen_random_uuid(), 'quick', rs,
    format('[{"seat":0,"color":"red","user_id":"%s","rank":1},{"seat":1,"color":"yellow","user_id":"%s","rank":2,"left":true}]', a, b)::jsonb,
    now() - interval '1 minute', now(), 'left', '', 1, 10, 't');
  if (v_j->'progress'->b::text->>'xp')::int <> 0 then raise exception 'FAIL 2.7 leaver got xp'; end if; n := n + 1;
  v_j := game.record_match(gen_random_uuid(), 'test', rs, seats2, now() - interval '1 minute', now(), 'finished', '', 1, 10, 't');
  execute format('set local role %I', me);
  if v_j->'progress' <> '{}'::jsonb then raise exception 'FAIL 2.8 test match gave xp'; end if; n := n + 1;
  -- 4 players: 50 / 35 / 25 / 15
  set local role game_server;
  v_j := game.record_match(gen_random_uuid(), 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":4},{"seat":1,"color":"green","user_id":"%s","rank":1},{"seat":2,"color":"yellow","user_id":"%s","rank":2},{"seat":3,"color":"blue","user_id":"%s","rank":3}]', a, b, c, d)::jsonb,
    now() - interval '20 minutes', now(), 'finished', '', 1, 1500, 't');
  execute format('set local role %I', me);
  if (v_j->'progress'->b::text->>'xp')::int <> 50 or (v_j->'progress'->c::text->>'xp')::int <> 35
     or (v_j->'progress'->d::text->>'xp')::int <> 25 or (v_j->'progress'->a::text->>'xp')::int <> 15 then raise exception 'FAIL 2.9 4p xp %', v_j; end if; n := n + 1;

  ------------------------------------------------- 3. level-ups pay once
  update public.profiles set xp = 540, level = 1 where user_id = c;   -- just below level 5 (550)
  select coins into gold_before from public.wallets where user_id = c;
  set local role game_server;
  v_j := game.record_match(gen_random_uuid(), 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":1},{"seat":1,"color":"yellow","user_id":"%s","rank":2}]', c, d)::jsonb,
    now() - interval '6 minutes', now(), 'finished', '', 1, 200, 't');
  execute format('set local role %I', me);
  if (v_j->'progress'->c::text->>'level_after')::int <> 5 then raise exception 'FAIL 3.1 level after %', v_j; end if; n := n + 1;
  select coins - gold_before into v_b from public.wallets where user_id = c;
  if v_b <> 70 + 80 + 90 + 100 then raise exception 'FAIL 3.2 level gold %', v_b; end if; n := n + 1;
  select count(*) into v_i from public.wallet_transactions where user_id = c and reason = 'level_up';
  if v_i <> 4 then raise exception 'FAIL 3.3 ledger rows %', v_i; end if; n := n + 1;
  if not exists (select 1 from public.player_unlocks where user_id = c and kind = 'badge' and item_id = 'level_5') then raise exception 'FAIL 3.4 badge'; end if; n := n + 1;
  -- the same level is never paid twice (idempotency key per user and level)
  perform game._apply(c, 'gold', 100, 'level_up', format('level:%s:%s', c, 5), 'level', '5');
  select count(*) into v_i from public.wallet_transactions where user_id = c and reason = 'level_up';
  if v_i <> 4 then raise exception 'FAIL 3.5 level paid twice'; end if; n := n + 1;

  ----------------------------------------------------- 4. client side
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_j := public.my_progress();
  if (v_j->>'level')::int <> 5 or (v_j->>'xp_in_level')::int <> (v_j->>'xp')::int - 550 or (v_j->>'xp_for_next')::int <> 200
     or not (v_j->'badges') ? 'level_5' then raise exception 'FAIL 4.1 my_progress %', v_j; end if; n := n + 1;
  select count(*) into v_i from public.xp_events;
  if v_i <> 2 then raise exception 'FAIL 4.2 sees only own xp events (%)', v_i; end if; n := n + 1;
  begin
    update public.profiles set xp = 999999, level = 99 where user_id = c;
    raise exception 'FAIL 4.3 client changed its level';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    insert into public.xp_events (user_id, amount, reason, ref_id, level_after) values (c, 500, 'match', 'x', 9);
    raise exception 'FAIL 4.4 client wrote xp';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    perform game._grant_xp(c, 1000, 'match', 'fake');
    raise exception 'FAIL 4.5 client granted xp';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    insert into public.player_unlocks (user_id, kind, item_id, source) values (c, 'badge', 'level_100', 'x');
    raise exception 'FAIL 4.6 client unlocked a badge';
  exception when insufficient_privilege then n := n + 1;
  end;
  execute format('set local role %I', me);
  begin
    set local role game_server;
    perform game._grant_xp(c, 1000, 'match', 'fake');
    raise exception 'FAIL 4.7 game_server calls internals';
  exception when insufficient_privilege then n := n + 1;
  end;


  ------------------------------------------------- 5. quests (6.2): periods
  if app_private.tr_day('2026-11-17 20:59:59+00') <> '2026-11-17' or app_private.tr_day('2026-11-17 21:00:00+00') <> '2026-11-18' then
    raise exception 'FAIL 5.1 TR day boundary (00:00 UTC+3)';
  end if; n := n + 1;
  if app_private.tr_week('2026-11-22 20:59:59+00') <> '2026-11-16' or app_private.tr_week('2026-11-22 21:00:00+00') <> '2026-11-23' then
    raise exception 'FAIL 5.2 TR week boundary (Monday 00:00)';
  end if; n := n + 1;
  if app_private.tr_next_reset('daily', '2026-11-18 10:00:00+00') <> '2026-11-18 21:00:00+00' then raise exception 'FAIL 5.3 next daily reset'; end if; n := n + 1;

  ------------------------------------------- 6. quests: assignment and progress
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_j := public.my_quests();
  execute format('set local role %I', me);
  if jsonb_array_length(v_j->'daily') <> 3 or jsonb_array_length(v_j->'weekly') <> 4 then raise exception 'FAIL 6.1 3 daily + 4 weekly %', v_j; end if; n := n + 1;
  select count(distinct q2->>'quest_id') into v_i from jsonb_array_elements(v_j->'daily') q2;
  select count(*) into v_cnt from public.player_quests where user_id = d;
  if v_i <> 3 or v_cnt <> 7 then raise exception 'FAIL 6.2 distinct quests, stored once'; end if; n := n + 1;
  if (select count(distinct split_part(quest_id, '_', 2)) from public.player_quests where user_id = d and period = 'daily') <> 3 then
    raise exception 'FAIL 6.3 one quest per group';
  end if; n := n + 1;
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.my_quests();                                -- asking again changes nothing
  execute format('set local role %I', me);
  select count(*) into v_i from public.player_quests where user_id = d;
  if v_i <> 7 then raise exception 'FAIL 6.4 quests assigned twice'; end if; n := n + 1;

  -- a quick 2P win of d with 30 rolls: every metric of d's open quests advances by the server's numbers
  set local role game_server;
  perform game.record_match(gen_random_uuid(), 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":1,"rolls":30},{"seat":1,"color":"yellow","user_id":"%s","rank":2,"rolls":25}]', d, a)::jsonb,
    now() - interval '7 minutes', now(), 'finished', '', 1, 300, 't');
  execute format('set local role %I', me);
  for q in select * from public.player_quests where user_id = d loop
    -- d's matches in this test: 4P quick (3rd, §2.9), 2P quick lost (§3), this 2P win with 30 rolls
    v_exp := least(q.target, case q.metric when 'matches' then 3 when 'wins' then 1 when 'rolls' then 30 when 'matches_2p' then 2 when 'matches_4p' then 1 else 0 end);
    if q.progress <> v_exp then raise exception 'FAIL 6.5 % progress % expected %', q.quest_id, q.progress, v_exp; end if;
    if (q.completed_at is not null) <> (v_exp >= q.target) then raise exception 'FAIL 6.6 % completion', q.quest_id; end if;
  end loop; n := n + 2;
  -- private match without a friend: no quest progress; a leaver: no progress
  select coalesce(sum(progress), 0) into v_i from public.player_quests where user_id = d;
  set local role game_server;
  perform game.record_match(gen_random_uuid(), 'private', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":1,"rolls":40},{"seat":1,"color":"yellow","user_id":"%s","rank":2}]', d, a)::jsonb,
    now() - interval '7 minutes', now(), 'finished', '', 1, 300, 't');
  perform game.record_match(gen_random_uuid(), 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":2,"rolls":40,"left":true},{"seat":1,"color":"yellow","user_id":"%s","rank":1}]', d, a)::jsonb,
    now() - interval '2 minutes', now(), 'left', '', 1, 30, 't');
  execute format('set local role %I', me);
  select coalesce(sum(progress), 0) into v_cnt from public.player_quests where user_id = d;
  if v_cnt <> v_i then raise exception 'FAIL 6.7 private (no friend) / leaver advanced quests'; end if; n := n + 1;
  -- with a friend: friend_matches advances (also in a private room)
  insert into public.friendships (user_low, user_high) values (least(c, d), greatest(c, d));
  update public.player_quests set metric = 'friend_matches', target = 1 where user_id = d and period = 'weekly' and quest_id = (
    select quest_id from public.player_quests where user_id = d and period = 'weekly' and completed_at is null order by quest_id limit 1);
  set local role game_server;
  perform game.record_match(gen_random_uuid(), 'private', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":2},{"seat":1,"color":"yellow","user_id":"%s","rank":1}]', d, c)::jsonb,
    now() - interval '7 minutes', now(), 'finished', '', 1, 300, 't');
  execute format('set local role %I', me);
  if not exists (select 1 from public.player_quests where user_id = d and metric = 'friend_matches' and completed_at is not null) then
    raise exception 'FAIL 6.8 friend match progress';
  end if; n := n + 1;

  ----------------------------------------------------- 7. quests: claiming
  select coins into gold_before from public.wallets where user_id = d;
  select * into q from public.player_quests where user_id = d and completed_at is not null and claimed_at is null order by quest_id limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_j := public.claim_quest(q.period, q.period_key, q.quest_id);
  if (v_j->>'gold')::int <> q.gold or (v_j->>'xp')::int <> q.xp then raise exception 'FAIL 7.1 reward %', v_j; end if; n := n + 1;
  begin
    perform public.claim_quest(q.period, q.period_key, q.quest_id);
    raise exception 'FAIL 7.2 claimed twice';
  exception when others then if sqlerrm <> 'ALREADY_CLAIMED' then raise; end if; n := n + 1;
  end;
  begin
    perform public.claim_quest('daily', v_today, (select quest_id from public.player_quests where user_id = d and completed_at is null limit 1));
    raise exception 'FAIL 7.3 unfinished quest claimed';
  exception when others then if sqlerrm not in ('NOT_COMPLETED', 'QUEST_NOT_FOUND') then raise; end if; n := n + 1;
  end;
  begin
    update public.player_quests set progress = 999, completed_at = now() where user_id = d;
    raise exception 'FAIL 7.4 client changed quest progress';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    perform game._quest_add(d, 'wins', 50, now());
    raise exception 'FAIL 7.5 client added progress';
  exception when insufficient_privilege then n := n + 1;
  end;
  execute format('set local role %I', me);
  select coins - gold_before into v_b from public.wallets where user_id = d;
  if v_b <> q.gold then raise exception 'FAIL 7.6 gold once (%)', v_b; end if; n := n + 1;
  select count(*) into v_i from public.wallet_transactions where user_id = d and reason = 'quest';
  if v_i <> (case when q.gold > 0 then 1 else 0 end) then raise exception 'FAIL 7.7 ledger rows'; end if; n := n + 1;
  -- another player cannot claim d's quest (the caller is always the JWT user)
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    perform public.claim_quest(q.period, q.period_key, (select quest_id from public.player_quests where user_id = d and completed_at is not null and claimed_at is null limit 1));
    raise exception 'FAIL 7.8 claimed for another player';
  exception when others then if sqlerrm not in ('QUEST_NOT_FOUND', 'NOT_COMPLETED', 'ALREADY_CLAIMED') then raise; end if; n := n + 1;
  end;
  execute format('set local role %I', me);
  -- yesterday's completed quest stays claimable; it is listed as "unclaimed_old"
  insert into public.player_quests (user_id, period, period_key, quest_id, metric, target, progress, gold, xp, completed_at)
  values (d, 'daily', v_today - 1, 'd_play_1', 'matches', 1, 1, 60, 15, now() - interval '1 day');
  perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_j := public.my_quests();
  if jsonb_array_length(v_j->'unclaimed_old') < 1 then raise exception 'FAIL 7.9 old unclaimed quest not listed'; end if; n := n + 1;
  v_j := public.claim_quest('daily', v_today - 1, 'd_play_1');
  if (v_j->>'gold')::int <> 60 then raise exception 'FAIL 7.10 old quest claim'; end if; n := n + 1;
  execute format('set local role %I', me);


  ------------------------------------------ 8. reward guards (anti-farming)
  -- a match cut short by a leave (< min actions) gives no XP and no quest progress, even to the winner
  select xp into v_b from public.profiles where user_id = b;
  select coalesce(sum(progress), 0) into v_i from public.player_quests where user_id = b;
  set local role game_server;
  v_j := game.record_match(gen_random_uuid(), 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":2,"left":true},{"seat":1,"color":"yellow","user_id":"%s","rank":1,"rolls":3}]', c, b)::jsonb,
    now() - interval '20 seconds', now(), 'left', '', 1, 12, 't');
  execute format('set local role %I', me);
  if (v_j->'progress'->b::text->>'xp')::int <> 0 or (v_j->'progress'->b::text->>'counted')::boolean then raise exception 'FAIL 8.1 early leave rewarded %', v_j; end if; n := n + 1;
  select coalesce(sum(progress), 0) into v_cnt from public.player_quests where user_id = b;
  if v_cnt <> v_i then raise exception 'FAIL 8.2 early leave advanced quests'; end if; n := n + 1;
  -- a real match ended by a leave (enough actions) still counts for the remaining player
  set local role game_server;
  v_j := game.record_match(gen_random_uuid(), 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":2,"left":true},{"seat":1,"color":"yellow","user_id":"%s","rank":1}]', c, b)::jsonb,
    now() - interval '6 minutes', now(), 'left', '', 1, 140, 't');
  execute format('set local role %I', me);
  if (v_j->'progress'->b::text->>'xp')::int <> 40 then raise exception 'FAIL 8.3 real match after a leave %', v_j; end if; n := n + 1;
  -- daily cap on match XP
  select coalesce(sum(amount), 0) into v_i from public.xp_events where user_id = b and reason = 'match';   -- b's match XP today so far
  insert into public.xp_events (user_id, amount, reason, ref_id, level_after)
  values (b, ((cfg->'xp'->>'daily_match_xp_cap')::int) - 10 - v_i, 'match', 'cap-filler', 1);
  set local role game_server;
  v_j := game.record_match(gen_random_uuid(), 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":1},{"seat":1,"color":"yellow","user_id":"%s","rank":2}]', b, c)::jsonb,
    now() - interval '6 minutes', now(), 'finished', '', 1, 200, 't');
  v_cnt := (v_j->'progress'->b::text->>'xp')::int;
  v_j := game.record_match(gen_random_uuid(), 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":1},{"seat":1,"color":"yellow","user_id":"%s","rank":2}]', b, c)::jsonb,
    now() - interval '6 minutes', now(), 'finished', '', 1, 200, 't');
  execute format('set local role %I', me);
  if v_cnt <> 10 or (v_j->'progress'->b::text->>'xp')::int <> 0 then raise exception 'FAIL 8.4 daily match XP cap (% then %)', v_cnt, v_j->'progress'->b::text->>'xp'; end if; n := n + 1;


  -------------------------------------------- 9. daily login (6.3)
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_j := public.daily_login_status();
  if not (v_j->>'can_claim')::boolean or (v_j->>'next_day')::int <> 1 then raise exception 'FAIL 9.1 first status %', v_j; end if; n := n + 1;
  select coins into gold_before from public.wallets where user_id = a;
  v_j := public.claim_daily_login();
  if (v_j->>'day')::int <> 1 or (v_j->>'xp')::int <> 30 or (v_j->>'streak')::int <> 1 then raise exception 'FAIL 9.2 day 1 reward %', v_j; end if; n := n + 1;
  begin
    perform public.claim_daily_login();
    raise exception 'FAIL 9.3 second claim the same day';
  exception when others then if sqlerrm <> 'ALREADY_CLAIMED' then raise; end if; n := n + 1;
  end;
  v_j := public.daily_login_status();
  if (v_j->>'can_claim')::boolean or (v_j->>'next_day')::int <> 2 then raise exception 'FAIL 9.4 status after claim %', v_j; end if; n := n + 1;
  begin
    update public.player_login set last_claim_day = null where user_id = a;
    raise exception 'FAIL 9.5 client reset its login day';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    insert into public.login_claims (user_id, claim_day, cycle_day) values (a, v_today + 1, 2);
    raise exception 'FAIL 9.6 client wrote a claim';
  exception when insufficient_privilege then n := n + 1;
  end;
  execute format('set local role %I', me);
  -- "tomorrow": the previous claim was yesterday -> streak 2, day 2 pays gold
  update public.player_login set last_claim_day = v_today - 1 where user_id = a;
  delete from public.login_claims where user_id = a and claim_day = v_today;
  delete from public.wallet_transactions where user_id = a and idempotency_key = format('login:%s:%s', a, v_today);   -- simulated next day
  set local role authenticated;
  v_j := public.claim_daily_login();
  if (v_j->>'day')::int <> 2 or (v_j->>'gold')::int <> 100 or (v_j->>'streak')::int <> 2 then raise exception 'FAIL 9.7 consecutive day %', v_j; end if; n := n + 1;
  execute format('set local role %I', me);
  select coins - gold_before into v_b from public.wallets where user_id = a;
  if v_b < 100 then raise exception 'FAIL 9.8 gold not paid'; end if; n := n + 1;
  -- missed days: the cycle continues (day 3), the streak starts again at 1
  update public.player_login set last_claim_day = v_today - 3 where user_id = a;
  delete from public.login_claims where user_id = a and claim_day = v_today;
  delete from public.wallet_transactions where user_id = a and idempotency_key = format('login:%s:%s', a, v_today);   -- simulated next day
  set local role authenticated;
  v_j := public.claim_daily_login();
  if (v_j->>'day')::int <> 3 or (v_j->>'streak')::int <> 1 then raise exception 'FAIL 9.9 missed day rule %', v_j; end if; n := n + 1;
  execute format('set local role %I', me);
  -- day 7 closes the cycle: badge once, next day is 1 again
  update public.player_login set last_claim_day = v_today - 1, next_cycle_day = 7 where user_id = a;
  delete from public.login_claims where user_id = a and claim_day = v_today;
  delete from public.wallet_transactions where user_id = a and idempotency_key = format('login:%s:%s', a, v_today);   -- simulated next day
  set local role authenticated;
  v_j := public.claim_daily_login();
  if (v_j->>'day')::int <> 7 or (v_j->>'gold')::int <> 500 or v_j->>'badge' <> 'login_week' then raise exception 'FAIL 9.10 day 7 %', v_j; end if; n := n + 1;
  v_j := public.daily_login_status();
  if (v_j->>'next_day')::int <> 1 or (v_j->>'cycles')::int <> 1 then raise exception 'FAIL 9.11 new cycle %', v_j; end if; n := n + 1;
  execute format('set local role %I', me);
  -- the same day is never paid twice even with the ledger key (idempotency)
  select count(*) into v_i from public.wallet_transactions where user_id = a and reason = 'daily_login' and idempotency_key = format('login:%s:%s', a, v_today);
  if v_i <> 1 then raise exception 'FAIL 9.12 ledger rows for today %', v_i; end if; n := n + 1;
  -- every claim advances the weekly login quest (if the player has it)
  update public.player_quests set metric = 'login_days', target = 10, progress = 0, completed_at = null
   where user_id = a and period = 'weekly' and quest_id = (select quest_id from public.player_quests where user_id = a and period = 'weekly' order by quest_id limit 1);
  update public.player_login set last_claim_day = v_today - 1 where user_id = a;
  delete from public.login_claims where user_id = a and claim_day = v_today;
  delete from public.wallet_transactions where user_id = a and idempotency_key = format('login:%s:%s', a, v_today);   -- simulated next day
  set local role authenticated;
  perform public.my_quests();
  perform public.claim_daily_login();
  execute format('set local role %I', me);
  if not exists (select 1 from public.player_quests where user_id = a and metric = 'login_days' and progress = 1) then
    raise exception 'FAIL 9.13 login quest progress';
  end if; n := n + 1;


  -------------------------------------------- 10. achievements (6.4)
  set local role game_server;
  v_j := game.record_match(gen_random_uuid(), 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":1},{"seat":1,"color":"yellow","user_id":"%s","rank":2}]', e, f)::jsonb,
    now() - interval '7 minutes', now(), 'finished', '', 1, 200, 't');
  execute format('set local role %I', me);
  if not (v_j->'progress'->e::text->'achievements') @> '["first_match","first_win"]'::jsonb
     or not (v_j->'progress'->f::text->'achievements') @> '["first_match"]'::jsonb
     or (v_j->'progress'->f::text->'achievements') @> '["first_win"]'::jsonb then raise exception 'FAIL 10.1 first achievements %', v_j; end if; n := n + 1;
  -- two more wins: streak 3 reached; then a loss resets the current streak, the best stays
  set local role game_server;
  for v_i in 1..2 loop
    perform game.record_match(gen_random_uuid(), 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":1},{"seat":1,"color":"yellow","user_id":"%s","rank":2}]', e, f)::jsonb,
      now() - interval '7 minutes', now(), 'finished', '', 1, 200, 't');
  end loop;
  perform game.record_match(gen_random_uuid(), 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":2},{"seat":1,"color":"yellow","user_id":"%s","rank":1}]', e, f)::jsonb,
    now() - interval '7 minutes', now(), 'finished', '', 1, 200, 't');
  execute format('set local role %I', me);
  select win_streak * 100 + best_win_streak * 10 + quick_wins into v_i from public.player_counters where user_id = e;
  if v_i <> 0 * 100 + 3 * 10 + 3 then raise exception 'FAIL 10.2 streak counters %', v_i; end if; n := n + 1;
  if not exists (select 1 from public.player_achievements where user_id = e and achievement_id = 'streak_3') then raise exception 'FAIL 10.3 streak_3'; end if; n := n + 1;
  -- a match cut short by a leave changes no counter; a private match only the social one
  select to_jsonb(pc) - 'updated_at' into v_j from public.player_counters pc where user_id = e;
  set local role game_server;
  perform game.record_match(gen_random_uuid(), 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":1},{"seat":1,"color":"yellow","user_id":"%s","rank":2,"left":true}]', e, f)::jsonb,
    now() - interval '20 seconds', now(), 'left', '', 1, 8, 't');
  execute format('set local role %I', me);
  if (select to_jsonb(pc) - 'updated_at' from public.player_counters pc where user_id = e) <> v_j then raise exception 'FAIL 10.4 short match changed counters'; end if; n := n + 1;
  insert into public.friendships (user_low, user_high) values (least(e, f), greatest(e, f));
  update public.player_counters set friend_matches = 9 where user_id = e;
  set local role game_server;
  v_j := game.record_match(gen_random_uuid(), 'private', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":1},{"seat":1,"color":"yellow","user_id":"%s","rank":2}]', e, f)::jsonb,
    now() - interval '7 minutes', now(), 'finished', '', 1, 200, 't');
  execute format('set local role %I', me);
  select quick_matches * 100 + friend_matches into v_i from public.player_counters where user_id = e;
  if v_i <> 4 * 100 + 10 or not (v_j->'progress'->e::text->'achievements') @> '["friends_10"]'::jsonb then
    raise exception 'FAIL 10.5 private match: social only (%) %', v_i, v_j;
  end if; n := n + 1;

  -- claiming
  perform set_config('request.jwt.claims', json_build_object('sub', e, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_j := public.my_achievements();
  if jsonb_array_length(v_j->'achievements') <> jsonb_array_length((select value->'achievements' from public.app_config where key = 'achievements')) then
    raise exception 'FAIL 10.6 list';
  end if; n := n + 1;
  if not exists (select 1 from jsonb_array_elements(v_j->'achievements') x where x->>'id' = 'matches_10' and (x->>'progress')::int = 4 and not (x->>'completed')::boolean) then
    raise exception 'FAIL 10.7 progress of an open achievement';
  end if; n := n + 1;
  v_j := public.claim_achievement('friends_10');
  if (v_j->>'gold')::int <> 300 or v_j->>'badge' <> 'social' then raise exception 'FAIL 10.8 claim %', v_j; end if; n := n + 1;
  begin
    perform public.claim_achievement('friends_10');
    raise exception 'FAIL 10.9 claimed twice';
  exception when others then if sqlerrm <> 'ALREADY_CLAIMED' then raise; end if; n := n + 1;
  end;
  begin
    perform public.claim_achievement('matches_100');
    raise exception 'FAIL 10.10 claimed an unreached achievement';
  exception when others then if sqlerrm <> 'NOT_COMPLETED' then raise; end if; n := n + 1;
  end;
  begin
    perform public.claim_achievement('no_such');
    raise exception 'FAIL 10.11 unknown achievement';
  exception when others then if sqlerrm <> 'ACHIEVEMENT_NOT_FOUND' then raise; end if; n := n + 1;
  end;
  -- badges on the profile: only unlocked ones
  begin
    perform public.set_profile_badge('champion');
    raise exception 'FAIL 10.12 locked badge shown';
  exception when others then if sqlerrm <> 'BADGE_LOCKED' then raise; end if; n := n + 1;
  end;
  v_j := public.set_profile_badge('social');
  v_j := public.my_progress();
  if v_j->>'badge_id' <> 'social' then raise exception 'FAIL 10.13 badge selected %', v_j; end if; n := n + 1;
  begin
    update public.player_counters set quick_wins = 999 where user_id = e;
    raise exception 'FAIL 10.14 client changed counters';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    insert into public.player_achievements (user_id, achievement_id) values (e, 'wins_50');
    raise exception 'FAIL 10.15 client completed an achievement';
  exception when insufficient_privilege then n := n + 1;
  end;
  execute format('set local role %I', me);
  perform set_config('request.jwt.claims', json_build_object('sub', f, 'role', 'authenticated')::text, true);
  set local role authenticated;
  if public.get_player_profile(e)->>'badge_id' <> 'social' then raise exception 'FAIL 10.16 friend sees the badge'; end if; n := n + 1;
  execute format('set local role %I', me);

  raise exception 'TESTS_PASSED %', n;
end
$$;
