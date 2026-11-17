class_name SafeArea
extends RefCounted
## Top / bottom safe-area insets (notch, camera hole, Dynamic Island, gesture
## bar) in canvas pixels (UI_UX_DESIGN_SYSTEM §8). Desktop: a minimum margin.
## Tests and screenshots: -- --safe-insets=<top>,<bottom> (canvas px).

const MIN_TOP := 24
const MIN_BOTTOM := 16

static var override := Vector2(-1, -1)


static func insets(viewport_size: Vector2) -> Vector2:
	if override.x >= 0.0:
		return override
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--safe-insets="):
			var parts := arg.trim_prefix("--safe-insets=").split(",")
			if parts.size() == 2:
				return Vector2(float(parts[0]), float(parts[1]))
	var top := float(MIN_TOP)
	var bottom := float(MIN_BOTTOM)
	if OS.get_name() in ["Android", "iOS"] and DisplayServer.get_name() != "headless":
		var screen := Vector2(DisplayServer.screen_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if screen.y > 0 and safe.size.y > 0:
			var k := viewport_size.y / screen.y
			top = maxf(top, safe.position.y * k)
			bottom = maxf(bottom, (screen.y - safe.end.y) * k)
	return Vector2(top, bottom)
