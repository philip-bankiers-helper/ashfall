extends RefCounted
## Additive industrial fittings. No physics, lights, gameplay state or animation.
## Call after enemy._build_warden; all coordinates are existing visual-local units.
static var _materials: Array[StandardMaterial3D] = []
static var _cache: Dictionary = {}
var _surfaces: Dictionary = {}

func attach_detail(existing_visual: Node3D, turret: Node3D, variant: int) -> Dictionary:
	if variant not in [1,3]: return {"triangles":0,"instances":0}
	if existing_visual.has_node("DroneIndustrialDetail"): return {"triangles":0,"instances":0,"already_attached":true}
	_init_materials()
	if not _cache.has(variant): _build_cache(variant)
	var total := 0
	var instances := 0
	for entry in _cache[variant]:
		var parent: Node3D = turret if entry.turret else existing_visual
		var root := parent.get_node_or_null("DroneIndustrialDetail") as Node3D
		if root == null:
			root = Node3D.new()
			root.name = "DroneIndustrialDetail"
			parent.add_child(root)
		var instance := MeshInstance3D.new()
		instance.mesh = entry.mesh
		instance.visibility_range_end = 20.0 if entry.small else 55.0
		instance.visibility_range_end_margin = 2.0
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
		total += int(entry.triangles)
		instances += 1
	return {"triangles":total,"instances":instances,"materials":_materials.size()}

static func _init_materials() -> void:
	if not _materials.is_empty(): return
	for color in [Color("263c40"),Color("809392"),Color("101b20"),Color("8e602b")]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = 0.65
		material.roughness = 0.62
		_materials.append(material)

func _append(mesh: Mesh, position: Vector3, material: int, small: bool = true, turret: bool = false, basis: Basis = Basis.IDENTITY) -> void:
	var key := "%d:%d:%d" % [material,int(small),int(turret)]
	if not _surfaces.has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[key] = {"surface":surface,"material":material,"small":small,"turret":turret}
	_surfaces[key].surface.append_from(mesh,0,Transform3D(basis,position))

func _box(position:Vector3,size:Vector3,material:int,small:bool=true,turret:bool=false,basis:Basis=Basis.IDENTITY) -> void:
	var mesh := BoxMesh.new()
	mesh.size=size
	_append(mesh,position,material,small,turret,basis)

func _cylinder(position:Vector3,radius:float,height:float,material:int,small:bool=true,turret:bool=false,basis:Basis=Basis.IDENTITY) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=8
	mesh.rings=1
	_append(mesh,position,material,small,turret,basis)

func _ring(position:Vector3,inner:float,outer:float,material:int,small:bool=true,turret:bool=false,basis:Basis=Basis.IDENTITY) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius=inner
	mesh.outer_radius=outer
	mesh.rings=16
	mesh.ring_segments=6
	_append(mesh,position,material,small,turret,basis)

func _hose(points:Array[Vector3],radius:float) -> void:
	for i in range(points.size()-1):
		var direction := points[i+1]-points[i]
		_cylinder((points[i]+points[i+1])*.5,radius,direction.length(),2,true,false,Basis(Quaternion(Vector3.UP,direction.normalized())))

func _triangle(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,normal:Vector3) -> void:
	# Godot front faces are clockwise; explicit outward normals avoid smoothing seams.
	if (b-a).cross(c-a).dot(normal)>0:
		var swap := b
		b=c
		c=swap
	for vertex in [a,b,c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)

