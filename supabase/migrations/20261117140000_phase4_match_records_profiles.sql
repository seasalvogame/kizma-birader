-- Kızma Birader — Phase 4: persistent match records, stats, profile editing.
--
--  * game_server may log in (connection limit 20). Its password is NOT set here:
--    server/worker/scripts/setup_game_server_db.mjs sets a random one as a SCRAM
--    verifier (the plain password never reaches git, chat or database logs).
--  * game.record_match: the game server records a finished free match (no entry
--    fee) and updates every player's stats in ONE transaction, idempotent per match.
--  * game.player_names: display names for the matchmaker (profile names, not client input).
--  * public.update_my_profile: a player changes only their own name / avatar,
--    validated in the database (auth.uid(); no other row can be touched).

-- ------------------------------------------------------------ server role
alter role game_server login connection limit 20;

-- --------------------------------------------------------- record columns
alter table public.matches drop constraint if exists matches_mode_check;
alter table public.matches add constraint matches_mode_check check (mode in ('quick', 'private', 'test'));
alter table public.matches
  add column if not exists server_version   text,      -- Worker version that ran the match
  add column if not exists final_state_hash bigint,    -- FNV-1a of the canonical final state (engine)
  add column if not exists action_count     int,
  add column if not exists protocol_version int not null default 1;
alter table public.match_players
  add column if not exists display_name text,          -- name at the time of the match
  add column if not exists tag          int;
alter table public.player_stats
  add column if not exists last_match_at timestamptz;
create index if not exists matches_ended_idx on public.matches (ended_at desc) where status = 'finished';

