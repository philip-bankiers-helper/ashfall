extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame
	game.set_process(false);game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	var actor=game.player;actor.set_process(false);actor.set_physics_process(false);actor.xr_enabled=true;actor.tracking_available=true;actor.input_enabled=true
	var rack=game.weapon;rack.set_process(false);var builder=game.field_builder;var input=game.building_input;input.set_physics_process(false)
	var roof:=StaticBody3D.new();roof.position=Vector3(1000,7.5,1000);var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(4,1,6);collision.shape=shape;roof.add_child(collision);root.add_child(roof)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="build053_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	for dominance in ["right","left"]:
		actor.dominant_hand=dominance;rack._refresh_hands();actor.position=Vector3(1001.7,8,1000);actor.xr_camera.position=Vector3(0,1.65,0);rack.set_holstered(true);builder.reset_builds();builder.piece_index=0;builder._set_piece();builder.charges=12
		var hand:XRController3D=actor.get_weapon_hand();var primary=trackers[hand]
		input._desktop_cancel=false
		for h in [actor.left_hand,actor.right_hand]:actor._hand_input_ready[h]=true
		input._physics_process(.011)
		for i in 2:
			primary.set_input("by_button",true);rack._switch_previous=false;rack._process(.011);input._physics_process(.011)
			primary.set_input("by_button",false);rack._process(.011);input._physics_process(.011)
		check(rack.is_holstered and builder.piece_index==2,dominance+" idle B/Y cycles to horizontal without drawing a gun or placing a wall")
		var expected_level:=8.0;var first_level:=0.0
		for segment in 3:
			var side:float=builder.grid_spacing
			var target:=Vector3((floorf((actor.position.x+side*.65)/side)+.5)*side,expected_level,1000)
			var origin:Vector3=actor.global_position+Vector3(0,1.25,0)
			var pointer:=Transform3D(Basis.looking_at((target-origin).normalized(),Vector3.UP),origin)
			hand.global_transform=pointer*Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3.ZERO)
			primary.set_input("trigger",0.0);input._physics_process(.011);primary.set_input("trigger",1.0);input._physics_process(.011);primary.set_input("trigger",0.0);input._physics_process(.011)
			print("PLACEMENT_DEBUG ",dominance," ",segment," eligible=",input.eligible()," reason=",builder.invalid_reason," origin=",input.sample().origin," target=",target," at=",builder._placement.origin," anchor=",builder._level_y)
			var floors:Array=builder.pieces.filter(func(p):return is_instance_valid(p) and p.get_meta("construction_kind","")=="floor")
			check(floors.size()==segment+1,dominance+" actual input places horizontal extension "+str(segment))
			if floors.size()!=segment+1:continue
			var piece:Node3D=floors[-1];var top:float=piece.position.y+.08
			if segment==0:first_level=top
			check(absf(top-expected_level)<.015,dominance+" non-grid8m roof remains at same floor level")
			await physics_frame;await physics_frame
			var supported:=true
			for frame in 70:
				if actor.position.x>=piece.position.x:break
				actor.apply_locomotion_motion(Vector3.RIGHT,Vector3.FORWARD,false,false,1.0/90.0);await physics_frame
				if not actor.is_supported() or absf(actor.position.y-expected_level)>.04:supported=false
			check(supported and actor.position.x>=piece.position.x-.08,dominance+" actual player walks onto newly input-placed floor "+str(segment))
		builder.reset_builds();await physics_frame
		builder._active=true;actor.climbing=true;actor.climbing_left=dominance=="right";actor.climbing_right=dominance=="left";rack.set_holstered(true)
		primary.set_input("by_button",true);rack._switch_previous=false;rack._process(.011)
		check(not rack.is_holstered and actor.climbing,dominance+" ineligible construction lets B/Y draw/switch while offhand stays anchored")
		primary.set_input("by_button",false);actor.climbing=false;actor.climbing_left=false;actor.climbing_right=false
	for t in trackers.values():XRServer.remove_tracker(t)
	game._quitting=true;game.weapon.shutdown();game._stop_audio_tree(game);roof.free();game.queue_free();await create_timer(.2).timeout
	print("BUILDING_FLOW_053 checks=",checks," failures=",failures," actual_input_and_physics=true headset_tested=false")
	quit(failures)


