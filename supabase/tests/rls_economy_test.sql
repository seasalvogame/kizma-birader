-- RLS, privilege and economy tests for the Kızma Birader schema.
--
-- Run against the linked (dev) project:
--   npx supabase db query --remote --yes -f supabase/tests/rls_economy_test.sql
--
-- Everything happens inside one transaction that ALWAYS ends with an
-- exception, so nothing it creates is kept. Expected final message:
--   TESTS_PASSED <n>
-- Any other message names the first failing check.

do $$
declare
  a    uuid := '00000000-0000-4000-8000-0000000000a1';
  b    uuid := '00000000-0000-4000-8000-0000000000b1';
  c    uuid := '00000000-0000-4000-8000-0000000000c1';
  m1   uuid := '00000000-0000-4000-8000-0000000000e1';
  m2   uuid := '00000000-0000-4000-8000-0000000000e2';
  m3   uuid := '00000000-0000-4000-8000-0000000000e3';
  m4   uuid := '00000000-0000-4000-8000-0000000000e4';
  m5   uuid := '00000000-0000-4000-8000-0000000000e5';
  m6   uuid := '00000000-0000-4000-8000-0000000000e6';
  rs   jsonb := '{"id": "classic_v1"}';
  seats_ab   jsonb := format('[{"seat":0,"color":"red","user_id":"%s"},{"seat":1,"color":"yellow","user_id":"%s"}]', a, b)::jsonb;
  seats_ac   jsonb := format('[{"seat":0,"color":"green","user_id":"%s"},{"seat":1,"color":"blue","user_id":"%s"}]', a, c)::jsonb;
  seats_bad  jsonb := format('[{"seat":0,"color":"red","user_id":"%s"},{"seat":1,"color":"green","user_id":"%s"}]', a, b)::jsonb;
  seats_bot  jsonb := format('[{"seat":0,"color":"red","user_id":"%s"},{"seat":1,"color":"yellow","is_bot":true}]', a)::jsonb;
  me   text := current_user;
  n    int := 0;
  v_i  int;
  v_b  bigint;
  v_t  text;
  v_j  jsonb;

  -- helpers implemented inline below:
  --   claims for user X:  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role', 'authenticated')::text, true);
