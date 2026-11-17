-- Kızma Birader — 3/4 economy: Gold + Gems wallets, ledger, debts, purchases,
-- match entry escrow, and the server-only functions that change them
-- (docs/economy/GOLD_AND_DIAMOND_ECONOMY.md).
--
-- Invariants enforced here (not only in application code):
--   * balances never go below zero (CHECK) — a refund of spent currency becomes a debt;
--   * every balance change writes one ledger row in the same transaction;
--   * every change has a unique idempotency key, so a retried request has no second effect;
--   * Gems are never used for match entry (escrow only touches gold);
--   * gold-entry matches are refused while app_config.features.gold_matches_enabled is false (E-7);
--   * payouts can never exceed the escrowed pool.

-- ------------------------------------------------------------------ tables
create table public.wallets (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  coins      bigint not null default 0 check (coins >= 0),   -- Altın
  gems       bigint not null default 0 check (gems >= 0),    -- Elmas
  updated_at timestamptz not null default now()
);

create table public.wallet_transactions (
  id              bigint generated always as identity primary key,
  user_id         uuid not null references auth.users (id) on delete cascade,
  currency        text not null check (currency in ('gold', 'gems')),
  delta           bigint not null check (delta <> 0),
  balance_after   bigint not null check (balance_after >= 0),
  reason          text not null check (reason in (
                    'starting_gold', 'match_entry', 'match_payout', 'match_refund',
                    'iap_gold', 'iap_gems', 'refund_clawback', 'debt_settlement',
                    'daily_free_gold', 'bailout', 'daily_login', 'quest', 'achievement',
                    'level_up', 'store_purchase', 'ad_reward', 'compensation', 'admin_adjust')),
  ref_type        text,
  ref_id          text,
  idempotency_key text not null unique,
  created_at      timestamptz not null default now()
);
create index wallet_tx_user_idx on public.wallet_transactions (user_id, created_at desc);

create table public.purchases (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid references auth.users (id) on delete set null,   -- kept for legal retention (K-48)
  platform         text not null check (platform in ('google', 'apple')),
  environment      text not null check (environment in ('production', 'sandbox')),
  product_id       text not null,
  transaction_id   text not null,
  kind             text not null check (kind in ('gold', 'gems')),
  amount           bigint not null check (amount > 0),
  status           text not null check (status in ('granted', 'refunded', 'revoked')),
  verified_payload jsonb not null default '{}'::jsonb,   -- fields from the store's server-side verification
  granted_at       timestamptz not null default now(),
  refunded_at      timestamptz,
  unique (platform, transaction_id)
);
create index purchases_user_idx on public.purchases (user_id, granted_at desc);

-- A refund of currency that was already spent (E-6): the balance stops at 0,
-- the rest is recorded here and paid back from later credits.
create table public.wallet_debts (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  currency    text not null check (currency in ('gold', 'gems')),
  amount      bigint not null check (amount > 0),
  remaining   bigint not null check (remaining >= 0 and remaining <= amount),
  purchase_id uuid references public.purchases (id) on delete set null,
  created_at  timestamptz not null default now(),
  settled_at  timestamptz
);
create index wallet_debts_open_idx on public.wallet_debts (user_id, currency) where remaining > 0;

