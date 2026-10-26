extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for c in n.get_children():freeze(c)
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame;freeze(game)
	game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	var a=game.player;var r=game.weapon;var inv=game.weapon_inventory;var s=game.field_consumables
	a.input_enabled=true;a.tracking_available=true;a.xr_enabled=true;a.position=Vector3(1000,0,1000);a.xr_camera.position=Vector3(0,1.404,0)
	var floor_body:=StaticBody3D.new();floor_body.position=Vector3(1000,-.1,1000);var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(30,.2,30);col.shape=box;floor_body.add_child(col);root.add_child(floor_body)
	var trackers:Dictionary={}
	for h in [a.left_hand,a.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="game069_"+str(h.get_instance_id());XRServer.add_tracker(t);h.tracker=t.name;h.pose="grip"
		t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers[h]=t
	await process_frame;await physics_frame;a.update_hand_input_rearm(.2)
	for side in ["left","right"]:
		a.dominant_hand=side;r._refresh_hands();s.reset_supplies(a.position);inv.capacity=3;inv.owned.assign([0,2,9]);r.selected=0;r.is_holstered=false;r._apply_selection()
		for prop in inv.pickups.values():prop.global_position=Vector3(1150,1,1150)
		for i in s.pickups.size():s.pickups[i].global_position=Vector3(1100+i,1,1100)
		var h:XRController3D=a.get_weapon_hand();var other:XRController3D=a.get_support_hand()
		var point:=Vector3(1000,1.2,998.5);s.pickups[0].global_position=point
		h.global_transform=Transform3D(Basis(Vector3.RIGHT,PI*.5),point+Vector3.BACK*1.8)
		s._update_pickup_rings();check(s.aim_rings[h].visible and s.aim_rings[h].get_node("TargetName").text=="SHIELD SHAKER","targeted supply ring and name "+side)
		# Actual targeted ring update paths must keep child names upright at head roll.
		var saved_head_basis:Basis=a.xr_camera.global_basis
		var saved_hand_pose:Transform3D=h.global_transform
		var gun_index:int=inv.pickups.keys()[0]
		var saved_gun_position:Vector3=inv.pickups[gun_index].global_position
		inv.pickups[gun_index].global_position=point
		for roll in [-90.0,90.0]:
			a.xr_camera.global_basis=Basis(Vector3.BACK,deg_to_rad(roll))
			h.global_transform=saved_hand_pose
			s._update_pickup_rings()
			check(s.aim_rings[h].visible and s.aim_rings[h].get_node("TargetName").global_basis.y.dot(Vector3.UP)>.9999,"targeted supply name remains world upright at roll "+str(roll)+side)
			h.global_position=inv._pickup_center(gun_index)+Vector3.BACK*1.8
			inv.update_aim_rings()
			check(inv.aim_rings[h].visible and int(inv.aim_rings[h].get_meta("pickup_index"))==gun_index,"actual weapon target acquired at roll "+str(roll)+side)
			check(inv.aim_rings[h].get_node("TargetName").global_basis.y.dot(Vector3.UP)>.9999,"targeted weapon name remains world upright at roll "+str(roll)+side)
		inv.pickups[gun_index].global_position=saved_gun_position
		a.xr_camera.global_basis=saved_head_basis;h.global_transform=saved_hand_pose

		trackers[h].set_input("grip",0.0);a._objective_grip_frame=-1;a.update_objective_grips();trackers[h].set_input("grip",1.0);a._objective_grip_frame=-1;a.update_objective_grips()
		check(s.held_kind=="shaker" and inv.total_slots()==3,"full shared pickup equips actual arbiter route "+side)
		check(inv.pickups.has(0) and not inv.owned.has(0),"full pickup physically drops old gun instance "+side)
		var shaker_id:String=s.selected_instance
		inv.capacity=4;s.pickups[1].global_position=point+Vector3.RIGHT*.6;h.global_position+=Vector3.RIGHT*.6
		trackers[h].set_input("grip",0.0);a._objective_grip_frame=-1;a.update_objective_grips();trackers[h].set_input("grip",1.0);a._objective_grip_frame=-1;a.update_objective_grips()
		check(s.held_kind=="soda" and s.items.has(shaker_id) and inv.total_slots()==4,"free slot stows prior heal and equips circled soda "+side)
		# Four discrete peel strokes: grip at top, pull down, release/reacquire.
		inv.capacity=5;check(s.collect(2) and s.equip_instance(s.selected_instance,h),"banana pickup equips "+side)
		s._process(.01)
		for stroke in 4:
			other.global_position=s.held_prop.to_global(Vector3(0,.1,0));trackers[other].set_input("grip",1.0)
			check(s.handle_grip("consumable:open",other),"fresh peel grip "+str(stroke))
			s.sample_peel(Vector3(0,-.02,0),true,true);s._update_preparation_visual()
			check(s.peel_count==stroke+1 and (s.phase=="consume")== (stroke==3),"four distinct peels required "+str(stroke))
			s.sample_peel(Vector3(0,-.02,0),true,true);check(s.peel_count==stroke+1,"held stationary peel cannot repeat")
			s.sample_peel(Vector3.ZERO,false,true);trackers[other].set_input("grip",0.0)
		game.health=25;check(s.consume_at_mouth(.51,true,true) and game.health==100,"peeled banana eats and removes its shared slot")
		# Labels disappear when aim leaves; no permanent ground labels.
		h.global_basis=Basis.IDENTITY;s._update_pickup_rings()
		check(not s.pickups[0].get_node("ItemTitle").visible,"no persistent ground supply label")
	# Trigger hold preview / release commit; level aim now chooses a vertical grid face automatically.
	a.xr_enabled=false;a.position=Vector3(1000,0,1000);a.input_enabled=true
	var b=game.field_builder;b.reset_builds();b.piece_index=0;b._set_piece()
	var state:Dictionary={"trigger":false,"cycle":false,"cancel":false,"eligible":true,"tracking":true,"origin":Vector3(1000,1.2,1000),"head":Vector3(1000,1.404,1000),"direction":Vector3.FORWARD}
	b.tick_input(state);state.trigger=true;b.tick_input(state)
	check(b.is_active() and b.preview_valid and b.pieces.is_empty(),"level forward hold displays supported grid wall without placement")
	for i in 10:b.tick_input(state)
	check(b.pieces.is_empty(),"holding trigger never repeats placement")
	state.trigger=false;b.tick_input(state);check(b.pieces.size()==1 and not b.is_active(),"release places exactly one grid wall and closes preview")
	check(b.pieces[0].get_meta("construction_kind")=="wall","forward ray chooses vertical wall geometry")
	state.origin=Vector3(1050,1.2,1050);state.head=state.origin;state.trigger=true;b.tick_input(state)
	check(not b.preview_valid,"unsupported horizontal preview rejected")
	state.trigger=false;b.tick_input(state);check(b.pieces.size()==1,"unsupported release spends nothing")
	var menu=game.field_menu;menu.settings_page="root";menu.audio_page=false
	check(menu._labels()==["LOCOMOTION","SET HEIGHT","WEAPONS","GENERAL","CLOSE"],"reference settings hierarchy")
	menu._refresh();check(absf(menu._rows[0].position.y-.34)<.0001 and menu._category_icons[0].visible,"reference card labels and icons use actual matching layout")
	menu._choose(3);check(menu.settings_page=="general","General card navigates")
	menu.set_numeric_setting(0,.4);check(is_equal_approx(menu.master_volume,.4),"working master volume")
	menu.set_numeric_setting(1,.3);check(is_equal_approx(menu.audio_volumes.SFX,.3),"working SFX slider")
	menu._choose(7);menu._choose(0);check(menu.settings_page=="movement","Back then Locomotion navigates")
	for t in trackers.values():XRServer.remove_tracker(t)
	game._quitting=true;r.shutdown();game._stop_audio_tree(game);await create_timer(1).timeout;game.queue_free();floor_body.free();await process_frame;await process_frame
	print("GAMEPLAY_069 checks=",checks," failures=",failures);quit(failures)
