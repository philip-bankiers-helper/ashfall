extends SceneTree
const Builder = preload("res://scripts/field_builder.gd")
class Actor extends Node3D:
	var eye := 1.95
	func measured_eye_height() -> float: return eye
class Protected extends Node:
	var targets: Array = []
	func _construction_protected_targets() -> Array: return targets
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ",label)
	else: failed += 1; printerr("FAIL ",label)
func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40,0.5,40)
	collider.shape = shape
	floor_body.add_child(collider)
	scene.add_child(floor_body)
	floor_body.position.y = -0.25
	var actor := Actor.new()
	scene.add_child(actor)
	var game := Protected.new()
	scene.add_child(game)
	var builder := Builder.new()
	scene.add_child(builder)
	builder.setup(actor,null,game)
	check(is_equal_approx(builder.wall_height,2.07),"wall caches standing eye plus head top")
	actor.eye = 0.9
	builder._set_piece()
	check(is_equal_approx(builder.wall_height,2.07) and is_equal_approx(builder._shape.size.y,2.07),"crouching cannot shrink calibrated wall")
	await physics_frame
	await physics_frame
	var state := {"trigger":false,"cycle":false,"eligible":true,"tracking":true,"origin":Vector3(.31,1.6,.21),"direction":Vector3(.12,-.7,-1).normalized(),"head":Vector3(.31,1.6,.21)}
	builder.tick_input(state)
	state.trigger = true
	builder.tick_input(state)
	check(builder.pieces.size() == 1 and builder.charges == 5,"first fresh valid trigger immediately places and spends once")
	var panel = builder.pieces[0]
	check(is_zero_approx(fmod(absf(panel.position.x),2.0)) and is_zero_approx(fmod(absf(panel.position.z),2.0)),"off-grid aim snaps to world2m centers")
	check(is_zero_approx(fmod(absf(panel.rotation.y),PI/2.0)),"oblique aim snaps yaw90degrees")
	check(is_zero_approx(fmod(absf(panel.position.y-builder.wall_height/2.0-.02),.1)),"support base snaps vertical10cm grid")
	var material: StandardMaterial3D = panel.visual.material_override
	check(material.albedo_texture != null and material.roughness_texture != null and material.emission_texture != null and material.metallic > .5,"original generated sci-fi panel has PBR texture and luminous seams")
	panel.hit(30)
	panel._process(.2)
	check(material.albedo_color.r < .8 and material.emission.r > .15,"damage darkens panel and warms warning seams")
	for repeat in 5: builder.tick_input(state)
	check(builder.pieces.size() == 1 and builder.charges == 5,"held trigger never repeats")
	for repeat in 3:
		state.trigger = false; builder.tick_input(state)
		state.trigger = true; builder.tick_input(state)
	check(builder.pieces.size() == 1 and builder.charges == 5 and builder.invalid_reason == "occupied_slot","rapid duplicate presses do not double-spend same slot")
	var at: Vector3 = panel.position
	state.origin = Vector3(at.x,1.6,at.z-2)
	state.head = state.origin
	state.direction = Vector3(0,-.8,1).normalized()
	state.trigger = false; builder.tick_input(state)
	state.trigger = true; builder.tick_input(state)
	check(builder.pieces.size() == 1 and builder.charges == 5,"opposite facing same wall slot cannot double-spend")
	state.origin = Vector3(at.x+2,1.6,at.z)
	state.head = state.origin
	state.direction = Vector3(-1,-.8,0).normalized()
	state.trigger = false; builder.tick_input(state)
	state.trigger = true; builder.tick_input(state)
	check(builder.pieces.size() == 2 and builder.charges == 4,"perpendicular wall may intersect existing wall same center")
	await physics_frame
	await physics_frame
	panel.hit(1000)
	await physics_frame
	await physics_frame
	state.origin = Vector3(.31,1.6,.21)
	state.head = state.origin
	state.direction = Vector3(.12,-.7,-1).normalized()
	state.trigger = false; builder.tick_input(state)
	state.trigger = true; builder.tick_input(state)
	check(builder.pieces.size() == 2 and builder.charges == 3,"destroyed slot reusable while crossing wall survives")
	builder.reset_builds()
	await physics_frame
	await physics_frame
	state.origin = Vector3(0,1.6,.9)
	state.head = state.origin
	state.direction = Vector3(0,-.4,-1).normalized()
	builder._update_placement(state)
	check(not builder.preview_valid and builder.invalid_reason == "reach","strict4.5m reach rejects anchor with no oldhalf-meter allowance")
	state.origin = Vector3(0,1.6,0)
	state.head = Vector3(0,1.6,4)
	state.direction = Vector3.DOWN
	game.targets = [{"position":Vector3(0,1,0)}]
	builder._update_placement(state)
	check(not builder.preview_valid and builder.invalid_reason == "objective_clearance","grid never overrides protected objective clearance")
	game.targets.clear()
	state.head = Vector3(0,1,0)
	builder._update_placement(state)
	check(not builder.preview_valid and builder.invalid_reason == "head_clearance","grid never traps tracked head")
	for column in 3:
		state.origin = Vector3(column*2,1.6,0)
		state.head = state.origin
		state.direction = Vector3(0,-.8,-1).normalized()
		state.trigger = false; builder.tick_input(state)
		state.trigger = true; builder.tick_input(state)
	check(builder.pieces.size() == 3 and builder.charges == 3,"rapid release-presses across grid columns place three walls without timer delay")
	state.tracking = false
	builder.tick_input(state)
	state.tracking = true
	state.origin.x = 6
	state.head = state.origin
	builder.tick_input(state)
	check(builder.pieces.size() == 3,"held trigger after tracking restoration does not accidentally build")
	print("BUILDING_GRID_040_RESULT ",passed," passed ",failed," failed")
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)
