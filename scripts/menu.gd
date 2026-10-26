class_name AshMenu
extends Node3D

signal resumed
signal restart_requested
signal quit_requested
signal settings_changed(settings: Dictionary)
signal loadout_selected(index: int)
signal loadout_dropped(index: int)
signal home_requested
signal vertical_combat_reinitialize_requested
var loadout_icon_provider: Callable
var _loadout_icons: Array[MeshInstance3D] = []
var _desktop_drop_ring: ColorRect
var _desktop_drop_material: ShaderMaterial
var _drop_ring: MeshInstance3D
var _drop_material: ShaderMaterial
var _drop_armed := false
var _drop_a := false
var _drop_grip := false
var _drop_consumed := false
var _drop_elapsed := 0.0
var _drop_index := -1
var _drop_page := false
const LOADOUT_DROP_SECONDS := 3.0
var loadout_provider: Callable
var catalog_ui:Node3D
var network_bridge:Node

func _host_controlled1000(index:int)->bool:
	if network_bridge==null or not network_bridge.live():return false
	return (settings_page=="game" and index in [0,3,4]) or (settings_page=="movement" and index in [4,5]) or (settings_page=="flight" and index in [0,1,2,4,5])

func set_item_catalog(service:Node)->void:
	if catalog_ui!=null:return
	catalog_ui=load("res://scripts/item_catalog_ui_088.gd").new();add_child(catalog_ui);catalog_ui.setup(self,service)

var player: AshPlayer
var is_open := false
var selected := 0
var vignette_enabled := false
var comfort_speed := false
var graphics_quality := "high"
var difficulty := 0.5
var enemy_damage_multiplier := 1.0
var player_damage_multiplier := 1.0
var hud_size := 1.0
var hud_style:="reference"
var front_menu_visible:=false
var settings_from_home0992:=false
var _difficulty_tick := 0.0
const MENU_ROWS := 8
const AUDIO_BUSES := ["Music", "SFX", "Ambience", "Voice"]
var audio_volumes := {"Music": 0.0, "SFX": 1.0, "Ambience": 0.0, "Voice": 1.0}
var _pause_style0993:Node
var audio_page := false
var master_volume:=1.0
var _category_cards:Array[MeshInstance3D]=[]
var _category_icons:Array[Sprite3D]=[]
var _category_edges:Array[MeshInstance3D]=[]
var settings_page := "root"
const WEAPON_SETTINGS_DEFAULTS := {"motion_damping": 1.0, "offhand_influence": 0.0, "grip_toggle": false}
var weapon_settings := WEAPON_SETTINGS_DEFAULTS.duplicate()
var _adjust_ready := true
var _desktop_loadout_grid:GridContainer
var _desktop_loadout_buttons:Array[Button]=[]
var _desktop_rows: Array[HBoxContainer] = []
var _sliders: Array[HSlider] = []
var _volume_labels: Array[Label] = []
var _spatial_title: Label3D
var _spatial_hint: Label3D
var _desktop_hint: Label
var _desktop_title: Label
var campaign_identity := "CLASSIC / 4 MISSIONS"

func set_campaign_identity(expanded: bool) -> void:
	campaign_identity = "CAMPAIGN / 6 MISSIONS" if expanded else "CLASSIC / 4 MISSIONS"
	if is_instance_valid(_desktop_title): _refresh()
var _difficulty_slider: Node3D
var _difficulty_fill: MeshInstance3D
var _difficulty_knob: MeshInstance3D
var _toggle_held := false
var _select_held := false
var _nav_ready := true
var _panel: Node3D
var _rows: Array[Label3D] = []
var _desktop_layer: CanvasLayer
var _buttons: Array[Button] = []
var _vignette: MeshInstance3D
var _vignette_material: ShaderMaterial
var _vignette_strength := 0.0
var _damage_strength := 0.0
var _damage_time := 0.0
var _obstruction_fade := 0.0
var _numeric_tracks: Array[Node3D] = []
var _numeric_fills: Array[MeshInstance3D] = []
var _numeric_knobs: Array[MeshInstance3D] = []
var _pointer_lines: Array[MeshInstance3D] = []
var _pointer_dots: Array[MeshInstance3D] = []
var _settings_dirty := false
var _settings_flush := 0.0
var _slider_pointer
const DAMAGE_PULSE_DURATION := 0.6

func setup(actor: AshPlayer) -> void:
	player = actor
	_slider_pointer=load("res://scripts/menu_slider_pointer.gd").new()
	_apply_audio_volumes()
	_build_spatial_panel()
	_build_desktop_panel()
	_build_loadout_visuals()
	_build_vignette()
	_pause_style0993=preload("res://scripts/pause_menu_style0993.gd").new();add_child(_pause_style0993);_pause_style0993.setup(self)
	_refresh()
	_panel.visible = false
	_desktop_layer.visible = false

func _labels() -> Array[String]:
	if settings_page=="pause":return ["RESUME", "SETTINGS", "INITIALIZE VERTICAL COMBAT SYSTEM", "HOME"]
	if settings_page=="general":return ["MASTER VOLUME", "SFX VOLUME", "MUSIC VOLUME", "VOICE VOLUME", "AMBIENCE VOLUME", "COMFORT VIGNETTE    "+("ON" if vignette_enabled else "OFF"), "GAME OPTIONS", "BACK"]
	if settings_page == "loadout":
		return loadout_provider.call() if loadout_provider.is_valid() else []
	if settings_page == "flight":
		return ["FLYING SPEED    %.1f m/s | GLIDE 7:1" % player.glide_speed_mps, "SLOW SPRINT    %.2fx" % player.sprint_slow_gain, "FAST SPRINT    %.2fx" % player.sprint_fast_gain, "GLIDE STEERING    %.2fx" % player.glide_steering_gain, "STAMINA    %.1f s" % player.sprint_stamina_seconds, "RECOVERY    %.1f s" % player.sprint_recovery_seconds, "BACK TO MOTION OPTIONS"]
	if settings_page == "game":
		var level := "EASIER" if difficulty < 0.34 else ("CHALLENGING" if difficulty > 0.66 else "MODERATE")
		return ["DIFFICULTY    %d%% | %s" % [roundi(difficulty * 100.0), level], "GRAPHICS    " + graphics_quality.to_upper(), "HUD SIZE    %d%%" % roundi(hud_size * 100.0), "ENEMY DAMAGE    %d%%" % roundi(enemy_damage_multiplier*100), "PLAYER DAMAGE    %d%%" % roundi(player_damage_multiplier*100), "REINITIALIZE VERTICAL COMBAT SYSTEM", "HUD STYLE    "+hud_style.to_upper(), "BACK TO SETTINGS"]
	if settings_page == "movement":
		return ["FORWARD MOTION    " + ("HEAD HEADING" if player.forward_reference == "head" else "LEFT CONTROLLER HEADING"), "TURNING    " + player.turning_style.to_upper().replace("_", " "), "SNAP ANGLE    %d deg" % int(player.snap_degrees), "SMOOTH TURN    %d deg/s" % int(player.smooth_turn_speed), "FLING POWER    %d%%" % roundi(player.fling_power * 100.0), "WALK SPEED    %.2fx | %.2f m/s" % [player.walk_speed_multiplier, player.effective_walk_speed()], "SMOOTH TURN OPTIONS", "BACK TO SETTINGS"]
	if settings_page == "turning":
		return ["EASE IN    " + ("ON" if player.smooth_ease_in else "OFF"), "ANALOG CONTROL    " + ("ON" if player.smooth_analog else "OFF"), "WALK BASE    " + ("COMFORT" if comfort_speed else "STANDARD"), "SPRINT    TOGGLE LEFT " + ("GRIP" if player.sprint_binding=="left_grip" else "STICK CLICK"), "FLIGHT / SPRINT TUNING", "RESET MOVEMENT DEFAULTS", "BACK TO MOVEMENT"]
	if settings_page == "weapons":
		return ["MOTION DAMPING    %d%%" % roundi(weapon_settings.motion_damping * 100.0), "OFFHAND INFLUENCE    %d%%" % roundi(weapon_settings.offhand_influence * 100.0), "GRIP TOGGLE    " + ("ON" if weapon_settings.grip_toggle else "OFF"), "DOMINANT HAND    " + player.dominant_hand.to_upper(), "BACK TO SETTINGS"]
	if audio_page:
		var labels: Array[String] = []
		for bus in AUDIO_BUSES:
			labels.append("%s    %d%%" % [bus.to_upper(), roundi(float(audio_volumes[bus]) * 100.0)])
		labels.append("BACK TO SETTINGS")
		return labels
	return ["LOCOMOTION","SET HEIGHT","WEAPONS","GENERAL","BACK"]

