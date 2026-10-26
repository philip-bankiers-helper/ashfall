extends Node3D
## Original mesh/shader burst. All nodes, meshes and materials are allocated once.
## Blasts use 18 mesh draws + two debris/ember batches and one shadowless light.
## Retains the same 2.5 s effect/audio lifetime; no per-frame resource allocation.
var kind := "frag"
var _tail_sound099:AudioStreamPlayer3D
var age := 0.0
var rings: Array[MeshInstance3D] = []
var shards: Array[MeshInstance3D] = []
var directions: Array[Vector3] = []
var core: MeshInstance3D
var light: OmniLight3D
var _fire: Array[MeshInstance3D] = []
var _fire_directions: Array[Vector3] = []
var _smoke: Array[MeshInstance3D] = []
var _smoke_directions: Array[Vector3] = []
var _debris_directions: Array[Vector3] = []
var _debris_spin: Array[Vector3] = []
var _ember_bases: Array[Basis] = []
var _ember_batch: MultiMeshInstance3D
var _debris_batch: MultiMeshInstance3D
var _pressure_grounded := false
var _core_material: ShaderMaterial
var _fire_material: ShaderMaterial
var _smoke_material: ShaderMaterial
var _pressure_material: ShaderMaterial
var _ember_material: StandardMaterial3D
var _debris_material: StandardMaterial3D

const CLOUD_NOISE := """
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float cloud_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(cell), hash3(cell + vec3(1,0,0)), f.x),
		mix(hash3(cell + vec3(0,1,0)), hash3(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(cell + vec3(0,0,1)), hash3(cell + vec3(1,0,1)), f.x),
		mix(hash3(cell + vec3(0,1,1)), hash3(cell + vec3(1,1,1)), f.x), f.y), f.z);
}
"""

static var _fire_shader: Shader
static var _smoke_shader: Shader
static var _pressure_shader: Shader

func setup(effect_kind: String) -> void:
	kind = effect_kind
	if kind == "zone":
		_build_zone()
	else:
		_build_blast()
	light = OmniLight3D.new()
	light.light_color = Color("ad58ff") if kind == "zone" else Color("ff9b43")
	light.omni_range = 10
	light.light_energy = 3
	light.shadow_enabled = false
	add_child(light)
	# Keep the existing dispatch, bus, gain and lifetime of every original cue.
	var sound := AudioStreamPlayer3D.new()
	sound.bus = "SFX"
	sound.max_distance = 100
	sound.volume_db = -4
	sound.stream = load("res://scripts/audio_bank.gd").sample("zone_bloom" if kind == "zone" else ("rocket_impact" if kind == "smaw" else "frag_blast"))
	add_child(sound)
	_tail_sound099=sound
	sound.play()
	_update_zone() if kind == "zone" else _update_blast()

