extends Node3D
var network_bridge:Node
## Original authored props and finite pouch. Values/gesture tolerances are documented
## ASHFALL defaults, not claims of exact Population: One interaction parity.
signal changed
signal feedback(message:String)
const KINDS:Array[String]=["shaker","soda","banana"]
const TITLES:Dictionary={"shaker":"SHIELD SHAKER","soda":"SHIELD SODA","banana":"BANANA"}
const INITIAL_CAPACITY:=3
const MAX_CAPACITY:=6
const MAX_STACK:=2
const INITIAL_STOCK:Dictionary={"shaker":0,"soda":0,"banana":0}
const SODA_AMOUNT:=50.0
const SODA_SECONDS:=10.0
const SHAKER_AMOUNT:=50.0
const BANANA_AMOUNT:=100.0
const SHAKE_CHARGE_RATE:=1.3 #072: 30% faster rate, not a measured reference duration
const SHAKE_DISTANCE:=1.8
const SHAKE_REVERSALS:=6
const SHAKE_SECONDS:=3.0
const CONSUME_HEADSET_RADIUS_M:=0.45
var actor:Node3D
var rack:Node
var game:Node
var capacity:=INITIAL_CAPACITY
var stock:Dictionary=INITIAL_STOCK.duplicate()
var items:Dictionary={}
var selected_instance:=""
var _next_instance:=0
var peel_count:=0
var _peel_active:=false
var _peel_start:=Vector3.ZERO
var _last_shake_motion:=Vector3.ZERO
var pickups:Array[Node3D]=[]
var held_kind:=""
var held_hand:Node3D
var held_prop:Node3D
var phase:="idle"
var soda_left:=0.0
var _shake_distance:=0.0
var _reversals:=0
var _shake_seconds:=0.0
var _previous_sign:=0
var _previous_local:=Vector3.ZERO
var _have_sample:=false
var _mouth_time:=0.0
var _use_previous:=true
var selected_kind:=""
var saved_states:Dictionary={}
var audio_events:Array[String]=[]
var aim_rings:Dictionary={}
var _audio:AudioStreamPlayer3D
var _shake_audio_clock:=0.0
var _shake_voice0992:AudioStreamPlayer3D
var _shake_motion_left0992:=0.0
var _pouch:Node3D
var _pouch_labels:Array[Label3D]=[]

func setup(player:Node3D,weapon_rack:Node,game_node:Node)->void:
	actor=player; rack=weapon_rack; game=game_node
	_build_pouch()
	_audio=AudioStreamPlayer3D.new();_audio.bus="SFX";_audio.volume_db=-12;_audio.max_distance=12;add_child(_audio)
	if "consumable_provider" in rack:
		rack.consumable_provider=self;rack.wheel.consumable_provider=self
		changed.connect(func():rack._apply_selection())
	reset_supplies(actor.global_position)

func reset_supplies(origin:Vector3)->void:
	stow();items.clear();selected_instance="";saved_states.clear();selected_kind=""; capacity=INITIAL_CAPACITY; stock=INITIAL_STOCK.duplicate(); soda_left=0
	for prop in pickups:prop.queue_free()
	pickups.clear()
	# Spread beyond the gun row. Hovered, collision-free props never obstruct climbing.
	for i in range(12):
		var kind:String=KINDS[i%3] if i<9 else "backpack"
		var prop:=make_prop(kind)
		prop.set_meta("kind",kind); prop.set_meta("taken",false)
		add_child(prop); prop.global_position=origin+Vector3(-3.4+(i%4)*.65,.75,1.8+floori(i/4.0)*.65)
		pickups.append(prop)
		if is_instance_valid(rack.inventory):rack.inventory._settle_pickup_id.call_deferred(prop.get_instance_id())
	_refresh_pouch(); changed.emit()

func total_items()->int:
	var total:=0
	for kind in KINDS:total+=int(stock.get(kind,0))
	return total

