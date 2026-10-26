extends RefCounted
## Gemini's scope-only GLB. The accepted rifle, magazine and bolt remain unchanged.
static func build(scope:Node3D)->Node3D:
	var path:="res://assets/models/gemini_scope098/spr_scope_light.glb" if preload("res://scripts/asset_quality.gd").lightweight() else "res://assets/models/gemini_scope098/spr_scope_pcvr.glb"
	var packed:PackedScene=load(path)
	var housing:Node3D=packed.instantiate();housing.name="GeminiCompactSPRScope098"
	scope.add_child(housing)
	for part in housing.find_children("*","VisualInstance3D",true,false):part.layers=1<<18
	var marker:Node3D=housing.find_child("ReticleViewPlane",true,false)
	if marker!=null:marker.hide() # The existing live per-eye lens owns this aperture.
	return housing
