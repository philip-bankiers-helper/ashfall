extends RefCounted
static func _clear_visuals(parent:Node3D)->void:
	for child in parent.get_children():
		if child is Node3D:child.hide()
static func _copy(asset:Node3D,name:String,parent:Node3D)->MeshInstance3D:
	var original:=asset.find_child(name,true,false) as MeshInstance3D
	var part:=MeshInstance3D.new();part.name="Downloaded"+name+"085";part.mesh=original.mesh;parent.add_child(part);return part
static func m60(w:Node3D)->void:
	var asset:Node3D=load("res://assets/models/download_m60/model.glb").instantiate()
	var keep:Array=[w.cover,w.belt_box,w.belt,w.charging_handle,w.feed_socket,w.muzzle_flash,w.ammo_label]
	for child in w.model.get_children():
		if child is Node3D and child not in keep:child.hide()
	_copy(asset,"Body",w.model)
	_clear_visuals(w.cover);_copy(asset,"Cover",w.cover)
	var box:=asset.find_child("Magazine",true,false) as MeshInstance3D
	w.belt_box.mesh=box.mesh;w.belt_box.material_override=null;_clear_visuals(w.belt_box)
	for holder in [w.offered_box,w.held_box]:
		_clear_visuals(holder);_copy(asset,"Magazine",holder)
	_clear_visuals(w.belt)
	var linked:=_copy(asset,"Belt",w.belt);linked.rotation.y=PI*.5;linked.position=Vector3(-.08,.09,-.11)-linked.basis*linked.mesh.get_aabb().get_center()
	var handle:=asset.find_child("Bolt",true,false) as MeshInstance3D
	# The charging node remains the actual contact/moving part, not a static decoration.
	var mesh:=ArrayMesh.new();var tool:=SurfaceTool.new()
	for surface in handle.mesh.get_surface_count():
		tool.clear();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.append_from(handle.mesh,surface,Transform3D(Basis.IDENTITY,-handle.mesh.get_aabb().get_center()));tool.set_material(handle.mesh.surface_get_material(surface));tool.commit(mesh)
	w.charging_handle.mesh=mesh;w.charging_handle.material_override=null;_clear_visuals(w.charging_handle)
	w.set_meta("downloaded_model_077","m60");w.set_meta("downloaded_heavy_085",true);asset.free()
static func rocket(w:Node3D)->void:
	var asset:Node3D=load("res://assets/models/download_smaw/model.glb").instantiate()
	_clear_visuals(w.payload);_copy(asset,"Body",w.payload)
	w.set_meta("downloaded_model_077","smaw");w.set_meta("downloaded_heavy_085",true);asset.free()
