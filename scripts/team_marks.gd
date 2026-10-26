extends Node3D
## Local marks with transport-neutral payloads. No networking is implemented.
signal mark_created(payload:Dictionary)
const COLORS:=[Color("ffd338"),Color("ff4848"),Color("329dff"),Color("eeeeee"),Color("eeeeee"),Color("eeeeee"),Color("be79ed"),Color("6ce36a"),Color.WHITE]
const COLOR_NAMES:=["yellow","red","blue","white","white","white","purple","green","white"]
const ACTIONS:=["hold","enemy","location","emote_local","target","emote_alt","help","go_here","weapon"]
const TITLES:=["HOLD","ENEMY","PING","EMOTE (LOCAL MARK)","TARGET","EMOTE 2","HELP","GO HERE","WEAPON"]
const OUTER_RADIUS:=preload("res://scripts/weapon_wheel.gd").OUTER_RADIUS
const INNER_RADIUS:=OUTER_RADIUS*.30
@export var sky_limit_y:=80.0
const COLUMN_WIDTH:=.6096*1.2
var _sectors:Array[MeshInstance3D]=[]
var _header:Label3D
@export var hold_seconds:=.10
@export var reach:=80.0
@export var lifetime_seconds:=30.0
var actor:Node
var rack:Node
var game:Node
var wheel_open:=false
var selected_color:=2
var _held:=false
var _armed:=false
var _elapsed:=0.0
var _press_pose:=Transform3D.IDENTITY
var _target:Dictionary={}
var _current_pose:=Transform3D.IDENTITY
var _wheel_was_open:=false
var _serial:=0
var records:Array[Dictionary]=[]
var _visuals:Array[Node3D]=[]
var _weapon_context0993:Dictionary={}
var _explicit_choice0993:=false
var _stick_choice0993:=false
var ping_audio_events0993:=0
var _wheel:Node3D
func setup(player:Node,weapons:Node,campaign:Node)->void:
	actor=player;rack=weapons;game=campaign
	_ensure_wheel() # build/import once during setup, never on first B hold
func _physics_process(delta:float)->void:
	if actor==null:return
	var pose:Transform3D=rack._pointer_transform() if actor.xr_enabled else actor.get_view_camera().global_transform
	var pressed:=Input.is_physical_key_pressed(KEY_B)
	var choice:=Vector2.ZERO
	var ready:bool=actor.input_enabled and actor.tracking_available and not game.paused and not game.dead and not game.complete and not rack.is_selecting
	if game.field_menu!=null and game.field_menu.is_open:ready=false
	if actor.xr_enabled:
		var hand=actor.get_weapon_hand();pressed=hand.is_button_pressed("by_button");choice=hand.get_vector2("primary");ready=ready and actor.is_hand_input_ready(hand)
	if choice.length()<.25 and _held:
		var delta_ray:Vector3=-pose.basis.z+_press_pose.basis.z
		choice=Vector2(delta_ray.dot(_upright_wheel_basis().x),delta_ray.dot(Vector3.UP))*3.0
	consume_state({"pressed":pressed,"eligible":ready,"pose":pose,"choice":choice},delta)
	for i in range(records.size()-1,-1,-1):
		if Time.get_ticks_msec()-int(records[i].created_ms)>lifetime_seconds*1000:
			records.remove_at(i);_visuals[i].queue_free();_visuals.remove_at(i)
func _surface(pose:Transform3D)->Dictionary:
	var excluded:Array[RID]=[]
	_collect_owned_colliders(actor,excluded);_collect_owned_colliders(rack,excluded)
	# World/construction currently layer1; targets layer4; include layer8 panels.
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pose.origin,pose.origin-pose.basis.z*reach,1|4|8,excluded))
func _collect_owned_colliders(node:Node,excluded:Array[RID])->void:
	if node==null:return
	if node is CollisionObject3D and not excluded.has(node.get_rid()):excluded.append(node.get_rid())
	for child in node.get_children():_collect_owned_colliders(child,excluded)
func consume_state(state:Dictionary,delta:float)->void:
	var pressed:bool=state.get("pressed",false)
	_current_pose=state.get("pose",_press_pose)
	if not state.get("eligible",false):
		_armed=false;_held=false;wheel_open=false;_target.clear();_weapon_context0993.clear();_show_wheel();return
	if not _armed:
		if not pressed:_armed=true
		return
	if pressed and not _held:
		_held=true;_elapsed=0;_press_pose=state.get("pose",Transform3D.IDENTITY)
		selected_color=2;_explicit_choice0993=false
		_weapon_context0993=state.get("weapon",_pointed_weapon0993()).duplicate(true)
		_target=state.hit.duplicate(true) if state.has("hit") else (_surface(_press_pose) if is_inside_tree() else {})
	if _held and pressed:
		_elapsed+=maxf(0,delta);wheel_open=_elapsed>hold_seconds+.0000001
		var choice:Vector2=state.get("choice",Vector2.ZERO)
		_stick_choice0993=wheel_open and choice.length()>.25
		if _stick_choice0993:
			selected_color=sector_for_direction(choice);_explicit_choice0993=true
	elif _held:
		if not _weapon_context0993.is_empty() and not _explicit_choice0993:
			_create_mark(_weapon_context0993.position,Vector3.UP,8,int(_weapon_context0993.index))
		elif not _target.is_empty():_create_mark(_target.position,_target.get("normal",Vector3.UP),selected_color)
		_held=false;wheel_open=false;_target.clear();_weapon_context0993.clear()
	_show_wheel()
