// MatchSession — one match: current state + idempotency (NETWORK_PROTOCOL §7).
// A request id that was already processed returns the first result again and
// changes nothing, so a resent "roll" never produces a second dice value.
// The dice source is consulted only when an action actually needs dice, and
// with the upper bound of the rules (1..5 after two sixes, GAME_RULES §6.2).

import { DiceSource } from "./dice.js";
import { Action, ApplyResult, GameEngine, maxDiceValue } from "./engine.js";
import { GameEvent } from "./events.js";
import { GameState } from "./state.js";

export interface SubmitResult {
  ok: boolean;
  error?: string;
  events: GameEvent[];
  duplicate: boolean;
  version: number;
}

export class MatchSession {
  private seen = new Map<string, SubmitResult>();
  private order: string[] = [];

  constructor(
    public state: GameState,
    private readonly engine: GameEngine,
    private readonly dice: DiceSource,
    private readonly memory = 1000,
  ) {}

  submit(requestId: string, action: Action): SubmitResult {
    const key = `${action.seat}:${requestId}`;
    const previous = this.seen.get(key);
    if (previous) return { ...previous, duplicate: true };
    const needsDice = action.type === "roll" || (action.type === "timeout" && this.state.turn.phase === "roll");
    const result: ApplyResult = this.preflight(action)
      ? this.engine.apply(this.state, action, needsDice ? this.dice.next(maxDiceValue(this.state)) : undefined)
      : this.engine.apply(this.state, action);
    if (result.ok) this.state = result.state;
    const out: SubmitResult = result.ok
      ? { ok: true, events: result.events, duplicate: false, version: result.state.version }
      : { ok: false, error: result.error, events: [], duplicate: false, version: this.state.version };
    this.seen.set(key, out);
    this.order.push(key);
    if (this.order.length > this.memory) this.seen.delete(this.order.shift()!);
    return out;
  }

  /** Draw dice only for an action the engine will accept (no wasted rolls on errors). */
  private preflight(action: Action): boolean {
    const t = this.state.turn;
    return t.phase !== "game_over" && action.type !== "leave" && action.seat === t.seat && action.turn_id === t.turn_id
      && this.state.players[action.seat]?.status === "active"
      && (action.type !== "roll" || t.phase === "roll");
  }
}
