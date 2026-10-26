extends SceneTree
class RejectSecondDrop extends "res://scripts/weapon_inventory.gd":
	var attempts:=0
	func _place_reachable_drop(_prop:Node3D)->bool:
		attempts+=1
		return attempts<2
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for child in n.get_children():freeze(child)
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame;freeze(game)
	game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	var actor=game.player;var rack=game.weapon;var inv=game.weapon_inventory;var supply=game.field_consumables
	actor.xr_enabled=false;actor.input_enabled=true;actor.tracking_available=true;actor.vertical_combat_initializing=false;actor.head_obstructed=false;actor.position=Vector3(1000,0,1000)
	var floor_body:=StaticBody3D.new();floor_body.position=Vector3(1000,-.1,1000)
	var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(30,.2,30);col.shape=box;floor_body.add_child(col);root.add_child(floor_body);await physics_frame
	inv.owned.clear();inv._slot_groups.clear();supply.reset_supplies(actor.position);inv.capacity=3
	check(inv.total_slots()==0,"zero items use zero slots")
	check(supply.collect(0) and supply.equip_instance(supply.selected_instance),"first shaker pickup equips its persistent instance")
	var first:String=supply.selected_instance;supply.phase="consume"
	check(supply.collect(3) and supply.equip_instance(supply.selected_instance),"second shaker pickup equips new instance")
	var second:String=supply.selected_instance
	check(first!=second and supply.saved_states[first].phase=="consume" and supply.phase=="shake","shakers keep independent readiness and selected identity")
	check(inv.total_slots()==1 and inv.stack_count("consumable:"+second)==2,"two shakers share one slot")
	check(inv.slot_actions()[0]=="consumable:"+second and game._loadout_labels()[0].ends_with("x2"),"actual selector chooses held member and displays count")
	rack._apply_selection();check(rack.wheel.has_node("StackCount%d"%rack.wheel.ITEM_SLOTS[0]),"wheel renders stack count")
	check(supply.collect(6) and supply.equip_instance(supply.selected_instance),"third shaker gets overflow slot")
	var third:String=supply.selected_instance
	check(inv.total_slots()==2 and inv.stack_count("consumable:"+third)==1,"third item never expands first stack above two")
	supply.equip_instance(second);supply.phase="consume";game.shield=0
	check(supply.consume_at_mouth(.66,true,true),"consume selected member")
	check(inv.total_slots()==2 and supply.selected_instance==first and supply.phase=="consume","partially consumed stack stays separate from overflow; ready survivor autoequips")
	game.shield=0;check(supply.consume_at_mouth(.66,true,true) and inv.total_slots()==1 and supply.items.has(third),"slot removed only when original stack becomes empty")
	# Full inventory: matching half-stack adds no drops; third overflow replaces whole held stack.
	supply.reset_supplies(actor.position);inv.owned.assign([0,2]);inv._slot_groups.clear();rack.selected=0
	check(supply.collect(0) and supply.equip_instance(supply.selected_instance),"create full inventory with one shaker")
	first=supply.selected_instance;supply.phase="consume"
	check(supply.collect(3) and supply.equip_instance(supply.selected_instance),"matching stack pickup accepted at full slot capacity")
	second=supply.selected_instance
	check(inv.total_slots()==3 and inv.owned.has(0) and inv.owned.has(2) and supply.items.size()==2,"matching stack drops nothing")
	var reject:=RejectSecondDrop.new();root.add_child(reject);reject.player=actor;reject.rack=rack
	check(not reject.drop_slot("consumable:"+second) and reject.attempts==2,"second placement failure rejects whole-slot transaction")
	check(supply.items.has(first) and supply.items.has(second) and supply.selected_instance==second,"failed whole-slot drop preserves both members and selected ID")
	reject.free()
	check(supply.collect(1) and supply.equip_instance(supply.selected_instance),"different type replaces full held two-item slot")
	check(inv.total_slots()==3 and supply.items.size()==1 and supply.held_kind=="soda","whole-slot replacement preserves capacity and equips incoming")
	var dropped:Array=[]
	for prop in supply.pickups:
		if not prop.get_meta("taken",false) and str(prop.get_meta("item_id","")) in [first,second]:dropped.append(str(prop.get_meta("item_id")))
	check(dropped.size()==2 and dropped.has(first) and dropped.has(second) and supply.saved_states[first].phase=="consume","both replaced members become physical pickups with original state/IDs")
	# Soda stacking and banana exclusion.
	supply.reset_supplies(actor.position);inv.owned.clear();inv._slot_groups.clear();inv.capacity=6
	for index in [1,4,7,2,5]:check(supply.collect(index),"collect soda/banana case %d"%index)
	check(inv.total_slots()==4 and supply.items.size()==5,"three sodas use two slots; two bananas use two single slots")
	# Normal grenades only. Zone grenades and duplicate firearms remain individual instances.
	supply.reset_supplies(actor.position);inv._slot_groups.clear()
	var frag2:int=rack.create_instance(26);var frag3:int=rack.create_instance(26);var zone2:int=rack.create_instance(28);var gun2:int=rack.create_instance(17)
	inv.owned.assign([26,frag2,frag3,28,zone2,17,gun2]);rack.selected=frag2;rack.is_holstered=false;rack._apply_selection()
	check(inv.total_slots()==6 and inv.stack_count("weapon_26")==2 and inv.stack_count("weapon_%d"%frag3)==1,"normal grenade pair plus overflow uses two slots")
	check(inv.stack_count("weapon_28")==1 and inv.stack_count("weapon_%d"%zone2)==1 and inv.stack_count("weapon_17")==1 and inv.stack_count("weapon_%d"%gun2)==1,"zone grenades and duplicate weapons never stack")
	check(rack.weapons[frag2].ammo==1 and rack.weapons[zone2].ammo==1,"one payload per normal/zone grenade instance")
	var grenade= rack.weapons[frag2];grenade.global_position=actor.get_view_camera().global_position+Vector3(0,0,-.3)
	grenade.cooldown=0
	grenade.throw_input(false,true,Vector3.ZERO);grenade.throw_input(true,true,Vector3.FORWARD*4);await process_frame
	check(not inv.owned.has(frag2) and rack.selected==26 and inv.total_slots()==6,"actual grenade throw decrements pair and equips survivor without removing slot")
	check(inv.owned.has(frag3) and inv.stack_count("weapon_%d"%frag3)==1,"overflow grenade remains its own slot")
	print("INVENTORY_STACK_071 checks=",checks," failures=",failures)
	game.weapon.shutdown();game._stop_audio_tree(game);game.queue_free();floor_body.queue_free();await create_timer(.25).timeout;quit(0 if failures==0 else 1)
