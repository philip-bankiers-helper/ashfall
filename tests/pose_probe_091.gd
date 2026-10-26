extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var glove:=preload("res://scripts/grip_hand_086.gd").new();root.add_child(glove);glove.setup(false)
	for key in glove.poses:
		var rotations:Dictionary=glove.poses[key];print("POSE ",key," tracks=",rotations.size())
		for bone in ["Index_Proximal_R","Middle_Proximal_R","Middle_Intermediate_R","Middle_Distal_R"]:
			print("  ",bone," ",rotations.get(bone))
	for id in ["fal","magnum","matadors","katana"]:
		var weapon:=Node3D.new();root.add_child(weapon);weapon.set_meta("reference_id",id)
		glove.update_pose(1,1,{"role":"weapon","weapon":weapon,"profile":"sword" if id=="katana" else "gun"},1)
		var sk:Skeleton3D=glove.skeleton;var wrist:=sk.get_bone_global_pose(sk.find_bone("Wrist_R")).origin
		for name in ["Middle_Distal_R","Ring_Distal_R"]:
			print("TIP ",id," ",name," ",sk.get_bone_global_pose(sk.find_bone(name)).origin," wrist_dist=",wrist.distance_to(sk.get_bone_global_pose(sk.find_bone(name)).origin))
		weapon.queue_free()
	glove.queue_free();await process_frame;quit()