func _mesh(mesh: Mesh, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = surface
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _batch(mesh: Mesh, surface: Material, count: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = count
	node.multimesh = batch
	node.material_override = surface
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _build_zone() -> void:
	# Retain the distinct purple energy bloom; ordinary blasts have no orbit rings.
	var colour := Color("ad58ff")
	for i in 3:
		var mesh := TorusMesh.new()
		mesh.inner_radius = .90
		mesh.outer_radius = 1
		mesh.rings = 40
		mesh.ring_segments = 6
		var ring := _mesh(mesh, material(colour, .75))
		ring.rotation = Vector3(i * .4, 0, i * .9)
		rings.append(ring)
	var sphere := SphereMesh.new()
	sphere.radius = .6
	sphere.height = 1.2
	sphere.radial_segments = 16
	sphere.rings = 8
	core = _mesh(sphere, material(colour, 1))
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(.025, .025, .3)
	for i in 28:
		shards.append(_mesh(spark_mesh, material(colour, 1)))
		var y := 1.0 - 2.0 * (float(i) + .5) / 28.0
		var phi := i * 2.399963
		directions.append(Vector3(cos(phi) * sqrt(1 - y * y), y, sin(phi) * sqrt(1 - y * y)))

func _build_blast() -> void:
	_build_shaders()
	_core_material = ShaderMaterial.new()
	_core_material.shader = _fire_shader
	_core_material.set_shader_parameter("hot_core", 1.0)
	_fire_material = ShaderMaterial.new()
	_fire_material.shader = _fire_shader
	_smoke_material = ShaderMaterial.new()
	_smoke_material.shader = _smoke_shader
	_pressure_material = ShaderMaterial.new()
	_pressure_material.shader = _pressure_shader
	_ember_material = material(Color("ffc16d"), 1)
	_debris_material = material(Color("34302b"), 1)
	_debris_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	var sphere := SphereMesh.new()
	sphere.radius = .5
	sphere.height = 1
	sphere.radial_segments = 20
	sphere.rings = 10
	core = _mesh(sphere, _core_material)
	for i in 7:
		var lobe := _mesh(sphere, _fire_material)
		lobe.rotation = Vector3(i * .71, i * 1.31, i * .43)
		_fire.append(lobe)
		var phi := i * 2.399963
		var y := .08 + float(i % 3) * .24
		_fire_directions.append(Vector3(cos(phi), y, sin(phi)).normalized())
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = .5
	smoke_mesh.height = 1
	smoke_mesh.radial_segments = 16
	smoke_mesh.rings = 8
	for i in 9:
		var puff := _mesh(smoke_mesh, _smoke_material)
		puff.rotation = Vector3(i * .57, i * .93, i * .37)
		_smoke.append(puff)
		var phi := i * 2.399963
		_smoke_directions.append(Vector3(cos(phi), .18 + float(i % 4) * .23, sin(phi)).normalized())
	var pressure_mesh := QuadMesh.new()
	pressure_mesh.size = Vector2(2, 2)
	var pressure := _mesh(pressure_mesh, _pressure_material)
	pressure.rotation.x = -PI * .5
	# A wall/air burst does not invent a glowing horizontal plane in mid-air.
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * .25, global_position + Vector3.DOWN * 3, 1))
	if not hit.is_empty() and hit.normal.y > .55:
		pressure.global_position = hit.position + Vector3.UP * .025
		_pressure_grounded = true
	else:
		pressure.hide()
	rings.append(pressure)
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(.018, .018, .16)
	_ember_batch = _batch(spark_mesh, _ember_material, 20)
	for i in 20:
		var phi := i * 2.399963
		var y := .05 + float(i % 7) * .13
		var direction := Vector3(cos(phi), y, sin(phi)).normalized()
		_ember_bases.append(Basis.looking_at(direction, Vector3.UP))
		directions.append(direction)
	var debris_mesh := BoxMesh.new()
	debris_mesh.size = Vector3(.075, .055, .10)
	_debris_batch = _batch(debris_mesh, _debris_material, 9)
	for i in 9:
		var phi := i * 2.399963 + .7
		_debris_directions.append(Vector3(cos(phi), .3 + float(i % 3) * .3, sin(phi)).normalized())
		_debris_spin.append(Vector3(2.1 + i * .17, -3.3 + i * .21, 1.6 + i * .13))

func _build_shaders() -> void:
	if _fire_shader == null:
		_fire_shader = Shader.new()
		_fire_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque;
uniform float effect_age = 0.0;
uniform float hot_core = 0.0;
varying vec3 surface_position;
""" + CLOUD_NOISE + """
void vertex() {
	float billow = cloud_noise(VERTEX * 4.3 + vec3(0.0, -effect_age * 1.7, 2.0));
	VERTEX += NORMAL * (billow - 0.35) * 0.24;
	surface_position = VERTEX;
}
void fragment() {
	vec3 flow = surface_position * 4.8 + vec3(0.0, -effect_age * 3.5, 0.0);
	float cloud = cloud_noise(flow) * 0.7 + cloud_noise(flow * 2.1) * 0.3;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float heat = clamp(1.12 - effect_age * 1.65 + cloud * 0.42 + hot_core * 0.32 - (1.0 - facing) * 0.24, 0.0, 1.0);
	vec3 colour = mix(vec3(0.32,0.045,0.008), vec3(1.0,0.24,0.018), smoothstep(0.12,0.60,heat));
	colour = mix(colour, vec3(1.0,0.72,0.20), smoothstep(0.58,0.88,heat));
	colour = mix(colour, vec3(1.0,0.94,0.72), smoothstep(0.88,1.0,heat));
	float envelope = smoothstep(0.0,0.025,effect_age) * (1.0 - smoothstep(0.22,0.82 - hot_core * 0.20,effect_age));
	ALBEDO = colour;
	EMISSION = colour * heat * 0.7;
	ALPHA = envelope * smoothstep(0.02,0.40,facing) * (0.70 + cloud * 0.30);
}
"""
	if _smoke_shader == null:
		_smoke_shader = Shader.new()
		_smoke_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque;
uniform float effect_age = 0.0;
varying vec3 surface_position;
""" + CLOUD_NOISE + """
void vertex() {
	float billow = cloud_noise(VERTEX * 5.0 + vec3(0.0,-effect_age * 0.4,3.0));
	VERTEX += NORMAL * (billow - 0.35) * 0.30;
	surface_position = VERTEX;
}
void fragment() {
	float cloud = cloud_noise(surface_position * 5.7 + vec3(0.0,-effect_age * 0.7,0.0));
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float shade = clamp(dot(normalize(NORMAL), normalize(vec3(-0.4,0.8,0.2))) * 0.30 + 0.55, 0.0, 1.0);
	vec3 colour = mix(vec3(0.045,0.040,0.035), vec3(0.22,0.205,0.18), cloud * shade);
	float glow = max(0.0, 1.0 - effect_age * 1.6);
	ALBEDO = colour + vec3(0.16,0.045,0.006) * glow * cloud;
	ALPHA = smoothstep(0.045,0.25,effect_age) * (1.0-smoothstep(1.05,2.45,effect_age)) * smoothstep(0.015,0.42,facing) * (0.40 + cloud * 0.32);
}
"""
	if _pressure_shader == null:
		_pressure_shader = Shader.new()
		_pressure_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float effect_age = 0.0;
