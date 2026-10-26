extends RefCounted
## Explicit, reviewed action routing. Unknown cues retain the authored bank.
const PATH:="res://assets/audio/reference097/manifest.json"
static var _manifest:Dictionary={}
static var _cache:Dictionary={}
static func enabled()->bool:return not OS.get_cmdline_user_args().has("--authored-audio")
static func manifest()->Dictionary:
	if _manifest.is_empty():_manifest=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _manifest
static func variant(paths:Array,index:int,loop:bool=false)->AudioStreamWAV:
	if paths.is_empty():return null
	var path:String=paths[posmod(index,paths.size())]
	if not _cache.has(path):
		var sound:AudioStreamWAV=AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else load(path) as AudioStreamWAV
		if sound==null:return null
		if loop:sound.loop_mode=AudioStreamWAV.LOOP_FORWARD;sound.loop_begin=0;sound.loop_end=sound.data.size()/2
		_cache[path]=sound
	return _cache[path]
static func generic(kind:String,index:int)->AudioStreamWAV:
	if not enabled():return null
	return variant(manifest().generic.get(kind,[]),index,kind=="katana_shield")
static func weapon(kind:String,owner_gun:Node3D,index:int)->AudioStreamWAV:
	if not enabled():return null
	var id:=str(owner_gun.get_meta("reference_id",""))
	if id=="uzi":id="uzis"
	return variant(manifest().weapons.get(id,{}).get(kind,[]),index)
static func action(kind:String,subject:String,index:int)->AudioStreamWAV:
	if not enabled():return null
	return variant(manifest().actions.get(subject,{}).get(kind,[]),index)
