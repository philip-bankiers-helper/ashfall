extends RefCounted
## All match-affecting settings live here. Personal VR preferences never enter this schema.
const DEFAULTS := {"map":"range","mode":"revive","max_players":8,"teams":2,"friendly_fire":false,"damage":1.0,"npc_damage":1.0,"build_damage":1.0,"headshots":1.0,"walk":1.0,"run":1.0,"flight":1.0,"fling":1.0,"stamina":1.0,"starting_health":100,"starting_shield":100,"starting_builds":999,"builds":true,"infinite_builds":false,"infinite_ammo":false,"loot":true,"catalog":false,"respawn_delay":5.0,"protection":3.0,"retain_inventory":true,"downed_seconds":60.0,"time_limit":600,"score_limit":25,"rounds":1,"late_join":true,"spectators":true,"locked":false,"loadout":"standard"}
const LIMITS := {"max_players":[2,8],"teams":[0,8],"damage":[0.0,4.0],"npc_damage":[0.0,4.0],"build_damage":[0.0,4.0],"headshots":[0.0,3.0],"walk":[.25,3.0],"run":[.25,3.0],"flight":[.25,3.0],"fling":[0.0,5.0],"stamina":[.25,4.0],"starting_health":[1,100],"starting_shield":[0,100],"starting_builds":[0,100000],"respawn_delay":[1.0,30.0],"protection":[0.0,10.0],"downed_seconds":[10.0,180.0],"time_limit":[0,3600],"score_limit":[0,500],"rounds":[1,10]}
const CHOICES := {"map":["valley","range","cyber_bird"],"mode":["revive","respawn"],"loadout":["standard","pistols","swords"]}
static func validate(input:Dictionary)->Dictionary:
	var result =DEFAULTS.duplicate(true)
	for key in DEFAULTS:
		if not input.has(key):continue
		var v=input[key]
		if CHOICES.has(key):
			if v is String and v in CHOICES[key]:result[key]=v
		elif DEFAULTS[key] is bool:
			if v is bool:result[key]=v
		elif LIMITS.has(key) and (v is int or v is float) and is_finite(float(v)):
			result[key]=clampi(int(v),int(LIMITS[key][0]),int(LIMITS[key][1])) if DEFAULTS[key] is int else clampf(float(v),float(LIMITS[key][0]),float(LIMITS[key][1]))
	return result
static func preset(id:String)->Dictionary:
	var r =DEFAULTS.duplicate(true)
	match id:
		"practice":r.merge({"mode":"respawn","damage":0.0,"catalog":true,"infinite_ammo":true,"infinite_builds":true,"score_limit":0,"time_limit":0},true)
		"team_respawn":r.mode="respawn"
		"free_for_all":r.mode="respawn";r.teams=0
	return r
static func starting_catalog(r:Dictionary)->Array:
	match str(r.loadout):
		"pistols":return [2,7,19]
		"swords":return [14,15,16]
	return [0,2,9]
