extends RefCounted
const FOLDER="res://assets/models/download_dt11/"
static func narrow_cylinder(part:MeshInstance3D,factor:float)->void:
	if part.mesh is CylinderMesh:
		var shape:=part.mesh.duplicate() as CylinderMesh;shape.top_radius*=factor;shape.bottom_radius*=factor;part.mesh=shape
static func build(w:Node3D)->void:
	var variant:String=preload("res://scripts/model_variants.gd").choose("dt11")
	var folder:="res://assets/models/download_"+variant+"/"
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"asset-provenance.json"))
	var asset:Node3D=load(folder+"model.glb").instantiate()
	var body:=asset.find_child("Body",true,false) as MeshInstance3D
	var barrels:=asset.find_child("Barrels",true,false) as MeshInstance3D
	for part in w.model.get_children():
		if part is Node3D and part not in [w.hinge,w.open_contact_cue,w.chamber_contact_cue,w.close_contact_cue,w.insert_guide,w.shell_offer,w.ammo_label,w.muzzle_flash,w.swipe_arrow]:part.hide()
	var retained:Node3D=w.hinge.get_node("ContouredForeEnd063")
	var retained_nodes:Array=[retained,w.fore_end_marker,w.seated_shells,w.latch_guide]
	retained_nodes.append_array(w.chamber_markers);retained_nodes.append_array(w.chamber_live);retained_nodes.append_array(w.chamber_spent)
	for part in w.hinge.get_children():
		if part is Node3D and part not in retained_nodes and not str(part.name).begins_with("OpenChamberMouth"):part.hide()
	var shell:=MeshInstance3D.new();shell.name="DownloadedDT11Body081";shell.mesh=preload("res://scripts/solid_import_085.gd").mesh(body.mesh);w.model.add_child(shell)
	var moving:=MeshInstance3D.new();moving.name="DownloadedDT11Barrels081";moving.mesh=preload("res://scripts/solid_import_085.gd").mesh(barrels.mesh);w.hinge.add_child(moving)
	var factor:float=data.get("chamber_visual_factor",data.scale)
	var y_shift:float=data.get("chamber_visual_y_shift",.02)
	# Narrow the real visible ports and shell meshes together; interaction directions,
	# stroke thresholds/radii, hinge, support point and ammunition remain unchanged.
	for part in w.chamber_markers:
		part.position.x*=factor;part.position.y+=y_shift
	for part in w.chamber_live+w.chamber_spent:
		part.position.x*=factor;part.position.y+=y_shift;narrow_cylinder(part,factor)
	for part in w.hinge.get_children():
		if str(part.name).begins_with("OpenChamberMouth"):
			part.position.x*=factor;part.position.y+=y_shift
			var ring:=part.mesh.duplicate() as TorusMesh;ring.inner_radius*=factor;ring.outer_radius*=factor;part.mesh=ring
	w.seated_shells.position.y+=y_shift
	for part in w.seated_shells.get_children():part.position.x*=factor;narrow_cylinder(part,factor)
	for group in [w.shell_offer,w.shell_pair]:
		for part in group.get_children():part.position.x*=factor;narrow_cylinder(part,factor)
	for part in w._shell_pool:narrow_cylinder(part,factor)
	#085 remove our oversized extra hand grip/bridge, retain real reload marker.
	retained.hide()
	w.set_meta("downloaded_model_variant_082",variant)
	w.set_meta("downloaded_model_077","dt11");asset.free()
