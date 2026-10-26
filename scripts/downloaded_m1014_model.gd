extends RefCounted
const FOLDER="res://assets/models/download_m1014/"
static func build(w:Node3D)->void:
	var asset:Node3D=load(FOLDER+"model.glb").instantiate()
	var body:=asset.find_child("Body",true,false) as MeshInstance3D
	var moving:=asset.find_child("Bolt",true,false) as MeshInstance3D
	for part in w.model.get_children():
		if part is Node3D and part not in [w.bolt,w.shell_pack,w.reload_arrow,w.muzzle_flash,w.ammo_label]:part.hide()
	var shell:=MeshInstance3D.new();shell.name="DownloadedM1014Body081";shell.mesh=body.mesh;w.model.add_child(shell)
	w.bolt.mesh=moving.mesh;w.bolt.material_override=null;w._bolt_finish=null;w.bolt.rotation=Vector3.ZERO;w.bolt.scale=Vector3.ONE;w.bolt.position=w.HANDLE
	for child in w.bolt.get_children():if child is Node3D:child.hide()
	w.set_meta("downloaded_model_077","m1014");asset.free()
