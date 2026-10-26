extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for side in ["right","left"]:
		actor.dominant_hand=side
		for body_yaw in [0.0,PI*.5,PI]:
			actor.rotation.y=body_yaw
			for heading_yaw in [0.0,PI*.5,PI,PI*1.5]:
				var forward:=Vector3.FORWARD.rotated(Vector3.UP,heading_yaw);var right:=forward.cross(Vector3.UP)
				var left_point:Vector3=actor.to_global(Vector3(-.6,1.6,0));var right_point:Vector3=actor.to_global(Vector3(.6,1.2,0))
				var heading:Vector3=actor.update_glide_heading(forward,left_point,right_point,true,.0001)
				check(heading.dot(right)>.3 and is_zero_approx(heading.y),side+" lower physical RIGHT arm banks toward travel-right at independent body/heading yaw %.2f/%.2f"%[body_yaw,heading_yaw])
				var next:Vector3=actor.update_glide_heading(forward,right_point,left_point,true,.0001)
				check(next.dot(right)<-.3,side+" reverse physical height immediately reverses bank")
				var slow:Vector3=actor.update_glide_heading(forward,left_point,right_point,true,.1)
				check(slow.is_equal_approx(heading),side+" no exponential steering delay at different delta")
				check(actor.update_glide_heading(forward,left_point,right_point,false,.1).is_equal_approx(forward),side+" tracking loss clears banking")
	actor.rotation=Vector3.ZERO;actor.global_position=Vector3(0,1000,0);actor.velocity=Vector3.ZERO;actor._supported=false
	actor.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,.1)
	check(is_equal_approx(actor.velocity.y,-1.62),"actual unsupported physics applies 16.2 gravity after ten-percent reduction")
	check(is_equal_approx(actor.GLIDE_HORIZONTAL_SPREAD,.95890625),"horizontal spread boundary retains additional five-percent reduction")
	actor.free();await process_frame
	print("GLIDE_GRAVITY_048 checks=",checks," failures=",failures," heading_independent=true immediate=true physical_direction_confirmation_pending=true")
	quit(failures)
