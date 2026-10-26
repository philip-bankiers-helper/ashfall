extends SceneTree
const Store = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0
var directory := ""
const FIRST := {"version": 1, "chapter": 1, "kills": 4, "play_time": 42.25}
const SECOND := {"version": 1, "chapter": 2, "kills": 10, "play_time": 83.5}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func raw(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(content)
	file.flush()
	file.close()

func same_save(actual: Dictionary, expected: Dictionary) -> bool:
	# JSON decodes numeric values as floats; compare supported numeric semantics.
	for key in ["version", "chapter", "kills", "play_time"]:
		if not actual.has(key) or float(actual[key]) != float(expected[key]):
			return false
	return true

func run() -> void:
	directory = ProjectSettings.globalize_path("res://../reports/save-store-tests-" + str(Time.get_ticks_usec()))
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "isolated workspace test directory created")
	var path := directory.path_join("campaign.json")
	check(Store.write_save(path, FIRST) == OK, "first save commits successfully")
	check(same_save(Store.read_save(path), FIRST), "strict read round-trips finite numeric payload")
	check(not FileAccess.file_exists(path + ".pending"), "committed save consumes pending file")
	check(Store.write_save(path, SECOND) == OK, "replacement save commits successfully")
	check(same_save(Store.read_save(path), SECOND) and same_save(Store.read_save(path + ".backup"), FIRST), "previous verified primary preserved as backup")
	raw(path, "{broken")
	check(Store.read_save(path).is_empty(), "strict corrupt-primary read refuses recovery")
	check(same_save(Store.read_save(path, true), FIRST), "explicit recovery accepts valid backup")
	raw(path + ".pending", JSON.stringify(SECOND))
	check(same_save(Store.read_save(path, true), SECOND), "valid pending preferred over older backup")
	DirAccess.remove_absolute(path)
	check(Store.read_save(path).is_empty() and same_save(Store.read_save(path, true), SECOND), "missing primary requires explicit recovery")
	check(Store.write_save(path, FIRST) == OK and same_save(Store.read_save(path + ".backup"), SECOND), "sole pending checkpoint preserved before rewriting")
	raw(path, JSON.stringify({"version": 2, "new_schema": true}))
	var future_text := FileAccess.get_file_as_string(path)
	check(Store.read_save(path, true).is_empty(), "future primary version never downgrades to backup")
	check(Store.write_save(path, FIRST) != OK and FileAccess.get_file_as_string(path) == future_text, "writer refuses and preserves future primary version")
	raw(path, "broken")
	raw(path + ".pending", JSON.stringify({"version": 2}))
	check(Store.read_save(path, true).is_empty(), "future pending prevents recovery downgrade")
	check(Store.write_save(path, FIRST) != OK, "writer refuses future pending version")
	var future_backup := directory.path_join("future-backup.json")
	raw(future_backup + ".pending", JSON.stringify(FIRST))
	raw(future_backup + ".backup", JSON.stringify({"version": 2}))
	check(Store.read_save(future_backup, true).is_empty(), "future backup blocks downgrade even when older pending is valid")
	var primary_wins := directory.path_join("primary-wins.json")
	raw(primary_wins, JSON.stringify(FIRST))
	raw(primary_wins + ".pending", JSON.stringify(SECOND))
	check(same_save(Store.read_save(primary_wins, true), FIRST), "valid primary always wins over pending recovery")
	var corrupt_pending := directory.path_join("corrupt-pending.json")
	raw(corrupt_pending, "broken")
	raw(corrupt_pending + ".pending", "truncated")
	raw(corrupt_pending + ".backup", JSON.stringify(FIRST))
	check(same_save(Store.read_save(corrupt_pending, true), FIRST), "corrupt pending skipped for valid backup")
	var malformed := directory.path_join("malformed.json")
	raw(malformed, JSON.stringify({"version": 1, "chapter": "2", "kills": 0, "play_time": 1}))
	check(Store.read_save(malformed).is_empty(), "read rejects malformed numeric fields")
	var invalid_path := directory.path_join("invalid.json")
	for bad in [
		{"version": 1, "chapter": "1", "kills": 0, "play_time": 0},
		{"version": 1, "chapter": 1, "kills": true, "play_time": 0},
		{"version": 1, "chapter": 1, "kills": 0, "play_time": INF},
		{"version": 1, "chapter": NAN, "kills": 0, "play_time": 0},
		{"version": 1, "chapter": 1, "kills": 0},
		{"version": true, "chapter": 1, "kills": 0, "play_time": 0}
	]:
		check(Store.write_save(invalid_path, bad) == ERR_INVALID_DATA, "invalid/nonfinite/missing numeric field rejected before write")
	check(not FileAccess.file_exists(invalid_path), "invalid writes create no primary")
	var failure_path := directory.path_join("failure.json")
	check(Store.write_save(failure_path, FIRST) == OK, "write-failure fixture initial save valid")
	DirAccess.make_dir_absolute(failure_path + ".pending")
	check(Store.write_save(failure_path, SECOND) != OK, "pending path directory produces controlled write failure")
	check(same_save(Store.read_save(failure_path), FIRST) and same_save(Store.read_save(failure_path + ".backup"), FIRST), "write failure preserves previous good primary and backup")
	var backup_only := directory.path_join("backup-only.json")
	raw(backup_only + ".backup", JSON.stringify(FIRST))
	DirAccess.make_dir_absolute(backup_only + ".pending")
	check(Store.write_save(backup_only, SECOND) != OK and same_save(Store.read_save(backup_only, true), FIRST), "failed write preserves sole valid backup")
	var backup_failure := directory.path_join("backup-failure.json")
	Store.write_save(backup_failure, FIRST)
	DirAccess.make_dir_absolute(backup_failure + ".backup.pending")
	check(Store.write_save(backup_failure, SECOND) != OK and same_save(Store.read_save(backup_failure), FIRST), "backup staging failure leaves primary unchanged")
	var clamp_path := directory.path_join("clamp.json")
	var needs_clamp := {"version": 1, "chapter": -2.5, "kills": -3, "play_time": 1e20}
	check(Store.write_save(clamp_path, needs_clamp) == OK and same_save(Store.read_save(clamp_path), needs_clamp), "finite out-of-range values retained for main clamping")
	print("SAVE_TEST_DIRECTORY ", directory)
	print("SAVE_STORE_TESTS checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
