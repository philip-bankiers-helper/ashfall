extends SceneTree
const Builder = preload("res://scripts/field_builder.gd")
class ProtectedGame extends Node:
	var targets: Array = []
	func _objective_grip_targets() -> Array:
		return []
	func _construction_protected_targets() -> Array:
		return targets
var passed := 0
var failed := 0
var scene: Node3D
var builder: Node3D
var state := {"origin":Vector3(0,1.6,0), "direction":Vector3.DOWN, "head":Vector3(0,1.6,3)}
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ",label)
	else:
		failed += 1
		printerr("FAIL ",label)
func shape(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	node.shape = box
	node.position = at
	body.add_child(node)
func run() -> void:
	scene = Node3D.new()
	root.add_child(scene)
	var support := StaticBody3D.new()
	shape(support,Vector3(0,-0.25,0),Vector3(20,0.5,20))
	scene.add_child(support)
	builder = Builder.new()
	scene.add_child(builder)
	builder.setup(null,null,null)
	await physics_frame
	await physics_frame
	for kind in 3:
		builder.piece_index = kind
		builder._set_piece()
		builder._update_placement(state)
		check(builder.preview_valid,"clear ground accepts kind %s" % kind)
	# A compound body can contain floor plus architecture; excluding its RID
	# hides every shape on it, not just the support surface.
	shape(support,Vector3(0.5,0.6,0),Vector3(0.25,1.2,0.25))
	await physics_frame
	await physics_frame
	for kind in 3:
		builder.piece_index = kind
		builder._set_piece()
		builder._update_placement(state)
		print("OBSTRUCTION DETAIL ",kind," ",builder.invalid_reason," ",builder.preview.global_position)
		check(not builder.preview_valid,"same-support compound obstruction rejects kind %s" % kind)
	# Remove only the architectural shape, retaining the actual floor.
	support.get_child(1).queue_free()
	await physics_frame
	await physics_frame
	var game := ProtectedGame.new()
	scene.add_child(game)
	builder._game = game
	builder.piece_index = 0
	builder._set_piece()
	builder._update_placement(state)
	game.targets = [{"position":builder.preview.global_position}]
	builder._update_placement(state)
	check(not builder.preview_valid and builder.invalid_reason == "objective_clearance","inactive guarded objective protected independently of active grip targets")
	game.targets.clear()
	builder._update_placement(state)
	builder._commit()
	check(builder.pieces.size() == 1 and builder.charges == builder.initial_charges - 1,"commit spends one charge")
	await physics_frame
	await physics_frame
	var old_body: StaticBody3D = builder.pieces[0]
	builder.reset_builds()
	await physics_frame
	await physics_frame
	check(not is_instance_valid(old_body) and builder.pieces.is_empty() and builder.charges == builder.initial_charges,"reset frees physics body and refills budget")
	builder.max_live_pieces = 0
	builder._update_placement(state)
	check(not builder.preview_valid and builder.invalid_reason == "capacity","live piece cap blocks with charges available")
	builder.max_live_pieces = 12
	builder.piece_cost = 3
	builder.charges = 2
	builder._update_placement(state)
	check(not builder.preview_valid and builder.invalid_reason == "capacity","tunable multi-charge cost rejects insufficient budget")
	scene.queue_free()
	await process_frame
	print("BUILDING_GEOMETRY_REVIEW ",passed," passed ",failed," failed")
	quit(1 if failed else 0)



