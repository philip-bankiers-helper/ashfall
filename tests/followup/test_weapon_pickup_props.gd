extends SceneTree
var failures:=0
var checks:=0
func check(ok:bool,text:String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",text)
func inert(node:Node)->bool:
	if node is CollisionObject3D or node is AudioStreamPlayer3D:return false
	if node.get_script()!=null:return false
	for child in node.get_children():
		if not inert(child):return false
	return true
func _initialize():call_deferred("run")
func run():
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for weapon in rack.weapons:weapon.set_process(false);weapon.set_physics_process(false)
	var before_ammo:Array[int]=[]
	for i in range(rack.weapons.size()):
		rack.weapons[i].ammo=i+1
		before_ammo.append(i+1)
	var props=load("res://scripts/weapon_pickup_props.gd").new();root.add_child(props);props.setup(rack,Vector3(2,1,3))
	var targets:Array=props.get_grip_targets()
	var shelf:MeshInstance3D=props.get_child(0)
	check(shelf.get_child_count()==2,"shelf has two visible support legs")
	for leg in shelf.get_children():check(absf(leg.global_position.y-leg.mesh.size.y*0.5)<0.00001,"shelf support reaches staging floor")
	check(targets.size()==5 and rack.weapons.size()==5,"five explicit owned-weapon grip targets")
	for i in range(5):
		check(targets[i].id=="weapon_pickup:"+str(i),"target%d has explicit dispatch identity"%i)
		check(targets[i].position.is_equal_approx(Vector3(2+(i-2)*.56,.92,3)),"target%d coincides with displayed grip mount"%i)
		check(inert(props.get_child(i+1).get_child(0)),"cloned model%d is inert visual branch"%i)
		check(rack.weapons[i].ammo==before_ammo[i],"creating pickup%d never grants ammunition"%i)
	check(rack.select_weapon(1),"grip dispatch can select existing Cinder")
	rack.set_holstered(false)
	for i in range(5):
		check(rack.select_weapon(i),"grip dispatch selects owned slot%d"%i)
		check(rack.weapons[i].ammo==before_ammo[i],"select and draw preserve slot%d ammunition"%i)
	rack.select_weapon(0);rack.weapons[0].eject_magazine();rack.weapons[0].grab_magazine()
	check(not rack.select_weapon(1),"grip dispatch cannot bypass carried-reload protection")
	props.free();rack.shutdown();await create_timer(0.12).timeout;rack.free();actor.free()
	print("WEAPON_PICKUP_PROPS_RESULT checks=",checks," failures=",failures)
	quit(failures)

