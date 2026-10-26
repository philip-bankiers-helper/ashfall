extends RefCounted
const FOLDER="res://assets/models/download_magnum/"
static func build(w:Node3D)->void:
	var asset:Node3D=load(FOLDER+"model.glb").instantiate()
	var body:=asset.find_child("Body",true,false) as MeshInstance3D
	var sights:Node3D=w.sight_rear.get_parent()
	#088 Remove our extra sight meshes; retain reference markers for the unchanged aim ray.
	for part in sights.find_children("*","MeshInstance3D",true,false):part.hide()
	for part in w.model.get_children():
		if part is Node3D and part not in [w.cylinder,w.offered,w.reload_arrow,w.muzzle_flash,w.ammo_label,sights]:part.hide()
	var shell:=MeshInstance3D.new();shell.name="DownloadedMagnumBody081";shell.mesh=body.mesh;w.model.add_child(shell)
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"asset-provenance.json"))
	var p:Array=data.cylinder_center;var center:=Vector3(p[0],p[1],p[2]);var scale:=Vector3(.66,.66,.60)
	var fit:=Node3D.new();fit.name="FittedSevenChamberDrum081";w.cylinder.add_child(fit)
	for part in w.cylinder.get_children():
		if part!=fit:part.reparent(fit,false)
	fit.scale=scale;fit.position=center-Vector3(0,.035,-.11)*scale
	var rounds:=Node3D.new();rounds.name="FittedSevenRoundOffer081";w.offered.add_child(rounds)
	for part in w.offered.get_children():
		if part!=rounds:part.reparent(rounds,false)
	rounds.scale=Vector3(.66,.66,1)
	preload("res://scripts/magnum_finish_094.gd").apply(w.cylinder,body.mesh.surface_get_material(0))
	w.set_meta("downloaded_magnum_081",true);asset.free()
