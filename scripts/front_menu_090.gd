extends Node3D
## The same responsive menu surface supports desktop and tracked-controller pointing.
signal play_requested
signal settings_requested
signal quit_requested
const SIZE:=Vector2i(1280,800)
const BOARD_SIZE:=Vector2(1.60,1.0)
var actor:Node3D
var viewport:SubViewport
var desktop:CanvasLayer
var container:SubViewportContainer
var board:MeshInstance3D
var pointer:MeshInstance3D
var active:=false
var buttons:Array[Button]=[]
var _armed:=false
var _trigger:=false
var _pressed_button097:=-1
var _beam097:MeshInstance3D
func setup(player:Node3D)->void:
	actor=player;process_priority=115
	desktop=CanvasLayer.new();desktop.layer=100;add_child(desktop)
	container=SubViewportContainer.new();container.size=Vector2(SIZE);desktop.add_child(container)
	viewport=SubViewport.new();viewport.size=SIZE;viewport.transparent_bg=false;container.add_child(viewport)
	var art:=preload("res://scripts/front_menu_art_090.gd").new();art.size=Vector2(SIZE);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(art)
	_label("A S H F A L L",Vector2(76,99),70,Color("f0eee5"))
	_label("T H E   L A S T   R E L A Y",Vector2(82,193),19,Color("c8d3cd"))
	_label("THE VALLEY HAS GONE QUIET.",Vector2(82,280),17,Color("a4b9bb"))
	_label("Find your footing. Restore the signal.",Vector2(82,311),20,Color("d7e0dc"))
	for i in 3:
		var button:=Button.new();button.text=["PLAY", "SETTINGS", "EXIT"][i];button.position=Vector2(82,392+i*74);button.size=Vector2(360,58)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.add_theme_font_size_override("font_size",23)
		button.add_theme_color_override("font_color",Color("e4ece7"));button.add_theme_color_override("font_hover_color",Color("111f25"))
		for state in ["normal","hover","focus","pressed"]:
			var style:=StyleBoxFlat.new();style.bg_color=Color("b6d6c2") if state!="normal" else Color("1a2b31")
			style.border_color=Color("b6d6c2") if state!="normal" else Color("475f64");style.border_width_left=3;style.content_margin_left=23;style.corner_radius_top_right=3;style.corner_radius_bottom_right=3
			button.add_theme_stylebox_override(state,style)
		button.pressed.connect(activate.bind(i));viewport.add_child(button);buttons.append(button)
	_label("STANDALONE  /  090",Vector2(82,724),14,Color("a5b9b6"))
	_label("POINT + TRIGGER TO SELECT" if actor.xr_enabled else "SELECT WITH MOUSE",Vector2(915,724),14,Color("a5b9b6"))
	board=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=BOARD_SIZE;board.mesh=quad
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_texture=viewport.get_texture();mat.cull_mode=BaseMaterial3D.CULL_DISABLED;board.material_override=mat;board.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(board)
	pointer=MeshInstance3D.new();var dot:=SphereMesh.new();dot.radius=.004;dot.height=.008;pointer.mesh=dot;var white:=StandardMaterial3D.new();white.albedo_color=Color.WHITE;white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;pointer.material_override=white;add_child(pointer)
	set_active(false)
func _label(words:String,at:Vector2,size_value:int,color:Color)->void:
	var label:=Label.new();label.text=words;label.position=at;label.add_theme_font_size_override("font_size",size_value);label.modulate=color;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(label)
func activate(index:int)->void:
	if not active:return
	match index:
		0:play_requested.emit()
		1:settings_requested.emit()
		2:quit_requested.emit()
func set_active(value:bool)->void:
	active=value;_armed=false;_trigger=true;_pressed_button097=-1
	if _beam097!=null:_beam097.hide()
	if viewport==null:return
	desktop.visible=value and not actor.xr_enabled;board.visible=value and actor.xr_enabled;pointer.hide()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	if value:
		var camera:Camera3D=actor.get_view_camera();var facing:=preload("res://scripts/upright_ui.gd").view_basis(camera.global_basis)
		board.global_transform=Transform3D(facing,camera.global_position-facing.z*1.8)
		if not actor.xr_enabled:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func _process(_delta:float)->void:
	if not active:return
	if not actor.xr_enabled:
		var screen:=get_viewport().get_visible_rect().size;var fit:=minf(screen.x/SIZE.x,screen.y/SIZE.y)
		container.scale=Vector2.ONE*fit;container.position=(screen-Vector2(SIZE)*fit)*.5;return
	pointer.hide()
	if _beam097!=null:_beam097.hide()
	var hand:XRController3D=actor.get_weapon_hand()
	if not actor.tracking_available or not actor.is_hand_input_ready(hand):_armed=false;_pressed_button097=-1;return
	var trigger:bool=hand.get_float("trigger")>.65 or hand.is_button_pressed("trigger_click")
	if not _armed:
		if not trigger:_armed=true;_trigger=false
		return
	var pose:Transform3D=preload("res://scripts/weapon.gd").corrected_grip_transform(hand.global_transform)
	_draw_beam097(pose.origin,pose.origin-pose.basis.z*2.5)
	var start:=board.to_local(pose.origin);var direction:Vector3=board.global_basis.inverse()*(-pose.basis.z)
	if absf(direction.z)<.00001:_menu_edge097(trigger,-1);return
	var travel:float=-start.z/direction.z;var hit:=start+direction*travel
	if travel<0 or absf(hit.x)>BOARD_SIZE.x*.5 or absf(hit.y)>BOARD_SIZE.y*.5:_menu_edge097(trigger,-1);return
	var point:=Vector2(hit.x/BOARD_SIZE.x+.5,.5-hit.y/BOARD_SIZE.y)*Vector2(SIZE)
	pointer.global_position=board.to_global(hit+Vector3(0,0,.005));pointer.show()
	_draw_beam097(pose.origin,pointer.global_position)
	var hovered:=-1
	for i in buttons.size():
		if buttons[i].visible and buttons[i].get_global_rect().has_point(point):
			buttons[i].grab_focus()
			hovered=i
			break # A page change must not activate a second overlapping button.
	var loadout:Node=get("gallery") if "gallery" in self else null
	if loadout!=null and loadout.live097!=null:hovered=-1
	_menu_edge097(trigger,hovered)

func _menu_edge097(trigger:bool,hovered:int)->void:
	# Press captures one button; release must still point to that same button.
	if trigger and not _trigger:_pressed_button097=hovered
	if not trigger and _trigger:
		var pending:=_pressed_button097;_pressed_button097=-1
		if pending>=0 and pending==hovered:activate(pending)
	_trigger=trigger

func _draw_beam097(start:Vector3,finish:Vector3)->void:
	if _beam097==null:
		_beam097=MeshInstance3D.new();_beam097.name="HandMenuBeam097";var line:=CylinderMesh.new();line.top_radius=.0015;line.bottom_radius=.0015;line.radial_segments=6;line.height=1;_beam097.mesh=line;add_child(_beam097)
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color("9de4ff");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;_beam097.material_override=mat;_beam097.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var direction:=finish-start
	if direction.length()<.001:return
	_beam097.global_transform=Transform3D(Basis(Quaternion(Vector3.UP,direction.normalized())).scaled_local(Vector3(1,direction.length(),1)),(start+finish)*.5);_beam097.show()
