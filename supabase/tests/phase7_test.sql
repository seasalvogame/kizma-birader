-- Phase 7 tests: cosmetics catalog, inventory (7.1); later sub-phases append sections.
--   npx supabase db query --remote --yes -f supabase/tests/phase7_test.sql
-- One transaction that always ends with an exception (nothing is kept).
-- Expected final message: TESTS_PASSED <n>

do $$
declare
  a  uuid := '00000000-0000-4000-8000-0000000007a1';
  b  uuid := '00000000-0000-4000-8000-0000000007b1';
  me text := current_user;
  n  int := 0;
  v_i int;
  v_j jsonb;
  v_t text;
begin
  insert into auth.users (id, aud, role, is_anonymous, created_at, updated_at) values
    (a, 'authenticated', 'authenticated', true, now(), now()), (b, 'authenticated', 'authenticated', true, now(), now());

  ------------------------------------------------------- 1. catalog
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_j := public.cosmetics_catalog();
  if jsonb_array_length(v_j->'items') < 30 then raise exception 'FAIL 1.1 catalog size %', jsonb_array_length(v_j->'items'); end if; n := n + 1;
  select count(distinct x->>'category') into v_i from jsonb_array_elements(v_j->'items') x;
  if v_i <> 8 then raise exception 'FAIL 1.2 eight categories (%)', v_i; end if; n := n + 1;
  if (select (x->>'price')::int from jsonb_array_elements(v_j->'items') x where x->>'id' = 'dice_star') <> 2500
     or (select (x->>'price')::int from jsonb_array_elements(v_j->'items') x where x->>'id' = 'dice_night') <> 400
     or (select x->>'price' from jsonb_array_elements(v_j->'items') x where x->>'id' = 'dice_master') is not null then
    raise exception 'FAIL 1.3 server prices from the rarity table';
  end if; n := n + 1;
  if not (v_j->>'store_enabled')::boolean then raise exception 'FAIL 1.4 cosmetics store switch'; end if; n := n + 1;
  begin
    select value::text into v_t from public.app_config where key = 'cosmetics';
    if v_t is not null then raise exception 'FAIL 1.5 raw catalog readable by clients'; end if;
    n := n + 1;
  exception when insufficient_privilege then n := n + 1;
  end;
  execute format('set local role %I', me);
  -- unpublished items are hidden
  update public.app_config set value = jsonb_set(value, '{items}', (
    select jsonb_agg(case when i->>'id' = 'dice_night' then i || '{"published": false}'::jsonb else i end) from jsonb_array_elements(value->'items') i))
   where key = 'cosmetics';
  set local role authenticated;
  if exists (select 1 from jsonb_array_elements(public.cosmetics_catalog()->'items') x where x->>'id' = 'dice_night') then
    raise exception 'FAIL 1.6 unpublished item listed';
  end if; n := n + 1;
  execute format('set local role %I', me);

  ------------------------------------------------------ 2. inventory
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_j := public.my_inventory();
  select count(*) into v_i from jsonb_array_elements(v_j->'owned') x where x->>'source' = 'default';
  if v_i <> 7 or v_j->'loadout'->>'dice' <> 'dice_classic' then raise exception 'FAIL 2.1 defaults %', v_j; end if; n := n + 1;
  execute format('set local role %I', me);
  if not game._grant_item(a, 'dice_master', 'level:15') then raise exception 'FAIL 2.2 grant'; end if; n := n + 1;
  if game._grant_item(a, 'dice_master', 'level:15') then raise exception 'FAIL 2.3 granted twice'; end if; n := n + 1;
  if game._grant_item(a, 'dice_classic', 'x') then raise exception 'FAIL 2.4 default stored'; end if; n := n + 1;
  begin
    perform game._grant_item(a, 'no_such_item', 'x');
    raise exception 'FAIL 2.5 unknown item granted';
  exception when others then if sqlerrm <> 'ITEM_NOT_FOUND' then raise; end if; n := n + 1;
  end;
  perform game._grant_item(a, 'badge_level_5', 'level:5');
  if not exists (select 1 from public.player_unlocks where user_id = a and kind = 'badge' and item_id = 'level_5') then
    raise exception 'FAIL 2.6 badge ids stay Phase 6 compatible';
  end if; n := n + 1;
  set local role authenticated;
  v_j := public.my_inventory();
  if not exists (select 1 from jsonb_array_elements(v_j->'owned') x where x->>'id' = 'dice_master' and x->>'source' = 'level:15')
     or not exists (select 1 from jsonb_array_elements(v_j->'owned') x where x->>'id' = 'badge_level_5') then
    raise exception 'FAIL 2.7 owned items with source %', v_j->'owned';
  end if; n := n + 1;
  begin
    insert into public.player_unlocks (user_id, kind, item_id, source) values (a, 'dice', 'dice_star', 'hack');
    raise exception 'FAIL 2.8 client added an item';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    update public.player_loadout set dice = 'dice_star' where user_id = a;
    raise exception 'FAIL 2.9 client changed its loadout';
  exception when insufficient_privilege then n := n + 1;
  end;
  begin
    perform game._grant_item(a, 'dice_star', 'hack');
    raise exception 'FAIL 2.10 client called the grant function';
  exception when insufficient_privilege then n := n + 1;
  end;
  execute format('set local role %I', me);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  if exists (select 1 from jsonb_array_elements(public.my_inventory()->'owned') x where x->>'id' = 'dice_master') then
    raise exception 'FAIL 2.11 inventories are not isolated';
  end if; n := n + 1;
  select count(*) into v_i from public.player_unlocks;
  if v_i <> 0 then raise exception 'FAIL 2.12 b reads a''s unlocks'; end if; n := n + 1;
  execute format('set local role %I', me);

  raise exception 'TESTS_PASSED %', n;
end
$$;
