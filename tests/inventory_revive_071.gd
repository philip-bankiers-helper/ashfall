extends SceneTree
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
	var actor=game.player;actor.xr_enabled=false;actor.input_enabled=true;actor.tracking_available=true;actor.vertical_combat_initializing=false;actor.head_obstructed=false;actor.position=Vector3(1000,0,1000)
	var rack=game.weapon;var inv=game.weapon_inventory;var supply=game.field_consumables;var wheel=rack.wheel
	check(inv.capacity==3 and inv.SLOT_LIMIT==6,"three unlocked initially, six total")
	check(wheel.BASE_ACTIONS[3]=="revive" and wheel.BASE_ACTIONS[4]=="backpack","revive 4:30 / backpack 6 o'clock utility slots")
	# Actual rendered menu mapping, then actual wheel pointer/release route, with duplicate instances.
	var duplicate:int=rack.create_instance(17);rack.weapons[duplicate].ammo=7;rack.weapons[17].ammo=11
	inv.owned.assign([duplicate,14,9,17,26]);supply.items={"supply_17":{"kind":"shaker"}};supply.stock.shaker=1;inv.capacity=6;rack.selected=duplicate
	var before:Node=rack.weapons[duplicate];rack._apply_selection()
	var expected:Array=["weapon_14","weapon_9","weapon_17","weapon_%d"%duplicate,"weapon_26","consumable:supply_17"]
	check(inv.slot_actions()==expected,"mixed duplicate inventory categories sorted by persistent instance")
	check(rack.weapons[duplicate]==before and rack.selected==duplicate and before.ammo==7 and rack.weapons[17].ammo==11,"sorting preserves selected identity and per-instance ammo")
	check(wheel.SLOT_CLOCK_HOURS[3]==4.5 and wheel.SLOT_CLOCK_HOURS[4]==6,"fixed utility clock positions")
	var ordinary_hours:Array=[3.0,1.5,12.0,10.5,9.0,7.5]
	for i in 6:
		var slot:int=wheel.ITEM_SLOTS[i];var point:Vector3=wheel.slot_position(slot,.23)
		check(wheel.SLOT_CLOCK_HOURS[slot]==ordinary_hours[i],"ordinary slot %d at %d o'clock"%[i,ordinary_hours[i]])
		check(slot not in [3,4],"ordinary item never occupies revive/backpack sectors")
		var expected_angle:float=PI/2.0-fposmod(float(ordinary_hours[i]),12.0)*TAU/12.0
		check(point.distance_to(Vector3(cos(expected_angle),sin(expected_angle),0)*.23)<.00001,"rendered icon uses clock position")
		check(wheel.SLOT_ACTIONS[slot]==expected[i],"wheel displayed action matches backpack slot %d"%i)
		check(game._loadout_labels()[i]==inv.action_label(expected[i]),"actual backpack label maps action %d"%i)
		check(absf(game.field_menu.loadout_cell_position(i).x-(.5-i*.2))<.00001,"VR backpack right anchored %d"%i)
	# Every displayed center and hover use the same equal 45-degree partition.
	wheel.global_transform=Transform3D.IDENTITY
	for slot in 8:
		var center:Vector3=wheel.slot_position(slot,.23)
		wheel.point(Transform3D(Basis.IDENTITY,center+Vector3(0,0,1)))
		check(wheel.highlighted==slot,"actual ray hits rendered clock center %d"%wheel.SLOT_CLOCK_HOURS[slot])
	check(wheel.SLOT_ACTIONS[3]=="revive" and wheel.SLOT_ACTIONS[4]=="backpack","full ordinary inventory leaves both utilities intact")
	# Actual A press -> ray hover -> release route, not only a sorted helper assertion.
	var opening:=Transform3D(Basis.IDENTITY,actor.get_view_camera().global_position)
	rack._a_blocked=false;rack.update_a_input(.016,false,true,opening);rack.update_a_input(.11,true,true,opening)
	var pick_point:Vector3=wheel.to_global(wheel.slot_position(wheel.ITEM_SLOTS[0],.23))
	var pick_ray:=Transform3D(Basis.looking_at(pick_point-opening.origin,Vector3.UP),opening.origin)
	rack.update_a_input(.016,true,true,pick_ray);rack.update_a_input(.016,false,true,pick_ray)
	check(rack.selected==14 and not rack.is_holstered,"actual A pointer release equips rightmost sorted sword")
	check(rack.weapons[duplicate]==before and before.ammo==7,"UI selection preserves other duplicate instance ammo")
	for capacity in range(3,7):
		inv.capacity=capacity;inv.owned.assign([14]);supply.items.clear();rack._apply_selection()
		game.field_menu.settings_page="loadout";game.field_menu._refresh()
		for i in 6:
			var label:String=game._loadout_labels()[i];var card:Button=game.field_menu._desktop_loadout_buttons[i]
			check((label=="LOCKED")== (i>=capacity),"locked count follows backpacks %d/%d"%[capacity,i])
			check(card.disabled== (i>0),"empty/locked cards cannot select %d/%d"%[capacity,i])
			if i>=capacity:check(game._loadout_icons()[i].resource_path.ends_with("inventory_locked.svg"),"contrasting X artwork assigned")
	inv.capacity=99;check(inv.capacity==6,"capacity cannot exceed six")
	game.field_menu.set_open(false);actor.input_enabled=true
	var tool=game.revive_paddles;var target=game.rescue_dummy;target.global_position=Vector3(1000,0,1000);target.reset_training()
	check(tool.equip() and rack.is_holstered,"revive equips functional tool and stows gun")
	var l:=Vector3(1000,1,1000);var r:=l+Vector3(.1,0,0)
	for i in 120:tool.step_contacts(1.0/60,l,r,true)
	check(tool.charge==0,"stationary touching paddles cannot charge")
	# Same piecewise-linear .48m rubbing path at 30 and 90Hz; each 30Hz
	# increment is .04m, deliberately above the removed .035m per-frame cap.
	var rates:Array[float]=[]
	for hz in [30,90]:
		tool._clear_charge()
		tool.step_contacts(1.0/hz,Vector3.ZERO,Vector3(.08,-.06,0),true)
		var segment_steps:int=hz/10
		for sample_index in range(1,4*segment_steps+1):
			var phase:float=float(sample_index)/float(segment_steps)
			var y:float=-.06+.12*(1.0-absf(fposmod(phase,2.0)-1.0))
			tool.step_contacts(1.0/hz,Vector3.ZERO,Vector3(.08,y,0),true)
		rates.append(tool.charge)
	check(absf(rates[0]-rates[1])<.0001 and absf(rates[0]-.4/tool.FASTEST_CHARGE_SECONDS)<.0001,"30/90Hz identical physical rubbing gives equal charge")
	check(tool._label.billboard==BaseMaterial3D.BILLBOARD_FIXED_Y and target._label.billboard==BaseMaterial3D.BILLBOARD_FIXED_Y,"paddle and rescue labels stay world upright")
	tool._clear_charge()
	tool.step_contacts(1.0/90,Vector3.ZERO,Vector3(.08,-.06,0),true)
	tool.step_contacts(1.0/90,Vector3.ZERO,Vector3(.08,.06,0),true)
	check(tool.charge==0,"tracking jump above physical speed bound cannot charge")
	tool._clear_charge()
	for i in 300:tool.step_contacts(.02,l,r+Vector3(0,.025 if i%2 else 0,0),true)
	check(tool.charge_ready,"relative rubbing charges paddles")
	var pads:Array=target.revive_contacts()
	check(not tool.step_contacts(.02,pads[0],pads[1]+Vector3(0,0,.8),true) and target.downed,"one contact cannot revive")
	check(tool.step_contacts(.02,pads[0],pads[1],true) and not target.downed and target.health==50,"two charged contacts restore solo casualty health")
	check(not tool.charge_ready and tool.successful_revives==1,"successful rescue spends charge exactly once")
	check(not tool.step_contacts(.02,pads[0],pads[1],true) and target.revive_count==1,"uncharged repeat cannot duplicate revive")
	tool.toggle();check(not tool.active and tool.selected,"A-style stow preserves selected utility")
	tool.toggle();check(tool.active,"A-style equip restores utility")
	rack._clear_consumable_selection();check(not tool.active and not tool.selected,"ordinary selection clears paddles")
	print("INVENTORY_REVIVE_071 checks=",checks," failures=",failures)
	game.weapon.shutdown();game._stop_audio_tree(game);game.queue_free();await create_timer(.25).timeout;quit(0 if failures==0 else 1)
