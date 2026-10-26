extends SceneTree
class MP9 extends "res://scripts/catalog_firearm.gd":
	func _vr_active()->bool:return true
var checks:=0
var failures:=0
var game:Node3D
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	game=load("res://scripts/main.gd").new();root.add_child(game);game._start_from_title()
	for node in game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	game.set_process(false)
	var actor:Node3D=game.player;var rack:Node3D=game.weapon
	var hud:Node3D=game.combat_hud.get_node_or_null("ReferenceHUD090")
	if hud==null:
		for node in game.combat_hud.get_children():
			if node.get_script()==preload("res://scripts/reference_hud_090.gd"):hud=node
	check(hud!=null,"real reference HUD found")
	if hud!=null:
		game.health=100;game.shield=73;hud.refresh()
		for pair in [[hud.health_text,hud.health],[hud.shield_text,hud.shield]]:
			check(pair[0].horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT,"meter numbers left aligned")
			check(pair[0].vertical_alignment==VERTICAL_ALIGNMENT_CENTER and is_equal_approx(pair[0].position.y,pair[1].position.y),"meter numbers centered vertically")
			check(is_equal_approx(pair[0].position.x,-.159),"meter numbers inset from left bar edge")
		var back:MeshInstance3D
		for child in hud.get_children():
			if child is MeshInstance3D and child.mesh is QuadMesh and is_equal_approx(child.mesh.size.x,.039):back=child
		check(back!=null and is_equal_approx(back.position.y+back.mesh.size.y*.5,-.433+.019*.5),"build backing top aligns with shield top")
	var fit=preload("res://scripts/playtest_fit_088.gd")
	check(is_equal_approx(fit.hand_offset(rack.weapons[9]).y*rack.weapons[9].visual_model_scale(),.0381),"M1014 hand up another half physical inch")
	check(is_equal_approx(fit.hand_offset(rack.weapons[27]).z*rack.weapons[27].visual_model_scale(),.0508),"rocket rendered hand back another physical inch")
	var ring:Node3D=rack.weapons[25].get_meta("ring_sight")
	check(is_equal_approx(ring.position.y*rack.weapons[25].model.global_basis.get_scale().y,-.0381),"S85 entire ring assembly down1.5physical inches")
	for i in rack.ACTIVE_WEAPON_INDICES:
		var gun:Node3D=rack.weapons[i]
		if i in [11,12]:continue # Parent pair readout is deliberately hidden; inspect both actual guns below.
		if gun.ammo_panel==null:continue
		gun.update_ammo_display()
		check(gun.ammo_label.text.split("\n").size()==2 and not gun.ammo_label.text.contains("/"),"stacked ammo readout "+str(i))
		check(gun.ammo_panel.dimensions.y>=.035,"both readout rows fit "+str(i))
	for i in [11,12]:
		for gun in rack.weapons[i].guns:
			gun.update_ammo_display();check(gun.ammo_label.text.split("\n").size()==2,"paired weapon stacked ammo")
	for i in [14,15,16]:
		var sword:Node3D=rack.weapons[i];sword.visible=true;sword.model.visible=true;sword._update_guard()
		check(sword.shield_hint.text.is_empty() and not sword.shield_hint.visible,"sword has no instructional text "+str(i))
		if i!=14:check(not sword.grip_cue.visible,"nonkatana sword has no blue support ring")
	var trackers:Dictionary={}
	actor.xr_enabled=true;actor.tracking_available=true;actor.xr_camera.position.y=actor.DEFAULT_EYE_HEIGHT_M
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="feedback093_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("trigger",0.0);tracker.set_input("grip",0.0);tracker.set_input("primary",Vector2.ZERO);tracker.set_input("primary_click",false);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2);actor.objective_grip_provider=Callable();actor._objective_grip_arbiter.reset()
	var magnum:Node3D=rack.weapons[7];var old_binding:String=actor.sprint_binding;actor.sprint_binding="disabled"
	for dominant in ["right","left"]:
		actor.dominant_hand=dominant;rack._refresh_hands()
		magnum.reset_weapon();magnum.chambers[0]="empty";magnum.chambers[1]="empty";magnum._sync()
		var before:int=magnum.get_loaded_rounds();trackers[magnum.right_hand].set_input("primary_click",false);magnum._poll_vr()
		trackers[magnum.right_hand].set_input("primary_click",true);magnum._poll_vr()
		check(magnum.reload_state=="cylinder_open" and before==5 and magnum.get_loaded_rounds()==5,"thumb press opens partly loaded Magnum "+dominant)
		magnum._poll_vr();check(magnum.get_loaded_rounds()==5,"held thumb cannot discard live rounds "+dominant)
		trackers[magnum.right_hand].set_input("primary_click",false)
	actor.sprint_binding=old_binding;actor.dominant_hand="right";rack._refresh_hands()
	var mp9:=MP9.new();mp9.profile_id="mp9";game.add_child(mp9);mp9.setup(actor,false);mp9.set_process(false);mp9.set_physics_process(false)
	mp9.set_weapon_settings({"motion_damping":2.0})
	check(mp9.motion_damping==0.0 and rack.weapons[0].motion_damping==1.0,"MP9 alone opts out of motion damping")
	var laser:Node3D
	for child in mp9.get_children():
		if child.get_script()==preload("res://scripts/mp9_laser_091.gd"):laser=child
	for step in 16:
		mp9.global_transform=Transform3D(Basis.from_euler(Vector3(.06*sin(step),.1*step,.04*step)),Vector3(step*.02,4,0))
		mp9._apply_aim_filter(1.0/90)
		check(mp9._filtered_aim.is_equal_approx(mp9.global_basis),"MP9 aim has no delayed basis "+str(step))
		laser._process(0);var vertices:PackedVector3Array=laser.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(((vertices[0]+vertices[1])*.5).distance_to(mp9.get_shot_transform().origin)<.00001,"MP9 laser starts at current muzzle "+str(step))
	mp9.queue_free()
	var p90:Node3D=rack.weapons[10]
	for stage in ["needs_mag","held_mag","needs_rack"]:
		p90.reload_state=stage;p90._process(0)
		var arrow:Node3D=p90.charging_arrow if stage=="needs_rack" else p90.insertion_arrow
		check(arrow.visible and arrow.find_children("*","MeshInstance3D",true,false).size()>=3,"P90 reload arrow has actual visible geometry "+stage)
		check(arrow.global_position.y>p90.model.to_global(p90.get_charge_point() if stage=="needs_rack" else (p90.get_top_offer() if stage=="needs_mag" else p90.get_top_seat())).y,"P90 cue is above target "+stage)
		var direction:Vector3=arrow.basis.z if stage=="needs_rack" else arrow.basis.y
		check(direction.normalized().dot(Vector3.BACK if stage=="needs_rack" else Vector3.FORWARD)>.999,"P90 cue direction "+stage)
	var spr:Node3D=rack.weapons[13];spr.optic._commit_displayed_frame()
	check(is_equal_approx(spr.optic.reticle_world_center().distance_to(spr.optic.lens.global_position),1.0),"SPR reticle fixed virtual depth1metre")
	check(spr.optic._material.shader.code.contains("virtual_hit") and not spr.optic._material.shader.code.contains("vec2 aim=(UV"),"SPR per-eye virtual plane replaces near-glass marking")
	var awp:Node3D=rack.weapons[5];check(awp.shot_sound_kind_089()=="shot_awp","AWP routes to new distinct sound family")
	for i in 3:
		var sound:AudioStreamWAV=AshAudioBank.sample("shot_awp",i);check(sound.mix_rate==48000 and sound.format==AudioStreamWAV.FORMAT_16_BITS and sound.get_length()>1.8,"AWP lossless long report "+str(i))
		awp._play_shot();var voice:AudioStreamPlayer3D=awp._shot_voices[posmod(awp._shot_voice_cursor-1,awp._shot_voices.size())]
		check(voice.stream==sound and voice.volume_db==-1,"actual AWP voice uses new variant and stronger level "+str(i))
	var pads:Node3D=game.revive_paddles;rack.is_selecting=false;actor.inventory_open=false;actor.input_enabled=true;pads.equip();pads.set_process(false)
	for speed in [0.0,.5]:
		pads._clear_charge();var elapsed:=0.0
		while not pads.charge_ready and elapsed<11:
			var displacement:Vector3=Vector3.UP*float(speed)*elapsed
			pads.step_contacts(.01,Vector3(-.2,3,0)+displacement,Vector3(.2,3,0)+displacement,true,Vector3.RIGHT,Vector3.LEFT)
			elapsed+=.01
		check(absf(elapsed-(10.0 if speed==0 else 5.5))<.03,"existing 5.5–10second charge rate retained "+str(speed))
	pads._clear_charge()
	pads._paddles[0].global_position=Vector3(-.2,3,0);pads._paddles[1].global_position=Vector3(.2,3,0)
	var completions:int=pads.completion_events;pads._add_charge(1.0)
	check(pads.charge_ready and pads.completion_events==completions+1,"full charge automatically triggers completion")
	check(pads._audio.stream==AshAudioBank.sample("revive_discharge"),"automatic completion plays discharge sound")
	var effects:Array=game.get_children().filter(func(n:Node):return n.get_script()==preload("res://scripts/revive_discharge_fx_091.gd"))
	check(not effects.is_empty() and effects.back().mesh.get_surface_count()==1,"automatic completion has animated lightning geometry")
	pads._add_charge(.1);check(pads.completion_events==completions+1,"full charge does not continuously repeat effects")
	pads.step_contacts(.1,Vector3(-2,3,0),Vector3(5,7,4),true,Vector3.RIGHT,Vector3.RIGHT)
	check(is_equal_approx(pads.charge,.96) and not pads.charge_ready,"turning electrodes apart drains ready charge")
	pads.charge=.5;pads._have_sample=false;pads.step_contacts(.01,Vector3(-5,8,0),Vector3(10,0,5),true,Vector3.RIGHT,Vector3.LEFT)
	check(is_equal_approx(pads.charge,.5),"moving paddles far apart without changing facing does not drain")
	pads._drain_charge(10);check(pads.charge==0,"charge drain clamps at zero")
	pads.charge=1;pads.charge_ready=true;actor.xr_enabled=false;pads._process(0);check(pads._label.text=="READY","ready HUD has no touch text or dash")
	pads.stow()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	game.front_menu.selected_map="range";var range_map:=preload("res://scripts/sandbox_map_091.gd").new();game.add_child(range_map);range_map.enter(game)
	check(game.rescue_dummy.revive_contacts()[0].y>1.2 and game.rescue_dummy.revive_contacts()[0].y<1.4,"practice rescue contacts raised to standing chest height")
	check(game.rescue_dummy.global_position.y>0,"practice rescue torso no longer buried")
	game.queue_free();await process_frame;await process_frame
	print("FEEDBACK_093 checks=",checks," failures=",failures," xr_runtime=off headset_tested=false");quit(failures)
