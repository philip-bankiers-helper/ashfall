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
	var rack=game.weapon;rack.set_process(false);var b=game.field_builder;var adapter=game.building_input;adapter.set_physics_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="construction061_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	var roof_center:=Vector3(1000.37,8.37,1000.19)
	var roof:=StaticBody3D.new();roof.position=roof_center-Vector3.UP*.5;var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(4,1,4);collision.shape=shape;roof.add_child(collision);root.add_child(roof)
	for dominance in ["right","left"]:
		actor.dominant_hand=dominance;rack._refresh_hands()
		for travel in [Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT,Vector3.BACK]:
			actor.position=roof_center+travel*1.7;actor.xr_camera.position=Vector3(0,1.65,0);rack.set_holstered(true);b.reset_builds();b.piece_index=0;b._set_piece()
			await physics_frame;await physics_frame
			var hand:XRController3D=actor.get_weapon_hand();var primary=trackers[hand];primary.set_input("trigger",0.0);primary.set_input("by_button",false);primary.set_input("ax_button",false)
			for h in [actor.left_hand,actor.right_hand]:actor._hand_input_ready[h]=true
			adapter._desktop_cancel=false;adapter._physics_process(.011)
			for i in 2:
				primary.set_input("by_button",true);rack._switch_previous=false;rack._process(.011);adapter._physics_process(.011)
				primary.set_input("by_button",false);rack._process(.011);adapter._physics_process(.011)
			var label:String=dominance+" "+str(travel)
			check(rack.is_holstered and b.piece_index==2 and b.pieces.is_empty(),label+" actual B/Y selects horizontal and preserves holster")
			for segment in 3:
				var target:Vector3=roof_center+travel*4.0*float(segment+1)
				var origin:Vector3=actor.global_position+Vector3.UP*1.25+travel.cross(Vector3.UP)*.15
				var pointer:=Transform3D(Basis.looking_at((target-origin).normalized(),Vector3.UP),origin)
				hand.global_transform=pointer*Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3.ZERO)
				primary.set_input("trigger",0.0);adapter._physics_process(.011);primary.set_input("trigger",1.0);adapter._physics_process(.011);primary.set_input("trigger",0.0);adapter._physics_process(.011)
				check(b.pieces.size()==segment+1 and b.pieces.all(func(p):return p.get_meta("construction_kind")=="floor"),label+" actual trigger places supported horizontal tile "+str(segment))
				if b.pieces.size()!=segment+1:
					print("PLACEMENT_FAILURE reason=",b.invalid_reason," intended=",target," selected=",b._placement.origin," phase=",b._floor_grid_origin);continue
				var piece:Node3D=b.pieces[-1]
				check(piece.global_position.distance_to(target-Vector3.UP*.08)<.015,label+" four-metre floor aligns flush to non-grid roof and previous tile "+str(segment))
				await physics_frame;await physics_frame
				var supported:=true
				for frame in 90:
					if (actor.position-target).dot(travel)>=-.02:break
					actor.apply_locomotion_motion(travel,Vector3.FORWARD,false,false,1.0/90.0);await physics_frame
					if not actor.is_supported() or absf(actor.position.y-roof_center.y)>.04:supported=false
				check(supported and (actor.position-target).dot(travel)>=-.08,label+" production player walks continuously roof to tile "+str(segment))
			check(b.charges==996,label+" three floors spend exactly three of expanded stock")
			b.reset_builds();await physics_frame;await physics_frame
	for t in trackers.values():XRServer.remove_tracker(t)
	game._quitting=true;game.weapon.shutdown();game._stop_audio_tree(game);roof.free();game.queue_free();await process_frame
	# Fixed-fps headless frames run much faster than Dummy's real-time audio
	# thread. Give stopped playbacks one real mixer interval before shutdown.
	OS.delay_msec(180);await process_frame;await create_timer(.2).timeout
	print("CONSTRUCTION_INPUT_061 checks=",checks," failures=",failures," production_adapter=true controller_edges=true player_physics=true xr_runtime=false headset_tested=false")
	quit(failures)
