extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run()->void:
	load("res://scripts/audio_bank.gd").ensure_buses()
	var floor:=StaticBody3D.new();root.add_child(floor);floor.position.y=-.1
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.2,100);collider.shape=box;floor.add_child(collider)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);freeze(actor)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);freeze(rack)
	await physics_frame;await physics_frame
	var inv=load("res://scripts/weapon_inventory.gd").new();root.add_child(inv);inv.setup(actor,rack);inv.set_process(false)
	await physics_frame;await physics_frame;await physics_frame
	var points:Array[Vector3]=[]
	for index in inv.pickups:
		var prop:Node3D=inv.pickups[index];points.append(prop.global_position)
		check(prop.global_basis.y.dot(Vector3.UP)>.9999,"ground weapon%d stays upright rather than left side"%index)
		check(absf(inv._lowest_mesh_point(prop)-.75)<.001,"ground weapon%d retains75cm lowest-mesh hover"%index)
	var nearest:=INF
	for i in points.size():
		for j in range(i+1,points.size()):
			var a:=Vector2(points[i].x,points[i].z);var b:=Vector2(points[j].x,points[j].z);nearest=minf(nearest,a.distance_to(b))
	check(nearest>=1.39,"pickup rows have at least1.4m separation instead of overlapping62cm rows")
	var katana:Node3D=inv.pickups[14]
	check(inv._pickup_center(14).distance_to(katana.to_global(rack.weapons[14].hand_grip_center))<.001,"Katana aimed pickup ring is at reachable hilt, not blade midpoint")
	var ammo:Dictionary=rack.reserves.duplicate();var loaded:int=rack.weapons[0].ammo
	for side in ["right","left"]:
		actor.dominant_hand=side;rack._refresh_hands();rack.selected=0;rack.is_holstered=false;rack._apply_selection()
		actor.desktop_camera.rotation=Vector3(0,.73 if side=="right" else -1.12,0)
		check(inv.drop_weapon(0),side+" drop commits only after reachable floor checks")
		var prop:Node3D=inv.pickups[0];var head:Vector3=actor.desktop_camera.global_position
		var forward:Vector3=-actor.desktop_camera.global_basis.z;forward.y=0;forward=forward.normalized()
		var offset:=prop.global_position-head;offset.y=0
		check(absf(offset.length()-1.0)<.001 and offset.normalized().dot(forward)>.9999,side+" dropped gun is exactly1m in user's viewing direction")
		check((-prop.global_basis.z).dot(forward)>.9999 and prop.global_basis.y.dot(Vector3.UP)>.9999,side+" dropped muzzle faces away from user with upright grip")
		check(absf(inv._lowest_mesh_point(prop)-.75)<.001,side+" drop preserves hover and retrieval height")
		check(inv.pickup_weapon(0),side+" dropped persistent instance remains retrievable")
	check(rack.reserves==ammo and rack.weapons[0].ammo==loaded,"drop/pickup never duplicates or spends ammunition")
	inv.free();rack.shutdown();rack.free();actor.free();floor.free();await process_frame
	print("PICKUP_ORIENTATION_061 checks=",checks," failures=",failures," cpu_physics=true headset_tested=false rendered=false")
	quit(failures)
