extends SceneTree
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var rifle_script=load("res://scripts/weapon.gd")
	var raw:=Transform3D(Basis.from_euler(Vector3(0.2,0.7,-0.3)),Vector3(3,2,1))
	var corrected:Transform3D=rifle_script.corrected_grip_transform(raw)
	check(corrected.origin==raw.origin,"grip correction does not translate tracked origin")
	check((raw.basis.inverse()*corrected.basis.y).is_equal_approx(Vector3.FORWARD),"local positive Y rotates to negative Z")
	check((raw.basis.inverse()*corrected.basis.z).is_equal_approx(Vector3.UP),"local positive Z rotates to positive Y")
	check(corrected.basis.x.is_equal_approx(raw.basis.x),"local X axis unchanged")
	var actor=load("res://scripts/player.gd").new()
	root.add_child(actor)
	actor.setup(false)
	actor.set_process(false);actor.set_physics_process(false)
	actor.right_hand.global_transform=raw
	actor.left_hand.global_transform=raw
	var glove:Node3D=actor._hand_visuals[actor.right_hand]
	var rolled_glove:=Transform3D(corrected.basis*Basis(Vector3.FORWARD,-PI/2.0),raw.origin)
	check(glove.global_basis.is_equal_approx(rolled_glove.basis),"visible right glove uses corrected grip and inward roll")
	check(glove.global_position.is_equal_approx(rolled_glove*Vector3(0,-0.023,0.025)),"glove art offset rotates with corrected grip and roll")
	for name in ["weapon","shotgun"]:
		var weapon=load("res://scripts/"+name+".gd").new()
		root.add_child(weapon)
		weapon._build_model()
		weapon.set_process(false);weapon.set_physics_process(false)
		weapon.left_hand=actor.left_hand
		weapon.right_hand=actor.right_hand
		weapon.global_transform=weapon.corrected_grip_transform(raw)
		var muzzle:=Vector3(0,0.045,-0.69) if name=="weapon" else Vector3(0,0.04,-0.65)
		check(weapon.to_global(muzzle).is_equal_approx(corrected*muzzle),name+" muzzle derives from corrected weapon root")
		check((-weapon.global_basis.z).is_equal_approx(-corrected.basis.z),name+" shot direction derives from corrected root")
		check(weapon.sight_front.global_basis.is_equal_approx(corrected.basis),name+" closed sight axes follow corrected root")
		if name=="weapon":
			check(weapon.get_offered_magazine_transform().origin.is_equal_approx(corrected*weapon.OFFER_POINT),"magazine offer follows corrected root")
			if weapon.has_method("get_held_magazine_transform"):check(weapon.get_held_magazine_transform().basis.is_equal_approx(corrected.basis),"held magazine correction follows hand")
		elif weapon.has_method("get_held_shell_transform"):check(weapon.get_held_shell_transform().basis.is_equal_approx(corrected.basis),"held shell correction follows hand")
		weapon.free()
	check(actor.right_hand.global_transform==raw and actor.left_hand.global_transform==raw,"raw controller roots remain unchanged")
	actor.free()
	print("GRIP_CORRECTION_RESULT checks=",checks," failures=",failures," headset_tested=false")
	quit(failures)
