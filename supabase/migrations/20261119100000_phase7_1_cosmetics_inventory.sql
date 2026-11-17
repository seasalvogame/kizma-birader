-- Kızma Birader — Phase 7.1: cosmetics catalog and inventory.
--
-- Catalog: app_config 'cosmetics' (source shared/config/cosmetics_catalog.json; NOT public:
-- clients read it only through public.cosmetics_catalog(), which hides unpublished items).
-- Prices come from the catalog's rarity price table (server side only).
-- Inventory: the existing public.player_unlocks (Phase 6 badges) — one row per owned item,
-- kind = category. Default items are owned by everybody and never stored.
-- Equipped items: public.player_loadout (badge stays in profiles.badge_id, Phase 6).
-- Rarity is only a visual class; cosmetics never change the game.

insert into public.app_config (key, value, is_public) values ('cosmetics', '{"version": 1, "prices": {"gold": {"common": 400, "rare": 1200, "epic": 2500, "legendary": 5000}, "gems": {"rare": 60, "epic": 120, "legendary": 250}}, "featured": ["dice_star", "pawns_crown", "board_mint", "frame_gold", "effect_sparkle", "dice_aurora"], "items": [{"id": "dice_classic", "category": "dice", "rarity": "common", "default": true, "published": true, "purchasable": false, "earnable": false, "asset": "res://assets/dice", "usage": "match"}, {"id": "dice_night", "category": "dice", "rarity": "common", "currency": "gold", "published": true, "purchasable": true, "earnable": false, "asset": "res://assets/cosmetics/dice/night", "usage": "match"}, {"id": "dice_mango", "category": "dice", "rarity": "rare", "currency": "gold", "published": true, "purchasable": true, "earnable": false, "asset": "res://assets/cosmetics/dice/mango", "usage": "match"}, {"id": "dice_emerald", "category": "dice", "rarity": "rare", "currency": "gold", "published": true, "purchasable": true, "earnable": false, "asset": "res://assets/cosmetics/dice/emerald", "usage": "match"}, {"id": "dice_star", "category": "dice", "rarity": "epic", "currency": "gold", "published": true, "purchasable": true, "earnable": false, "asset": "res://assets/cosmetics/dice/star", "usage": "match"}, {"id": "dice_aurora", "category": "dice", "rarity": "epic", "currency": "gems", "published": true, "purchasable": true, "earnable": false, "asset": "res://assets/cosmetics/dice/aurora", "usage": "match"}, {"id": "dice_master", "category": "dice", "rarity": "rare", "published": true, "purchasable": false, "earnable": true, "source": "level:15", "asset": "res://assets/cosmetics/dice/master", "usage": "match"}, {"id": "pawns_classic", "category": "pawns", "rarity": "common", "default": true, "published": true, "purchasable": false, "earnable": false, "asset": "res://assets/pawns", "usage": "match"}, {"id": "pawns_crown", "category": "pawns", "rarity": "rare", "currency": "gold", "published": true, "purchasable": true, "earnable": false, "asset": "res://assets/cosmetics/pawns/crown", "usage": "match"}, {"id": "pawns_star", "category": "pawns", "rarity": "epic", "published": true, "purchasable": false, "earnable": true, "source": "level:20", "asset": "res://assets/cosmetics/pawns/star", "usage": "match"}, {"id": "pawns_gem", "category": "pawns", "rarity": "epic", "currency": "gems", "published": true, "purchasable": true, "earnable": false, "asset": "res://assets/cosmetics/pawns/gem", "usage": "match"}, {"id": "board_classic", "category": "board", "rarity": "common", "default": true, "published": true, "purchasable": false, "earnable": false, "asset": "palette:classic", "usage": "match"}, {"id": "board_mint", "category": "board", "rarity": "rare", "currency": "gold", "published": true, "purchasable": true, "earnable": false, "asset": "palette:mint", "usage": "match"}, {"id": "board_night", "category": "board", "rarity": "epic", "published": true, "purchasable": false, "earnable": true, "source": "level:25", "asset": "palette:night", "usage": "match"}, {"id": "board_sunset", "category": "board", "rarity": "legendary", "currency": "gems", "published": true, "purchasable": true, "earnable": false, "asset": "palette:sunset", "usage": "match"}, {"id": "frame_none", "category": "frame", "rarity": "common", "default": true, "published": true, "purchasable": false, "earnable": false, "asset": "frame:none", "usage": "profile+match"}, {"id": "frame_mint", "category": "frame", "rarity": "common", "currency": "gold", "published": true, "purchasable": true, "earnable": true, "source": "quest:w_play_10", "asset": "frame:mint", "usage": "profile+match"}, {"id": "frame_gold", "category": "frame", "rarity": "rare", "currency": "gold", "published": true, "purchasable": true, "earnable": false, "asset": "frame:gold", "usage": "profile+match"}, {"id": "frame_star", "category": "frame", "rarity": "epic", "published": true, "purchasable": false, "earnable": true, "source": "level:10", "asset": "frame:star", "usage": "profile+match"}, {"id": "frame_champion", "category": "frame", "rarity": "legendary", "published": true, "purchasable": false, "earnable": true, "source": "leaderboard:1", "asset": "frame:champion", "usage": "profile+match"}, {"id": "frame_royal", "category": "frame", "rarity": "legendary", "currency": "gems", "published": true, "purchasable": true, "earnable": false, "asset": "frame:royal", "usage": "profile+match"}, {"id": "effect_none", "category": "effect", "rarity": "common", "default": true, "published": true, "purchasable": false, "earnable": false, "asset": "effect:none", "usage": "profile"}, {"id": "effect_sparkle", "category": "effect", "rarity": "epic", "currency": "gold", "published": true, "purchasable": true, "earnable": false, "asset": "effect:sparkle", "usage": "profile"}, {"id": "effect_aurora", "category": "effect", "rarity": "legendary", "currency": "gems", "published": true, "purchasable": true, "earnable": false, "asset": "effect:aurora", "usage": "profile"}, {"id": "name_plain", "category": "name", "rarity": "common", "default": true, "published": true, "purchasable": false, "earnable": false, "asset": "name:plain", "usage": "profile+match"}, {"id": "name_mango", "category": "name", "rarity": "common", "currency": "gold", "published": true, "purchasable": true, "earnable": false, "asset": "name:mango", "usage": "profile+match"}, {"id": "name_gold", "category": "name", "rarity": "rare", "currency": "gold", "published": true, "purchasable": true, "earnable": false, "asset": "name:gold", "usage": "profile+match"}, {"id": "name_star", "category": "name", "rarity": "epic", "published": true, "purchasable": false, "earnable": true, "source": "achievement:streak_5", "asset": "name:star", "usage": "profile+match"}, {"id": "emotes_classic", "category": "emotes", "rarity": "common", "default": true, "published": true, "purchasable": false, "earnable": false, "asset": "emotes", "usage": "match", "phrases": ["hello", "gg", "go", "wow"]}, {"id": "emotes_cheer", "category": "emotes", "rarity": "rare", "currency": "gold", "published": true, "purchasable": true, "earnable": false, "asset": "emotes", "usage": "match", "phrases": ["great", "lucky", "close", "thanks"]}, {"id": "emotes_star", "category": "emotes", "rarity": "epic", "currency": "gems", "published": true, "purchasable": true, "earnable": false, "asset": "emotes", "usage": "match", "phrases": ["star", "champ", "rematch", "amazing"]}, {"id": "badge_level_5", "category": "badge", "rarity": "common", "published": true, "purchasable": false, "earnable": true, "source": "level:5", "asset": "badge:level_5", "usage": "profile"}, {"id": "badge_level_10", "category": "badge", "rarity": "rare", "published": true, "purchasable": false, "earnable": true, "source": "level:10", "asset": "badge:level_10", "usage": "profile"}, {"id": "badge_level_25", "category": "badge", "rarity": "epic", "published": true, "purchasable": false, "earnable": true, "source": "level:25", "asset": "badge:level_25", "usage": "profile"}, {"id": "badge_level_50", "category": "badge", "rarity": "legendary", "published": true, "purchasable": false, "earnable": true, "source": "level:50", "asset": "badge:level_50", "usage": "profile"}, {"id": "badge_level_100", "category": "badge", "rarity": "legendary", "published": true, "purchasable": false, "earnable": true, "source": "level:100", "asset": "badge:level_100", "usage": "profile"}, {"id": "badge_login_week", "category": "badge", "rarity": "rare", "published": true, "purchasable": false, "earnable": true, "source": "daily_login:7", "asset": "badge:login_week", "usage": "profile"}, {"id": "badge_veteran", "category": "badge", "rarity": "epic", "published": true, "purchasable": false, "earnable": true, "source": "achievement:matches_100", "asset": "badge:veteran", "usage": "profile"}, {"id": "badge_champion", "category": "badge", "rarity": "legendary", "published": true, "purchasable": false, "earnable": true, "source": "achievement:wins_50", "asset": "badge:champion", "usage": "profile"}, {"id": "badge_unstoppable", "category": "badge", "rarity": "epic", "published": true, "purchasable": false, "earnable": true, "source": "achievement:streak_5", "asset": "badge:unstoppable", "usage": "profile"}, {"id": "badge_social", "category": "badge", "rarity": "rare", "published": true, "purchasable": false, "earnable": true, "source": "achievement:friends_10", "asset": "badge:social", "usage": "profile"}, {"id": "badge_weekly_champion", "category": "badge", "rarity": "legendary", "published": true, "purchasable": false, "earnable": true, "source": "leaderboard:1", "asset": "badge:weekly_champion", "usage": "profile"}, {"id": "badge_weekly_top10", "category": "badge", "rarity": "epic", "published": true, "purchasable": false, "earnable": true, "source": "leaderboard:10", "asset": "badge:weekly_top10", "usage": "profile"}]}'::jsonb, false)
on conflict (key) do update set value = excluded.value, is_public = false, version = public.app_config.version + 1, updated_at = now();

