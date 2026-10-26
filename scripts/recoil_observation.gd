extends RefCounted
## Observed output includes wrist motion; provenance is intentionally bundled.
const PATH:="res://assets/data/recoil_observed_067.json"
static var _manifest:Dictionary={}
static func manifest()->Dictionary:
	if _manifest.is_empty():_manifest=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _manifest
static func has_profile(id:String)->bool:return manifest().profiles.has(id)
static func sample(id:String,supported:bool,seconds:float)->Vector2:
	var points:Array=manifest().profiles[id]["two" if supported else "one"].samples
	var t:=maxf(seconds,0.0)
	var last:float=points[-1][0]
	if t>last and str(manifest().profiles[id].get("tail_mode","reflect"))=="hold_last":
		t=last
	if t>last:
		# Bounded recorded-tail continuation is disclosed as original extrapolation.
		var span:=minf(last,2.5)
		var phase:=fposmod(t-last,span*2.0)
		t=last-(phase if phase<span else span*2.0-phase)
	if t<=float(points[0][0]):return Vector2(float(points[0][1]),float(points[0][2]))
	var lo:=0;var hi:=points.size()-1
	while hi-lo>1:
		var mid:=(lo+hi)/2
		if float(points[mid][0])<=t:lo=mid
		else:hi=mid
	var a:Array=points[lo];var b:Array=points[hi]
	var weight:=clampf((t-float(a[0]))/maxf(float(b[0])-float(a[0]),.000001),0,1)
	return Vector2(lerpf(float(a[1]),float(b[1]),weight),lerpf(float(a[2]),float(b[2]),weight))