func collect(index:int)->bool:
	if network_bridge!=null and network_bridge.live() and not network_bridge.applying:return network_bridge.gateway("heal_pickup",index)
	if index<0 or index>=pickups.size():return false
	var prop:=pickups[index]
	if prop.get_meta("taken",false):return false
	var kind:String=prop.get_meta("kind")
	if kind=="backpack":
		if rack.inventory.capacity>=MAX_CAPACITY:return false
		rack.inventory.capacity+=1;capacity=rack.inventory.capacity; feedback.emit("BACKPACK | POUCH %d"%capacity)
	else:
		if not rack.inventory.make_room("kind:"+kind):return false
		stow()
		var id:String=str(prop.get_meta("item_id",""))
		if id.is_empty():id="supply_%d"%_next_instance;_next_instance+=1
		items[id]={"kind":kind};prop.set_meta("item_id",id)
		selected_instance=id;stock[kind]=int(stock.get(kind,0))+1; feedback.emit(TITLES[kind]+" COLLECTED")
	_play_cue("pickup");prop.set_meta("taken",true); prop.hide(); _refresh_pouch(); changed.emit(); return true

func equip(kind:String,hand:Node3D=null)->bool:
	for id in items:
		if items[id].kind==kind:return equip_instance(str(id),hand)
	return false
func equip_instance(id:String,hand:Node3D=null)->bool:
	if not items.has(id):return false
	stow();selected_instance=id
	return _equip_kind(str(items[id].kind),hand)
func _equip_kind(kind:String,hand:Node3D=null)->bool:
	if not kind in KINDS or int(stock.get(kind,0))<=0 or not _allowed():return false
	stow()
	held_kind=kind; selected_kind=kind; held_hand=hand
	if held_hand==null and actor.xr_enabled:held_hand=actor.get_weapon_hand()
	if actor.xr_enabled and (not is_instance_valid(held_hand) or not actor.is_hand_tracked(held_hand)):
		held_kind=""; held_hand=null; return false
	rack.is_holstered=true
	if rack.has_method("_apply_selection"):rack._apply_selection()
	held_prop=make_prop(kind); add_child(held_prop)
	phase="shake" if kind=="shaker" else "open"
	_shake_distance=0; _reversals=0; _shake_seconds=0; _previous_sign=0; _have_sample=false; _mouth_time=0; _use_previous=true;peel_count=0;_peel_active=false
	_play_cue("equip")
	feedback.emit(TITLES[kind]+" | "+("SHAKE THEN DRINK" if kind=="shaker" else ("PEEL THEN EAT" if kind=="banana" else "OPEN THEN DRINK")))
	return true

func stow(play_sound:bool=true)->void:
	if _shake_voice0992:_shake_voice0992.stop()
	if play_sound and not held_kind.is_empty() and is_instance_valid(actor) and actor.input_enabled and not game.paused and not game.dead:
		_play_cue("stow")
	saved_states.erase(selected_instance) # Preparation always resets on stow / redraw.
	if is_instance_valid(held_prop):held_prop.queue_free()
	held_prop=null; held_hand=null; held_kind=""; phase="idle"; _have_sample=false; _mouth_time=0; _use_previous=true

func hand_holds_item(hand:Node3D)->bool:
	return not held_kind.is_empty() and hand==held_hand

func _allowed()->bool:
	return is_instance_valid(actor) and is_instance_valid(game) and actor.input_enabled and actor.get("inventory_open")!=true and actor.tracking_available and not actor.head_obstructed and not game.paused and not game.dead and not game.complete

func _build_pouch()->void:
	_pouch=Node3D.new(); _pouch.name="ConsumablePouch"; add_child(_pouch);_pouch.hide()
	for i in range(3):
		var prop:=make_prop(KINDS[i]); prop.position=Vector3((i-1)*.19,0,0); prop.scale=Vector3.ONE*.65; _pouch.add_child(prop)
		var label:=Label3D.new(); label.font_size=30; label.pixel_size=.0018; label.outline_size=5
		label.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y; label.position=prop.position+Vector3(0,.18,0); _pouch.add_child(label); _pouch_labels.append(label)

func _refresh_pouch()->void:
	for i in range(_pouch_labels.size()):_pouch_labels[i].text="%s x%d"%[TITLES[KINDS[i]],stock[KINDS[i]]]

