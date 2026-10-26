extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false);rack.set_physics_process(false)
	var util=load("res://scripts/reference_response.gd");var geometry=load("res://scripts/reticle_geometry.gd")
	var node:=Node3D.new();root.add_child(node)
	for i in 8:
		var part:=MeshInstance3D.new();part.material_override=StandardMaterial3D.new();node.add_child(part)
	for id in ["cx4","dt11","m60","magnum"]:
		var p:Dictionary=util.manifest().reticles[id];geometry.rebuild(node,p);geometry.layout(node,p,p.rest_px,Color.RED)
		var bounds:=AABB();var first:=true
		for i in range(4,8):
			var part:MeshInstance3D=node.get_child(i);var a: AABB=part.mesh.get_aabb();a.position+=part.position
			bounds=a if first else bounds.merge(a);first=false
			check(not a.has_point(Vector3.ZERO),id+" leaves exact ballistic center empty, part"+str(i))
		check(absf(bounds.size.x*.04*1147.17-float(p.rest_px))<4.0,id+" actual colored mesh projects to reference pixel extent")
	check(is_equal_approx(actor.get_effective_glide_speed(),8.460954216867469) and is_equal_approx(actor.sprint_slow_gain*actor.WALK_SPEED,5.288096385542169) and is_equal_approx(actor.sprint_fast_gain*actor.WALK_SPEED,6.6982554216867465),"fresh measured movement targets4.58301686746988/5.288096385542169/6.6982554216867465/8.460954216867469")
	var m60=rack.weapons[8];check(is_equal_approx(m60.maximum_rps,7.2),"production M60 receives counter-derived7.2rps")
	var shots:Array=[0.0,.26387,.49996,.76383,.95826,1.16657,1.33323,1.49988,1.66654,1.83319]
	var next:=0;var file:=FileAccess.open("user://m60-response.csv",FileAccess.WRITE);file.store_line("seconds,pitch_degrees,bloom_pixels")
	m60.reset_weapon();m60.set_process(false);var now:=0.0;var measured:Array[float]=[]
	for i in 2401:
		while next<shots.size() and float(shots[next])<=now+.000001:m60._kick_recoil(.052,deg_to_rad(5.5));next+=1
		measured.append(rad_to_deg(m60.recoil_pitch))
		if i%5==0:file.store_line("%.4f,%.6f,%.6f"%[now,rad_to_deg(m60.recoil_pitch),m60.get_reference_bloom()])
		m60._reference_clock+=.001;m60._recover_recoil(.001);now+=.001
	file.close();print("MEASURED_RESPONSE_CSV=",ProjectSettings.globalize_path("user://m60-response.csv"))
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/reference_m60_fixture_059.json"))
	var squared_error:=0.0
	for sample in fixture.samples:
		var index:=clampi(roundi(float(sample.seconds)*1000),0,measured.size()-1)
		squared_error+=pow(measured[index]-float(sample.pitch_degrees),2)
	var rms:float=sqrt(squared_error/fixture.samples.size())
	# The initial-only 059 fit is preserved as a diagnostic, not the 061 model.
	# New camera-compensated full trajectories are tested in sustained_recoil_061.
	print("LEGACY_INITIAL_ONLY_FIT_RMS_DEG=",rms," superseded_by_full_observed_061=true")
	check(next==10 and m60.recoil_pitch>0 and is_finite(m60.recoil_yaw),"M60 starts upward with finite observed horizontal motion")
	m60._recover_recoil(1.0);check(m60.recoil_pitch==0 and m60.recoil_pattern_index==0,"release settles and resets measured sequence")
	var p90=rack.weapons[10];p90._kick_recoil(.05,.1);p90._reference_clock+=.06;check(p90.get_reference_bloom()>0 and p90.get_meta("reference_id")=="p90","P90 override still publishes per-shot bloom")
	var grenade=rack.weapons[26]
	var ballistics=load("res://scripts/grenade_ballistics.gd")
	for kind in ["frag","zone"]:
		grenade.profile_id=kind
		for height in [1.2,2.0]:
			# 061 supersedes the old tracked-velocity/fuse-capped range premise:
			# level held aim +45 degrees, fixed strength, 33.843816867469876 m ground contact.
			grenade.model.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,height-.045,0))
			var aimed:Vector3=grenade.prepared_velocity(Vector3.ZERO)
			for v in [Vector3(0,4,-12),Vector3(0,10,-10),Vector3(0,0,-14)]:
				var output:Vector3=grenade.prepared_velocity(v);var h:float=maxf(0,grenade.get_shot_transform().origin.y-actor.global_position.y-ballistics.COLLISION_RADIUS)
				var flight:float=(output.y+sqrt(output.y*output.y+2*9.8*h))/9.8
				var actual_range:float=Vector2(output.x,output.z).length()*flight
				check(absf(actual_range-33.843816867469876)<.02 and output.distance_to(aimed)<.0001 and absf(rad_to_deg(Vector3.FORWARD.angle_to(output))-45.0)<.001,kind+" aimed press throw: +45degrees and33.843816867469876mground contact independent of wrist speed, height"+str(height))
				if kind=="frag":check(flight<float(load("res://scripts/arsenal_data.gd").tuning().frag_fuse_seconds),"frag33.843816867469876mground contact precedes configured original3.5sfuse")
	for gun in rack.weapons:gun.set_process(false)
	node.free();rack.shutdown();rack.free();actor.free();await create_timer(.2).timeout
	print("REFERENCE_RESPONSE_062 checks=",checks," failures=",failures," actual_production_response=true video_comparison_separate=true headset_tested=false");quit(failures)

