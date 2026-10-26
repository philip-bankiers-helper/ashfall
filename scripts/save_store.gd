class_name AshSaveStore
extends RefCounted
## Single-writer checkpoint store. Windows rename replacement is NOT atomic.
## A verified backup survives the remove/rename gap; recovery is opt-in.
const PENDING_SUFFIX := ".pending"
const BACKUP_SUFFIX := ".backup"
const BACKUP_PENDING_SUFFIX := ".backup.pending"

static func _numeric_finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _valid(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not _numeric_finite(data.get("version")) or float(data.version) != 1.0:
		return false
	for key in ["chapter", "kills", "play_time"]:
		if not data.has(key) or not _numeric_finite(data[key]):
			return false
	return true

static func _inspect(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"state": "missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"state": "unreadable"}
	var content := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(content) != OK:
		return {"state": "invalid"}
	var data: Variant = parser.data
	# Even an unfamiliar future schema must never be replaced with an older one.
	if data is Dictionary and _numeric_finite(data.get("version")) and float(data.version) > 1.0:
		return {"state": "future"}
	if not _valid(data):
		return {"state": "invalid"}
	return {"state": "valid", "data": data, "text": content}

static func read_save(path: String, allow_recovery: bool = false) -> Dictionary:
	if path.is_empty():
		return {}
	var primary := _inspect(path)
	if primary.state == "valid":
		return primary.data
	if not allow_recovery or primary.state == "future" or primary.state == "unreadable":
		return {}
	# No mutation on read. Caller explicitly chooses whether to use recovery data.
	var candidates: Array[Dictionary] = []
	for suffix in [PENDING_SUFFIX, BACKUP_SUFFIX, BACKUP_PENDING_SUFFIX]:
		var candidate := _inspect(path + suffix)
		if candidate.state == "future":
			return {}
		candidates.append(candidate)
	for candidate in candidates.slice(0, 2):
		if candidate.state == "valid":
			return candidate.data
	return {}

static func _write_verified(path: String, content: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	var reread := _inspect(path)
	if reread.state != "valid" or reread.text != content:
		return ERR_FILE_CORRUPT
	return OK

static func write_save(path: String, data: Dictionary) -> Error:
	if path.is_empty() or not _valid(data):
		return ERR_INVALID_DATA
	var absolute := ProjectSettings.globalize_path(path)
	var snapshots: Array[Dictionary] = []
	for suffix in ["", PENDING_SUFFIX, BACKUP_SUFFIX, BACKUP_PENDING_SUFFIX]:
		var snapshot := _inspect(absolute + suffix)
		if snapshot.state == "future":
			return ERR_UNAVAILABLE
		if snapshot.state == "unreadable":
			return ERR_FILE_CANT_READ
		snapshots.append(snapshot)
	# Preserve a verified prior save before touching either the primary or a
	# pending file that might be the only intact record after an earlier crash.
	var previous_text := ""
	for snapshot in snapshots:
		if snapshot.state == "valid":
			previous_text = snapshot.text
			break
	# Do not rewrite the only good backup just to copy it onto itself.
	var backup_already_matches: bool = snapshots[2].state == "valid" and snapshots[2].text == previous_text
	if not previous_text.is_empty() and not backup_already_matches:
		var backup_error := _write_verified(absolute + BACKUP_PENDING_SUFFIX, previous_text)
		if backup_error != OK:
			return backup_error
		backup_error = DirAccess.rename_absolute(absolute + BACKUP_PENDING_SUFFIX, absolute + BACKUP_SUFFIX)
		if backup_error != OK:
			return backup_error
		var backup := _inspect(absolute + BACKUP_SUFFIX)
		if backup.state != "valid" or backup.text != previous_text:
			return ERR_FILE_CORRUPT
	var content := JSON.stringify(data, "", true, true)
	var pending_error := _write_verified(absolute + PENDING_SUFFIX, content)
	if pending_error != OK:
		return pending_error
	# Godot/Windows may remove an existing destination before rename. A crash
	# here can leave primary missing; verified pending/backup enable recovery.
	var replace_error := DirAccess.rename_absolute(absolute + PENDING_SUFFIX, absolute)
	if replace_error != OK:
		return replace_error
	var committed := _inspect(absolute)
	if committed.state != "valid" or committed.text != content:
		return ERR_FILE_CORRUPT
	return OK
