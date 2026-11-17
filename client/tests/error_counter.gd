class_name ErrorCounter
extends Logger
## Counts engine and script errors while tests run, so a test that triggers
## a SCRIPT ERROR (or push_error) fails instead of passing silently.

var count := 0
var messages: PackedStringArray = []
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	count += 1
	messages.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func take() -> PackedStringArray:
	_mutex.lock()
	var out := messages
	messages = []
	count = 0
	_mutex.unlock()
	return out
