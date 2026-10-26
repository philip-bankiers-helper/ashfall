extends SceneTree
class Actor extends Node3D:
	var eye:=.55
	var tracking_available:=false
	func measured_eye_height()->float:return eye
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor:=Actor.new();root.add_child(actor)
	var builder=load("res://scripts/field_builder.gd").new();root.add_child(builder);builder.setup(actor,null,null)
	check(is_equal_approx(builder.wall_height,2.2*1.15) and builder.wall_height==builder.grid_spacing,"B01 startup square minimum2.53m")
	var state:={"eligible":false,"tracking":true,"trigger":true}
	actor.eye=2.1;builder.tick_input(state);check(is_equal_approx(builder.wall_height,2.2*1.15),"P01 unavailable tracking cannot recalibrate")
	actor.tracking_available=true;builder.tick_input(state)
	check(is_equal_approx(builder.wall_height,2.28*1.15) and builder._shape.size.x==builder._shape.size.y,"B01 valid standing calibration enlarges both square dimensions")
	for value in [NAN,INF,-INF,-1.0,4.0]:actor.eye=value;builder.tick_input(state)
	check(is_equal_approx(builder.wall_height,2.28*1.15),"P01 invalid eye samples rejected")
	builder._placement=Transform3D(Basis.IDENTITY,Vector3(0,1.14*1.15,-3));builder.preview_valid=true;builder._commit()
	var old=builder.pieces[0];var old_shape=old.get_child(1).shape;var old_transform:Transform3D=old.transform
	actor.eye=2.2;builder.tick_input(state)
	check(is_equal_approx(builder.grid_spacing,2.28*1.15) and old.get_child(1).shape==old_shape and old.transform==old_transform,"B02 placed grid and corners stay immutable through later height samples")
	builder.reset_builds();builder.tick_input(state)
	check(is_equal_approx(builder.grid_spacing,2.38*1.15) and builder._shape.size.y==builder._shape.size.x,"B01 after reset taller standing sample can calibrate whole new grid")
	actor.eye=.9;builder.tick_input(state);check(is_equal_approx(builder.grid_spacing,2.38*1.15),"P01 crouching cannot shrink standing grid")
	check(builder.pieces.is_empty() and builder.charges==builder.initial_charges,"P01 calibration/conflicting held input never spends or creates panels")
	builder.free();actor.free();await process_frame
	print("CALIBRATION_053 checks=",checks," failures=",failures)
	quit(failures)

