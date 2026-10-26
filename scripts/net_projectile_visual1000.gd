extends "res://scripts/explosive_projectile.gd"
## Only the server decides impact/fuse timing. Replicas retain the original art and audio.
func _physics_process(_delta:float)->void:
	if finished:return
	if kind=="frag":_advance_warning(age)
	if zone_active and zone_visual!=null:
		var lifetime:float=float(tuning.get("zone_lifetime",10.0))
		zone_visual.scale=Vector3.ONE*maxf(.001,float(tuning.get("zone_initial_radius",15.0))*(1-zone_age/lifetime))
