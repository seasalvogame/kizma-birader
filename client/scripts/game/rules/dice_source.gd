class_name DiceSource
extends RefCounted
## Where dice values come from (GAME_RULES §3). The engine never rolls by
## itself. Online games will use the server's dice only; the offline
## practice mode uses the device RNG; tests use scripted values.

var _values: Array[int] = []
var _index := 0
var _rng: RandomNumberGenerator


## Offline practice: device RNG (randomized seed).
static func local() -> DiceSource:
	var d := DiceSource.new()
	d._rng = RandomNumberGenerator.new()
	d._rng.randomize()
	return d


## Tests and simulations: reproducible from a seed, each value drawn within
## the bound asked for (twin of seededDice in dice.ts; not the same stream).
static func seeded(seed: int) -> DiceSource:
	var d := DiceSource.new()
	d._rng = RandomNumberGenerator.new()
	d._rng.seed = seed
	return d


## Tests: a fixed sequence (errors when it runs out).
static func scripted(values: Array) -> DiceSource:
	var d := DiceSource.new()
	for v: Variant in values:
		d._values.append(int(v))
	return d


## A value in 1..max_value (6, or 5 right after two sixes; see
## GameEngine.max_dice_value).
func next(max_value: int = 6) -> int:
	if max_value < 1 or max_value > 6:
		push_error("bad dice max %d" % max_value)
		return 1
	if _rng != null:
		return _rng.randi_range(1, max_value)
	if _index >= _values.size():
		push_error("scripted dice ran out")
		return 1
	_index += 1
	var v := _values[_index - 1]
	if v < 1 or v > max_value:
		push_error("bad scripted dice %d (max %d)" % [v, max_value])
	return v


func remaining() -> int:
	return _values.size() - _index
