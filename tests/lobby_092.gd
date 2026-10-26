extends SceneTree
var checks:=0
var failures:=0
var game:Node3D
var menu:Node3D
var actor:Node3D
var tracker:XRControllerTracker
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func press(index:int)->void:
	var center:Vector2=menu.buttons[index].get_global_rect().get_center()
	var target:Vector3=menu.board.to_global(Vector3((center.x/1280-.5)*1.6,(.5-center.y/800),0))
	var hand:XRController3D=actor.get_weapon_hand()
	hand.global_transform=Transform3D(Basis.looking_at(target-hand.global_position,Vector3.UP)*Basis(Vector3.RIGHT,PI*.5),hand.global_position)
	tracker.set_input("trigger",0.0);menu._process(.011);menu._process(.011)
	tracker.set_input("trigger",1.0);menu._process(.011)
func run()->void:
	game=load("res://scripts/main.gd").new();root.add_child(game);await process_frame
	game.set_process(false);actor=game.player;actor.set_process(false);actor.set_physics_process(false);menu=game.front_menu;menu.set_process(false)
	actor.xr_enabled=true;actor.tracking_available=false;actor.xr_camera.position=Vector3.ZERO
	menu.set_active(true)
	var old_board:Vector3=menu.board.global_position
	actor.xr_camera.position=Vector3(.2,1.65,.1);actor.xr_camera.rotation=Vector3(-.3,.45,.2)
	actor.tracking_available=true;menu._process(.011)
	check(menu.board.global_position.y>old_board.y+1.4,"late headset height moves menu above the deck")
	var camera:Camera3D=actor.get_view_camera()
	check(absf(menu.board.global_position.y-(camera.global_position.y-.2))<.001,"menu anchors at current eye height")
	check(menu.board.global_basis.y.dot(Vector3.UP)>.999,"menu remains upright when headset is pitched or rolled")
	for index in [0,3,4]:
		check(menu.buttons[index].visible,"core button visible "+str(index))
		var center:Vector2=menu.buttons[index].get_global_rect().get_center()
		var target:Vector3=menu.board.to_global(Vector3((center.x/1280-.5)*1.6,(.5-center.y/800),0))
		var local:Vector3=camera.to_local(target)
		check(local.z<0 and absf(local.x/-local.z)<.7 and absf(local.y/-local.z)<.7,"core button in front of tracked view "+str(index))
	check(menu.buttons[0].text=="READY","reference action is READY")
	var anchor:Transform3D=menu.board.global_transform
	actor.xr_camera.position.x+=.15;actor.xr_camera.rotation.y+=.2;menu._process(.011)
	check(menu.board.global_transform.is_equal_approx(anchor),"panel stays still while looking and pointing")
	actor.tracking_available=false;menu._process(.011);actor.xr_camera.position.y=1.4;actor.tracking_available=true;menu._process(.011)
	check(absf(menu.board.global_position.y-(camera.global_position.y-.2))<.001,"tracking resume reanchors menu")
	var hand:XRController3D=actor.get_weapon_hand();tracker=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="lobby092";XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
	tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("trigger",0.0);tracker.set_input("grip",0.0)
	await process_frame;actor.update_hand_input_rearm(.2);hand.global_position=camera.global_position+Vector3(.2,-.3,-.2)
	press(4);check(menu.page=="maps","tracked trigger opens Map Select")
	menu._process(.011);check(menu.page=="maps","held trigger cannot select a newly shown overlapping map button")
	press(12);check(menu.page=="lobby" and menu.selected_map=="range","tracked trigger selects Sandbox Range")
	press(3);check(menu.page=="loadout" and menu.gallery.active,"tracked trigger opens Loadout")
	press(10);check(menu.page=="lobby","tracked trigger returns from Loadout")
	await physics_frame
	var fields:Array=get_nodes_in_group("lobby_force_field")
	check(fields.size()==4,"four invisible force fields enclose lobby")
	for field in fields:
		check(field.find_children("*","MeshInstance3D",true,false).is_empty(),"force field has no visible geometry")
		check(field.collision_layer==1,"force field blocks player movement")
	var space:PhysicsDirectSpaceState3D=actor.get_world_3d().direct_space_state
	for y in [.2,1.6,3.0]:
		for target in [Vector3(-12,y,-2),Vector3(12,y,-2),Vector3(0,y,-12),Vector3(0,y,8),Vector3(12,y,8),Vector3(-12,y,-12)]:
			var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(menu.lobby.global_position+Vector3(0,y,-2),menu.lobby.global_position+target,1))
			check(not hit.is_empty() and hit.collider.is_in_group("lobby_force_field"),"edge and corner path blocked at height "+str(y)+" target "+str(target))
	for motion in [Vector3(2,0,0),Vector3(-2,0,0),Vector3(0,0,2),Vector3(0,0,-2)]:
		var start:Vector3=Vector3(10 if motion.x>0 else (-10 if motion.x<0 else 0),0,6 if motion.z>0 else (-10 if motion.z<0 else -2))
		check(actor.test_move(Transform3D(Basis.IDENTITY,menu.lobby.global_position+start),motion),"actual player body cannot cross lobby edge "+str(motion))
	press(0);check(not game.front_end_active and actor.input_enabled,"tracked READY enters game")
	check(game.has_node("StandaloneSandboxRange091"),"READY loads selected map")
	XRServer.remove_tracker(tracker);actor.xr_enabled=false;game.queue_free();await process_frame;await process_frame
	print("LOBBY_092 checks=",checks," failures=",failures," late_head_pose=true tracked_buttons=true invisible_boundaries=true xr_runtime=off");quit(failures)
