extends RefCounted
## Output measurements from Al's local recordings; uncertainty stays in the manifest.
const PATH:="res://assets/data/reference_062.json"
static var _cached:Dictionary={}
static func manifest()->Dictionary:
	if _cached.is_empty():
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:_cached=parsed
	return _cached
static func profile(gun:Node3D)->Dictionary:
	return manifest().get("reticles",{}).get(str(gun.get_meta("reference_id","")),{})
