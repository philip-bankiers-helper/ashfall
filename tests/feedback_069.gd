extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame
	freeze(game);game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	var actor=game.player;actor.input_enabled=true;actor.tracking_available=true
	var inv=game.weapon_inventory;var rack=game.weapon;var supplies=game.field_consumables
	check(inv.total_slots()==3 and inv.capacity==3,"three shared slots initially occupied; three locked")
	check(rack.wheel.ITEM_SLOTS.size()==6 and rack.wheel.SLOT_ACTIONS.count("locked")==3,"exactly six item sectors with three locked")
	check(supplies.total_items()==0,"no additional hidden heal slots")
	for i in [9,10,11]:check(supplies.collect(i),"each backpack unlocks one slot")
	check(inv.capacity==6,"maximum six shared slots")
	var clone:int=rack.create_instance(18);inv._spawn_pickup(clone,Vector3(1,.75,-1))
	check(inv.pickup_weapon(18) and inv.pickup_weapon(clone),"duplicate MP9 instances accepted")
	rack.weapons[18].ammo=3;rack.weapons[clone].ammo=9
	check(rack.weapons[18]!=rack.weapons[clone] and rack.catalog_index(clone)==18,"stable separate instances share catalog identity only")
	check(supplies.collect(0),"heal occupies sixth shared slot")
	check(inv.total_slots()==6 and supplies.items.size()==1,"six total includes heal")
	var id:String=supplies.selected_instance
	check(supplies.equip_instance(id),"selected heal equips")
	check(rack.is_holstered and supplies.held_kind=="shaker","heal in hand hides gun")
	for i in 480:supplies.sample_shake(Vector3(sin(i*.25)*.12,0,0),1.0/90)
	check(supplies.phase=="consume" and supplies.audio_events.has("ready"),"horizontal actual shaker motion charges with ready cue")
	supplies._update_preparation_visual()
	check(supplies.held_prop.get_node("ItemTitle").text.contains("READY"),"conspicuous ready visual")
	supplies.stow();check(supplies.equip_instance(id) and supplies.phase=="consume","per-instance preparation survives stow/equip")
	var before_selected:int=rack.selected
	rack.weapons[clone].reload_state="needs_mag"
	var sorted:Array=inv.owned_indices();inv.owned.reverse();check(inv.owned_indices()==sorted,"sorting independent of ownership insertion order")
	check(rack.weapons[18].ammo==3 and rack.weapons[clone].ammo==9 and rack.weapons[clone].reload_state=="needs_mag" and rack.selected==before_selected,"sorting preserves distinct ammo and selected identity")
	check(inv.slot_actions().size()==6,"six actions for six items")
	rack.wheel.set_owned_indices(sorted)
	for slot in rack.wheel.ITEM_SLOTS:
		var action:String=rack.wheel.SLOT_ACTIONS[slot]
		if action.begins_with("consumable:"):check(inv.action_icon(action)!=null,"heal has visible image asset")
	game._open_backpack();check(game._loadout_labels().size()==6 and not str(game._loadout_labels()).contains("RETURN"),"backpack has six slots and no settings return")
	game.field_menu._loadout_gesture(.1,true,false,false);game.field_menu._loadout_gesture(.1,true,true,false)
	check(not game.field_menu.is_open,"A closes backpack outright")
	# Stand above seated calibration; lowering returns exactly to baseline/crouch.
	actor.xr_enabled=true;actor.xr_camera.position.y=1.0;actor.xr_origin.position.y=0;actor.initialize_vertical_combat_system()
	actor.xr_camera.position.y=1.7;actor._apply_vertical_combat_ceiling()
	check(absf(actor.measured_eye_height()-1.7088)<.0001,"standing after seated calibration capped at six-foot top")
	actor.xr_camera.position.y=.8;actor._apply_vertical_combat_ceiling()
	check(absf(actor.measured_eye_height()-1.5088)<.0001,"downward crouch preserved at1:1")
	actor.xr_camera.position.y=1.6;actor._apply_vertical_combat_ceiling();actor.initialize_vertical_combat_system();actor._apply_vertical_combat_ceiling()
	check(absf(actor.measured_eye_height()-1.7088)<.0001,"reinitialize while capped does not double-apply correction")
	var factor:float=preload("res://scripts/measurement_calibration.gd").FACTOR
	for index in [14,15,16]:
		var sword:Node3D=rack.weapons[index];var pommel:MeshInstance3D=sword.model.get_node("Pommel")
		var bottom:Vector3=pommel.to_global(Vector3(0,-pommel.mesh.size.y*.5,0))
		check(absf(bottom.distance_to(sword.blade_tip.global_position)-1.2192*factor)<.00001,"final sword hierarchy factor once "+str(index))
		check(absf(bottom.distance_to(sword.model.to_global(sword.hand_grip_center))-.2032*factor)<.00001,"grip datum factor once "+str(index))
	check(is_equal_approx(rack.weapons[27].ROCKET_GRIP.z,-.3195),"076 grip centered on tube without changing world scale")
	# Recoil patterns are separate from return envelope.
	var s85=rack.weapons[25];s85.recoil_pitch=.2;s85.recoil_idle=.09;s85._recover_recoil(.1)
	check(s85.recoil_pitch<.04,"S85 returns substantially faster")
	game._quitting=true;rack.shutdown();game._stop_audio_tree(game);await create_timer(1).timeout;game.queue_free();await process_frame;await process_frame
	print("FEEDBACK_069 checks=",checks," failures=",failures);quit(failures)
