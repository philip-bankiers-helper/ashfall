extends RefCounted
## One-time yellow finishes; old box guides remain API nodes with no visible geometry.
static var _yellow:StandardMaterial3D
static func yellow()->StandardMaterial3D:
	if _yellow==null:
		_yellow=StandardMaterial3D.new();_yellow.albedo_color=Color("ffd63d");_yellow.emission_enabled=true;_yellow.emission=Color("e5ac22");_yellow.emission_energy_multiplier=.45;_yellow.metallic=.15;_yellow.roughness=.5
	return _yellow
static func apply(w:Node3D)->void:
	if w.guide!=null:w.guide.mesh=null
	w._reload_finish=yellow()
	for arrow in [w.insertion_arrow,w.charging_arrow,w.get("reload_arrow"),w.get("rocket_arrow"),w.get("swipe_arrow"),w.get("insert_guide")]:
		if arrow==null or arrow.has_meta("yellow_reload_089"):continue
		for part in arrow.find_children("*","MeshInstance3D",true,false):part.material_override=yellow()
		arrow.set_meta("yellow_reload_089",true)
	var latch=w.get("latch_guide")
	if latch is MeshInstance3D:latch.material_override=yellow()
	w._reload_finish=yellow()
	if w.hip_source!=null:
		for child in w.hip_source.get_children():
			if child is MeshInstance3D and child.mesh is CylinderMesh:child.hide()
	w.set_meta("yellow_reload_089",true)
