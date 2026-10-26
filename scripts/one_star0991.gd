extends RefCounted
static var _data:Dictionary={}
static func data()->Dictionary:
	if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/one_star0991.json"))
	return _data.weapons
static func apply(gun:Node3D)->void:
	if "_mechanisms" in gun:
		for cue in ["open","insert","close"]:gun._mechanisms[cue]=preload("res://scripts/audio_bank.gd").for_weapon(gun,cue)
	var id:=str(gun.get_meta("reference_id",""));var row:Dictionary=data().get(id,{})
	if not row.is_empty():gun.damage=float(row.body)/int(row.pellets);gun.set_meta("rarity0991",1);gun.set_meta("rarity_color0991",Color("879099"))
	if "guns" in gun:
		for child in gun.guns:
			child.damage=float(row.body)/int(row.pellets) if not row.is_empty() else child.damage
			child.set_meta("rarity0991",1)
static func hit_damage(target:Node3D,point:Vector3,amount:float,gun:Node3D)->float:
	if not target.has_method("hit_zone_at0991") or target.hit_zone_at0991(point)!="head":return amount
	var row:Dictionary=data().get(str(gun.get_meta("reference_id","")),{})
	return amount*float(row.head)/float(row.body) if not row.is_empty() else amount