func _build_spatial_panel() -> void:
	_panel = Node3D.new()
	add_child(_panel)
	var board := MeshInstance3D.new();board.name="SettingsBoard"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.48)
	board.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = false
	mat.albedo_color = Color("040e17")
	board.material_override = mat
	_panel.add_child(board)
	_spatial_title = _label("ASHFALL / FIELD SYSTEMS", 42, Vector3(0.0, 0.61, 0.008))
	_spatial_title.modulate = Color("40e8ef")
	for i in range(MENU_ROWS):
		_rows.append(_label("", 30, Vector3(0.0, 0.42 - float(i) * 0.115, 0.008)))
	for i in 4:
		var card:=MeshInstance3D.new();var shape:=QuadMesh.new();shape.size=Vector2(.94,.21);card.mesh=shape;card.position=Vector3(0,.40-i*.245,.003)
		var finish:=StandardMaterial3D.new();finish.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;finish.albedo_color=Color("252a30");card.material_override=finish;_panel.add_child(card);_category_cards.append(card)
		var edge:=MeshInstance3D.new();var strip:=QuadMesh.new();strip.size=Vector2(.94,.006);edge.mesh=strip;edge.position=card.position+Vector3(0,-.102,.002)
		var border:=StandardMaterial3D.new();border.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;border.albedo_color=Color("89939a");edge.material_override=border;_panel.add_child(edge);_category_edges.append(edge)
		var icon:=Sprite3D.new();icon.texture=load("res://assets/ui/settings_%d.svg"%i);icon.pixel_size=.00065;icon.position=card.position+Vector3(0,.037,.008);_panel.add_child(icon);_category_icons.append(icon)
	_spatial_hint = _label("", 18, Vector3(0.0, -0.58, 0.008))
	_spatial_hint.modulate = Color(0.53, 0.7, 0.75)

	_difficulty_slider = Node3D.new()
	_difficulty_slider.position = Vector3(0.0, 0.355, 0.014)
	_panel.add_child(_difficulty_slider)
	_slider_quad(Vector2(0.9, 0.012), Color(0.15, 0.22, 0.26))
	_difficulty_fill = _slider_quad(Vector2(0.9, 0.012), Color("40e8ef"))
	_difficulty_fill.position.z = 0.001
	_difficulty_knob = _slider_quad(Vector2(0.016, 0.035), Color(0.95, 0.96, 0.98))
	_difficulty_knob.position.z = 0.002
	_difficulty_slider.visible = false
	for i in range(MENU_ROWS):
		var track := Node3D.new()
		track.position = Vector3(0, .42-i*.115-.035, .02)
		_panel.add_child(track)
		_numeric_tracks.append(track)
		var old := _difficulty_slider
		_difficulty_slider = track
		_slider_quad(Vector2(.9,.012), Color(.15,.22,.26))
		var fill := _slider_quad(Vector2(.9,.012),Color("40e8ef"))
		fill.position.z=.001
		_numeric_fills.append(fill)
		var knob := _slider_quad(Vector2(.018,.03),Color.WHITE)
		knob.position.z=.002
		_numeric_knobs.append(knob)
		_difficulty_slider=old
	for i in range(2):
		var line := MeshInstance3D.new()
		var box := BoxMesh.new();box.size=Vector3(.002,.002,1)
		line.mesh=box
		var material := StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color=Color(.2,.85,1)
		line.material_override=material
		add_child(line);_pointer_lines.append(line);line.visible=false
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new();sphere.radius=.007;sphere.height=.014
		dot.mesh=sphere;dot.material_override=material
		add_child(dot);_pointer_dots.append(dot);dot.visible=false

