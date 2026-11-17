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
begin
  insert into auth.users (id, aud, role, is_anonymous, created_at, updated_at) values
    (a, 'authenticated', 'authenticated', true, now(), now()), (b, 'authenticated', 'authenticated', true, now(), now()),
    (c, 'authenticated', 'authenticated', true, now(), now()), (d, 'authenticated', 'authenticated', true, now(), now());
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

  raise exception 'TESTS_PASSED %', n;
end
$$;
