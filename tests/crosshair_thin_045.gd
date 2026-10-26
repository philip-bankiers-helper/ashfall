extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
	var reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(reticle)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	reticle.setup(actor,Node3D.new(),Node.new());reticle.set_process(false)
	check(reticle.get_child_count()==8,"four arms per outline/red layer retained")
	check(reticle.SIZE_MULTIPLIER==4.0,"overall fourfold size retained")
	for i in range(8):
		var arm:MeshInstance3D=reticle.get_child(i)
		var size:Vector2=arm.mesh.size
		var thin:=minf(size.x,size.y)
		check(is_equal_approx(thin,.10 if i<4 else .035),"arm%d thinner stroke without scaling overall cross"%i)
		var half:=size*.5
		check(absf(arm.position.x)>half.x or absf(arm.position.y)>half.y,"arm%d preserves open center"%i)
		if i>=4:
			var color:Color=arm.material_override.albedo_color
			check(color.r>.99 and color.g<.05 and color.b<.05,"red arm%d color retained"%i)
	var outer:MeshInstance3D=reticle.get_child(0)
	check(is_equal_approx(outer.position.x+outer.mesh.size.x*.5,.5),"outer extent unchanged")
	reticle.rack.free();reticle.game.free();reticle.free();actor.free();await process_frame
	print("CROSSHAIR_THIN_045 checks=",checks," failures=",failures," rendering_tested=false");quit(failures)