func _slider_quad(size: Vector2, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	visual.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Track, fill and knob occupy progressively nearer planes. Depth testing
	# guarantees their ordering independent of opaque draw submission order.
	material.no_depth_test = false
	material.albedo_color = color
	visual.material_override = material
	_difficulty_slider.add_child(visual)
	return visual

func _label(text_value: String, size: int, pos: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = size
	label.pixel_size = 0.0013
	label.outline_size = 2
	label.position = pos
	label.no_depth_test = true
	_panel.add_child(label)
	return label

func _build_desktop_panel() -> void:
	_desktop_layer = CanvasLayer.new()
	_desktop_layer.layer = 30
	add_child(_desktop_layer)
	var background := ColorRect.new()
	background.color = Color(0.008, 0.015, 0.025, 0.9)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desktop_layer.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(440, 0)
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	var title := Label.new()
	_desktop_title = title
	title.text = "ASHFALL / FIELD SYSTEMS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("40e8ef"))
	column.add_child(title)
	for i in range(MENU_ROWS):
		var row := HBoxContainer.new()
		column.add_child(row)
		_desktop_rows.append(row)
		var button := Button.new()
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose.bind(i))
		row.add_child(button)
		_buttons.append(button)
		if i < MENU_ROWS:
			var volume_label := Label.new()
			volume_label.custom_minimum_size = Vector2(170, 48)
			row.add_child(volume_label)
			_volume_labels.append(volume_label)
			var slider := HSlider.new()
			slider.min_value = 0.0
			slider.max_value = 100.0
			slider.step = 5.0
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slider.custom_minimum_size.x = 220
			slider.value_changed.connect(_on_numeric_slider.bind(i))
			row.add_child(slider)
			_sliders.append(slider)
	_desktop_loadout_grid=GridContainer.new();_desktop_loadout_grid.name="ColoredInventoryGrid";_desktop_loadout_grid.columns=6;_desktop_loadout_grid.layout_direction=Control.LAYOUT_DIRECTION_RTL
	_desktop_loadout_grid.add_theme_constant_override("h_separation",12);_desktop_loadout_grid.add_theme_constant_override("v_separation",12)
	column.add_child(_desktop_loadout_grid)
	for i in range(MENU_ROWS):
		var card:=Button.new();card.custom_minimum_size=Vector2(180,112);card.expand_icon=true;card.add_theme_constant_override("icon_max_width",160)
		card.pressed.connect(_choose.bind(i));_desktop_loadout_grid.add_child(card);_desktop_loadout_buttons.append(card)
	_desktop_loadout_grid.hide()
	var hint := Label.new()
	_desktop_hint = hint
	hint.text = "TAB to return | Changes apply immediately"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

func _build_vignette() -> void:
	_vignette = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	_vignette.mesh = quad
	_vignette.position.z = -0.2
	_vignette.extra_cull_margin = 100.0
	_vignette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled; uniform float strength = 0.0; uniform float danger = 0.0; uniform float obstruction = 0.0; void vertex(){POSITION=vec4(VERTEX.xy,0.0,1.0);} void fragment(){float r=length((UV-vec2(0.5))*2.0); float comfort=smoothstep(0.55,1.05,r)*strength; float damage=smoothstep(0.62,1.08,r)*danger; float total=max(comfort,damage); vec3 edge_color=mix(vec3(0.005,0.008,0.012),vec3(0.42,0.012,0.006),clamp(damage/max(total,0.001),0.0,1.0)); ALBEDO=mix(edge_color,vec3(0.0),obstruction); ALPHA=max(total,obstruction);}"
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = shader
	_vignette_material.render_priority = 127
	_vignette.material_override = _vignette_material
	player.get_view_camera().add_child(_vignette)
	_vignette.visible = false

func _input(event: InputEvent) -> void:
	if player == null or player.xr_enabled or front_menu_visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		set_open(not is_open)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if player == null or front_menu_visible:
		return
	_settings_flush+=delta
	if _settings_dirty and _settings_flush>=.1:
		_settings_dirty=false;_settings_flush=0
		settings_changed.emit(get_settings())
	if catalog_ui==null or settings_page!="loadout":_update_slider_pointers()
	if player.xr_enabled:
		var toggle := player.is_hand_input_ready(player.left_hand) and player.left_hand.is_button_pressed("menu_button")
		if toggle and not _toggle_held:
			set_open(not is_open)
		_toggle_held = toggle
		var dominant: XRController3D = player.left_hand if player.dominant_hand == "left" else player.right_hand
		var select := player.is_hand_input_ready(dominant) and dominant.is_button_pressed("ax_button")
		if catalog_ui==null or settings_page!="loadout":_loadout_gesture(delta, player.tracking_available and player.is_hand_input_ready(dominant) and not player.head_obstructed, select, dominant.is_button_pressed("grip_click") or dominant.get_float("grip") > .65)
		if is_open and not (settings_page=="loadout" and catalog_ui!=null):
			var nav := 0.0
			if player.is_hand_input_ready(player.left_hand):
				nav = player.left_hand.get_vector2("primary").y
			if absf(nav) < 0.3 and player.is_hand_input_ready(player.right_hand):
				nav = player.right_hand.get_vector2("primary").y
			if settings_page=="loadout":
				var horizontal:=0.0
				if player.is_hand_input_ready(player.left_hand):horizontal=player.left_hand.get_vector2("primary").x
				if absf(horizontal)<.3 and player.is_hand_input_ready(player.right_hand):horizontal=player.right_hand.get_vector2("primary").x
				if maxf(absf(nav),absf(horizontal))<.3:_nav_ready=true
				elif maxf(absf(nav),absf(horizontal))>.65 and _nav_ready:
					selected=clampi(selected+(-3*int(signf(nav)) if absf(nav)>absf(horizontal) else int(signf(horizontal))),0,_labels().size()-1)
					_nav_ready=false;_refresh()
			elif absf(nav) < 0.3:
				_nav_ready = true
			elif absf(nav) > 0.65 and _nav_ready:
				selected = posmod(selected - int(signf(nav)), _labels().size())
				_nav_ready = false
				_refresh()
			if (audio_page or settings_page != "root") and settings_page!="loadout":
				var adjust := 0.0
				if player.is_hand_input_ready(player.right_hand):
					adjust = player.right_hand.get_vector2("primary").x
				if settings_page == "game" and selected == 0:
					adjust_difficulty_stick(adjust if absf(nav) < 0.4 else 0.0, delta)
				elif absf(adjust) < 0.3:
					_adjust_ready = true
				elif absf(adjust) > 0.65 and _adjust_ready and absf(nav) < 0.4:
					if audio_page:
						adjust_audio(selected, signf(adjust) * 0.05)
					else:
						_adjust_setting(selected, signf(adjust))
					_adjust_ready = false
			if settings_page != "loadout" and select and not _select_held and numeric_setting(selected).is_empty():
				_choose(selected)
		_select_held = select
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var target := 0.7 if vignette_enabled and player.xr_enabled and not is_open and (horizontal_speed > 1.0 or player.gliding) else 0.0
	_vignette_strength = move_toward(_vignette_strength, target, delta * 2.0)
	_damage_time = maxf(0.0, _damage_time - delta)
	var damage := _damage_strength * (_damage_time / DAMAGE_PULSE_DURATION) if player.xr_enabled else 0.0
	var obstructed := player.xr_enabled and player.head_obstructed
	_obstruction_fade = move_toward(_obstruction_fade, 1.0 if obstructed else 0.0, delta / (0.12 if obstructed else 0.2))
	_vignette_material.set_shader_parameter("strength", _vignette_strength)
	_vignette_material.set_shader_parameter("danger", damage)
	_vignette_material.set_shader_parameter("obstruction", _obstruction_fade)
	_vignette.visible = _vignette_strength > 0.001 or damage > 0.001 or _obstruction_fade > 0.001
	if _damage_time <= 0.0:
		_damage_strength = 0.0

func flash_damage(strength: float = 0.35) -> void:
	# Peripheral hit feedback remains available with comfort masking disabled.
	# A repeated hit refreshes a short pulse without accumulating opacity.
	if strength <= 0.0:
		return
	_damage_strength = maxf(_damage_strength, clampf(strength, 0.0, 0.65))
	_damage_time = DAMAGE_PULSE_DURATION

func set_open(value: bool) -> void:
	if player == null or value == is_open:
		return
	_cancel_loadout_gesture()
	is_open = value
	if not value and catalog_ui!=null:catalog_ui.set_active(false)
	_slider_pointer.reset()
	if _settings_dirty:
		_settings_dirty=false
		settings_changed.emit(get_settings())
	player.inventory_open=false
	player.input_enabled = not value
	if value:
		_difficulty_tick = 0.0
		player.reset_motion()
		audio_page = false
		settings_page = "pause"
		settings_from_home0992=false
		_adjust_ready = true
		selected = 0
		position_panel_at_eye_level()
		_refresh()
	_panel.visible = value and player.xr_enabled
	_desktop_layer.visible = value and not player.xr_enabled
	if not player.xr_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	if not value:
		if player.xr_enabled:
			player.require_neutral_input()
		resumed.emit()

func _choose(index: int) -> void:
	if index<0 or index>=_labels().size():return
	preload("res://scripts/sound_cues099.gd").play_ui(self,"menu_click")
	if settings_page=="pause":
		match index:
			0:set_open(false)
			1:settings_page="root";selected=0;_refresh()
			2:set_open(false);vertical_combat_reinitialize_requested.emit()
			3:set_open(false);home_requested.emit()
		return
	# Numeric controls are dragged, never cycled with A or a button click.
	if not numeric_setting(index).is_empty(): return
	if settings_page != "root":
		_adjust_setting(index, 1.0)
		return
	if audio_page:
		if index < AUDIO_BUSES.size():
			adjust_audio(index, 0.05)
		else:
			audio_page = false
			selected = 4
			_refresh()
		return
	match index:
		0:settings_page="movement"
		1:set_open(false);vertical_combat_reinitialize_requested.emit();return
		2:settings_page="weapons"
		3:settings_page="general"
		4:
			if settings_from_home0992:set_open(false)
			else:settings_page="pause";selected=1;_refresh()
			return
	selected=0;_refresh()

func get_settings() -> Dictionary:
	return {"audio_defaults_revision":993,"hud_style":hud_style,"master_volume":master_volume,"hud_size":hud_size, "enemy_damage_multiplier":enemy_damage_multiplier, "player_damage_multiplier":player_damage_multiplier, "glide_steering_gain":player.glide_steering_gain, "movement_settings_version":3, "controls_tuning_revision":1, "measurement_reference_revision":3,"measurement_visual_correction":48.0/41.5, "reference_unit_meters":AshPlayer.MEASURED_REFERENCE_UNIT_METERS, "vertical_combat_target_top_height_m":player.vertical_combat_target_top_height_m, "vertical_combat_height_semantics":"standing_head_top", "vertical_combat_stature_revision":1, "vertical_combat_top_to_eye_m":AshPlayer.AUTHORED_HEAD_TOP_TO_EYE_M, "sprint_binding":player.sprint_binding, "snap_degrees": player.snap_degrees, "comfort_speed": comfort_speed, "walk_speed_multiplier": player.walk_speed_multiplier, "dominant_hand": player.dominant_hand, "vignette_enabled": vignette_enabled, "audio_volumes": audio_volumes.duplicate(), "graphics_quality": graphics_quality, "difficulty": difficulty, "forward_reference": player.forward_reference, "turning_style": player.turning_style, "smooth_turn_speed": player.smooth_turn_speed, "smooth_ease_in": player.smooth_ease_in, "smooth_analog": player.smooth_analog, "fling_power": player.fling_power, "glide_speed_mps":player.glide_speed_mps, "sprint_slow_gain":player.sprint_slow_gain, "sprint_fast_gain":player.sprint_fast_gain, "sprint_double_press_window":player.sprint_double_press_window, "sprint_stamina_seconds":player.sprint_stamina_seconds, "sprint_recovery_seconds":player.sprint_recovery_seconds, "weapon_settings": weapon_settings.duplicate()}

func _adjust_setting(index: int, direction: float) -> void:
	if _host_controlled1000(index):return
	if settings_page=="general":
		if index==5:vignette_enabled=not vignette_enabled;settings_changed.emit(get_settings())
		elif index==6:settings_page="game";selected=0
		elif index==7:settings_page="root";selected=0
		_refresh();return
	var numeric := numeric_setting(index)
	if not numeric.is_empty():
		set_numeric_setting(index, float(numeric.value)+direction*float(numeric.step))
		return
	if settings_page == "loadout":
		if index >= 0 and index < _labels().size() and not _labels()[index] in ["LOCKED","EMPTY"]: loadout_selected.emit(index)
		_refresh()
		return
	if settings_page == "flight":
		if index != 6: return
		settings_page = "turning"; selected = 4
		_refresh()
		return
	if settings_page == "game":
		match index:
			0: difficulty = clampf(snappedf(difficulty + direction * 0.05, 0.01), 0.0, 1.0)
			1: graphics_quality = "balanced" if graphics_quality == "high" else "high"
			5:
				set_open(false)
				vertical_combat_reinitialize_requested.emit()
			6: hud_style="simple" if hud_style=="reference" else "reference"
			7: settings_page = "root"; selected = 5
	elif settings_page == "movement":
		match index:
			0: player.forward_reference = "hand" if player.forward_reference == "head" else "head"
			1:
				var modes := ["snap", "auto_snap", "smooth"]
				player.turning_style = modes[posmod(modes.find(player.turning_style) + int(direction), modes.size())]
			2: player.snap_degrees = _cycle_value(player.snap_degrees, direction * 5.0, 15.0, 180.0)
			3: player.smooth_turn_speed = _cycle_value(player.smooth_turn_speed, direction * 30.0, 30.0, 720.0)
			4: player.fling_power = _cycle_value(player.fling_power, direction * 0.25, 0.0, 5.0)
			5:
				comfort_speed = not comfort_speed
				player.move_speed = AshPlayer.COMFORT_WALK_SPEED if comfort_speed else AshPlayer.WALK_SPEED
			6: settings_page = "turning"; selected = 0
			7: settings_page = "root"; selected = 1
	elif settings_page == "turning":
		match index:
			0: player.smooth_ease_in = not player.smooth_ease_in
			1: player.smooth_analog = not player.smooth_analog
			2: comfort_speed = not comfort_speed; player.move_speed = AshPlayer.COMFORT_WALK_SPEED if comfort_speed else AshPlayer.WALK_SPEED
			3: player.sprint_binding = "left_grip" if player.sprint_binding=="left_stick_click" else "left_stick_click"; player.require_neutral_input()
			4: settings_page = "flight"; selected = 0
			5: reset_movement_settings()
			6: settings_page = "movement"; selected = 6
	elif settings_page == "weapons":
		match index:
			0: weapon_settings.motion_damping = _cycle_value(weapon_settings.motion_damping, direction * 0.05, 0.0, 2.0)
			1: weapon_settings.offhand_influence = _cycle_value(weapon_settings.offhand_influence, direction * 0.05, 0.0, 1.0)
			2: weapon_settings.grip_toggle = not weapon_settings.grip_toggle
			3:
				player.dominant_hand = "left" if player.dominant_hand == "right" else "right"
				player.require_neutral_input()
			4: settings_page = "root"; selected = 2
	_refresh()
	settings_changed.emit(get_settings())

func _cycle_value(value: float, amount: float, minimum: float, maximum: float) -> float:
	var result := snappedf(value + amount, 0.01)
	if result > maximum: return minimum
	if result < minimum: return maximum
	return result

func _saved_number(settings: Dictionary, key: String, fallback: float, minimum: float, maximum: float) -> float:
	var value: Variant = settings.get(key)
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), minimum, maximum)
	return fallback

