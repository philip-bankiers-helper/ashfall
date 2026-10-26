extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var assets=load("res://scripts/blade_assets.gd");var shield=load("res://scripts/directional_shield.gd")
	for data in [["katana",.83,-.075],["excalibur",.95,0.0],["cyberblade",.79,-.012]]:
		var model:=Node3D.new();root.add_child(model);var built:Dictionary=assets.build(model,data[0]);var base:=Vector3(0,.085,.025)
		var old_tip:=base+Vector3(0,data[1],data[2]);var old_lower:=base+Vector3.UP*.04
		check(built.tip.position.distance_to(base+(old_tip-base)*1.3)<.00001,"authored tip and curvature exactly30percent longer "+data[0])
		check(absf(built.tip.position.distance_to(built.base.position)/old_tip.distance_to(old_lower)-1.3)<.00001,"actual damage contact span exactly30percent longer "+data[0])
		check(model.get_node("GripCore").position==assets.GRIP and model.get_node("GripCore").mesh.size==Vector3(.032,.225,.037),"controller-sized grip/contact unchanged "+data[0])
		var blade:MeshInstance3D=model.get_node("AuthoredBlade")
		check(absf(blade.mesh.get_aabb().size.y-data[1]*1.3)<.00001,"rendered blade matches extended contact reach "+data[0]);model.free()
	for yaw in [0.0,.55]:
		var plane:=Transform3D(Basis(Vector3.UP,yaw),Vector3(3,2,-4))
		for point in [Vector2.ZERO,Vector2(.41,.55),Vector2(-.41,-.55),Vector2(.41,-.55)]:
			check(not shield.intersect_bullet(plane*Vector3(point.x,point.y,-2),plane*Vector3(point.x,point.y,2),plane,Vector2(.42,.56)).is_empty(),"rectangle covers center and formerly-oval corner "+str(point))
		for point in [Vector2(.421,0),Vector2(0,.561),Vector2(-.421,-.4)]:
			check(shield.intersect_bullet(plane*Vector3(point.x,point.y,-2),plane*Vector3(point.x,point.y,2),plane,Vector2(.42,.56)).is_empty(),"outside rectangle still passes "+str(point))
		check(shield.intersect_bullet(plane*Vector3(0,0,2),plane*Vector3(0,0,-2),plane,Vector2(.42,.56)).is_empty(),"rectangular shield remains front-only")
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var sword=load("res://scripts/melee_sword.gd").new();root.add_child(sword);sword.setup(actor,false);sword.set_process(false);sword.set_physics_process(false)
	check((sword.shield_visual.mesh as QuadMesh).size==Vector2(.84,1.12) and sword.shield_visual.material_override.shader.code.contains("max(abs(p.x),abs(p.y))"),"visible shield is same bounded rectangle as bullet test")
	sword.shutdown();sword.free();actor.free();await create_timer(.2).timeout
	print("SWORDS_058_GEOMETRY checks=",checks," failures=",failures," native_rendered=false headset_tested=false");quit(failures)
