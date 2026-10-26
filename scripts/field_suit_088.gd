extends RefCounted
## Original render-only tailored field suit. Existing two-bone pose solver owns all motion.
static var _fabric:Texture2D
static var _grain:Texture2D
static var _stitch:Material
static func fabric()->Texture2D:
	if _fabric!=null:return _fabric
	var image:=Image.create(128,128,false,Image.FORMAT_RGB8)
	var noise:=FastNoiseLite.new();noise.seed=88;noise.frequency=.055;noise.fractal_octaves=3
	for y in 128:
		for x in 128:
			var n:=noise.get_noise_2d(x,y)
			var color:=Color("454b49") if n>.12 else (Color("2f3634") if n>-.18 else Color("1c2425"))
			var weave:=1.08 if (x+y)%4<2 else .9
			image.set_pixel(x,y,Color(color.r*weave,color.g*weave,color.b*weave))
	image.generate_mipmaps();_fabric=ImageTexture.create_from_image(image);return _fabric
static func grain()->Texture2D:
	if _grain!=null:return _grain
	var image:=Image.create(128,128,false,Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var v:=.81+.12*sin(y*2.71)+.035*sin(x*.73+y*8.17)
			image.set_pixel(x,y,Color(v,v,v))
	image.generate_mipmaps();_grain=ImageTexture.create_from_image(image);return _grain
static func metal_finish(mat:StandardMaterial3D)->void:
	mat.albedo_color=Color("687174");mat.albedo_texture=grain();mat.metallic=.62;mat.roughness=.38;mat.uv1_scale=Vector3(3,3,1)
	mat.uv1_triplanar=true;mat.uv1_scale=Vector3(24,24,24);mat.roughness_texture=grain()
static func finish(color:String,metallic:float=0.0,roughness:float=.85)->StandardMaterial3D:
	var result:=StandardMaterial3D.new();result.albedo_color=Color(color);result.metallic=metallic;result.roughness=roughness;return result
static func _add(mesh:ArrayMesh,shape:Mesh,at:Vector3,scale:Vector3,mat:Material,basis:Basis=Basis.IDENTITY)->void:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(shape,0,Transform3D(basis.scaled_local(scale),at));tool.set_material(mat);tool.commit(mesh)
static func _box(mesh:ArrayMesh,size:Vector3,at:Vector3,mat:Material)->void:
	var shape:=BoxMesh.new();shape.size=Vector3.ONE;_add(mesh,shape,at,size,mat)
static func _capsule(mesh:ArrayMesh,size:Vector3,at:Vector3,mat:Material)->void:
	var shape:=CapsuleMesh.new();shape.height=1;shape.radius=.5;shape.radial_segments=32;shape.rings=12;_add(mesh,shape,at,size,mat)
static func _batch(source:ArrayMesh)->ArrayMesh:
	var groups:Dictionary={}
	for i in source.get_surface_count():
		var mat:=source.surface_get_material(i)
		if not groups.has(mat):groups[mat]=[]
		groups[mat].append(i)
	var result:=ArrayMesh.new()
	for mat in groups:
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in groups[mat]:tool.append_from(source,i,Transform3D.IDENTITY)
		tool.set_material(mat);tool.commit(result)
	return result
static func _sleeve(mat:Material,forearm:bool)->ArrayMesh:
	var mesh:=ArrayMesh.new();var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=48;var rings:=24
	for row in rings:
		for side in count:
			for sample in [[0,0],[1,1],[1,0],[0,0],[0,1],[1,1]]:
				var t:=float(row+sample[0])/rings;var angle:=TAU*float(side+sample[1])/count
				var shape:=sin(PI*clampf(t*1.12+.01,0,1))*.08
				var radius:=lerpf(.49,.31 if forearm else .39,t)+shape
				# Restrained sleeve folds are real smooth geometry, with cuff and elbow taper.
				radius+=sin(t*TAU*6.0+cos(angle*3.0)*.8)*.012*sin(PI*t)
				var position:=Vector3(cos(angle)*radius,t-.5,sin(angle)*radius*.91)
				tool.set_normal(Vector3(cos(angle),-.12,sin(angle)/.91).normalized());tool.set_uv(Vector2(float(side+sample[1])/count,t*1.6));tool.add_vertex(position)
	tool.set_material(mat);tool.commit(mesh)
	var rubber:=finish("172221",.05,.79)
	var pad:=finish("303a36",.12,.7)
	# Rounded reinforcement follows the sleeve, stitched tape stays integrated in the same node.
	_capsule(mesh,Vector3(.58,.34,.09),Vector3(0,-.29 if forearm else .29,.43),pad)
	if forearm:
		var cuff:=CylinderMesh.new();cuff.height=.11;cuff.top_radius=.31;cuff.bottom_radius=.34;cuff.radial_segments=48
		_add(mesh,cuff,Vector3(0,.445,0),Vector3(1,1,.91),rubber)
		_box(mesh,Vector3(.42,.065,.055),Vector3(0,.43,.30),pad)
	for side in [-1.0,1.0]:
		for row in 13:_box(mesh,Vector3(.012,.016,.012),Vector3(side*.21,.14+row*.023,.475),_stitch)
	return mesh
static func build(body:Node3D)->void:
	var cloth:=finish("c3ccc2");cloth.albedo_texture=fabric();cloth.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;cloth.uv1_scale=Vector3(2,2,1)
	var armor:=finish("333f3b",.24,.63);armor.albedo_texture=grain()
	var rubber:=finish("172321",.03,.86)
	_stitch=finish("778176",.0,.9)
	var torso:=ArrayMesh.new();var shell:=CylinderMesh.new();shell.height=1;shell.top_radius=.20;shell.bottom_radius=.16;shell.radial_segments=48;shell.rings=12
	_add(torso,shell,Vector3.ZERO,Vector3(.94,1,.62),cloth)
	# Tailored front placket, seams and padded collar stay below the existing eye clearance.
	_box(torso,Vector3(.018,.70,.012),Vector3(0,.03,-.139),rubber)
	for side in [-1.0,1.0]:
		_box(torso,Vector3(.034,.62,.016),Vector3(side*.145,.02,-.10),armor)
		for row in 12:_box(torso,Vector3(.006,.012,.006),Vector3(side*.12,-.29+row*.045,-.13),_stitch)
	body._piece("Jacket",torso,cloth);body.pieces.Jacket.material_override=null
	var plate:=ArrayMesh.new();_capsule(plate,Vector3(.29,.27,.035),Vector3.ZERO,armor)
	for side in [-1.0,1.0]:
		_box(plate,Vector3(.105,.11,.025),Vector3(side*.069,-.039,-.025),rubber)
		for row in 3:_box(plate,Vector3(.105,.009,.006),Vector3(side*.069,-.075+row*.032,-.04),armor)
	body._piece("ChestPlate",plate,armor);body.pieces.ChestPlate.material_override=null
	var belt:=ArrayMesh.new();_capsule(belt,Vector3(.31,.18,.22),Vector3.ZERO,rubber)
	for side in [-1.0,1.0]:_box(belt,Vector3(.06,.115,.055),Vector3(side*.14,-.005,-.07),armor)
	_box(belt,Vector3(.052,.046,.016),Vector3(0,.015,-.113),armor)
	body._piece("Belt",belt,rubber);body.pieces.Belt.material_override=null
	for side in ["L","R"]:
		for part in ["UpperArm","Forearm","Thigh","Shin"]:
			var mesh:=_sleeve(cloth,part=="Forearm") if part in ["UpperArm","Forearm"] else ArrayMesh.new()
			if part in ["Thigh","Shin"]:
				_capsule(mesh,Vector3(1,1,.90),Vector3.ZERO,cloth)
				_capsule(mesh,Vector3(.72,.27,.15),Vector3(0,.20,-.42),armor)
			body._piece(side+part,mesh,cloth);body.pieces[side+part].material_override=null
		var boot:=ArrayMesh.new();_capsule(boot,Vector3(.13,.13,.25),Vector3.ZERO,rubber)
		_box(boot,Vector3(.13,.022,.24),Vector3(0,-.055,0),rubber)
		for row in 4:_box(boot,Vector3(.062,.003,.006),Vector3(0,.061,-.05+row*.024),armor)
		body._piece(side+"Boot",boot,rubber);body.pieces[side+"Boot"].material_override=null
	for piece in body.pieces.values():piece.mesh=_batch(piece.mesh)
	body.set_meta("detailed_field_suit_088",true)
static func upgrade_arms(body:Node3D)->void:
	var cloth:=finish("c3ccc2");cloth.albedo_texture=fabric();cloth.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_stitch=finish("566153",.0,.9)
	for side in ["L","R"]:
		for part in ["UpperArm","Forearm"]:
			body.pieces[side+part].mesh=_batch(_sleeve(cloth,part=="Forearm"));body.pieces[side+part].material_override=null
	body.set_meta("detailed_arms_088",true)
static func dress_optic(optic:Node3D)->void:
	var steel:=finish("5b6465",.85,.31);metal_finish(steel)
	for side in [-1.0,1.0]:
		for y in [.123,.179]:
			var screw:=MeshInstance3D.new();screw.name="RecessedOpticFastener088_%s_%s"%[side,y];var shape:=CylinderMesh.new();shape.height=.003;shape.top_radius=.003;shape.bottom_radius=.003;shape.radial_segments=16
			screw.mesh=shape;screw.material_override=steel;screw.rotation.x=PI*.5;screw.position=Vector3(side*.060,y,.081);screw.layers=1<<18;optic.add_child(screw)