func apply_settings(settings: Dictionary) -> void:
	hud_style="simple" if settings.get("hud_style")=="simple" else "reference"
	master_volume=clampf(float(settings.get("master_volume",1.0)),0,1)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(master_volume,.0001)))
	# The old key was an eye target. Do not reinterpret provisional 2.0/1.2192
	# saves as stature. Revision 1 migrates the previous five-foot target to six feet.
	player.vertical_combat_target_top_height_m = AshPlayer.DEFAULT_PLAYER_TOP_HEIGHT_M
	if _saved_number(settings,"vertical_combat_stature_revision",0,0,999)>=1:
		player.vertical_combat_target_top_height_m = _saved_number(settings, "vertical_combat_target_top_height_m", AshPlayer.DEFAULT_PLAYER_TOP_HEIGHT_M, .55+AshPlayer.AUTHORED_HEAD_TOP_TO_EYE_M, 2.2+AshPlayer.AUTHORED_HEAD_TOP_TO_EYE_M)
	hud_size = _saved_number(settings, "hud_size", 1.0, 0.65, 1.75)
	player.glide_steering_gain = _saved_number(settings, "glide_steering_gain", .875, .25, 2.5)
	var old_controls := _saved_number(settings,"controls_tuning_revision",0,0,999) < 1
	if old_controls and settings.has("glide_steering_gain"):
		player.glide_steering_gain=clampf(player.glide_steering_gain*.5,.25,2.5)
	player.snap_degrees = _saved_number(settings, "snap_degrees", 30.0, 15.0, 180.0)
	var next_dominant := "left" if settings.get("dominant_hand","right")=="left" else "right"
	if player.dominant_hand!=next_dominant:
		player.dominant_hand=next_dominant
		player.require_neutral_input()
	comfort_speed = bool(settings.get("comfort_speed", false))
	player.walk_speed_multiplier = _saved_number(settings, "walk_speed_multiplier", 1.0, 0.25, 3.0)
	var old_walk:Variant=settings.get("walk_speed_multiplier")
	var version:Variant=settings.get("movement_settings_version",1)
	if (version is int or version is float) and float(version)<2 and (old_walk is float or old_walk is int) and is_finite(float(old_walk)):
		# Pre-v2 saves first convert to the accepted display-scale convention.
		# Reference conversion is already in WALK_SPEED; never multiply the saved gain.
		player.walk_speed_multiplier=clampf(float(old_walk)/1.2,.25,3.0)
	player.sprint_binding="left_grip" if settings.get("sprint_binding")=="left_grip" else "left_stick_click"
	vignette_enabled = bool(settings.get("vignette_enabled", false))
	player.move_speed = AshPlayer.COMFORT_WALK_SPEED if comfort_speed else AshPlayer.WALK_SPEED
	graphics_quality = "balanced" if settings.get("graphics_quality", "high") == "balanced" else "high"
	difficulty = _saved_number(settings, "difficulty", 0.5, 0.0, 1.0)
	enemy_damage_multiplier = _saved_number(settings,"enemy_damage_multiplier",1.0,.25,4.0)
	player_damage_multiplier = _saved_number(settings,"player_damage_multiplier",1.0,.25,4.0)
	player.forward_reference = "hand" if settings.get("forward_reference") == "hand" else "head"
	player.turning_style = str(settings.get("turning_style", "smooth"))
	if not player.turning_style in ["snap", "auto_snap", "smooth"]: player.turning_style = "smooth"
	player.smooth_turn_speed = _saved_number(settings, "smooth_turn_speed", 360.0, 30.0, 720.0)
	player.smooth_ease_in = settings.get("smooth_ease_in", false) == true
	player.smooth_analog = settings.get("smooth_analog", true) != false
	player.fling_power = _saved_number(settings, "fling_power", 1.0, 0.0, 5.0)
	# Legacy independent glide value is ignored; measured flight scales with walk tuning.
	player.sprint_slow_gain = _saved_number(settings, "sprint_slow_gain", AshPlayer.RUN_SPEED/AshPlayer.WALK_SPEED, 1.0, 2.0)
	player.sprint_fast_gain = maxf(player.sprint_slow_gain, _saved_number(settings, "sprint_fast_gain", AshPlayer.SPRINT_SPEED/AshPlayer.WALK_SPEED, 1.0, 2.5))
	if old_controls and is_equal_approx(player.sprint_fast_gain,1.5): player.sprint_fast_gain=AshPlayer.SPRINT_SPEED/AshPlayer.WALK_SPEED
	player.sprint_double_press_window = _saved_number(settings, "sprint_double_press_window", .32, .1, .6)
	player.sprint_stamina_seconds = _saved_number(settings, "sprint_stamina_seconds", 6.0, 2.0, 20.0)
	player.sprint_recovery_seconds = _saved_number(settings, "sprint_recovery_seconds", 4.0, 1.0, 20.0)
	var saved_weapon: Variant = settings.get("weapon_settings", {})
	weapon_settings = WEAPON_SETTINGS_DEFAULTS.duplicate()
	if saved_weapon is Dictionary:
		weapon_settings.motion_damping = _saved_number(saved_weapon, "motion_damping", WEAPON_SETTINGS_DEFAULTS.motion_damping, 0.0, 2.0)
		weapon_settings.offhand_influence = _saved_number(saved_weapon, "offhand_influence", WEAPON_SETTINGS_DEFAULTS.offhand_influence, 0.0, 1.0)
		weapon_settings.grip_toggle = saved_weapon.get("grip_toggle", false) == true
	var saved_volumes: Variant = settings.get("audio_volumes", {})
	if saved_volumes is Dictionary:
		for bus in AUDIO_BUSES:
			if saved_volumes.get(bus) is float or saved_volumes.get(bus) is int:
				var value := float(saved_volumes[bus])
				if is_finite(value): audio_volumes[bus] = clampf(value, 0.0, 1.0)
	if int(settings.get("audio_defaults_revision",0))<993:
		audio_volumes.Music=0.0;audio_volumes.Ambience=0.0
	_apply_audio_volumes()
	_refresh()

