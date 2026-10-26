class_name AshInterferenceUnit
extends StaticBody3D
## Stationary, shootable campaign target. Origin is the base on the floor.
signal disabled
const AudioBank = preload("res://scripts/audio_bank.gd")
const MAX_HEALTH := 90.0
var health := MAX_HEALTH
var is_disabled := false
var active := true
var _built := false
var _lens: StandardMaterial3D
var _antenna: Node3D
var _status: Label3D
var _sound: AudioStreamPlayer3D
var _sparks: Array[MeshInstance3D] = []
var _effect_time := 0.0
var _paused := false

func set_paused(value: bool) -> void:
	_paused = value
	if is_instance_valid(_sound): _sound.stream_paused = value

func _ready() -> void:
	setup()

func setup(materials: Dictionary = {}) -> void:
	if _built: return
	_built = true
	collision_layer = 4
	collision_mask = 0
	set_meta("surface", "metal")
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.13, 0.18, 0.20)
	metal.metallic = 0.65
	metal.roughness = 0.54
	var shell: Material = materials.get("metal", metal)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.05, 2.25, 0.8)
	shape.shape = box
	shape.position.y = 1.125
	add_child(shape)
	_box(self, Vector3(0, 0.12, 0), Vector3(1.2, 0.24, 1.0), shell)
	_box(self, Vector3(0, 0.95, 0), Vector3(0.95, 1.6, 0.7), shell)
	_lens = StandardMaterial3D.new()
	_lens.albedo_color = Color(1.0, 0.3, 0.05)
	_lens.emission_enabled = true
	_lens.emission = Color(1.0, 0.15, 0.02)
	_lens.emission_energy_multiplier = 2.0
	for side in [-1.0, 1.0]:
		_box(self, Vector3(0, 1.18, side * 0.365), Vector3(0.65, 0.65, 0.035), _lens)
		for x in [-0.36, 0.36]:
			_box(self, Vector3(x, 1.18, side * 0.4), Vector3(0.055, 0.85, 0.09), shell)
	_antenna = Node3D.new()
	_antenna.position.y = 1.8
	add_child(_antenna)
	_box(_antenna, Vector3(0, 0.45, 0), Vector3(0.08, 0.9, 0.08), shell)
	for y in [0.2, 0.45, 0.7]:
		_box(_antenna, Vector3(0, y, 0), Vector3(1.0 - y * 0.4, 0.055, 0.07), shell)
	_status = Label3D.new()
	_status.position = Vector3(0, 1.78, 0.42)
	_status.font_size = 28
	_status.pixel_size = 0.002
	_status.text = "INTERFERENCE"
	add_child(_status)
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1, 0.65, 0.08)
	for i in range(8):
		var spark := _box(self, Vector3.ZERO, Vector3(0.025, 0.08, 0.025), spark_material)
		spark.hide()
		_sparks.append(spark)
	AudioBank.ensure_buses()
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = AudioBank.sample("impact_metal")
	_sound.bus = "SFX"
	_sound.volume_db = -8
	_sound.max_distance = 35
	add_child(_sound)
	set_process(false)
	set_active(active)

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func take_damage(amount: float) -> void:
	if not active or is_disabled or not is_finite(amount) or amount <= 0: return
	health = maxf(0, health - amount)
	if health > 0: return
	is_disabled = true
	_lens.emission_enabled = false
	_lens.albedo_color = Color(0.08, 0.1, 0.1)
	_antenna.rotation.z = 0.5
	_status.text = "SIGNAL OFFLINE"
	_effect_time = 0.0
	_sound.play()
	set_process(true)
	disabled.emit()

func get_hit_feedback() -> String:
	return "INTERFERENCE DISABLED" if is_disabled else ""

func set_active(value: bool) -> void:
	active = value
	if _built: _status.visible = value

func reset() -> void:
	if not _built: setup()
	health = MAX_HEALTH
	is_disabled = false
	active = true
	_lens.emission_enabled = true
	_lens.albedo_color = Color(1.0, 0.3, 0.05)
	_antenna.rotation = Vector3.ZERO
	_status.text = "INTERFERENCE"
	_status.show()
	_sound.stop()
	for spark in _sparks: spark.hide()
	set_process(false)

func _process(delta: float) -> void:
	if _paused: return
	_effect_time += delta
	for i in range(_sparks.size()):
		var angle := i * TAU / 8.0
		_sparks[i].position = Vector3(0, 1.25, 0) + Vector3(cos(angle), 1, sin(angle)) * _effect_time * 3 + Vector3.DOWN * _effect_time * _effect_time * 8
		_sparks[i].visible = _effect_time < 0.3
	if _effect_time >= 0.3: set_process(false)

func _exit_tree() -> void:
	if is_instance_valid(_sound):
		_sound.stop()
		_sound.stream = null
