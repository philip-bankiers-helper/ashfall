extends Node3D
const Maps=preload("res://scripts/map_catalog1000.gd")
var game:Node
var session:Node
var opened =false
var _trigger =false
var viewport:SubViewport
var board:MeshInstance3D
var canvas:Control
var roster:Label
var caption:Label
var preview:TextureRect
var drawer:Control
var desktop:CanvasLayer
var _last_map =""
var top_image:Texture2D
func setup(g:Node,net:Node)->void:
	game=g;session=net;name="TacticalMap1000";process_priority=125;process_physics_priority=80
	viewport=SubViewport.new();viewport.size=Vector2i(1400,850);viewport.transparent_bg=true;add_child(viewport)
	canvas=Control.new();canvas.set_script(preload("res://scripts/tactical_map_draw1000.gd"));canvas.map=self;canvas.size=Vector2(1400,850);viewport.add_child(canvas)
	roster=Label.new();roster.position=Vector2(38,105);roster.size=Vector2(245,680);roster.add_theme_font_size_override("font_size",23);canvas.add_child(roster)
	caption=Label.new();caption.position=Vector2(1000,100);caption.size=Vector2(365,120);caption.add_theme_font_size_override("font_size",27);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;canvas.add_child(caption)
	preview=TextureRect.new();preview.position=Vector2(1000,245);preview.size=Vector2(355,235);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;canvas.add_child(preview)
	var help =Label.new();help.text="NORTH UP\n\nLeft trigger: close\nDesktop: M\n\n● You   ● Friendly\n● Opponent   ○ Downed";help.position=Vector2(1000,530);help.add_theme_font_size_override("font_size",23);canvas.add_child(help)
	board=MeshInstance3D.new();var quad =QuadMesh.new();quad.size=Vector2(1.65,1.0);board.mesh=quad
	var mat =StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_texture=viewport.get_texture();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;board.material_override=mat;board.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(board)
	desktop=CanvasLayer.new();desktop.layer=180;add_child(desktop)
	var display =TextureRect.new();display.texture=viewport.get_texture();display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);desktop.add_child(display)
	set_open(false)
func map_id()->String:
	if session.active:return str(session.rules.map)
	return str(game.front_menu.selected_map) if is_instance_valid(game.front_menu) else "valley"
func set_open(value:bool)->void:
	opened=value;board.visible=value and game.player.xr_enabled;desktop.visible=value and not game.player.xr_enabled;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	game.player.set_meta("tactical_map1000",value)
func _unhandled_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_M and map_eligible():
		set_open(not opened);get_viewport().set_input_as_handled()
func map_eligible()->bool:
	if game.front_end_active or game.field_menu.is_open:return false
	return game.weapon.is_holstered or game.weapon.catalog_index(game.weapon.selected) not in [11,12]
func consume_trigger(pressed:bool,eligible:bool)->void:
	if pressed and not _trigger and eligible:set_open(not opened)
	_trigger=pressed
func _physics_process(_delta:float)->void:
	var pressed =false
	if game.player.xr_enabled and is_instance_valid(game.player.left_hand) and game.player.is_hand_input_ready(game.player.left_hand):pressed=game.player.left_hand.get_float("trigger")>.65 or game.player.left_hand.is_button_pressed("trigger_click")
	consume_trigger(pressed,map_eligible())
func _process(_delta:float)->void:
	if not map_eligible():
		if opened:set_open(false)
	if not opened:return
	var camera:Camera3D=game.player.get_view_camera();var facing =preload("res://scripts/upright_ui.gd").view_basis(camera.global_basis)
	board.global_transform=Transform3D(facing,camera.global_position+facing*Vector3(0,0,-1.7))
	var id =map_id()
	if id!=_last_map:
		_last_map=id;var row =Maps.info(id);caption.text=row.title+"\n"+row.subtitle;preview.texture=Maps.image(id)
		var top_path="res://assets/maps1000/%s_top.png"%id;top_image=load(top_path) if ResourceLoader.exists(top_path) else null
	var text ="PLAYERS\n\n"
	if session.active:
		for pid in session.players:
			var p:Dictionary=session.players[pid];var team ="FFA" if int(p.team)<0 else "T%d"%(int(p.team)+1)
			text+="%s  %s%s\n%s\n\n"%[team,p.name," (YOU)" if pid==session.me() else "",p.life.to_upper()]
	else:text+="YOU\n%d HEALTH · %d SHIELD"%[ceili(game.health),ceili(game.shield)]
	roster.text=text;canvas.queue_redraw()
