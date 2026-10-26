extends SceneTree
const Harness=preload("res://tests/test_aim_reticle_red_carry_048.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var scene:=Node3D.new();root.add_child(scene)
	var actor:=Harness.Actor.new();scene.add_child(actor);actor.add_child(actor.camera);actor.add_child(actor.right_hand);actor.add_child(actor.left_hand)
	actor.collision_layer=2;actor.camera.position=Vector3(0,2,0)
	var rack:=Harness.Rack.new();scene.add_child(rack);var game:=Harness.Game.new();scene.add_child(game)
	var gun=load("res://scripts/revolver.gd").new();rack.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun.set_meta("reference_id","magnum")
	gun.position=Vector3(0,2,-.3);gun.model.transform=Transform3D.IDENTITY;rack.weapons=[gun]
	var reticle=load("res://scripts/aim_reticle.gd").new();scene.add_child(reticle);reticle.setup(actor,rack,game);reticle.set_process(false)
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/reference_magnum_fixture_060.json"))
	var squared:=0.0
	for sample in fixture.samples:
		gun.supported=sample.supported;gun._reference_shots.assign([0.0]);gun._reference_clock=maxf(0,float(sample.seconds))
		var predicted:float=(88.0 if gun.supported else 134.0)+gun.get_reference_bloom()
		squared+=pow(predicted-float(sample.width_px),2)
	var rms:float=sqrt(squared/fixture.samples.size())
	check(rms<8,"production Magnum width versus "+str(fixture.samples.size())+" film samples, RMSpx="+str(rms))
	gun._reference_shots.clear();gun.ammo=7;gun.reload_state="ready"
	for supported in [false,true]:
		gun.supported=supported;reticle.update_reticle();check(reticle.visible,"loaded chevrons visible, supported="+str(supported))
		var bounds:=AABB();var first:=true
		for i in range(4,8):
			var part:MeshInstance3D=reticle.get_child(i);var a:AABB=part.mesh.get_aabb();a.position+=part.position;bounds=a if first else bounds.merge(a);first=false
			if i==4:check(absf(a.size.x*.04*1147.17-18.0)<2,"single chevron coloured component matches recorded17-18px horizontal depth")
			var vertices:PackedVector3Array=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var outer:float=INF if i<6 else -INF;var inner:float=-INF if i<6 else INF
			for vertex in vertices:
				if i<6:outer=minf(outer,vertex.x);inner=maxf(inner,vertex.x)
				else:outer=maxf(outer,vertex.x);inner=minf(inner,vertex.x)
			var near_apex:=0.0;var near_end:=0.0;var apex_n:=0;var end_n:=0
			for vertex in vertices:
				if absf(vertex.x-outer)<absf(vertex.x-inner):near_apex+=absf(vertex.y);apex_n+=1
				else:near_end+=absf(vertex.y);end_n+=1
			check(near_apex/maxi(apex_n,1)<near_end/maxi(end_n,1),"outward chevron apex centered vertically, part"+str(i))
		check(absf(bounds.size.x*.04*1147.17-(88.0 if supported else 134.0))<2,"actual mesh agrees with recorded rest extent")
	gun.ammo=0;gun.reload_state="cylinder_open";reticle.update_reticle()
	check(reticle.visible and is_instance_valid(reticle._reload_symbol) and reticle._reload_symbol.visible,"empty Magnum retains chevrons and circular reload cue")
	check(reticle.white_parts[0].material_override.albedo_color.g>.8,"empty supported Magnum is yellow")
	gun.set_meta("reference_id","m60");reticle.update_reticle();check(reticle.visible and reticle._reload_symbol.visible,"recorded empty M60 retains yellow corners and circular reload cue")
	gun.set_meta("reference_id","magnum")
	gun.ammo=7;gun.reload_state="ready";reticle.update_reticle();check(not reticle._reload_symbol.visible,"ready hides reload glyph")
	gun.set_meta("reference_id","cx4");reticle.update_reticle();gun.remove_meta("reference_id");reticle.update_reticle();check(reticle.visible,"weapon profile switch safely restores original pool after reload glyph existed")
	gun.shutdown();scene.free();await create_timer(.2).timeout
	print("REFERENCE_MAGNUM_060 checks=",checks," failures=",failures," actual_production=true native_rendered=false headset_tested=false");quit(failures)
