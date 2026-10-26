extends RefCounted
static var _meshes:Dictionary={}
static func apply(parent:Node3D,kind:String)->void:
	var variant:String=preload("res://scripts/model_variants.gd").choose(kind)
	var mesh:Mesh=_meshes.get(variant)
	if mesh==null:
		var asset:Node3D=load("res://assets/models/download_"+variant+"/model.glb").instantiate()
		mesh=asset.find_child("Body",true,false).mesh;_meshes[variant]=mesh;asset.free()
	for part in parent.get_children():
		if part is MeshInstance3D:part.hide()
	var blade:=MeshInstance3D.new();blade.name="DownloadedBlade077";blade.mesh=mesh
	if kind in ["katana","cyberblade"]:
		var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/download_"+variant+"/asset-provenance.json"))
		var a:Array=data.get("target_pommel",data.target);var b:Array=data.contact_tip
		var pommel:=Vector3(a[0],a[1],a[2]);var tip:=Vector3(b[0],b[1],b[2])
		blade.basis=Basis((tip-pommel).normalized(),0.0 if kind=="katana" else PI);blade.position=pommel-blade.basis*pommel
		blade.set_meta("long_axis_roll_degrees_084",360.0 if kind=="katana" else 180.0)
		if kind=="cyberblade":
			var target_tip:Vector3=parent.get_node("BladeContactTip").position
			var alignment:=Basis(Quaternion((tip-pommel).normalized(),(target_tip-pommel).normalized()))
			blade.basis=alignment*blade.basis
			blade.position=pommel-blade.basis*pommel
	blade.layers=1<<18;blade.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(blade)
	parent.set_meta("downloaded_blade_077",kind)
	parent.set_meta("downloaded_model_variant_082",variant)
