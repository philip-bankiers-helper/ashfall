extends Node3D
## CYBER BIRD. Original, deterministic city; one Godot unit = one SI metre.
## Windows are omissions in the geometry, never alpha panels or collision cutouts.
const MAP_ID := "cyber_bird"
const MAP_TITLE := "CYBER BIRD"
const EXTENT := 400.0
const STOREY := 4.2
const DISTRICTS := ["HERON QUAY", "FEATHER MARKET", "ROOK FOUNDRY", "CROWN NESTS"]
var spawn := Vector3.ZERO
var buildings: Array[Dictionary] = []
var windows: Array[Dictionary] = []
var routes: Array[Dictionary] = []
var loot_points: Array[Vector3] = []
var materials: Dictionary = {}
var statistics: Dictionary = {"boxes":0,"collision_triangles":0,"batches":0,"floors":0,"stairs":0,"bridges":0}
var _batches: Dictionary = {}
var _faces := PackedVector3Array()
var _unit_faces := PackedVector3Array()
var _chunk: Node3D
var _built := false
var _game: Node
var _refresh_pending := false
var _cube: BoxMesh
var _environment: Environment
var _previous_environment: Environment
var _clock := 0.0
var _local_lights: Array[OmniLight3D] = []
var _light_sites: Array[Dictionary] = []
var _neon_sites: Array[Dictionary] = []
var _old_ammo: Array[Node3D] = []
var _city_ammo: Array[Node3D] = []

func build() -> void:
	if _built: return
	_built = true
	name = "CyberBird"
	_cube = BoxMesh.new()
	_cube.size = Vector3.ONE
	_unit_faces = _cube.get_faces()
	_make_materials()
	_city_ground()
	for row in 8:
		for col in 8:
			var district: int = (0 if col < 4 else 1) + (0 if row < 4 else 2)
			var center := Vector3(-308.0 + col * 88.0 - 9.0,0,-308.0 + row * 88.0)
			var floors: int = 3 + ((col * 7 + row * 3) % 10)
			if Vector2(center.x,center.z).length() < 100: floors = 6
			if col == 2 and row == 3: floors = 16
			if col == 5 and row == 4: floors = 15
			var width: float = 28.0 + ((col + row) % 3) * 3.0
			var depth: float = 30.0 + ((col * 3 + row) % 3) * 3.0
			_building(center,width,depth,floors,district,row * 8 + col)
			if (col + row) % 4 == 0:
				_building(center + Vector3(32,0,-23),14,23,3,district,100 + row * 8 + col)
			_street_furniture(center,district,row * 8 + col)
	_sky_routes()
	_landmarks()
	_boundary()
	_make_environment()
	spawn = global_position + Vector3(-9,.16,365)
	set_process(false)

func _make_materials() -> void:
	var shader := load("res://assets/cyber_bird/weathered.gdshader") as Shader
	for entry in [["road","14212c",.72,.24],["concrete","344350",.10,.77],["metal","172935",.76,.30],["copper","855645",.72,.35],["floor","3d454c",.30,.53],["warmwall","675950",.15,.72]]:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("base_color",Color(entry[1]))
		mat.set_shader_parameter("metal",float(entry[2]))
		mat.set_shader_parameter("rough",float(entry[3]))
		if entry[0]=="floor": mat.set_shader_parameter("floor_finish",1.0)
		if entry[0] in ["floor","warmwall"]: mat.set_shader_parameter("bounce_color",Color(.24,.16,.085))
		materials[entry[0]] = mat
	for entry in [["cyan","21e9ef"],["pink","fb458e"],["gold","ffd17d"],["violet","9a7bff"],["white","e6f6ff"]]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(entry[1])
		mat.emission_enabled = true
		mat.emission = Color(entry[1])
		mat.emission_energy_multiplier = 3.5
		materials[entry[0]] = mat
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("070f19")
	dark.roughness = .34
	dark.metallic = .5
	materials["dark"] = dark

func _begin_chunk(title: String, at := Vector3.ZERO) -> void:
	_chunk = Node3D.new()
	_chunk.name = title
	add_child(_chunk)
	_chunk.position = at
	_batches = {}
	_faces = PackedVector3Array()

func _box(at: Vector3, size: Vector3, material: String, solid := true, detail := false, basis := Basis.IDENTITY) -> void:
	var transform := Transform3D(basis.scaled_local(size),at)
	var key := material + (":detail" if detail else ":shell")
	if not _batches.has(key): _batches[key] = []
	_batches[key].append(transform)
	statistics.boxes += 1
	if solid:
		for vertex in _unit_faces: _faces.append(transform * vertex)

func _beam(a: Vector3, b: Vector3, thickness: float, material: String, solid := false) -> void:
	var axis := b - a
	if axis.length() < .001: return
	var basis := Basis.looking_at(axis.normalized(),Vector3.FORWARD if absf(axis.normalized().y) > .99 else Vector3.UP)
	_box((a+b)*.5,Vector3(thickness,thickness,axis.length()),material,solid,false,basis)

