extends RefCounted
const IDS := ["valley","range","cyber_bird"]
const DATA := {
	"valley":{"title":"RELAY VALLEY","subtitle":"Industrial ridges · long sightlines","min":Vector2(-100,-130),"max":Vector2(100,70),"origin":Vector3.ZERO},
	"range":{"title":"SANDBOX RANGE","subtitle":"Practice arenas · weapons and revival","min":Vector2(-50,-50),"max":Vector2(50,50),"origin":Vector3(0,0,600)},
	"cyber_bird":{"title":"CYBER BIRD","subtitle":"Avian megacity · 80 buildings · open windows","min":Vector2(-400,-400),"max":Vector2(400,400),"origin":Vector3(0,0,2400)}}
static func info(id:String)->Dictionary:return DATA.get(id,DATA.range)
static func image(id:String)->Texture2D:
	var path ="res://assets/maps1000/%s.png"%id
	return load(path) if ResourceLoader.exists(path) else null
static func uv(id:String,position:Vector3)->Vector2:
	var row =info(id);var local:Vector3=position-row.origin
	return (Vector2(local.x,local.z)-row.min)/(row.max-row.min)
