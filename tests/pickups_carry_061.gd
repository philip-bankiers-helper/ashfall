extends SceneTree
var checks:=0
var failures:=0
var game
var actor
var rack
var inv
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
	for child in node.get_children():freeze(child)
func hover_ok(index:int)->bool:
	var prop:Node3D=inv.pickups[index]
	var low:float=inv._lowest_mesh_point(prop)
	var query:=PhysicsRayQueryParameters3D.create(prop.global_position+Vector3.UP*2,prop.global_position-Vector3.UP*20,1,[actor.get_rid()])
	var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and low-hit.position.y>=.60 and low-hit.position.y<=.90
func grip(hand:XRController3D,value:float)->void:
	trackers[hand].set_input("grip",value)
	if value==0.0:actor.update_hand_input_rearm(.2)
	actor._objective_grip_frame=-1;actor.update_objective_grips()
func aim(hand:XRController3D,index:int,distance:float)->void:
	var center:Vector3=inv._pickup_center(index)
	hand.global_transform=Transform3D(Basis(Vector3.RIGHT,PI/2),center+Vector3.BACK*distance)
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("reports/QA/test-appdata"):quit(2);return
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	for frame in range(65):await physics_frame
	freeze(game);game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	actor=game.player;rack=game.weapon;inv=game.weapon_inventory;actor.input_enabled=true
	check(rack.weapons.size()>=33 and inv.pickups.size()==28 and inv.owned_indices()==[9,2,0],"actual authored Main starts 28 active items plus reserved indices, three carried25 ground")
	for index in inv.pickups:check(hover_ok(index),"authored spawn type%d lowest visible mesh hovers above actual support"%index)
	var original_ids:Dictionary={}
	for index in inv.pickups:original_ids[index]=inv.pickups[index].get_instance_id()
	# Actual Main combat transition and repeated production process calls reproduce
	# the old disappearing parent condition without rendering or headset input.
	game._on_shot(actor.get_view_camera().global_position,Vector3.FORWARD,1.0)
	game._activate_encounter(false)
	for frame in range(12):game._process(1.0/90.0)
	var stable:bool=inv.pickups.size()==28
	for index in original_ids:
		stable=stable and inv.pickups.has(index) and inv.pickups[index].get_instance_id()==original_ids[index] and inv.pickups[index].is_visible_in_tree()
	check(game.encounter_active and stable,"real shooting encounter plus repeated Main processing keeps all ground props visible with stable identities")
	freeze(game)
	var floor:=StaticBody3D.new();floor.position=Vector3(1000,-.1,1000)
	var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,.2,20);col.shape=box;floor.add_child(col);game.add_child(floor)
	actor.global_position=Vector3(1000,0,1000);actor.xr_camera.position.y=1.65
	inv.relocate_pickups(actor.global_position);await physics_frame;await physics_frame;await process_frame
	inv.capacity=6
	for fill in [3,5,6]:check(inv.pickup_weapon(fill),"fill six-slot inventory before full-swap regression")
	actor.xr_enabled=true;actor.tracking_available=true
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.name="pickup044_"+str(hand.get_instance_id());t.type=XRServer.TRACKER_CONTROLLER;XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip"
		t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	for side in ["right","left"]:
		actor.dominant_hand=side;rack._refresh_hands()
		for hand in [actor.left_hand,actor.right_hand]:
			var index:=1 if rack.selected==0 else 0
			# Keep every other real prop, but separate it to make the ray choice unique.
			for other in inv.pickups:
				inv.pickups[other].global_position=Vector3(1005+other,1,1005)
			inv.pickups[index].global_position=Vector3(1000,1.0,998.5)
			var label:String=side+" physical"+("left" if hand==actor.left_hand else "right")+" "
			var old:int=rack.selected;var before:Array=inv.owned_indices();var bank:Dictionary=rack.reserves.duplicate();var loaded:Array=[]
			for gun in rack.weapons:loaded.append(gun.get_loaded_rounds())
			check(not inv.pickup_weapon(index) and inv.owned_indices()==before,label+" generic pickup API still rejects full slots")
			aim(hand,index,2.01);grip(hand,0);inv.update_aim_rings()
			check(inv.get_aimed_pickup(hand)==-1 and not inv.aim_rings[hand].visible,label+" 2.01m rejects and hides ring")
			grip(hand,1);check(inv.owned_indices()==before,label+" out of reach fresh production grip does not pick up")
			aim(hand,index,1.9);grip(hand,0);inv.update_aim_rings()
			check(inv.get_aimed_pickup(hand)==index and inv.aim_rings[hand].visible and inv.aim_rings[hand].get_meta("pickup_index")==index,label+" aimed1.9m target has eligible physical hand ring")
			var blocker:=StaticBody3D.new();blocker.position=hand.global_position+Vector3.FORWARD*.8
			var bc:=CollisionShape3D.new();var bs:=BoxShape3D.new();bs.size=Vector3(1,2,.1);bc.shape=bs;blocker.add_child(bc);game.add_child(blocker);await physics_frame
			inv.update_aim_rings();check(inv.get_aimed_pickup(hand)==-1 and not inv.aim_rings[hand].visible,label+" real intervening wall occludes ring and eligibility")
			grip(hand,1);check(inv.owned_indices()==before,label+" occluded production grip cannot acquire")
			blocker.free();await physics_frame;grip(hand,0);aim(hand,index,1.9)
			game.field_menu.set_open(true);actor.input_enabled=false;grip(hand,1)
			check(inv.owned_indices()==before,label+" paused menu cannot acquire")
			game.field_menu.set_open(false);game.paused=false;actor.input_enabled=true;grip(hand,0)
			rack.weapons[old].reload_state="held_mag";grip(hand,1)
			check(inv.owned_indices()==before,label+" held reload rejects pickup")
			rack.weapons[old].reload_state="ready";grip(hand,0);aim(hand,index,1.9)
			# Acquire a real wall anchor using the production grab query, never insert it.
			rack.set_holstered(true) # 048 requires a weapon hand to be free before wall acquisition.
			var wall:=StaticBody3D.new();wall.position=hand.global_position+Vector3.RIGHT*.06
			var wc:=CollisionShape3D.new();var ws:=BoxShape3D.new();ws.size=Vector3(.08,2,1);wc.shape=ws;wall.add_child(wc);game.add_child(wall);await physics_frame
			actor._update_grab(hand,true,false);var anchor=actor._grabs.get(hand)
			check(actor._grabs.has(hand),label+" production grab query acquires actual wall anchor")
			grip(hand,1);check(inv.owned_indices()==before and actor._grabs.has(hand) and actor._grabs[hand]==anchor,label+" pickup never steals real wall anchor")
			actor._update_grab(hand,false,false);wall.free();await physics_frame;grip(hand,0);rack.set_holstered(false);aim(hand,index,1.9)
			grip(hand,1)
			check(inv.has_weapon(index) and not inv.has_weapon(old) and inv.owned_indices().size()==inv.SLOT_LIMIT and rack.selected==index,label+" full-slot fresh production arbiter grip safely swaps current and equips aimed type")
			check(inv.pickups.has(old) and hover_ok(old),label+" swapped old gun becomes reachable hovering real prop")
			var conserved:bool=rack.reserves==bank
			for gun_index in range(rack.weapons.size()):conserved=conserved and rack.weapons[gun_index].get_loaded_rounds()==loaded[gun_index]
			check(conserved,label+" swap preserves all loaded states and finite banks")
			grip(hand,0)
	var owned:Array=inv.owned_indices();actor.xr_enabled=false;game.chapter=1;game._begin_chapter();await physics_frame;await physics_frame;await process_frame
	check(inv.owned_indices()==owned and inv.pickups.size()==rack.ACTIVE_WEAPON_INDICES.size(),"actual chapter relocation preserves valid carried types and exact active unowned count")
	for index in inv.pickups:check(hover_ok(index),"chapter prop%d still hovers over actual support"%index)
	for t in trackers.values():XRServer.remove_tracker(t)
	game._stop_audio_tree(game);game.queue_free();await process_frame;await create_timer(.2).timeout
	print("PICKUPS_CARRY_048 checks=",checks," failures=",failures," actual_main=true synthetic=true headset_tested=false");quit(failures)

