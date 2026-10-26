extends SceneTree
const Builder = preload("res://scripts/field_builder.gd")
class Actor extends Node3D:
	var eye := 0.55
	var tracking_available := false
	func measured_eye_height() -> float: return eye
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ",label)
	else: failed += 1; printerr("FAIL ",label)
func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var actor := Actor.new()
	scene.add_child(actor)
	var builder := Builder.new()
	scene.add_child(builder)
	builder.setup(actor,null,null)
	check(is_equal_approx(builder.wall_height,1.8),"startup missing pose uses minimum1.8")
	builder._placement = Transform3D(Basis.IDENTITY,Vector3(0,.92,-2))
	builder.preview_valid = true
	builder._commit()
	var old = builder.pieces[0]
	var old_shape = old.get_child(1).shape
	var old_mesh = old.visual.mesh
	var old_transform: Transform3D = old.transform
	var state := {"trigger":true,"eligible":false,"tracking":true}
	actor.eye = 1.9
	builder.tick_input(state)
	check(is_equal_approx(builder.wall_height,1.8),"actor tracking unavailable ignores tall sample")
	actor.tracking_available = true
	state.tracking = false
	builder.tick_input(state)
	check(is_equal_approx(builder.wall_height,1.8),"input tracking unavailable ignores tall sample")
	state.tracking = true
	builder.tick_input(state)
	check(is_equal_approx(builder.wall_height,2.02) and is_equal_approx(builder._shape.size.y,2.02),"first valid tracked pose calibrates newpreview before input conflicts")
	check(old.get_child(1).shape == old_shape and old.visual.mesh == old_mesh and is_equal_approx(old_shape.size.y,1.8) and old.transform == old_transform,"placed wall mesh collider and center never resize")
	check(builder._shape != old_shape and builder.preview.mesh != old_mesh,"newpreview owns independent geometry")
	actor.eye = .9
	builder.tick_input(state)
	check(is_equal_approx(builder.wall_height,2.02),"crouch never shrinks standing maximum")
	for invalid in [NAN,INF,-INF,-1.0,4.0]:
		actor.eye = invalid
		builder.tick_input(state)
	check(is_equal_approx(builder.wall_height,2.02),"nonfinite and implausible eye samples ignored")
	var previous_shape = builder._shape
	actor.eye = 1.91
	builder.tick_input(state)
	check(builder._shape == previous_shape,"sub2cm tracking noise does not allocate geometry")
	actor.eye = 2.0
	builder.tick_input(state)
	check(is_equal_approx(builder.wall_height,2.12),"new standing maximum grows future wall")
	check(builder.pieces.size() == 1 and builder.charges == 5,"calibration and held trigger do not place or spend")
	builder.piece_index = 1
	builder._set_piece()
	var ramp_shape = builder._shape
	actor.eye = 2.1
	builder.tick_input(state)
	check(is_equal_approx(builder.wall_height,2.22) and builder._shape == ramp_shape,"calibrating while ramp selected leaves ramp geometry unchanged")
	builder.piece_index = 0
	builder._set_piece()
	check(is_equal_approx(builder._shape.size.y,2.22),"returning to wall uses new standing calibration")
	builder.reset_builds()
	check(is_equal_approx(builder.wall_height,2.22),"chapter reset preserves standing calibration")
	print("NEWCALIBRATION_041_RESULT ",passed," passed ",failed," failed")
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)
