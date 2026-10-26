extends Node3D
signal shot(origin:Vector3,direction:Vector3,damage:float)
signal pellet_shot(origin:Vector3,directions:Array[Vector3],damage:float)
signal feedback(text:String)
signal explosive_launch(spec:Dictionary)
signal melee_contact(target:Node3D,point:Vector3,amount:float,direction:Vector3)
signal backpack_requested
var weapons:Array=[]
var instance_catalog:Dictionary={}
var selected:=0
const INITIAL_RESERVES:Dictionary={"rifle":2400,"pistol":1200,"shells":480,"smg":1200,"sniper":2400,"frag":12,"zone":12}
const Arsenal=preload("res://scripts/arsenal_data.gd")
const AMMO_FAMILIES:Array[String]=["rifle","shells","pistol","rifle","shells","sniper","smg","pistol","rifle","shells","smg","smg","shells","sniper","melee","melee","melee","smg","smg","pistol","pistol","rifle","rifle","rifle","rifle","sniper","frag","rockets","zone","melee"]
const ACTIVE_WEAPON_INDICES:Array[int]=[0,1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,23,24,25,26,27,28,29]
const MAX_RESERVE:=0 #089 no gameplay cap
var reserves:Dictionary=INITIAL_RESERVES.duplicate()
var weapon_ids:Array[String]=["kestrel","cinder","meridian","vector3","furnace","longwatch","latch","cairn6","atlas","surge8","crest","twin_meridian","twin_matadors","spr","katana","excalibur","cyberblade","mp5","mp9","1911","tec9","akm","reserved_22","rfb","fal","s85","frag","smaw","zone","knife"]
var weapon_names:Array[String]=["CX4","DT11","PX4","MK18","RESERVED / INACTIVE","AWP","UMP","MAGNUM","M60","M1014","P90","DUAL UZIS","DUAL MATADORS","SPR","ASH KATANA","RIDGE EXCALIBUR","ARC CYBERBLADE","MP5","SILENCED MP9","1911","TEC9","AKM","RESERVED / INACTIVE","RFB","FAL","S85","FRAG","SMAW","ZONE GRENADE","FIELD KNIFE"]
var wheel_events:Array[Dictionary]=[]
var _wheel_log_count:=0
var is_holstered := false
var is_selecting := false
var construction_provider: Node
var consumable_provider:Node
var revive_provider:Node
var inventory: Node
var wheel: Node3D
var _a_previous := false
var _a_blocked := true
var _a_time := 0.0
var _a_gesture_seen := false
var _a_drop_index := -1
var _a_drop_time := 0.0
var _a_drop_consumed := false
var _a_drop_succeeded := false
const DROP_HOLD_SECONDS := 3.0
const QUICK_A_TAP_SECONDS := 0.10
const A_TIME_EPSILON := 0.0000001
var active_id:String:
	get:return weapon_ids[selected]
var weapon_name:String:
	get:return weapon_names[selected]
var player:Node3D
var _switch_previous:=true
var _draw_delay:=0.0
var ammo:int:
	get:return weapons[selected].ammo if not weapons.is_empty() else 0
var magazine_size:int:
	get:return weapons[selected].magazine_size if not weapons.is_empty() else 24
var reload_state:String:
	get:return weapons[selected].reload_state if not weapons.is_empty() else "ready"
var cooldown:float:
	get:return maxf(_draw_delay,weapons[selected].cooldown) if not weapons.is_empty() else 0.0
	set(value):
		if not weapons.is_empty():weapons[selected].cooldown=value
