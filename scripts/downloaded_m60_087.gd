extends RefCounted
## Complete author cover, separate charging knob, and rigid donor box/belt.
const Copy=preload("res://scripts/downloaded_heavy_085.gd")
static func apply(w:Node3D)->void:
	var asset:Node3D=load("res://assets/models/download_m60/model.glb").instantiate()
	var donor:Node3D=load("res://assets/models/download_m60_reload087/model.glb").instantiate()
	var fit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/download_m60/reload-fit.json"))
	var points:Dictionary={}
	for key in ["cover_home","cover_grab","box_home","box_offer","handle_home","belt_grab","feed_home","primary_grip"]:
		var a:Array=fit[key];points[key]=Vector3(float(a[0]),float(a[1]),float(a[2]))
	w.set_meta("m60_fit_087",points)
	var delta:Array=fit.get("donor_fit_delta_088",[0,0,0])
	w.set_meta("m60_donor_delta_088",Vector3(delta[0],delta[1],delta[2]))
	w.set_meta("primary_grip_084",points.primary_grip)
	var keep:Array=[w.cover,w.belt_box,w.belt,w.charging_handle,w.feed_socket,w.muzzle_flash,w.ammo_label]
	for child in w.model.get_children():
		if child is Node3D and child not in keep:child.hide()
	Copy._copy(asset,"Body",w.model)
	Copy._clear_visuals(w.cover);Copy._copy(asset,"Cover",w.cover)
	w.cover.position=points.cover_home
	# Existing physical contact nodes own the source geometry; no duplicated static parts.
	var box:=donor.find_child("Magazine",true,false) as MeshInstance3D
	w.belt_box.mesh=box.mesh;w.belt_box.material_override=null;Copy._clear_visuals(w.belt_box)
	for holder in [w.offered_box,w.held_box]:
		Copy._clear_visuals(holder);Copy._copy(donor,"Magazine",holder)
	Copy._clear_visuals(w.belt);Copy._copy(donor,"Belt",w.belt)
	w.belt.position=Vector3(0,float(fit.get("belt_lift_088",0.0)),float(delta[2]))
	var handle:=asset.find_child("Bolt",true,false) as MeshInstance3D
	w.charging_handle.mesh=handle.mesh;w.charging_handle.material_override=null;Copy._clear_visuals(w.charging_handle)
	w.belt_feed_grip.mesh=null #089 remove old gray proxy over the actual linked rounds
	w.feed_socket.mesh=null # actual donor box/tray supplies the visible geometry
	w.belt_feed_grip.position=points.belt_grab-Vector3(delta[0],float(fit.get("belt_lift_088",0.0)),delta[2])
	# A source mesh keeps its original textures during contact highlighting.
	w.set_meta("downloaded_model_077","m60");w.set_meta("downloaded_heavy_085",true)
	w.set_meta("articulated_m60_087",true)
	asset.free();donor.free()
