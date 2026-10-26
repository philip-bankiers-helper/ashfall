extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	var game:Node3D=load("res://scripts/main.gd").new();root.add_child(game);game._start_from_title()
	for node in game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	game.set_process(false)
	check(game.weapon.weapons[15]._gold_trail097==null,"Excalibur has no yellow trail")
	var cyber:Node3D=game.weapon.weapons[16];var sweep:Node3D=cyber._gold_trail097
	check(sweep!=null,"Cyberblade owns sweep")
	for i in 20:sweep.sample_blade(Vector3(float(i)*.01,3,0),Vector3(float(i)*.02,4,0),.01,true)
	check(sweep.history.size()>=2 and sweep.history.size()<=15,"short bounded sweep history")
	check(sweep.mesh.get_surface_count()==1,"entire blade sweep has rendered surface")
	if sweep.mesh.get_surface_count():
		var bounds:AABB=sweep.mesh.get_aabb();check(bounds.size.y>.9,"sweep extends from blade base to tip")
	sweep.sample_blade(Vector3.ZERO,Vector3.ZERO,0,false);check(sweep.history.is_empty(),"stow clears sweep")
	var body:Node3D=game.body_visual
	check(body!=null,"real player body found")
	game.player.input_enabled=true;game.player.gliding=true;game.player.xr_enabled=false
	for i in 200:
		game.player.global_position=Vector3(float(i)*.04,6,0);body._process(.01)
	for trail in body._flight_trails097:
		check(absf(trail.distance-3.0)<.002,"actual flying elbow history spans three metres")
		check(trail.mesh.get_surface_count()==1,"both real elbow trails render")
	game.player.gliding=false;body._process(.01)
	for trail in body._flight_trails097:check(trail.history.is_empty(),"landing clears flight trail")
	var gun:Node3D=game.weapon.weapons[25]
	check(gun.get_meta("downloaded_model_077")=="s85","M1 remains S85 interaction identity")
	var shell:MeshInstance3D=gun.model.get_node("DownloadedBody077")
	check(shell.mesh.get_surface_count()>1,"M1 parts present in held model")
	check(gun.bolt.mesh!=null and gun.bolt.mesh.get_aabb().size.z>.04,"real M1 bolt and operating rod remain reload-owned")
	check(AshAudioBank.for_weapon(gun,"shot")!=AshAudioBank.for_weapon(game.weapon.weapons[13],"shot"),"dedicated S85 report replaces temporary SPR alias")
	check(AshAudioBank.for_weapon(gun,"bolt")!=AshAudioBank.for_weapon(game.weapon.weapons[13],"bolt"),"S85 uses its own bolt action")
	game.queue_free();await process_frame;await process_frame
	print("FEEDBACK_099 checks=",checks," failures=",failures," xr_runtime=off headset_tested=false");quit(failures)
