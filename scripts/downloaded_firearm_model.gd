extends RefCounted
const IDS=["px4","tec9","mp9","fal","rfb","mp5","akm","p90","cx4","awp","s85","mk18","spr"]
static func available(id:String)->bool:
	return id in IDS and not preload("res://scripts/asset_quality.gd").lightweight()
static func build(w:Node3D,id:String)->void:
	var variant:String=preload("res://scripts/model_variants.gd").choose(id)
	var folder:="res://assets/models/download_"+variant+"/"
	if id=="s85":folder="res://assets/models/download_s85_m1_099/"
	var asset:Node3D=load(folder+"model.glb").instantiate()
	var body:=asset.find_child("Body",true,false) as MeshInstance3D
	var mag:=asset.find_child("Magazine",true,false) as MeshInstance3D
	var moving:=asset.find_child("Slide",true,false) as MeshInstance3D
	if moving==null:moving=asset.find_child("Bolt",true,false) as MeshInstance3D
	for part in w.model.get_children():
		if part is Node3D and part not in [w.magazine,w.bolt,w.guide,w.muzzle_flash,w.ammo_label,w.insertion_arrow,w.charging_arrow]:part.hide()
	if id=="p90":
		body.mesh=preload("res://scripts/solid_import_085.gd").mesh(body.mesh)
		mag.mesh=preload("res://scripts/solid_import_085.gd").mesh(mag.mesh)
	var shell:=MeshInstance3D.new();shell.name="DownloadedBody077";shell.mesh=body.mesh;w.model.add_child(shell)
	if moving!=null:
		w.bolt.mesh=moving.mesh;w.bolt.material_override=null;w.bolt.scale=Vector3.ONE;w.bolt.rotation=Vector3.ZERO
		w.bolt.position=Vector3(0,.04,-.10) if moving.name=="Slide" else Vector3(.065 if id=="rfb" else -.045,.064,-.10)
		if id in ["spr","s85"]:w.bolt.position=Vector3.ZERO # Correctly partitioned rear T-handle in model coordinates.
		w._bolt_finish=null
		w.set_meta("charging_rest_089",w.bolt.position)
		w.set_meta("charging_mesh_center_089",moving.mesh.get_aabb().get_center())
		if id=="spr":w.charging_arrow.position=w.charging_grip_point()+Vector3(0,.025,0)
		for child in w.bolt.get_children():if child is Node3D:child.hide()
	w.magazine.mesh=mag.mesh;w.magazine.material_override=null;w.magazine.rotation=Vector3.ZERO;w.magazine.scale=Vector3.ONE
	for child in w.magazine.get_children():if child is Node3D:child.hide()
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"asset-provenance.json"))
	if data.has("reflex_height"):w.set_meta("download_reflex_height_077",float(data.reflex_height))
	var home:Array=data.magazine_center;var at:=Vector3(home[0],home[1],home[2]);w.magazine.position=at
	w.set_meta("downloaded_model_077",id);w.set_meta("download_magazine_home_077",at)
	w.set_meta("downloaded_model_variant_082",variant)
	var m:Array=data.muzzle;w.set_meta("download_muzzle_084",Vector3(m[0],m[1],m[2]))
	if data.has("primary_grip"):
		var g:Array=data.primary_grip;w.set_meta("primary_grip_084",Vector3(g[0],g[1],g[2]))
	if id=="tec9":w.set_meta("primary_grip_084",Vector3(0,-.057,-.025))
	w.insertion_arrow.position.z=at.z
	if id=="p90":w._top_rest=at
	elif id not in ["px4","mk18","spr"]:w.magazine_home=at
	if w.has_method("_build_profile_magazine_offers"):w._build_profile_magazine_offers()
	else:
		w.loose_magazine.mesh=mag.mesh;w.loose_magazine.material_override=null;w.loose_magazine.scale=Vector3.ONE;w.loose_magazine.rotation=Vector3.ZERO
		for child in w.loose_magazine.get_children():if child is Node3D:child.hide()
		for child in w.hip_source.get_children():child.free()
		var offered:=MeshInstance3D.new();offered.mesh=mag.mesh;w.hip_source.add_child(offered)
	if id=="mp9":
		# This download is unsuppressed; preserve the silenced variant and its old shot datum.
		var steel:Material=w._material(Color("252d32"),.8,.35)
		w._rod(Vector3(0,.045,float(data.suppressor_start)),Vector3(0,.045,-.42),.023,steel,20)
	if id=="cx4":
		var steel:Material=w._material(Color("454f55"),.78,.32)
		w._rod(Vector3(0,.045,float(data.barrel_extension_start)),Vector3(0,.045,-.62),.0125,steel,16)
	if id in ["akm","cx4","s85"] and w.has_meta("ring_sight"):w.get_meta("ring_sight").show()
	asset.free()
static func replace_debris(w:Node3D)->void:
	if not w.has_meta("downloaded_model_077"):return
	for i in range(w.CASING_POOL_SIZE,w._debris.size()):
		w._debris[i].mesh=w.magazine.mesh;w._debris[i].material_override=null;w._debris[i].scale=Vector3.ONE
