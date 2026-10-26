extends SceneTree
var checks:=0
var failures:=0
var game:Node3D
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",message)
func run()->void:
	game=load("res://scripts/main.gd").new();root.add_child(game)
	for node in game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	game.set_process(false)
	var actor:Node3D=game.player;var menu:Node3D=game.front_menu;var gallery:Node3D=menu.gallery
	menu.page="lobby";menu.set_active(true);menu._armed=true;menu._trigger=false
	menu._menu_edge097(true,4);check(menu.page=="lobby","press does not activate Map Select")
	menu._menu_edge097(false,4);check(menu.page=="maps","release activates captured Map Select")
	menu._menu_edge097(true,12);menu._menu_edge097(false,11);check(menu.page=="maps","drag to different button cancels")
	menu._menu_edge097(true,-1);menu._menu_edge097(false,12);check(menu.page=="maps","release over a button without press does nothing")
	menu._menu_edge097(true,12);menu._menu_edge097(false,-1);check(menu.page=="maps","release outside cancels")
	menu._menu_edge097(true,12);menu._menu_edge097(false,12);check(menu.page=="lobby" and menu.selected_map=="range","one release changes one page")
	menu._draw_beam097(Vector3(0,3,0),Vector3(0,3,-2))
	check(menu._beam097.visible and is_equal_approx(menu._beam097.global_basis.get_scale().y,2),"hand ray has full length")
	menu.set_active(false);check(not menu._beam097.visible,"menu exit hides ray")
	for i in [5,6]:
		check(menu.buttons[i].position.y>=670 and menu.buttons[i].size.x>=200 and menu.buttons[i].size.y>=100,"large lower gallery arrow "+str(i))
	var old_reserves:Dictionary=game.weapon.reserves.duplicate()
	actor.input_enabled=false
	for i in range(game.weapon.ACTIVE_WEAPON_INDICES.size()):
		var id:int=game.weapon.ACTIVE_WEAPON_INDICES[i]
		gallery.show_item(false,i);gallery._start_live097()
		check(gallery.live097!=null,"live gallery factory "+str(id))
		check(gallery.live097!=game.weapon.weapons[id] and not gallery.prop.visible,"inspection gun is independent "+str(id))
		check(gallery.live097._input_allowed() and not actor.input_enabled,"only preview has input "+str(id))
		if id not in [14,15,16,29]:
			gallery.live097._process(0)
			var saved:int=game.weapon.weapons[id].get_loaded_rounds()
			var before:int=gallery.live097.get_loaded_rounds();var events:int=gallery.preview_shots097
			gallery.live097.cooldown=0;gallery.live097._requires_trigger_release=false
			if id in [11,12]:
				for gun in gallery.live097.guns:gun.cooldown=0;gun._requires_trigger_release=false
			if id in [26,28]:gallery.live097.launch_payload(Vector3.FORWARD*7)
			else:gallery.live097.fire()
			if id in [11,12]:gallery.live097.guns[1].fire();gallery.live097._sync_pair()
			check(gallery.live097.get_loaded_rounds()==before-(2 if id in [11,12] else 1) and gallery.preview_shots097>events,"inspection gun fires "+str(id))
			check(game.weapon.weapons[id].get_loaded_rounds()==saved,"live carried ammunition preserved "+str(id))
		gallery.release();check(gallery.live097==null and gallery.prop.visible,"release safely docks "+str(id))
	check(game.weapon.reserves==old_reserves,"gallery never consumes live reserves")
	gallery.close()
	gallery.show_item(true,0)
	check(absf((gallery.dock.origin-actor.get_view_camera().global_position).y+.40)<.001,"character preview keeps its original lower anchor")
	gallery.close()
	for id in game.weapon.ACTIVE_WEAPON_INDICES:
		var prop:Node3D=game.weapon_inventory._create_prop(id)
		check(prop.find_children("AmmoReadoutPanel","",true,false).is_empty(),"ground copy has no ammo backing "+str(id));prop.queue_free()
	actor.input_enabled=true
	var pads:Node3D=game.revive_paddles;pads.equip();pads._add_charge(1)
	check(pads.ready_remaining097==5 and pads.charge_ready,"full charge starts five second window")
	pads.tick_ready_window097(4.9);check(pads.charge_ready and pads.ready_remaining097>.09,"ready through 4.9 seconds")
	pads._drain_charge(2);check(pads.charge_ready and pads.charge==1,"orientation changes cannot shorten ready window")
	pads._charged_arcs097._process(.1)
	check(pads._charged_arcs097.mesh.get_surface_count()==1 and pads._charged_arcs097.paddles==pads._paddles,"corona uses both actual paddle transforms")
	pads.tick_ready_window097(.11);check(not pads.charge_ready and pads.charge==0 and not pads._charged_arcs097.visible,"window expiration resets charge and lightning")
	pads.stow()
	var spr:Node3D=game.weapon.weapons[13];var optic:Node3D=spr.optic
	for roll in [-PI*.7,-.3,0,1.0,PI*.8]:
		spr.global_transform=Transform3D(Basis.from_euler(Vector3(.2,.4,roll)),Vector3(0,4,0))
		optic._commit_displayed_frame()
		var pose:Transform3D=optic._displayed_pose;var forward:Vector3=-pose.basis.z
		check((optic.reticle_world_center()-pose.origin).cross(forward).length()<.0001,"reticle lies on authoritative firing line at roll "+str(roll))
		check(absf((optic.reticle_world_center()-optic.lens.global_position).dot(forward)-1)<.001,"virtual reticle depth remains one metre")
		var eye:Vector3=actor.get_view_camera().global_position
		var virtual_ray:Vector3=optic.reticle_world_center()-eye
		var reticle_angle:=Vector2(virtual_ray.dot(pose.basis.x),virtual_ray.dot(pose.basis.y))/virtual_ray.dot(forward)
		for range_value in [5.0,30.0,150.0]:
			var target:Vector3=pose.origin+forward*range_value;var view:Camera3D=optic.scope_camera
			var extent:Vector2=optic._material.get_shader_parameter("tangent_left")
			var target_angle:Vector2=optic._target_uv(view,target,extent)*extent
			var sampled_angle:Vector2=(reticle_angle-reticle_angle)/2+target_angle
			var aimed:Vector3=eye+(forward+pose.basis.x*sampled_angle.x+pose.basis.y*sampled_angle.y)*((target-eye).dot(forward))
			check(aimed.distance_to(target)<.001,"per-eye magnification maps mark to actual bullet point at range "+str(range_value))
	check(optic._material.shader.code.contains("smoothstep(0.64,1.0"),"SPR aperture vignette present")
	var trail:=preload("res://scripts/motion_trail097.gd").new();game.add_child(trail);trail.setup(Color.YELLOW,.24,.035)
	for i in 12:trail.sample_point(Vector3(i*.02,4,-1),.01,true,.5)
	check(trail.history.size()>2 and trail.mesh.get_surface_count()==1,"moving blade produces bounded yellow trail")
	trail.sample_point(Vector3(30,4,-1),.01,true,.5);check(trail.history.is_empty(),"teleport cannot produce long trail")
	trail.sample_point(Vector3.ZERO,.01,false,.5);check(not trail.have_previous,"inactive clears trail history")
	check(game.weapon.weapons[15]._gold_trail097.ink==Color("ffdf38"),"Excalibur trail is yellow")
	var excalibur:Node3D=game.weapon.weapons[15]
	for i in 5:excalibur._gold_trail097.sample_point(Vector3(i*.05,4,-1),.01,true,.5)
	excalibur._suspend_gestures();check(excalibur._gold_trail097.history.is_empty(),"stowing Excalibur clears old trail")
	check(game.body_visual._flight_trails097.size()==2 and game.body_visual._flight_trails097[0].ink==Color.WHITE,"both elbow trails are white")
	game.queue_free();await process_frame;await process_frame
	print("PLAYTEST_097 checks=",checks," failures=",failures," xr_runtime=off headset_tested=false");quit(failures)