-- cosmetic purchases with gold / gems are a separate switch from real-money purchases ('store_enabled' stays off)
update public.app_config set value = value || '{"cosmetics_store_enabled": true}'::jsonb, version = version + 1, updated_at = now()
 where key = 'features';

-- inventory: more categories
alter table public.player_unlocks drop constraint player_unlocks_kind_check;
alter table public.player_unlocks add constraint player_unlocks_kind_check
  check (kind in ('badge', 'avatar', 'frame', 'dice', 'pawns', 'board', 'effect', 'name', 'emotes'));

create table public.player_loadout (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  dice       text not null default 'dice_classic',
  pawns      text not null default 'pawns_classic',
  board      text not null default 'board_classic',
  frame      text not null default 'frame_none',
  effect     text not null default 'effect_none',
  name       text not null default 'name_plain',
  emotes     text not null default 'emotes_classic',
  updated_at timestamptz not null default now()
);
alter table public.player_loadout enable row level security;
create policy player_loadout_read_own on public.player_loadout for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.player_loadout from anon, authenticated;
grant select on public.player_loadout to authenticated;

-- ------------------------------------------------------------------ helpers
-- Catalog entry of an item id (null if unknown).
create or replace function app_private.cosmetic(p_id text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select i from public.app_config c, jsonb_array_elements(c.value->'items') i
   where c.key = 'cosmetics' and i->>'id' = p_id limit 1;
$$;

-- Inventory row id of an item: badges keep their Phase 6 ids ("level_5"), others the catalog id.
create or replace function app_private.unlock_id(p_item jsonb)
returns text language sql immutable set search_path = '' as $$
  select case when p_item->>'category' = 'badge' then substr(p_item->>'id', 7) else p_item->>'id' end;
$$;

create or replace function app_private.owns(p_user uuid, p_id text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((app_private.cosmetic(p_id)->>'default')::boolean, false)
      or exists (select 1 from public.player_unlocks u
                  where u.user_id = p_user and u.kind = app_private.cosmetic(p_id)->>'category'
                    and u.item_id = app_private.unlock_id(app_private.cosmetic(p_id)));
$$;

revoke all on function app_private.cosmetic(text), app_private.unlock_id(jsonb), app_private.owns(uuid, text) from public, anon, authenticated;

-- Grants an item once (rewards); returns true if it was new. Unknown ids raise.
create or replace function game._grant_item(p_user uuid, p_id text, p_source text)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare v jsonb := app_private.cosmetic(p_id);
begin
  if v is null then raise exception 'ITEM_NOT_FOUND'; end if;
  if coalesce((v->>'default')::boolean, false) then return false; end if;
  insert into public.player_unlocks (user_id, kind, item_id, source)
  values (p_user, v->>'category', app_private.unlock_id(v), p_source) on conflict do nothing;
  return found;
end;
$$;
revoke all on function game._grant_item(uuid, text, text) from public, anon, authenticated;

-- ------------------------------------------------------------------ client
-- Published catalog with server prices (rarity table) and featured list.
create or replace function public.cosmetics_catalog()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_cfg jsonb := (select value from public.app_config where key = 'cosmetics');
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  return jsonb_build_object(
    'version', v_cfg->'version',
    'store_enabled', coalesce((select (value->>'cosmetics_store_enabled')::boolean from public.app_config where key = 'features'), false),
    'featured', v_cfg->'featured',
    'items', coalesce((select jsonb_agg(i || jsonb_build_object(
                         'price', case when (i->>'purchasable')::boolean
                                       then (v_cfg->'prices'->(i->>'currency')->>(i->>'rarity'))::int end)
                       order by ord)
                  from jsonb_array_elements(v_cfg->'items') with ordinality x(i, ord)
                 where (i->>'published')::boolean), '[]'::jsonb));
end;
$$;

-- My items (with how I got them) and what I have equipped.
create or replace function public.my_inventory()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_cfg jsonb := (select value from public.app_config where key = 'cosmetics');
  l record;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into l from public.player_loadout where user_id = v_me;
  return jsonb_build_object(
    'owned', coalesce((
      select jsonb_agg(jsonb_build_object('id', i->>'id', 'category', i->>'category', 'source', coalesce(u.source, 'default'),
                                          'acquired_at', u.created_at) order by i->>'category', i->>'id')
        from jsonb_array_elements(v_cfg->'items') i
        left join public.player_unlocks u on u.user_id = v_me and u.kind = i->>'category' and u.item_id = app_private.unlock_id(i)
       where coalesce((i->>'default')::boolean, false) or u.user_id is not null), '[]'::jsonb),
    'loadout', jsonb_build_object(
      'dice', coalesce(l.dice, 'dice_classic'), 'pawns', coalesce(l.pawns, 'pawns_classic'), 'board', coalesce(l.board, 'board_classic'),
      'frame', coalesce(l.frame, 'frame_none'), 'effect', coalesce(l.effect, 'effect_none'), 'name', coalesce(l.name, 'name_plain'),
      'emotes', coalesce(l.emotes, 'emotes_classic'),
      'badge', (select case when badge_id is null then null else 'badge_' || badge_id end from public.profiles where user_id = v_me)));
end;
$$;

revoke all on function public.cosmetics_catalog(), public.my_inventory() from public, anon;
grant execute on function public.cosmetics_catalog(), public.my_inventory() to authenticated;
