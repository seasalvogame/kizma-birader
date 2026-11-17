-- Kızma Birader — Phase 6: daily match-XP cap under concurrency (security review).
-- game._after_match locks the player's profile row before reading today's match XP,
-- so two matches of one player recorded at the same moment cannot both pass the cap.
-- (Same function as 20261118120000 otherwise.)

create or replace function game._after_match(p_match_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_cfg jsonb := (select value from public.app_config where key = 'progression');
  v_min int := coalesce((v_cfg->'xp'->>'min_actions_after_leave')::int, 0);
  v_cap int := coalesce((v_cfg->'xp'->>'daily_match_xp_cap')::int, 2147483647);
  m record;
  p record;
  v_xp int;
  v_today int;
  v_valid boolean;
  r jsonb;
  v_friend boolean;
  out jsonb := '{}'::jsonb;
begin
  select * into m from public.matches where id = p_match_id;
  if m.mode = 'test' then return out; end if;
  -- a match cut short by players leaving does not count for rewards
  v_valid := not (m.end_reason = 'left' and coalesce(m.action_count, 0) < v_min);
  for p in select * from public.match_players where match_id = p_match_id and not is_bot and user_id is not null loop
    -- 6.1 XP and level (place based; capped per TR day)
    v_xp := case when v_valid then app_private.match_xp(m.mode, m.players, p.rank, p.left_match, v_cfg) else 0 end;
    if v_xp > 0 then
      -- lock the player first: two matches of the same player recorded at the same time
      -- must not both read the daily total below the cap (security review)
      perform 1 from public.profiles where user_id = p.user_id for update;
      select coalesce(sum(amount), 0) into v_today from public.xp_events
       where user_id = p.user_id and reason = 'match' and app_private.tr_day(created_at) = app_private.tr_day(m.ended_at);
      v_xp := greatest(0, least(v_xp, v_cap - v_today));
    end if;
    r := game._grant_xp(p.user_id, v_xp, 'match', p_match_id::text);
    update public.match_players set xp_gained = (r->>'xp')::int, level_after = (r->>'level_after')::int
     where match_id = p_match_id and seat = p.seat;
    out := out || jsonb_build_object(p.user_id::text, r || jsonb_build_object('counted', v_valid));
    -- 6.2 quests (nothing for a player who left, nothing from a match cut short)
    if v_valid and not p.left_match then
      v_friend := exists (select 1 from public.match_players o
                           where o.match_id = p_match_id and o.user_id is not null and o.user_id <> p.user_id
                             and app_private.are_friends(p.user_id, o.user_id));
      if v_friend then perform game._quest_add(p.user_id, 'friend_matches', 1, m.ended_at); end if;
      if m.mode = 'quick' then
        perform game._quest_add(p.user_id, 'matches', 1, m.ended_at);
        perform game._quest_add(p.user_id, case when m.players = 2 then 'matches_2p' else 'matches_4p' end, 1, m.ended_at);
        if p.rank = 1 then perform game._quest_add(p.user_id, 'wins', 1, m.ended_at); end if;
        perform game._quest_add(p.user_id, 'rolls', p.rolls, m.ended_at);
      end if;
    end if;
  end loop;
  return out;
end;
$$;
revoke all on function game._after_match(uuid) from public, anon, authenticated;
