extends RefCounted
const PATH="res://assets/models/download_frag/model.glb"
static var _mesh:Mesh
static var _meshes:Dictionary={}
static func build(parent:Node3D,visual_scale:float,kind:String="zone")->Node3D:
	var variant:String="frag" if kind=="zone" else "frag_alt"
	var mesh:Mesh=_meshes.get(variant)
	if mesh==null:
		var asset:Node3D=load("res://assets/models/download_"+variant+"/model.glb").instantiate();mesh=asset.find_child("Body",true,false).mesh;_meshes[variant]=mesh;asset.free()
	if variant=="frag":_mesh=mesh
	visual_scale*=2.0 if kind=="zone" else .9
	var root:=Node3D.new();root.name="DownloadedGrenadeArt079";root.scale=Vector3.ONE*visual_scale
	root.set_meta("art_profile",kind);root.set_meta("uniform_visual_scale",visual_scale);root.set_meta("downloaded_grenade_079",true);parent.add_child(root)
	root.set_meta("downloaded_model_variant_082",variant)
	var body:=MeshInstance3D.new();body.name="DownloadedGrenade079";body.mesh=mesh;root.add_child(body)
	return root
