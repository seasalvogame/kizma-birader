-- Kızma Birader — Phase 7.2: buying cosmetics with gold or gems.
--
-- public.purchase_cosmetic(item): everything decided by the server, in ONE transaction:
--   item published + purchasable, cosmetics store switched on, not owned yet, no open
--   wallet debt (GOLD_AND_DIAMOND_ECONOMY E-6), price from the catalog's rarity table
--   (the client sends only the item id), balance charged through the existing ledger
--   (game._apply: row lock, no negative balance, reason 'store_purchase', idempotency key
--   per player and item -> a repeated or concurrent request never charges twice), and the
--   item added to the inventory (player_unlocks, source 'store'). Any failure rolls all back.
-- No real money, no random boxes, no transfers between players.

create or replace function public.purchase_cosmetic(p_item text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_cfg jsonb := (select value from public.app_config where key = 'cosmetics');
  v jsonb := app_private.cosmetic(p_item);
  v_currency text;
  v_price int;
  r jsonb;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  if v is null or not coalesce((v->>'published')::boolean, false) then raise exception 'ITEM_NOT_FOUND'; end if;
  if not coalesce((v->>'purchasable')::boolean, false) then raise exception 'NOT_FOR_SALE'; end if;
  if not coalesce((select (value->>'cosmetics_store_enabled')::boolean from public.app_config where key = 'features'), false) then
    raise exception 'STORE_CLOSED';
  end if;
  v_currency := v->>'currency';
  v_price := (v_cfg->'prices'->v_currency->>(v->>'rarity'))::int;
  if v_currency not in ('gold', 'gems') or v_price is null or v_price <= 0 then raise exception 'NOT_FOR_SALE'; end if;
  -- one purchase at a time per player (a concurrent request waits, then sees the item as owned)
  perform 1 from public.wallets where user_id = v_me for update;
  if app_private.owns(v_me, p_item) then raise exception 'ALREADY_OWNED'; end if;
  if game._has_open_debt(v_me, v_currency) then raise exception 'DEBT_OPEN'; end if;
  r := game._apply(v_me, v_currency, -v_price, 'store_purchase', format('buy:%s:%s', v_me, p_item), 'cosmetic', p_item);
  if not (r->>'applied')::boolean then raise exception 'ALREADY_OWNED'; end if;
  insert into public.player_unlocks (user_id, kind, item_id, source)
  values (v_me, v->>'category', app_private.unlock_id(v), 'store');
  return jsonb_build_object('item', p_item, 'currency', v_currency, 'price', v_price, 'balance', (r->>'balance')::bigint);
end;
$$;

revoke all on function public.purchase_cosmetic(text) from public, anon;
grant execute on function public.purchase_cosmetic(text) to authenticated;

-- Equipping changes only the owner's saved look.  It never changes a rule,
-- wallet or match state; the server still verifies the catalog category and
-- that the item is in the player's inventory.
create or replace function public.equip_cosmetic(p_item text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v jsonb := app_private.cosmetic(p_item);
  v_category text;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  if v is null or not coalesce((v->>'published')::boolean, false) then raise exception 'ITEM_NOT_FOUND'; end if;
  v_category := v->>'category';
  if v_category not in ('dice', 'pawns', 'board', 'frame', 'effect', 'name', 'emotes') then
    raise exception 'NOT_EQUIPPABLE';
  end if;
  if not app_private.owns(v_me, p_item) then raise exception 'NOT_OWNED'; end if;

  insert into public.player_loadout (user_id) values (v_me) on conflict (user_id) do nothing;
  case v_category
    when 'dice' then update public.player_loadout set dice = p_item, updated_at = now() where user_id = v_me;
    when 'pawns' then update public.player_loadout set pawns = p_item, updated_at = now() where user_id = v_me;
    when 'board' then update public.player_loadout set board = p_item, updated_at = now() where user_id = v_me;
    when 'frame' then update public.player_loadout set frame = p_item, updated_at = now() where user_id = v_me;
    when 'effect' then update public.player_loadout set effect = p_item, updated_at = now() where user_id = v_me;
    when 'name' then update public.player_loadout set name = p_item, updated_at = now() where user_id = v_me;
    when 'emotes' then update public.player_loadout set emotes = p_item, updated_at = now() where user_id = v_me;
  end case;
  return jsonb_build_object('category', v_category, 'item', p_item);
end;
$$;

revoke all on function public.equip_cosmetic(text) from public, anon;
grant execute on function public.equip_cosmetic(text) to authenticated;

-- The game server receives a compact, verified visual loadout when it creates
-- a match.  It never accepts these ids from a client.  Every value is checked
-- again here, so an old/bad row cannot expose an unpublished or unowned item.
create or replace function game.player_match_cosmetics(p_users uuid[])
returns table (user_id uuid, cosmetics jsonb, emote_ids jsonb)
language sql stable security definer set search_path = '' as $$
  select p.user_id, jsonb_build_object(
    'dice',   case when app_private.cosmetic(l.dice)->>'category' = 'dice'     and app_private.owns(p.user_id, l.dice)   and coalesce((app_private.cosmetic(l.dice)->>'published')::boolean, false)   then l.dice   else 'dice_classic' end,
    'pawns',  case when app_private.cosmetic(l.pawns)->>'category' = 'pawns'   and app_private.owns(p.user_id, l.pawns)  and coalesce((app_private.cosmetic(l.pawns)->>'published')::boolean, false)  then l.pawns  else 'pawns_classic' end,
    'board',  case when app_private.cosmetic(l.board)->>'category' = 'board'   and app_private.owns(p.user_id, l.board)  and coalesce((app_private.cosmetic(l.board)->>'published')::boolean, false)  then l.board  else 'board_classic' end,
    'frame',  case when app_private.cosmetic(l.frame)->>'category' = 'frame'   and app_private.owns(p.user_id, l.frame)  and coalesce((app_private.cosmetic(l.frame)->>'published')::boolean, false)  then l.frame  else 'frame_none' end,
    'effect', case when app_private.cosmetic(l.effect)->>'category' = 'effect' and app_private.owns(p.user_id, l.effect) and coalesce((app_private.cosmetic(l.effect)->>'published')::boolean, false) then l.effect else 'effect_none' end,
    'name',   case when app_private.cosmetic(l.name)->>'category' = 'name'     and app_private.owns(p.user_id, l.name)   and coalesce((app_private.cosmetic(l.name)->>'published')::boolean, false)   then l.name   else 'name_plain' end,
    'emotes', case when app_private.cosmetic(l.emotes)->>'category' = 'emotes' and app_private.owns(p.user_id, l.emotes) and coalesce((app_private.cosmetic(l.emotes)->>'published')::boolean, false) then l.emotes else 'emotes_classic' end),
    case when app_private.cosmetic(l.emotes)->>'category' = 'emotes' and app_private.owns(p.user_id, l.emotes) and coalesce((app_private.cosmetic(l.emotes)->>'published')::boolean, false)
         then coalesce(app_private.cosmetic(l.emotes)->'phrases', '[]'::jsonb)
         else '["hello","gg","go","wow"]'::jsonb end
    from public.profiles p
    left join public.player_loadout l on l.user_id = p.user_id
   where cardinality(p_users) <= 4 and p.user_id = any(p_users);
$$;
revoke all on function game.player_match_cosmetics(uuid[]) from public, anon, authenticated;
grant execute on function game.player_match_cosmetics(uuid[]) to game_server;

-- ---------------------------------------------------------------- rewards
-- Existing Phase 6 reward machinery stays authoritative.  These server-owned
-- config additions make the earnable catalog entries real and _grant_item
-- continues to enforce one copy per player.
update public.app_config
   set value = jsonb_set(
                 jsonb_set(
                   jsonb_set(
                     jsonb_set(
                       jsonb_set(value, '{level_unlocks,10}', coalesce(value #> '{level_unlocks,10}', '[]'::jsonb) || '[{"kind":"frame","id":"frame_star"}]'::jsonb),
                     '{level_unlocks,15}', '[{"kind":"dice","id":"dice_master"}]'::jsonb),
                   '{level_unlocks,20}', '[{"kind":"pawns","id":"pawns_star"}]'::jsonb),
                 '{level_unlocks,25}', coalesce(value #> '{level_unlocks,25}', '[]'::jsonb) || '[{"kind":"board","id":"board_night"}]'::jsonb),
               '{version}', '2'::jsonb), version = version + 1, updated_at = now()
 where key = 'progression';

update public.app_config
   set value = jsonb_set(jsonb_set(value, '{achievements}', (
         select jsonb_agg(case when a->>'id' = 'streak_5' then a || '{"item":"name_star"}'::jsonb else a end)
           from jsonb_array_elements(value->'achievements') a)), '{version}', '2'::jsonb),
       version = version + 1, updated_at = now()
 where key = 'achievements';

update public.app_config
   set value = jsonb_set(jsonb_set(value, '{weekly}', (
         select jsonb_agg(case when q->>'id' = 'w_play_10' then q || '{"item":"frame_mint"}'::jsonb else q end)
           from jsonb_array_elements(value->'weekly') q)), '{version}', '2'::jsonb),
       version = version + 1, updated_at = now()
 where key = 'quests';

update public.app_config
   set value = jsonb_set(jsonb_set(value, '{rewards}', (
         select jsonb_agg(case when (r->>'from')::int = 1 and (r->>'to')::int = 1 then r || '{"item":"frame_champion"}'::jsonb else r end)
           from jsonb_array_elements(value->'rewards') r)), '{version}', '2'::jsonb),
       version = version + 1, updated_at = now()
 where key = 'leaderboard';

-- Claiming still uses the pre-existing player row as the source of truth; the
-- optional cosmetic is selected only from its server-owned definition.
create or replace function public.claim_quest(p_period text, p_period_key date, p_quest_id text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  q record;
  v_ref text;
  v_item text;
  r jsonb;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  update public.player_quests set claimed_at = now()
   where user_id = v_me and period = p_period and period_key = p_period_key and quest_id = p_quest_id
     and completed_at is not null and claimed_at is null
  returning * into q;
  if not found then
    if exists (select 1 from public.player_quests where user_id = v_me and period = p_period and period_key = p_period_key
                 and quest_id = p_quest_id and claimed_at is not null) then raise exception 'ALREADY_CLAIMED'; end if;
    if exists (select 1 from public.player_quests where user_id = v_me and period = p_period and period_key = p_period_key
                 and quest_id = p_quest_id) then raise exception 'NOT_COMPLETED'; end if;
    raise exception 'QUEST_NOT_FOUND';
  end if;
  select d->>'item' into v_item from public.app_config c, jsonb_array_elements(c.value->p_period) d
   where c.key = 'quests' and d->>'id' = p_quest_id;
  v_ref := format('quest:%s:%s:%s', p_period, p_period_key, p_quest_id);
  if q.gold > 0 then perform game._apply(v_me, 'gold', q.gold, 'quest', v_me::text || ':' || v_ref, 'quest', v_ref); end if;
  r := game._grant_xp(v_me, q.xp, 'quest', v_ref);
  if v_item is not null then perform game._grant_item(v_me, v_item, 'quest:' || p_quest_id); end if;
  return jsonb_build_object('gold', q.gold, 'xp', (r->>'xp')::int, 'item', v_item,
                            'level_before', (r->>'level_before')::int, 'level_after', (r->>'level_after')::int,
                            'level_gold', (r->>'gold')::int);
end;
$$;

create or replace function public.claim_achievement(p_id text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_def jsonb := (select a from public.app_config cfg, jsonb_array_elements(cfg.value->'achievements') a
                   where cfg.key = 'achievements' and a->>'id' = p_id);
  v_gold int;
  v_xp int;
  v_item text;
  r jsonb;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_def is null then raise exception 'ACHIEVEMENT_NOT_FOUND'; end if;
  update public.player_achievements set claimed_at = now()
   where user_id = v_me and achievement_id = p_id and claimed_at is null;
  if not found then
    if exists (select 1 from public.player_achievements where user_id = v_me and achievement_id = p_id) then raise exception 'ALREADY_CLAIMED'; end if;
    raise exception 'NOT_COMPLETED';
  end if;
  v_gold := coalesce((v_def->>'gold')::int, 0);
  v_xp := coalesce((v_def->>'xp')::int, 0);
  v_item := v_def->>'item';
  if v_gold > 0 then perform game._apply(v_me, 'gold', v_gold, 'achievement', format('ach:%s:%s', v_me, p_id), 'achievement', p_id); end if;
  r := game._grant_xp(v_me, v_xp, 'achievement', p_id);
  if v_def ? 'badge' then
    insert into public.player_unlocks (user_id, kind, item_id, source)
    values (v_me, 'badge', v_def->>'badge', 'achievement:' || p_id) on conflict do nothing;
  end if;
  if v_item is not null then perform game._grant_item(v_me, v_item, 'achievement:' || p_id); end if;
  return jsonb_build_object('id', p_id, 'gold', v_gold, 'xp', coalesce((r->>'xp')::int, 0),
                            'badge', v_def->>'badge', 'item', v_item,
                            'level_before', (r->>'level_before')::int, 'level_after', (r->>'level_after')::int,
                            'level_gold', coalesce((r->>'gold')::int, 0));
end;
$$;

-- Week close was already an atomic, idempotent server job.  Add the optional
-- catalog item to the same successful reward branch so a rerun cannot grant it
-- twice (and it remains a purely visual prize).
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
        if t ? 'item' then perform game._grant_item(s.user_id, t->>'item', 'leaderboard:' || w.week_key); end if;
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
