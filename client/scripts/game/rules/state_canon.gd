class_name StateCanon
extends RefCounted
## Canonical state text + FNV-1a 32-bit hash — twin of
## server/game-engine/src/canonical.ts. Part of the parity contract: change
## both at once.


static func canonical(s: Dictionary) -> String:
	var t: Dictionary = s["turn"]
	var players: PackedStringArray = []
	for p: Dictionary in s["players"]:
		var steps: PackedStringArray = []
		for st: Variant in s["pawns"][p["color"]]:
			steps.append(str(int(st)))
		players.append("%d:%s:%s:%s:%d:%d:%d:%s" % [int(p["seat"]), p["color"], p["kind"], p["status"], int(p["rank"]),
			int(p["timeouts"]), 1 if p["autopilot"] else 0, ",".join(steps)])
	var legal: PackedStringArray = []
	for m: Dictionary in s["legal"]:
		legal.append("%d>%dx%d%s" % [int(m["pawn"]), int(m["to"]), (m["captures"] as Array).size(), "f" if m["finishes"] else ""])
	return "v%d;t%d,%s,%d,%d,%d;%s;r%s;l%s;m%s" % [int(s["version"]), int(t["seat"]), t["phase"], int(t["dice"]),
		int(t["sixes"]), int(t["turn_id"]), "|".join(players), _join_ints(s["ranks"]), _join_ints(s["left_order"]), ",".join(legal)]


static func fnv1a32(text: String) -> int:
	var h := 0x811c9dc5
	for b: int in text.to_ascii_buffer():
		h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
	return h


static func state_hash(s: Dictionary) -> int:
	return fnv1a32(canonical(s))


static func _join_ints(values: Array) -> String:
	var parts: PackedStringArray = []
	for v: Variant in values:
		parts.append(str(int(v)))
	return ",".join(parts)
