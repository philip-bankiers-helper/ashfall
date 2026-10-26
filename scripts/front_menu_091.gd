extends "res://scripts/front_menu_090.gd"
## Separate pedestal lobby with only the requested ready / loadout / map features.
var lobby:Node3D
var gallery:Node3D
var game:Node
var page:="lobby"
var selected_map:="valley"
var _return_pose:=Transform3D.IDENTITY
var _entered:=false
var title_text:Label
var selection_text:Label
var _previous_environment:Environment
var _lobby_tracking_ready:=false
var _boot_done099:=false
var _hovered099:=-1
func setup(player:Node3D)->void:
	actor=player;game=get_parent();process_priority=115
	if OS.get_cmdline_user_args().has("--scope-playtest"):selected_map="range"
	lobby=preload("res://scripts/lobby_map_091.gd").new();add_child(lobby);lobby.build();lobby.position=Vector3(1000,0,1000)
	gallery=preload("res://scripts/lobby_gallery_091.gd").new();add_child(gallery);gallery.setup(actor,game);gallery.set_process(false)
	desktop=CanvasLayer.new();desktop.layer=100;add_child(desktop)
	container=SubViewportContainer.new();container.size=Vector2(SIZE);desktop.add_child(container)
	viewport=SubViewport.new();viewport.size=SIZE;viewport.transparent_bg=true;container.add_child(viewport)
	title_text=words("ASHFALL",Vector2(42,28),28,Color.WHITE)
	selection_text=words("RELAY VALLEY",Vector2(465,554),17,Color.WHITE);selection_text.size=Vector2(350,28);selection_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	# Keep the established first three action IDs for working Ready / Settings / Exit.
	button("READY",Vector2(465,584),Vector2(350,88),Color("e5eb00"),Color("171b13"),48)
	button("SETTINGS",Vector2(40,726),Vector2(170,48))
	button("EXIT",Vector2(1130,726),Vector2(110,48))
	button("LOADOUT",Vector2(450,712),Vector2(330,64))
	button("MAP SELECT",Vector2(465,490),Vector2(350,58),Color("0499c4"),Color.WHITE,24)
	button("<",Vector2(350,672),Vector2(210,105),Color("101b31"),Color.WHITE,46)
	button(">",Vector2(720,672),Vector2(210,105),Color("101b31"),Color.WHITE,46)
	button("WEAPONS",Vector2(400,108),Vector2(230,54))
	button("CHARACTERS",Vector2(650,108),Vector2(230,54))
	button("USE CHARACTER",Vector2(500,594),Vector2(280,54),Color("0298c3"))
	button("BACK",Vector2(40,650),Vector2(170,54))
	button("RELAY VALLEY",Vector2(400,350),Vector2(480,76))
	button("SANDBOX RANGE",Vector2(400,450),Vector2(480,76))
	board=MeshInstance3D.new();board.mesh=QuadMesh.new();board.mesh.size=BOARD_SIZE
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_texture=viewport.get_texture();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;board.material_override=mat;board.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(board)
	pointer=MeshInstance3D.new();pointer.mesh=SphereMesh.new();pointer.mesh.radius=.004;pointer.mesh.height=.008;var white:=StandardMaterial3D.new();white.albedo_color=Color.WHITE;white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;pointer.material_override=white;add_child(pointer)
	refresh_page();set_active(false)
func words(value:String,at:Vector2,size_value:int,color:Color)->Label:
	var label:=Label.new();label.text=value;label.position=at;label.add_theme_font_size_override("font_size",size_value);label.modulate=color;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2);viewport.add_child(label);return label
func button(value:String,at:Vector2,size_value:Vector2,color:Color=Color("101b31"),ink:Color=Color.WHITE,font:int=22)->void:
	var index:=buttons.size();var b:=Button.new();b.text=value;b.position=at;b.size=size_value;b.add_theme_font_size_override("font_size",font)
	if value=="READY":
		var bold:=FontVariation.new();bold.base_font=ThemeDB.fallback_font;bold.variation_embolden=.7;b.add_theme_font_override("font",bold)
	for state in ["normal","hover","focus","pressed"]:
		var style:=StyleBoxFlat.new();style.bg_color=color.lightened(.15) if state!="normal" else color;style.border_color=color.lightened(.4);style.border_width_bottom=4;style.border_width_left=2;b.add_theme_stylebox_override(state,style)
		b.add_theme_color_override("font_"+("color" if state=="normal" else state+"_color"),ink)
	b.pressed.connect(activate.bind(index));b.mouse_entered.connect(func():
		if active:preload("res://scripts/sound_cues099.gd").play_ui(self,"menu_hover"))
	viewport.add_child(b);buttons.append(b)