func setup(actor:Node3D)->void:
	player=actor
	player.set("sprint_conflict_provider",self)
	wheel=load("res://scripts/weapon_wheel.gd").new()
	wheel.set_meta("weapon_names",weapon_names);add_child(wheel)
	var catalog_paths:=["res://scripts/catalog_firearm.gd","res://scripts/dt11.gd","res://scripts/pistol.gd","res://scripts/burst_carbine.gd","res://scripts/pump_shotgun.gd","res://scripts/precision_rifle.gd","res://scripts/compact_smg.gd","res://scripts/revolver.gd","res://scripts/belt_lmg.gd","res://scripts/auto_shotgun.gd","res://scripts/top_feed_pdw.gd","res://scripts/dual_pistols.gd","res://scripts/dual_matadors.gd","res://scripts/spr.gd","res://scripts/melee_sword.gd","res://scripts/speed_sword.gd","res://scripts/energy_sword.gd","res://scripts/catalog_firearm.gd","res://scripts/catalog_firearm.gd","res://scripts/catalog_firearm.gd","res://scripts/catalog_firearm.gd","res://scripts/catalog_firearm.gd","res://scripts/inactive_weapon.gd","res://scripts/catalog_firearm.gd","res://scripts/catalog_firearm.gd","res://scripts/catalog_firearm.gd","res://scripts/explosive_weapon.gd","res://scripts/explosive_weapon.gd","res://scripts/explosive_weapon.gd","res://scripts/short_knife.gd"]
	for index in catalog_paths.size():
		var path:String=catalog_paths[index]
		var weapon=load(path).new()
		var profile:=Arsenal.profile(index)
		if path.ends_with("catalog_firearm.gd"):
			weapon.profile_id=profile.id;weapon.mode=profile.fire_mode
		elif path.ends_with("explosive_weapon.gd"):weapon.profile_id=profile.id
		add_child(weapon)
		weapon.setup(actor,false)
		Arsenal.apply(weapon,index)
		weapon.set_process_unhandled_input(false)
		# Existing rifle setup owns these connections; rack becomes sole dispatcher.
		if actor.is_connected("fired",weapon.fire):actor.disconnect("fired",weapon.fire)
		if actor.is_connected("reload_requested",weapon.desktop_reload_step):actor.disconnect("reload_requested",weapon.desktop_reload_step)
		weapon.feedback.connect(func(message:String):feedback.emit(message))
		weapon.ammo_provider=self
		weapon.ammo_slot=weapons.size()
		preload("res://scripts/common_reflex_090.gd").install(weapon,index)
		weapons.append(weapon)
	for weapon in weapons:_connect_weapon_events(weapon)
	wheel.set_weapon_icons(weapons)
	actor.connect("fired",fire)
	actor.connect("reload_requested",desktop_reload_step)
	_apply_selection()
	_draw_delay=0.0
	weapons[selected].cooldown=0.0
func _connect_weapon_events(weapon:Node3D)->void:
	preload("res://scripts/one_star0991.gd").apply(weapon)
	if weapon.has_signal("melee_contact"):weapon.melee_contact.connect(func(target:Node3D,point:Vector3,amount:float,direction:Vector3):melee_contact.emit(target,point,amount,direction))
	if weapon.has_signal("explosive_launch"):weapon.explosive_launch.connect(func(spec:Dictionary):explosive_launch.emit(spec))
	if weapon.has_signal("depleted"):weapon.depleted.connect(_consume_disposable.bind(weapons.find(weapon)))
	if weapon.has_signal("pellet_shot"):
		weapon.pellet_shot.connect(func(origin:Vector3,directions:Array[Vector3],damage:float):refresh_ammo_displays();pellet_shot.emit(origin,directions,damage))
	weapon.shot.connect(func(origin:Vector3,direction:Vector3,damage:float):refresh_ammo_displays();shot.emit(origin,direction,damage))
func _apply_selection()->void:
	if is_instance_valid(revive_provider) and is_instance_valid(consumable_provider) and not consumable_provider.selected_kind.is_empty():revive_provider.stow()
	if wheel and inventory!=null:wheel.set_owned_indices(inventory.owned_indices())
	for i in range(weapons.size()):
		var enabled:=has_weapon(i) and i==selected and not is_holstered and not is_selecting
		weapons[i].visible=enabled
		weapons[i].set_process(enabled)
		weapons[i].set_physics_process(enabled)
		if weapons[i].has_method("suspend_for_selection"):weapons[i].suspend_for_selection()
		else:weapons[i]._suspend_gestures()
		weapons[i]._sound.stop()
		for voice in weapons[i]._shot_voices:voice.stop()
	weapons[selected]._reserve_support_hand(not is_holstered and not is_selecting and reload_state!="ready")
	_draw_delay=0.25
	weapons[selected].cooldown=maxf(weapons[selected].cooldown,_draw_delay)
	_switch_previous=true
	refresh_ammo_displays()
func can_switch()->bool:
	return player.input_enabled and not is_selecting and not player.weapon_hand_climbing()
