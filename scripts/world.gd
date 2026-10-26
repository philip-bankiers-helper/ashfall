class_name AshWorld
extends Node3D
## Original modular alpine hydroelectric relay installation.
## All architecture with collision is intentionally hand-climbable.

var player_spawn := Vector3(0, 1, 8)
var extraction_position := Vector3(0, 0.2, 15)
var extraction_spawn_points: Array[Vector3] = [Vector3(12, 0.2, 12), Vector3(10, 0.2, 0), Vector3(-14, 0.2, 0), Vector3(-14, 0.2, 12), Vector3(7, 0.2, -2), Vector3(-6, 0.2, -1)]
var objective_positions: Array[Vector3] = [Vector3(0, 2, -16), Vector3(-18, 9, -44), Vector3(15, 17, -70)]
var enemy_spawn_points: Array[Vector3] = [Vector3(-7, 1, -14), Vector3(7, 1, -22), Vector3(-12, 1, -30), Vector3(-20, 9, -46), Vector3(-15, 9, -42), Vector3(4, 1, -47), Vector3(13, 17, -72), Vector3(19, 17, -68), Vector3(12, 1, -61)]
var encounter_spawns: Array = [
	[Vector3(-8, 0.2, -13), Vector3(8, 0.2, -23), Vector3(-3, 1.2, -15), Vector3(3, 1.2, -17)],
	[Vector3(-20, 8.2, -43), Vector3(-15, 8.2, -43), Vector3(-23, 8.2, -48), Vector3(-13, 8.2, -40), Vector3(-8, 8.2, -47), Vector3(-18, 8.2, -38.5)],
	[Vector3(11, 16.2, -65), Vector3(17, 16.2, -65), Vector3(21, 16.2, -69), Vector3(9, 16.2, -72), Vector3(20, 16.2, -75), Vector3(13, 16.2, -70), Vector3(17, 16.2, -70), Vector3(8, 16.2, -58)]
]
var mats: Dictionary = {}
var batches: Dictionary = {}
var built := false
var sun_light: DirectionalLight3D
var authored_lights: Array[Light3D] = []
var last_light_sample: Dictionary = {}
var graphics_quality := "balanced"
var _rescue_arrival_tween: Tween
var destructible_fixtures: Array[StaticBody3D] = []

func reset_environment_damage() -> void:
	for fixture in destructible_fixtures:
		if is_instance_valid(fixture): fixture.reset_fixture()

func _shootable_light(pos: Vector3, energy: float, reach: float) -> void:
	var fixture = preload("res://scripts/light_fixture.gd").new()
	fixture.position = pos
	add_child(fixture)
	fixture.setup(energy, reach)
	destructible_fixtures.append(fixture)
	authored_lights.append(fixture.light)

func set_graphics_quality(mode: String) -> Dictionary:
	graphics_quality = "high" if mode == "high" else "balanced"
	var high := graphics_quality == "high"
	if is_instance_valid(sun_light):
		sun_light.directional_shadow_max_distance = 130.0 if high else 85.0
		sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if is_inside_tree():
		get_viewport().msaa_3d = Viewport.MSAA_4X if high else Viewport.MSAA_2X
		get_viewport().positional_shadow_atlas_size = 4096 if high else 2048
	return {"mode": graphics_quality, "msaa": 4 if high else 2, "sun_shadow_cascades": 4 if high else 2, "sun_shadow_distance_m": 130 if high else 85, "local_shadow_atlas": 4096 if high else 2048, "material_resolution": "2K"}

func reset_extraction_arrival() -> void:
	if is_instance_valid(_rescue_arrival_tween): _rescue_arrival_tween.kill()
	_rescue_arrival_tween = null
	if is_instance_valid(rescue_craft):
		for i in range(authored_lights.size() - 1, -1, -1):
			var light := authored_lights[i]
			if not is_instance_valid(light) or rescue_craft.is_ancestor_of(light): authored_lights.remove_at(i)
		rescue_craft.hide()
		rescue_craft.queue_free()
	rescue_craft = null
	_rescue_rotors.clear()
	_rescue_beacon = null
	_rescue_time = 0.0
	_rescue_landed = false
	set_process(false)

func get_light_exposure(point: Vector3) -> float:
	if not is_inside_tree(): return 0.12
	var space := get_world_3d().direct_space_state
	var sun_visible := false
	var exposure := 0.12
	var local_contribution := 0.0
	if is_instance_valid(sun_light) and sun_light.visible:
		var toward_sun := sun_light.global_transform.basis.z.normalized()
		var ray := PhysicsRayQueryParameters3D.create(point, point + toward_sun * 220.0, 1)
		sun_visible = space.intersect_ray(ray).is_empty()
		if sun_visible: exposure += clampf(sun_light.light_energy / 1.15, 0, 1) * 0.72
	for light in authored_lights:
		if not is_instance_valid(light) or not light.visible or light.light_energy <= 0: continue
		var reach: float = light.omni_range if light is OmniLight3D else light.spot_range
		var distance := point.distance_to(light.global_position)
		if distance >= reach: continue
		if light is SpotLight3D and distance > 0.01:
			var facing := -light.global_transform.basis.z.normalized()
			if facing.dot((point - light.global_position).normalized()) < cos(deg_to_rad(light.spot_angle)): continue
		var ray := PhysicsRayQueryParameters3D.create(point, light.global_position, 1)
		if not space.intersect_ray(ray).is_empty(): continue
		local_contribution += pow(1.0 - distance / reach, 2) * minf(light.light_energy, 3.0) * 0.32
	exposure = clampf(exposure + local_contribution, 0.0, 1.0)
	last_light_sample = {"point": point, "sun_visible": sun_visible, "local_contribution": local_contribution, "exposure": exposure}
	return exposure

func _local_light(pos: Vector3, color: Color, energy: float, reach: float, shadows: bool = false) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = shadows
	add_child(light)
	authored_lights.append(light)
var rescue_craft: Node3D
var _rescue_rotors: Array[Node3D] = []
var _rescue_time := 0.0
var _rescue_landed := false
var _rescue_beacon: OmniLight3D

func build() -> void:
	if built: return
	built = true
	_make_materials()
	_atmosphere()
	_landscape()
	_staging()
	_extraction()
	_relay_yard()
	_turbine_tower()
	_uplink()
	_connections()
	_scatter()
	_detailed_props()
	_facility_detail()
	_construction_detail()
	_turbine_landmark_detail()
	_scanned_environment()
	_flush_batches()
	set_graphics_quality(graphics_quality)
	set_process(false)

