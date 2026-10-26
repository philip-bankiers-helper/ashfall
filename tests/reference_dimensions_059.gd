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
		var pommel:MeshInstance3D=model.get_node("Pommel");var bottom:float=pommel.position.y-pommel.mesh.size.y*.5
		check(absf(built.tip.position.y-bottom-2.0)<.00001,"actual pommel-to-tip2m "+kind)
		check(model.get_node("GripCore").position==assets.GRIP and model.get_node("GripCore").mesh.size==Vector3(.032,.225,.037),"tracked hilt remains controller sized "+kind)
		var bounds:AABB=model.get_node("AuthoredBlade").mesh.get_aabb()
		check(absf(bounds.end.y-built.tip.position.y)<.00001 and built.base.position.y<bounds.end.y,"damage tip follows actual blade mesh "+kind);model.free()
	var sword=load("res://scripts/melee_sword.gd").new();root.add_child(sword);sword.setup(actor,false);sword.set_process(false);sword.set_physics_process(false)
	check(sword.shield_visual.mesh.size==Vector2(1.6,2.0),"Katana visible shield1.6x2m")
	var shield=load("res://scripts/directional_shield.gd");var plane:=Transform3D(Basis(Vector3.UP,.6),Vector3(3,2,-4))
	for p in [Vector2.ZERO,Vector2(.79,.99),Vector2(-.79,-.99)]:check(not shield.intersect_bullet(plane*Vector3(p.x,p.y,-2),plane*Vector3(p.x,p.y,2),plane,sword.SHIELD_RADII).is_empty(),"actual shield collision covers measured rectangle "+str(p))
	for p in [Vector2(.81,0),Vector2(0,1.01)]:check(shield.intersect_bullet(plane*Vector3(p.x,p.y,-2),plane*Vector3(p.x,p.y,2),plane,sword.SHIELD_RADII).is_empty(),"outside shield passes "+str(p))
	check(shield.intersect_bullet(plane*Vector3(0,0,2),plane*Vector3(0,0,-2),plane,sword.SHIELD_RADII).is_empty(),"shield still blocks front bullets only")
	var b=load("res://scripts/field_builder.gd").new();root.add_child(b);b.setup(actor,null,null)
	check(b.grid_spacing==4 and b.wall_height==4 and b._shape.size.x==4 and b._shape.size.y==4,"actual wall physics and grid4x4m")
	actor.desktop_camera.position.y=1.2;b.tick_input({"tracking":true,"eligible":false})
	check(b.grid_spacing==4 and b.wall_height==4,"crouch does not resize construction lattice")
	actor.desktop_camera.position.y=2.2;b.tick_input({"tracking":true,"eligible":false})
	check(b.grid_spacing==4 and b.wall_height==4,"taller headset does not resize construction lattice")
	b.free();sword.shutdown();sword.free();actor.free();await create_timer(.2).timeout
	print("REFERENCE_DIMENSIONS_059 checks=",checks," failures=",failures," actual_geometry=true native_rendered=false headset_tested=false");quit(failures)
