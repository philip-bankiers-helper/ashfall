extends RefCounted
const FOLDER="res://assets/models/download_awp/"
static func build(w:Node3D)->void:
	var asset:Node3D=load(FOLDER+"model.glb").instantiate()
	var body:=asset.find_child("Body",true,false) as MeshInstance3D
	var mag:=asset.find_child("Magazine",true,false) as MeshInstance3D
	var bolt:=asset.find_child("Bolt",true,false) as MeshInstance3D
	for part in w.model.get_children():
		if part is Node3D and part not in [w.magazine,w.bolt_handle,w.chamber_window,w.guide,w.muzzle_flash,w.ammo_label,w.insertion_arrow,w.charging_arrow]:part.hide()
	var shell:=MeshInstance3D.new();shell.name="DownloadedAWPBody081";shell.mesh=body.mesh;w.model.add_child(shell)
	for child in w.bolt_handle.get_children():if child is Node3D:child.hide()
	var carrier:=MeshInstance3D.new();carrier.name="DownloadedAWPBolt081";carrier.mesh=bolt.mesh;w.bolt_handle.add_child(carrier)
	w.magazine.mesh=mag.mesh;w.magazine.material_override=null;w.magazine.scale=Vector3.ONE;w.magazine.rotation=Vector3.ZERO
	for child in w.magazine.get_children():if child is Node3D:child.hide()
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"asset-provenance.json"));var v:Array=data.magazine_center
	var home:=Vector3(v[0],v[1],v[2]);w.magazine.position=home;w.insertion_arrow.position.z=home.z
	w.set_meta("downloaded_model_077","awp");w.set_meta("download_magazine_home_077",home)
	w.loose_magazine.mesh=mag.mesh;w.loose_magazine.material_override=null;w.loose_magazine.rotation=Vector3.ZERO;w.loose_magazine.scale=Vector3.ONE
	for child in w.loose_magazine.get_children():if child is Node3D:child.hide()
	for child in w.hip_source.get_children():child.free()
	var offered:=MeshInstance3D.new();offered.mesh=mag.mesh;w.hip_source.add_child(offered)
	w.chamber_window.position.x=.022
	var metal:Material=w._material(Color("333c42"),.8,.35)
	w.set_meta("source_scope_restored_085",true) # supplied mounts/rings are in source Body
	asset.free()
