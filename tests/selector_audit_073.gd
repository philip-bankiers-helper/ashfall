extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var wheel=load("res://scripts/weapon_wheel.gd").new();root.add_child(wheel);wheel.show();wheel.set_owned_indices([0,1,2,3,4,5])
	var marks=load("res://scripts/team_marks.gd").new();root.add_child(marks);marks.set_physics_process(false)
	check(is_equal_approx(wheel.INNER_RADIUS/wheel.OUTER_RADIUS,marks.INNER_RADIUS/marks.OUTER_RADIUS),"both selector center discs share reference proportion")
	for i in 8:
		wheel.point(wheel.global_transform*Transform3D(Basis.IDENTITY,wheel.slot_position(i,.095)+Vector3.BACK))
		check(wheel.highlighted==-1,"expanded center cancels actual ray sector "+str(i))
		wheel.point(wheel.global_transform*Transform3D(Basis.IDENTITY,wheel.slot_position(i,.15)+Vector3.BACK))
		check(wheel.highlighted==i,"ordinary ring still selects actual ray sector "+str(i))
	wheel.free();marks.free()
	print("SELECTOR_AUDIT_073 checks=",checks," failures=",failures);quit(failures)
