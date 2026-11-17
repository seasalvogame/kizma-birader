-- Kızma Birader — Phase 5: friends (search, requests, list, remove, block) and
-- the server-side checks used by the game server for invites and presence.
--
-- Tables come from 20261117120300_social.sql (unchanged). Clients still cannot
-- write them directly: every change goes through these SECURITY DEFINER
-- functions, which take the caller from the JWT (auth.uid()) — a client can
-- never act for another user. Blocks hide both players from each other
-- (search, requests, profiles, invites); who blocked whom is never revealed
-- (both directions answer NOT_ALLOWED).

-- ----------------------------------------------------------------- helpers
create or replace function app_private.blocked_between(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.blocks
                  where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a));
$$;

create or replace function app_private.are_friends(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.friendships where user_low = least(a, b) and user_high = greatest(a, b));
$$;

create or replace function app_private.friend_count(a uuid)
returns int language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.friendships where a in (user_low, user_high);
$$;

-- One transaction at a time per pair of players (requests in both directions at once).
create or replace function app_private.lock_pair(a uuid, b uuid)
returns void language sql volatile security definer set search_path = '' as $$
  select pg_advisory_xact_lock(hashtextextended(least(a, b)::text || greatest(a, b)::text, 5));
$$;

create or replace function app_private.relation(me uuid, other uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case
    when app_private.are_friends(me, other) then 'friend'
    when exists (select 1 from public.friend_requests r where r.from_id = me and r.to_id = other and r.status = 'pending') then 'outgoing'
    when exists (select 1 from public.friend_requests r where r.from_id = other and r.to_id = me and r.status = 'pending') then 'incoming'
    else 'none' end;
$$;

revoke all on function app_private.blocked_between(uuid, uuid), app_private.are_friends(uuid, uuid),
  app_private.friend_count(uuid), app_private.lock_pair(uuid, uuid), app_private.relation(uuid, uuid) from public, anon, authenticated;

-- ------------------------------------------------------------------ search
-- "Ayşe" (name prefix) or "Ayşe#1234" (exact tag). At most 20 rows; never the
-- caller, never a blocked player (either direction).
create or replace function public.search_players(p_query text)
returns table (user_id uuid, display_name text, tag int, avatar_id text, relation text)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_q text := btrim(coalesce(p_query, ''));
  v_name text;
  v_tag int;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  if length(v_q) < 2 or length(v_q) > 24 then return; end if;
  if v_q ~ '#[0-9]{1,4}$' then
    v_name := btrim(split_part(v_q, '#', 1));
    v_tag := split_part(v_q, '#', 2)::int;
  else
    v_name := v_q;
  end if;
  if length(v_name) < 2 then return; end if;
  v_name := replace(replace(replace(lower(v_name), '\', '\\'), '%', '\%'), '_', '\_');
  return query
    select p.user_id, p.display_name, p.tag, p.avatar_id, app_private.relation(v_me, p.user_id)
      from public.profiles p
     where p.user_id <> v_me
       and lower(p.display_name) like v_name || '%'
       and (v_tag is null or p.tag = v_tag)
       and not app_private.blocked_between(v_me, p.user_id)
     order by (lower(p.display_name) = v_name) desc, p.display_name, p.tag
     limit 20;
end;
$$;

-- --------------------------------------------------------------- requests
create or replace function public.send_friend_request(p_to uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_id bigint;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_to is null or p_to = v_me then raise exception 'SELF'; end if;
  if not exists (select 1 from public.profiles where user_id = p_to) then raise exception 'NOT_FOUND'; end if;
  perform app_private.lock_pair(v_me, p_to);
  if app_private.blocked_between(v_me, p_to) then raise exception 'NOT_ALLOWED'; end if;
  if app_private.are_friends(v_me, p_to) then raise exception 'ALREADY_FRIENDS'; end if;
  if exists (select 1 from public.friend_requests where from_id = v_me and to_id = p_to and status = 'pending') then
    raise exception 'ALREADY_PENDING';
  end if;
  -- they already asked me: this is an acceptance
  select id into v_id from public.friend_requests where from_id = p_to and to_id = v_me and status = 'pending' for update;
  if v_id is not null then
    if app_private.friend_count(v_me) >= 200 or app_private.friend_count(p_to) >= 200 then raise exception 'FRIEND_LIMIT'; end if;
    update public.friend_requests set status = 'accepted', responded_at = now() where id = v_id;
    insert into public.friendships (user_low, user_high) values (least(v_me, p_to), greatest(v_me, p_to)) on conflict do nothing;
    return jsonb_build_object('status', 'accepted', 'request_id', v_id);
  end if;
  if (select count(*) from public.friend_requests where from_id = v_me and status = 'pending') >= 50 then
    raise exception 'REQUEST_LIMIT';
  end if;
  insert into public.friend_requests (from_id, to_id, status) values (v_me, p_to, 'pending') returning id into v_id;
  return jsonb_build_object('status', 'pending', 'request_id', v_id);
end;
$$;

create or replace function public.respond_friend_request(p_request_id bigint, p_accept boolean)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_from uuid;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  select from_id into v_from from public.friend_requests
   where id = p_request_id and to_id = v_me and status = 'pending' for update;
  if v_from is null then raise exception 'REQUEST_NOT_FOUND'; end if;
  perform app_private.lock_pair(v_me, v_from);
  if not p_accept then
    update public.friend_requests set status = 'declined', responded_at = now() where id = p_request_id;
    return jsonb_build_object('status', 'declined');
  end if;
  if app_private.blocked_between(v_me, v_from) then raise exception 'NOT_ALLOWED'; end if;
  if app_private.friend_count(v_me) >= 200 or app_private.friend_count(v_from) >= 200 then raise exception 'FRIEND_LIMIT'; end if;
  update public.friend_requests set status = 'accepted', responded_at = now() where id = p_request_id;
  update public.friend_requests set status = 'cancelled', responded_at = now()
   where from_id = v_me and to_id = v_from and status = 'pending';
  insert into public.friendships (user_low, user_high) values (least(v_me, v_from), greatest(v_me, v_from)) on conflict do nothing;
  return jsonb_build_object('status', 'accepted', 'user_id', v_from);
end;
$$;

create or replace function public.cancel_friend_request(p_request_id bigint)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  update public.friend_requests set status = 'cancelled', responded_at = now()
   where id = p_request_id and from_id = v_me and status = 'pending';
  if not found then raise exception 'REQUEST_NOT_FOUND'; end if;
  return jsonb_build_object('status', 'cancelled');
end;
$$;

-- ------------------------------------------------------- friends and blocks
create or replace function public.remove_friend(p_other uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  delete from public.friendships where user_low = least(v_me, p_other) and user_high = greatest(v_me, p_other);
  return jsonb_build_object('removed', found);
end;
$$;

create or replace function public.block_player(p_other uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_other is null or p_other = v_me then raise exception 'SELF'; end if;
  if not exists (select 1 from public.profiles where user_id = p_other) then raise exception 'NOT_FOUND'; end if;
  perform app_private.lock_pair(v_me, p_other);
  insert into public.blocks (blocker_id, blocked_id) values (v_me, p_other) on conflict do nothing;
  delete from public.friendships where user_low = least(v_me, p_other) and user_high = greatest(v_me, p_other);
  update public.friend_requests set status = 'cancelled', responded_at = now()
   where status = 'pending' and ((from_id = v_me and to_id = p_other) or (from_id = p_other and to_id = v_me));
  return jsonb_build_object('blocked', true);
end;
$$;

create or replace function public.unblock_player(p_other uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  delete from public.blocks where blocker_id = v_me and blocked_id = p_other;
  return jsonb_build_object('unblocked', found);
end;
$$;

-- ------------------------------------------------------------------- lists
create or replace function public.my_friends()
returns table (user_id uuid, display_name text, tag int, avatar_id text, since timestamptz)
language sql stable security definer set search_path = '' as $$
  select p.user_id, p.display_name, p.tag, p.avatar_id, f.created_at
    from public.friendships f
    join public.profiles p on p.user_id = case when f.user_low = auth.uid() then f.user_high else f.user_low end
   where auth.uid() in (f.user_low, f.user_high)
   order by lower(p.display_name), p.tag;
$$;

create or replace function public.my_friend_requests()
returns table (id bigint, direction text, user_id uuid, display_name text, tag int, avatar_id text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select r.id, case when r.to_id = auth.uid() then 'in' else 'out' end, p.user_id, p.display_name, p.tag, p.avatar_id, r.created_at
    from public.friend_requests r
    join public.profiles p on p.user_id = case when r.to_id = auth.uid() then r.from_id else r.to_id end
   where r.status = 'pending' and auth.uid() in (r.from_id, r.to_id)
     and not app_private.blocked_between(r.from_id, r.to_id)
   order by r.created_at desc
   limit 100;
$$;

create or replace function public.my_blocks()
returns table (user_id uuid, display_name text, tag int, avatar_id text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select p.user_id, p.display_name, p.tag, p.avatar_id, b.created_at
    from public.blocks b join public.profiles p on p.user_id = b.blocked_id
   where b.blocker_id = auth.uid()
   order by b.created_at desc;
$$;

-- Another player's public profile: name, avatar, online totals, relation.
-- Nothing for blocked players (either direction).
create or replace function public.get_player_profile(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v jsonb;
begin
  if v_me is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_user <> v_me and app_private.blocked_between(v_me, p_user) then raise exception 'NOT_FOUND'; end if;
  select jsonb_build_object(
           'user_id', p.user_id, 'display_name', p.display_name, 'tag', p.tag, 'avatar_id', p.avatar_id,
           'relation', app_private.relation(v_me, p.user_id),
           'matches_2p', coalesce(s.matches_2p, 0), 'wins_2p', coalesce(s.wins_2p, 0),
           'matches_4p', coalesce(s.matches_4p, 0), 'wins_4p', coalesce(s.wins_4p, 0),
           'friends_since', (select f.created_at from public.friendships f
                              where f.user_low = least(v_me, p.user_id) and f.user_high = greatest(v_me, p.user_id)))
    into v
    from public.profiles p left join public.player_stats s on s.user_id = p.user_id
   where p.user_id = p_user;
  if v is null then raise exception 'NOT_FOUND'; end if;
  return v;
end;
$$;

revoke all on function public.search_players(text), public.send_friend_request(uuid), public.respond_friend_request(bigint, boolean),
  public.cancel_friend_request(bigint), public.remove_friend(uuid), public.block_player(uuid), public.unblock_player(uuid),
  public.my_friends(), public.my_friend_requests(), public.my_blocks(), public.get_player_profile(uuid) from public, anon;
grant execute on function public.search_players(text), public.send_friend_request(uuid), public.respond_friend_request(bigint, boolean),
  public.cancel_friend_request(bigint), public.remove_friend(uuid), public.block_player(uuid), public.unblock_player(uuid),
  public.my_friends(), public.my_friend_requests(), public.my_blocks(), public.get_player_profile(uuid) to authenticated;

-- --------------------------------------------------------- game server side
-- Used by the Worker (role game_server) for invites and presence.
create or replace function game.social_check(p_from uuid, p_to uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('friends', app_private.are_friends(p_from, p_to),
                            'blocked', app_private.blocked_between(p_from, p_to));
$$;

create or replace function game.friend_ids(p_user uuid)
returns uuid[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(case when f.user_low = p_user then f.user_high else f.user_low end), '{}')
    from (select * from public.friendships where p_user in (user_low, user_high) limit 200) f;
$$;

revoke all on function game.social_check(uuid, uuid), game.friend_ids(uuid) from public, anon, authenticated;
grant execute on function game.social_check(uuid, uuid), game.friend_ids(uuid) to game_server;
