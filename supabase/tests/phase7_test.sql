-- Phase 7 tests: cosmetics catalog, inventory, store and loadout.
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
  v_before bigint;
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

  -------------------------------------------------- 3. store and loadout
  -- The user has a wallet created by the normal auth trigger.  Give it test
  -- currency only inside this rollback-only transaction.
  update public.wallets set coins = 3000, gems = 200 where user_id = a;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_j := public.purchase_cosmetic('dice_star');
  if v_j->>'item' <> 'dice_star' or (v_j->>'price')::int <> 2500 or (v_j->>'balance')::bigint <> 500 then
    raise exception 'FAIL 3.1 server priced or charged purchase %', v_j;
  end if; n := n + 1;
  begin
    perform public.purchase_cosmetic('dice_star');
    raise exception 'FAIL 3.2 bought item twice';
  exception when others then if sqlerrm <> 'ALREADY_OWNED' then raise; end if; n := n + 1;
  end;
  select coins into v_before from public.wallets where user_id = a;
  if v_before <> 500 or not exists (select 1 from public.player_unlocks where user_id = a and kind = 'dice' and item_id = 'dice_star')
     or (select count(*) from public.wallet_transactions where user_id = a and reason = 'store_purchase' and ref_id = 'dice_star') <> 1 then
    raise exception 'FAIL 3.3 purchase was not atomic';
  end if; n := n + 1;
  begin
    perform public.purchase_cosmetic('dice_master');
    raise exception 'FAIL 3.4 bought earn-only item';
  exception when others then if sqlerrm <> 'NOT_FOR_SALE' then raise; end if; n := n + 1;
  end;
  begin
    perform public.purchase_cosmetic('not_an_item');
    raise exception 'FAIL 3.5 bought unknown item';
  exception when others then if sqlerrm <> 'ITEM_NOT_FOUND' then raise; end if; n := n + 1;
  end;
  begin
    -- dice_night was deliberately unpublished in section 1 and must be
    -- rejected by the write path as well as omitted from the catalog.
    perform public.purchase_cosmetic('dice_night');
    raise exception 'FAIL 3.5b bought unpublished item';
  exception when others then if sqlerrm <> 'ITEM_NOT_FOUND' then raise; end if; n := n + 1;
  end;
  begin
    perform public.purchase_cosmetic('pawns_crown');
    raise exception 'FAIL 3.5c bought without enough gold';
  exception when others then if sqlerrm <> 'INSUFFICIENT_FUNDS' then raise; end if; n := n + 1;
  end;
  if exists (select 1 from public.player_unlocks where user_id = a and item_id = 'pawns_crown')
     or (select count(*) from public.wallet_transactions where user_id = a and ref_id = 'pawns_crown') <> 0 then
    raise exception 'FAIL 3.5d insufficient funds left partial purchase';
  end if; n := n + 1;
  v_j := public.purchase_cosmetic('dice_aurora');
  if v_j->>'currency' <> 'gems' or (v_j->>'price')::int <> 120 or (v_j->>'balance')::bigint <> 80
     or (select coins from public.wallets where user_id = a) <> 500 then
    raise exception 'FAIL 3.5e server selected gems price/currency %', v_j;
  end if; n := n + 1;
  v_j := public.equip_cosmetic('dice_star');
  if v_j->>'category' <> 'dice' or public.my_inventory()->'loadout'->>'dice' <> 'dice_star' then
    raise exception 'FAIL 3.6 item was not equipped';
  end if; n := n + 1;
  begin
    perform public.equip_cosmetic('board_mint');
    raise exception 'FAIL 3.7 equipped an unowned item';
  exception when others then if sqlerrm <> 'NOT_OWNED' then raise; end if; n := n + 1;
  end;
  begin
    perform public.equip_cosmetic('badge_level_5');
    raise exception 'FAIL 3.8 equipped a badge through cosmetic loadout';
  exception when others then if sqlerrm <> 'NOT_EQUIPPABLE' then raise; end if; n := n + 1;
  end;
  execute format('set local role %I', me);

  update public.app_config set value = value || '{"cosmetics_store_enabled": false}'::jsonb where key = 'features';
  set local role authenticated;
  begin
    perform public.purchase_cosmetic('name_mango');
    raise exception 'FAIL 3.9 bought while store closed';
  exception when others then if sqlerrm <> 'STORE_CLOSED' then raise; end if; n := n + 1;
  end;
  execute format('set local role %I', me);
  update public.app_config set value = value || '{"cosmetics_store_enabled": true}'::jsonb where key = 'features';

  --------------------------------------- 4. server-to-match visual payload
  select cosmetics, emote_ids::text into v_j, v_t from game.player_match_cosmetics(array[a]);
  if v_j->>'dice' <> 'dice_star' or v_j->>'pawns' <> 'pawns_classic' then
    raise exception 'FAIL 4.1 match cosmetics did not contain verified loadout %', v_j;
  end if; n := n + 1;
  if v_t <> '["hello", "gg", "go", "wow"]' then raise exception 'FAIL 4.1b classic emote set %', v_t; end if; n := n + 1;
  -- Even an accidental privileged bad loadout cannot be passed to a match.
  update public.player_loadout set dice = 'frame_star' where user_id = a;
  select cosmetics into v_j from game.player_match_cosmetics(array[a]);
  if v_j->>'dice' <> 'dice_classic' then
    raise exception 'FAIL 4.2 match cosmetics trusted invalid loadout %', v_j;
  end if; n := n + 1;
  update public.player_loadout set dice = 'dice_mango' where user_id = a;
  select cosmetics into v_j from game.player_match_cosmetics(array[a]);
  if v_j->>'dice' <> 'dice_classic' then
    raise exception 'FAIL 4.3 match cosmetics trusted unowned loadout %', v_j;
  end if; n := n + 1;
  update public.player_loadout set dice = 'dice_star' where user_id = a;

  raise exception 'TESTS_PASSED %', n;
end
$$;
