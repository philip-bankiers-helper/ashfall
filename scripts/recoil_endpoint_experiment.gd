extends RefCounted
## Reversible071 best-fit experiment. Inferred spatial order is not measured shot order.
const PATH:="res://assets/data/recoil_endpoint_experiment_071.json"
static var _data:Dictionary={}
static func manifest()->Dictionary:
 if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 return _data
static func enabled(id:String)->bool:
 return id in ["ump","p90","akm","rfb","uzis"] and bool(ProjectSettings.get_setting("ashfall/recoil_endpoint_experiments",true)) and bool(manifest().enabled) and manifest().profiles.has(id)
static func sample(id:String,held:bool,index:int)->Vector2:
 var points:Array=manifest().profiles[id]["two" if held else "one"].samples_pitch_yaw_deg
 var p:Array=points[clampi(index,0,points.size()-1)]
 return Vector2(float(p[0]),float(p[1]))
static func keep_yaw(id:String)->bool:
 return bool(manifest().profiles[id].one.get("retain_baseline_yaw",false))