func get_grip_targets()->Array:
	var result:Array=[]
	if not _allowed() or not actor.xr_enabled:return result
	if "is_selecting" in rack and rack.is_selecting:return result
	for hand in [actor.left_hand,actor.right_hand]:
		if not actor.is_hand_input_ready(hand) or actor._grabs.has(hand):continue
		if not held_kind.is_empty():
			if hand!=held_hand and phase=="open":result.append({"id":"consumable:open","position":held_prop.global_position+held_prop.global_basis.y*.10,"hand":hand})
		# Ordinary aimed pickups use the same transfer/reload ownership gates as guns.
		if "inventory" in rack and is_instance_valid(rack.inventory):
			if not rack.inventory._hand_eligible(hand) or not rack.inventory._transfer_safe(rack.selected):continue
		for i in range(pickups.size()):
			if not pickups[i].get_meta("taken",false) and _pickup_reachable(hand,pickups[i].global_position):result.append({"id":"consumable:pickup:%d"%i,"position":pickups[i].global_position,"hand":hand,"reach":2.0})
	return result

func handle_grip(id:String,hand:Node3D)->bool:
	if not _allowed():return false
	var valid:=false
	for target in get_grip_targets():
		if target.id==id and target.hand==hand and hand.global_position.distance_to(target.position)<=float(target.get("reach",.35)):valid=true;break
	if not valid:return false
	if id=="consumable:open":
		if held_kind=="banana":_peel_start=held_prop.to_local(hand.global_position);_peel_active=true;return true
		return open_item()
	if id.begins_with("consumable:pickup:"):
		var index:=int(id.trim_prefix("consumable:pickup:"))
		if not collect(index):return false
		var kind:String=pickups[index].get_meta("kind")
		if kind in KINDS:equip_instance(str(pickups[index].get_meta("item_id")),hand)
		return true
	if id.begins_with("consumable:equip:"):return equip(id.trim_prefix("consumable:equip:"),hand)
	return false

func open_item()->bool:
	if phase!="open":return false
	if held_kind=="banana" and peel_count<4:return false
	phase="consume"; _mouth_time=0;_play_cue("open")
	if held_prop:
		held_prop.set_meta("opened",true)
		if held_prop.has_node("Cap"):held_prop.get_node("Cap").hide()
	feedback.emit("EAT" if held_kind=="banana" else "DRINK")
	return true

func sample_shake(local_position:Vector3,delta:float)->void:
	if phase!="shake" or delta<=0 or not local_position.is_finite():return
	if _have_sample:
		var motion:=local_position-_previous_local
		var travel:=motion.length();var speed:=travel/delta
		if speed>=.45 and speed<=8 and travel<.3:
			_shake_sound0992()
			_shake_distance+=travel*SHAKE_CHARGE_RATE;_shake_seconds+=minf(delta,.1)*SHAKE_CHARGE_RATE
			if _last_shake_motion!=Vector3.ZERO and motion.normalized().dot(_last_shake_motion)<-.4:_reversals+=1
			_last_shake_motion=motion.normalized()

	_previous_local=local_position; _have_sample=true
	if _shake_distance>=SHAKE_DISTANCE and float(_reversals)*SHAKE_CHARGE_RATE>=SHAKE_REVERSALS and _shake_seconds>=SHAKE_SECONDS:_ready_to_drink()

static func within_headset_reach(item_position:Vector3,headset_position:Vector3)->bool:
	# One micrometre accommodates Vector3 float rounding at the inclusive boundary.
	return item_position.is_finite() and headset_position.is_finite() and item_position.distance_squared_to(headset_position)<=pow(CONSUME_HEADSET_RADIUS_M+0.000001,2)

static func within_consumption_volume(point:Vector3,head:Transform3D,_kind:String)->bool:
	if not point.is_finite() or not head.is_finite():return false
	# Modest extension of the original 45cm reach; instant valid contact remains.
	var p:Vector3=head.affine_inverse()*point
	return within_headset_reach(point,head.origin) or (absf(p.x)<=.25 and p.y>=-.35 and p.y<=.12 and p.z>=-.50 and p.z<=.05)