func _pointed_weapon0993()->Dictionary:
	if actor==null or rack==null or game==null:return {}
	var inventory:Node=game.weapon_inventory;var hand:Node3D=actor.get_weapon_hand()
	if not inventory.aim_rings.has(hand):return {}
	var ring:Node3D=inventory.aim_rings[hand]
	if not is_instance_valid(ring) or not ring.is_visible_in_tree():return {}
	var index:int=int(ring.get_meta("pickup_index",-1))
	if index<0 or not inventory.pickups.has(index):return {}
	return {"index":index,"position":inventory._pickup_center(index)}
static func surface_basis0993(normal:Vector3)->Basis:
	var n:=normal.normalized();var x:=Vector3.RIGHT-n*n.dot(Vector3.RIGHT)
	if x.length_squared()<.0001:x=Vector3.FORWARD-n*n.dot(Vector3.FORWARD)
	x=x.normalized();return Basis(x,n.cross(x).normalized(),n)
func _create_mark(point:Vector3,normal:Vector3,color_index:int,weapon_index:int=-1)->void:
	if not point.is_finite() or not normal.is_finite() or normal.length_squared()<.0001 or color_index<0 or color_index>=ACTIONS.size():return
	if color_index==8 and (rack==null or weapon_index<0 or weapon_index>=rack.weapons.size()):return
	for old in _visuals:remove_child(old);old.queue_free()
	_visuals.clear();records.clear();_serial+=1
	var paint:bool=color_index in [3,4,5]
	var payload:={"schema":1,"id":"local:"+str(_serial),"sender":"local","team":"local","color":COLOR_NAMES[color_index],"action":ACTIONS[color_index],"networked":false,"surface_decal":paint,"position":[point.x,point.y,point.z],"normal":[normal.x,normal.y,normal.z],"created_ms":Time.get_ticks_msec(),"ttl_seconds":lifetime_seconds}
	var visual:=Node3D.new();add_child(visual);visual.global_position=point+normal.normalized()*(.004 if paint else .035);_visuals.append(visual)
	var icon:=Sprite3D.new();icon.name="BasePingIcon";icon.no_depth_test=false;icon.shaded=false;icon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;visual.add_child(icon)
	if color_index==8:
		var catalog:int=rack.catalog_index(weapon_index);icon.texture=preload("res://scripts/weapon_icons_094.gd").icon(catalog);icon.pixel_size=COLUMN_WIDTH/icon.texture.get_width();icon.position.y=.5;icon.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
		payload["weapon_index"]=weapon_index;payload["catalog_index"]=catalog;payload["weapon_name"]=rack.weapon_names[weapon_index]
		var label:=Label3D.new();label.text=rack.weapon_names[weapon_index];label.font_size=24;label.pixel_size=.0015;label.position.y=.80;label.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;visual.add_child(label)
	else:
		icon.texture=load("res://assets/ui/ping0993_5.svg" if color_index==5 else "res://assets/ui/ping072_%d.svg"%color_index);icon.pixel_size=(.55 if paint else COLUMN_WIDTH)/64.0
		if paint:visual.global_basis=surface_basis0993(normal);icon.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		else:icon.position.y=.5;icon.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	if not paint:_add_column(visual,point,COLORS[color_index])
	records.append(payload);mark_created.emit(payload.duplicate(true));_ping0993()
func _ping0993()->void:
	var voice:=AudioStreamPlayer.new();voice.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master";voice.volume_db=-8;voice.stream=AshAudioBank.sample("mark_ping0993");add_child(voice);voice.finished.connect(voice.queue_free);voice.play();ping_audio_events0993+=1
func _upright_wheel_basis()->Basis:
	var forward:Vector3=-_press_pose.basis.z;forward.y=0
	if forward.length_squared()<.001:forward=Vector3.FORWARD
	return Basis.looking_at(forward.normalized(),Vector3.UP)
static func sector_for_direction(choice:Vector2)->int:
	return posmod(int(floor((PI*.5-atan2(choice.y,choice.x)+PI/8.0)/(PI/4.0))),8)
func _add_column(visual:Node3D,point:Vector3,color:Color)->void:
	var dots:=MultiMeshInstance3D.new();dots.name="DottedSkyColumn"
	var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D
	var dot:=SphereMesh.new();dot.radius=COLUMN_WIDTH*.5;dot.height=.36;dot.radial_segments=8;dot.rings=4
	multimesh.mesh=dot;multimesh.instance_count=maxi(1,ceili(maxf(0,sky_limit_y-point.y-2)))
	for i in multimesh.instance_count:multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(0,float(i+2),0)))
	dots.multimesh=multimesh;var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color;dots.material_override=material;visual.add_child(dots)
func _ensure_wheel()->void:
	if _wheel!=null or not is_inside_tree():return
	_wheel=preload("res://scripts/ping_wheel_086.gd").new();add_child(_wheel);_header=_wheel.status_label
func _show_wheel()->void:
	_ensure_wheel()
	if _wheel==null:return
	if wheel_open:
		var anchor:Vector3=actor.get_locomotion_anchor_position() if actor!=null and actor.has_method("get_locomotion_anchor_position") else Vector3.ZERO
		if not _wheel_was_open:
			var view:Transform3D=actor.get_view_camera().global_transform if actor!=null else _press_pose
			_wheel.open_at(view,_current_pose,anchor)
		else:_wheel.follow_player_translation(anchor)
		_wheel.point(_current_pose)
		if _wheel.highlighted>=0 and not _stick_choice0993:selected_color=_wheel.highlighted;_explicit_choice0993=true
		_wheel.status_label.text=("MARK "+rack.weapon_names[int(_weapon_context0993.index)]) if not _weapon_context0993.is_empty() and not _explicit_choice0993 else TITLES[selected_color]
	else:_wheel.hide()
	_wheel_was_open=wheel_open