func select_weapon(index:int)->bool:
	if index<0 or index>=weapons.size() or not has_weapon(index) or index==selected or not can_switch():return false
	if player.xr_enabled:
		if not player.is_hand_input_ready(_support_hand()) or not player.is_hand_input_ready(_weapon_hand()):return false
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):return false
	_clear_consumable_selection()
	selected=index
	is_holstered=false
	_apply_selection()
	feedback.emit(weapon_name)
	return true
func select_inventory_weapon(index:int)->bool:
	# A closing inventory menu still owns input and may be holding its click/trigger.
	# Existing climb ownership still blocks equipping; reload mechanisms suspend safely.
	if index<0 or index>=weapons.size() or not has_weapon(index) or is_selecting:return false
	if player.weapon_hand_climbing():return false
	_clear_consumable_selection()
	selected=index
	is_holstered=false
	_apply_selection() # Suspends gestures and requires a fresh trigger press.
	feedback.emit(weapon_name)
	return true
func _process(delta:float)->void:
	refresh_ammo_displays()
	_refresh_hands()
	_draw_delay=maxf(0,_draw_delay-delta)
	if not player.input_enabled:
		cancel_selection()
		_switch_previous=true
		return
	if player.xr_enabled:
		if not player.is_hand_input_ready(_weapon_hand()) or not player.is_hand_input_ready(_support_hand()):
			cancel_selection()
			_switch_previous=true
			return
		update_a_input(delta, _weapon_hand().is_button_pressed("ax_button"), true, _pointer_transform())
		# B/Y is reserved for team_marks; A retains inventory switching.
	# Draw delay also gates autonomous VR input in active concrete weapon.
	if _draw_delay>0:weapons[selected].cooldown=maxf(weapons[selected].cooldown,_draw_delay)
func _unhandled_input(event:InputEvent)->void:
	if player==null or player.xr_enabled or not event is InputEventKey or not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_1:select_weapon(0)
		KEY_2:select_weapon(1)
		KEY_3:select_weapon(2)
		KEY_4:select_weapon(3)
		KEY_5:select_weapon(4)
		KEY_Q:select_weapon(next_owned_weapon())
func has_weapon(index:int)->bool:
	return ACTIVE_WEAPON_INDICES.has(catalog_index(index)) and (inventory==null or inventory.has_weapon(index))
func is_catalog_active(index:int)->bool:return ACTIVE_WEAPON_INDICES.has(catalog_index(index))
func next_owned_weapon()->int:
	for offset in range(1,weapons.size()+1):
		var index: int=(selected+offset)%weapons.size()
		if has_weapon(index):return index
	return selected
func fire()->void:
	if is_instance_valid(revive_provider) and revive_provider.active:
		revive_provider.desktop_discharge();return
	if has_weapon(selected) and _draw_delay<=0 and player.input_enabled and not is_holstered and not is_selecting:weapons[selected].fire()
func desktop_reload_step()->void:
	if has_weapon(selected) and _draw_delay<=0 and player.input_enabled and not is_holstered and not is_selecting:weapons[selected].desktop_reload_step()
func eject_magazine()->void:
	if has_weapon(selected) and player.input_enabled and not is_holstered and not is_selecting:weapons[selected].eject_magazine()
func reset_weapon()->void:
	reserves=INITIAL_RESERVES.duplicate()
	cancel_selection()
	is_holstered=false
	for index in weapons.size():
		weapons[index].reset_weapon();Arsenal.apply(weapons[index],index)
	_apply_selection()
func set_weapon_settings(settings:Dictionary)->void:
	_refresh_hands()
	for weapon in weapons:weapon.set_weapon_settings(settings)
func get_reload_hint()->String:
	if selected!=1:return ""
	if not player.xr_enabled:
		return {"ready":"R opens the breech.","open_empty":"R seats the shell pair.","holding_shells":"R seats the shell pair.","open_loaded":"R closes and latches the barrel."}.get(reload_state,"")
	return weapons[selected].get_reload_hint()
func shutdown()->void:
	if is_instance_valid(player) and player.get("sprint_conflict_provider")==self:player.set("sprint_conflict_provider",null)
	for weapon in weapons:weapon.shutdown()

func _pointer_transform() -> Transform3D:
	if weapons[0].has_method("corrected_grip_transform"):
		return weapons[0].corrected_grip_transform(_weapon_hand().global_transform)
	return _weapon_hand().global_transform * Transform3D(Basis(Vector3.RIGHT,-PI/2.0),Vector3.ZERO)

