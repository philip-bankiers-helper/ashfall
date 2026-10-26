extends SceneTree
class Gun extends "res://scripts/weapon.gd":
	func _input_allowed()->bool:return true
	func _hand_input_ready(_hand)->bool:return true
var failures:=0
var checks:=0
func check(ok:bool,text:String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",text)
func _initialize():call_deferred("run")
func run():
	var actor:=Node3D.new();root.add_child(actor)
	var left:=XRController3D.new();var right:=XRController3D.new();actor.add_child(left);actor.add_child(right)
	left.position=Vector3(-0.2,1.3,-0.35);right.position=Vector3(0.2,1.3,-0.35)
	var gun:=Gun.new();root.add_child(gun);gun.set_process(false);gun.player=actor;gun.motion_damping=1
	for hand in [left,right]:
		gun.right_hand=hand
		for speed in [360.0,720.0,180.0]:
			for moving in [false,true]:
				actor.transform=Transform3D.IDENTITY;gun._aim_filter_ready=false
				gun.global_transform=gun.corrected_grip_transform(hand.global_transform);gun._apply_aim_filter(1.0/90)
				var max_error:=0.0
				var max_position_error:=0.0
				for frame in range(1 if speed==180 else 90):
					actor.rotate_y(deg_to_rad(180 if speed==180 else speed/90))
					if moving:actor.position+=Vector3(0.01,0,0.02)
					var expected:Transform3D=gun.corrected_grip_transform(hand.global_transform)
					gun.global_transform=expected;gun._apply_aim_filter(1.0/90)
					max_error=maxf(max_error,(-gun.global_basis.z).distance_to(-expected.basis.z))
					max_position_error=maxf(max_position_error,gun.global_position.distance_to(expected.origin))
				check(max_error<0.00001 and max_position_error<0.00001,"same-frame turn "+str(speed)+" moving="+str(moving)+" hand="+("left" if hand==left else "right"))
	gun._aim_filter_ready=false;gun.global_transform=gun.corrected_grip_transform(right.global_transform);gun._apply_aim_filter(0.01)
	var before:Basis=gun.global_basis
	right.rotate_y(0.3)
	var target:Basis=gun.corrected_grip_transform(right.global_transform).basis
	gun.global_basis=target;gun._apply_aim_filter(0.01)
	check(not gun.global_basis.is_equal_approx(target) and not gun.global_basis.is_equal_approx(before),"independent physical hand movement remains damped")
	gun.free();actor.free()
	print("TURN_AIM_RESULT checks=",checks," failures=",failures)
	quit(failures)