func _plate(position:Vector3,size:Vector3,material:int,turret:bool=false) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x:=size.x*.5
	var y:=size.y*.5
	var z:=size.z*.5
	var bevel:=minf(x,y)*.24
	var outline:Array[Vector2]=[Vector2(-x+bevel,-y),Vector2(x-bevel,-y),Vector2(x,-y+bevel),Vector2(x,y-bevel),Vector2(x-bevel,y),Vector2(-x+bevel,y),Vector2(-x,y-bevel),Vector2(-x,-y+bevel)]
	for side in [-1.0,1.0]:
		for i in range(1,7):
			_triangle(surface,Vector3(outline[0].x,outline[0].y,z*side),Vector3(outline[i].x,outline[i].y,z*side),Vector3(outline[i+1].x,outline[i+1].y,z*side),Vector3(0,0,side))
	for i in range(8):
		var a:=outline[i]
		var b:=outline[(i+1)%8]
		var normal:=Vector3(b.y-a.y,a.x-b.x,0).normalized()
		_triangle(surface,Vector3(a.x,a.y,-z),Vector3(b.x,b.y,-z),Vector3(b.x,b.y,z),normal)
		_triangle(surface,Vector3(a.x,a.y,-z),Vector3(b.x,b.y,z),Vector3(a.x,a.y,z),normal)
	_append(surface.commit(),position,material,false,turret)

func _build_cache(variant:int) -> void:
	_surfaces.clear()
	var large:=variant==3
	# Side and aft service panels leave the complete forward core/shutter sweep clear.
	for side in [-1.0,1.0]:
		_plate(Vector3(side*(.51 if large else .39),1.1,.12 if large else .02),Vector3(.13,.42,.72 if large else .34),0)
		_plate(Vector3(side*.17,.02,.215),Vector3(.13,.2,.04),0,true)
		_ring(Vector3(side*.19,.02,-.235),.031,.046,1,true,true,Basis(Vector3.RIGHT,PI/2))
		_cylinder(Vector3(side*.19,.02,-.239),.027,.012,2,true,true,Basis(Vector3.RIGHT,PI/2))
		for y in [.89,1.25]:
			_cylinder(Vector3(side*(.49 if large else .32),y,.57 if large else .24),.022,.025,1,true,false,Basis(Vector3.RIGHT,PI/2))
		var rotor_x: float = side*(1.35 if large else .696)
		var rotor_y:=1.14 if large else .92
		var rotor_z:=.1 if large else 0.0
		_ring(Vector3(rotor_x,rotor_y+(.105 if large else .085),rotor_z),.46 if large else .195,.51 if large else .23,1,false)
		for bolt in range(8):
			var angle:=bolt*TAU/8
			var radius:=.49 if large else .21
			_cylinder(Vector3(rotor_x+cos(angle)*radius,rotor_y+(.13 if large else .11),rotor_z+sin(angle)*radius),.018,.025,2)
		if not large:
			for blade in range(5):
				var angle:=blade*TAU/5
				_box(Vector3(rotor_x+sin(angle)*.09,1.008,cos(angle)*.09),Vector3(.035,.014,.15),1,true,false,Basis(Vector3.UP,angle))
		_hose([Vector3(side*.2,1.25,.63 if large else .27),Vector3(side*.42,1.27,.64 if large else .29),Vector3(rotor_x,rotor_y+.06,rotor_z+.21)],.017)
	# Inset dark cooling cavity backed by real raised louvers and protective ribs.
	var rear:=.57 if large else .245
	_plate(Vector3(0,1.05,rear),Vector3(.68 if large else .55,.4,.035),0)
	_box(Vector3(0,1.05,rear+.025),Vector3(.48,.27,.018),2)
	for row in range(6):
		_box(Vector3(0,.935+row*.044,rear+.043),Vector3(.46,.016,.035),1,true,false,Basis(Vector3.RIGHT,-.3))
	for x in [-.25,.25]: _box(Vector3(x,1.05,rear+.04),Vector3(.022,.30,.04),3)
	_plate(Vector3(0,.13,.07),Vector3(.43,.07,.32),0,true)
	# Cache merged geometry: one draw per material/distance/attachment bucket.
	var entries:Array=[]
	for entry in _surfaces.values():
		entry.surface.set_material(_materials[entry.material])
		var mesh:ArrayMesh=entry.surface.commit()
		var arrays:=mesh.surface_get_arrays(0)
		var index_count:int=arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else 0
		var count:int=index_count if index_count>0 else arrays[Mesh.ARRAY_VERTEX].size()
		entries.append({"mesh":mesh,"triangles":count/3,"small":entry.small,"turret":entry.turret})
	_cache[variant]=entries
	_surfaces.clear()
