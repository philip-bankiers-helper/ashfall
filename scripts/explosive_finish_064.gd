extends RefCounted
## Original item geometry shared by held and flight props. No input or physics.
const GRENADE_RADIUS:=.047
static var _grenade_meshes:Dictionary={}
static var _rocket_meshes:Dictionary={}
static func _finish(color:String,metal:float,rough:float,glow:float=0.0)->StandardMaterial3D:
	var material:=StandardMaterial3D.new();material.albedo_color=Color(color);material.metallic=metal;material.roughness=rough
	if glow>0:material.emission_enabled=true;material.emission=material.albedo_color;material.emission_energy_multiplier=glow
	return material
static func _root(parent:Node3D,label:String)->Node3D:
	var value:=Node3D.new();value.name=label;parent.add_child(value);return value
static func _box(parent:Node3D,size:Vector3,point:Vector3,finish:Material)->MeshInstance3D:
	var value:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;value.mesh=mesh;value.material_override=finish;value.position=point;parent.add_child(value);return value
static func _rod(parent:Node3D,a:Vector3,b:Vector3,radius:float,finish:Material,sides:int=16)->void:
	var value:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=sides;mesh.rings=1
	value.mesh=mesh;value.material_override=finish;value.position=(a+b)*.5;value.quaternion=Quaternion(Vector3.UP,(b-a).normalized());parent.add_child(value)
static func _ring(parent:Node3D,point:Vector3,inner:float,outer:float,finish:Material,axis:Vector3=Vector3.UP)->void:
	var value:=MeshInstance3D.new();var mesh:=TorusMesh.new();mesh.inner_radius=inner;mesh.outer_radius=outer;mesh.rings=20;mesh.ring_segments=6
	value.mesh=mesh;value.material_override=finish;value.position=point;value.quaternion=Quaternion(Vector3.UP,axis);parent.add_child(value)
static func _lathe(parent:Node3D,profile:Array[Vector2],finish:Material)->void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(1,profile.size()):
		var a:Vector2=profile[row-1];var b:Vector2=profile[row];var normal:=Vector2(b.y-a.y,a.x-b.x).normalized()
		for side in 24:
			var angles:=[TAU*side/24.0,TAU*(side+1)/24.0]
			for sample in [[0,0],[0,1],[1,1],[0,0],[1,1],[1,0]]:
				var p:Vector2=a if sample[0]==0 else b;var angle:float=angles[sample[1]]
				surface.set_normal(Vector3(cos(angle)*normal.x,normal.y,sin(angle)*normal.x));surface.add_vertex(Vector3(cos(angle)*p.x,p.y,sin(angle)*p.x))
	# append_from must not mix unindexed custom vertices with indexed primitives.
	surface.index()
	var value:=MeshInstance3D.new();value.mesh=surface.commit();value.material_override=finish;parent.add_child(value)
static func _batch(root:Node3D)->void:
	var groups:Dictionary={}
	for child in root.get_children():
		if child is MeshInstance3D:
			if not groups.has(child.material_override):groups[child.material_override]=[]
			groups[child.material_override].append(child)
	for finish in groups:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in groups[finish]:
			for i in part.mesh.get_surface_count():surface.append_from(part.mesh,i,part.transform)
			part.free()
		surface.index()
		var merged:=MeshInstance3D.new();merged.name="BatchedItemFinish";merged.mesh=surface.commit();merged.material_override=finish;root.add_child(merged)
static func _resources(root:Node3D)->Array:
	var result:Array=[]
	for child in root.get_children():
		if child is MeshInstance3D:result.append({"mesh":child.mesh,"finish":child.material_override})
	return result
static func _restore(root:Node3D,resources:Array)->void:
	for item in resources:
		var mesh:=MeshInstance3D.new();mesh.name="BatchedItemFinish";mesh.mesh=item.mesh;mesh.material_override=item.finish;root.add_child(mesh)
static func _palette_key(value:Material)->String:
	if value is StandardMaterial3D:return str([value.albedo_color,value.metallic,value.roughness,value.emission_enabled,value.emission,value.emission_energy_multiplier])
	return str(value.get_instance_id())

