class_name AshCampaignProgress
extends RefCounted
## Mission-entry checkpoints only: jammer/gate state is rebuilt by the caller.
## Legacy saves are read-only. No read or migration writes any file.
const Store = preload("res://scripts/save_store.gd")
const CAMPAIGN_ID := "ashfall-expanded-v1"
const MISSIONS := ["relay", "turbine", "uplink", "dam_crown", "spillway", "extraction", "complete"]
const LEGACY_MISSIONS := ["relay", "turbine", "uplink", "extraction", "complete"]
const SUFFIXES := ["", ".pending", ".backup", ".backup.pending"]
const MAX_KILLS := 1000000
const MAX_TIME := 31536000.0

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _whole_in_range(value: Variant, maximum: int) -> bool:
	return _finite_number(value) and float(value) >= 0 and float(value) <= maximum and float(value) == floor(float(value))

static func _valid_stats(data: Dictionary) -> bool:
	return _whole_in_range(data.get("kills"), MAX_KILLS) and _finite_number(data.get("play_time")) and float(data.play_time) >= 0 and float(data.play_time) <= MAX_TIME

static func _canonical(data: Dictionary) -> Dictionary:
	return {"mission_id": data.mission_id, "kills": int(data.kills), "play_time": float(data.play_time)}

static func _inspect(path: String, expanded: bool) -> Dictionary:
	if expanded and FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null: return {"state": "blocked"}
		var parser := JSON.new()
		var error := parser.parse(file.get_as_text())
		file.close()
		if error == OK and parser.data is Dictionary:
			if parser.data.get("campaign_id") != CAMPAIGN_ID:
				return {"state": "blocked"}
			if parser.data.get("mission_id") not in MISSIONS:
				return {"state": "blocked"}
	var snapshot := Store._inspect(path)
	if snapshot.state in ["future", "unreadable"]: return {"state": "blocked"}
	if snapshot.state != "valid": return snapshot
	var data: Dictionary = snapshot.data
	var missions: Array = MISSIONS if expanded else LEGACY_MISSIONS
	if expanded and data.get("campaign_id") != CAMPAIGN_ID:
		return {"state": "blocked"}
	if not _whole_in_range(data.chapter, missions.size() - 1) or not _valid_stats(data):
		return {"state": "invalid"}
	var mission: String = missions[int(data.chapter)]
	if expanded and data.get("mission_id") != mission:
		# Unknown missions may belong to a later revision; never downgrade them.
		return {"state": "blocked" if data.get("mission_id") not in MISSIONS else "invalid"}
	return {"state": "valid", "data": {"mission_id": mission, "kills": int(data.kills), "play_time": float(data.play_time)}}

static func _read_family(path: String, expanded: bool, allow_recovery: bool) -> Dictionary:
	var snapshots: Array[Dictionary] = []
	var exists := false
	for suffix in SUFFIXES:
		var item := _inspect(path + suffix, expanded)
		exists = exists or item.state != "missing"
		if item.state == "blocked": return {"state": "blocked", "data": {}, "source": path + suffix}
		snapshots.append(item)
	for index in ([0, 1, 2] if allow_recovery else [0]):
		if snapshots[index].state == "valid":
			return {"state": "valid", "data": snapshots[index].data, "source": path + SUFFIXES[index]}
	return {"state": "invalid" if exists else "missing", "data": {}, "source": ""}

static func read_progress(new_path: String, legacy_path: String, allow_recovery: bool = true) -> Dictionary:
	if new_path.is_empty() or new_path == legacy_path:
		return {"state": "blocked", "data": {}, "source": ""}
	var result := _read_family(new_path, true, allow_recovery)
	if result.state != "missing": return result
	if legacy_path.is_empty(): return result
	result = _read_family(legacy_path, false, allow_recovery)
	if result.state == "valid": result.state = "migrated"
	return result

static func _known_schema(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary: return false
	var data: Dictionary = parser.data
	return _finite_number(data.get("version")) and float(data.version) == 1.0 and data.get("campaign_id") == CAMPAIGN_ID and data.get("mission_id") in MISSIONS

static func _quarantine_verified(path: String) -> Error:
	# Single writer, matching SaveStore's contract. Existing quarantines are never
	# reused. Copy and verify exact bytes before removing the invalid artifact.
	var source := FileAccess.open(path, FileAccess.READ)
	if source == null: return ERR_FILE_CANT_READ
	var bytes := source.get_buffer(source.get_length())
	source.close()
	var source_hash := FileAccess.get_sha256(path)
	var target := path + ".quarantine." + str(Time.get_unix_time_from_system()).replace(".", "-") + "-" + str(Time.get_ticks_usec())
	while FileAccess.file_exists(target): target += "-next"
	var output := FileAccess.open(target, FileAccess.WRITE)
	if output == null: return FileAccess.get_open_error()
	output.store_buffer(bytes)
	output.flush()
	var error := output.get_error()
	output.close()
	if error != OK: return error
	if source_hash.is_empty() or FileAccess.get_sha256(target) != source_hash or FileAccess.get_sha256(path) != source_hash:
		return ERR_FILE_CORRUPT
	return OK

static func _prepare_known_recovery(new_path: String) -> Error:
	var invalid_paths: Array[String] = []
	var retained_path := ""
	var retained_hash := ""
	# Complete the protection scan before any mutation, even if an earlier
	# artifact is invalid and a later artifact has an unknown/future identity.
	for suffix in SUFFIXES:
		var path: String = new_path + suffix
		var snapshot := _inspect(path, true)
		if snapshot.state == "blocked": return ERR_UNAVAILABLE
		if snapshot.state == "valid" and suffix != ".backup.pending" and retained_path.is_empty():
			retained_path = path
			retained_hash = FileAccess.get_sha256(path)
		if snapshot.state == "invalid" and _known_schema(path): invalid_paths.append(path)
	if invalid_paths.is_empty(): return OK
	# Without a readable semantic checkpoint, preserve all evidence and fail.
	if retained_path.is_empty() or retained_hash.is_empty(): return ERR_INVALID_DATA
	for path in invalid_paths:
		var error := _quarantine_verified(path)
		if error != OK: return error
		if _inspect(retained_path, true).state != "valid" or FileAccess.get_sha256(retained_path) != retained_hash:
			return ERR_FILE_CORRUPT
		error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if error != OK: return error
	# A crash before/during removal still leaves the semantic snapshot in its
	# original recovery slot. The writer now sees only semantic valid snapshots.
	return OK

static func write_progress(new_path: String, data: Dictionary) -> Error:
	if new_path.is_empty() or new_path.get_file().to_lower() == "campaign.json": return ERR_INVALID_PARAMETER
	if data.get("mission_id") not in MISSIONS or not _valid_stats(data): return ERR_INVALID_DATA
	var preparation := _prepare_known_recovery(new_path)
	if preparation != OK: return preparation
	var canonical := _canonical(data)
	canonical["version"] = 1
	canonical["campaign_id"] = CAMPAIGN_ID
	canonical["chapter"] = MISSIONS.find(canonical.mission_id)
	return Store.write_save(new_path, canonical)