func consume_at_mouth(delta:float,near_mouth:bool,tilted:bool)->bool:
	if phase!="consume":return false
	if not near_mouth or (held_kind!="banana" and not tilted):_mouth_time=0;return false
	_mouth_time+=maxf(delta,0)
	#089 consume on the first valid contact frame; no hidden dwell timer.
	var kind:=held_kind
	if (kind=="banana" and game.health>=100 and float(actor.get("_sprint_stamina"))>=float(actor.get("sprint_stamina_seconds"))) or (kind!="banana" and game.shield>=100):return false
	if int(stock.get(kind,0))<=0:stow(false);return false
	if network_bridge!=null and network_bridge.live() and not network_bridge.applying:return network_bridge.gateway("consume",selected_instance)
	var consumed_id:=selected_instance
	var remaining:Array=rack.inventory.stack_members("consumable:"+consumed_id)
	remaining.erase("consumable:"+consumed_id)
	stock[kind]-=1
	items.erase(consumed_id)
	if kind=="banana":
		game.health=minf(100,game.health+BANANA_AMOUNT)
		actor.set("_sprint_stamina",float(actor.get("sprint_stamina_seconds")))
	elif kind=="shaker":game.shield=minf(100,game.shield+SHAKER_AMOUNT)
	else:soda_left+=SODA_AMOUNT
	_play_cue("drink");stow(false);saved_states.erase(consumed_id);selected_kind="";selected_instance="";_refresh_pouch()
	if not remaining.is_empty():equip_instance(str(remaining[0]).trim_prefix("consumable:"))
	changed.emit();return true

func _process(delta:float)->void:
	if not is_instance_valid(actor):return
	_shake_motion_left0992=maxf(0,_shake_motion_left0992-delta)
	if _shake_voice0992:
		_shake_voice0992.stream_paused=_shake_motion_left0992<=0
		if is_instance_valid(held_prop):_shake_voice0992.global_position=held_prop.global_position
	_update_pickup_rings()
	if not _allowed():
		stow()
		if _pouch:_pouch.hide()
		return
	var camera:Camera3D=actor.get_view_camera()
	var flat:Vector3=-camera.global_basis.z; flat.y=0
	if flat.length_squared()<.001:flat=Vector3.FORWARD
	_pouch.global_position=actor.global_position+flat.normalized()*.28+Vector3.UP*.85
	_pouch.global_rotation.y=atan2(flat.x,flat.z)
	_pouch.visible=false
	if soda_left>0:
		var portion:=minf(soda_left,maxf(delta,0)*SODA_AMOUNT/SODA_SECONDS)
		soda_left-=portion;game.shield=minf(100,game.shield+portion)
	if held_kind.is_empty():return
	if not rack.is_holstered:stow();return
	if "is_selecting" in rack and rack.is_selecting:
		held_prop.hide();_have_sample=false;_mouth_time=0;return
	held_prop.show()
	if actor.xr_enabled:
		if not actor.is_hand_input_ready(held_hand):held_prop.hide();_have_sample=false;_peel_active=false;return
		held_prop.global_transform=preload("res://scripts/weapon.gd").corrected_grip_transform(held_hand.global_transform).translated_local(held_offset(held_kind))
		sample_shake(actor.to_local(held_hand.global_position),delta)
		if held_kind=="banana":
			var other:Node3D=actor.left_hand if held_hand==actor.right_hand else actor.right_hand
			sample_peel(held_prop.to_local(other.global_position),other.get_float("grip")>.55,actor.is_hand_input_ready(other))
		_update_preparation_visual()
		consume_at_mouth(delta,within_consumption_volume(consumption_anchor(),camera.global_transform,held_kind),held_prop.global_basis.y.dot(Vector3.UP)<.75)
	else:
		held_prop.global_transform=camera.global_transform.translated_local(Vector3(.20,-.18,-.38)+held_offset(held_kind))
		var pressed:=Input.is_physical_key_pressed(KEY_E)
		if pressed and not _use_previous:
			if phase=="shake":
				_reversals+=2;_shake_distance+=.6*SHAKE_CHARGE_RATE
			elif phase=="open":
				if held_kind=="banana":peel_count=mini(4,peel_count+1)
				open_item();_update_preparation_visual()
		if pressed and phase=="shake":
			_shake_sound0992()
			_shake_seconds+=maxf(delta,0)*SHAKE_CHARGE_RATE
			if _reversals>=SHAKE_REVERSALS and _shake_seconds>=SHAKE_SECONDS:_ready_to_drink()
		_use_previous=pressed
		_update_preparation_visual()
		if pressed:consume_at_mouth(delta,true,true)

