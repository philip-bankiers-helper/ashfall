extends SceneTree
var failed:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value:failed+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new()
	root.add_child(actor);actor.setup(false);actor.set_physics_process(false);actor.set_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new()
	root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	var ray:=Transform3D(Basis.IDENTITY,Vector3(.1,1.3,0))
	rack.update_a_input(.01,false,true,ray)
	rack.update_a_input(.01,true,true,ray)
	check(rack.is_selecting and rack.wheel.visible,"A-down opens wheel immediately")
	var initial:Transform3D=rack.wheel.global_transform
	actor.get_view_camera().rotation=Vector3(.5,.9,.2)
	actor.right_hand.position+=Vector3(.4,.2,.1)
	actor.right_hand.rotation=Vector3(.3,.4,.1)
	rack.update_a_input(.01,true,true,ray)
	check(rack.wheel.global_transform.is_equal_approx(initial),"head/controller movement cannot recenter or rotate held wheel")
	var translation:=Vector3(4,.35,-7)
	actor.global_position+=translation
	rack.update_a_input(.01,true,true,ray)
	check(rack.wheel.global_position.is_equal_approx(initial.origin+translation),"running translates wheel by exact player delta")
	check(rack.wheel.global_basis.is_equal_approx(initial.basis),"locomotion preserves captured wheel orientation")
	actor.rotation.y=1.4
	rack.rotation.y=.7
	rack.update_a_input(.01,true,true,ray)
	check(rack.wheel.global_position.is_equal_approx(initial.origin+translation) and rack.wheel.global_basis.is_equal_approx(initial.basis),"body and rack rotation cannot orbit or turn anchored wheel")
	actor.get_view_camera().position.x=.45
	actor.get_view_camera().position.z=.3
	var pivot_before:Vector3=actor.get_view_camera().global_position
	var wheel_before:Transform3D=rack.wheel.global_transform
	actor.snap_turn(deg_to_rad(45))
	rack.update_a_input(.01,true,true,ray)
	check(actor.get_view_camera().global_position.is_equal_approx(pivot_before),"actual off-center snap turn preserves head pivot")
	check(rack.wheel.global_transform.is_equal_approx(wheel_before),"actual off-center snap-turn origin compensation cannot move held wheel")
	actor.turning_style="smooth"
	actor.apply_turn_input(.9,.1)
	rack.update_a_input(.01,true,true,ray)
	check(rack.wheel.global_transform.is_equal_approx(wheel_before),"actual off-center smooth turn cannot move held wheel")
	actor._last_head=actor.xr_camera.global_position
	actor.xr_camera.position+=Vector3(.25,0,-.2)
	var tracked_before:Vector3=actor.xr_camera.global_position
	actor._sync_body_to_head()
	rack.update_a_input(.01,true,true,ray)
	check(actor.xr_camera.global_position.is_equal_approx(tracked_before),"roomscale recenter preserves raw XR head world pose")
	check(rack.wheel.global_transform.is_equal_approx(wheel_before),"roomscale body recenter cannot drag held wheel")
	var target:Vector3=rack.wheel.to_global(rack.wheel.slot_position(6,.8))
	var pointer_origin:=ray.origin+translation
	var pointer_ray:=Transform3D(Basis.looking_at(target-pointer_origin,Vector3.UP),pointer_origin)
	rack.update_a_input(.01,true,true,pointer_ray)
	check(rack.wheel.highlighted==6,"independent pointer still selects angle beyond wheel radius after running")
	check(rack.wheel.global_position.is_equal_approx(initial.origin+translation),"pointer sweep never drags anchor")
	rack.cancel_selection()
	var next_ray:=Transform3D(Basis(Vector3.UP,.4),Vector3(-2,1.4,3))
	rack.update_a_input(.01,false,true,next_ray)
	rack.update_a_input(.01,true,true,next_ray)
	check(not rack.wheel.global_position.is_equal_approx(initial.origin+translation),"new opening captures a fresh aim anchor")
	rack.wheel.set_owned_indices([0,2,4,6,8,11])
	var count:=0
	for action in rack.wheel.SLOT_ACTIONS:
		if action.begins_with("weapon_"):count+=1
	check(count==6,"all six carried weapons fit distinct wheel sectors")
	check(rack.wheel.SLOT_ACTIONS.has("backpack") and rack.wheel.SLOT_ACTIONS.has("revive_unavailable"),"six weapons retain backpack and revive utility sectors")
	check(rack.wheel.SLOT_ACTIONS[0].begins_with("weapon_"),"former empty noon sector becomes sixth weapon sector")
	rack.shutdown();await create_timer(.2).timeout;rack.free();actor.free()
	print("WHEEL_ANCHOR_045 checks=",checks," failures=",failed," synthetic=true headset_tested=false")
	quit(failed)


