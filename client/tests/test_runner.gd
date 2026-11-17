extends Node
## Headless test runner:
##   godot_console --headless --path client res://tests/test_runner.tscn [-- --only=<file part>] [--online --game-url=<url>]
## Runs every test_* method of the scripts in tests/unit and tests/scene.
## Exit code 0 = all passed.

const DIRS: Array[String] = ["res://tests/unit", "res://tests/scene"]


func _ready() -> void:
	# Let the tree finish setting up (tests add nodes to the root).
	await get_tree().process_frame
	var only := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	# Online tests need a game server: only with -- --online [--game-url=...]
	var dirs := DIRS.duplicate()
	if OS.get_cmdline_user_args().has("--online"):
		dirs = ["res://tests/online"]
	else:
		OnlineConfig.force_offline = true   # never create cloud accounts from offline tests
	_isolate()
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var started := Time.get_ticks_msec()
	var total := 0
	var failed := 0
	for dir: String in dirs:
		var files := DirAccess.get_files_at(dir)
		files.sort()
		for file: String in files:
			if not file.ends_with(".gd") or (only != "" and not file.contains(only)):
				continue
			var script: GDScript = load(dir.path_join(file))
			if script == null or not script.can_instantiate():
				total += 1
				failed += 1
				print("FAIL  %s (script does not compile)" % file)
				for e: String in errors.take():
					print("      " + e)
				continue
			errors.take()
			var methods: Array[String] = []
			for m: Dictionary in script.get_script_method_list():
				var method_name := String(m["name"])
				if method_name.begins_with("test_") and not methods.has(method_name):
					methods.append(method_name)
			for method_name: String in methods:
				var test: TestCase = script.new()
				test.tree = get_tree()
				test.reset()
				test.before_each()
				await test.call(method_name)
				test.after_each()
				total += 1
				var failures := test.get_failures()
				# Any engine / script error during the test fails it (unless the test expected it).
				for e: String in errors.take():
					if test.expected_errors > 0:
						test.expected_errors -= 1
					else:
						failures.append("engine error: " + e)
				if failures.is_empty():
					print("PASS  %s.%s" % [file.get_basename(), method_name])
				else:
					failed += 1
					print("FAIL  %s.%s" % [file.get_basename(), method_name])
					for f: String in failures.slice(0, 8):
						print("      " + f)
					if failures.size() > 8:
						print("      … %d more" % (failures.size() - 8))
	print("%d test(s), %d failed, %.1f s" % [total, failed, (Time.get_ticks_msec() - started) / 1000.0])
	OS.remove_logger(errors)
	get_tree().quit(1 if failed > 0 else 0)


## Tests never touch the player's own files: settings, session and profile
## cache go to user://test_run/ (cleared at the start of every run).
func _isolate() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_run")
	for f: String in DirAccess.get_files_at("user://test_run"):
		DirAccess.remove_absolute("user://test_run/" + f)
	if not Settings.path.begins_with("user://test"):
		Settings.path = "user://test_run/settings.cfg"
		Settings.load_settings()
	Online.session.path = "user://test_run/online_session.cfg"
	Online.session._clear()
	Online.profile.cache_path = "user://test_run/online_profile_cache.json"
	Online.profile.reset()

