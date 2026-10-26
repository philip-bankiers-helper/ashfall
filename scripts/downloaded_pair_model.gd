extends RefCounted
static func build(w:Node3D,id:String)->void:
	var folder:="res://assets/models/download_"+id+"/"
	var asset:Node3D=load(folder+"model.glb").instantiate()
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"asset-provenance.json"))
	for part in w.model.get_children():
		if part is Node3D and part not in [w.ammo_label,w.muzzle_flash]:part.hide()
	# Parent fields remain valid for inherited clocks. They no longer draw old box geometry.
	w.magazine.mesh=null;w.bolt.mesh=null;w._bolt_finish=null
	# Base clocks may show these parent nodes again. Clear their old rendered children.
	for legacy in [w.magazine,w.bolt]:
		for child in legacy.get_children():
			if child is Node3D:child.hide()
		for child in legacy.find_children("*","MeshInstance3D",true,false):child.mesh=null
	var source:=Node3D.new();source.name="DownloadedPair084";w.model.add_child(source)
	for name in ["Body","Magazine","Bolt"]:
		var part:=asset.find_child(name,true,false) as MeshInstance3D
		if part==null:continue
		var copy:=MeshInstance3D.new();copy.name=name;copy.mesh=part.mesh;source.add_child(copy)
		if name=="Magazine":
			var home:Array=data.magazine_center;copy.position=Vector3(home[0],home[1],home[2])
		elif name=="Bolt":
			var home:Array=data.bolt_home;copy.position=Vector3(home[0],home[1],home[2])
	w.set_meta("downloaded_pair_084",id);w.set_meta("primary_grip_084",Vector3(0,-.057,.025));asset.free()