func set_holstered(value: bool) -> void:
	var was_holstered:=is_holstered
	if not value:_clear_consumable_selection()
	if not value and player.weapon_hand_climbing():return
	is_holstered=value or not has_weapon(selected)
	_apply_selection()
	if was_holstered!=is_holstered and player.input_enabled:preload("res://scripts/sound_cues099.gd").play_ui(self,"item_stow" if is_holstered else "item_equip")
	feedback.emit("HOLSTERED" if value else weapon_name)
	_record_wheel_event("holstered" if value else "drawn")

func cancel_selection() -> void:
	var was_selecting := is_selecting
	is_selecting=false
	_a_blocked=true
	_a_previous=false
	_a_time=0.0
	_a_gesture_seen=false
	_a_drop_index=-1
	_a_drop_time=0
	_a_drop_consumed=false
	_a_drop_succeeded=false
	if wheel:wheel.set_drop_progress(-1,0)
	if wheel: wheel.hide()
	if was_selecting: _apply_selection()

func _wheel_locomotion_origin()->Vector3:
	return player.get_locomotion_anchor_position() if player.has_method("get_locomotion_anchor_position") else player.global_position

func update_a_input(delta: float, pressed: bool, valid: bool, ray: Transform3D) -> void:
	if is_selecting:wheel.follow_player_translation(_wheel_locomotion_origin())
	if not valid or not player.input_enabled or player.inventory_open:
		cancel_selection()
		return
	if _a_blocked:
		if not pressed: _a_blocked=false
		return
	if pressed:
		if not _a_previous:
			_a_time=0.0
			_a_gesture_seen=false
			_a_drop_index=-1
			_a_drop_time=0
			_a_drop_consumed=false
			_a_drop_succeeded=false
		_a_time+=maxf(0.0,delta)
		if not is_selecting and _a_time>QUICK_A_TAP_SECONDS+A_TIME_EPSILON:
			is_selecting=true
			wheel.open_at(player.get_view_camera().global_transform, ray, _wheel_locomotion_origin())
			_record_wheel_event("opened")
			_apply_selection()
		if is_selecting:
			wheel.point(ray)
			if wheel.highlighted>=0: _a_gesture_seen=true
			if not _a_drop_consumed:
				var drop_index:int=wheel.weapon_index_at_slot(wheel.SLOT_ACTIONS,wheel.highlighted)
				if drop_index!=_a_drop_index:
					_a_drop_index=drop_index
					_a_drop_time=0
				if drop_index>=0 and inventory!=null and has_weapon(drop_index) and reload_state in ["ready","needs_mag"] and not player.climbing_left and not player.climbing_right:
					_a_drop_time+=maxf(0,delta)
					wheel.set_drop_progress(wheel.highlighted,_a_drop_time/DROP_HOLD_SECONDS)
					if _a_drop_time>=DROP_HOLD_SECONDS:
						# A deliberate drop attempt owns this gesture even when safe
						# placement rejects it. Never retry or equip on its release.
						_a_drop_consumed=true
						_a_drop_succeeded=inventory.drop_weapon(drop_index)
						wheel.set_drop_progress(-1,0)
				else:wheel.set_drop_progress(-1,0)
			var action: String = wheel.point_action()
			wheel.set_status("HOLSTER FIRING HAND FIRST" if player.weapon_hand_climbing() else ("RELEASE TO EQUIP PADDLES" if action=="revive" else ("EMPTY SLOT" if action=="empty" else ("RELEASE TO CANCEL" if action=="cancel" else "RELEASE TO SELECT"))))
	elif _a_previous:
		# A rapid tap belongs only to the held item, regardless of aim drift.
		if _a_time<=QUICK_A_TAP_SECONDS+A_TIME_EPSILON:
			toggle_selected_item()
			_record_wheel_event("quick_toggle")
		elif is_selecting:
			var index: int=wheel.point(ray)
			var action: String=wheel.point_action()
			if wheel.highlighted>=0: _a_gesture_seen=true
			if index<0:_record_wheel_event("released_outside")
			is_selecting=false
			wheel.hide()
			wheel.set_drop_progress(-1,0)
			if _a_drop_consumed:
				_record_wheel_event("dropped" if _a_drop_succeeded else "drop_rejected")
			elif action=="cancel":
				pass # A long hold released at the center cancels the wheel.
			elif action.begins_with("consumable:"):
				if not player.weapon_hand_climbing() and is_instance_valid(consumable_provider):consumable_provider.equip_instance(action.trim_prefix("consumable:"))
			elif action=="backpack":
				backpack_requested.emit()
				_record_wheel_event("backpack")
			elif action=="revive":
				if is_instance_valid(revive_provider):revive_provider.equip()
				_record_wheel_event("revive")
			elif index==selected:
				if not player.weapon_hand_climbing():
					_clear_consumable_selection();is_holstered=false
			elif index>=0:
				if not select_weapon(index):
					feedback.emit("FIRING HAND IS CLIMBING")
					_record_wheel_event("selection_blocked")
				else:_record_wheel_event("selected")
			_apply_selection()
		_a_time=0.0
	_a_previous=pressed
