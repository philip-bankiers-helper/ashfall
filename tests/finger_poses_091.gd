extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	var actor:=preload("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack:=preload("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	for side in ["left","right"]:
		actor.dominant_hand=side;rack._refresh_hands();var hand:XRController3D=actor.get_weapon_hand();var adapter:Node3D=actor._hand_visuals[hand].get_node("SkinnedGlove086")
		for index in [0,1,2,3,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,23,24,25,27]:
			rack.selected=index;rack.is_holstered=false;rack._apply_selection();var contact:Dictionary=actor.get_hand_art_contact(hand);var tracked:Transform3D=hand.global_transform;var gun:Node3D=contact.weapon;var gun_pose:Transform3D=gun.global_transform
			adapter.update_pose(1,1,contact,1)
			var suffix:="_L" if side=="left" else "_R";var bone:String="Middle_Intermediate"+suffix;var sk:Skeleton3D=adapter.skeleton
			var pose_name:="Grip Shaft" if index in [14,15,16] else ("Grip 1" if index in [2,7,12,18,19,20] else "Grip")
			var opened:Quaternion=adapter.poses["Grip 5"][bone];var closed:Quaternion=adapter.poses[pose_name][bone];var actual:Quaternion=sk.get_bone_pose_rotation(sk.find_bone(bone))
			var old_amount:float=1.05 if index in [2,7,12,14,15,16,18,19,20] else (.88 if index in [0,3,6,10,21,23,24,27] else 1.0)
			var old:Quaternion=opened.slerp(closed,old_amount)
			if index==12:check(actual.angle_to(old)<.003,"accepted Matador pose unchanged")
			elif index in [7,14,15,16,20]:check(actual.angle_to(opened)>old.angle_to(opened)+.015,"actual skinned fingers visibly tighter "+str(index))
			else:check(actual.angle_to(opened)<old.angle_to(opened)-.025,"actual skinned fingers visibly wider "+str(index))
			check(hand.global_transform.is_equal_approx(tracked) and gun.global_transform.is_equal_approx(gun_pose),"bone edits preserve tracking / gun aim "+str(index))
	rack.shutdown();rack.queue_free();actor.queue_free();await process_frame
	print("FINGER_POSES_091 checks=",checks," failures=",failures," posed_skin_measured=true headset_tested=false");quit(failures)