func refresh_page()->void:
	for i in buttons.size():buttons[i].visible=(i in [0,1,2,3,4] if page=="lobby" else (i in [5,6,7,8,10] or (i==9 and gallery.characters) if page=="loadout" else i in [10,11,12]))
	selection_text.visible=page!="maps"
	selection_text.text=("RELAY VALLEY" if selected_map=="valley" else "SANDBOX RANGE") if page=="lobby" else gallery.model_name
	selection_text.position=Vector2(465,554) if page=="lobby" else Vector2(465,550)
	title_text.text="ASHFALL" if page=="lobby" else ("LOADOUT" if page=="loadout" else "SELECT MAP")
func activate(index:int)->void:
	if not active or index<0 or index>=buttons.size() or not buttons[index].visible:return
	preload("res://scripts/sound_cues099.gd").play_ui(self,"menu_click")
	if index==0:preload("res://scripts/sound_cues099.gd").play_ui(self,"game_start_music")
	match index:
		0:play_requested.emit()
		1:settings_requested.emit()
		2:quit_requested.emit()
		3:page="loadout";gallery.show_item(false,0)
		4:page="maps";gallery.close()
		5,6:gallery.show_item(gallery.characters,gallery.selected+(-1 if index==5 else 1))
		7,8:gallery.show_item(index==8,0)
		9:gallery.use_character();preload("res://scripts/lobby_map_091.gd").apply_style(lobby.avatars[1].get_child(0),gallery.style)
		10:page="lobby";gallery.close()
		11,12:selected_map="valley" if index==11 else "range";page="lobby"
	refresh_page()
func set_active(value:bool)->void:
	if value and not _entered:
		_return_pose=actor.global_transform;_entered=true;actor.global_transform=Transform3D(Basis.IDENTITY,lobby.global_position+Vector3(0,.3,3.8));actor.reset_motion();lobby.show()
		_previous_environment=actor.get_world_3d().environment
		var environment:=Environment.new();environment.background_mode=Environment.BG_SKY;environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("bbd9ed");environment.ambient_light_energy=.55
		var sky:=Sky.new();var atmosphere:=ProceduralSkyMaterial.new();atmosphere.sky_top_color=Color("246eb6");atmosphere.sky_horizon_color=Color("a3c9e4");atmosphere.ground_bottom_color=Color("354859");atmosphere.ground_horizon_color=Color("a3c9e4");sky.sky_material=atmosphere;environment.sky=sky;actor.get_world_3d().environment=environment
	super.set_active(value)
	_lobby_tracking_ready=false
	if value:
		_place_lobby_board()
		_lobby_tracking_ready=actor.xr_enabled and actor.tracking_available
		refresh_page()
	else:
		gallery.close()
func leave_lobby()->void:
	if not _entered:return
	_entered=false;actor.global_transform=_return_pose;actor.reset_motion();actor.get_world_3d().environment=_previous_environment;lobby.hide();gallery.close()
	if selected_map=="valley" and is_instance_valid(game.active_sandbox_map):
		var old:Node3D=game.active_sandbox_map;game.active_sandbox_map=null;old.get_parent().remove_child(old);old.queue_free();game.world.show();game.new_campaign()
	if selected_map=="range" and is_instance_valid(game.active_sandbox_map):return
	if selected_map=="range" and "weapon_inventory" in game:
		var range_map:=preload("res://scripts/sandbox_map_091.gd").new();game.add_child(range_map);range_map.enter(game)
func _process(delta:float)->void:
	if active and actor.xr_enabled:
		if not actor.tracking_available:_lobby_tracking_ready=false
		elif not _lobby_tracking_ready:
			_place_lobby_board();_lobby_tracking_ready=true
	if active and not _boot_done099 and (not actor.xr_enabled or actor.tracking_available):
		_boot_done099=true;preload("res://scripts/sound_cues099.gd").play_ui(self,"vr_initialize")
	super._process(delta)
	if active and page=="loadout":gallery._process(delta)
func _place_lobby_board()->void:
	# Startup may precede the first tracked HMD pose. Re-anchor on tracking
	# acquisition / resume, then keep the panel still while the player points.
	var camera:Camera3D=actor.get_view_camera()
	var forward:Vector3=-camera.global_basis.z;forward.y=0
	if forward.length_squared()<.0001:forward=-actor.global_basis.z;forward.y=0
	if forward.length_squared()<.0001:forward=Vector3.FORWARD
	var facing:=Basis.looking_at(forward.normalized(),Vector3.UP)
	board.global_transform=Transform3D(facing,camera.global_position+forward.normalized()*1.8-Vector3.UP*.20)
func _exit_tree()->void:
	if _entered and is_instance_valid(actor):actor.global_transform=_return_pose;actor.get_world_3d().environment=_previous_environment

func _menu_edge097(trigger:bool,hovered:int)->void:
	if hovered!=_hovered099:
		_hovered099=hovered
		if hovered>=0:preload("res://scripts/sound_cues099.gd").play_ui(self,"menu_hover")
	super._menu_edge097(trigger,hovered)
