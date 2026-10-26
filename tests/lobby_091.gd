extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	var game:=preload("res://scripts/main.gd").new();root.add_child(game);await process_frame
	game.set_process(false)
	var menu:Node3D=game.front_menu;menu.set_process(false)
	check(menu.lobby.pedestals.size()==3 and menu.lobby.avatars.size()==3,"separate lobby has three player-model pedestals")
	check(game.player.global_position.distance_to(game.world.player_spawn)>500 and not game.player.input_enabled,"lobby level spatially isolated and gameplay gated")
	check(menu.buttons[0].text=="READY" and menu.buttons[3].text=="LOADOUT" and menu.buttons[4].text=="MAP SELECT","reference core menu buttons")
	var ammo:Array=[]
	for gun in game.weapon.weapons:ammo.append(gun.get_loaded_rounds());gun.set_process(false);gun.set_physics_process(false)
	menu.buttons[3].pressed.emit();check(menu.page=="loadout" and menu.gallery.active and is_instance_valid(menu.gallery.prop),"loadout opens actual 3D weapon")
	for step in 5:
		menu.buttons[6].pressed.emit();check(menu.gallery.prop.find_children("*","MeshInstance3D",true,false).size()>0,"weapon selection constructs 3D meshes")
	menu.buttons[8].pressed.emit();check(menu.gallery.characters and menu.buttons[9].visible,"character inspection and use option")
	menu.buttons[6].pressed.emit();menu.buttons[9].pressed.emit();check(menu.gallery.style==1,"character selection applies outfit")
	var actor:Node3D=game.player;actor.set_process(false);actor.set_physics_process(false);actor.xr_enabled=true;actor.tracking_available=true
	var hand:XRController3D=actor.get_weapon_hand();var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="lobby091_test";XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
	tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0)
	await process_frame;actor.update_hand_input_rearm(.2)
	var center:Vector3=menu.gallery.prop.global_position
	hand.global_transform=Transform3D(Basis(Vector3.RIGHT,PI*.5),center+Vector3.BACK*.2)
	menu.gallery._process(.01);tracker.set_input("grip",1.0);menu.gallery._process(.01)
	check(menu.gallery.holder==hand,"actual grip input picks up character inspection model")
	hand.global_position+=Vector3.RIGHT*.2;menu.gallery._process(.01);check(menu.gallery.prop.global_position.distance_to(hand.global_position)<.001,"grabbed model follows current tracked hand")
	tracker.set_input("grip",0.0);menu.gallery._process(.01);check(menu.gallery.holder==null,"release returns inspection model to display")
	XRServer.remove_tracker(tracker);actor.xr_enabled=false
	for i in ammo.size():check(game.weapon.weapons[i].get_loaded_rounds()==ammo[i],"loadout copies never alter live weapon ammunition")
	menu.buttons[10].pressed.emit();menu.buttons[4].pressed.emit();check(menu.page=="maps" and menu.buttons[11].visible and menu.buttons[12].visible,"map selector offers two implemented maps")
	menu.buttons[12].pressed.emit();check(menu.selected_map=="range" and menu.page=="lobby","map selection returns to Ready")
	menu.buttons[0].pressed.emit();check(not game.front_end_active and game.player.input_enabled and not menu.lobby.visible,"Ready exits lobby and restores gameplay")
	check(game.has_node("StandaloneSandboxRange091") and not game.world.visible and game.player.global_position.z>600,"Ready loads selected separate sandbox range")
	check(game._checkpoint_position().is_equal_approx(game.player.global_position) and game.enemies.is_empty(),"sandbox checkpoint / reset stays in selected map without campaign enemies")
	game.queue_free();await process_frame;await process_frame
	print("LOBBY_091 checks=",checks," failures=",failures," actual_3d_grab=true xr_runtime=off");quit(failures)
