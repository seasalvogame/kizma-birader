class_name TestCase
extends RefCounted
## Base class of the headless tests (tests/test_runner.tscn).

var tree: SceneTree
## Engine errors this test triggers on purpose (they do not fail it).
var expected_errors := 0
var _failures: PackedStringArray = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func get_failures() -> PackedStringArray:
	return _failures


func reset() -> void:
	_failures = []


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not deep_equal(actual, expected):
		fail("%sexpected %s, got %s" % ["" if message == "" else message + ": ", str(expected), str(actual)])


## Structural equality where JSON numbers (float) equal GDScript ints.
static func deep_equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	var num := [TYPE_INT, TYPE_FLOAT]
	if ta in num and tb in num:
		return is_equal_approx(float(a), float(b))
	if ta == TYPE_DICTIONARY and tb == TYPE_DICTIONARY:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for k: Variant in da:
			if not db.has(k) or not deep_equal(da[k], db[k]):
				return false
		return true
	if ta in [TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_STRING_ARRAY] and tb in [TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_STRING_ARRAY]:
		var aa: Array = Array(a)
		var ab: Array = Array(b)
		if aa.size() != ab.size():
			return false
		for i in aa.size():
			if not deep_equal(aa[i], ab[i]):
				return false
		return true
	if ta in [TYPE_STRING, TYPE_STRING_NAME] and tb in [TYPE_STRING, TYPE_STRING_NAME]:
		return String(a) == String(b)
	return ta == tb and a == b


## Absolute path of a file in the repository outside the Godot project (tests only).
static func repo_path(relative: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(relative).simplify_path()
