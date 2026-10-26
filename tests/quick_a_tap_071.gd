extends SceneTree
var checks:=0
var failures:=0
var rack
var actor
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for child in n.get_children():freeze(child)
func gesture(seconds:float,hz:int,long_target:int=-1)->void:
	var origin:Vector3=actor.get_view_camera().global_position
	var ray:=Transform3D(Basis.IDENTITY,origin)
	rack.cancel_selection();rack.update_a_input(0,false,true,ray)
	var elapsed:=0.0;var frame:=0;var opened_early:=false
	while elapsed<seconds-.00000001:
		var dt:=minf(seconds-elapsed,(1.0/hz)*(1.2 if frame%2 else .8))
		ray=Transform3D(Basis(Vector3.UP,.7 if frame%2 else -.7),origin+Vector3(.04 if frame%2 else -.04,0,0))
		rack.update_a_input(dt,true,true,ray);elapsed+=dt;frame+=1
		if elapsed<=.1 and rack.is_selecting:opened_early=true
	check(not opened_early,"wheel remains closed during <=100ms despite pointer jitter")
	if long_target>=0:
		check(rack.is_selecting,"hold above100ms opens wheel")
		var slot:int=rack.wheel.SLOT_ACTIONS.find("weapon_%d"%long_target)
		var point:Vector3=rack.wheel.to_global(rack.wheel.slot_position(slot,.23))
		ray=Transform3D(Basis.looking_at(point-origin,Vector3.UP),origin)
	rack.update_a_input(0,false,true,ray)
	# Repeated released samples must never toggle again or select another instance.
	rack.update_a_input(1.0/hz,false,true,ray)
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame;freeze(game)
	game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	actor=game.player;rack=game.weapon
	actor.xr_enabled=false;actor.input_enabled=true;actor.tracking_available=true;actor.vertical_combat_initializing=false;actor.head_obstructed=false
	game.weapon_inventory.owned.assign([0,14,9]);game.weapon_inventory.capacity=6
	for side in ["left","right"]:
		actor.dominant_hand=side;rack._refresh_hands()
		for hz in [30,72,90,120]:
			for seconds in [.06,.099,.10]:
				rack._clear_consumable_selection();rack.selected=0;rack.is_holstered=false;rack.weapons[0].ammo=7;rack._apply_selection()
				gesture(seconds,hz)
				check(rack.selected==0 and rack.is_holstered and rack.weapons[0].ammo==7,"quick weapon tap stows same instance %s/%d/%s"%[side,hz,seconds])
				gesture(seconds,hz)
				check(rack.selected==0 and not rack.is_holstered and rack.weapons[0].ammo==7,"next tap restores same gun without double click")
				var supply=game.field_consumables;supply.items={"tap_a":{"kind":"shaker"},"tap_b":{"kind":"shaker"}};supply.stock.shaker=2
				supply.equip_instance("tap_b");supply.phase="consume"
				gesture(seconds,hz)
				check(supply.selected_instance=="tap_b" and supply.held_kind.is_empty() and supply.items.size()==2,"quick heal tap stows selected stack member")
				gesture(seconds,hz)
				check(supply.selected_instance=="tap_b" and supply.held_kind=="shaker" and supply.phase=="consume","quick heal tap restores readiness and member ID")
				rack._clear_consumable_selection();game.revive_paddles.equip()
				gesture(seconds,hz);check(not game.revive_paddles.active and game.revive_paddles.selected,"quick paddle tap stows utility")
				gesture(seconds,hz);check(game.revive_paddles.active,"quick paddle tap restores utility")
				rack._clear_consumable_selection();supply.items.clear();supply.stock.shaker=0
			rack.selected=0;rack.is_holstered=false;rack._apply_selection()
			gesture(.1001,hz,14)
			check(rack.selected==14 and not rack.is_holstered,"just above100ms release selects hovered item")
	var menu=game.field_menu;rack.selected=0;rack.is_holstered=false;rack._apply_selection()
	menu.set_open(true);menu.settings_page="loadout"
	var ray:=Transform3D(Basis.IDENTITY,actor.get_view_camera().global_position)
	rack.update_a_input(.03,true,true,ray)
	menu._loadout_gesture(.016,true,false,false);menu._loadout_gesture(.016,true,true,false)
	actor.input_enabled=true;rack.update_a_input(.016,false,true,ray)
	check(not menu.is_open and rack.selected==0 and not rack.is_holstered and not rack.is_selecting,"backpack A closes menu without leaking into quick-toggle")
	print("QUICK_A_TAP_071 checks=",checks," failures=",failures)
	game.weapon.shutdown();game._stop_audio_tree(game);game.queue_free();await create_timer(.25).timeout;quit(0 if failures==0 else 1)
