extends RefCounted
const ASSET_PATH="res://assets/models/tactical_1911/tactical_1911.glb"
# Baked uniformly into metre coordinates by prepare_1911.py; no runtime scale.
static func build(w:Node3D)->void:
	var asset:Node3D=load(ASSET_PATH).instantiate()
	var body:=asset.find_child("Tactical1911Body",true,false) as MeshInstance3D
	var slide:=asset.find_child("Tactical1911Slide",true,false) as MeshInstance3D
	var mag:=asset.find_child("Tactical1911Magazine",true,false) as MeshInstance3D
	for part in w.model.get_children():
		if part is Node3D and part not in [w.magazine,w.bolt,w.guide,w.muzzle_flash,w.ammo_label,w.insertion_arrow,w.charging_arrow]:part.hide()
	var shell:=MeshInstance3D.new();shell.name="ImportedTactical1911";shell.mesh=body.mesh;w.model.add_child(shell)
	w.bolt.mesh=slide.mesh;w.bolt.material_override=null;w.bolt.position=Vector3(0,.04,-.10)
	w.bolt.scale=Vector3.ONE;w.bolt.rotation=Vector3.ZERO
	w.set_meta("charging_rest_089",w.bolt.position)
	w.set_meta("charging_mesh_center_089",slide.mesh.get_aabb().get_center())
	w._bolt_finish=null
	for child in w.bolt.get_children():if child is Node3D:child.hide()
	w.magazine.mesh=mag.mesh;w.magazine.material_override=null;w.magazine.rotation=Vector3.ZERO;w.magazine.scale=Vector3.ONE
	for child in w.magazine.get_children():if child is Node3D:child.hide()
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/tactical_1911/asset-provenance.json"))
	var home:Array=data.magazine_center;w.magazine_home=Vector3(home[0],home[1],home[2]);w.magazine.position=w.magazine_home
	w.insertion_arrow.position.z=w.magazine_home.z
	w._build_profile_magazine_offers()
	w.set_meta("imported_tactical_1911",true)
	asset.free()