-- ------------------------------------------------- game.record_match
-- p_seats: [{"seat":0,"color":"red","user_id":"<uuid>"|null,"is_bot":false,"rank":1,"left":false,"name":"Bot 1"}, ...]
create or replace function game.record_match(
  p_match_id uuid, p_mode text, p_ruleset jsonb, p_seats jsonb,
  p_started_at timestamptz, p_ended_at timestamptz, p_end_reason text,
  p_actions text, p_final_state_hash bigint, p_action_count int, p_server_version text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n      int;
  v_colors text[];
  v_ranks  int[];
  s        jsonb;
  v_user   uuid;
  v_bot    boolean;
  v_humans uuid[] := '{}';
  v_prof   record;
begin
  if p_match_id is null then raise exception 'BAD_MATCH'; end if;
  if exists (select 1 from public.matches where id = p_match_id) then
    return jsonb_build_object('applied', false);          -- already recorded: nothing changes
  end if;
  if p_mode not in ('quick', 'private', 'test') then raise exception 'BAD_MODE'; end if;
  if p_seats is null or jsonb_typeof(p_seats) <> 'array' then raise exception 'BAD_SEATS'; end if;
  v_n := jsonb_array_length(p_seats);
  if v_n not in (2, 4) then raise exception 'BAD_SEATS'; end if;
  if p_started_at is null or p_ended_at is null or p_ended_at < p_started_at then raise exception 'BAD_TIMES'; end if;

  select array_agg(e->>'color' order by (e->>'seat')::int), array_agg((e->>'rank')::int order by (e->>'seat')::int)
    into v_colors, v_ranks from jsonb_array_elements(p_seats) e;
  if (select count(distinct (e->>'seat')::int) from jsonb_array_elements(p_seats) e
      where (e->>'seat')::int between 0 and v_n - 1) <> v_n then raise exception 'BAD_SEATS'; end if;
  if (select count(distinct c) from unnest(v_colors) c where c in ('red', 'green', 'yellow', 'blue')) <> v_n then
    raise exception 'BAD_COLORS';
  end if;
  if v_n = 2 and not (v_colors @> array['red', 'yellow'] or v_colors @> array['green', 'blue']) then
    raise exception 'COLOR_INVALID';
  end if;
  -- a finished match ranks every seat 1..n exactly once (4p: the 4th place is set by the engine)
  if (select count(distinct r) from unnest(v_ranks) r where r between 1 and v_n) <> v_n then
    raise exception 'BAD_RANKS';
  end if;

  insert into public.matches (id, mode, players, ruleset, economy_tier, entry_fee, status, started_at, ended_at,
                              end_reason, actions, server_version, final_state_hash, action_count)
  values (p_match_id, p_mode, v_n, coalesce(p_ruleset, '{}'::jsonb), 'free', 0, 'finished', p_started_at, p_ended_at,
          p_end_reason, p_actions, p_server_version, p_final_state_hash, p_action_count);

  for s in select * from jsonb_array_elements(p_seats) loop
    v_bot := coalesce((s->>'is_bot')::boolean, false);
    v_user := nullif(s->>'user_id', '')::uuid;
    if v_bot <> (v_user is null) then raise exception 'BAD_SEATS'; end if;
    if not v_bot then
      if v_user = any(v_humans) then raise exception 'BAD_SEATS'; end if;
      v_humans := v_humans || v_user;
      select display_name, tag into v_prof from public.profiles where user_id = v_user;
      if not found then raise exception 'UNKNOWN_PLAYER'; end if;
    end if;
    insert into public.match_players (match_id, seat, user_id, color, is_bot, rank, left_match, display_name, tag)
    values (p_match_id, (s->>'seat')::int, v_user, s->>'color', v_bot, (s->>'rank')::int,
            coalesce((s->>'left')::boolean, false),
            case when v_bot then left(coalesce(s->>'name', 'Bot'), 16) else v_prof.display_name end,
            case when v_bot then null else v_prof.tag end);
  end loop;

  -- online stats: real (non-test) matches only; practice matches never reach the server
  if p_mode <> 'test' then
    update public.player_stats ps
       set matches_2p = matches_2p + case when v_n = 2 then 1 else 0 end,
           matches_4p = matches_4p + case when v_n = 4 then 1 else 0 end,
           wins_2p    = wins_2p + case when v_n = 2 and mp.rank = 1 then 1 else 0 end,
           wins_4p    = wins_4p + case when v_n = 4 and mp.rank = 1 then 1 else 0 end,
           leaves     = leaves + case when mp.left_match then 1 else 0 end,
           last_match_at = p_ended_at,
           updated_at = now()
      from public.match_players mp
     where mp.match_id = p_match_id and mp.user_id = ps.user_id and not mp.is_bot;
  end if;
  return jsonb_build_object('applied', true);
end;
$$;

-- ------------------------------------------------- game.player_names
create or replace function game.player_names(p_ids uuid[])
returns table (user_id uuid, display_name text, tag int, avatar_id text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.user_id, p.display_name, p.tag, p.avatar_id
    from public.profiles p
   where cardinality(p_ids) <= 4 and p.user_id = any(p_ids);
$$;

revoke all on function game.record_match(uuid, text, jsonb, jsonb, timestamptz, timestamptz, text, text, bigint, int, text) from public, anon, authenticated;
revoke all on function game.player_names(uuid[]) from public, anon, authenticated;
grant execute on function game.record_match(uuid, text, jsonb, jsonb, timestamptz, timestamptz, text, text, bigint, int, text) to game_server;
grant execute on function game.player_names(uuid[]) to game_server;

-- ------------------------------------------- public.update_my_profile
-- Name rules: 3–16 characters; letters (any language, incl. Turkish), digits, space,
-- "_", ".", "-"; starts and ends with a letter or digit; no double spaces.
-- The 4-digit tag stays unless the new (name, tag) pair is taken.
create or replace function public.update_my_profile(p_display_name text default null, p_avatar_id text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := (select auth.uid());
  v_name text;
  v_tag  int;
  v_cur  public.profiles;
  i      int := 0;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_cur from public.profiles where user_id = v_uid for update;
  if not found then raise exception 'NO_PROFILE'; end if;
  v_name := v_cur.display_name;
  v_tag := v_cur.tag;
  if p_display_name is not null then
    v_name := btrim(p_display_name);
    if char_length(v_name) < 3 or char_length(v_name) > 16
       or v_name !~ '^[[:alpha:][:digit:]]([[:alpha:][:digit:] _.-]*[[:alpha:][:digit:]])?$'
       or position('  ' in v_name) > 0 then
      raise exception 'NAME_INVALID';
    end if;
    while exists (select 1 from public.profiles
                   where lower(display_name) = lower(v_name) and tag = v_tag and user_id <> v_uid) loop
      i := i + 1;
      if i > 60 then raise exception 'NAME_TAKEN'; end if;
      v_tag := case when i < 30 then 1000 + floor(random() * 9000)::int else 10000 + floor(random() * 90000)::int end;
    end loop;
  end if;
  if p_avatar_id is not null and p_avatar_id not in ('default', 'fill:0', 'fill:1', 'fill:2', 'fill:3', 'fill:4', 'fill:5') then
    raise exception 'AVATAR_INVALID';
  end if;
  update public.profiles
     set display_name = v_name, tag = v_tag,
         avatar_id = coalesce(p_avatar_id, avatar_id), updated_at = now()
   where user_id = v_uid;
  return (select jsonb_build_object('display_name', display_name, 'tag', tag, 'avatar_id', avatar_id)
            from public.profiles where user_id = v_uid);
end;
$$;
revoke all on function public.update_my_profile(text, text) from public, anon;
grant execute on function public.update_my_profile(text, text) to authenticated;
