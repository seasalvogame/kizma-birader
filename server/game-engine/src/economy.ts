// Economy preparation (Phase 2): gold entry tiers and match payouts are data,
// never constants in code. The server owns the config (shared/config/
// economy_config.example.json shows the shape); this module validates it and
// computes payouts with integer maths only. Not wired to any wallet yet.
//
// Rules (docs/ECONOMY_TWO_CURRENCY_DESIGN.md):
// - Only GOLD enters matches. Gems (Elmas) never appear here.
// - pool = entry x players; rake (house cut, %) is removed from the pool;
//   the rest is split by place with basis points (sum 10000).
// - Rounding always goes down; the total paid never exceeds the pool.
// - A player who left gets the share of the place they ended in (usually 0).

export interface EntryTier {
  id: string;
  entry_gold: number;
  players: (2 | 4)[];
  /** Basis points per place (1st, 2nd, ...), must sum to 10000. */
  shares_2p: number[];
  shares_4p: number[];
  /** Minimum level to join (0 = none). */
  min_level: number;
  enabled: boolean;
}

export interface EconomyConfig {
  version: number;
  rake_percent: number;
  tiers: EntryTier[];
  daily_free_gold: number;
  /** Top-up for players who cannot afford the cheapest tier. */
  bailout: { below_gold: number; amount: number; per_day: number };
  starting_gold: number;
}

export function validateEconomyConfig(c: EconomyConfig): string[] {
  const errors: string[] = [];
  const int = (v: unknown) => Number.isInteger(v) && (v as number) >= 0;
  if (!int(c.version)) errors.push("version");
  if (!int(c.rake_percent) || c.rake_percent > 50) errors.push("rake_percent must be 0..50");
  if (!int(c.daily_free_gold)) errors.push("daily_free_gold");
  if (!int(c.starting_gold)) errors.push("starting_gold");
  if (!int(c.bailout?.below_gold) || !int(c.bailout?.amount) || !int(c.bailout?.per_day)) errors.push("bailout");
  const ids = new Set<string>();
  for (const t of c.tiers ?? []) {
    if (!t.id || ids.has(t.id)) errors.push(`tier id ${t.id}`);
    ids.add(t.id);
    if (!Number.isInteger(t.entry_gold) || t.entry_gold <= 0) errors.push(`${t.id}: entry_gold`);
    if (!t.players?.length || t.players.some((p) => p !== 2 && p !== 4)) errors.push(`${t.id}: players`);
    for (const [n, shares] of [[2, t.shares_2p], [4, t.shares_4p]] as const) {
      if (!t.players?.includes(n)) continue;
      if (!Array.isArray(shares) || shares.length !== n) errors.push(`${t.id}: shares_${n}p length`);
      else if (shares.some((s) => !int(s))) errors.push(`${t.id}: shares_${n}p integers`);
      else if (shares.reduce((a, b) => a + b, 0) !== 10000) errors.push(`${t.id}: shares_${n}p must sum to 10000`);
      else if (shares.some((s, i) => i > 0 && s > shares[i - 1]!)) errors.push(`${t.id}: shares_${n}p must not increase`);
    }
    if (!int(t.min_level)) errors.push(`${t.id}: min_level`);
  }
  if (!c.tiers?.length) errors.push("no tiers");
  return errors;
}

export interface Payout {
  pool: number;
  rake: number;
  /** Gold paid to each place (index 0 = 1st). */
  paid: number[];
  /** Rounding remainder (not paid to anyone; a sink like the rake). */
  remainder: number;
}

/** Payout of a finished match in a tier. ranks: seats in finishing order (left players last). */
export function computePayout(config: EconomyConfig, tierId: string, players: 2 | 4): Payout {
  const tier = config.tiers.find((t) => t.id === tierId);
  if (!tier || !tier.enabled) throw new Error(`unknown or disabled tier ${tierId}`);
  if (!tier.players.includes(players)) throw new Error(`tier ${tierId} has no ${players}-player matches`);
  const shares = players === 2 ? tier.shares_2p : tier.shares_4p;
  const pool = tier.entry_gold * players;
  const rake = Math.floor((pool * config.rake_percent) / 100);
  const distributable = pool - rake;
  const paid = shares.map((s) => Math.floor((distributable * s) / 10000));
  const remainder = distributable - paid.reduce((a, b) => a + b, 0);
  return { pool, rake, paid, remainder };
}

/** Can the player enter? (balance never goes negative: the entry is checked, not borrowed.) */
export function canEnter(config: EconomyConfig, tierId: string, goldBalance: number, level: number): boolean {
  const tier = config.tiers.find((t) => t.id === tierId);
  return !!tier && tier.enabled && goldBalance >= tier.entry_gold && level >= tier.min_level;
}

/** Bailout eligibility: below the threshold and fewer than per_day top-ups today. */
export function bailoutAmount(config: EconomyConfig, goldBalance: number, bailoutsToday: number): number {
  if (goldBalance >= config.bailout.below_gold || bailoutsToday >= config.bailout.per_day) return 0;
  return config.bailout.amount;
}
