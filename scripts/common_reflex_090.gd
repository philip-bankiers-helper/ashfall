extends RefCounted
## One detailed nonmagnifying optic. Existing sniper scopes retain their magnification.
static func install(gun:Node3D,index:int)->void:
	if index not in [3,9,17,18,23]:return # Explicit optics only; preserve original ring / iron sights.
	if "guns" in gun:
		for child in gun.guns:install(child,9 if gun.shotgun_mode else 10)
		return
	for key in ["reflex_sight","ring_sight"]:
		if gun.has_meta(key):gun.get_meta(key).hide()
	for part in [gun.sight_rear,gun.sight_front]:
		if is_instance_valid(part):part.hide()
	var height:float=gun.get_meta("download_reflex_height_077",.139 if index==9 else .13)
	var physical_scale:float=gun.model.global_basis.get_scale().x
	if index==17:height-=.018/physical_scale
	elif index==23:height-=.006/physical_scale
	var optic_scale:=.75 if index in [17,18] else 1.0
	# Keep the rail foot fixed while reducing the complete optic around its window centre.
	var foot_depth:float=preload("res://scripts/authored_reflex_sight.gd").WINDOW_SIZE.y*.5+.023
	height-=foot_depth*(1.0-optic_scale)/physical_scale
	var sight:Node3D=preload("res://scripts/authored_reflex_sight.gd").new();gun.model.add_child(sight)
	sight.setup("holographic",Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*optic_scale/physical_scale),Vector3(0,height,-.10)),gun)
	gun.set_meta("reflex_sight",sight)
