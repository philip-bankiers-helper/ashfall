extends SceneTree
const Builder = preload("res://scripts/field_builder.gd")
class ObjectiveGame extends Node:
	var targets: Array = []
	func _objective_grip_targets() -> Array:
		return targets
var passed := 0
var failed := 0
var builder: Node3D
var scene: Node3D
var state := {"trigger": false, "cycle": false, "eligible": true, "tracking": true, "origin": Vector3(0,1.6,0), "direction": Vector3(0,-0.4,-1).normalized(), "head": Vector3(0,1.6,0)}
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		printerr("FAIL ", label)
func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	scene.add_child(body)
	body.position = at
	return body
func tick(trigger: bool) -> void:
	state.trigger = trigger
	builder.tick_input(state)
func run() -> void:
	scene = Node3D.new()
	root.add_child(scene)
	box(Vector3(0,-0.25,0),Vector3(30,0.5,30))
	builder = Builder.new()
	scene.add_child(builder)
	builder.setup(null,null,null)
	await physics_frame
	await physics_frame
	tick(true)
	check(not builder.is_active(), "held trigger at startup cannot enter")
	tick(false)
	tick(true)
	check(builder.is_active() and builder.pieces.size() == 1, "fresh press enters and immediately places valid ground wall")
	tick(true)
	check(builder.pieces.size() == 1, "held trigger never repeats")
	tick(false)
	tick(true)
	check(builder.pieces.size() == 1 and builder.charges == builder.initial_charges - 1, "release then fresh press places charged real body")
	await physics_frame
	await physics_frame
	var body: StaticBody3D = builder.pieces[0]
	var collision := scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(body.global_position + Vector3(0,0,1),body.global_position + Vector3(0,0,-1)))
	check(not collision.is_empty() and collision.collider == body and body.is_in_group("climbable"), "placed wall blocks world ray and is climbable")
	tick(false)
	tick(true)
	check(builder.pieces.size() == 1, "overlapping placed wall rejected")
	state.eligible = false
	tick(true)
	check(not builder.is_active(), "menu/weapon/reload conflict cancels")
	state.eligible = true
	tick(true)
	check(not builder.is_active(), "held trigger after conflict cannot leak placement")
	tick(false)
	tick(true)
	state.origin = Vector3(6,1.6,0)
	state.head = state.origin
	state.cycle = true
	tick(false)
	check(builder.piece_index == 1, "fresh cycle selects ramp while preview active")
	tick(false)
	check(builder.piece_index == 1, "held cycle does not repeat")
	state.cycle = false
	tick(false)
	tick(true)
	check(builder.pieces.size() == 2, "ramp confirmed on floor")
	await physics_frame
	await physics_frame
	var ramp: StaticBody3D = builder.pieces[-1]
	var ramp_hit := scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ramp.global_position + Vector3(0,3,0),ramp.global_position + Vector3(0,-1,0)))
	check(not ramp_hit.is_empty() and ramp_hit.collider == ramp and ramp_hit.normal.y > 0.5, "ramp real sloped support collision")
	builder.reset_builds()
	await physics_frame
	await physics_frame
	check(builder.pieces.is_empty() and builder.charges == builder.initial_charges and not builder.is_active(), "checkpoint/death reset clears structures refills and cancels")
	state.origin = Vector3(0,1.6,0)
	state.head = Vector3(0,1.6,-3.9)
	tick(false)
	tick(true)
	check(not builder.preview_valid, "head intersecting preview blocks placement")
	state.tracking = false
	tick(false)
	check(not builder.is_active(), "tracking loss cancels preview")
	state.tracking = true
	state.head = Vector3(0,1.6,0)
	builder.charges = 0
	tick(false)
	tick(true)
	check(not builder.preview_valid and builder.invalid_reason == "capacity", "resource exhausted placement rejected")
	builder.reset_builds()
	await physics_frame
	await physics_frame
	var game := ObjectiveGame.new()
	scene.add_child(game)
	builder._game = game
	builder.piece_index = 2
	builder._set_piece()
	tick(false)
	builder._update_placement(state)
	check(builder.preview_valid, "floor preview valid on supported ground")
	game.targets = [{"position": builder.preview.global_position}]
	tick(true)
	check(not builder.preview_valid and builder.invalid_reason == "objective_clearance", "objective grip protected from construction")
	game.targets.clear()
	tick(false)
	tick(true)
	check(builder.pieces.size() == 1 and builder.pieces[0].get_child(1).shape is BoxShape3D, "floor confirmation creates real solid collider")
	await physics_frame
	await physics_frame
	var floor_body: StaticBody3D = builder.pieces[0]
	var floor_hit := scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(floor_body.global_position + Vector3.UP,floor_body.global_position + Vector3.DOWN))
	check(not floor_hit.is_empty() and floor_hit.collider == floor_body, "placed floor supports downward collision query")
	builder.reset_builds()
	await physics_frame
	await physics_frame
	state.origin = Vector3(20,1.6,20)
	state.head = state.origin
	tick(false)
	tick(true)
	check(not builder.preview_valid, "unsupported air placement rejected")
	state.cancel = true
	tick(false)
	check(not builder.is_active(), "dominant holster/draw cancel path closes preview")
	state.cancel = false
	state.origin = Vector3(0,1.6,0)
	state.head = state.origin
	tick(false)
	tick(true)
	builder.max_live_pieces = 0
	tick(false)
	check(not builder.preview_valid and builder.invalid_reason == "capacity", "live geometry cap enforced separately from charges")
	builder.reset_builds()
	await process_frame
	scene.queue_free()
	await process_frame
	print("BUILDING039 ",passed," passed ",failed," failed")
	quit(1 if failed else 0)

