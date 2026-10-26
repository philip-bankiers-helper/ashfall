extends RefCounted
## These inspected P90/DT11 wood and metal surfaces were exported as BLEND.
## Preserve textures, PBR and sidedness, but put solid gun geometry in the depth pass.
static var _cache:Dictionary={}
static func mesh(source:Mesh)->Mesh:
	if _cache.has(source):return _cache[source]
	var result:=source.duplicate() as ArrayMesh
	for surface in result.get_surface_count():
		var material:=source.surface_get_material(surface) as StandardMaterial3D
		if material==null:continue
		var solid:=material.duplicate() as StandardMaterial3D
		solid.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
		solid.albedo_color.a=1.0
		result.surface_set_material(surface,solid)
	_cache[source]=result
	return result
