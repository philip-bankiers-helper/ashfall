extends StaticBody3D
## Bullet-only target: layer4 never occludes world-only exposure rays.
const AudioBank = preload("res://scripts/audio_bank.gd")
var is_light_fixture := true
var broken := false
var light: OmniLight3D
var _energy := 1.0
var _lens: StandardMaterial3D
var _sparks: Array[MeshInstance3D] = []
var _spark_time := 0.0
var _crack: AudioStreamPlayer3D

func setup(energy: float, reach: float) -> void:
	collision_layer = 4
	collision_mask = 0
	set_meta("surface", "metal")
	_energy = energy
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.85, 0.20, 0.42)
	collision.shape = shape
	add_child(collision)
	var housing := StandardMaterial3D.new()
	housing.albedo_color = Color(0.16, 0.19, 0.20)
	housing.roughness = 0.75
	_mesh(Vector3(0, 0.07, 0), Vector3(0.9, 0.17, 0.46), housing)
	_lens = StandardMaterial3D.new()
	_lens.albedo_color = Color(1, 0.80, 0.53)
	_lens.emission_enabled = true
	_lens.emission = Color(1, 0.66, 0.28)
	_lens.emission_energy_multiplier = 2.0
	_mesh(Vector3(0, -0.05, 0), Vector3(0.75, 0.08, 0.34), _lens)
	for x in [-0.32, 0.0, 0.32]:
		_mesh(Vector3(x, -0.10, 0), Vector3(0.025, 0.03, 0.4), housing)
	light = OmniLight3D.new()
	light.light_color = Color(1, 0.78, 0.51)
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = true
	add_child(light)
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1, 0.65, 0.12)
	for i in range(8):
		var spark := _mesh(Vector3.ZERO, Vector3(0.015, 0.06, 0.015), spark_material)
		spark.hide()
		_sparks.append(spark)
	_crack = AudioStreamPlayer3D.new()
	AudioBank.ensure_buses()
	_crack.bus = "SFX"
	_crack.stream = AudioBank.sample("impact_metal")
	_crack.volume_db = -15
	_crack.max_distance = 25
	_crack.max_polyphony = 1
	add_child(_crack)
	set_process(false)

func _mesh(pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	instance.mesh = box
	instance.position = pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func take_damage(amount: float) -> void:
	if broken or amount <= 0: return
	broken = true
	light.light_energy = 0
	_lens.emission_enabled = false
	_lens.albedo_color = Color(0.10, 0.09, 0.07)
	_spark_time = 0
	_crack.play()
	set_process(true)

func get_hit_feedback() -> String:
	return "LIGHT DISABLED" if broken else "LIGHT FIXTURE"

func _exit_tree() -> void:
	if is_instance_valid(_crack):
		_crack.stop()
		_crack.stream = null

func reset_fixture() -> void:
	broken = false
	light.light_energy = _energy
	_lens.emission_enabled = true
	_lens.albedo_color = Color(1, 0.80, 0.53)
	_crack.stop()
	for spark in _sparks: spark.hide()
	_spark_time = 0
	set_process(false)

func _process(delta: float) -> void:
	_spark_time += delta
	for i in range(_sparks.size()):
		var angle := i * TAU / 8.0
		_sparks[i].position = Vector3(cos(angle), -0.6, sin(angle)) * _spark_time * 2.0 + Vector3.DOWN * _spark_time * _spark_time * 4
		_sparks[i].visible = _spark_time < 0.25
	if _spark_time >= 0.25: set_process(false)