begin
  ---------------------------------------------------------------- setup
  insert into auth.users (id, aud, role, is_anonymous, created_at, updated_at) values
    (a, 'authenticated', 'authenticated', true, now(), now()),
    (b, 'authenticated', 'authenticated', true, now(), now()),
    (c, 'authenticated', 'authenticated', true, now(), now());

  ------------------------------------------- 1. new-user bootstrap (trigger)
  select coins into v_b from public.wallets where user_id = a;
  if v_b is distinct from 1000 then raise exception 'FAIL 1.1 starting gold = %', v_b; end if; n := n + 1;
  select count(*) into v_i from public.wallet_transactions where user_id = a and reason = 'starting_gold';
  if v_i <> 1 then raise exception 'FAIL 1.2 starting ledger rows = %', v_i; end if; n := n + 1;
  select count(*) into v_i from public.profiles where user_id in (a, b, c) and display_name = 'Oyuncu' and tag between 1000 and 99999;
  if v_i <> 3 then raise exception 'FAIL 1.3 profiles = %', v_i; end if; n := n + 1;
  select count(*) into v_i from public.player_stats where user_id in (a, b, c);
  if v_i <> 3 then raise exception 'FAIL 1.4 stats = %', v_i; end if; n := n + 1;

  ------------------------------------------ 2. authenticated player A (RLS)
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_i from public.profiles;
  if v_i <> 1 then raise exception 'FAIL 2.1 A sees % profiles', v_i; end if; n := n + 1;
  select count(*) into v_i from public.wallets where user_id = a;
  if v_i <> 1 then raise exception 'FAIL 2.2 A cannot see own wallet'; end if; n := n + 1;
  select count(*) into v_i from public.wallets where user_id <> a;
  if v_i <> 0 then raise exception 'FAIL 2.3 A sees other wallets'; end if; n := n + 1;
  select count(*) into v_i from public.wallet_transactions where user_id <> a;
  if v_i <> 0 then raise exception 'FAIL 2.4 A sees other ledgers'; end if; n := n + 1;
  select count(*) into v_i from public.app_config where key in ('economy', 'features');
  if v_i <> 2 then raise exception 'FAIL 2.5 public config not readable'; end if; n := n + 1;
  select count(*) into v_i from public.get_profile_cards(array[b, c]);
  if v_i <> 2 then raise exception 'FAIL 2.6 profile cards = %', v_i; end if; n := n + 1;
  execute format('set local role %I', me);

  -- A cannot write anything directly (each block is rolled back on its own)
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
    set local role authenticated;
    update public.wallets set coins = 999999 where user_id = a;
    raise exception 'FAIL 2.7 wallet update allowed';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    set local role authenticated;
    insert into public.wallet_transactions (user_id, currency, delta, balance_after, reason, idempotency_key)
    values (a, 'gold', 5, 5, 'compensation', 'x');
    raise exception 'FAIL 2.8 ledger insert allowed';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    set local role authenticated;
    delete from public.profiles where user_id = a;
    raise exception 'FAIL 2.9 profile delete allowed';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    set local role authenticated;
    insert into public.matches (id, mode, players, ruleset, status) values (m6, 'quick', 2, rs, 'finished');
    raise exception 'FAIL 2.10 match insert allowed';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    set local role authenticated;
    perform game.grant_purchase(a, 'google', 'sandbox', 'gold_s', 'FAKE', 'gold', 100000, '{}');
    raise exception 'FAIL 2.11 client called a server function';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    set local role authenticated;
    perform game._apply(a, 'gold', 100000, 'compensation', 'hack');
    raise exception 'FAIL 2.12 client called _apply';
  exception when insufficient_privilege then n := n + 1;
  end;

  ------------------------------------------------- 3. anonymous (no login)
  begin
    perform set_config('request.jwt.claims', '{"role": "anon"}', true);
    set local role anon;
    perform count(*) from public.profiles;
    raise exception 'FAIL 3.1 anon reads profiles';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    set local role anon;
    perform count(*) from public.wallets;
    raise exception 'FAIL 3.2 anon reads wallets';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    set local role anon;
    perform * from public.get_profile_cards(array[a]);
    raise exception 'FAIL 3.3 anon reads profile cards';
  exception when insufficient_privilege then n := n + 1;
  end;
  perform set_config('request.jwt.claims', '{"role": "anon"}', true);
  set local role anon;
  select count(*) into v_i from public.app_config where is_public;
  if v_i < 2 then raise exception 'FAIL 3.4 anon cannot read public config'; end if; n := n + 1;
  execute format('set local role %I', me);

  ------------------------------------- 4. restricted game server role (K-59)
  begin
    set local role game_server;
    perform count(*) from public.wallets;
    raise exception 'FAIL 4.1 game_server reads tables directly';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    set local role game_server;
    perform game._apply(a, 'gold', 5, 'compensation', 'k');
    raise exception 'FAIL 4.2 game_server calls internal helper';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    set local role game_server;
    perform game.start_match(m1, 'quick', rs, 'lobby_100', 100, 1, seats_ab);
    raise exception 'FAIL 4.3 gold match allowed while disabled';
  exception when others then
    if sqlerrm <> 'GOLD_MATCHES_DISABLED' then raise; end if; n := n + 1;
  end;

  -- enable gold matches for the rest of the test (rolled back at the end)
  update public.app_config set value = jsonb_set(value, '{gold_matches_enabled}', 'true') where key = 'features';

  begin
    set local role game_server;
    perform game.start_match(m1, 'quick', rs, 'lobby_100', 100, 1, seats_bad);
    raise exception 'FAIL 4.4 non-opposite colours accepted';
  exception when others then
    if sqlerrm <> 'COLOR_INVALID' then raise; end if; n := n + 1;
  end;
  begin
    set local role game_server;
    perform game.start_match(m1, 'quick', rs, 'lobby_100', 100, 1, seats_bot);
    raise exception 'FAIL 4.5 bot in gold match accepted';
  exception when others then
    if sqlerrm <> 'BOTS_IN_GOLD_MATCH' then raise; end if; n := n + 1;
  end;

  set local role game_server;
  v_j := game.start_match(m1, 'quick', rs, 'lobby_100', 100, 1, seats_ab);
  if not (v_j->>'created')::boolean then raise exception 'FAIL 4.6 start_match'; end if; n := n + 1;
  v_j := game.start_match(m1, 'quick', rs, 'lobby_100', 100, 1, seats_ab);   -- retry
  if (v_j->>'created')::boolean then raise exception 'FAIL 4.7 start_match not idempotent'; end if; n := n + 1;
  execute format('set local role %I', me);
  select coins into v_b from public.wallets where user_id = a;
  if v_b <> 900 then raise exception 'FAIL 4.8 A after entry = %', v_b; end if; n := n + 1;
  select coins into v_b from public.wallets where user_id = b;
  if v_b <> 900 then raise exception 'FAIL 4.9 B after entry = %', v_b; end if; n := n + 1;

  begin
    set local role game_server;
    perform game.finish_match(m1, '[]', format('[{"user_id":"%s","amount":201}]', a)::jsonb, 'finished', 'r6');
    raise exception 'FAIL 4.10 payout above pool accepted';
  exception when others then
    if sqlerrm <> 'PAYOUT_EXCEEDS_POOL' then raise; end if; n := n + 1;
  end;

  set local role game_server;
  v_j := game.finish_match(m1, '[{"seat":0,"rank":1},{"seat":1,"rank":2}]',
                           format('[{"user_id":"%s","amount":180}]', a)::jsonb, 'finished', 'r6 m0 r3');
  if not (v_j->>'applied')::boolean or (v_j->>'rake')::bigint <> 20 then raise exception 'FAIL 4.11 finish %', v_j; end if; n := n + 1;
  v_j := game.finish_match(m1, '[{"seat":0,"rank":1},{"seat":1,"rank":2}]',
                           format('[{"user_id":"%s","amount":180}]', a)::jsonb, 'finished', 'r6 m0 r3');
  if (v_j->>'applied')::boolean then raise exception 'FAIL 4.12 double finish'; end if; n := n + 1;
  execute format('set local role %I', me);
  select coins into v_b from public.wallets where user_id = a;
  if v_b <> 1080 then raise exception 'FAIL 4.13 A after payout = %', v_b; end if; n := n + 1;
  select wins_2p * 10 + matches_2p into v_i from public.player_stats where user_id = a;
  if v_i <> 11 then raise exception 'FAIL 4.14 A stats = %', v_i; end if; n := n + 1;
  begin
    set local role game_server;
    perform game.void_match(m1, 'test');
    raise exception 'FAIL 4.15 finished match voided';
  exception when others then
    if sqlerrm <> 'MATCH_FINISHED' then raise; end if; n := n + 1;
  end;

  -- all-or-nothing entry: C cannot pay 2000, so A must not be charged either
  begin
    set local role game_server;
    perform game.start_match(m2, 'quick', rs, 'lobby_2500', 2000, 1, seats_ac);
    raise exception 'FAIL 4.16 entry without funds accepted';
  exception when others then
    if sqlerrm <> 'INSUFFICIENT_FUNDS' then raise; end if; n := n + 1;
  end;
  select coins into v_b from public.wallets where user_id = a;
  if v_b <> 1080 then raise exception 'FAIL 4.17 A charged in a failed match: %', v_b; end if; n := n + 1;
  select count(*) into v_i from public.matches where id = m2;
  if v_i <> 0 then raise exception 'FAIL 4.18 failed match left a record'; end if; n := n + 1;

  -- void refunds everybody, once
  set local role game_server;
  perform game.start_match(m3, 'quick', rs, 'lobby_100', 100, 1, seats_ac);
  v_j := game.void_match(m3, 'server_error');
  if (v_j->>'refunded')::int <> 2 then raise exception 'FAIL 4.19 void %', v_j; end if; n := n + 1;
  v_j := game.void_match(m3, 'server_error');
  if (v_j->>'applied')::boolean then raise exception 'FAIL 4.20 double void'; end if; n := n + 1;
  execute format('set local role %I', me);
  select coins into v_b from public.wallets where user_id = c;
  if v_b <> 1000 then raise exception 'FAIL 4.21 C after void = %', v_b; end if; n := n + 1;

  ------------------------------------------------ 5. purchases and refunds
  set local role game_server;
  v_j := game.grant_purchase(b, 'google', 'sandbox', 'gold_s', 'T-GOLD-1', 'gold', 300, '{"order":"x"}');
  if not (v_j->>'applied')::boolean then raise exception 'FAIL 5.1 grant'; end if; n := n + 1;
  v_j := game.grant_purchase(b, 'google', 'sandbox', 'gold_s', 'T-GOLD-1', 'gold', 300, '{"order":"x"}');
  if (v_j->>'applied')::boolean then raise exception 'FAIL 5.2 double grant'; end if; n := n + 1;
  execute format('set local role %I', me);
  begin
    set local role game_server;
    perform game.grant_purchase(c, 'google', 'sandbox', 'gold_s', 'T-GOLD-1', 'gold', 300, '{}');
    raise exception 'FAIL 5.3 purchase reused by another user';
  exception when others then
    if sqlerrm <> 'PURCHASE_OWNED_BY_OTHER' then raise; end if; n := n + 1;
  end;
  select coins into v_b from public.wallets where user_id = b;
  if v_b <> 1200 then raise exception 'FAIL 5.4 B after purchase = %', v_b; end if; n := n + 1;

  set local role game_server;
  perform game.grant_purchase(c, 'apple', 'sandbox', 'gems_s', 'T-GEMS-1', 'gems', 50, '{}');
  -- B spends 1150 of 1200 in a gold match, then the 300 gold purchase is refunded
  perform game.start_match(m4, 'quick', rs, 'custom', 1050, 1, seats_ab);
  execute format('set local role %I', me);
  select coins into v_b from public.wallets where user_id = b;
  if v_b <> 150 then raise exception 'FAIL 5.5 B after entry = %', v_b; end if; n := n + 1;
  set local role game_server;
  v_j := game.revoke_purchase('google', 'T-GOLD-1', 'refunded');
  if (v_j->>'taken')::bigint <> 150 or (v_j->>'debt')::bigint <> 150 then raise exception 'FAIL 5.6 revoke %', v_j; end if; n := n + 1;
  v_j := game.revoke_purchase('google', 'T-GOLD-1', 'refunded');
  if (v_j->>'applied')::boolean then raise exception 'FAIL 5.7 double revoke'; end if; n := n + 1;
  execute format('set local role %I', me);
  select coins into v_b from public.wallets where user_id = b;
  if v_b <> 0 then raise exception 'FAIL 5.8 B balance after refund = % (must stop at 0)', v_b; end if; n := n + 1;

  -- with an open debt B cannot enter a gold match, and nobody is charged
  begin
    set local role game_server;
    perform game.start_match(m5, 'quick', rs, 'lobby_100', 0 + 10, 1, seats_ab);
    raise exception 'FAIL 5.9 entry with debt accepted';
  exception when others then
    if sqlerrm not in ('DEBT_OUTSTANDING', 'INSUFFICIENT_FUNDS') then raise; end if; n := n + 1;
  end;
  select coins into v_b from public.wallets where user_id = a;
  if v_b <> 30 then raise exception 'FAIL 5.10 A charged while B had debt: %', v_b; end if; n := n + 1;

  -- a later credit pays the debt first
  set local role game_server;
  perform game.finish_match(m4, '[{"seat":0,"rank":2},{"seat":1,"rank":1}]',
                            format('[{"user_id":"%s","amount":1890}]', b)::jsonb, 'finished', '');
  execute format('set local role %I', me);
  select coins into v_b from public.wallets where user_id = b;
  if v_b <> 1740 then raise exception 'FAIL 5.11 B after payout and debt = %', v_b; end if; n := n + 1;
  select remaining into v_b from public.wallet_debts where user_id = b;
  if v_b <> 0 then raise exception 'FAIL 5.12 debt left = %', v_b; end if; n := n + 1;

  -- Gems are untouched by matches; the ledger equals every balance
  select gems into v_b from public.wallets where user_id = c;
  if v_b <> 50 then raise exception 'FAIL 5.13 C gems = %', v_b; end if; n := n + 1;
  select count(*) into v_i from public.wallets w
   where w.user_id in (a, b, c)
     and (w.coins <> coalesce((select sum(delta) from public.wallet_transactions t where t.user_id = w.user_id and t.currency = 'gold'), 0)
       or w.gems  <> coalesce((select sum(delta) from public.wallet_transactions t where t.user_id = w.user_id and t.currency = 'gems'), 0));
  if v_i <> 0 then raise exception 'FAIL 5.14 ledger does not match balances'; end if; n := n + 1;

  ------------------------------------------------ 6. match and social RLS
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_i from public.matches where id = m1;
  if v_i <> 0 then raise exception 'FAIL 6.1 C sees a match it did not play'; end if; n := n + 1;
  execute format('set local role %I', me);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_i from public.matches where id = m1;
  if v_i <> 1 then raise exception 'FAIL 6.2 A cannot see own match'; end if; n := n + 1;
  select count(*) into v_i from public.match_players where match_id = m1;
  if v_i <> 2 then raise exception 'FAIL 6.3 A sees % seats of own match', v_i; end if; n := n + 1;
  select count(*) into v_i from public.match_entries where user_id <> a;
  if v_i <> 0 then raise exception 'FAIL 6.4 A sees other entries'; end if; n := n + 1;
  execute format('set local role %I', me);

  insert into public.blocks (blocker_id, blocked_id) values (b, a);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into v_i from public.get_profile_cards(array[b]);
  if v_i <> 0 then raise exception 'FAIL 6.5 blocked profile visible'; end if; n := n + 1;
  select count(*) into v_i from public.blocks;
  if v_i <> 0 then raise exception 'FAIL 6.6 A sees who blocked them'; end if; n := n + 1;
  execute format('set local role %I', me);

  raise exception 'TESTS_PASSED %', n;
end
$$;
