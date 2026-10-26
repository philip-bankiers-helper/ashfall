extends RefCounted
## Staged original manufacture detail. Not imported by production while QA freezes source.
static var _grain:ImageTexture
static func finish(color:Color,metallic:float,roughness:float)->StandardMaterial3D:
	if _grain==null:
		var image:=Image.create(64,64,false,Image.FORMAT_RGB8)
		var rng:=RandomNumberGenerator.new()
		rng.seed=814002
		for y in range(64):
			for x in range(64):
				var value:=0.88+rng.randf()*0.12
				image.set_pixel(x,y,Color(value,value,value))
		image.generate_mipmaps()
		_grain=ImageTexture.create_from_image(image)
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.metallic=metallic
	material.roughness=roughness
	material.roughness_texture=_grain
	material.uv1_scale=Vector3(4,4,4)
	return material

static func iron_sights(parent:Node3D,rear_z:float,front_z:float,height:float,metal:Material,bead:Material,front_height:float=NAN)->Node3D:
	if is_nan(front_height):front_height=height
	var sights:=Node3D.new()
	sights.name="IronSights"
	parent.add_child(sights)
	for side in [-1.0,1.0]:
		_box(sights,Vector3(0.008,0.018,0.012),Vector3(side*0.010,height-0.003,rear_z),metal)
	_box(sights,Vector3(0.028,0.005,0.015),Vector3(0,height-0.014,rear_z),metal)
	var front:=Node3D.new()
	front.name="FrontAssembly"
	sights.add_child(front)
	_box(front,Vector3(0.009,0.026,0.018),Vector3(0,front_height-0.014,front_z),metal)
	var sphere:=SphereMesh.new()
	sphere.radius=0.0025
	sphere.height=0.005
	sphere.radial_segments=10
	sphere.rings=6
	var mark:=MeshInstance3D.new()
	mark.mesh=sphere
	mark.material_override=bead
	mark.position=Vector3(0,front_height,front_z)
	front.add_child(mark)
	for z in [rear_z,front_z]:
		var reference:=Marker3D.new()
		reference.position=Vector3(0,height if z==rear_z else front_height,z)
		reference.name="RearReference" if z==rear_z else "FrontReference"
		(sights if z==rear_z else front).add_child(reference)
	return sights

static func _box(parent:Node3D,size:Vector3,position:Vector3,material:Material)->void:
	var mesh:=MeshInstance3D.new()
	var shape:=BoxMesh.new()
	shape.size=size
	mesh.mesh=shape
	mesh.position=position
	mesh.material_override=material
	parent.add_child(mesh)

static func zeroed_sights(parent:Node3D,rear_z:float,front_z:float,rear_height:float,muzzle:Vector3,zero_distance:float,metal:Material,bead:Material)->Node3D:
	# Hitscan has no drop: a geometrical zero against its UNMODIFIED ray.
	var target:=muzzle+Vector3.FORWARD*maxf(zero_distance,1.0)
	var ratio:float=(front_z-rear_z)/(target.z-rear_z)
	var front_height:=lerpf(rear_height,target.y,ratio)
	var sights:=iron_sights(parent,rear_z,front_z,rear_height,metal,bead,front_height)
	sights.set_meta("zero_distance",zero_distance)
	sights.set_meta("bore_origin",muzzle)
	return sights

static func tapered_stock(parent:Node3D,material:Material)->void:
	var vertices:PackedVector3Array=[Vector3(-0.022,-0.025,0.055),Vector3(0.022,-0.025,0.055),Vector3(0.022,0.025,0.055),Vector3(-0.022,0.025,0.055),Vector3(-0.035,-0.08,0.285),Vector3(0.035,-0.08,0.285),Vector3(0.035,0.03,0.285),Vector3(-0.035,0.03,0.285)]
	var triangles:PackedInt32Array=[0,2,1,0,3,2,4,5,6,4,6,7,0,4,7,0,7,3,1,2,6,1,6,5,3,7,6,3,6,2,0,1,5,0,5,4]
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# This authored list is conventional outward CCW. Godot's front faces are
	# clockwise; reverse each triangle before deriving its outward render normal.
	for triangle in range(0,triangles.size(),3):
		for offset in [0,2,1]:surface.add_vertex(vertices[triangles[triangle+offset]])
	surface.generate_normals()
	surface.index()
	var mesh:=MeshInstance3D.new()
	mesh.mesh=surface.commit()
	mesh.material_override=material
	parent.add_child(mesh)