func _apply_audio_volumes() -> void:
	for bus in AUDIO_BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
		var value := float(audio_volumes[bus])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))
		AudioServer.set_bus_mute(index, value <= 0.0)

func set_audio_volume(bus: String, value: float) -> void:
	if not AUDIO_BUSES.has(bus) or not is_finite(value):
		return
	audio_volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_audio_volumes()
	_refresh()
	settings_changed.emit(get_settings())

func adjust_audio(index: int, amount: float) -> void:
	if index >= 0 and index < AUDIO_BUSES.size():
		var bus: String = AUDIO_BUSES[index]
		set_audio_volume(bus, float(audio_volumes[bus]) + amount)

func _on_volume_slider(value: float, bus: String) -> void:
	if settings_page == "game":
		set_difficulty(value / 100.0)
	else:
		set_audio_volume(bus, value / 100.0)

func set_difficulty(value: float) -> void:
	if not is_finite(value): return
	difficulty = clampf(value, 0.0, 1.0)
	_refresh()
	settings_changed.emit(get_settings())

func adjust_difficulty_stick(axis: float, delta: float) -> void:
	# Holding the stick sweeps the value rather than requiring repeated flicks.
	# Updates are bounded to 10Hz so persistence does not write every render frame.
	if absf(axis) <= 0.3:
		_difficulty_tick = 0.0
		return
	_difficulty_tick += delta
	if _difficulty_tick >= 0.1:
		var elapsed := minf(_difficulty_tick, 0.2)
		_difficulty_tick = 0.0
		set_difficulty(difficulty + signf(axis) * inverse_lerp(0.3, 1.0, minf(absf(axis), 1.0)) * elapsed * 0.3)