func start_extraction_arrival() -> void:
	if is_instance_valid(rescue_craft): return
	rescue_craft = Node3D.new()
	rescue_craft.name = "KESTREL civilian rescue VTOL"
	add_child(rescue_craft)
	rescue_craft.position = Vector3(0, 35, 80)
	_craft_hull(rescue_craft)
	# Cockpit, emergency access doors and skid undercarriage.
	_craft_box(rescue_craft, Vector3(0, 0.55, -1.7), Vector3(1.8, 0.75, 1.6), "glass", Vector3(-0.16, 0, 0))
	_craft_box(rescue_craft, Vector3(0, 0.96, -1.7), Vector3(0.07, 0.08, 1.6), "trim")
	_craft_box(rescue_craft, Vector3(0, 0.60, -2.51), Vector3(0.07, 0.7, 0.04), "trim")
	for side in [-1.0, 1.0]:
		_craft_box(rescue_craft, Vector3(side * 1.25, 0, 0.1), Vector3(0.10, 1.5, 2.2), "orange")
		_craft_box(rescue_craft, Vector3(side * 1.32, 0.38, -0.1), Vector3(0.035, 0.55, 1.15), "glass")
		_craft_box(rescue_craft, Vector3(side * 1.35, -0.12, 0.7), Vector3(0.06, 0.10, 0.35), "white")
		_craft_box(rescue_craft, Vector3(side * 1.0, -1.2, 0), Vector3(0.18, 0.16, 4.1), "steel")
		for z in [-1.2, 1.2]:
			_craft_box(rescue_craft, Vector3(side * 1.0, -0.85, z), Vector3(0.13, 0.7, 0.13), "trim")
		_craft_box(rescue_craft, Vector3(side * 2.25, 0.5, 0.2), Vector3(2.6, 0.24, 1.15), "white", Vector3(0, 0, side * -0.08))
		_craft_box(rescue_craft, Vector3(side * 3.4, 0.7, 0.2), Vector3(0.65, 0.75, 1.7), "orange")
		_craft_box(rescue_craft, Vector3(side * 3.4, 1.28, 0.2), Vector3(0.15, 0.6, 0.15), "trim")
		for j in range(5):
			_craft_box(rescue_craft, Vector3(side * 3.4, 0.48 + j * 0.11, 1.08), Vector3(0.5, 0.06, 0.035), "black")
		var rotor := Node3D.new()
		rotor.position = Vector3(side * 3.4, 1.6, 0.2)
		rescue_craft.add_child(rotor)
		_rescue_rotors.append(rotor)
		for blade in range(3):
			var arm := Node3D.new()
			arm.rotation.y = blade * TAU / 3
			rotor.add_child(arm)
			_craft_box(arm, Vector3(1.05, 0, 0), Vector3(2.1, 0.045, 0.16), "black")
			_craft_box(arm, Vector3(1.95, 0.005, 0), Vector3(0.22, 0.05, 0.17), "yellow")
		_craft_box(rescue_craft, Vector3(side * 1.0, -0.4, -2.3), Vector3(0.25, 0.14, 0.12), "cyan")
		var searchlight := SpotLight3D.new()
		searchlight.position = Vector3(side * 0.9, -0.5, -1.8)
		searchlight.rotation_degrees.x = -75
		searchlight.light_color = Color(0.65, 0.85, 1.0)
		searchlight.light_energy = 5
		searchlight.spot_range = 20
		searchlight.spot_angle = 28
		searchlight.shadow_enabled = false
		rescue_craft.add_child(searchlight)
		authored_lights.append(searchlight)
	# Tall tail and small horizontal stabilizer provide a recognizable silhouette.
	_craft_box(rescue_craft, Vector3(0, 0.55, 2.4), Vector3(0.18, 1.8, 1.2), "orange", Vector3(-0.3, 0, 0))
	_craft_box(rescue_craft, Vector3(0, 0.22, 2.8), Vector3(3.2, 0.12, 0.8), "white")
	_craft_box(rescue_craft, Vector3(0, 1.43, 2.2), Vector3(0.17, 0.17, 0.25), "red")
	_rescue_beacon = OmniLight3D.new()
	_rescue_beacon.position = Vector3(0, 1.5, 2.2)
	_rescue_beacon.light_color = Color(1, 0.12, 0.04)
	_rescue_beacon.omni_range = 5
	_rescue_beacon.shadow_enabled = false
	rescue_craft.add_child(_rescue_beacon)
	set_process(true)
	var arrival := create_tween()
	_rescue_arrival_tween = arrival
	arrival.tween_property(rescue_craft, "position", extraction_position + Vector3(0, 10, 5), 8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arrival.tween_property(rescue_craft, "position", extraction_position + Vector3(0, 5.5, 0), 4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrival.tween_callback(func(): _rescue_landed = true)

func _process(delta: float) -> void:
	if not is_instance_valid(rescue_craft): return
	_rescue_time += delta
	for i in range(_rescue_rotors.size()):
		_rescue_rotors[i].rotate_y(delta * (26.0 if i == 0 else -26.0))
	_rescue_beacon.light_energy = 2.0 if fmod(_rescue_time, 1.3) < 0.12 else 0.0
	rescue_craft.rotation.z = sin(_rescue_time * 1.4) * 0.012
	if _rescue_landed:
		rescue_craft.position.y = extraction_position.y + 5.5 + sin(_rescue_time * 1.8) * 0.07

func _craft_box(parent: Node3D, pos: Vector3, size: Vector3, material: String, rot: Vector3 = Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mats[material]
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)

func _craft_hull(parent: Node3D) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	for ring in [Vector3(0.55, 0.40, -2.7), Vector3(1.30, 0.75, -1.1), Vector3(1.25, 0.70, 1.1), Vector3(0.50, 0.40, 2.6)]:
		for corner in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1)]:
			points.append(Vector3(corner.x * ring.x, corner.y * ring.y, ring.z))
	for ring in range(3):
		for side in range(4):
			var a := ring * 4 + side
			var b := ring * 4 + (side + 1) % 4
			for idx in [a, a + 4, b, b, a + 4, b + 4]:
				surface.add_vertex(points[idx])
	for idx in [0, 1, 2, 0, 2, 3, 12, 14, 13, 12, 15, 14]:
		surface.add_vertex(points[idx])
	surface.generate_normals()
	var hull_material: StandardMaterial3D = mats["white"].duplicate()
	hull_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(hull_material)
	var hull := MeshInstance3D.new()
	hull.mesh = surface.commit()
	parent.add_child(hull)

func _mat(key: String, color: Color, roughness: float = 0.8, metal: float = 0.0, grain: bool = false) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metal
	if grain:
		var noise := FastNoiseLite.new()
		noise.seed = 671 + key.length() * 31
		noise.frequency = 0.045
		noise.fractal_octaves = 3
		var tex := NoiseTexture2D.new()
		tex.width = 256
		tex.height = 256
		tex.seamless = true
		tex.noise = noise
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.48, 0.48, 0.48))
		gradient.set_color(1, Color(1, 1, 1))
		tex.color_ramp = gradient
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.22, 0.22, 0.22)
	mats[key] = m

func _make_materials() -> void:
	_mat("concrete", Color(0.48, 0.51, 0.51), 0.94, 0, true)
	_mat("dark_concrete", Color(0.24, 0.29, 0.30), 0.97, 0, true)
	_mat("steel", Color(0.15, 0.20, 0.22), 0.62, 0.45)
	_mat("deck", Color(0.28, 0.32, 0.34), 1.0, 0.0)
	_mat("trim", Color(0.39, 0.46, 0.47), 0.32, 0.8)
	_mat("rust", Color(0.40, 0.19, 0.095), 0.82, 0.48, true)
	_mat("orange", Color(0.88, 0.29, 0.07), 0.48, 0.35)
	_mat("yellow", Color(0.97, 0.65, 0.12), 0.62, 0.3)
	_mat("black", Color(0.035, 0.047, 0.05), 0.88)
	_mat("snow", Color(0.79, 0.86, 0.88), 0.99, 0, true)
	_mat("rock", Color(0.23, 0.29, 0.32), 1, 0, true)
	_mat("water", Color(0.06, 0.20, 0.25), 0.17, 0.42)
	_mat("glass", Color(0.08, 0.24, 0.29), 0.14, 0.62)
	_mat("white", Color(0.84, 0.88, 0.85), 0.5)
	for entry in [["cyan", Color(0.15, 0.85, 1)], ["amber", Color(1, 0.43, 0.09)], ["red", Color(0.9, 0.08, 0.035)]]:
		_mat(entry[0], entry[1], 0.4)
		mats[entry[0]].emission_enabled = true
		mats[entry[0]].emission = entry[1]
		mats[entry[0]].emission_energy_multiplier = 2.2
	_apply_pbr("concrete", "concrete/Concrete034_2K-JPG", 0.35)
	_apply_pbr("dark_concrete", "concrete/Concrete034_2K-JPG", 0.35)
	_apply_pbr("deck", "metal/MetalPlates006_2K-JPG", 0.35)
	_apply_pbr("rock", "rock/Rock030_2K-JPG", 0.035)
	# Poly Haven Blue Metal Plate / Rob Tuytel / CC0, verified2K PBR maps.
	var steel: StandardMaterial3D = mats["steel"]
	steel.albedo_texture = load("res://assets/materials/painted_steel/color.jpg")
	steel.albedo_color = Color(0.85,0.87,0.88)
	steel.roughness_texture = load("res://assets/materials/painted_steel/Rough.jpg")
	steel.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	steel.roughness = 0.90
	steel.normal_enabled = true
	steel.normal_texture = load("res://assets/materials/painted_steel/nor_gl.jpg")
	steel.normal_scale = 0.28
	steel.metallic = 0.08
	steel.metallic_specular = 0.22
	steel.uv1_triplanar = true
	steel.uv1_world_triplanar = true
	steel.uv1_scale = Vector3.ONE * 0.28
	steel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

func _apply_pbr(key: String, source: String, tiling: float) -> void:
	var prefix := "res://assets/materials/" + source
	var material: StandardMaterial3D = mats[key]
	if not ResourceLoader.exists(prefix + "_Color.jpg"): return
	material.albedo_texture = load(prefix + "_Color.jpg")
	material.albedo_color = Color.WHITE
	if key == "concrete": material.albedo_color = Color(0.58, 0.62, 0.63)
	if key == "dark_concrete": material.albedo_color = Color(0.22, 0.28, 0.31)
	material.roughness_texture = load(prefix + "_Roughness.jpg")
	material.normal_enabled = true
	material.normal_texture = load(prefix + "_NormalGL.jpg")
	material.normal_scale = 0.28
	material.metallic_specular = 0.18
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * tiling
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if ResourceLoader.exists(prefix + "_Metalness.jpg"):
		material.metallic_texture = load(prefix + "_Metalness.jpg")
		material.metallic = 0.25
		material.roughness = 0.95
	if key == "deck":
		material.metallic = 0.0
		material.metallic_specular = 0.1
		material.roughness_texture = null
		material.roughness = 1.0
		material.normal_scale = 0.12

