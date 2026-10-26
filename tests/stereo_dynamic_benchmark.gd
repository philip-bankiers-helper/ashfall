extends "res://tests/stereo_render_benchmark.gd"
## Deliberately synthetic active-AI/rigid-body fixture; no campaign mutation.
const EnemyScript = preload("res://scripts/enemy.gd")
const RagdollScript = preload("res://scripts/ragdoll.gd")
class MovingTarget extends CharacterBody3D:
	var exposure_provider: Node
	func get_aim_position() -> Vector3: return global_position + Vector3.UP * 1.35
var actor_root: Node3D
var dummy_target: MovingTarget
var dynamic_view := -1
var kick_clock := 0.0
var body_peak := 0
var enemy_peak := 0

func _ready() -> void:
	super._ready()
	if cameras.size() != 2: return
	_build_fixture()

func _build_fixture() -> void:
	if is_instance_valid(actor_root):
		_stop_audio(actor_root)
		actor_root.queue_free()
	actor_root = Node3D.new()
	actor_root.name = "SyntheticDynamicWorkload"
	add_child(actor_root)
	dummy_target = MovingTarget.new()
	for child in get_children():
		if child is AshWorld: dummy_target.exposure_provider = child
	actor_root.add_child(dummy_target)
	var center: Vector3 = VIEWS[view_index].position - Vector3.UP * 1.6
	var forward: Vector3 = (VIEWS[view_index].target - VIEWS[view_index].position) * Vector3(1,0,1)
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	dummy_target.position = center
	# Eight real production AI actors including one Warden. Their shots do not
	# damage a player; the moving synthetic target has no gameplay health.
	for i in range(8):
		var enemy = EnemyScript.new()
		enemy.position = center + right * (float(i%4)-1.5)*1.8 + forward*(5.0+floorf(float(i)/4.0)*2.2) + Vector3.UP*0.1
		enemy.setup(dummy_target, 3 if i == 7 else i % 3)
		actor_root.add_child(enemy)
		enemy.set_difficulty(0.75)
		enemy.notify_gunshot(center, 1.0)
		if i < 6:
			var corpse_pos := center + right*(float(i)-2.5) + forward*3.5 + Vector3.UP*0.2
			# Six eight-body wrecks reach the production 48-body cap.
			RagdollScript.spawn(actor_root, Transform3D(Basis.IDENTITY,corpse_pos),Vector3(0.8,0.6,-0.4),0,enemy._visual)
	dynamic_view = view_index
	kick_clock = 0.0
	enemy_peak = maxi(enemy_peak,8)
	print("DYNAMIC_FIXTURE view=",VIEWS[view_index].name," live_enemies=8 ragdolls=6 scripted_impulses=true")

func _process(delta: float) -> void:
	if finished: return
	if is_instance_valid(dummy_target):
		var center: Vector3 = VIEWS[view_index].position - Vector3.UP*1.6
		dummy_target.position = center + Vector3(sin(phase_time)*1.8,0,cos(phase_time*.7)*.8)
		dummy_target.velocity = Vector3(cos(phase_time)*1.8,0,-sin(phase_time*.7)*.56)
		kick_clock += delta
		var bodies := actor_root.find_children("*","RigidBody3D",true,false)
		body_peak = maxi(body_peak,bodies.size())
		if kick_clock > 1.5:
			kick_clock = 0
			for body in bodies:
				body.sleeping = false
				body.apply_central_impulse(Vector3(0.08,0.15,-0.04))
	super._process(delta)
	if not finished and view_index != dynamic_view: _build_fixture()

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop(); node.stream = null
	for child in node.get_children(): _stop_audio(child)

func _finish() -> void:
	finished = true
	_stop_audio(actor_root)
	actor_root.set_process(false)
	for corpse in get_tree().get_nodes_in_group("ragdolls"):
		if actor_root.is_ancestor_of(corpse): corpse.set_paused(true)
	for child in actor_root.get_children(): child.set_physics_process(false)
	await get_tree().create_timer(0.15).timeout
	super._finish()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output))
	data["dynamic_fixture"] = {"live_enemy_peak":enemy_peak,"ragdolls_per_view":6,"rigid_body_peak":body_peak,"ai_difficulty":0.75,"scripted_target_and_periodic_impulses":true,"includes_weapon_or_campaign_ui":false}
	data["limits"] = "Synthetic separate-eye rendering plus production AI and ragdolls against a scripted invulnerable target. Periodic impulses intentionally keep physics active. Excludes OpenXR multiview/runtime/compositor/Link, physical tracking, player weapon and campaign UI. Not headset frame time or FPS."
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t")); file.close()
