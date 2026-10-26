extends SceneTree
const Assets=preload("res://scripts/blade_assets.gd")
const Shield=preload("res://scripts/directional_shield.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var records:Array=[]
	for kind in ["katana","excalibur","cyberblade","knife"]:
		var model:=Node3D.new();root.add_child(model);var built:Dictionary=Assets.build(model,kind)
		var pommel:MeshInstance3D=model.get_node("Pommel");var hilt:MeshInstance3D=model.get_node("GripCore")
		var bottom:Vector3=pommel.position-Vector3.UP*pommel.mesh.size.y*.5
		var target:=.38 if kind=="knife" else 1.4101590361445784
		check(absf(bottom.distance_to(built.tip.position)-target)<.000001,kind+" actual pommel-to-tip chord equals corrected length exactly once")
		var blade:MeshInstance3D=model.get_node("AuthoredBlade")
		check(absf(blade.mesh.get_aabb().end.y-built.tip.position.y)<.000001,kind+" physical damage tip follows actual blade mesh")
		if kind=="knife":
			check(hilt.mesh.size==Vector3(.033,.130,.036),"knife authored130mm handle is not blanket scaled")
			check(is_equal_approx(Assets.KNIFE_LENGTH,.38),"unmeasured authored38cm knife is preserved")
		else:
			check(hilt.mesh.size==Vector3(.032,.285,.037),kind+" authored controller-sized handle is not blanket scaled")
			check(is_equal_approx(bottom.distance_to(built.tip.position)/2.0,0.7050795180722892),kind+" corrected reference scale is0.6096, not compounded")
			check(absf(Assets.GRIP.distance_to(bottom)-0.23502650602409636)<.000001,kind+" primary fist exactly8in from outer pommel end")
			var guard:Vector3=Vector3(0,.085,Assets.GRIP.z)
			records.append({"kind":kind,"pommel_to_tip_m":bottom.distance_to(built.tip.position),"primary_fist_to_pommel_bottom_m":Assets.GRIP.distance_to(bottom),"primary_fist_to_guard_plane_m":absf(Assets.GRIP.y-guard.y),"requested_grip_distance_m":0.23502650602409636,"grip_datum_status":"resolved_outer_pommel_end"})
		model.free()
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var sword=load("res://scripts/melee_sword.gd").new();root.add_child(sword);sword.setup(actor,false);sword.set_process(false);sword.set_physics_process(false)
	check(sword.shield_visual.mesh.size.is_equal_approx(Vector2(1.1281272289156627,1.4101590361445784)),"corrected visible shield is0.97536×1.4101590361445784m")
	check((sword.SHIELD_RADII*2).is_equal_approx(sword.shield_visual.mesh.size),"shield visual and collision dimensions are identical")
	for yaw in [0.0,.65]:
		var plane:=Transform3D(Basis(Vector3.UP,yaw),Vector3(3,2,-4))
		for point in [Vector2.ZERO,Vector2(.48758,.6095),Vector2(-.48758,-.6095)]:
			check(not Shield.intersect_bullet(plane*Vector3(point.x,point.y,-2),plane*Vector3(point.x,point.y,2),plane,sword.SHIELD_RADII).is_empty(),"corrected shield blocks inside edge "+str(point))
		for point in [Vector2((sword.SHIELD_RADII.x+.0001),0),Vector2(0,(sword.SHIELD_RADII.y+.0001))]:
			check(Shield.intersect_bullet(plane*Vector3(point.x,point.y,-2),plane*Vector3(point.x,point.y,2),plane,sword.SHIELD_RADII).is_empty(),"corrected shield passes beyond edge "+str(point))
		check(Shield.intersect_bullet(plane*Vector3(0,0,2),plane*Vector3(0,0,-2),plane,sword.SHIELD_RADII).is_empty(),"shield remains front-only")
	check(sword.CONTACT_RADIUS==.026 and sword.MIN_SPEED==.20 and sword.FULL_SPEED==2.0 and sword.FULL_TRAVEL==.50,"true-SI sweep preserved;071 hand damage threshold explicitly2m/s")
	check(sword.WHOOSH_SPEED==1.4 and sword.WHOOSH_TRAVEL==.12,"authored swing-audio thresholds are not rescaled")
	check(sword.SUPPORT_POINT==Vector3(0,-.190,.025) and sword.SHIELD_CENTRE==Vector3(0,.34,-.08),"unmeasured support/shield centre true-SI placement preserved")
	var inventory=load("res://scripts/weapon_inventory.gd").new()
	check(inventory.AIM_REACH==2.0 and inventory.HOVER_HEIGHT==.75,"true-SI pickup reach and hover remain unchanged")
	inventory.free();sword.shutdown();sword.free();actor.free();await process_frame
	print("MEASURED_MELEE_062_GRIP_PROVENANCE ",JSON.stringify(records))
	print("MEASURED_MELEE_062 checks=",checks," failures=",failures," actual_geometry=true cpu_only=true headset_tested=false grip_datum_resolved=outer_pommel_end")
	quit(failures)