func backpack_is_open()->bool:return is_open and settings_page=="loadout" and catalog_ui!=null

func _refresh() -> void:
	player.inventory_open=backpack_is_open()
	player.input_enabled=not is_open or player.inventory_open
	if catalog_ui!=null:
		var catalog_open:bool=is_open and settings_page=="loadout"
		catalog_ui.set_active(catalog_open)
		if catalog_open:
			catalog_ui.refresh();_panel.hide();_desktop_layer.hide();return
		_panel.visible=is_open and player.xr_enabled;_desktop_layer.visible=is_open and not player.xr_enabled
	var build_version:=str(ProjectSettings.get_setting("application/config/version","unknown"))
	_refresh_loadout_visuals()
	var labels := _labels()
	_desktop_loadout_grid.visible=settings_page=="loadout"
	var grid_icons:Array=loadout_icon_provider.call() if loadout_icon_provider.is_valid() else []
	for i in _desktop_loadout_buttons.size():
		var card:=_desktop_loadout_buttons[i];card.visible=settings_page=="loadout" and i<labels.size()
		card.icon=grid_icons[i] if i<grid_icons.size() else null
		card.tooltip_text=labels[i] if i<labels.size() else ""
		card.text=labels[i] if i<labels.size() else ""
		card.disabled=i>=labels.size() or labels[i] in ["LOCKED","EMPTY"]
		card.modulate=Color(.72,.75,.8) if i<labels.size() and labels[i]=="LOCKED" else (Color(1.0,.76,.4) if i==selected else Color.WHITE)
	_difficulty_slider.visible = false
	_difficulty_fill.scale.x = maxf(difficulty, 0.001)
	_difficulty_fill.position.x = -0.45 + 0.45 * difficulty
	_difficulty_knob.position.x = -0.45 + 0.9 * difficulty
	_spatial_title.text = "ASHFALL / " + ("AUDIO LEVELS" if audio_page else ("FIELD SYSTEMS" if settings_page == "root" else settings_page.to_upper()))
	if settings_page == "root" and not audio_page: _spatial_title.text = "SETTINGS"
	if settings_page=="pause":_spatial_title.text="ASHFALL"
	_desktop_title.text = "ASHFALL " + build_version + " / " + campaign_identity
	_spatial_hint.text = ""
	_desktop_hint.text = "0% EASIER  <---- DIFFICULTY ---->  100% CHALLENGING\nTAB to return | Changes apply immediately" if settings_page == "game" else "TAB to return | Changes apply immediately"
	if settings_page == "game":
		_spatial_hint.text = ""
	for i in _category_cards.size():
		_category_cards[i].visible=settings_page=="root" and not audio_page;_category_icons[i].visible=_category_cards[i].visible
		_category_cards[i].material_override.albedo_color=Color("225d76") if selected==i else Color("252a30")
		_category_edges[i].visible=_category_cards[i].visible;_category_edges[i].material_override.albedo_color=Color("40e8ef") if selected==i else Color("89939a")
	for i in range(_rows.size()):
		_rows[i].position.y=_menu_row_y(i)
		var active := i < labels.size()
		_numeric_tracks[i].visible = false
		_rows[i].visible = active and settings_page!="loadout"
		_desktop_rows[i].visible = active and settings_page!="loadout"
		if not active:
			continue
		_rows[i].text = "" if settings_page == "loadout" else ((">  " if i == selected else "   ") + labels[i])
		_rows[i].modulate = Color("40e8ef") if i == selected else Color(0.82, 0.9, 0.93)
		_buttons[i].text = "" if settings_page == "loadout" else labels[i]
		_buttons[i].icon = null
		if settings_page == "loadout":
			var icons: Array = loadout_icon_provider.call() if loadout_icon_provider.is_valid() else []
			if i < icons.size(): _buttons[i].icon = icons[i]
			_buttons[i].expand_icon = true
			_buttons[i].add_theme_constant_override("icon_max_width", 100)
		var spec := numeric_setting(i)
		var show_slider := not spec.is_empty()
		_numeric_tracks[i].visible = show_slider
		_rows[i].position.y = _menu_row_y(i) + (.012 if show_slider else 0.0)
		_rows[i].position.x=0;_rows[i].horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_rows[i].font_size=30
		_numeric_tracks[i].position=Vector3(0,.42-i*.115-.035,.02);_numeric_tracks[i].scale=Vector3.ONE
		if settings_page=="general" and show_slider:
			_rows[i].position=Vector3(-.08,_menu_row_y(i),.008);_rows[i].horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;_rows[i].font_size=23
			_numeric_tracks[i].position=Vector3(.25,_menu_row_y(i),.02);_numeric_tracks[i].scale=Vector3(.52,4,1)
			_rows[i].text=labels[i]+"  %d%%"%int(float(spec.value)*100)
		_buttons[i].visible = not show_slider
		_sliders[i].visible = show_slider
		_volume_labels[i].visible = show_slider
		if show_slider:
			var fraction := inverse_lerp(float(spec.min),float(spec.max),float(spec.value))
			_numeric_fills[i].scale.x=maxf(.001,fraction)
			_numeric_fills[i].position.x=-.45+.45*fraction
			_numeric_knobs[i].position.x=-.45+.9*fraction
			_volume_labels[i].text=labels[i]
			_sliders[i].set_block_signals(true)
			_sliders[i].min_value=spec.min
			_sliders[i].max_value=spec.max
			_sliders[i].step=spec.step
			_sliders[i].set_value_no_signal(spec.value)
			_sliders[i].set_block_signals(false)

	if _pause_style0993:_pause_style0993.refresh(self)