create table public.match_entries (
  match_id   uuid not null references public.matches (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  amount     bigint not null check (amount > 0),
  status     text not null check (status in ('held', 'paid_out', 'refunded')),
  created_at timestamptz not null default now(),
  settled_at timestamptz,
  primary key (match_id, user_id)
);

-- ------------------------------------------------------------------- RLS
alter table public.wallets enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.purchases enable row level security;
alter table public.wallet_debts enable row level security;
alter table public.match_entries enable row level security;
create policy wallets_read_own on public.wallets for select to authenticated using (user_id = (select auth.uid()));
create policy wallet_tx_read_own on public.wallet_transactions for select to authenticated using (user_id = (select auth.uid()));
create policy purchases_read_own on public.purchases for select to authenticated using (user_id = (select auth.uid()));
create policy wallet_debts_read_own on public.wallet_debts for select to authenticated using (user_id = (select auth.uid()));
create policy match_entries_read_own on public.match_entries for select to authenticated using (user_id = (select auth.uid()));

revoke all on public.wallets, public.wallet_transactions, public.purchases, public.wallet_debts, public.match_entries
  from anon, authenticated;
grant select on public.wallets, public.wallet_transactions, public.purchases, public.wallet_debts, public.match_entries
  to authenticated;

-- ------------------------------------------------------- internal helpers
-- Apply one balance change. Locks the wallet row first, so concurrent calls
-- for the same user are serialised and the idempotency check below is exact.
-- Returns {applied, balance}. A reused key with different content is a bug.
create or replace function game._apply(
  p_user uuid, p_currency text, p_delta bigint, p_reason text, p_key text,
  p_ref_type text default null, p_ref_id text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tx      public.wallet_transactions;
  v_balance bigint;
begin
  if p_delta is null or p_delta = 0 then raise exception 'BAD_AMOUNT'; end if;
  if p_currency is null or p_currency not in ('gold', 'gems') then raise exception 'BAD_CURRENCY'; end if;
  if p_key is null or length(p_key) = 0 then raise exception 'BAD_KEY'; end if;

  perform 1 from public.wallets where user_id = p_user for update;
  if not found then raise exception 'NO_WALLET'; end if;

  select * into v_tx from public.wallet_transactions where idempotency_key = p_key;
  if found then
    if v_tx.user_id <> p_user or v_tx.currency <> p_currency or v_tx.delta <> p_delta then
      raise exception 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return jsonb_build_object('applied', false, 'balance', v_tx.balance_after);
  end if;

  begin
    if p_currency = 'gold' then
      update public.wallets set coins = coins + p_delta, updated_at = now()
        where user_id = p_user returning coins into v_balance;
    else
      update public.wallets set gems = gems + p_delta, updated_at = now()
        where user_id = p_user returning gems into v_balance;
    end if;
  exception when check_violation then
    raise exception 'INSUFFICIENT_FUNDS';
  end;

  insert into public.wallet_transactions
    (user_id, currency, delta, balance_after, reason, ref_type, ref_id, idempotency_key)
  values (p_user, p_currency, p_delta, v_balance, p_reason, p_ref_type, p_ref_id, p_key);
  return jsonb_build_object('applied', true, 'balance', v_balance);
end;
$$;

create or replace function game._has_open_debt(p_user uuid, p_currency text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.wallet_debts
                 where user_id = p_user and currency = p_currency and remaining > 0);
$$;

-- After a credit: pay open debts of that currency from the balance.
create or replace function game._settle_debts(p_user uuid, p_currency text, p_key_base text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  d     record;
  v_bal bigint;
  v_pay bigint;
begin
  for d in select id, remaining from public.wallet_debts
           where user_id = p_user and currency = p_currency and remaining > 0
           order by id for update
  loop
    select case when p_currency = 'gold' then coins else gems end into v_bal
      from public.wallets where user_id = p_user;
    v_pay := least(v_bal, d.remaining);
    exit when v_pay <= 0;
    perform game._apply(p_user, p_currency, -v_pay, 'debt_settlement',
                        p_key_base || ':debt:' || d.id, 'debt', d.id::text);
    update public.wallet_debts
       set remaining = remaining - v_pay,
           settled_at = case when remaining - v_pay = 0 then now() else null end
     where id = d.id;
  end loop;
end;
$$;

-- --------------------------------------------------- server API: matches
-- Creates the match record and takes the entry fee from every human player
-- in one transaction: all players pay or nobody does. Idempotent per match id.
-- p_seats: [{"seat": 0, "color": "red", "user_id": "<uuid>" | null, "is_bot": false}, ...]
create or replace function game.start_match(
  p_match_id uuid, p_mode text, p_ruleset jsonb, p_economy_tier text,
  p_entry_fee bigint, p_config_version int, p_seats jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_n      int;
  v_colors text[];
  s        jsonb;
  v_user   uuid;
  v_bot    boolean;
  v_humans uuid[] := '{}';
begin
  if p_match_id is null then raise exception 'BAD_MATCH'; end if;
  select status into v_status from public.matches where id = p_match_id;
  if found then
    return jsonb_build_object('created', false, 'status', v_status);
  end if;

  if p_seats is null or jsonb_typeof(p_seats) <> 'array' then raise exception 'BAD_SEATS'; end if;
  v_n := jsonb_array_length(p_seats);
  if v_n not in (2, 4) then raise exception 'BAD_SEATS'; end if;
  if p_entry_fee is null or p_entry_fee < 0 then raise exception 'BAD_AMOUNT'; end if;

  select array_agg(e->>'color' order by (e->>'seat')::int) into v_colors from jsonb_array_elements(p_seats) e;
  if (select count(distinct (e->>'seat')::int) from jsonb_array_elements(p_seats) e
      where (e->>'seat')::int between 0 and v_n - 1) <> v_n then
    raise exception 'BAD_SEATS';
  end if;
  if (select count(distinct c) from unnest(v_colors) c where c in ('red', 'green', 'yellow', 'blue')) <> v_n then
    raise exception 'BAD_COLORS';
  end if;
  -- 2 players: opposite colours only (K-08): red–yellow or green–blue.
  if v_n = 2 and not (v_colors @> array['red', 'yellow'] or v_colors @> array['green', 'blue']) then
    raise exception 'COLOR_INVALID';
  end if;

  if p_entry_fee > 0 then
    if coalesce((select (value->>'gold_matches_enabled')::boolean from public.app_config where key = 'features'), false) is not true then
      raise exception 'GOLD_MATCHES_DISABLED';
    end if;
  end if;

  insert into public.matches (id, mode, players, ruleset, economy_tier, entry_fee, economy_config_version, status)
  values (p_match_id, p_mode, v_n, p_ruleset, coalesce(p_economy_tier, 'free'), p_entry_fee, p_config_version, 'playing');

  for s in select * from jsonb_array_elements(p_seats) loop
    v_bot := coalesce((s->>'is_bot')::boolean, false);
    v_user := nullif(s->>'user_id', '')::uuid;
    if v_bot and v_user is not null then raise exception 'BAD_SEATS'; end if;
    if not v_bot then
      if v_user is null or v_user = any(v_humans) then raise exception 'BAD_SEATS'; end if;
      v_humans := v_humans || v_user;
    end if;
    insert into public.match_players (match_id, seat, user_id, color, is_bot)
    values (p_match_id, (s->>'seat')::int, v_user, s->>'color', v_bot);
  end loop;

  if p_entry_fee > 0 then
    if cardinality(v_humans) <> v_n then raise exception 'BOTS_IN_GOLD_MATCH'; end if;
    foreach v_user in array v_humans loop
      if game._has_open_debt(v_user, 'gold') then raise exception 'DEBT_OUTSTANDING'; end if;
      perform game._apply(v_user, 'gold', -p_entry_fee, 'match_entry',
                          'entry:' || p_match_id || ':' || v_user, 'match', p_match_id::text);
      insert into public.match_entries (match_id, user_id, amount, status)
      values (p_match_id, v_user, p_entry_fee, 'held');
    end loop;
  end if;
  return jsonb_build_object('created', true, 'status', 'playing');
end;
$$;

-- Records the result and pays the server-computed payouts (computePayout).
-- The sum of payouts can never exceed the escrowed pool. Idempotent.
-- p_results: [{"seat": 0, "rank": 1, "left": false}, ...]
-- p_payouts: [{"user_id": "<uuid>", "amount": 180}, ...]   (amount > 0 only)
create or replace function game.finish_match(
  p_match_id uuid, p_results jsonb, p_payouts jsonb, p_end_reason text, p_actions text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_match  public.matches;
  v_pool   bigint;
  v_total  bigint := 0;
  r        jsonb;
  v_user   uuid;
  v_amount bigint;
  v_res    jsonb;
  v_users  uuid[] := '{}';
begin
  select * into v_match from public.matches where id = p_match_id for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if v_match.status = 'finished' then return jsonb_build_object('applied', false, 'status', 'finished'); end if;
  if v_match.status = 'void' then raise exception 'MATCH_VOID'; end if;

  for r in select * from jsonb_array_elements(coalesce(p_results, '[]'::jsonb)) loop
    update public.match_players
       set rank = nullif(r->>'rank', '')::int,
           left_match = coalesce((r->>'left')::boolean, false)
     where match_id = p_match_id and seat = (r->>'seat')::int;
    if not found then raise exception 'BAD_RESULTS'; end if;
  end loop;

  select coalesce(sum(amount), 0) into v_pool
    from public.match_entries where match_id = p_match_id and status = 'held';

  for r in select * from jsonb_array_elements(coalesce(p_payouts, '[]'::jsonb)) loop
    v_user := (r->>'user_id')::uuid;
    v_amount := (r->>'amount')::bigint;
    if v_amount is null or v_amount <= 0 or v_user = any(v_users) then raise exception 'BAD_PAYOUT'; end if;
    if not exists (select 1 from public.match_entries
                   where match_id = p_match_id and user_id = v_user and status = 'held') then
      raise exception 'BAD_PAYOUT';
    end if;
    v_users := v_users || v_user;
    v_total := v_total + v_amount;
  end loop;
  if v_total > v_pool then raise exception 'PAYOUT_EXCEEDS_POOL'; end if;

  for r in select * from jsonb_array_elements(coalesce(p_payouts, '[]'::jsonb)) loop
    v_user := (r->>'user_id')::uuid;
    v_amount := (r->>'amount')::bigint;
    v_res := game._apply(v_user, 'gold', v_amount, 'match_payout',
                         'payout:' || p_match_id || ':' || v_user, 'match', p_match_id::text);
    if (v_res->>'applied')::boolean then
      perform game._settle_debts(v_user, 'gold', 'payout:' || p_match_id || ':' || v_user);
    end if;
    update public.match_players set payout = v_amount where match_id = p_match_id and user_id = v_user;
  end loop;

  update public.match_entries set status = 'paid_out', settled_at = now()
   where match_id = p_match_id and status = 'held';
  update public.matches
     set status = 'finished', ended_at = now(), end_reason = p_end_reason, actions = p_actions
   where id = p_match_id;

  update public.player_stats ps
     set matches_2p = matches_2p + case when v_match.players = 2 then 1 else 0 end,
         matches_4p = matches_4p + case when v_match.players = 4 then 1 else 0 end,
         wins_2p    = wins_2p + case when v_match.players = 2 and mp.rank = 1 then 1 else 0 end,
         wins_4p    = wins_4p + case when v_match.players = 4 and mp.rank = 1 then 1 else 0 end,
         leaves     = leaves + case when mp.left_match then 1 else 0 end,
         updated_at = now()
    from public.match_players mp
   where mp.match_id = p_match_id and mp.user_id = ps.user_id and not mp.is_bot;

  return jsonb_build_object('applied', true, 'pool', v_pool, 'paid', v_total, 'rake', v_pool - v_total);
end;
$$;

-- Void match (server failure, unrecoverable state): every held entry is
-- refunded. Idempotent; a finished match cannot be voided.
create or replace function game.void_match(p_match_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  e        record;
  v_n      int := 0;
begin
  select status into v_status from public.matches where id = p_match_id for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if v_status = 'void' then return jsonb_build_object('applied', false, 'status', 'void'); end if;
  if v_status = 'finished' then raise exception 'MATCH_FINISHED'; end if;
  for e in select user_id, amount from public.match_entries
           where match_id = p_match_id and status = 'held' loop
    perform game._apply(e.user_id, 'gold', e.amount, 'match_refund',
                        'refund:' || p_match_id || ':' || e.user_id, 'match', p_match_id::text);
    perform game._settle_debts(e.user_id, 'gold', 'refund:' || p_match_id || ':' || e.user_id);
    v_n := v_n + 1;
  end loop;
  update public.match_entries set status = 'refunded', settled_at = now()
   where match_id = p_match_id and status = 'held';
  update public.matches set status = 'void', ended_at = now(), end_reason = p_reason where id = p_match_id;
  return jsonb_build_object('applied', true, 'refunded', v_n);
end;
$$;

-- Reconciliation (scheduled job): matches still 'playing' after p_max_age are
-- voided and refunded (SECURITY_ARCHITECTURE §7).
create or replace function game.reconcile_stale_matches(p_max_age interval)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  m   record;
  v_n int := 0;
begin
  if p_max_age < interval '1 hour' then raise exception 'BAD_AGE'; end if;
  for m in select id from public.matches
           where status = 'playing' and started_at < now() - p_max_age loop
    perform game.void_match(m.id, 'stale');
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

-- ------------------------------------------------- server API: purchases
-- Called only after the store's server API verified the purchase (Phase 8).
-- Idempotent per (platform, transaction_id); a purchase is bound to one user.
create or replace function game.grant_purchase(
  p_user uuid, p_platform text, p_environment text, p_product_id text,
  p_transaction_id text, p_kind text, p_amount bigint, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id    uuid;
  v_owner uuid;
  v_key   text := 'iap:' || p_platform || ':' || p_transaction_id;
  v_res   jsonb;
begin
  if p_kind not in ('gold', 'gems') then raise exception 'BAD_CURRENCY'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'BAD_AMOUNT'; end if;
  insert into public.purchases (user_id, platform, environment, product_id, transaction_id, kind, amount, status, verified_payload)
  values (p_user, p_platform, p_environment, p_product_id, p_transaction_id, p_kind, p_amount, 'granted', coalesce(p_payload, '{}'::jsonb))
  on conflict (platform, transaction_id) do nothing
  returning id into v_id;
  if v_id is null then
    select user_id into v_owner from public.purchases
     where platform = p_platform and transaction_id = p_transaction_id;
    if v_owner is distinct from p_user then raise exception 'PURCHASE_OWNED_BY_OTHER'; end if;
    return jsonb_build_object('applied', false);
  end if;
  v_res := game._apply(p_user, p_kind, p_amount, case when p_kind = 'gold' then 'iap_gold' else 'iap_gems' end,
                       v_key, 'purchase', v_id::text);
  perform game._settle_debts(p_user, p_kind, v_key);
  return jsonb_build_object('applied', true, 'purchase_id', v_id);
end;
$$;

-- Refund / revocation reported by the store. Takes back what is still in the
-- wallet; the spent part becomes a debt (E-6). The balance never goes below 0.
create or replace function game.revoke_purchase(p_platform text, p_transaction_id text, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_p    public.purchases;
  v_bal  bigint;
  v_take bigint := 0;
  v_rest bigint := 0;
begin
  if p_status not in ('refunded', 'revoked') then raise exception 'BAD_STATUS'; end if;
  select * into v_p from public.purchases
   where platform = p_platform and transaction_id = p_transaction_id for update;
  if not found then raise exception 'PURCHASE_NOT_FOUND'; end if;
  if v_p.status <> 'granted' then return jsonb_build_object('applied', false, 'status', v_p.status); end if;

  if v_p.user_id is not null then
    perform 1 from public.wallets where user_id = v_p.user_id for update;
    select case when v_p.kind = 'gold' then coins else gems end into v_bal
      from public.wallets where user_id = v_p.user_id;
    v_take := least(coalesce(v_bal, 0), v_p.amount);
    v_rest := v_p.amount - v_take;
    if v_take > 0 then
      perform game._apply(v_p.user_id, v_p.kind, -v_take, 'refund_clawback',
                          'revoke:' || p_platform || ':' || p_transaction_id, 'purchase', v_p.id::text);
    end if;
    if v_rest > 0 then
      insert into public.wallet_debts (user_id, currency, amount, remaining, purchase_id)
      values (v_p.user_id, v_p.kind, v_rest, v_rest, v_p.id);
    end if;
  end if;
  update public.purchases set status = p_status, refunded_at = now() where id = v_p.id;
  return jsonb_build_object('applied', true, 'taken', v_take, 'debt', v_rest);
end;
$$;

-- --------------------------------------------- new account bootstrap
-- Every new auth user (guest or permanent) gets a profile, stats and a wallet
-- with the configured starting gold. Linking a guest to Google / Apple / email
-- keeps the same auth.users id, so nothing has to be moved (USER_FLOWS §3).
create or replace function game.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tag   int;
  v_start bigint;
  i       int := 0;
begin
  loop
    v_tag := case when i < 30 then 1000 + floor(random() * 9000)::int
                  else 10000 + floor(random() * 90000)::int end;
    begin
      insert into public.profiles (user_id, display_name, tag) values (new.id, 'Oyuncu', v_tag);
      exit;
    exception when unique_violation then
      i := i + 1;
      if i > 60 then raise; end if;
    end;
  end loop;
  insert into public.player_stats (user_id) values (new.id);
  insert into public.wallets (user_id) values (new.id);
  select (value->>'starting_gold')::bigint into v_start from public.app_config where key = 'economy';
  if coalesce(v_start, 0) > 0 then
    perform game._apply(new.id, 'gold', v_start, 'starting_gold', 'start:' || new.id, 'user', new.id::text);
  end if;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function game.handle_new_user();

-- ------------------------------------------------------------ privileges
revoke all on all functions in schema game from public, anon, authenticated;
grant execute on function
  game.start_match(uuid, text, jsonb, text, bigint, int, jsonb),
  game.finish_match(uuid, jsonb, jsonb, text, text),
  game.void_match(uuid, text),
  game.reconcile_stale_matches(interval),
  game.grant_purchase(uuid, text, text, text, text, text, bigint, jsonb),
  game.revoke_purchase(text, text, text)
to game_server;