void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	float band = smoothstep(0.72,0.86,radius) * (1.0-smoothstep(0.88,1.0,radius));
	float broken_dust = 0.65 + 0.35 * sin(atan(UV.y-0.5,UV.x-0.5) * 19.0 + radius * 35.0);
	ALBEDO = vec3(0.65,0.30,0.10);
	ALPHA = band * broken_dust * max(0.0,1.0-effect_age/0.55) * 0.30;
}
"""

func material(colour: Color, alpha: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	result.albedo_color = Color(colour, alpha)
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _process(delta: float) -> void:
	age += delta
	if age>=2.5:
		hide()
		if _tail_sound099==null or not _tail_sound099.playing:queue_free()
		return
	if kind == "zone":
		_update_zone()
	else:
		_update_blast()
	if age >= 2.5:
		queue_free()

func _update_zone() -> void:
	var fade := maxf(0, 1 - age / 1.8)
	for i in rings.size():
		rings[i].scale = Vector3.ONE * (.2 + age * (4.5 + i))
		rings[i].material_override.albedo_color.a = fade * .55
	core.scale = Vector3.ONE * (.3 + age * 2.8)
	core.material_override.albedo_color.a = maxf(0, 1 - age / .55)
	light.light_energy = maxf(0, 3 - age * 9)
	for i in shards.size():
		shards[i].position = directions[i] * age * 8 + Vector3.DOWN * age * age * 3
		shards[i].material_override.albedo_color.a = fade
		shards[i].look_at(global_position + directions[i] * 20, Vector3.UP)

func _update_blast() -> void:
	_core_material.set_shader_parameter("effect_age", age)
	_fire_material.set_shader_parameter("effect_age", age)
	_smoke_material.set_shader_parameter("effect_age", age)
	_pressure_material.set_shader_parameter("effect_age", age)
	var expansion := 1.0 - exp(-age * 9.0)
	var blast_size := 1.12 if kind == "smaw" else 1.0
	core.visible = age < .62
	core.scale = Vector3.ONE * (.32 + expansion * 1.75) * blast_size
	for i in _fire.size():
		var lobe := _fire[i]
		lobe.visible = age < .82
		lobe.position = (_fire_directions[i] * (.08 + expansion * .87) + Vector3.UP * age * .5) * blast_size
		var radius := (.25 + expansion * (1.1 + float(i % 3) * .14)) * blast_size
		lobe.scale = Vector3(radius, radius * (1.08 + float(i % 2) * .18), radius)
	for i in _smoke.size():
		var puff := _smoke[i]
		puff.visible = age > .045 and age < 2.45
		puff.position = (_smoke_directions[i] * (.20 + age * 1.15) + Vector3.UP * (.10 + age * .64)) * blast_size
		var radius := (.12 + sqrt(age) * (1.0 + float(i % 3) * .16)) * blast_size
		puff.scale = Vector3(radius, radius * 1.12, radius)
	rings[0].scale = Vector3.ONE * (.30 + age * 12.0)
	rings[0].visible = _pressure_grounded and age < .55
	light.light_energy = maxf(0, 3 - age * 9)
	var ember_fade := maxf(0, 1 - age / 1.65)
	_ember_batch.visible = age < 1.65
	_ember_material.albedo_color = Color(1.0, .28 + ember_fade * .42, .035 + ember_fade * .18, ember_fade)
	for i in directions.size():
		var speed := 4.0 + float(i % 5) * 1.1
		var position_value := directions[i] * age * speed + Vector3.DOWN * age * age * 3.0
		var basis_value := _ember_bases[i].scaled(Vector3.ONE * maxf(.1, 1.0 - age * .43))
		_ember_batch.multimesh.set_instance_transform(i, Transform3D(basis_value, position_value))
	var debris_fade := maxf(0, 1 - maxf(0, age - .55) / 1.7)
	_debris_batch.visible = age < 2.25
	_debris_material.albedo_color.a = debris_fade
	for i in _debris_directions.size():
		var position_value := _debris_directions[i] * age * (3.4 + float(i % 4) * .72) + Vector3.DOWN * age * age * 3.6
		_debris_batch.multimesh.set_instance_transform(i, Transform3D(Basis.from_euler(_debris_spin[i] * age), position_value))
