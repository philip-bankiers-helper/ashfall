extends RefCounted
## Dated numbers and original uncertain timing are carried with their evidence.
const PATH:="res://assets/data/one_star_050.json"
static func manifest()->Dictionary:
	var value=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return value if value is Dictionary else {}
static func profile(index:int)->Dictionary:
	for p in manifest().get("profiles",[]):
		if int(p.index)==index:return p
	return {}
static func tuning()->Dictionary:
	var values:Dictionary=manifest().get("original_tuning",{}).duplicate(true)
	if FileAccess.file_exists("user://explosive-tuning-overrides.json"):
		var custom=JSON.parse_string(FileAccess.get_file_as_string("user://explosive-tuning-overrides.json"))
		if custom is Dictionary:
			for key in values.keys():
				var value=custom.get(key,null)
				if (value is int or value is float) and is_finite(float(value)):values[key]=clampf(float(value),.05,240.0 if key=="rocket_speed" else 60.0)
	return values
static func apply(gun:Node3D,index:int,fill:bool=true)->void:
	var data:=profile(index)
	if data.is_empty():return
	gun.set_meta("one_star_profile",data)
	gun.set_meta("reference_id",str(data.id))
	var rate:float=float(data.rounds_per_second)
	if FileAccess.file_exists("user://weapon-timing-overrides.json"):
		var custom=JSON.parse_string(FileAccess.get_file_as_string("user://weapon-timing-overrides.json"))
		if custom is Dictionary:
			var candidate=custom.get(data.id,rate)
			if candidate is float or candidate is int:
				if is_finite(float(candidate)):rate=clampf(float(candidate),.2,40.0)
	if str(data.id)=="matadors":rate*=1.2 #086 +20% firing rate, not 20% shorter interval
	gun.fire_interval=1.0/rate
	if data.id=="mk18":gun.post_burst_interval=float(data.get("post_burst_seconds",.24))
	var capacity:int=int(data.magazine_per_hand)
	# 071 inventory: each grenade ID is one physical payload. Frag pairs are
	# represented by two IDs in one slot; zone grenades always occupy one slot.
	if str(data.id) in ["frag","zone"]:capacity=1
	if gun.has_method("get_reticle_entries"):
		for child in gun.guns:
			child.set_meta("reference_id",str(data.id))
			child.magazine_size=capacity;child.fire_interval=1.0/rate
			if fill:child.ammo=capacity
		gun.magazine_size=capacity*2;gun._sync_pair()
	else:
		gun.magazine_size=capacity
		if fill:
			gun.ammo=capacity
			if data.id=="m60":gun.seated=capacity;gun.maximum_rps=rate
	gun.update_ammo_display()