func numeric_setting(index: int) -> Dictionary:
	if _host_controlled1000(index):return {}
	if settings_page=="general" and index>=0 and index<5:
		var value:float=master_volume if index==0 else audio_volumes[["SFX","Music","Voice","Ambience"][index-1]]
		return {"min":0.0,"max":1.0,"step":.01,"value":value}
	if settings_page == "flight":
		match index:
			0: return {}
			1: return {"min":1.0,"max":2.0,"step":.05,"value":player.sprint_slow_gain}
			2: return {"min":player.sprint_slow_gain,"max":2.5,"step":.05,"value":player.sprint_fast_gain}
			3: return {"min":.25,"max":2.5,"step":.05,"value":player.glide_steering_gain}
			4: return {"min":2.0,"max":20.0,"step":.5,"value":player.sprint_stamina_seconds}
			5: return {"min":1.0,"max":20.0,"step":.5,"value":player.sprint_recovery_seconds}
	if audio_page and index>=0 and index<4:
		return {"min":0.0,"max":1.0,"step":.01,"value":audio_volumes[AUDIO_BUSES[index]]}
	if settings_page=="game" and index==0:
		return {"min":0.0,"max":1.0,"step":.01,"value":difficulty}
	if settings_page=="game" and index==2:
		return {"min":.65,"max":1.75,"step":.05,"value":hud_size}
	if settings_page=="game" and index in [3,4]:
		return {"min":.25,"max":4.0,"step":.25,"value":enemy_damage_multiplier if index==3 else player_damage_multiplier}
	if settings_page=="movement":
		match index:
			2:return {"min":15.0,"max":180.0,"step":5.0,"value":player.snap_degrees}
			3:return {"min":30.0,"max":720.0,"step":5.0,"value":player.smooth_turn_speed}
			4:return {"min":0.0,"max":5.0,"step":.05,"value":player.fling_power}
			5:return {"min":.25,"max":3.0,"step":.05,"value":player.walk_speed_multiplier}
	if settings_page=="weapons" and index in [0,1]:
		return {"min":0.0,"max":2.0 if index==0 else 1.0,"step":.01,"value":weapon_settings.motion_damping if index==0 else weapon_settings.offhand_influence}
	return {}

func set_numeric_setting(index: int, value: float) -> void:
	var spec := numeric_setting(index)
	if spec.is_empty() or not is_finite(value):return
	value=clampf(snappedf(value,float(spec.step)),float(spec.min),float(spec.max))
	if is_equal_approx(value,float(spec.value)):return
	if settings_page=="general":
		if index==0:master_volume=value;AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value,.0001)))
		else:audio_volumes[["SFX","Music","Voice","Ambience"][index-1]]=value;_apply_audio_volumes()
	elif settings_page == "flight":
		match index:
			0: pass # Flight derives from the measured12m/s default.
			1:
				player.sprint_slow_gain = value
				player.sprint_fast_gain = maxf(value, player.sprint_fast_gain)
			2: player.sprint_fast_gain = value
			3: player.glide_steering_gain = value
			4: player.sprint_stamina_seconds = value
			5: player.sprint_recovery_seconds = value
	elif audio_page:
		audio_volumes[AUDIO_BUSES[index]]=value
		_apply_audio_volumes()
	elif settings_page=="game":
		if index==0: difficulty=value
		elif index==2: hud_size=value
		elif index==3: enemy_damage_multiplier=value
		elif index==4: player_damage_multiplier=value
	elif settings_page=="movement":
		match index:
			2:player.snap_degrees=value
			3:player.smooth_turn_speed=value
			4:player.fling_power=value
			5:player.walk_speed_multiplier=value
	elif settings_page=="weapons":
		if index==0:weapon_settings.motion_damping=value
		else:weapon_settings.offhand_influence=value
	_settings_dirty=true
	_refresh()

func _on_numeric_slider(value: float,index: int) -> void:
	set_numeric_setting(index,value)

func reset_movement_settings() -> void:
	player.forward_reference="head";player.turning_style="smooth";player.snap_degrees=30.0
	player.smooth_turn_speed=360.0;player.fling_power=1.0;player.walk_speed_multiplier=1.0
	player.smooth_ease_in=false;player.smooth_analog=true
	comfort_speed=false;player.move_speed=AshPlayer.WALK_SPEED
	player.sprint_binding="left_stick_click";vignette_enabled=false
	player.glide_steering_gain=.875;player.sprint_slow_gain=AshPlayer.RUN_SPEED/AshPlayer.WALK_SPEED;player.sprint_fast_gain=AshPlayer.SPRINT_SPEED/AshPlayer.WALK_SPEED
	player.sprint_double_press_window=.32;player.sprint_stamina_seconds=6.0;player.sprint_recovery_seconds=4.0
	player.require_neutral_input()
	_settings_dirty=true
	_refresh()

func reset_weapon_settings() -> void:
	weapon_settings=WEAPON_SETTINGS_DEFAULTS.duplicate()
	_refresh()
	settings_changed.emit(get_settings())

func _update_slider_pointers() -> void:
	for i in range(2):
		_pointer_lines[i].visible=false
		_pointer_dots[i].visible=false
	if not is_open or not player.xr_enabled:return
	var targets:Array=[]
	for i in range(_labels().size()):
		var slider := not numeric_setting(i).is_empty()
		var y := _menu_row_y(i)
		if settings_page=="loadout":
			if _labels()[i] in ["LOCKED","EMPTY"]:continue
			var cell:=loadout_cell_position(i)
			targets.append({"id":i,"slider":false,"rect":Rect2(cell.x-.095,cell.y-.105,.19,.21)});continue
		if settings_page=="pause":
			targets.append({"id":i,"slider":false,"rect":Rect2(-.29,y-.105,.58,.21)});continue
		targets.append({"id":i,"slider":slider,"rect":(Rect2(.016,y-.025,.468,.05) if settings_page=="general" else Rect2(-.45,y-.035-.025,.9,.05)) if slider else (Rect2(-.47,y-.07,.94,.21) if settings_page=="root" and i<4 else Rect2(-.60,y-.05,1.2,.10))})
	for i in range(2):
		var hand:XRController3D=player.left_hand if i==0 else player.right_hand
		var valid := player.is_hand_input_ready(hand)
		var ray_basis := hand.global_basis * Basis(Vector3.RIGHT,-PI/2.0)
		var origin := hand.global_position
		var direction := -ray_basis.z
		var trigger := maxf(hand.get_float("trigger"),1.0 if hand.is_button_pressed("trigger_click") else 0.0)
		var result:Dictionary=_slider_pointer.step("left" if i==0 else "right",origin,direction,trigger,valid,_panel.global_transform,targets)
		if not valid:continue
		var endpoint := origin+direction*1.4
		if result.hovered>=0 or result.dragging:
			endpoint=_panel.to_global(result.point)
			_pointer_dots[i].global_position=endpoint
			_pointer_dots[i].visible=true
		_pointer_lines[i].global_position=(origin+endpoint)*.5
		_pointer_lines[i].look_at(endpoint,Vector3.RIGHT if absf(direction.dot(Vector3.UP))>.98 else Vector3.UP)
		_pointer_lines[i].scale=Vector3(1,1,maxf(.001,origin.distance_to(endpoint)))
		_pointer_lines[i].visible=true
		if settings_page == "loadout" and result.hovered >= 0 and selected != result.hovered:
			selected=result.hovered
			_refresh()
		if result.index>=0:
			selected=result.index
			var spec := numeric_setting(selected)
			if not spec.is_empty() and (result.dragging or result.pressed) and float(result.value)>=0.0:
				set_numeric_setting(selected,lerpf(float(spec.min),float(spec.max),float(result.value)))
			elif result.pressed and not (settings_page == "loadout" and (_drop_a or _drop_grip or _drop_consumed)):
				_choose(selected)
				_slider_pointer.reset()
				break

