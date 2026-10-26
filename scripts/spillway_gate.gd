class_name AshSpillwayGate
extends Node3D
## Floor origin; 4m wide x 3m clear opening along local Z. Frame stays solid.
signal opened
var is_open := false
var _built := false
var _panel: MeshInstance3D
var _barrier: StaticBody3D
var _travel := 0.0
var _paused := false

func set_paused(value: bool) -> void:
	_paused = value

func _ready() -> void:
	setup()

func setup(materials: Dictionary = {}) -> void:
	if _built: return
	_built = true
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.19, 0.23, 0.25)
	metal.metallic = 0.6
	metal.roughness = 0.65
	var shell: Material = materials.get("metal", metal)
	for x in [-2.2, 2.2]: _solid(Vector3(x, 1.7, 0), Vector3(0.4, 3.4, 0.6), shell)
	_solid(Vector3(0, 3.25, 0), Vector3(4.8, 0.5, 0.6), shell)
	_barrier = _solid(Vector3(0, 1.5, 0), Vector3(4, 3, 0.24), shell)
	_panel = _barrier.get_child(0) as MeshInstance3D
	set_process(false)

func _solid(pos: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", "metal")
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func activate() -> void:
	if not _built: setup()
	if is_open: return
	is_open = true
	# Collision removed before visual travel: cannot carry, trap, or push the player.
	_barrier.collision_layer = 0
	_travel = 0
	set_process(true)
	opened.emit()

func reset() -> void:
	if not _built: setup()
	is_open = false
	_travel = 0
	_panel.position = Vector3.ZERO
	_barrier.collision_layer = 1
	set_process(false)

func _process(delta: float) -> void:
	if _paused: return
	_travel = minf(1.0, _travel + delta / 0.65)
	_panel.position.y = 3.1 * smoothstep(0.0, 1.0, _travel)
	if _travel >= 1.0: set_process(false)