func _finish_chunk(terrain := false) -> void:
	for key in _batches:
		var instances: Array = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _cube
		mm.instance_count = instances.size()
		for i in instances.size(): mm.set_instance_transform(i,instances[i])
		var view := MultiMeshInstance3D.new()
		view.name = str(key).replace(":","_")
		view.multimesh = mm
		view.material_override = materials[str(key).get_slice(":",0)]
		view.visibility_range_end = 170 if str(key).ends_with(":detail") else 950
		# Opaque distance culling. No alpha fades in stereo.
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if str(key).get_slice(":",0) in ["cyan","pink","gold","violet","white"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_chunk.add_child(view)
		statistics.batches += 1
	if not _faces.is_empty():
		var body := StaticBody3D.new()
		body.name = "ArchitectureCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("climbable")
		if terrain: body.add_to_group("construction_terrain")
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(_faces)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		_chunk.add_child(body)
		statistics.collision_triangles += _faces.size() / 3
	_batches.clear()
	_faces.clear()

func _sign(text: String, at: Vector3, color: String, size := .045, rotation := 0.0) -> void:
	var label := Label3D.new()
	label.name = "Sign_" + text.replace("\n","_")
	label.text = text
	label.font_size = 96
	label.pixel_size = size
	label.modulate = (materials[color] as StandardMaterial3D).albedo_color
	label.outline_size = 4
	label.outline_modulate = Color("07101b")
	label.no_depth_test = false
	label.shaded = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.visibility_range_end = 300
	_chunk.add_child(label)
	label.position = at
	label.rotation.y = rotation

func _city_ground() -> void:
	# Sixteen physical ground chunks, no missing underside or unrendered barriers.
	for z in 4:
		for x in 4:
			_begin_chunk("Ground_%d_%d" % [x,z],Vector3(-300+x*200,0,-300+z*200))
			_box(Vector3(0,-2,0),Vector3(200,4,200),"road")
			_finish_chunk(true)
	for n in 9:
		var axis := -352.0 + n*88
		_begin_chunk("Avenue_%d" % n)
		for k in range(-38,39):
			_box(Vector3(axis,.012,k*10),Vector3(.15,.022,3.4),"gold",false,true)
			_box(Vector3(k*10,.012,axis),Vector3(3.4,.022,.15),"gold",false,true)
		for side in [-1.0,1.0]:
			_box(Vector3(axis+side*10,.055,0),Vector3(.35,.11,780),"concrete")
			_box(Vector3(0,.055,axis+side*10),Vector3(780,.11,.35),"concrete")
		_finish_chunk()

func _building(center: Vector3, width: float, depth: float, floors: int, district: int, id: int) -> void:
	var accent: String = ["cyan","pink","gold","violet"][district]
	_begin_chunk("Building_%03d_%s" % [id,DISTRICTS[district].replace(" ","_")],center)
	var sx := width*.5-5
	var body_mat: String = "copper" if district == 2 else "concrete"
	var descriptor := {"id":id,"center":center,"width":width,"depth":depth,"floors":floors,"district":DISTRICTS[district],"stair_x":sx}
	buildings.append(descriptor)
	for level in floors+1:
		var y := level*STOREY
		var floor_y := y+.012 # Keep the finished slab above the ground, avoiding coplanar flicker.
		# Floor with an actual 8 x 12 metre switchback opening.
		_box(Vector3(-4.5,floor_y-.14,0),Vector3(width-9,.28,depth),"floor")
		_box(Vector3(width*.5-.5,floor_y-.14,0),Vector3(1,.28,depth),"floor")
		for side in [-1.0,1.0]:
			_box(Vector3(sx,floor_y-.14,side*(depth*.25+3)),Vector3(8,.28,depth*.5-6),"floor")
		# A full-width lower landing reaches both flights and the main corridor.
		_box(Vector3(sx,floor_y-.14,-5.05),Vector3(8,.28,2.1),"floor")
		loot_points.append(global_position+center+Vector3(-width*.24,y+.65,-depth*.22))
		if level == floors: break
		statistics.floors += 1
		_stairs(sx,y)
		# Structural skin is divided into sills, lintels and piers. Every bay is open.
		for side in [-1.0,1.0]:
			_facade(center,width,depth,y,side,false,body_mat,id,level)
			_facade(center,depth,width,y,side,true,body_mat,id,level)
		# A lightwell/corridor and two offset partitions create alternate paths.
		if width > 20:
			for sign_value in [-1.0,1.0]:
				_box(Vector3(-width*.18,y+1.5,sign_value*(depth*.25+1.7)),Vector3(.22,3,depth*.5-7),"warmwall")
				_box(Vector3(-width*.18+sign_value*3,y+1.5,sign_value*3.5),Vector3(3.8,3,.22),"warmwall")
				_box(Vector3(-width*.18+sign_value*4,y+.55,sign_value*(depth*.5-3)),Vector3(2.5,1.1,1),"metal",true,true)
		_box(Vector3(-width*.23,y+3.91,-depth*.22),Vector3(4,.06,.25),"gold",false,true)
		_box(Vector3(sx,y+3.93,-5),Vector3(2.4,.06,.2),accent,false,true)
		_box(Vector3(-3,y+.018,-7),Vector3(width*.47,.025,.045),"gold",false,true)
		if level < 4:
			_sign("%02d  /  ROOF ↑" % level,Vector3(sx-3.8,y+2.0,-6.15),accent,.004)
		_light_sites.append({"at":global_position+center+Vector3(-width*.23,y+2.9,-depth*.22),"color":Color("ffbb79")})
		_light_sites.append({"at":global_position+center+Vector3(sx,y+2.8,1),"color":Color("ffbb79")})
		if level%2==0:
			# Useful local cover: consoles, booths and service benches, clear of circulation.
			_box(Vector3(-width*.34,y+.55,-depth*.33),Vector3(2.3,1.1,1.2),"metal",true,true)
			_box(Vector3(-width*.34,y+1.12,-depth*.33),Vector3(2,.04,.8),accent,false,true)
			_box(Vector3(-width*.35,y+.4,depth*.25),Vector3(1.1,.8,3.4),"copper",true,true)
		if width>20: _interior_program(width,depth,y,level,district,id)
		# Exterior service balcony every third storey with separate side access.
		if level % 3 == 0:
			var z := depth*.5+1.8
			_box(Vector3(-3,y-.15,z),Vector3(width-4,.3,3.6),"metal")
			for x in [-width*.5+1,width*.5-7]:
				_box(Vector3(x,y+.58,z),Vector3(.18,1.16,3.6),"metal")
			for x in [-width*.3,width*.1]:
				_box(Vector3(x,y+.56,z+1.7),Vector3(3.4,1.12,.25),"concrete")
	# Roof parapets have gaps at the four approach axes; nests split long angles.
	var roof := floors*STOREY
	for side in [-1.0,1.0]:
		for section in [-1.0,1.0]:
			_box(Vector3(section*(width*.25+2.5),roof+.55,side*(depth*.5-.2)),Vector3(width*.5-5,1.1,.4),body_mat)
			_box(Vector3(side*(width*.5-.2),roof+.55,section*(depth*.25+2.5)),Vector3(.4,1.1,depth*.5-5),body_mat)
	for k in (1 if id>=100 else 3):
		_box(Vector3(-width*.3+k*3.7,roof+.9,depth*.15),Vector3(2.2,1.8,3),"metal")
		_box(Vector3(-width*.3+k*3.7,roof+1.82,depth*.15),Vector3(2,.04,2.8),accent,false)
	_nest(Vector3(-4.5,roof,0),minf(4.3,(width-9)*.38),accent)
	# Four different roof profiles: fan roofs, solar wings, service crowns, cooling fins.
	if id<100 and id%4==0:
		for side in [-1.0,1.0]:
			_box(Vector3(side*width*.27,roof+3.2,-depth*.25),Vector3(width*.43,.32,8),"metal",true,false,Basis(Vector3.FORWARD,side*.22))
			_beam(Vector3(side*width*.45,roof+4.1,-depth*.25),Vector3(side*width*.08,roof+2.5,-depth*.25),.16,accent)
	elif id<100 and id%4==1:
		for fin in 5:
			_box(Vector3(width*.25,roof+1.5,(-2+fin)*1.5),Vector3(3,3,.24),"copper")
	elif id<100 and id%4==2:
		_box(Vector3(width*.2,roof+2,-depth*.2),Vector3(4,4,5),"metal")
		_feather(Vector3(width*.2,roof+6,-depth*.2),2.3,accent)
	elif id<100:
		for fin in 3:
			_beam(Vector3(-width*.4+fin*3,roof,-depth*.4),Vector3(-width*.4+fin*3,roof+8-fin*1.5,-depth*.4),.4,"copper",true)
	if id in [26,37]: _bird(Vector3(-5,roof+11,3),7,accent,id==26)
	_neon_sites.append({"at":global_position+center+Vector3(-4.5,roof+2,0),"color":(materials[accent] as StandardMaterial3D).albedo_color})
	for side in [-1.0,1.0]:
		_box(Vector3(side*(width*.5+.06),roof*.5,0),Vector3(.1,roof,.17),accent,false)
		for y in range(2,mini(floors,8),2):
			_feather(Vector3(side*(width*.5+.12),y*STOREY,depth*.25),2.3,accent,PI*.5)
	if id < 100:
		var title: String = ["HERON\nTRANSIT","FEATHER\nARCADE","ROOK\nWORKS","CROWN\nHABITAT"][district]
		_box(Vector3(-width*.28,6,depth*.5+1),Vector3(6,5,.4),"dark")
		_sign(title,Vector3(-width*.28,6,depth*.5+1.23),accent,.012)
		if id % 8 == 3: _sign(DISTRICTS[district],Vector3(0,roof+4,0),accent,.04)
	_finish_chunk()
	# A solid service partition provides conservative occlusion without sealing windows.
	if width > 20:
		for level in floors:
			var occluder := OccluderInstance3D.new()
			var box := BoxOccluder3D.new()
			box.size = Vector3(.18,2.9,depth*.5-7)
			occluder.occluder = box
			_chunk.add_child(occluder)
			occluder.position = Vector3(-width*.18,level*STOREY+1.5,depth*.25+1.7)

func _facade(center: Vector3, span: float, perpendicular: float, y: float, side: float, rotated: bool, mat: String, id: int, level: int) -> void:
	var bays := maxi(2,int(span/6))
	var step := span/bays
	for i in bays:
		var u := -span*.5+step*(i+.5)
		# A central door on all four elevations of every floor connects balconies/bridges.
		var door := i == bays/2 or (level == 0 and i == bays/2-1)
		var sill := 0.0 if door else .92
		var pos := Vector3(u,y+sill*.5,side*perpendicular*.5)
		var size := Vector3(step,sill,.32)
		if sill > 0: _box(_swap(pos,rotated),_swap(size,rotated),mat)
		_box(_swap(Vector3(u,y+3.85,side*perpendicular*.5),rotated),_swap(Vector3(step,.7,.32),rotated),mat)
		_box(_swap(Vector3(-span*.5+i*step,y+2.1,side*perpendicular*.5),rotated),_swap(Vector3(.48,4.2,.48),rotated),"metal")
		var local := _swap(Vector3(u,y+2,side*perpendicular*.5),rotated)
		windows.append({"at":global_position+center+local,"normal":_swap(Vector3(0,0,side),rotated),"building":id,"floor":level,"door":door,"width":step-.48,"sill":sill})
	_box(_swap(Vector3(span*.5,y+2.1,side*perpendicular*.5),rotated),_swap(Vector3(.48,4.2,.48),rotated),"metal")

func _interior_program(width: float, depth: float, y: float, level: int, district: int, id: int) -> void:
	var accent: String=["cyan","pink","gold","violet"][district]
	var room_z := depth*.27
	# Trim and illuminated door headers make the circulation legible at human height.
	for side in [-1.0,1.0]:
		_box(Vector3(-width*.18-.13,y+1.03,side*(depth*.25+1.7)),Vector3(.06,.09,depth*.5-7),"copper",false,true)
		_box(Vector3(-width*.18-.13,y+2.72,side*(depth*.25+1.7)),Vector3(.06,.05,depth*.5-7),accent,false,true)
	_box(Vector3(-width*.18,y+2.9,0),Vector3(.22,.18,6.7),"metal")
	_box(Vector3(-width*.18-.14,y+2.88,0),Vector3(.025,.055,5.8),accent,false,true)
	# Distinct uses and silhouettes in each district; none seal the stair or exit lane.
	match district:
		0:
			# Heron terminal lounges, destination boards and baggage sorting benches.
			for seat in 3:
				var at := Vector3(-width*.35,y,-4+seat*3.2)
				_box(at+Vector3(0,.48,0),Vector3(2.4,.18,1.1),"copper")
				_box(at+Vector3(0,.95,-.45),Vector3(2.4,.9,.18),"metal")
				for leg in [-1.0,1.0]: _box(at+Vector3(leg*.8,.22,0),Vector3(.14,.44,.75),"metal",false,true)
			_box(Vector3(-1.5,y+1,room_z),Vector3(5.8,2,1.3),"metal")
			_box(Vector3(-1.5,y+2.1,room_z),Vector3(5.5,.16,1.4),"copper")
			_box(Vector3(-1.5,y+1.5,room_z+.67),Vector3(4.4,.08,.035),"cyan",false,true)
			if level%3==0: _sign("HERON / TRANSIT\nNIGHT LINE  •  %02d"%level,Vector3(-1.5,y+2.8,room_z+.72),"gold",.004)
		1:
			# Market noodle counters / arcade workstations and seating booths.
			_box(Vector3(-1.4,y+.58,room_z),Vector3(6.2,1.16,1.4),"copper")
			_box(Vector3(-1.4,y+1.2,room_z),Vector3(6.4,.12,1.6),"metal")
			for station in 3:
				var at := Vector3(-3.4+station*2,y,room_z)
				_box(at+Vector3(0,1.75,-.4),Vector3(1.3,.9,.2),"dark")
				_box(at+Vector3(0,1.75,-.28),Vector3(1.1,.67,.035),"pink",false,true)
				_box(at+Vector3(0,.4,1.8),Vector3(.8,.8,.8),"metal")
			for side in [-1.0,1.0]:
				_box(Vector3(-width*.36,y+.55,side*depth*.23),Vector3(2.3,1.1,2.7),"copper")
				_box(Vector3(-width*.36,y+1.13,side*depth*.23),Vector3(1.5,.05,2.2),"dark",false,true)
			if level%3==0: _sign("PLUMAGE\nNOODLES / ARCADE",Vector3(-1.4,y+2.8,room_z+.85),"pink",.0045)
		2:
			# Foundry relay racks, service benches and compact machinery cover.
			for server in 3:
				var at := Vector3(-width*.36,y,-5+server*4.5)
				_box(at+Vector3(0,1.25,0),Vector3(2.6,2.5,1.7),"metal")
				for vent in 5:
					_box(at+Vector3(0,.5+vent*.35,.88),Vector3(2,.09,.06),"copper",false,true)
				_box(at+Vector3(.9,1.9,.9),Vector3(.15,.5,.04),"gold",false,true)
			_box(Vector3(-1.5,y+.7,room_z),Vector3(6,1.4,1.6),"copper")
			for machine in 2:
				_box(Vector3(-3+machine*3,y+1.9,room_z),Vector3(1.2,2.4,1.1),"metal")
			if level%3==0: _sign("ROOK / RELAY %02d\nMAINTENANCE LOOP"%level,Vector3(-1.5,y+3.2,room_z+1),"gold",.004)
		3:
			# Crown tea lounges and sleeping alcoves with low firing cover.
			for side in [-1.0,1.0]:
				var at := Vector3(-width*.36,y,side*depth*.25)
				_box(at+Vector3(0,.35,0),Vector3(2.2,.7,3.4),"metal")
				_box(at+Vector3(0,.8,-1.35),Vector3(2.2,1.6,.24),"copper")
				_box(at+Vector3(0,.73,0),Vector3(1.9,.06,2.7),"warmwall",false,true)
			_box(Vector3(-1.5,y+.5,room_z),Vector3(4.6,1,2),"copper")
			for side in [-1.0,1.0]:
				_box(Vector3(-1.5+side*3.2,y+.5,room_z),Vector3(1.1,1,3),"metal")
				_box(Vector3(-1.5+side*3.6,y+1.2,room_z),Vector3(.28,1.4,3),"warmwall")
			if level%3==0: _sign("CROWN / TEA LOUNGE\nNEST %03d / %02d"%[id,level],Vector3(-1.5,y+2.8,room_z+1.2),"violet",.004)

func _swap(v: Vector3, rotated: bool) -> Vector3:
	return Vector3(v.z,v.y,v.x) if rotated else v

func _stairs(sx: float, y: float) -> void:
	# Twenty-four 175mm risers. Both flights are 2.3m wide; landing 1.8m deep.
	for step in 12:
		var rise := (step+1)*.175
		var z := -3.8+step*.60
		_box(Vector3(sx-1.3,y+rise*.5,z),Vector3(2.3,rise,.60),"metal")
		_box(Vector3(sx+1.3,y+2.1+rise*.5,2.8-step*.60),Vector3(2.3,rise,.60),"metal")
		_box(Vector3(sx-1.3,y+rise+.012,z-.29),Vector3(2.3,.024,.04),"gold",false,true)
		_box(Vector3(sx+1.3,y+2.1+rise+.012,3.09-step*.60),Vector3(2.3,.024,.04),"gold",false,true)
	_box(Vector3(sx,y+1.96,4),Vector3(5.2,.28,1.8),"floor")
	# Solid slim central divider and guard at the landing; the walking lanes stay clear.
	_box(Vector3(sx,y+1.6,0),Vector3(.16,3.2,6.8),"metal")
	_box(Vector3(sx,y+2.65,4.85),Vector3(5.3,1.1,.16),"metal")
	routes.append({"kind":"stairs","from":global_position+_chunk.position+Vector3(sx-1.3,y,-4.4),"to":global_position+_chunk.position+Vector3(sx+1.3,y+STOREY,-4.4)})
	statistics.stairs += 1

func _nest(at: Vector3, radius: float, accent: String) -> void:
	for i in 12:
		var angle := i*TAU/12
		var tangent := Basis(Vector3.UP,-angle)
		_box(at+Vector3(cos(angle)*radius,.65,sin(angle)*radius),Vector3(.35,1.3,1.65),"copper",true,false,tangent)
		if i%3==0: _box(at+Vector3(cos(angle)*radius,1.35,sin(angle)*radius),Vector3(.4,.07,1.65),accent,false,false,tangent)

func _feather(at: Vector3, length: float, accent: String, rotation := 0.0) -> void:
	var orientation := Basis(Vector3.UP,rotation)
	_beam(at+orientation*Vector3(0,-length,0),at+orientation*Vector3(0,length,0),.10,accent)
	for i in 5:
		var y := -length*.7+i*length*.32
		var width := length*(.58-absf(float(i)-2)*.11)
		for side in [-1.0,1.0]:
			_beam(at+orientation*Vector3(0,y,0),at+orientation*Vector3(side*width,y+length*.5,0),.095,accent)

func _street_furniture(center: Vector3, district: int, id: int) -> void:
	var accent: String = ["cyan","pink","gold","violet"][district]
	_neon_sites.append({"at":global_position+center+Vector3(-15,3.6,29),"color":(materials[accent] as StandardMaterial3D).albedo_color})
	var service_z := 24.0 if (floori(float(id)/8)+id%8)%4==0 else -24.0
	_begin_chunk("Courtyard_%d" % id,center)
	# Irregular truck bays, planters, service islands and vendor awnings break street angles.
	for k in 4:
		var x: float = -20+k*12
		var z: float = -29 if k%2==0 else 29
		_box(Vector3(x,.55,z),Vector3(3.6,1.1,2),"concrete")
		_box(Vector3(x,1.18,z),Vector3(3.2,.16,1.6),"copper")
		_box(Vector3(x,1.3,z),Vector3(.15,.2,1.65),accent,false)
		loot_points.append(global_position+center+Vector3(x+2.6,.7,z))
	for side in [-1.0,1.0]:
		_box(Vector3(side*34,3.4,service_z),Vector3(.32,6.8,.32),"metal")
		_beam(Vector3(side*34,6.5,service_z),Vector3(side*29,6.5,service_z),.22,"metal",true)
		_box(Vector3(side*29,6.4,service_z),Vector3(2,.12,.6),"gold",false)
	_box(Vector3(25,1.1,service_z),Vector3(6,2.2,3.2),"metal")
	_box(Vector3(25,2.25,service_z),Vector3(5,.1,2.4),accent,false,true)
	for side in [-1.0,1.0]:
		_box(Vector3(-15+side*6,1.6,26),Vector3(.15,3.2,.15),"copper")
	_box(Vector3(-15,3.3,26),Vector3(13,.25,6),"metal")
	_feather(Vector3(-15,5.9,28.9),2,accent)
	if id%4==0:
		_box(Vector3(-15,1.0,26),Vector3(7,2,1.2),"warmwall")
		_sign(["HERON / NIGHT FERRY","PLUMAGE / NIGHT MARKET","ROOK / FABRICATION","NEST / ROOFTOP CLUB"][district],Vector3(-15,3.9,29),accent,.008)
	if district==1:
		# Market kiosks form close alleys at street level, with lit wing awnings.
		for stall in 3:
			var at := Vector3(-20+stall*7,0,-27)
			_box(at+Vector3(0,.6,0),Vector3(4,1.2,2),"copper")
			_box(at+Vector3(0,3,0),Vector3(5.7,.2,4.4),"metal",true,false,Basis(Vector3.FORWARD,.12))
			_box(at+Vector3(0,2.8,2.2),Vector3(5,.2,.12),"pink",false)
	elif district==2:
		for pipe in 3:
			_beam(Vector3(28+pipe*1.2,0,23),Vector3(28+pipe*1.2,9+pipe*3,23),.6,"copper",true)
		_box(Vector3(28,4.1,23),Vector3(6,.2,5),"metal")
	elif district==0:
		for blade in 5:
			_beam(Vector3(-27+blade*1.2,0,25),Vector3(-27+blade*1.2,4+blade*.6,25),.26,"cyan")
	else:
		_nest(Vector3(22,0,26),4,"violet")
	_finish_chunk()

func _bridge(a: Vector3, b: Vector3, accent: String, index: int) -> void:
	_begin_chunk("SkyBridge_%02d" % index)
	var direction := (b-a).normalized()
	var length := a.distance_to(b)
	var basis := Basis.looking_at(direction,Vector3.UP)
	var mid := (a+b)*.5
	_box(mid-Vector3.UP*.15,Vector3(3.6,.3,length),"metal",true,false,basis)
	for side in [-1.0,1.0]:
		_box(mid+basis.x*side*1.73+Vector3.UP*.55,Vector3(.16,1.1,length),"metal",true,false,basis)
		_box(mid+basis.x*side*1.75+Vector3.UP*1.14,Vector3(.08,.08,length),accent,false,false,basis)
	# Opposing cover leaves a1.7m passing lane and interrupts a single bridge sightline.
	for t in [.28,.70]:
		var side := -1.0 if t<.5 else 1.0
		_box(a.lerp(b,t)+basis.x*side*1.2+Vector3.UP*.7,Vector3(1.0,1.4,2.6),"concrete",true,false,basis)
		_box(a.lerp(b,t)-Vector3.UP*3,Vector3(.35,6,.35),"copper")
	_finish_chunk()
	routes.append({"kind":"bridge","from":global_position+a,"to":global_position+b})
	statistics.bridges += 1

func _sky_routes() -> void:
	var index := 0
	for row in [2,3,4,5]:
		for col in [2,3,4]:
			var a: Dictionary = buildings.filter(func(v: Dictionary): return v.id==row*8+col)[0]
			var b: Dictionary = buildings.filter(func(v: Dictionary): return v.id==row*8+col+1)[0]
			var y := STOREY*(2 if row%2==0 else 3)
			# East/west center bays are door-height openings. Bridge has broad flush ends.
			var za: float = -float(a.depth)*.5 + float(a.depth)/int(float(a.depth)/6)*(int(int(float(a.depth)/6)/2)+.5)
			var zb: float = -float(b.depth)*.5 + float(b.depth)/int(float(b.depth)/6)*(int(int(float(b.depth)/6)/2)+.5)
			_bridge(a.center+Vector3(float(a.width)*.5-.4,y,za),b.center+Vector3(-float(b.width)*.5+.4,y,zb),"cyan" if row<4 else "pink",index)
			index+=1
	for col in [2,5]:
		for row in [2,3,4]:
			var a: Dictionary = buildings.filter(func(v: Dictionary): return v.id==row*8+col)[0]
			var b: Dictionary = buildings.filter(func(v: Dictionary): return v.id==(row+1)*8+col)[0]
			var xa: float = -float(a.width)*.5+float(a.width)/int(float(a.width)/6)*(int(int(float(a.width)/6)/2)+.5)
			var xb: float = -float(b.width)*.5+float(b.width)/int(float(b.width)/6)*(int(int(float(b.width)/6)/2)+.5)
			_bridge(a.center+Vector3(xa,STOREY*2,float(a.depth)*.5-.4),b.center+Vector3(xb,STOREY*2,-float(b.depth)*.5+.4),"gold",index)
			index+=1

func _landmarks() -> void:
	_begin_chunk("Aviary_Cathedral")
	# Open industrial aviary: elevated ring, immense wing ribs, accessible lower dais.
	for side in [-1.0,1.0]:
		for k in 7:
			var z: float = -24+k*8
			_beam(Vector3(side*24,0,z),Vector3(side*18,34,z),.65,"metal",true)
			_beam(Vector3(side*18,34,z),Vector3(0,44,z),.48,"copper",true)
			_beam(Vector3(side*18,34,z),Vector3(side*4,41,z),.18,"cyan")
		_box(Vector3(side*22,.6,0),Vector3(3,1.2,48),"concrete")
	_nest(Vector3.ZERO,10,"cyan")
	_bird(Vector3(0,22,0),12,"cyan",false)
	_sign("CYBER BIRD",Vector3(0,14,25),"cyan",.060)
	_sign("AVIARY / 00",Vector3(0,8,25),"gold",.022)
	_finish_chunk()
	_begin_chunk("Heron_Spire",Vector3(-185,0,-80))
	_bird(Vector3(0,28,0),10,"gold",true)
	_box(Vector3(0,12,0),Vector3(3,24,3),"metal")
	_nest(Vector3(0,.1,0),8,"gold")
	_sign("HERON QUAY",Vector3(0,7,7),"cyan",.025)
	_finish_chunk()
	_begin_chunk("SafeSpawn_NightTerminal",Vector3(-9,0,365))
	_box(Vector3(0,5,0),Vector3(24,.7,22),"metal")
	# Broad opaque blast baffles shield spawn with two dogleg exits.
	for side in [-1.0,1.0]:
		_box(Vector3(side*11,2.5,0),Vector3(.6,5,22),"concrete")
		_box(Vector3(side*6,1.5,-10),Vector3(10,3,.7),"concrete")
		_box(Vector3(side*8,2.5,10),Vector3(6,5,.6),"concrete")
	_box(Vector3(0,2,-5),Vector3(7,4,.6),"metal")
	_feather(Vector3(0,2.7,-4.65),1.0,"cyan")
	_sign("CYBER BIRD\nNIGHT TERMINAL",Vector3(0,3.1,9.6),"cyan",.014,PI)
	_sign("HERON ←     AVIARY ↑     CROWN →",Vector3(0,5.9,-10),"gold",.009,PI)
	loot_points.append(global_position+Vector3(-9,.7,369))
	_light_sites.append({"at":global_position+Vector3(-9,3.7,368),"color":Color("ffbb79")})
	_neon_sites.append({"at":global_position+Vector3(-9,2.8,361),"color":Color("21e9ef")})
	_finish_chunk()

func _bird(at: Vector3, size: float, accent: String, heron: bool) -> void:
	# Abstract original sculpture: long-necked heron / angular raven, cut-metal feathers.
	_beam(at-Vector3.UP*size*.35,at+Vector3.UP*size*.3,size*.18,"metal",true)
	var neck: Vector3 = at+Vector3(0,size*(.95 if heron else .45),-size*.12)
	_beam(at,neck,size*.09,"copper",true)
	_beam(neck,neck+Vector3(size*.32,0,0),size*.075,accent)
	for side in [-1.0,1.0]:
		for feather in 8:
			var spread: float = .25+feather*.11
			var end := at+Vector3(side*size*spread,size*(.52-feather*.035),size*(feather*.07-.2))
			_beam(at+Vector3(0,-feather*.15,0),end,size*.065,"metal",true)
			_beam(end,end+Vector3(side*size*.22,-size*.36,size*.09),size*.035,accent)

func _boundary() -> void:
	_begin_chunk("Finished_City_Seawall")
	for side in [-1.0,1.0]:
		_box(Vector3(side*397,12,0),Vector3(6,24,800),"metal")
		_box(Vector3(0,12,side*397),Vector3(788,24,6),"metal")
		_box(Vector3(side*397,24.1,0),Vector3(6,.2,800),"cyan",false)
		_box(Vector3(0,24.1,side*397),Vector3(788,.2,6),"pink",false)
		# Physical, opaque skyline fins continue upward. A marked ceiling catches flight.
		_box(Vector3(side*399,222,0),Vector3(2,396,800),"dark")
		_box(Vector3(0,222,side*399),Vector3(796,396,2),"dark")
		for k in range(-7,8):
			_box(Vector3(side*393,20,k*50),Vector3(3,40,5),"concrete")
			_box(Vector3(k*50,20,side*393),Vector3(5,40,3),"concrete")
	_finish_chunk()
	_begin_chunk("Visible_Flight_Canopy")
	_box(Vector3(0,421,0),Vector3(800,2,800),"dark")
	_finish_chunk()
	for view in _chunk.get_children():
		if view is GeometryInstance3D: view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _make_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("07101f")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("799bb9")
	_environment.ambient_light_energy = .48
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.glow_enabled = true
	_environment.glow_intensity = .9
	_environment.glow_bloom = .14
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("1d3043")
	_environment.fog_density = .0018
	var light := DirectionalLight3D.new()
	light.name = "City_Moon"
	light.light_color = Color("9ac8ed")
	light.light_energy = .7
	light.rotation_degrees = Vector3(-47,-24,0)
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 110
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(light)
	for i in 6:
		var local_light := OmniLight3D.new()
		local_light.name = "Nearest_Interior_Light_%d" % i
		local_light.omni_range = 12
		local_light.light_energy = 2.3
		local_light.shadow_enabled = false
		add_child(local_light)
		_local_lights.append(local_light)

func enter(game: Node) -> void:
	_game = game
	position = Vector3(0,0,2400)
	build()
	_previous_environment = get_world_3d().environment
	get_world_3d().environment = _environment
	get_viewport().use_occlusion_culling = true
	game.world.hide()
	game.active_sandbox_map = self
	game.player.global_position = spawn
	game.player.reset_motion()
	_old_ammo.assign(game.ammo_pickups.boxes)
	game._begin_chapter()
	game.training.reset()
	game.mission_label.text = MAP_TITLE
	update_lighting(game.player.get_view_camera().global_position)
	set_process(true)

func refresh_loot() -> void:
	if not is_instance_valid(_game) or _refresh_pending: return
	_refresh_pending = true
	# _begin_chapter completes its normal reset before city placement; no duplicate ammo.
	_place_loot.call_deferred()

func _place_loot() -> void:
	if not is_instance_valid(_game): return
	var inventory: Node = _game.weapon_inventory
	var i := 0
	var pickup_ids: Array = inventory.pickups.keys()
	pickup_ids.sort()
	for id in pickup_ids:
		var prop: Node3D = inventory.pickups[id]
		# Existing finite, grabbable instances; never scenery replicas or altered quantities.
		var b: Dictionary = buildings[(i*17)%buildings.size()]
		var level: int = 0 if i%3==0 else (mini(2,int(b.floors)-1) if i%3==1 else int(b.floors))
		prop.global_position = global_position+b.center+Vector3(-float(b.width)*.24,level*STOREY+.65,-float(b.depth)*.22)
		if i%4==0: prop.global_position = global_position+b.center+Vector3(-17,.65,-29)
		if i==0: prop.global_position = spawn+Vector3(-3,.65,4)
		inventory.review_positions[id] = prop.global_position
		inventory._settle_pickup_id.call_deferred(prop.get_instance_id())
		i+=1
	for old in _city_ammo:
		if is_instance_valid(old):
			_game.ammo_pickups.boxes.erase(old)
			old.queue_free()
	_city_ammo.clear()
	for old in _old_ammo:
		if is_instance_valid(old):old.hide()
	# Six existing supply categories, original per-box amounts; distributed in32 caches.
	for cache in 32:
		var b: Dictionary = buildings[(cache*13)%buildings.size()]
		var level: int = 0 if cache%3==0 else (1 if cache%3==1 else int(b.floors))
		var point: Vector3 = global_position+b.center+Vector3(-float(b.width)*.25,level*STOREY+.65,float(b.depth)*.28)
		if cache%4==0: point = global_position+b.center+Vector3(-17,.65,-29)
		if cache==0: point=spawn+Vector3(-4,.65,3)
		for category in 6:
			var family: String = _game.ammo_pickups.families[category]
			var prop: Node3D = _game.ammo_pickups.spawn_box(family,point+Vector3((category%3)*.65,0,(category/3)*.65))
			_city_ammo.append(prop)
	for index in _game.field_consumables.pickups.size():
		var prop: Node3D = _game.field_consumables.pickups[index]
		var b: Dictionary = buildings[(index*19)%buildings.size()]
		prop.global_position = global_position+b.center+Vector3(-float(b.width)*.25,(int(b.floors)*STOREY if index%3==2 else 0)+.7,2)
		if index in [0,9]: prop.global_position=spawn+Vector3(3+(index%2),.7,4-(index%2))
		inventory._settle_pickup_id.call_deferred(prop.get_instance_id())
	_game.mission_label.text = MAP_TITLE
	_refresh_pending = false

func _process(delta: float) -> void:
	if not is_instance_valid(_game): return
	_clock += delta
	if _clock < .5: return
	_clock = 0
	var eye: Vector3 = _game.player.get_view_camera().global_position
	update_lighting(eye)
	if _game.player.global_position.y < -12:
		_game.player.global_position = spawn
		_game.player.reset_motion()

func update_lighting(eye: Vector3) -> void:
	var sites := _light_sites.duplicate()
	sites.sort_custom(func(a: Dictionary,b: Dictionary): return eye.distance_squared_to(a.at)<eye.distance_squared_to(b.at))
	var neon := _neon_sites.duplicate()
	neon.sort_custom(func(a: Dictionary,b: Dictionary): return eye.distance_squared_to(a.at)<eye.distance_squared_to(b.at))
	for i in _local_lights.size():
		var site: Dictionary = sites[i] if i<3 else neon[i-3]
		_local_lights[i].global_position = site.at
		_local_lights[i].light_color = site.color
		_local_lights[i].light_energy = 6.5 if i<3 else 3.4
		_local_lights[i].omni_range = 18 if i<3 else 14
		_local_lights[i].visible = eye.distance_squared_to(site.at)<65*65

func leave() -> void:
	set_process(false)
	if is_instance_valid(_game):
		get_world_3d().environment = _previous_environment
		for prop in _city_ammo:
			_game.ammo_pickups.boxes.erase(prop)
			if is_instance_valid(prop): prop.queue_free()
		for prop in _old_ammo:
			if is_instance_valid(prop): prop.show()
	_city_ammo.clear()
