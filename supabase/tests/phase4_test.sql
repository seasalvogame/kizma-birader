-- Phase 4 tests: profile editing, match records, stats, privileges.
--   npx supabase db query --remote --yes -f supabase/tests/phase4_test.sql
-- One transaction that always ends with an exception (nothing is kept).
-- Expected final message: TESTS_PASSED <n>

do $$
declare
  a  uuid := '00000000-0000-4000-8000-0000000004a1';
  b  uuid := '00000000-0000-4000-8000-0000000004b1';
  m1 uuid := '00000000-0000-4000-8000-0000000004e1';
  m2 uuid := '00000000-0000-4000-8000-0000000004e2';
  m3 uuid := '00000000-0000-4000-8000-0000000004e3';
  m4 uuid := '00000000-0000-4000-8000-0000000004e4';
  rs jsonb := '{"id":"classic_v1"}';
  me text := current_user;
  n  int := 0;
  v_i int;
  v_t text;
  v_j jsonb;
  bad text;
  seats2 jsonb;
begin
  insert into auth.users (id, aud, role, is_anonymous, created_at, updated_at) values
    (a, 'authenticated', 'authenticated', true, now(), now()),
    (b, 'authenticated', 'authenticated', true, now(), now());
  seats2 := format('[{"seat":0,"color":"red","user_id":"%s","rank":1},{"seat":1,"color":"yellow","user_id":"%s","rank":2}]', a, b)::jsonb;

  ------------------------------------------------------------ 1. profile editing
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_j := public.update_my_profile('  Ayşe Öz  ', 'fill:2');
  if v_j->>'display_name' <> 'Ayşe Öz' or v_j->>'avatar_id' <> 'fill:2' then raise exception 'FAIL 1.1 update %', v_j; end if; n := n + 1;
  execute format('set local role %I', me);

  foreach bad in array array['ab', 'a<b', 'x2345678901234567', 'a  b', '-abc', 'abc.', '😀😀😀'] loop
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
      set local role authenticated;
      perform public.update_my_profile(bad, null);
      raise exception 'FAIL 1.2 name accepted: %', bad;
    exception when others then
      if sqlerrm <> 'NAME_INVALID' then raise; end if; n := n + 1;
    end;
  end loop;
  begin
    set local role authenticated;
    perform public.update_my_profile(null, 'fill:9');
    raise exception 'FAIL 1.3 avatar accepted';
  exception when others then
    if sqlerrm <> 'AVATAR_INVALID' then raise; end if; n := n + 1;
  end;
  begin
    set local role authenticated;
    update public.profiles set display_name = 'Hacker' where user_id = b;
    raise exception 'FAIL 1.4 direct profile update allowed';
  exception when insufficient_privilege then n := n + 1;
  end;
  select display_name into v_t from public.profiles where user_id = b;
  if v_t <> 'Oyuncu' then raise exception 'FAIL 1.5 B changed by A: %', v_t; end if; n := n + 1;

  -- same name + same tag is impossible: B gets another tag
  update public.profiles set tag = (select tag from public.profiles where user_id = a) where user_id = b;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_j := public.update_my_profile('ayşe öz', null);
  execute format('set local role %I', me);
  if (v_j->>'tag')::int = (select tag from public.profiles where user_id = a) then raise exception 'FAIL 1.6 duplicate name#tag'; end if; n := n + 1;

  begin
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    set local role anon;
    perform public.update_my_profile('Anon', null);
    raise exception 'FAIL 1.7 anon updated a profile';
  exception when insufficient_privilege then n := n + 1;
  end;

  --------------------------------------------------------- 2. match records
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
    set local role authenticated;
    perform game.record_match(m1, 'quick', rs, seats2, now() - interval '9 minutes', now(), 'finished', 'r6 m0', 123, 2, 'v1');
    raise exception 'FAIL 2.1 player recorded a match';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    set local role authenticated;
    insert into public.matches (id, mode, players, ruleset, status) values (m4, 'quick', 2, rs, 'finished');
    raise exception 'FAIL 2.2 player inserted a match';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    set local role authenticated;
    update public.player_stats set wins_2p = 99 where user_id = a;
    raise exception 'FAIL 2.3 player changed stats';
  exception when insufficient_privilege then n := n + 1;
  end;

  set local role game_server;
  v_j := game.record_match(m1, 'quick', rs, seats2, now() - interval '9 minutes', now(), 'finished', 'r6 m0 r3', 4242, 3, 'test-ver');
  if not (v_j->>'applied')::boolean then raise exception 'FAIL 2.4 record'; end if; n := n + 1;
  v_j := game.record_match(m1, 'quick', rs, seats2, now() - interval '9 minutes', now(), 'finished', 'r6 m0 r3', 4242, 3, 'test-ver');
  if (v_j->>'applied')::boolean then raise exception 'FAIL 2.5 recorded twice'; end if; n := n + 1;
  execute format('set local role %I', me);
  select matches_2p * 100 + wins_2p * 10 + leaves into v_i from public.player_stats where user_id = a;
  if v_i <> 110 then raise exception 'FAIL 2.6 A stats %', v_i; end if; n := n + 1;
  select matches_2p * 100 + wins_2p * 10 + leaves into v_i from public.player_stats where user_id = b;
  if v_i <> 100 then raise exception 'FAIL 2.7 B stats %', v_i; end if; n := n + 1;
  select count(*) into v_i from public.match_players where match_id = m1 and display_name is not null and tag is not null;
  if v_i <> 2 then raise exception 'FAIL 2.8 names not stored'; end if; n := n + 1;
  select count(*) into v_i from public.matches where id = m1 and final_state_hash = 4242 and action_count = 3 and server_version = 'test-ver' and ended_at > started_at;
  if v_i <> 1 then raise exception 'FAIL 2.9 verification fields'; end if; n := n + 1;

  -- test matches are stored but never counted in stats
  set local role game_server;
  perform game.record_match(m2, 'test', rs, seats2, now() - interval '1 minute', now(), 'finished', '', 1, 1, 'test-ver');
  execute format('set local role %I', me);
  select matches_2p into v_i from public.player_stats where user_id = a;
  if v_i <> 1 then raise exception 'FAIL 2.10 test match counted'; end if; n := n + 1;

  -- invalid results are refused before anything is written
  foreach bad in array array[
      format('[{"seat":0,"color":"red","user_id":"%s","rank":1},{"seat":1,"color":"yellow","user_id":"%s","rank":1}]', a, b),
      format('[{"seat":0,"color":"red","user_id":"%s","rank":1},{"seat":1,"color":"green","user_id":"%s","rank":2}]', a, b),
      format('[{"seat":0,"color":"red","user_id":"%s","rank":1},{"seat":1,"color":"yellow","user_id":"%s","rank":2}]', a, '00000000-0000-4000-8000-00000000dead')] loop
    begin
      set local role game_server;
      perform game.record_match(m3, 'quick', rs, bad::jsonb, now() - interval '1 minute', now(), 'finished', '', 1, 1, 'v');
      raise exception 'FAIL 2.11 invalid result accepted: %', bad;
    exception when others then
      if sqlerrm not in ('BAD_RANKS', 'COLOR_INVALID', 'UNKNOWN_PLAYER') then raise; end if; n := n + 1;
    end;
  end loop;
  select count(*) into v_i from public.matches where id = m3;
  if v_i <> 0 then raise exception 'FAIL 2.12 partial record left'; end if; n := n + 1;

  -- 4 players (A + 3 bots): all four places, only the human counted
  set local role game_server;
  perform game.record_match(m4, 'quick', rs, format('[{"seat":0,"color":"red","user_id":"%s","rank":3},{"seat":1,"color":"green","is_bot":true,"rank":1,"name":"Bot 1"},{"seat":2,"color":"yellow","is_bot":true,"rank":2,"name":"Bot 2"},{"seat":3,"color":"blue","is_bot":true,"rank":4,"name":"Bot 3"}]', a)::jsonb,
    now() - interval '30 minutes', now(), 'finished', '', 1, 900, 'v');
  execute format('set local role %I', me);
  select matches_4p * 10 + wins_4p into v_i from public.player_stats where user_id = a;
  if v_i <> 10 then raise exception 'FAIL 2.13 4p stats %', v_i; end if; n := n + 1;

  ---------------------------------------------------- 3. reads through RLS
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_i from public.matches where id in (m1, m4);
  if v_i <> 2 then raise exception 'FAIL 3.1 A sees % own matches', v_i; end if; n := n + 1;
  select count(*) into v_i from public.match_players where match_id = m1;
  if v_i <> 2 then raise exception 'FAIL 3.2 A sees % seats', v_i; end if; n := n + 1;
  execute format('set local role %I', me);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_i from public.matches where id = m4;
  if v_i <> 0 then raise exception 'FAIL 3.3 B sees a match it did not play'; end if; n := n + 1;
  select count(*) into v_i from public.player_stats where user_id = a;
  if v_i <> 0 then raise exception 'FAIL 3.4 B sees A stats'; end if; n := n + 1;
  execute format('set local role %I', me);

  ----------------------------------------------------------- 4. game_server
  set local role game_server;
  select count(*) into v_i from game.player_names(array[a, b]);
  if v_i <> 2 then raise exception 'FAIL 4.1 player_names'; end if; n := n + 1;
  execute format('set local role %I', me);
  begin
    set local role game_server;
    perform count(*) from public.profiles;
    raise exception 'FAIL 4.2 game_server reads tables';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    set local role game_server;
    perform public.update_my_profile('Server', null);
    raise exception 'FAIL 4.3 game_server edits profiles';
  exception when insufficient_privilege then n := n + 1;
  end;

  raise exception 'TESTS_PASSED %', n;
end
$$;