static func grenade(parent:Node3D,kind:String,visual_scale:float=1.0)->Node3D:
	if kind in ["frag","zone"] and not preload("res://scripts/asset_quality.gd").lightweight():return preload("res://scripts/downloaded_grenade_model.gd").build(parent,visual_scale,kind)
	var root:=_root(parent,"OriginalGrenadeArt064");root.scale=Vector3.ONE*visual_scale;root.set_meta("art_profile",kind);root.set_meta("uniform_visual_scale",visual_scale)
	if _grenade_meshes.has(kind):_restore(root,_grenade_meshes[kind]);return root
	var metal:=_finish("748087",.77,.38);var dark:=_finish("263034",.32,.62);var band:=_finish("b09256",.66,.42)
	if kind=="zone":
		var violet:=_finish("9875d2",.22,.44,.3)
		_lathe(root,[Vector2(0,-.0525),Vector2(.031,-.0525),Vector2(.039,-.043),Vector2(.039,.037),Vector2(.034,.049),Vector2(.026,.0525)],dark)
		for y in [-.045,.043]:_ring(root,Vector3(0,y,0),.036,.042,metal)
		_rod(root,Vector3(0,.050,0),Vector3(0,.061,0),.030,metal)
		_rod(root,Vector3(0,.061,0),Vector3(0,.064,0),.022,violet)
		for index in 3:
			var angle:=TAU*index/3.0
			var radial:=Vector3(sin(angle),0,cos(angle))
			_rod(root,radial*.024+Vector3(0,-.049,0),radial*.028+Vector3(0,-.062,0),.0025,metal,8)
			var frame:=_box(root,Vector3(.025,.054,.004),radial*.039,metal);frame.rotation.y=angle
			var window:=_box(root,Vector3(.017,.040,.001),radial*.042,violet);window.rotation.y=angle
			for y in [-.012,.0,.012]:
				var slat:=_box(root,Vector3(.019,.002,.002),radial*.043+Vector3.UP*y,dark);slat.rotation.y=angle
	else:
		var body:=_finish("66784b",.28,.64)
		_lathe(root,[Vector2(0,-.0525),Vector2(.026,-.047),Vector2(.040,-.030),Vector2(.047,-.005),Vector2(.041,.025),Vector2(.028,.043),Vector2(.019,.050)],body)
		for ring in [Vector3(-.030,.039,.0415),Vector3(-.005,.045,.048),Vector3(.020,.040,.0435)]:_ring(root,Vector3(0,ring.x,0),ring.y,ring.z,dark)
		var seams:Array[Vector2]=[Vector2(.0265,-.047),Vector2(.0405,-.030),Vector2(.0475,-.005),Vector2(.0415,.025),Vector2(.0285,.043)]
		for index in 8:
			var angle:=TAU*index/8.0
			for row in range(1,seams.size()):
				var a:Vector2=seams[row-1];var b:Vector2=seams[row]
				_rod(root,Vector3(cos(angle)*a.x,a.y,sin(angle)*a.x),Vector3(cos(angle)*b.x,b.y,sin(angle)*b.x),.00065,dark,8)
		_rod(root,Vector3(0,.048,0),Vector3(0,.061,0),.019,band)
		_box(root,Vector3(.063,.004,.014),Vector3(.020,.065,0),metal)
		var lever:=_box(root,Vector3(.009,.076,.014),Vector3(.048,.028,0),metal);lever.rotation.z=-.12
		_rod(root,Vector3(.009,.062,-.010),Vector3(.009,.062,.010),.0045,dark)
		_rod(root,Vector3(-.028,.056,0),Vector3(.006,.056,0),.0022,metal,12)
		_ring(root,Vector3(-.031,.056,0),.0075,.0105,band,Vector3.BACK)
	_batch(root);_grenade_meshes[kind]=_resources(root);return root

static func rocket(parent:Node3D,alloy:Material=null,band:Material=null)->Node3D:
	if alloy==null:alloy=_finish("39483e",.65,.58)
	if band==null:band=_finish("d23f86",.5,.43)
	var dark:=_finish("29363b",.4,.60);var root:=_root(parent,"OriginalRocketArt064");root.set_meta("art_profile","smaw_round");root.set_meta("nose_axis",Vector3.FORWARD);root.rotation.y=PI
	var palette:=_palette_key(alloy)+"|"+_palette_key(band)
	if _rocket_meshes.has(palette):_restore(root,_rocket_meshes[palette]);return root
	_rod(root,Vector3(0,0,-.12),Vector3(0,0,.11),.032,alloy)
	for z in [-.10,-.015,.085]:_ring(root,Vector3(0,0,z),.0305,.0345,band,Vector3.BACK)
	var nose:=MeshInstance3D.new();var cone:=CylinderMesh.new();cone.top_radius=0;cone.bottom_radius=.032;cone.height=.10;cone.radial_segments=16;cone.rings=1;nose.mesh=cone;nose.material_override=band;nose.rotation.x=PI*.5;nose.position.z=.16;root.add_child(nose)
	for index in 4:
		var angle:=TAU*index/4.0;var fin:=_box(root,Vector3(.018,.003,.065),Vector3(cos(angle)*.034,sin(angle)*.034,-.10),band);fin.rotation.z=angle
	_rod(root,Vector3(0,0,-.121),Vector3(0,0,-.124),.023,dark)
	_ring(root,Vector3(0,0,-.124),.022,.030,band,Vector3.BACK)
	_batch(root);_rocket_meshes[palette]=_resources(root);return root

static func launcher(payload:Node3D)->void:
	var root:=_root(payload,"OriginalLauncherDetail064");var metal:=_finish("7a888b",.7,.41);var dark:=_finish("253236",.25,.7)
	for z in [-.50,.10]:_ring(root,Vector3(0,.045,z),.0545,.0585,metal,Vector3.BACK)
	for side in [-1.0,1.0]:
		_box(root,Vector3(.002,.006,.43),Vector3(side*.055,.047,-.225),dark)
		for z in [-.47,.075]:_rod(root,Vector3(side*.055,.045,z),Vector3(side*.059,.045,z),.004,metal,8)
		for row in 5:_box(root,Vector3(.0015,.003,.052),Vector3(side*.0232,-.120+row*.018,-.14),metal)
	_batch(root)