func _weapon_hand() -> XRController3D:
	return player.get_weapon_hand() if player.has_method("get_weapon_hand") else player.get("right_hand")
func _support_hand() -> XRController3D:
	return player.get_support_hand() if player.has_method("get_support_hand") else player.get("left_hand")
func _refresh_hands() -> void:
	var changed:=false
	for weapon in weapons:
		if weapon.refresh_hands():changed=true
	if changed:
		cancel_selection()
		_apply_selection()


func blocks_sprint() -> bool:
	# Pure same-frame intent query; never depends on the later support reservation update.
	if is_selecting:return true
	if is_holstered or weapons.is_empty():return false
	var active:Node3D=weapons[selected]
	if active.has_method("blocks_sprint"):return active.blocks_sprint()
	if active.reload_state!="ready" or active.supported:return true
	var firing:XRController3D=_weapon_hand()
	if firing.get_float("trigger")>0.1 or firing.is_button_pressed("trigger_click"):return true
	var support:XRController3D=_support_hand()
	if support==player.get("left_hand") and (support.get_float("grip")>0.55 or support.is_button_pressed("grip_click")):
		return support.global_position.distance_to(active.to_global(Vector3(0,-0.025,-0.36)))<0.28
	return false


func _record_wheel_event(event:String)->void:
	var entry:Dictionary={"event":event,"ms":Time.get_ticks_msec(),"weapon":active_id,"reload":reload_state,"hand":str(player.get("dominant_hand")),"grip":_weapon_hand().get_float("grip"),"trigger":_weapon_hand().get_float("trigger")}
	wheel_events.append(entry)
	if wheel_events.size()>32:wheel_events.pop_front()
	if _wheel_log_count<64:
		print("WHEEL_EVENT ",JSON.stringify(entry))
		_wheel_log_count+=1

func get_weapon_label(index:int)->String:
	return weapon_names[index] if index>=0 and index<weapon_names.size() else "EMPTY"

func get_hand_grip_pose(hand:XRController3D)->float:
	if is_instance_valid(revive_provider) and revive_provider.active:return 1.0
	if is_holstered or is_selecting or weapons.is_empty() or not has_weapon(selected):return 0.0
	if weapons[selected].has_method("is_hand_holding_weapon"):
		return 1.0 if weapons[selected].is_hand_holding_weapon(hand) else 0.0
	if hand==_weapon_hand():return 1.0
	if hand==_support_hand() and weapons[selected].supported:return 1.0
	return 0.0

func get_ammo_display_state(index:int)->Dictionary:
	if index<0 or index>=weapons.size():return {"loaded":0,"reserve":0}
	if catalog_index(index)==27:return {"loaded":weapons[index].ammo,"reserve":weapons[index].rocket_reserve}
	if AMMO_FAMILIES[catalog_index(index)]=="melee":return {"loaded":0,"reserve":0,"kind":"melee"}
	return {"loaded":weapons[index].get_loaded_rounds(),"reserve":int(reserves[AMMO_FAMILIES[catalog_index(index)]])}
func consume_weapon_reserve(index:int,requested:int)->int:
	if index<0 or index>=weapons.size():return 0
	if catalog_index(index)==27:return weapons[index].take_reserve(requested)
	return consume_reserve(AMMO_FAMILIES[catalog_index(index)],requested)