func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo or not _allowed() or actor.xr_enabled:return
	if event.physical_keycode==KEY_7:equip("shaker")
	elif event.physical_keycode==KEY_8:equip("soda")
	elif event.physical_keycode==KEY_9:equip("banana")
	elif event.physical_keycode==KEY_0:stow()
	elif event.physical_keycode==KEY_J and rack.is_holstered:
		var camera:Camera3D=actor.get_view_camera()
		for i in range(pickups.size()):
			if camera.global_position.distance_to(pickups[i].global_position)<2 and collect(i):break

static func make_prop(kind:String)->Node3D:
	return preload("res://scripts/field_item_models.gd").consumable(kind,TITLES)

func toggle_selected()->bool:
	if selected_kind.is_empty():return false
	if not held_kind.is_empty():stow();return true
	return equip_instance(selected_instance)

func _pickup_reachable(hand:Node3D,point:Vector3)->bool:
	var offset:=point-hand.global_position
	if offset.length()>2.0:return false
	var forward:Vector3=-preload("res://scripts/weapon.gd").corrected_grip_transform(hand.global_transform).basis.z.normalized()
	if offset.length()>.35 and forward.dot(offset.normalized())<=.94:return false
	if "inventory" in rack and is_instance_valid(rack.inventory):
		return rack.inventory._line_clear(actor.get_view_camera().global_position,hand.global_position) and rack.inventory._line_clear(hand.global_position,point)
	return offset.length()<=.35

func _ready_to_drink()->void:
	if phase!="shake":return
	if _shake_voice0992:_shake_voice0992.stop()
	phase="consume";_mouth_time=0;_play_cue("ready");feedback.emit("SHAKER READY | DRINK")

func _shake_sound0992()->void:
	_shake_motion_left0992=.20
	if _shake_voice0992==null:
		_shake_voice0992=AudioStreamPlayer3D.new();_shake_voice0992.bus="SFX";_shake_voice0992.volume_db=-12;_shake_voice0992.max_distance=8;add_child(_shake_voice0992)
	_shake_voice0992.stream_paused=false
	if not _shake_voice0992.playing:
		_shake_voice0992.stream=AshAudioBank.for_action("shaker","consume_shake",0);_shake_voice0992.play()

func _play_cue(event:String)->void:
	audio_events.append(event)
	if audio_events.size()>64:audio_events.pop_front()
	if not is_instance_valid(_audio):return
	var kind:String={"open":"consume_open","drink":"consume_drink","shake":"consume_shake","ready":"consume_ready","pickup":"ammo_pickup","equip":"item_equip","stow":"item_stow"}.get(event,"item_equip")
	if event in ["pickup","equip","stow"]:
		preload("res://scripts/sound_cues099.gd").play_ui(self,kind);return
	_audio.stream=AshAudioBank.for_action(held_kind,kind,audio_events.size())
	_audio.global_position=held_prop.global_position if is_instance_valid(held_prop) else actor.global_position
	_audio.play()

func _update_pickup_rings()->void:
	if not "inventory" in rack or not is_instance_valid(rack.inventory):return
	for hand in [actor.left_hand,actor.right_hand]:
		if not is_instance_valid(hand):continue
		if not aim_rings.has(hand):
			var ring:Node3D=rack.inventory._create_aim_ring(hand);ring.reparent(self);aim_rings[hand]=ring
		aim_rings[hand].hide()
	var targets:=get_grip_targets()
	for hand in aim_rings:
		var best:Dictionary={};var distance:=INF
		for target in targets:
			if target.hand!=hand or not str(target.id).begins_with("consumable:pickup:"):continue
			var d:float=hand.global_position.distance_to(target.position)
			if d<distance:distance=d;best=target
		if best.is_empty():continue
		var ring:Node3D=aim_rings[hand];ring.global_position=best.position
		ring.global_basis=preload("res://scripts/upright_ui.gd").view_basis(actor.get_view_camera().global_basis);ring.show()
		var prop:Node3D=pickups[int(str(best.id).trim_prefix("consumable:pickup:"))]
		ring.get_node("TargetName").text=TITLES.get(prop.get_meta("kind"),"BACKPACK +1 SLOT")

