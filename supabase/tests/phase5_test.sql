-- Phase 5 tests: friends (search, requests, accept/decline, cancel, duplicates,
-- remove, block/unblock, profiles) and the game_server social checks.
--   npx supabase db query --remote --yes -f supabase/tests/phase5_test.sql
-- One transaction that always ends with an exception (nothing is kept).
-- Expected final message: TESTS_PASSED <n>

do $$
declare
  a uuid := '00000000-0000-4000-8000-0000000005a1';
  b uuid := '00000000-0000-4000-8000-0000000005b1';
  c uuid := '00000000-0000-4000-8000-0000000005c1';
  me text := current_user;
  n int := 0;
  v_i int;
  v_t text;
  v_j jsonb;
  v_req bigint;
begin
  insert into auth.users (id, aud, role, is_anonymous, created_at, updated_at) values
    (a, 'authenticated', 'authenticated', true, now(), now()),
    (b, 'authenticated', 'authenticated', true, now(), now()),
    (c, 'authenticated', 'authenticated', true, now(), now());
  update public.profiles set display_name = 'Zeynepp', tag = 1111 where user_id = a;
  update public.profiles set display_name = 'Zeynepq', tag = 2222 where user_id = b;
  update public.profiles set display_name = 'Zebra', tag = 3333 where user_id = c;

  ------------------------------------------------------------------ search
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_i from public.search_players('zeyn');
  if v_i <> 1 then raise exception 'FAIL 1.1 search finds others but not self (%)', v_i; end if; n := n + 1;
  select count(*) into v_i from public.search_players('Zeynepq#2222');
  if v_i <> 1 then raise exception 'FAIL 1.2 name#tag search'; end if; n := n + 1;
  select count(*) into v_i from public.search_players('Zeynepq#9999');
  if v_i <> 0 then raise exception 'FAIL 1.3 wrong tag found'; end if; n := n + 1;
  select count(*) into v_i from public.search_players('z%');
  if v_i <> 0 then raise exception 'FAIL 1.4 wildcard not escaped'; end if; n := n + 1;

  ---------------------------------------------------------------- requests
  begin
    perform public.send_friend_request(a);
    raise exception 'FAIL 2.1 request to self';
  exception when others then if sqlerrm <> 'SELF' then raise; end if; n := n + 1;
  end;
  v_j := public.send_friend_request(b);
  if v_j->>'status' <> 'pending' then raise exception 'FAIL 2.2 request %', v_j; end if; n := n + 1;
  v_req := (v_j->>'request_id')::bigint;
  begin
    perform public.send_friend_request(b);
    raise exception 'FAIL 2.3 duplicate request';
  exception when others then if sqlerrm <> 'ALREADY_PENDING' then raise; end if; n := n + 1;
  end;
  select relation into v_t from public.search_players('Zeynepq');
  if v_t <> 'outgoing' then raise exception 'FAIL 2.4 relation %', v_t; end if; n := n + 1;
  begin
    perform public.respond_friend_request(v_req, true);   -- A cannot accept its own request
    raise exception 'FAIL 2.5 sender accepted';
  exception when others then if sqlerrm <> 'REQUEST_NOT_FOUND' then raise; end if; n := n + 1;
  end;
  begin
    insert into public.friendships (user_low, user_high) values (least(a, c), greatest(a, c));
    raise exception 'FAIL 2.6 direct friendship insert';
  exception when insufficient_privilege then n := n + 1;
  end;

  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into v_i from public.my_friend_requests() where direction = 'in' and user_id = a;
  if v_i <> 1 then raise exception 'FAIL 2.7 incoming request not listed'; end if; n := n + 1;
  v_j := public.respond_friend_request(v_req, true);
  if v_j->>'status' <> 'accepted' then raise exception 'FAIL 2.8 accept'; end if; n := n + 1;
  select count(*) into v_i from public.my_friends() where user_id = a;
  if v_i <> 1 then raise exception 'FAIL 2.9 friend list'; end if; n := n + 1;
  begin
    perform public.send_friend_request(a);
    raise exception 'FAIL 2.10 request to a friend';
  exception when others then if sqlerrm <> 'ALREADY_FRIENDS' then raise; end if; n := n + 1;
  end;

  -- C -> A, A declines; C -> B, C cancels; mutual request = accept
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  v_req := (public.send_friend_request(a)->>'request_id')::bigint;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  v_j := public.respond_friend_request(v_req, false);
  if v_j->>'status' <> 'declined' then raise exception 'FAIL 3.1 decline'; end if; n := n + 1;
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  v_req := (public.send_friend_request(b)->>'request_id')::bigint;
  perform public.cancel_friend_request(v_req);
  select count(*) into v_i from public.my_friend_requests();
  if v_i <> 0 then raise exception 'FAIL 3.2 cancelled request still listed'; end if; n := n + 1;
  perform public.send_friend_request(b);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  v_j := public.send_friend_request(c);
  if v_j->>'status' <> 'accepted' then raise exception 'FAIL 3.3 mutual request becomes friendship'; end if; n := n + 1;

  ------------------------------------------------------------ remove, block
  v_j := public.remove_friend(c);
  if not (v_j->>'removed')::boolean then raise exception 'FAIL 4.1 remove'; end if; n := n + 1;
  perform public.block_player(a);                    -- B blocks A (they were friends)
  select count(*) into v_i from public.my_friends() where user_id = a;
  if v_i <> 0 then raise exception 'FAIL 4.2 block removes the friendship'; end if; n := n + 1;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  select count(*) into v_i from public.search_players('Zeynepq');
  if v_i <> 0 then raise exception 'FAIL 4.3 blocked player still searchable'; end if; n := n + 1;
  begin
    perform public.send_friend_request(b);
    raise exception 'FAIL 4.4 request despite block';
  exception when others then if sqlerrm <> 'NOT_ALLOWED' then raise; end if; n := n + 1;
  end;
  begin
    perform public.get_player_profile(b);
    raise exception 'FAIL 4.5 profile of a blocker';
  exception when others then if sqlerrm <> 'NOT_FOUND' then raise; end if; n := n + 1;
  end;
  select count(*) into v_i from public.blocks;            -- A cannot see that B blocked A
  if v_i <> 0 then raise exception 'FAIL 4.6 who blocked me is visible'; end if; n := n + 1;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into v_i from public.my_blocks() where user_id = a;
  if v_i <> 1 then raise exception 'FAIL 4.7 my blocks'; end if; n := n + 1;
  perform public.unblock_player(a);
  v_j := public.get_player_profile(a);
  if v_j->>'relation' <> 'none' or (v_j->>'matches_2p')::int <> 0 then raise exception 'FAIL 4.8 profile after unblock %', v_j; end if; n := n + 1;
  begin
    update public.blocks set blocked_id = c;
    raise exception 'FAIL 4.9 direct block change';
  exception when insufficient_privilege then n := n + 1;
  end;
  execute format('set local role %I', me);

  ------------------------------------------------------------- game_server
  set local role game_server;
  v_j := game.social_check(b, c);
  if (v_j->>'friends')::boolean or (v_j->>'blocked')::boolean then raise exception 'FAIL 5.1 social_check %', v_j; end if; n := n + 1;
  execute format('set local role %I', me);
  insert into public.friendships (user_low, user_high) values (least(a, c), greatest(a, c));
  set local role game_server;
  if not (game.social_check(c, a)->>'friends')::boolean then raise exception 'FAIL 5.2 friends'; end if; n := n + 1;
  if cardinality(game.friend_ids(a)) <> 1 then raise exception 'FAIL 5.3 friend_ids'; end if; n := n + 1;
  execute format('set local role %I', me);
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
    set local role authenticated;
    perform game.friend_ids(a);
    raise exception 'FAIL 5.4 client reads friend ids of the server';
  exception when insufficient_privilege then n := n + 1;
  end;
  execute format('set local role %I', me);
  begin
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    set local role anon;
    perform public.send_friend_request(a);
    raise exception 'FAIL 5.5 anon request';
  exception when insufficient_privilege then n := n + 1;
  end;

  raise exception 'TESTS_PASSED %', n;
end
$$;
