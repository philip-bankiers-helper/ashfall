extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var assets=load("res://scripts/blade_assets.gd")
	for kind in ["katana","excalibur","cyberblade"]:
		var model:=Node3D.new();root.add_child(model);var built:Dictionary=assets.build(model,kind)
		var pommel:MeshInstance3D=model.get_node("Pommel");var bottom:Vector3=pommel.position-Vector3.UP*pommel.mesh.size.y*.5
		# Actual straight pommel-to-tip span includes the authored blade curvature,
		# rather than treating its vertical projection as the full measured length.
		check(absf(built.tip.position.distance_to(bottom)-1.4101590361445784)<.00001,"actual pommel-to-tip1.4101590361445784m chord "+kind)
		var hilt:MeshInstance3D=model.get_node("GripCore");var hilt_bounds:=hilt.get_aabb()
		var hand_local:Vector3=assets.GRIP-hilt.position
		check(hilt.mesh.size==Vector3(.032,.285,.037) and hilt_bounds.has_point(hand_local-Vector3.UP*.05) and hilt_bounds.has_point(hand_local+Vector3.UP*.05) and hand_local.y>=.025,"extended hilt retains controller cross-section and seats primary fist toward guard "+kind)
		var bounds:AABB=model.get_node("AuthoredBlade").mesh.get_aabb()
		check(absf(bounds.end.y-built.tip.position.y)<.00001 and built.base.position.y<bounds.end.y,"damage tip follows actual blade mesh "+kind);model.free()
	var knife_art:=Node3D.new();root.add_child(knife_art);var knife_built:Dictionary=assets.build(knife_art,"knife")
	var knife_pommel:MeshInstance3D=knife_art.get_node("Pommel");var knife_bottom:Vector3=knife_pommel.position-Vector3.UP*knife_pommel.mesh.size.y*.5
	check(absf(knife_built.tip.position.distance_to(knife_bottom)-.38)<.00001,"knife29 original compact38cm art is distinct from measured1.4101590361445784m swords")
	check((knife_art.get_node("GripCore").mesh as BoxMesh).size==Vector3(.033,.130,.036),"knife29 keeps controller-sized130mm grip")
	knife_art.free()
	var sword=load("res://scripts/melee_sword.gd").new();root.add_child(sword);sword.setup(actor,false);sword.set_process(false);sword.set_physics_process(false)
	check(sword.shield_visual.mesh.size==Vector2(1.1281272289156627,1.4101590361445784),"Katana visible shield.97536x1.4101590361445784m")
	var shield=load("res://scripts/directional_shield.gd");var plane:=Transform3D(Basis(Vector3.UP,.6),Vector3(3,2,-4))
	for p in [Vector2.ZERO,Vector2(.47768,.5996),Vector2(-.47768,-.5996)]:check(not shield.intersect_bullet(plane*Vector3(p.x,p.y,-2),plane*Vector3(p.x,p.y,2),plane,sword.SHIELD_RADII).is_empty(),"actual shield collision covers measured rectangle "+str(p))
	for p in [Vector2((sword.SHIELD_RADII.x+.01),0),Vector2(0,(sword.SHIELD_RADII.y+.01))]:check(shield.intersect_bullet(plane*Vector3(p.x,p.y,-2),plane*Vector3(p.x,p.y,2),plane,sword.SHIELD_RADII).is_empty(),"outside shield passes "+str(p))
	check(shield.intersect_bullet(plane*Vector3(0,0,2),plane*Vector3(0,0,-2),plane,sword.SHIELD_RADII).is_empty(),"shield still blocks front bullets only")
	var b=load("res://scripts/field_builder.gd").new();root.add_child(b);b.setup(actor,null,null)
	check(is_equal_approx(b.grid_spacing,2.8203180722891568) and is_equal_approx(b.wall_height,2.8203180722891568) and is_equal_approx(b._shape.size.x,2.8203180722891568) and is_equal_approx(b._shape.size.y,2.8203180722891568),"actual wall physics and grid2.8203180722891568x2.8203180722891568m")
	actor.desktop_camera.position.y=1.2;b.tick_input({"tracking":true,"eligible":false})
	check(is_equal_approx(b.grid_spacing,2.8203180722891568) and is_equal_approx(b.wall_height,2.8203180722891568),"crouch does not resize construction lattice")
	actor.desktop_camera.position.y=2.2;b.tick_input({"tracking":true,"eligible":false})
	check(is_equal_approx(b.grid_spacing,2.8203180722891568) and is_equal_approx(b.wall_height,2.8203180722891568),"taller headset does not resize construction lattice")
	b.free();sword.shutdown();sword.free();actor.free();await create_timer(.2).timeout
	print("REFERENCE_DIMENSIONS_062_CARRY checks=",checks," failures=",failures," actual_geometry=true native_rendered=false headset_tested=false");quit(failures)
