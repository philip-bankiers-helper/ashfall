extends SceneTree
class RejectInventory extends Node:
	var attempts:=0
	func has_weapon(index:int)->bool:return index in [0,2,4]
	func owned_indices()->Array:return [0,2,4]
	func drop_weapon(_index:int)->bool:
		attempts+=1
		return false
var passed:=0
var failed:=0
var rack
var actor
var opening:=Transform3D(Basis.IDENTITY,Vector3(.15,1.25,0))
func _initialize(): call_deferred("run")
func check(ok:bool,label:String):
	if ok: passed+=1;print("PASS ",label)
	else: failed+=1;printerr("FAIL ",label)
func ray_to(point:Vector3)->Transform3D:
	return Transform3D(Basis.looking_at(point-opening.origin,Vector3.UP),opening.origin)
func sector(slot:int,radius:float)->Transform3D:
	return ray_to(rack.wheel.to_global(rack.wheel.slot_position(slot,radius)))
func begin():
	rack.update_a_input(.011,false,true,opening)
	rack.update_a_input(.011,true,true,opening)
func finish(ray:Transform3D):
	rack.update_a_input(.011,false,true,ray)
func run():
	actor=load("res://scripts/player.gd").new()
	root.add_child(actor);actor.setup(false);actor.set_physics_process(false)
	rack=load("res://scripts/weapon_rack.gd").new()
	root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	await process_frame
	var reserves:Dictionary=rack.reserves.duplicate()
	for dominant in ["right","left"]:
		actor.dominant_hand=dominant
		rack._refresh_hands()
		check(rack._weapon_hand()==(actor.right_hand if dominant=="right" else actor.left_hand),dominant+" dominant A path follows physical role")
		begin()
		check(rack.is_selecting and rack.wheel.visible,dominant+" A-down opens in first11ms sample")
		check(rack.wheel.global_basis.x.length()>1.199,dominant+" flat wheel remains20percent larger")
		var target:=2 if rack.selected!=2 else 3
		var flick:=sector(rack.wheel.SLOT_ACTIONS.find("weapon_%d"%target),.8)
		rack.update_a_input(.011,true,true,flick)
		check(rack.selected!=target,dominant+" hover never equips before release")
		finish(flick)
		check(rack.selected==target and not rack.is_selecting and not rack.is_holstered,dominant+" subhold33ms wristflick equips on release")
		var after:int=rack.selected
		finish(flick)
		check(rack.selected==after and not rack.is_selecting,dominant+" duplicate release cannot act twice")
		for radius in [.081,.34,.8,3.0,20.0]:
			begin()
			for slot in range(8):
				rack.wheel.point(sector(slot,radius))
				check(rack.wheel.highlighted==slot,dominant+" angular sector%d radius%s"%[slot,radius])
				check(Vector2(rack.wheel.pointer.position.x,rack.wheel.pointer.position.y).length()<=.34001,"visible pointer stays within wheel")
			# End this geometry-only gesture through a neutral input cancellation.
			rack.cancel_selection()
		begin()
		for boundary in range(8):
			for epsilon in [-.0002,.0002]:
				var angle:float=PI/2+PI/8-boundary*PI/4+epsilon
				var hit:Vector3=rack.wheel.to_global(Vector3(cos(angle)*4,sin(angle)*4,0))
				rack.wheel.point(ray_to(hit))
				var expected:int=posmod(boundary-(1 if epsilon>0 else 0),8)
				check(rack.wheel.highlighted==expected,dominant+" distant boundary%d epsilon%s maps adjacent angularsector"%[boundary,epsilon])
		rack.cancel_selection()
		for hold in [1,50]:
			rack.set_holstered(false)
			begin()
			for i in range(hold):rack.update_a_input(.011,true,true,opening)
			finish(opening)
			check(rack.is_holstered,dominant+" center-only gesture holsters exactly once hold%s"%hold)
			finish(opening)
			check(rack.is_holstered,dominant+" held release does not toggle again")
			begin();finish(opening)
			check(not rack.is_holstered,dominant+" next center tap draws")
		rack.set_holstered(true)
		begin()
		var empty_slot:int=rack.wheel.SLOT_ACTIONS.find("empty")
		if empty_slot>=0:
			var empty:=sector(empty_slot,2)
			rack.update_a_input(.011,true,true,empty);finish(empty)
			check(rack.is_holstered,dominant+" empty-sector gesture does not draw or equip")
		else:check(false,"empty sector fixture exists")
		begin()
		rack.update_a_input(.011,true,true,sector(1,2))
		finish(opening)
		check(rack.is_holstered,dominant+" flick then return center cancels without tap toggle")
		begin()
		rack.update_a_input(.011,true,false,sector(0,2))
		finish(sector(0,2))
		check(not rack.is_selecting and rack.is_holstered,dominant+" tracking cancellation cannot equip or toggle on release")
		begin()
		var backward:=Transform3D(Basis(Vector3.UP,PI),opening.origin)
		finish(backward)
		check(rack.is_holstered,dominant+" backward invalid ray never becomes center tap")
		check(not rack.wheel.find_children("WeaponIcon*","Sprite3D",false,false).is_empty(),"flat original icons retained")
	check(rack.reserves==reserves,"all wheel interactions preserve finite reserve inventory")
	var rejected:=RejectInventory.new()
	root.add_child(rejected)
	rack.inventory=rejected
	rack._apply_selection()
	for dominant in ["right","left"]:
		actor.dominant_hand=dominant
		rack._refresh_hands()
		rack.selected=0
		rack.set_holstered(true)
		begin()
		var blocked_ray:=sector(rack.wheel.SLOT_ACTIONS.find("weapon_2"),2)
		var attempts_before:int=rejected.attempts
		rack.update_a_input(3.01,true,true,blocked_ray)
		for i in range(30):rack.update_a_input(.1,true,true,blocked_ray)
		check(rejected.attempts==attempts_before+1,dominant+" rejected placement attempts drop only once per held gesture")
		check(rejected.has_weapon(2) and not rack.wheel._drop_ring.visible,dominant+" rejected drop retains ownership and hides progress")
		finish(blocked_ray)
		check(rack.selected==0 and rack.is_holstered,dominant+" rejected drop release cannot equip or toggle")
		begin()
		rack.update_a_input(3.01,true,true,blocked_ray)
		finish(blocked_ray)
		check(rejected.attempts==attempts_before+2,dominant+" release and fresh A gesture rearms one new drop attempt")
	rack.inventory=null
	rejected.queue_free()
	var ground:=StaticBody3D.new()
	var ground_shape:=CollisionShape3D.new()
	var ground_box:=BoxShape3D.new()
	ground_box.size=Vector3(200,.2,200)
	ground_shape.shape=ground_box
	ground.add_child(ground_shape)
	ground.position.y=-.1
	root.add_child(ground)
	await physics_frame
	var inventory=load("res://scripts/weapon_inventory.gd").new()
	root.add_child(inventory)
	inventory.setup(actor,rack)
	check(rack.wheel.find_children("WeaponIcon*","Sprite3D",false,false).size()==3,"wheel renders only three carried weapon icons")
	check(not rack.select_weapon(1) and not rack.select_inventory_weapon(3),"unowned types cannot be selected through either rack path")
	rack.selected=0
	check(rack.next_owned_weapon()==2,"cycling skips unowned stable indices")
	for dominant in ["right","left"]:
		actor.dominant_hand=dominant
		rack._refresh_hands()
		if not inventory.has_weapon(2):inventory.pickup_weapon(2)
		rack.set_holstered(true)
		var ammo:int=rack.weapons[2].ammo
		begin()
		var slot:int=rack.wheel.SLOT_ACTIONS.find("weapon_2")
		var drop_ray:=sector(slot,2)
		rack.update_a_input(2.99,true,true,drop_ray)
		check(inventory.has_weapon(2) and rack.wheel._drop_ring.visible,dominant+" before3seconds item retained and nontext progressring visible")
		rack.update_a_input(.02,true,true,drop_ray)
		check(not inventory.has_weapon(2) and not rack.wheel._drop_ring.visible,dominant+" A3seconds drops highlighted actual item")
		var selected_after_drop:int=rack.selected
		finish(drop_ray)
		check(rack.selected==selected_after_drop and rack.is_holstered,dominant+" release after drop never equips or toggles")
		check(rack.weapons[2].ammo==ammo and inventory.pickups.has(2),dominant+" dropped persistent item preserves ammo and exists on ground")
		check(rack.wheel.find_children("WeaponIcon*","Sprite3D",false,false).size()==2,dominant+" drop clears carried icon")
		check(inventory.pickup_weapon(2),dominant+" grounded item can be picked back up into free carried slot")
		begin()
		var first:=sector(rack.wheel.SLOT_ACTIONS.find("weapon_2"),1)
		rack.update_a_input(2.0,true,true,first)
		var second:=sector(rack.wheel.SLOT_ACTIONS.find("weapon_4"),1)
		rack.update_a_input(1.5,true,true,second)
		check(inventory.has_weapon(2) and inventory.has_weapon(4),dominant+" changing highlighted item resets hold progress")
		finish(second)
		check(rack.selected==4,dominant+" short release still equips after highlight change")
		begin()
		var unavailable_slot:int=rack.wheel.BASE_ACTIONS.find("weapon_1")
		var unowned:=sector(unavailable_slot,2)
		finish(unowned)
		check(rack.selected==4,dominant+" unowned sector cancels without equipping another type")
	check(rack.wheel.find_children("*","Label3D",true,false).is_empty(),"progress ring adds no text nodes")
	for index in inventory.owned_indices():inventory.drop_weapon(index)
	begin();finish(opening)
	check(rack.is_holstered and rack.wheel.find_children("WeaponIcon*","Sprite3D",false,false).is_empty(),"empty inventory center tap cannot draw phantom weapon")
	var hidden:=true
	for gun in rack.weapons:hidden=hidden and not gun.visible
	check(hidden and rack.get_hand_grip_pose(actor.get_weapon_hand())==0,"empty inventory hides every weapon and releases held finger pose")
	inventory.queue_free()
	ground.queue_free()
	rack.shutdown()
	await create_timer(.15).timeout
	rack.queue_free();actor.queue_free()
	await process_frame
	print("WHEEL_041_RESULT passes=",passed," failures=",failed," headset_tested=false")
	quit(1 if failed else 0)


