extends SceneTree
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1;print("PASS " if value else "FAIL ",label)
	if not value:failures+=1
func pointer(hand:Node3D,point:Vector3,ray:Vector3)->void:
	var up:=Vector3.FORWARD if absf(ray.normalized().dot(Vector3.UP))>.99 else Vector3.UP
	hand.global_transform=Transform3D(Basis.looking_at(ray.normalized(),up),point)*Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3.ZERO)
func box(point:Vector3,size:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new();var shape:=BoxShape3D.new();shape.size=size;var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);root.add_child(body);body.position=point;return body
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame
	game.set_process(false);game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	var actor=game.player;actor.set_process(false);actor.set_physics_process(false);actor.xr_enabled=true;actor.tracking_available=true;actor.input_enabled=true;actor.head_obstructed=false;actor.mantling=false
	var rack=game.weapon;rack.set_process(false);var builder=game.field_builder;var adapter=game.building_input;adapter.set_physics_process(false);adapter.team_marks.set_physics_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="build071_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("trigger",0.0);tracker.set_input("grip",0.0);tracker.set_input("primary",Vector2.ZERO);tracker.set_input("ax_button",false);tracker.set_input("by_button",false);trackers[hand]=tracker
	await process_frame
	var side:float=builder.grid_spacing
	for sign_value in [-1.0,1.0]:
		var center:=Vector3((floorf(sign_value*1000/side)+.5)*side,0,(floorf(sign_value*1000/side)+.5)*side)
		var ground:=box(center-Vector3.UP*.1,Vector3(side*6,.2,side*6));await physics_frame;await physics_frame
		for free_side in ["left","right"]:
			builder.reset_builds();await physics_frame;await physics_frame
			actor.position=center;actor.xr_camera.position=Vector3(0,1.524,0);actor.dominant_hand="right";rack._refresh_hands();rack.set_holstered(true)
			var free_hand=actor.left_hand if free_side=="left" else actor.right_hand
			var anchor=actor.right_hand if free_side=="left" else actor.left_hand
			actor._grabs.clear();actor._grabs[anchor]={"test_anchor":"preserve"};actor.climbing=true
			for hand in [actor.left_hand,actor.right_hand]:actor._hand_input_ready[hand]=true
			pointer(free_hand,center+Vector3.UP*1.2,Vector3.FORWARD)
			trackers[free_hand].set_input("trigger",0.0);adapter._physics_process(.011)
			check(adapter.eligible(),free_side+" free hand eligible while opposite grip climbs")
			trackers[free_hand].set_input("by_button",true);rack._switch_previous=false;rack._process(.011);adapter._physics_process(.011)
			check(rack.is_holstered and builder.pieces.is_empty(),"B neither draws weapon nor builds/cycles")
			trackers[free_hand].set_input("by_button",false);trackers[free_hand].set_input("trigger",1.0);adapter._physics_process(.011)
			check(builder.is_active() and builder.preview_valid and builder.kinds[builder.piece_index]=="wall","forward hold previews first grid wall")
			var shown:Transform3D=builder.preview.global_transform
			actor.position+=Vector3.UP*.1 # Moving/hanging player must not reanchor grid.
			pointer(free_hand,center+Vector3.UP*1.3,Vector3.FORWARD);adapter._physics_process(.011)
			check(builder.preview.global_transform.is_equal_approx(shown),"hanging movement preserves world lattice")
			trackers[free_hand].set_input("trigger",0.0);adapter._physics_process(.011)
			check(builder.pieces.size()==1 and builder.pieces[0].global_transform.is_equal_approx(shown),"release commits exact preview transform once")
			check(actor._grabs.has(anchor) and actor._grabs[anchor].test_anchor=="preserve","build preserves anchored grip")
			await physics_frame;await physics_frame
			pointer(free_hand,center+Vector3.UP*1.2,Vector3.UP);adapter._physics_process(.011);trackers[free_hand].set_input("trigger",1.0);adapter._physics_process(.011)
			check(builder.preview_valid and builder.kinds[builder.piece_index]=="floor","upward ray selects supported horizontal face")
			var floor_transform:Transform3D=builder.preview.global_transform
			trackers[free_hand].set_input("trigger",0.0);adapter._physics_process(.011)
			check(builder.pieces.size()==2 and absf(floor_transform.origin.y-side)<.0001,"adjacent floor shares wall-top lattice plane")
			builder._refresh_support_graph();check(builder._supported.size()==2,"wall to floor support propagates")
			# A regrip cancels an in-progress free-hand preview, never releases anchor.
			pointer(free_hand,center+Vector3.UP*1.2,Vector3.RIGHT);adapter._physics_process(.011);trackers[free_hand].set_input("trigger",1.0);adapter._physics_process(.011);actor._grabs[free_hand]={"test_anchor":"second"};adapter._physics_process(.011)
			check(not builder.is_active() and actor._grabs.has(anchor),"both grips cancel preview without ungripping")
			actor._grabs.erase(free_hand);adapter._physics_process(.011);check(not builder.is_active(),"release-regrip requires fresh trigger")
			trackers[free_hand].set_input("trigger",0.0);adapter._physics_process(.011)
			actor._grabs.clear();actor.climbing=false;actor.dominant_hand=free_side;rack._refresh_hands();builder.reset_builds();await physics_frame;await physics_frame
			pointer(free_hand,center+Vector3.UP*1.2,Vector3.FORWARD)
			var obstruction:=box(center+Vector3(0,1.2,-.5),Vector3(.8,1,.1));await physics_frame
			adapter._physics_process(.011);trackers[free_hand].set_input("trigger",1.0);adapter._physics_process(.011)
			check(builder.preview_valid,"world object does not block lattice preview")
			trackers[free_hand].set_input("trigger",0.0);adapter._physics_process(.011);check(builder.pieces.size()==1,"release places supported panel despite world overlap");builder.reset_builds()
			obstruction.free()
			await physics_frame;await physics_frame
			pointer(free_hand,center+Vector3.UP*1.2,Vector3(1,0,-1));adapter._physics_process(.011);trackers[free_hand].set_input("trigger",1.0);adapter._physics_process(.011)
			var corner_key:String=builder._slot_key()
			for jitter in [-.003,.003,-.002,.002]:
				pointer(free_hand,center+Vector3.UP*1.2,Vector3(1+jitter,0,-1));adapter._physics_process(.011)
				check(builder.preview_valid and builder._slot_key()==corner_key,"near-tie corner hysteresis keeps face stable")
			trackers[free_hand].set_input("ax_button",true);adapter._physics_process(.011);trackers[free_hand].set_input("ax_button",false);trackers[free_hand].set_input("trigger",0.0);adapter._physics_process(.011)
			builder.reset_builds();actor.position+=Vector3(17,.25,-13);builder._capture_floor_grid({"origin":actor.position})
			check(builder.grid_origin==Vector3.ZERO and builder._level_y==0 and builder._floor_grid_origin==Vector2.ZERO,"reset/reinitialize/movement preserve map grid")
			pointer(free_hand,center+Vector3.UP*1.2,Vector3.DOWN)
			var marks=adapter.team_marks;var previous_marks:int=marks.records.size()
			trackers[free_hand].set_input("by_button",false);marks._physics_process(.01);trackers[free_hand].set_input("by_button",true);rack._process(.1);marks._physics_process(.1);trackers[free_hand].set_input("by_button",false);marks._physics_process(.01)
			check(marks.records.size()==previous_marks+1 and marks.records[-1].color=="blue" and rack.is_holstered,"actual B tracker path marks aimed ground without switching")
		ground.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	game._quitting=true;rack.shutdown();game._stop_audio_tree(game);game.queue_free();await process_frame;await create_timer(.3).timeout
	print("BUILD_MARKS_INPUT_071 checks=",checks," failures=",failures," actual_input_adapter=true headset_tested=false")
	quit(failures)
