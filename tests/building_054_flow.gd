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
	var comparison_script:=OS.get_environment("ASHFALL_BUILDING_AUDIT_SCRIPT")
	if not comparison_script.is_empty():
		var previous=builder;builder=load(comparison_script).new();game.add_child(builder);builder.setup(actor,rack,game);game.field_builder=builder;input.builder=builder;builder.input_eligible=input.eligible;rack.construction_provider=builder;previous.free()
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="building054_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);tracker.set_input("primary",Vector2.ZERO);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	var side:float=builder.grid_spacing
	var center:=Vector3((floorf(1000/side)+.5)*side,0,(floorf(1000/side)+.5)*side)
	for dominance in ["right","left"]:
		actor.dominant_hand=dominance;rack._refresh_hands()
		for index in 4:
			var travel:Vector3=[Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT,Vector3.BACK][index]
			var tangent:=travel.cross(Vector3.UP)
			var level:float=[3.73,8.37,12.13,5.91][index]
			var roof:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(side,1,side);collider.shape=shape;roof.add_child(collider);roof.position=center+Vector3.UP*(level-.5);root.add_child(roof)
			actor.position=center+travel*side*.36+Vector3.UP*level;actor.xr_camera.position=Vector3(0,1.65,0);rack.set_holstered(true);builder.reset_builds();builder.piece_index=0;builder._set_piece();builder.charges=12
			await physics_frame;await physics_frame
			var hand:XRController3D=actor.get_weapon_hand();var primary:XRControllerTracker=trackers[hand]
			primary.set_input("trigger",0.0);primary.set_input("by_button",false);primary.set_input("ax_button",false);input._desktop_cancel=false
			for h in [actor.left_hand,actor.right_hand]:actor._hand_input_ready[h]=true
			input._physics_process(.011)
			for cycle in 2:
				primary.set_input("by_button",true);rack._switch_previous=false;rack._process(.011);input._physics_process(.011)
				primary.set_input("by_button",false);rack._process(.011);input._physics_process(.011)
			var label:String=dominance+" "+str(travel)+" roof="+str(level)
			check(rack.is_holstered and builder.piece_index==2 and builder.pieces.is_empty(),label+" actual B/Y selects floor without draw/placement")
			check(absf(builder._level_y-level)<.006,label+" preview captures standing height")
			for segment in 3:
				var target:=center+travel*side*float(segment+1)+Vector3.UP*level
				# Off-axis hand origins produce genuinely oblique pointers on every
				# roof; the intended tile is on the shared standing plane.
				var origin:Vector3=actor.global_position+Vector3.UP*(1.05+segment*.12)+tangent*(.35+segment*.11)
				var direction:Vector3=(target-origin).normalized()
				var pointer:=Transform3D(Basis.looking_at(direction,Vector3.UP),origin)
				hand.global_transform=pointer*Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3.ZERO)
				primary.set_input("trigger",0.0);input._physics_process(.011);primary.set_input("trigger",1.0);input._physics_process(.011);primary.set_input("trigger",0.0);input._physics_process(.011)
				var floors:Array=builder.pieces.filter(func(p):return is_instance_valid(p) and p.get_meta("construction_kind","")=="floor")
				check(floors.size()==segment+1,label+" actual trigger places extension "+str(segment))
				if floors.size()!=segment+1:
					print("TARGET_FAILURE reason=",builder.invalid_reason," origin=",origin," intended=",target," selected=",builder._placement.origin)
					continue
				var floor:Node3D=floors[-1]
				check(floor.position.distance_to(target-Vector3.UP*.08)<.012,label+" aimed finite tile stays at standing layer "+str(segment))
				await physics_frame;await physics_frame
				var supported:=true
				for frame in 80:
					if (actor.position-target).dot(travel)>=-.02:break
					actor.apply_locomotion_motion(travel,Vector3.FORWARD,false,false,1.0/90.0);await physics_frame
					if not actor.is_supported() or absf(actor.position.y-level)>.04:supported=false
				check(supported and (actor.position-target).dot(travel)>=-.08,label+" production locomotion continuously walks onto extension "+str(segment))
			builder.reset_builds();roof.free();await physics_frame;await physics_frame
	# Every shape is also selected/committed through the actual adapter in both
	# dominances, rather than configuring a legacy transform for the fixture.
	for dominance in ["right","left"]:
		actor.dominant_hand=dominance;rack._refresh_hands();rack.set_holstered(true)
		var hand:XRController3D=actor.get_weapon_hand();var primary:XRControllerTracker=trackers[hand]
		for axis in [Vector3.RIGHT,Vector3.FORWARD]:
			for kind in 3:
				builder.reset_builds();builder.charges=12;builder.piece_index=2;builder._set_piece();actor.position=center+Vector3.UP*8.37
				await physics_frame;await physics_frame
				primary.set_input("trigger",0.0);primary.set_input("by_button",false);input._physics_process(.011)
				for cycle in kind+1:
					primary.set_input("by_button",true);rack._switch_previous=false;rack._process(.011);input._physics_process(.011)
					primary.set_input("by_button",false);rack._process(.011);input._physics_process(.011)
				var origin:Vector3=actor.position+Vector3.UP*1.3
				var direction:Vector3=(axis+axis.cross(Vector3.UP)*.15+Vector3.DOWN*(1.5 if kind==2 else .35)).normalized()
				hand.global_transform=Transform3D(Basis.looking_at(direction,Vector3.UP),origin)*Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3.ZERO)
				primary.set_input("trigger",1.0);input._physics_process(.011);primary.set_input("trigger",0.0);input._physics_process(.011)
				var expected:String=builder.kinds[kind]
				check(builder.piece_index==kind and rack.is_holstered and builder.pieces.any(func(p):return p.get_meta("construction_kind","")==expected),dominance+" actual input commits "+expected+" aimed "+str(axis))
				if not builder.pieces.any(func(p):return p.get_meta("construction_kind","")==expected):print("SHAPE_FAILURE kind=",expected," reason=",builder.invalid_reason," origin=",input.sample().origin," direction=",input.sample().direction," selected=",builder._placement.origin)
				await physics_frame;await physics_frame
				var first_count:int=builder.pieces.filter(func(p):return p.get_meta("construction_kind","")==expected and not p.get_meta("lower_support",false)).size()
				primary.set_input("trigger",1.0);input._physics_process(.011);primary.set_input("trigger",0.0);input._physics_process(.011)
				var second_count:int=builder.pieces.filter(func(p):return p.get_meta("construction_kind","")==expected and not p.get_meta("lower_support",false)).size()
				check(first_count==1 and second_count==2,dominance+" same actual pointer commits next depth "+expected+" "+str(axis))
				if second_count!=2:print("DEPTH_FAILURE kind=",expected," reason=",builder.invalid_reason," count=",second_count)
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	game._quitting=true;game.weapon.shutdown();game._stop_audio_tree(game);game.queue_free();await create_timer(.2).timeout
	print("BUILDING_054_FLOW checks=",checks," failures=",failures," actual_controller_input_and_physics=true headset_tested=false")
	quit(failures)