func position_panel_at_eye_level() -> void:
	var camera := player.get_view_camera()
	var forward := -camera.global_basis.z
	forward.y=0.0
	if forward.length_squared()<.001:forward=-player.global_basis.z
	forward.y=0.0
	forward=forward.normalized()
	# The board itself is centered on its origin (1.3m x1.48m), not its title.
	# Snapshot yaw and eye height; head pitch/roll must not lift or tilt controls.
	_panel.global_transform=Transform3D(Basis.looking_at(forward,Vector3.UP),camera.global_position+forward*1.6)









func _cancel_loadout_gesture() -> void:
	_drop_armed=false; _drop_a=false; _drop_grip=false; _drop_consumed=true
	_drop_elapsed=0.; _drop_index=-1
	_set_drop_progress(0.)

func _loadout_gesture(delta: float, valid: bool, a: bool, grip: bool) -> void:
	var active := is_open and settings_page == "loadout"
	if not active or not valid:
		_cancel_loadout_gesture(); _drop_page=active
		return
	if not _drop_page:
		_cancel_loadout_gesture(); _drop_page=true
	if not _drop_armed:
		if not a and not grip: _drop_armed=true; _drop_consumed=false; _drop_index=selected
		return
	if selected != _drop_index:
		_drop_elapsed=0.; _drop_consumed=a or grip; _drop_index=selected; _set_drop_progress(0.)
	var item := selected >= 0 and selected < _labels().size()
	if grip and not _drop_grip and item and not _drop_consumed:
		_drop_consumed=true; loadout_dropped.emit(selected)
	elif a and not _drop_a:
		set_open(false);return
	elif a and not _drop_consumed and item:
		_drop_elapsed+=maxf(delta,0.); _set_drop_progress(_drop_elapsed/LOADOUT_DROP_SECONDS)
		if _drop_elapsed>=LOADOUT_DROP_SECONDS:
			_drop_consumed=true; _set_drop_progress(0.); loadout_dropped.emit(selected)
	elif not a and _drop_a:
		var choose := not _drop_consumed
		_drop_elapsed=0.; _set_drop_progress(0.); _drop_consumed=false
		if choose: _choose(selected)
	if not a and not grip: _drop_consumed=false
	_drop_a=a; _drop_grip=grip

func _build_loadout_visuals() -> void:
	for i in range(MENU_ROWS):
		var icon := MeshInstance3D.new()
		icon.name="LoadoutPicture%d"%i
		var quad := QuadMesh.new(); quad.size=Vector2(.17,.14)
		icon.mesh=quad; icon.position=loadout_cell_position(i)
		var material := StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		icon.material_override=material
		_panel.add_child(icon); _loadout_icons.append(icon)
		var caption:=_label("",21,loadout_cell_position(i)+Vector3(0,-.098,.003));caption.name="LoadoutName%d"%i
	var shader := Shader.new()
	shader.code="shader_type spatial; render_mode unshaded,cull_disabled,blend_mix; uniform float progress=0.; void fragment(){vec2 p=UV-vec2(.5); float r=length(p); float a=mod(atan(p.x,-p.y)+6.283185,6.283185)/6.283185; ALBEDO=vec3(1.,.63,.26); ALPHA=(1.-smoothstep(.035,.045,abs(r-.40)))*step(a,progress)*step(.001,progress);}"
	_drop_material=ShaderMaterial.new(); _drop_material.shader=shader
	_drop_ring=MeshInstance3D.new()
	var quad := QuadMesh.new(); quad.size=Vector2(.065,.065)
	_drop_ring.mesh=quad; _drop_ring.material_override=_drop_material
	_panel.add_child(_drop_ring)
	_desktop_drop_ring=ColorRect.new(); _desktop_drop_ring.size=Vector2(36,36)
	_desktop_drop_ring.position=Vector2(24,24); _desktop_drop_ring.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var flat := Shader.new()
	flat.code="shader_type canvas_item; uniform float progress=0.; void fragment(){vec2 p=UV-vec2(.5); float r=length(p); float a=mod(atan(p.x,-p.y)+6.283185,6.283185)/6.283185; COLOR=vec4(1.,.63,.26,(1.-smoothstep(.035,.045,abs(r-.40)))*step(a,progress)*step(.001,progress));}"
	_desktop_drop_material=ShaderMaterial.new(); _desktop_drop_material.shader=flat
	_desktop_drop_ring.material=_desktop_drop_material; _desktop_layer.add_child(_desktop_drop_ring)
	_set_drop_progress(0.)

func _set_drop_progress(value: float) -> void:
	if not is_instance_valid(_drop_ring):return
	value=clampf(value,0.,1.)
	_drop_material.set_shader_parameter("progress",value)
	_desktop_drop_material.set_shader_parameter("progress",value)
	_drop_ring.visible=value>0. and settings_page=="loadout"
	_desktop_drop_ring.visible=_drop_ring.visible
	_drop_ring.position=loadout_cell_position(selected)+Vector3(.13,-.07,.012)

func _refresh_loadout_visuals() -> void:
	var icons: Array = loadout_icon_provider.call() if loadout_icon_provider.is_valid() else []
	for i in range(_loadout_icons.size()):
		var icon := _loadout_icons[i]
		icon.position=loadout_cell_position(i)
		icon.visible=settings_page=="loadout" and i<icons.size()
		var caption:=_panel.get_node("LoadoutName%d"%i) as Label3D
		caption.visible=icon.visible;caption.position=icon.position+Vector3(0,-.098,.003)
		caption.text=_labels()[i] if icon.visible and i<_labels().size() else ""
		if icon.visible:
			icon.material_override.albedo_texture=icons[i]
			icon.material_override.albedo_color=Color(.72,.75,.8) if caption.text=="LOCKED" else (Color(1,.63,.26) if i==selected else Color.WHITE)
	if settings_page!="loadout":
		_drop_page=false; _cancel_loadout_gesture()





func loadout_cell_position(index:int)->Vector3:
	return Vector3(.50-index*.20,.18,.018)




func _menu_row_y(index:int)->float:
	if settings_page=="pause":return .31-index*.235
	if settings_page=="root" and not audio_page:return .34-index*.245 if index<4 else -.61
	return .42-index*.115