func refund_weapon_reserve(index:int,requested:int)->int:
	if index<0 or index>=weapons.size():return 0
	return add_reserve(AMMO_FAMILIES[catalog_index(index)],requested)
func consume_reserve(family:String,requested:int)->int:
	if not reserves.has(family):return 0
	var amount:=mini(maxi(requested,0),int(reserves[family]))
	reserves[family]-=amount
	refresh_ammo_displays()
	return amount
func add_reserve(family:String,amount:int)->int:
	if not reserves.has(family):return 0
	var credited:=maxi(amount,0)
	reserves[family]+=credited
	refresh_ammo_displays()
	return credited
func refresh_ammo_displays()->void:
	for weapon in weapons:weapon.update_ammo_display()




func reload_claims_hand(hand:Node3D)->bool:
	if is_holstered or is_selecting or weapons.is_empty() or not has_weapon(selected):return false
	return weapons[selected].reload_claims_hand(hand)
func is_hand_holding_weapon(hand:Node3D)->bool:
	if is_holstered or weapons.is_empty() or not has_weapon(selected):return false
	var active:Node3D=weapons[selected]
	if active.has_method("is_hand_holding_weapon"):return active.is_hand_holding_weapon(hand)
	return hand==_weapon_hand() or (hand==_support_hand() and active.supported)

func _consume_disposable(index:int)->void:
	# Transfer ownership after the firing stack completes; no duplicate empty prop.
	if inventory!=null and inventory.has_method("consume_disposable"):inventory.consume_disposable.call_deferred(index)

func get_ground_speed_gain(sprint_gain:float)->float:
	# Original stacking policy: take the faster bonus; shield slowdown overrides sprint.
	if is_holstered or is_selecting or weapons.is_empty():return sprint_gain
	var active:Node3D=weapons[selected]
	if not active.has_method("get_movement_multiplier"):return sprint_gain
	var equipment:float=active.get_movement_multiplier()
	return equipment if equipment<1.0 else maxf(sprint_gain,equipment)
func intercept_bullet(origin:Vector3,endpoint:Vector3)->Dictionary:
	if is_holstered or is_selecting or weapons.is_empty() or not has_weapon(selected):return {}
	var active:Node3D=weapons[selected]
	return active.intercept_bullet(origin,endpoint) if active.has_method("intercept_bullet") else {}
func is_melee_selected()->bool:
	return not weapons.is_empty() and weapons[selected].has_method("sample_motion")

func toggle_selected_item()->void:
	if is_instance_valid(revive_provider) and revive_provider.selected:
		revive_provider.toggle();return
	if is_instance_valid(consumable_provider) and not consumable_provider.selected_kind.is_empty():
		if not player.weapon_hand_climbing():consumable_provider.toggle_selected()
		return
	set_holstered(not is_holstered)

func _clear_consumable_selection()->void:
	if is_instance_valid(revive_provider):revive_provider.stow()
	if is_instance_valid(consumable_provider):
		consumable_provider.stow();consumable_provider.selected_kind="";consumable_provider.selected_instance=""

func catalog_index(instance:int)->int:return int(instance_catalog.get(instance,instance))
func create_instance(catalog:int)->int:
	if not ACTIVE_WEAPON_INDICES.has(catalog):return -1
	var source:Node3D=weapons[catalog]
	var gun=source.get_script().new()
	var profile:=Arsenal.profile(catalog)
	if "profile_id" in gun:gun.profile_id=profile.id
	if "mode" in gun:gun.mode=profile.fire_mode
	add_child(gun);gun.setup(player,false);Arsenal.apply(gun,catalog)
	var id:=weapons.size();instance_catalog[id]=catalog
	weapons.append(gun);weapon_ids.append(weapon_ids[catalog]);weapon_names.append(weapon_names[catalog])
	gun.set_weapon_settings({"motion_damping":source.motion_damping,"offhand_influence":source.offhand_influence,"grip_toggle":source.grip_toggle})
	gun.ammo_provider=self;gun.ammo_slot=id;gun.set_meta("catalog_index",catalog)
	gun.feedback.connect(func(message:String):feedback.emit(message));_connect_weapon_events(gun)
	preload("res://scripts/common_reflex_090.gd").install(gun,catalog)
	gun.hide();gun.set_process(false);gun.set_physics_process(false);gun.set_process_unhandled_input(false)
	return id