func _atmosphere() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color(0.12, 0.23, 0.36)
	atmosphere.sky_horizon_color = Color(0.63, 0.70, 0.73)
	atmosphere.ground_bottom_color = Color(0.13, 0.18, 0.22)
	atmosphere.ground_horizon_color = Color(0.63, 0.70, 0.73)
	atmosphere.sun_angle_max = 10
	sky.sky_material = atmosphere
	var sky_path := "res://assets/environment/kloofendal_overcast_puresky_2k.hdr"
	if ResourceLoader.exists(sky_path):
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = load(sky_path)
		panorama.energy_multiplier = 0.4
		sky.sky_material = panorama
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_color = Color(0.60, 0.72, 0.85)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.48, 0.61, 0.69)
	e.fog_density = 0.0012
	e.fog_sky_affect = 0.18
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Late afternoon alpine sun"
	sun.rotation_degrees = Vector3(-38, -38, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100
	add_child(sun)
	sun_light = sun

func _landscape() -> void:
	_box(Vector3(0, -1.5, -35), Vector3(76, 3, 112), "dark_concrete", true, Vector3.ZERO, true, false, true)
	# Monolithic dam with articulated buttresses behind the playable installation.
	_box(Vector3(0, 9, -91), Vector3(110, 30, 7), "concrete", true)
	_box(Vector3(0, 24.3, -91), Vector3(112, 0.6, 9), "trim", true)
	for x in range(-50, 51, 10):
		_box(Vector3(x, 7, -86.5), Vector3(2.8, 28, 4), "dark_concrete", true)
		_box(Vector3(x, 24.8, -87.5), Vector3(0.15, 1, 0.15), "steel")
		_box(Vector3(x, 24.64, -91), Vector3(0.18, 0.025, 8), "yellow")
	for x in [-35.0, 35.0]:
		_box(Vector3(x, 0.8, -37), Vector3(1.2, 1.6, 103), "concrete", true)
		for z in range(-80, 14, 8):
			_box(Vector3(x, 1.7, z), Vector3(1.35, 0.1, 1.2), "snow")
	_box(Vector3(0, -8, 77), Vector3(500, 0.2, 210), "water")
	_box(Vector3(-85, -3, -140), Vector3(90, 0.2, 160), "water")
	var rng := RandomNumberGenerator.new()
	rng.seed = 8131
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		var pos := Vector3(cos(angle) * rng.randf_range(175, 260), -12, -45 + sin(angle) * rng.randf_range(190, 280))
		_mountain(pos, rng.randf_range(52, 100), rng.randf_range(70, 165), i)

func _staging() -> void:
	_box(Vector3(0, 0.025, 8), Vector3(13, 0.05, 10), "deck", true)
	for x in [-5.8, 5.8]:
		_box(Vector3(x, 0.07, 8), Vector3(0.16, 0.04, 9), "yellow")
	for z in [3.5, 12.5]:
		_box(Vector3(0, 0.07, z), Vector3(11.6, 0.04, 0.16), "yellow")
	# Sheltered arrival platform and original field equipment.
	_box(Vector3(-9, 1.6, 6), Vector3(4, 3.2, 7), "steel", true)
	_box(Vector3(-9, 3.25, 6), Vector3(4.3, 0.16, 7.3), "snow")
	for z in range(3, 10):
		_box(Vector3(-6.96, 1.6, z), Vector3(0.08, 2.8, 0.10), "trim")
	for x in [-5, 5]:
		_box(Vector3(x, 1.6, 2), Vector3(0.16, 3.2, 0.16), "steel", true)
	_box(Vector3(0, 3.1, 2), Vector3(10.2, 0.2, 0.3), "steel")
	for i in range(3):
		_crate(Vector3(7 + i * 1.5, 0.6, 7 - i), Vector3(1.3, 1.2, 1.3))

func _extraction() -> void:
	# Low-profile landing apron doubles as the return-glide navigation target.
	_box(Vector3(0, 0.055, 15), Vector3(12, 0.11, 10), "deck", true)
	for x in [-5.7, 5.7]:
		_box(Vector3(x, 0.125, 15), Vector3(0.13, 0.03, 9.6), "cyan")
	for z in [10.3, 19.7]:
		_box(Vector3(0, 0.125, z), Vector3(11.5, 0.03, 0.13), "cyan")
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.65
	torus.outer_radius = 3.85
	torus.rings = 40
	torus.ring_segments = 6
	torus.material = mats["yellow"]
	ring.mesh = torus
	ring.position = Vector3(0, 0.135, 15)
	ring.scale.y = 0.15
	add_child(ring)
	for x in [-1.1, 1.1]:
		_box(Vector3(x, 0.135, 15), Vector3(0.3, 0.03, 3.2), "white")
	_box(Vector3(0, 0.135, 15), Vector3(2.5, 0.03, 0.3), "white")
	for x in [-6.4, 6.4]:
		for z in [10.5, 19.5]:
			_box(Vector3(x, 0.4, z), Vector3(0.45, 0.8, 0.45), "steel", true)
			_cylinder(Vector3(x, 0.9, z), 0.17, 0.25, "cyan")
	for x in [-6.4, 6.4]:
		var light := OmniLight3D.new()
		light.position = Vector3(x, 1.2, 15)
		light.light_color = Color(0.15, 0.75, 1)
		light.light_energy = 0.7
		light.omni_range = 7
		light.shadow_enabled = false
		add_child(light)
		authored_lights.append(light)
	_box(Vector3(0, 1.1, 20.2), Vector3(4.5, 1.4, 0.15), "black", true)
	_label("EXTRACTION", Vector3(0, 1.1, 20.30), 0.013, Color(0.3, 0.9, 1))
	# A matching front-facing beacon sign makes the pad legible on the return glide.
	var back := Label3D.new()
	back.text = "EXTRACTION"
	back.position = Vector3(0, 1.2, 20.10)
	back.rotation.y = PI
	back.pixel_size = 0.008
	back.font_size = 32
	back.modulate = Color(0.3, 0.9, 1)
	back.outline_size = 0
	add_child(back)

func _relay_yard() -> void:
	_platform(Vector3(0, 0.5, -16), Vector3(12, 1, 12))
	_stairs(Vector3(0, 0, -7.2), 4, 0.25, 0.7, 4)
	_box(Vector3(0, 3.8, -20.5), Vector3(12, 5.6, 1), "concrete", true)
	_box(Vector3(-5.7, 3.8, -16), Vector3(0.6, 5.6, 9), "concrete", true)
	_box(Vector3(0, 6.7, -17), Vector3(13, 0.25, 9), "steel", true)
	for x in [-4, 0, 4]:
		_box(Vector3(x, 4.7, -19.95), Vector3(3.4, 2.2, 0.08), "glass")
		_box(Vector3(x, 2.1, -19.92), Vector3(3.4, 0.1, 0.1), "cyan")
	_label("RELAY", Vector3(0, 6.08, -11.95), 0.034, Color.WHITE)
	for x in [-3.5, 3.5]:
		_box(Vector3(x, 2.2, -18.7), Vector3(1.4, 2.4, 1), "steel", true)
		for j in range(4):
			_box(Vector3(x, 1.5 + j * 0.43, -18.18), Vector3(1.1, 0.23, 0.05), "black")
		_box(Vector3(x - 0.35, 3.1, -18.13), Vector3(0.18, 0.18, 0.08), "amber")
	for x in [11.0, 18.0]:
		_cylinder(Vector3(x, 2, -20), 1.6, 4, "trim", true)
		for y in [0.5, 3.5]:
			_cylinder(Vector3(x, y, -20), 1.72, 0.15, "rust")
		_box(Vector3(x, 2, -18.37), Vector3(0.65, 1.2, 0.03), "yellow")
		_pipe(Vector3(x, 4.1, -20), Vector3(x, 4.1, -27), 0.32, "rust")
	for x in [-12.0, 12.0]:
		_lamp(Vector3(x, 0, -8))
		_lamp(Vector3(x, 0, -28))

func _turbine_tower() -> void:
	_box(Vector3(-18, 3.75, -44), Vector3(14, 7.5, 14), "concrete", true)
	# Roof collision stays flush with the facade so hand climbing can mantle cleanly.
	_platform(Vector3(-18, 7.8, -44), Vector3(14, 0.4, 14))
	_box(Vector3(-18, 11, -49.5), Vector3(10, 6, 2), "steel", true)
	for x in [-22.5, -18.0, -13.5]:
		# Match the rendered facade for shots/marks without adding tiny climb steps.
		_box(Vector3(x, 3.6, -36.95), Vector3(3.6, 5.7, 0.09), "steel",false,Vector3.ZERO,true,true)
		for y in [1.2, 2.0, 2.8, 3.6, 4.4, 5.2, 6.0]:
			_box(Vector3(x, y, -36.85), Vector3(3.3, 0.08, 0.15), "trim",false,Vector3.ZERO,true,true)
	_label("TURBINE", Vector3(-18, 7.0, -36.7), 0.038, Color(1, 0.7, 0.24))
	for x in [-24.8, -11.2]:
		_box(Vector3(x, 4, -36.7), Vector3(0.18, 8, 0.18), "orange", true)
		for y in range(1, 8):
			_box(Vector3(x, y, -36.5), Vector3(0.7, 0.09, 0.3), "yellow", true)
	for x in [-22.0, -17.5, -13.0]:
		_cylinder(Vector3(x, 8.7, -46), 1.25, 1.4, "steel", true)
		_cylinder(Vector3(x, 9.42, -46), 0.93, 0.08, "black")
		for a in range(4):
			_box(Vector3(x, 9.48, -46), Vector3(1.6, 0.06, 0.09), "steel", false, Vector3(0, a * PI / 4, 0))
	_rail(Vector3(-25.2, 8, -44), 14, true)
	_rail(Vector3(-18, 8, -51.2), 14, false)
	# Switchback stair access keeps the campaign playable in desktop debug.
	_stairs(Vector3(-29, 0, -28.5), 20, 0.2, 0.6, 3)
	_platform(Vector3(-27, 3.8, -42.5), Vector3(7, 0.4, 4))
	_stairs(Vector3(-25, 4, -43.9), 20, 0.2, 0.6, 3, true)
	_platform(Vector3(-23, 7.8, -30.4), Vector3(7, 0.4, 3))
	_platform(Vector3(-20.7, 7.8, -34.5), Vector3(2.4, 0.4, 6))

func _uplink() -> void:
	_box(Vector3(15, 7.75, -70), Vector3(16, 15.5, 16), "dark_concrete", true)
	_platform(Vector3(15, 15.8, -70), Vector3(16, 0.4, 16))
	for x in [7.3, 22.7]:
		_box(Vector3(x, 8, -61.8), Vector3(0.5, 16, 0.6), "orange", true)
	for y in [3.5, 7.5, 11.5]:
		_box(Vector3(15, y, -61.85), Vector3(14.5, 0.22, 0.4), "trim", true)
		for x in [10.0, 15.0, 20.0]:
			_box(Vector3(x, y + 1.3, -61.95), Vector3(4, 2, 0.08), "glass")
	_label("UPLINK", Vector3(15, 14.5, -61.6), 0.052, Color.WHITE)
	_box(Vector3(15, 17.5, -75), Vector3(7, 3, 4), "steel", true)
	_box(Vector3(15, 19.1, -75), Vector3(7.3, 0.2, 4.3), "snow")
	for x in [12.0, 18.0]:
		_box(Vector3(x, 18, -72.94), Vector3(0.12, 1.7, 0.05), "cyan")
	for y in range(20, 33, 3):
		_pipe(Vector3(13, y, -75), Vector3(17, y + 3, -75), 0.065, "trim")
		_pipe(Vector3(17, y, -75), Vector3(13, y + 3, -75), 0.065, "trim")
	for x in [13.0, 17.0]:
		_pipe(Vector3(x, 19, -75), Vector3(x, 35, -75), 0.10, "steel")
	for y in [24.0, 29.0, 33.0]:
		_box(Vector3(12.6, y, -75), Vector3(0.5, 2, 0.6), "white")
		_box(Vector3(17.4, y, -75), Vector3(0.5, 2, 0.6), "white")
	_cylinder(Vector3(15, 35.3, -75), 0.15, 0.6, "red")
	_rail(Vector3(23.5, 16, -70), 16, true)
	_rail(Vector3(15, 16, -78.5), 16, false)
	# Wide front lip is an explicit launch zone; no rail across the landing.
	_box(Vector3(15, 16.03, -61.4), Vector3(9, 0.05, 0.3), "yellow")

func _connections() -> void:
	# Mid-height service bridge links tower to uplink with a stair route.
	_platform(Vector3(-2, 7.8, -47), Vector3(20, 0.4, 3))
	_rail(Vector3(-2, 8, -48.4), 20, false)
	for x in [-9.0, 2.0]:
		_box(Vector3(x, 3.8, -47), Vector3(0.4, 7.6, 0.4), "steel", true)
		_pipe(Vector3(x - 2, 0, -47), Vector3(x + 2, 7.6, -47), 0.12, "rust")
	_stairs(Vector3(6, 8, -47.5), 20, 0.2, 0.6, 3)
	_platform(Vector3(5, 11.8, -61.5), Vector3(5, 0.4, 4))
	_stairs(Vector3(2.5, 12, -63), 20, 0.2, 0.6, 3, true)
	_platform(Vector3(5, 15.8, -49.5), Vector3(8, 0.4, 3))
	_platform(Vector3(8, 15.8, -56), Vector3(2.5, 0.4, 12))
	# A secondary climbing route through the central industrial scaffold.
	for x in [-3.0, 3.0]:
		for z in [-33.0, -39.0]:
			_box(Vector3(x, 6, z), Vector3(0.35, 12, 0.35), "orange", true)
	for y in [3.0, 6.0, 9.0, 12.0]:
		_box(Vector3(0, y, -39), Vector3(6.4, 0.2, 0.35), "steel", true)
		_box(Vector3(0, y, -33), Vector3(6.4, 0.2, 0.35), "steel", true)
		_pipe(Vector3(-3, y - 3, -33), Vector3(3, y, -33), 0.07, "trim")
	_platform(Vector3(0, 12, -36), Vector3(7, 0.25, 7))
	_box(Vector3(0, 12.15, -32.5), Vector3(5, 0.05, 0.2), "yellow")
	for z in [-26.0, -56.0]:
		_pipe(Vector3(-32, 5, z), Vector3(32, 5, z), 0.32, "rust")
		for x in [-32.0, 32.0]:
			_box(Vector3(x, 2.5, z), Vector3(0.4, 5, 0.4), "steel", true)
	# Overhead sagging power lines, composed of short cylinder spans.
	for offset in [-0.4, 0.0, 0.4]:
		for i in range(12):
			var a := float(i) / 12
			var b := float(i + 1) / 12
			_pipe(Vector3(-18 + a * 33, 15 + a * 10 - sin(a * PI) * 4, -49 + a * -26 + offset), Vector3(-18 + b * 33, 15 + b * 10 - sin(b * PI) * 4, -49 + b * -26 + offset), 0.025, "black")

func _scatter() -> void:
	for entry in [Vector3(-9, 0.8, -5), Vector3(8, 0.8, -13), Vector3(-8, 0.8, -27), Vector3(9, 0.8, -34), Vector3(-3, 0.8, -52), Vector3(20, 0.8, -51), Vector3(28, 0.8, -68), Vector3(-21, 8.6, -40), Vector3(19, 16.6, -66)]:
		_crate(entry, Vector3(2.1, 1.6, 1.3))
	for z in range(-76, 8, 8):
		_box(Vector3(0, 0.025, z), Vector3(0.16, 0.03, 3), "yellow")
	for z in [-10.0, -30.0, -54.0, -76.0]:
		_lamp(Vector3(29, 0, z))
		_box(Vector3(-32, 0.05, z), Vector3(4, 0.1, 5), "snow")
	for x in [-29.0, 27.0]:
		for z in [-17.0, -44.0, -70.0]:
			_box(Vector3(x, 0.15, z), Vector3(3, 0.3, 5), "concrete", true)
			_cylinder(Vector3(x, 1.4, z), 0.65, 2.5, "rust", true)
			_cylinder(Vector3(x, 2.7, z), 0.72, 0.12, "trim")

func _detailed_props() -> void:
	# CC0 Poly Haven close-range assets; alternate collection pieces are stripped
	# from game scene roots. Original glTFs and provenance remain in assets/models.
	_model_prop("portable_generator", Vector3(-5, 0, 6), 1.4, -0.25, true)
	_model_prop("portable_generator", Vector3(3.5, 1, -13), 1.4, 0.35, true)
	for placement in [Vector3(4.5, 0, 5), Vector3(-4.4, 1, -13.8), Vector3(-23, 8, -41.5), Vector3(21, 16, -66)]:
		_model_prop("old_military_crate", placement, 1.5, 0.12, true)
	for placement in [Vector3(-4.6, 3.3, -19.9), Vector3(4.6, 3.3, -19.9), Vector3(-15, 11.5, -48.45), Vector3(12.5, 18.3, -72.95)]:
		_model_prop("industrial_caged_sconce", placement, 1.7, 0, false)
	for placement in [Vector3(-31, 0, -4), Vector3(32, 0, -35), Vector3(-32, 0, -59), Vector3(31, 0, -80)]:
		_model_prop("rock_07", placement, 15, placement.z * 0.13, true)

func _model_prop(asset: String, pos: Vector3, uniform_scale: float, yaw: float, collision: bool) -> void:
	var path := "res://assets/models/" + asset + "/" + asset + "_game.gltf"
	if not ResourceLoader.exists(path): return
	var packed := load(path) as PackedScene
	if packed == null: return
	var model := packed.instantiate() as Node3D
	var bounds := _prop_bounds(model)
	model.position = pos
	model.scale = Vector3.ONE * uniform_scale
	model.rotation.y = yaw
	model.name = "CC0_" + asset
	add_child(model)
	if collision:
		var body := StaticBody3D.new()
		body.set_meta("surface", "wood" if asset == "old_military_crate" else ("gravel" if asset.begins_with("rock_") else "metal"))
		body.add_to_group("climbable")
		if asset == "rock_07":
			# Irregular static rocks require their visible surface: the old bounds
			# box made low sloping edges into a 2.15 m invisible vertical wall.
			_add_prop_surface_collision(model, model.transform.affine_inverse(), body)
			body.add_to_group("ballistic_proxy_ignore")
			# A closed hull gives stable head/support collision. Ballistic rays
			# use the authored triangles instead, so decals sit on visible rock.
			var ballistic := StaticBody3D.new()
			ballistic.name = "RockBallisticSurface"
			ballistic.collision_layer = 8
			ballistic.collision_mask = 0
			ballistic.set_meta("surface", "gravel")
			ballistic.add_to_group("ballistic_surface")
			_add_prop_surface_collision(model, model.transform.affine_inverse(), ballistic, true)
			model.add_child(ballistic)
		elif asset.begins_with("rock_face_"):
			# Preserve scanned recesses/overhangs: convex bounds would fill visible air.
			body.name = "ScannedTerrainSurface"
			body.collision_layer = 9
			body.collision_mask = 0
			body.add_to_group("terrain_surface")
			body.add_to_group("ballistic_surface")
			_add_prop_surface_collision(model, model.transform.affine_inverse(), body, true)
		else:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = bounds.size.max(Vector3(0.05, 0.05, 0.05))
			shape.shape = box
			shape.position = bounds.get_center()
			body.add_child(shape)
		model.add_child(body)
		if asset.begins_with("rock_face_"): _bake_terrain_scale(body)
	_sanitize_prop_materials(model)
	if asset.begins_with("rock_face_"):_opaque_terrain_faces_089(model)

func _opaque_terrain_faces_089(node:Node)->void:
	if node is MeshInstance3D and node.mesh!=null:
		if node.material_override is StandardMaterial3D:
			var finish:StandardMaterial3D=node.material_override.duplicate();finish.cull_mode=BaseMaterial3D.CULL_DISABLED;finish.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED;finish.albedo_color.a=1.0;node.material_override=finish
		for i in node.mesh.get_surface_count():
			var source:Material=node.get_active_material(i)
			if source is StandardMaterial3D:
				var mat:StandardMaterial3D=source.duplicate();mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED;mat.albedo_color.a=1.0
				node.set_surface_override_material(i,mat)
	for child in node.get_children():_opaque_terrain_faces_089(child)

func _bake_terrain_scale(body: StaticBody3D) -> void:
	# Bake imported 10x/12x mesh scaling into immutable triangle vertices.
	# Unscaled physics avoids short foot/head-ray precision loss on tiny source triangles.
	var target := Transform3D(body.global_basis.orthonormalized(), body.global_position)
	for child in body.get_children():
		if not child is CollisionShape3D or not child.shape is ConcavePolygonShape3D: continue
		var into_target: Transform3D = target.affine_inverse() * child.global_transform
		var faces: PackedVector3Array = child.shape.get_faces()
		for i in range(faces.size()): faces[i] = into_target * faces[i]
		child.shape.set_faces(faces)
		child.transform = Transform3D.IDENTITY
	body.top_level = true
	body.global_transform = target

func _add_prop_surface_collision(node: Node3D, parent_transform: Transform3D, body: StaticBody3D, ballistic: bool = false) -> void:
	var relative := parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var shape := CollisionShape3D.new()
		# Close photogrammetry surface holes while retaining each mesh's actual
		# sloped silhouette. A triangle soup can let support rays pass through
		# missing/back-facing faces on an otherwise apparently solid rock.
		# Simplification also removes near-coplanar dense hull degeneracies;
		# high and head-height support rays must agree on the same surface.
		shape.shape = node.mesh.create_trimesh_shape() if ballistic else node.mesh.create_convex_shape(true, true)
		if shape.shape is ConcavePolygonShape3D: shape.shape.backface_collision = true
		shape.transform = relative
		body.add_child(shape)
	for child in node.get_children():
		if child is Node3D: _add_prop_surface_collision(child, relative, body, ballistic)

func _prop_bounds(node: Node3D, parent_transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var t := parent_transform * node.transform
	var bounds := AABB(t.origin, Vector3.ZERO)
	if node is MeshInstance3D and node.mesh != null:
		bounds = t * node.get_aabb()
	for child in node.get_children():
		if child is Node3D: bounds = bounds.merge(_prop_bounds(child, t))
	return bounds

func _sanitize_prop_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for index in range(node.mesh.get_surface_count()):
			var source = node.get_active_material(index)
			if source is StandardMaterial3D:
				var material: StandardMaterial3D = source.duplicate()
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				material.metallic_specular = 0.25
				node.set_surface_override_material(index, material)
	for child in node.get_children(): _sanitize_prop_materials(child)

func _facility_detail() -> void:
	_shootable_light(Vector3(0, 5.25, -16.5), 1.6, 7.5)
	_shootable_light(Vector3(21.5, 3.7, -40), 1.8, 8)
	_shootable_light(Vector3(18, 3.7, -41), 0.9, 5)
	# Control-room equipment remains outside the direct objective approach.
	_box(Vector3(-4.6, 1.42, -16), Vector3(1.3, 0.84, 3), "steel", true)
	_box(Vector3(-4.6, 1.88, -16), Vector3(1.4, 0.08, 3.1), "trim")
	_box(Vector3(-4.6, 2.3, -17), Vector3(0.9, 0.75, 0.12), "black")
	_box(Vector3(-4.6, 2.3, -16.92), Vector3(0.72, 0.55, 0.03), "cyan")
	_box(Vector3(4.4, 1.45, -16), Vector3(1.2, 0.9, 2), "steel", true)
	_box(Vector3(4.4, 1.95, -16), Vector3(1.2, 0.12, 2), "trim", false, Vector3(-0.14, 0, 0))
	for z in [-15.6, -16.2]:
		_box(Vector3(4.4, 2.03, z), Vector3(0.8, 0.03, 0.25), "black")
		for x in [4.1, 4.4, 4.7]:
			_box(Vector3(x, 2.06, z), Vector3(0.08, 0.03, 0.08), "amber")
	for x in [-3.5, 3.5]:
		_box(Vector3(x, 5.7, -16.7), Vector3(0.75, 0.65, 6), "trim")
		for z in [-14.5, -16.5, -18.5]:
			_box(Vector3(x, 5.7, z), Vector3(0.82, 0.7, 0.06), "steel")
		_box(Vector3(x, 5.3, -16), Vector3(0.35, 0.04, 3), "white")
	# Original evacuation diagram: three stations connected to the valley apron.
	_box(Vector3(0, 3.55, -19.9), Vector3(3, 1.6, 0.05), "black")
	for x in [-0.9, 0.0, 0.9]:
		_box(Vector3(x, 3.64, -19.84), Vector3(0.22, 0.22, 0.025), "cyan")
	_box(Vector3(0, 3.64, -19.84), Vector3(1.8, 0.04, 0.025), "cyan")
	# Turbine enclosure: manufactured panel seams, access door, pressure pipework.
	for x in [-22.5, -20.25, -18.0, -15.75, -13.5]:
		_box(Vector3(x, 11, -48.47), Vector3(0.045, 5.6, 0.04), "trim")
	_box(Vector3(-18, 9.35, -48.44), Vector3(2, 2.65, 0.08), "black")
	_box(Vector3(-18, 9.35, -48.38), Vector3(0.05, 2.6, 0.06), "trim")
	for x in [-18.3, -17.7]:
		_box(Vector3(x, 9.25, -48.29), Vector3(0.07, 0.4, 0.08), "white")
	for x in [-22.6, -13.4]:
		_pipe(Vector3(x, 8.2, -48.2), Vector3(x, 13.7, -48.2), 0.1, "rust")
		for y in [8.7, 10.7, 12.7]:
			_box(Vector3(x, y, -48.2), Vector3(0.32, 0.08, 0.32), "trim")
	# A second combat elevation: open condenser gallery and roof launch balcony.
	_box(Vector3(20, 0.025, -39), Vector3(10, 0.05, 14), "concrete", true)
	_box(Vector3(24.8, 2.25, -39), Vector3(0.4, 4.5, 14), "concrete", true)
	_box(Vector3(22, 2.25, -45.8), Vector3(6, 4.5, 0.4), "concrete", true)
	_platform(Vector3(20, 4.3, -39), Vector3(10, 0.4, 14))
	for x in [15.15, 24.85]:
		for z in [-32.15, -45.85]:
			_box(Vector3(x, 2.25, z), Vector3(0.3, 4.5, 0.3), "steel", true)
			_box(Vector3(x, 1.2, z + 0.16), Vector3(0.24, 0.8, 0.025), "yellow")
	_rail(Vector3(24.8, 4.5, -39), 13.6, true)
	_rail(Vector3(20, 4.5, -45.8), 9.6, false)
	_platform(Vector3(11, 4.3, -36), Vector3(8, 0.4, 2.8))
	_rail(Vector3(11, 4.5, -37.3), 8, false)
	_box(Vector3(7.2, 4.53, -36), Vector3(0.16, 0.04, 2.7), "yellow")
	_box(Vector3(17, 3.0, -32.02), Vector3(3, 0.5, 0.06), "black")
	_label("ROOF ACCESS", Vector3(17, 3.0, -31.97), 0.008, Color(1, 0.75, 0.3))
	for z in [-35.5, -41.5]:
		_box(Vector3(23.6, 0.6, z), Vector3(1.6, 1.2, 2.2), "steel", true)
		_box(Vector3(23.6, 1.25, z), Vector3(1.7, 0.1, 2.3), "trim")
		for y in [0.3, 0.55, 0.8, 1.05]:
			_box(Vector3(22.77, y, z), Vector3(0.03, 0.09, 1.9), "black")
		_pipe(Vector3(23.6, 1.3, z), Vector3(23.6, 3.5, z), 0.17, "rust")
	_pipe(Vector3(23.6, 3.5, -35.5), Vector3(23.6, 3.5, -44.5), 0.17, "rust")
	_box(Vector3(18.7, 0.58, -39), Vector3(2.4, 1.16, 1.1), "dark_concrete", true)
	_box(Vector3(18.7, 1.19, -39), Vector3(2.5, 0.06, 1.2), "yellow")
	# Side-lane cover leaves rooftop objective-center approaches clear.
	_box(Vector3(-24, 8.55, -43), Vector3(1.3, 1.1, 2), "steel", true)
	_box(Vector3(10, 16.55, -68), Vector3(1.2, 1.1, 2.6), "steel", true)
	_box(Vector3(19, 16.55, -72), Vector3(1.5, 1.1, 1.2), "steel", true)

func _construction_detail() -> void:
	# Visual-only fittings: the tested collision and navigation geometry is unchanged.
	for x in [-4.0, 0.0, 4.0]:
		_window_frame(Vector3(x, 4.7, -19.88), 3.4, 2.2)
	for y in [4.8, 8.8, 12.8]:
		for x in [10.0, 15.0, 20.0]:
			_window_frame(Vector3(x, y, -61.88), 4, 2)
	# Bolted joints interrupt long pipe spans at physically plausible lengths.
	for z in [-26.0, -56.0]:
		for x in [-24.0, -12.0, 0.0, 12.0, 24.0]:
			_pipe_flange(Vector3(x, 5, z), Vector3.RIGHT, 0.32)
		for x in [-32.0, 32.0]:
			_box(Vector3(x, 4.63, z), Vector3(0.75, 0.16, 0.85), "trim")
			_box(Vector3(x, 4.35, z), Vector3(0.4, 0.65, 0.3), "steel")
	for x in [11.0, 18.0]:
		for z in [-21.4, -25.4]:
			_pipe_flange(Vector3(x, 4.1, z), Vector3.FORWARD, 0.32)
		# Tank identification strip and pressure dial.
		_box(Vector3(x, 2.25, -18.36), Vector3(0.9, 1.45, 0.03), "steel")
		var dial := _cylinder(Vector3(x, 2.1, -18.25), 0.22, 0.10, "trim")
		dial.rotation.x = PI * 0.5
		var face := _cylinder(Vector3(x, 2.1, -18.18), 0.18, 0.025, "white")
		face.rotation.x = PI * 0.5
		_box(Vector3(x + 0.035, 2.14, -18.15), Vector3(0.025, 0.21, 0.02), "red", false, Vector3(0, 0, -0.62))
		for side in [-1.0, 1.0]:
			_box(Vector3(x + side * 1.05, 0.28, -20), Vector3(0.4, 0.5, 1.25), "steel")
			_box(Vector3(x + side * 1.05, 0.08, -20), Vector3(0.8, 0.1, 1.5), "trim")
	# Cable trays connect existing switchgear to the overhead distribution route.
	for x in [-4.9, 4.9]:
		_box(Vector3(x, 3.7, -19.87), Vector3(0.12, 3.3, 0.12), "steel")
		_box(Vector3(x, 5.35, -17), Vector3(0.16, 0.12, 5.8), "steel")
		for offset in [-0.04, 0.04]:
			_pipe(Vector3(x + offset, 2.1, -19.76), Vector3(x + offset, 5.2, -19.76), 0.018, "black")
		for y in [2.3, 3.1, 3.9, 4.7]:
			_box(Vector3(x, y, -19.72), Vector3(0.24, 0.045, 0.04), "trim")
	# Existing hut gains a properly framed, human-scale service entrance.
	_box(Vector3(-10, 1.2, 9.56), Vector3(1.08, 2.4, 0.07), "trim")
	_box(Vector3(-10, 1.19, 9.61), Vector3(0.9, 2.22, 0.04), "black")
	_box(Vector3(-10, 1.65, 9.65), Vector3(0.55, 0.45, 0.03), "glass")
	_box(Vector3(-9.66, 1.05, 9.68), Vector3(0.08, 0.3, 0.08), "trim")
	_window_frame(Vector3(-8.2, 1.7, 9.57), 1.0, 0.8)
	_box(Vector3(-8.2, 1.7, 9.56), Vector3(1, 0.8, 0.03), "glass")
	# Realistic panel fixings and service louvers on the rooftop equipment house.
	for x in [-22.3, -20.1, -15.9, -13.7]:
		for y in [8.4, 10.2, 12.0, 13.5]:
			_box(Vector3(x, y, -48.37), Vector3(0.055, 0.055, 0.025), "trim")
	for x in [-21.2, -14.8]:
		_box(Vector3(x, 11.6, -48.39), Vector3(1.5, 1.3, 0.06), "black")
		for i in range(7):
			_box(Vector3(x, 11.06 + i * 0.18, -48.33), Vector3(1.4, 0.06, 0.08), "trim", false, Vector3(-0.3, 0, 0))
	# Foundation joints ground the long dam facade without repetitive texture noise.
	for x in range(-45, 46, 10):
		_box(Vector3(x, 10, -87.45), Vector3(0.08, 26, 0.025), "dark_concrete")
		_box(Vector3(x, 23.5, -87.38), Vector3(0.65, 0.5, 0.04), "steel")
	# Compact originals on the maintenance benches: tool case and insulated leads.
	_box(Vector3(-4.6, 1.99, -15.1), Vector3(0.55, 0.2, 0.38), "orange")
	_box(Vector3(-4.6, 2.10, -15.1), Vector3(0.25, 0.04, 0.06), "black")
	_pipe(Vector3(-4.5, 1.96, -15.5), Vector3(-4.2, 1.96, -16.1), 0.016, "black")
	_pipe(Vector3(-4.2, 1.96, -16.1), Vector3(-4.5, 2.0, -16.6), 0.016, "black")

func _window_frame(center: Vector3, width: float, height: float) -> void:
	for x in [-width * 0.5, width * 0.5]:
		_box(center + Vector3(x, 0, 0), Vector3(0.07, height + 0.14, 0.09), "steel")
	for y in [-height * 0.5, height * 0.5]:
		_box(center + Vector3(0, y, 0), Vector3(width + 0.14, 0.07, 0.09), "steel")
	_box(center, Vector3(0.045, height, 0.08), "trim")
	_box(center + Vector3(0, -height * 0.5 - 0.04, 0.05), Vector3(width + 0.22, 0.05, 0.17), "trim")

func _pipe_flange(pos: Vector3, direction: Vector3, radius: float) -> void:
	var rotation_q := Quaternion(Vector3.UP, direction.normalized())
	var collar := _cylinder(pos, radius + 0.10, 0.11, "trim")
	collar.quaternion = rotation_q
	var gasket := _cylinder(pos, radius + 0.12, 0.025, "black")
	gasket.quaternion = rotation_q
	for i in range(6):
		var angle := TAU * i / 6
		var offset := rotation_q * Vector3(cos(angle) * (radius + 0.065), 0.07, sin(angle) * (radius + 0.065))
		_box(pos + offset, Vector3(0.055, 0.045, 0.055), "steel", false, rotation_q.get_euler())

func _scanned_environment() -> void:
	# CC0 scanned strata frame the near valley beyond the playable parapets.
	# Their irregular silhouettes and baked surface detail ground the distant ridge.
	for placement in [Vector3(-66,-12,-38), Vector3(-72,-12,-79), Vector3(68,-12,-54), Vector3(72,-12,-98)]:
		_model_prop("rock_face_01", placement, 10.0, PI / 2 if placement.x < 0 else -PI / 2, true)
	for placement in [Vector3(-60,-10,-8), Vector3(58,-10,-15), Vector3(-62,-9,-112)]:
		_model_prop("rock_face_02", placement, 12.0, 0.35 if placement.x < 0 else -0.8, true)
	# Real flanged pipe modules with authored2K wear/roughness maps; mounted
	# against solid service walls, outside tested traversal and cover footprints.
	for x in [-22.0,-14.0]:
		_scanned_pipe("pipe02", Vector3(x,11.2,-48.18), 2.0, 0.0)
		_scanned_pipe("pipe05", Vector3(x,9.0,-48.12), 2.0, 0.0)
	for x in [-3.5,3.5]:
		_scanned_pipe("pipe02", Vector3(x,3.3,-19.83), 1.8, 0.0)
		_scanned_pipe("pipe07", Vector3(x,2.0,-19.68), 1.8, 0.0)
	_scanned_pipe("pipe02", Vector3(24.42,2.2,-38.5), 1.7, 0.0)

func _scanned_pipe(part: String, pos: Vector3, scale_value: float, yaw: float) -> void:
	var packed := load("res://assets/models/modular_industrial_pipes_01/modular_industrial_pipes_01_game.gltf") as PackedScene
	var source := packed.instantiate()
	var candidate := source.find_child("modular_industrial_pipes_01_" + part, true, false) as MeshInstance3D
	if candidate != null:
		var instance := MeshInstance3D.new()
		instance.mesh = candidate.mesh
		instance.position = pos
		instance.scale = Vector3.ONE * scale_value
		instance.rotation.y = yaw
		instance.name = "CC0_ServicePipe_" + part
		add_child(instance)
		_sanitize_prop_materials(instance)
	source.free()

func _turbine_landmark_detail() -> void:
	var first_detail_child := get_child_count()
	# Original turbine governor housings. The tested cylinders remain the only
	# collision; all service fittings stay within or behind their existing footprint.
	for unit in range(3):
		var x := -22.0 + unit * 4.5
		for y in [8.1, 9.28]:
			_cylinder(Vector3(x, y, -46), 1.27, 0.10, "steel")
		_cylinder(Vector3(x, 9.36, -46), 1.13, 0.12, "orange")
		_cylinder(Vector3(x, 9.45, -46), 0.99, 0.06, "black")
		_cylinder(Vector3(x, 9.51, -46), 0.29, 0.12, "trim")
		for index in range(12):
			var angle := index * TAU / 12.0
			var edge := Vector3(cos(angle), 0, sin(angle))
			_box(Vector3(x, 9.37, -46) + edge * 1.17, Vector3(0.09, 0.10, 0.09), "trim")
			_box(Vector3(x, 8.68, -46) + edge * 1.245, Vector3(0.055, 0.98, 0.055), "steel")
			_box(Vector3(x, 9.49, -46) + edge * 0.62, Vector3(0.62, 0.04, 0.12), "steel", false, Vector3(0, -angle + 0.35, 0))
		# Fine top safety grill uses batched strips rather than alpha textures.
		for offset in [-0.72, -0.48, -0.24, 0.0, 0.24, 0.48, 0.72]:
			var chord := sqrt(0.94 * 0.94 - offset * offset) * 2.0
			_box(Vector3(x + offset, 9.58, -46), Vector3(0.022, 0.025, chord), "trim")
		_box(Vector3(x, 8.75, -44.748), Vector3(0.64, 0.36, 0.025), "black")
		# Instrument panel and insulated return lines on the rear side.
		_pipe(Vector3(x + 0.8, 8.2, -46.9), Vector3(x + 0.8, 9.05, -47.8), 0.075, "rust")
		_pipe(Vector3(x + 0.8, 9.05, -47.8), Vector3(x + 0.8, 10.5, -48.3), 0.075, "rust")
		var dial := _cylinder(Vector3(x + 0.80, 9.15, -47.72), 0.17, 0.07, "white")
		dial.rotation.x = PI / 2
		_box(Vector3(x + 0.8, 9.15, -47.675), Vector3(0.02, 0.24, 0.02), "black", false, Vector3(0,0,-0.6))
	# Roof-mounted maintenance crane defines the turbine station skyline.
	# All parts sit over the already solid rear plant enclosure, away from routes.
	for x in [-22.3, -13.7]:
		_box(Vector3(x, 15.65, -49.5), Vector3(0.28, 3.3, 0.4), "orange")
		_box(Vector3(x, 14.13, -49.5), Vector3(0.9, 0.18, 1.3), "steel")
		for side in [-1.0, 1.0]:
			_box(Vector3(x + side * 0.38, 14.7, -49.5), Vector3(0.12, 1.5, 0.22), "steel", false, Vector3(0,0,side * 0.48))
	_box(Vector3(-18, 17.25, -49.5), Vector3(10.5, 0.42, 0.38), "orange")
	for y in [17.0, 17.5]:
		_box(Vector3(-18, y, -49.5), Vector3(10.5, 0.08, 0.72), "steel")
	_box(Vector3(-16.6, 16.85, -49.5), Vector3(0.9, 0.45, 0.8), "yellow")
	_pipe(Vector3(-16.6, 16.6, -49.5), Vector3(-16.6, 15.05, -49.5), 0.025, "black")
	_cylinder(Vector3(-16.6, 14.95, -49.5), 0.12, 0.28, "yellow")
	# Drained plant status is readable from the roof without another HUD prompt.
	_box(Vector3(-21, 10.1, -48.40), Vector3(1.55, 0.65, 0.04), "black")
	# Bake only this pass's immutable round fittings into one mesh per material.
	# Boxes already use the world's MultiMesh batches; labels remain independent.
	var merged: Dictionary = {}
	for index in range(first_detail_child, get_child_count()):
		var instance := get_child(index) as MeshInstance3D
		if instance == null: continue
		var material := instance.mesh.surface_get_material(0)
		if not merged.has(material):
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builder.set_material(material)
			merged[material] = builder
		merged[material].append_from(instance.mesh, 0, instance.transform)
		instance.hide()
		instance.queue_free()
	for material in merged:
		var instance := MeshInstance3D.new()
		instance.mesh = merged[material].commit()
		instance.name = "TurbineServiceFittings"
		add_child(instance)

func _surface_for_material(material: String) -> String:
	if material in ["concrete", "dark_concrete"]: return "concrete"
	if material in ["rock", "snow"]: return "gravel"
	return "metal"

func _box(pos: Vector3, size: Vector3, material: String, collision: bool = false, rot: Vector3 = Vector3.ZERO, render_mesh: bool = true, shot_only:bool=false, terrain:bool=false) -> void:
	if render_mesh:
		if not batches.has(material): batches[material] = []
		var basis := Basis.from_euler(rot).scaled(size)
		batches[material].append(Transform3D(basis, pos))
	# Exact ballistic surfaces for raised painted markings, without tiny locomotion steps.
	var paint_surface := render_mesh and not collision and material == "yellow" and size.y <= 0.08 and size.x > size.y and size.z > size.y
	var exact_surface:=render_mesh and not collision #089 every rendered trim, tread and rail is a ballistic surface
	if collision or exact_surface:
		var body := StaticBody3D.new()
		if terrain:body.add_to_group("construction_terrain")
		if exact_surface:
			body.collision_layer = 8
			body.collision_mask = 0
			body.add_to_group("rendered_ballistic_surface")
			if paint_surface:body.add_to_group("painted_ballistic_surface")
		body.position = pos
		body.set_meta("surface", _surface_for_material(material))
		body.rotation = rot
		if not exact_surface: body.add_to_group("climbable")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		add_child(body)

func _flush_batches() -> void:
	for material in batches:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh.material = mats[material]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = batches[material].size()
		for i in range(multi.instance_count):
			multi.set_instance_transform(i, batches[material][i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.name = "Batched_" + material
		add_child(instance)
	batches.clear()

func _cylinder(pos: Vector3, radius: float, height: float, material: String, collision: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.material = mats[material]
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.set_meta("surface", _surface_for_material(material))
		body.add_to_group("climbable")
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
		body.add_child(cs)
		instance.add_child(body)
	return instance

func _pipe(a: Vector3, b: Vector3, radius: float, material: String) -> void:
	var instance := _cylinder((a + b) * 0.5, radius, a.distance_to(b), material)
	var body:=StaticBody3D.new();body.collision_layer=8;body.collision_mask=0;body.add_to_group("rendered_ballistic_surface");body.set_meta("surface",_surface_for_material(material))
	var shape:=CollisionShape3D.new();shape.shape=instance.mesh.create_trimesh_shape();body.add_child(shape);instance.add_child(body)
	var direction := (b - a).normalized()
	instance.quaternion = Quaternion(Vector3.UP, direction)

func _platform(pos: Vector3, size: Vector3) -> void:
	_box(pos, size, "steel", true)
	_box(pos + Vector3(0, size.y * 0.5 + 0.015, 0), Vector3(size.x - 0.1, 0.025, size.z - 0.1), "trim")
	for x in [-size.x * 0.5 + 0.15, size.x * 0.5 - 0.15]:
		_box(pos + Vector3(x, size.y * 0.5 + 0.04, 0), Vector3(0.12, 0.04, size.z), "yellow")

func _stairs(start: Vector3, count: int, rise: float, tread: float, width: float, reverse: bool = false) -> void:
	var direction := 1.0 if reverse else -1.0
	# Invisible continuous support meets every tread's leading top edge. Extend
	# one tread before the first riser to join the floor, then flatten the last
	# tread to join the landing. The previous tilted box lay below tread noses.
	var run := count * tread
	var height := count * rise
	var support := StaticBody3D.new()
	support.name = "StairSupport"
	support.position = start
	support.add_to_group("stair_support")
	support.add_to_group("climbable")
	support.set_meta("surface", "metal")
	var points := PackedVector3Array()
	for x in [-width * 0.5, width * 0.5]:
		for yz in [Vector2(-0.10, -tread), Vector2(height - 0.10, run - tread), Vector2(height, run - tread), Vector2(0, -tread)]:
			points.append(Vector3(x, yz.x, direction * yz.y))
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	var collision := CollisionShape3D.new()
	collision.shape = hull
	support.add_child(collision)
	# Separate thin final tread preserves the open space beneath the stairs;
	# filling a convex wedge down to ground would create invisible head walls.
	var landing_collision := CollisionShape3D.new()
	var landing_shape := BoxShape3D.new()
	# A 2 mm overlap avoids a floating-point ray-query seam between shapes.
	landing_shape.size = Vector3(width, 0.10, tread + 0.004)
	landing_collision.shape = landing_shape
	landing_collision.position = Vector3(0, height - 0.05, direction * (run - tread * 0.5))
	support.add_child(landing_collision)
	add_child(support)
	for i in range(count):
		var top := rise * (i + 1)
		_box(start + Vector3(0, top - 0.1, direction * (i * tread + tread * 0.5)), Vector3(width, 0.2, tread + 0.01), "steel")
		_box(start + Vector3(0, top + 0.01, direction * (i * tread + tread * 0.5)), Vector3(width, 0.025, 0.08), "yellow")
		if i % 4 == 0:
			for x in [-width * 0.5, width * 0.5]:
				_box(start + Vector3(x, top + 0.5, direction * (i * tread + tread * 0.5)), Vector3(0.07, 1, 0.07), "trim")
	for x in [-width * 0.5, width * 0.5]:
		_pipe(start + Vector3(x, rise + 1, 0), start + Vector3(x, rise * count + 1, direction * count * tread), 0.045, "yellow")

func _rail(pos: Vector3, length: float, along_z: bool) -> void:
	for i in range(int(length / 2) + 1):
		var offset := -length * 0.5 + i * 2
		_box(pos + (Vector3(0, 0.5, offset) if along_z else Vector3(offset, 0.5, 0)), Vector3(0.08, 1, 0.08), "trim")
	for y in [0.4, 1.0]:
		_box(pos + Vector3(0, y, 0), Vector3(0.08, 0.08, length) if along_z else Vector3(length, 0.08, 0.08), "yellow")

func _crate(pos: Vector3, size: Vector3) -> void:
	_box(pos, size, "steel", true)
	for x in [-size.x * 0.4, size.x * 0.4]:
		_box(pos + Vector3(x, 0, 0), Vector3(0.10, size.y + 0.04, size.z + 0.04), "rust")
	_box(pos + Vector3(0, 0, size.z * 0.5 + 0.025), Vector3(size.x * 0.4, size.y * 0.3, 0.025), "orange")

func _lamp(pos: Vector3) -> void:
	_local_light(pos + Vector3(-0.7, 4.75, 0), Color(1, 0.70, 0.34), 0.8, 6)
	_box(pos + Vector3(0, 2.5, 0), Vector3(0.14, 5, 0.14), "steel", true)
	_box(pos + Vector3(-0.5, 5, 0), Vector3(1.2, 0.12, 0.3), "steel")
	_box(pos + Vector3(-0.7, 4.92, 0), Vector3(0.7, 0.08, 0.25), "amber")

func _label(text: String, pos: Vector3, pixel_size: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.pixel_size = pixel_size * 0.5
	label.font_size = 32
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	add_child(label)

func _mountain(pos: Vector3, radius: float, height: float, seed_value: int) -> void:
	var terrain_noise := FastNoiseLite.new()
	terrain_noise.seed = 4871 + seed_value * 217
	terrain_noise.frequency = 0.009
	terrain_noise.fractal_octaves = 3
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var divisions := 64
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for z in range(divisions + 1):
		for x in range(divisions + 1):
			var px := (float(x) / divisions * 2 - 1) * radius
			var pz := (float(z) / divisions * 2 - 1) * radius
			var u := px / radius
			var w := pz / radius
			# Two overlapping asymmetric ridges form a massif instead of a cone.
			# The smooth boundary reaches ground before the mesh edge, preventing
			# the old high vertical cuts from reading as giant triangular sheets.
			var edge := (1.0 - smoothstep(0.70, 1.0, absf(u))) * (1.0 - smoothstep(0.70, 1.0, absf(w)))
			var ridge_a := exp(-pow((u + 0.13) / 0.56, 2) - pow((w - 0.08) / 0.82, 2))
			var ridge_b := exp(-pow((u - 0.34) / 0.45, 2) - pow((w + 0.27) / 0.55, 2)) * 0.55
			var n := terrain_noise.get_noise_2d(px * 1.35, pz * 1.35)
			var envelope := ridge_a * 0.68 + ridge_b * 0.40
			var ridge_low := 1.0 - absf(terrain_noise.get_noise_2d(px * 2.1 + seed_value * 137, pz * 2.1 - 413))
			var ridge_detail := 1.0 - absf(terrain_noise.get_noise_2d(px * 4.2 - 317, pz * 4.2 + seed_value * 79))
			# Broad massif retained; bounded shallow relief cannot create tall isolated needles.
			var relief := (ridge_low - 0.68) * 0.20 + (ridge_detail - 0.68) * 0.055
			var elevation := edge * height * envelope * (0.88 + n * 0.24 + relief)
			vertices.append(Vector3(px, elevation, pz))
	# Wide finite-difference normals smooth shading without changing any vertices.
	for z in range(divisions + 1):
		for x in range(divisions + 1):
			var dx := vertices[z * (divisions + 1) + mini(x + 2, divisions)] - vertices[z * (divisions + 1) + maxi(x - 2, 0)]
			var dz := vertices[mini(z + 2, divisions) * (divisions + 1) + x] - vertices[maxi(z - 2, 0) * (divisions + 1) + x]
			normals.append(dz.cross(dx).normalized())
	for z in range(divisions):
		for x in range(divisions):
			var a := z * (divisions + 1) + x
			for idx in [a, a + divisions + 1, a + 1, a + 1, a + divisions + 1, a + divisions + 2]:
				var v := vertices[idx]
				var snow_line := height * 0.48 + terrain_noise.get_noise_2d(v.x * 3, v.z * 3) * 15
				var snow_cover := smoothstep(snow_line, snow_line + 12, v.y)
				var rock_tone := 0.91 + terrain_noise.get_noise_2d(v.x * 0.4, v.z * 0.4) * 0.16
				surface.set_color((Color(0.25, 0.29, 0.31) * rock_tone).lerp(Color(0.72, 0.78, 0.81), snow_cover))
				surface.set_normal(normals[idx])
				surface.set_uv(Vector2(v.x, v.z) * 0.025)
				surface.add_vertex(v)
	#089 close terrain skirts and underside; no visible backface holes along map edges.
	var rim:Array[int]=[]
	for x in range(divisions+1):rim.append(x)
	for z in range(1,divisions+1):rim.append(z*(divisions+1)+divisions)
	for x in range(divisions-1,-1,-1):rim.append(divisions*(divisions+1)+x)
	for z in range(divisions-1,0,-1):rim.append(z*(divisions+1))
	for i in rim.size():
		var a:Vector3=vertices[rim[i]];var b:Vector3=vertices[rim[(i+1)%rim.size()]]
		var lower_a:=Vector3(a.x,-2,a.z);var lower_b:=Vector3(b.x,-2,b.z)
		for point in [a,b,lower_a,b,lower_b,lower_a,lower_a,lower_b,Vector3(0,-2,0)]:
			surface.set_normal(Vector3(point.x,0,point.z).normalized());surface.set_uv(Vector2(point.x,point.z)*.025);surface.add_vertex(point)
	surface.index()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/alpine_terrain.gdshader")
	material.set_shader_parameter("snow_height", height * 0.49)
	surface.set_material(material)
	var mountain := MeshInstance3D.new()
	mountain.mesh = surface.commit()
	mountain.position = pos
	mountain.rotation.y = seed_value * 0.73
	mountain.name = "Mountain_%02d" % seed_value
	add_child(mountain)
	# One immutable BVH per visible massif; support, head and bullet queries use
	# the rendered triangles. No perimeter wall or solid convex envelope is added.
	var terrain := StaticBody3D.new()
	terrain.name = "MountainTerrainSurface"
	terrain.collision_layer = 9
	terrain.collision_mask = 0
	terrain.set_meta("surface", "gravel")
	terrain.add_to_group("terrain_surface")
	terrain.add_to_group("climbable")
	terrain.add_to_group("ballistic_surface")
	var shape := CollisionShape3D.new()
	shape.shape = mountain.mesh.create_trimesh_shape()
	shape.shape.backface_collision = true
	terrain.add_child(shape)
	mountain.add_child(terrain)