func drop_selected()->bool:return drop_instance(selected_instance)
func drop_instance(id:String)->bool:
	if network_bridge!=null and network_bridge.live() and not network_bridge.applying:return network_bridge.gateway("drop_heal",id)
	if not items.has(id):return false
	var kind:String=items[id].kind
	var prop:=make_prop(kind);add_child(prop)
	if not rack.inventory._place_reachable_drop(prop):prop.free();return false
	if selected_instance==id:stow();selected_kind="";selected_instance=""
	prop.set_meta("kind",kind);prop.set_meta("taken",false);prop.set_meta("item_id",id);pickups.append(prop)
	items.erase(id);stock[kind]-=1;changed.emit();return true

func sample_peel(local:Vector3,grip:bool,valid:bool)->void:
	if held_kind!="banana" or phase!="open":return
	if not grip or not valid:_peel_active=false;return
	if not _peel_active:return
	if local.distance_to(_peel_start)>.5:_peel_active=false;return
	if _peel_start.y-local.y>=.10:
		peel_count=mini(4,peel_count+1);_peel_active=false;_play_cue("open");open_item()
func _update_preparation_visual()->void:
	if not is_instance_valid(held_prop):return
	var label:Label3D=held_prop.get_node("ItemTitle");label.show()
	if held_kind=="shaker":
		# Continuous distance/time progress; reversals remain a readiness prerequisite.
		var progress:=minf(.98,minf(_shake_distance/SHAKE_DISTANCE,_shake_seconds/SHAKE_SECONDS))
		label.text="READY — DRINK" if phase=="consume" else "SHAKE"
		_update_shaker_ring(1.0 if phase=="consume" else progress)
		label.modulate=Color.GREEN if phase=="consume" else Color.CYAN
	elif held_kind=="banana":
		label.text="EAT" if phase=="consume" else "PEEL %d / 4"%peel_count
		preload("res://scripts/banana_peel_086.gd").update(held_prop,peel_count,_peel_active,_peel_start,actor)
	else:label.text="DRINK" if phase=="consume" else "OPEN"

func consumption_anchor()->Vector3:
	# Mesh-space drinking/eating end, not the grip origin or a neck offset.
	var offset:=Vector3(0,.127,.008) if held_kind=="shaker" else (Vector3(0,.065,.010) if held_kind=="soda" else Vector3(.048,.095,0))
	return held_prop.to_global(offset)
func _update_shaker_ring(progress:float)->void:
	var ring:=held_prop.get_node_or_null("ChargeRing") as MeshInstance3D
	if ring==null:
		ring=MeshInstance3D.new();ring.name="ChargeRing";ring.mesh=ImmediateMesh.new();ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;held_prop.add_child(ring)
	var camera:Camera3D=actor.get_view_camera()
	ring.global_transform=Transform3D(preload("res://scripts/upright_ui.gd").view_basis(camera.global_basis),held_prop.global_position)
	var fill:=clampf(progress,0,1)
	var segments:=ceili(fill*64)
	if is_equal_approx(float(ring.get_meta("fill",-1.0)),fill):return
	ring.set_meta("fill",fill);ring.set_meta("segments",segments)
	var mesh:=ring.mesh as ImmediateMesh;mesh.clear_surfaces()
	for layer in 2:
		var count:=64 if layer==0 else segments
		if count==0:continue
		var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		mat.albedo_color=Color(.08,.15,.19) if layer==0 else (Color.GREEN if segments==64 else Color.CYAN)
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,mat)
		for step in count:
			var a:=PI/2-float(step)*TAU/64;var z:=PI/2-minf(float(step+1)/64,1.0 if layer==0 else fill)*TAU
			var vertices:=[Vector3(cos(a)*.09,sin(a)*.09,layer*.002),Vector3(cos(a)*.102,sin(a)*.102,layer*.002),Vector3(cos(z)*.102,sin(z)*.102,layer*.002),Vector3(cos(z)*.09,sin(z)*.09,layer*.002)]
			for i in [0,1,2,0,2,3]:mesh.surface_add_vertex(vertices[i])
		mesh.surface_end()

static func held_offset(kind:String)->Vector3:
	return Vector3(-.0254,-.0381,0) if kind in ["soda","shaker"] else Vector3.ZERO
