extends Node3D
## Independent live inspection weapons; carried inventory and world damage stay separate.
var actor:Node3D
var game:Node
var active:=false
var characters:=false
var selected:=0
var prop:Node3D
var holder:Node3D
var dock:=Transform3D.IDENTITY
var previous:Dictionary={}
var model_name:=""
var style:=0
var live097:Node3D
var preview_shots097:=0
var _desktop_down097:=false
var _reload_down097:=false
const STYLES=["FIELD CAMO","NIGHT CAMO","PALE CAMO"]
func setup(player:Node3D,owner_game:Node)->void:
	actor=player;game=owner_game
func show_item(character_mode:bool,index:int)->void:
	_stop_live097()
	characters=character_mode;holder=null;selected=index;active=true
	if is_instance_valid(prop):remove_child(prop);prop.queue_free()
	if characters:
		selected=posmod(index,3);model_name=STYLES[selected];prop=preload("res://scripts/lobby_map_091.gd").make_avatar(selected);prop.scale=Vector3.ONE*.45
	elif "weapon_inventory" in game:
		var indices:Array=game.weapon.ACTIVE_WEAPON_INDICES;selected=posmod(index,indices.size());var id:int=indices[selected];prop=game.weapon_inventory._create_prop(id);model_name=game.weapon.weapon_names[id]
	else:return
	if prop.get_parent()!=null:prop.reparent(self)
	else:add_child(prop)
	var camera:Camera3D=actor.get_view_camera();var view:Basis=preload("res://scripts/upright_ui.gd").view_basis(camera.global_basis)
	dock=Transform3D(view*Basis(Vector3.UP,PI*.5),camera.global_position+view*Vector3(0,-.40 if characters else -.16,-1.10));prop.global_transform=dock.scaled_local(Vector3.ONE*(.45 if characters else 1.0))
func close()->void:
	_stop_live097()
	active=false;holder=null
	if is_instance_valid(prop):prop.hide()
func grab(hand:Node3D)->bool:
	if not active or not is_instance_valid(prop) or holder!=null or not actor.is_hand_input_ready(hand):return false
	if not characters and hand!=actor.get_weapon_hand():return false
	var distance:float=hand.global_position.distance_to(prop.global_position)
	var pose:Transform3D=preload("res://scripts/weapon.gd").corrected_grip_transform(hand.global_transform)
	if distance>2.0 or (distance>.35 and (-pose.basis.z).dot((prop.global_position-hand.global_position).normalized())<.94):return false
	holder=hand
	if not characters:_start_live097()
	return true
func release()->void:
	_stop_live097()
	holder=null
	if is_instance_valid(prop):prop.global_transform=dock.scaled_local(Vector3.ONE*(.45 if characters else 1.0))
func _process(delta:float)->void:
	if not active or not is_instance_valid(prop):return
	if not actor.xr_enabled:
		var down:=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if characters and down:prop.rotate_y(delta*.8)
		if down and not _desktop_down097 and live097==null and not characters:
			var menu:Node3D=get_parent()
			var cursor:Vector2=menu.container.get_local_mouse_position()
			if Rect2(400,230,480,315).has_point(cursor):_start_live097()
		elif down and live097!=null:live097.fire()
		var reload_down:=Input.is_physical_key_pressed(KEY_R)
		if reload_down and not _reload_down097 and live097!=null:live097.desktop_reload_step()
		_desktop_down097=down;_reload_down097=reload_down
		return
	for hand in [actor.left_hand,actor.right_hand]:
		var valid:bool=actor.is_hand_input_ready(hand);var grip:bool=valid and (hand.get_float("grip")>.55 or hand.is_button_pressed("grip_click"))
		if not valid and holder==hand:release()
		if grip and not previous.get(hand,true):grab(hand)
		if not grip and holder==hand:release()
		previous[hand]=grip
	if holder!=null and live097==null:
		var pose:Transform3D=preload("res://scripts/weapon.gd").corrected_grip_transform(holder.global_transform)
		prop.global_transform=pose.scaled_local(Vector3.ONE*(.45 if characters else 1.0))
func use_character()->void:
	if not characters:return
	style=selected
	if "body_visual" in game:preload("res://scripts/lobby_map_091.gd").apply_style(game.body_visual,style)

func _start_live097()->void:
	if live097!=null or characters:return
	var id:int=preload("res://scripts/weapon_rack.gd").ACTIVE_WEAPON_INDICES[selected]
	var original:Node3D=game.weapon.weapons[id]
	live097=original.get_script().new()
	if id in [0,17,18,19,20,21,23,24,25]:
		live097.profile_id=original.profile_id;live097.mode=original.mode
	elif id in [26,27,28]:live097.profile_id=original.profile_id
	add_child(live097);live097.set_meta("lobby_preview097",true)
	live097.setup(actor,false);preload("res://scripts/arsenal_data.gd").apply(live097,id)
	preload("res://scripts/one_star0991.gd").apply(live097)
	if "guns" in live097:
		for gun in live097.guns:gun.set_meta("lobby_preview097",true)
	preload("res://scripts/common_reflex_090.gd").install(live097,id)
	live097.set_process_unhandled_input(false)
	live097.shot.connect(_preview_shot097)
	if live097.has_signal("pellet_shot"):
		live097.pellet_shot.connect(func(origin:Vector3,directions:Array[Vector3],damage:float):
			for direction in directions:_preview_shot097(origin,direction,damage))
	if live097.has_signal("explosive_launch"):
		live097.explosive_launch.connect(func(spec:Dictionary):_preview_shot097(spec.get("origin",live097.global_position),spec.get("velocity",-live097.global_basis.z).normalized(),0))
	prop.hide();live097._requires_trigger_release=true
func _stop_live097()->void:
	if not is_instance_valid(live097):live097=null;return
	live097.set_meta("lobby_preview097",false);live097.shutdown();live097._reserve_support_hand(false)
	if "guns" in live097:
		for gun in live097.guns:gun.set_meta("lobby_preview097",false)
	remove_child(live097);live097.queue_free();live097=null
	if is_instance_valid(prop):prop.show()
func _preview_shot097(origin:Vector3,direction:Vector3,_damage:float)->void:
	if not active or live097==null or not origin.is_finite() or direction.length_squared()<.1:return
	preview_shots097+=1
	var finish:=origin+direction.normalized()*40
	var query:=PhysicsRayQueryParameters3D.create(origin,finish,1|8,[actor.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():finish=hit.position
	var trace:=MeshInstance3D.new();var line:=ImmediateMesh.new();trace.mesh=line
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("ffe4a0");trace.material_override=mat;add_child(trace);trace.top_level=true;trace.global_transform=Transform3D.IDENTITY
	line.surface_begin(Mesh.PRIMITIVE_LINES);line.surface_add_vertex(origin);line.surface_add_vertex(finish);line.surface_end()
	get_tree().create_timer(.07).timeout.connect(trace.queue_free)
