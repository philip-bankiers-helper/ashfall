extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const WeaponScript = preload("res://scripts/weapon.gd")
const WeaponRackScript = preload("res://scripts/weapon_rack.gd")
const WorldScript = preload("res://scripts/world.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const MenuScript = preload("res://scripts/menu.gd")
const AmbienceScript = preload("res://scripts/ambience.gd")
const MusicScript = preload("res://scripts/music.gd")
const AudioBank = preload("res://scripts/audio_bank.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const TrainingScript = preload("res://scripts/training.gd")
const RagdollScript = preload("res://scripts/ragdoll.gd")
const NavigationScript = preload("res://scripts/guard_routes.gd")
const TelemetryScript = preload("res://scripts/telemetry.gd")
const Ballistics = preload("res://scripts/ballistic_query.gd")
const SAVE_PATH = "user://campaign.json"
const EXPANDED_SAVE_PATH = "user://campaign-expanded.json"
const CampaignProgress = preload("res://scripts/campaign_progress.gd")
const ExtensionScript = preload("res://scripts/campaign_extension.gd")
const InterferenceScript = preload("res://scripts/interference_unit.gd")
const GateScript = preload("res://scripts/spillway_gate.gd")
var network_bridge:Node
var front_menu:Node3D
var active_sandbox_map:Node3D
var front_end_active:=false
var _title_was_holstered:=false
var _desktop_crosshair:Label
var extended_campaign := false
var missions: Array[Dictionary] = []
var campaign_extension
var interference_units: Array = []
var spillway_gate
const CHAPTERS = ["01  /  DEAD AIR", "02  /  THE LONG FALL", "03  /  LAST LIGHT", "04  /  DOWNDRAFT"]
const ORDERS = ["Activate relay", "Activate turbine bypass", "Activate uplink", "Clear extraction pad"]
const RADIO = ["MARA: The storm severed every line out of the valley. Those machines are guarding a dead station. Get its relay back online. We have people waiting for that signal.", "MARA: We have a carrier, but no power. The turbine bypass is on the high gantry. Climb the steelwork. Spread your arms when you launch - the wing rig will catch you.", "MARA: Power is holding. The summit uplink is your last stop. Security has marked the antenna for demolition. Beat them there. Give this valley a way home.", "MARA: The signal is out. Glide back to the blue landing pad. A Warden is guarding extraction. Its armor opens when it attacks. Dodge the warning, then hit the orange core. Our pilot is inbound. You are not staying behind."]
var player
var weapon
var field_builder: Node3D
var building_input: Node
var body_visual: Node3D
var world
var xr_enabled = false
var weapon_pickup_props: Node3D
var weapon_inventory: Node3D
var ammo_pickups: Node3D
var item_catalog_088:Node
var world_ping: Node3D
var impact_marks: Node3D
var navigation_routes: Node3D
var telemetry = TelemetryScript.new()
var _xr_interface: OpenXRInterface
var _xr_focus_suspended:=false
var _xr_render_suspended:=false
var _xr_terminal:=false
var _xr_input_was_enabled:=true
var _xr_saved_viewports:Dictionary={}
var chapter = 0
var health = 100.0
var shield := 100.0
var combat_hud: Node3D
var field_consumables: Node3D
var practice_dummy: Node3D
var rescue_dummy:Node3D
var revive_paddles:Node3D
const DamageFeedback = preload("res://scripts/damage_feedback.gd")
const STATION_SCREEN_HEIGHT := 0.65
var enemies: Array = []
var total_kills = 0
var objective_nodes: Array[Node3D] = []
var hud: Label
var radio_label: Label
var center_label: Label
var mission_label: Label
var vr_label: Label3D
var vr_cue: Label3D
var _hud_bottom: Control
var _hud_controls: Label
var _caption_source := ""
var _caption_pages: PackedStringArray = []
var _caption_index := 0
var _caption_clock := 0.0
var _caption_pending := false
var _last_radio_remaining := 0.0
var toast = ""
var toast_time = 0.0
var radio_time = 0.0
var radio_text = ""
var damage_timer = 0.0
var complete = false
var dead = false
var paused = false
var vertical_combat: Node3D
var aim_reticle: Node3D
var play_time = 0.0
var frame_samples: Array[float] = []
var perf_timer = 0.0
var save_data: Dictionary = {}
var ui_layer: CanvasLayer
var overlay: ColorRect
var start_panel: PanelContainer
var sounds: Dictionary = {}
var _cue_players: Array[AudioStreamPlayer] = []
var _cue_cursor := 0
var _cue_variant := 0
var encounter_active = false
var field_menu
var radio_audio: AudioStreamPlayer
var ambience
var music
var training
var training_label: Label
var _awareness_timer := 0.0
var _light_exposure := 1.0
var _enemy_awareness := 0.0
var _quitting := false
var waypoint: Label3D
var gpu_samples: Array[float] = []
var _recovery_generation := 0
const EFFECT_POOL_SIZE := 16
var _tracers: Array[MeshInstance3D] = []
var _impacts: Array[MeshInstance3D] = []
var _tracer_times: Array[float] = []
var _impact_times: Array[float] = []
var _tracer_emitters:Array[WeakRef]=[]
var _tracer_ends:Array[Vector3]=[]
var _tracer_cursor := 0
var _impact_cursor := 0

func _ready():
	get_tree().auto_accept_quit = false
	get_viewport().physics_object_picking = false
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var args = OS.get_cmdline_user_args()
	extended_campaign = "--extended" in args
	var xr = XRServer.find_interface("OpenXR")
	_xr_interface = xr as OpenXRInterface
	# OpenXR initializes during engine startup. Do not reload its action map or
	# retry session creation inside the scene after a failed native startup.
	if not "--desktop" in args and xr and xr.is_initialized():
		xr_enabled = true
		_xr_focus_suspended=true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		for sig in ["session_begun", "session_synchronized", "session_focussed", "session_visible", "session_stopping"]:
			if xr.has_signal(sig): xr.connect(sig, _on_xr_session_event.bind(sig))
		for sig in ["session_loss_pending", "instance_exiting"]:
			if xr.has_signal(sig): xr.connect(sig, _on_xr_session_lost.bind(sig))
	telemetry.begin(xr_enabled)
	telemetry.set_build_identity(str(ProjectSettings.get_setting("application/config/version","unknown")), OS.get_executable_path())
	if "--require-vr" in args and not xr_enabled:
		set_process(false)
		push_error("HEADSET UNAVAILABLE: enter Quest PC Link with headset awake, then relaunch. Desktop debug requires Launch-Desktop.cmd.")
		telemetry.finish("startup_failed", 2)
		get_tree().quit(2)
		return
	print("ASHFALL_START xr=", xr_enabled, " device=", RenderingServer.get_video_adapter_name())
	world = WorldScript.new()
	add_child(world)
	world.build()
	impact_marks = load("res://scripts/impact_marks.gd").new()
	add_child(impact_marks)
	_configure_missions()
	navigation_routes = NavigationScript.new()
	add_child(navigation_routes)
	if extended_campaign:
		for corridor in campaign_extension.guard_corridors:
			if not navigation_routes.register_corridor(corridor):
				push_error("Campaign guard corridor registration failed")
	player = PlayerScript.new()
	add_child(player)
	player.setup(xr_enabled)
	player.objective_grip_provider = _objective_grip_targets
	player.objective_grip_requested.connect(_on_objective_grip)
	player.exposure_provider = world
	player.tracking_changed.connect(_on_tracking_changed)
	player.position = world.player_spawn
	weapon = WeaponRackScript.new()
	add_child(weapon)
	weapon.setup(player)
	body_visual=load("res://scripts/player_body.gd").new()
	add_child(body_visual)
	body_visual.setup(player)
	var wakes0992:=preload("res://scripts/elbow_wakes0992.gd").new();wakes0992.name="ElbowWakes0992";add_child(wakes0992);wakes0992.setup(player,body_visual)
	aim_reticle = load("res://scripts/aim_reticle.gd").new()
	add_child(aim_reticle)
	aim_reticle.setup(player, weapon, self)
	world_ping = load("res://scripts/world_ping.gd").new()
	add_child(world_ping)
	world_ping.setup(player, self)
	weapon_inventory = load("res://scripts/weapon_inventory.gd").new()
	add_child(weapon_inventory)
	weapon_inventory.setup(player, weapon)
	weapon_pickup_props = weapon_inventory
	ammo_pickups = load("res://scripts/ammo_pickups.gd").new()
	add_child(ammo_pickups)
	ammo_pickups.setup(player, weapon, [Vector3(1.5,0.3,-2), Vector3(2,0.3,-2), Vector3(2.5,0.3,-2)])
	weapon.melee_contact.connect(_on_melee_contact)
	weapon.explosive_launch.connect(_on_explosive_launch)
	weapon.shot.connect(_on_shot)
	weapon.pellet_shot.connect(_on_pellet_shot)
	training = TrainingScript.new()
	add_child(training)
	training.setup(player, weapon)
	_build_ui()
	combat_hud = load("res://scripts/combat_hud.gd").new()
	add_child(combat_hud)
	combat_hud.setup(player, self)
	field_consumables = load("res://scripts/field_consumables.gd").new()
	add_child(field_consumables)
	field_consumables.setup(player, weapon, self)
	field_consumables.feedback.connect(func(message:String):_feedback(message,1.4))
	# Root locomotion worker adds optional player.held_item_provider.
	if "held_item_provider" in player: player.held_item_provider = field_consumables
	practice_dummy = load("res://scripts/practice_dummy.gd").new()
	practice_dummy.name = "PracticeDummy"
	add_child(practice_dummy)
	rescue_dummy=load("res://scripts/rescue_training_dummy.gd").new()
	rescue_dummy.name="RescueTrainingCasualty";add_child(rescue_dummy)
	revive_paddles=load("res://scripts/revive_paddles.gd").new();add_child(revive_paddles)
	revive_paddles.setup(player,weapon)
	revive_paddles.feedback.connect(func(message:String):_feedback(message,1.6))
	_build_objectives()
	_build_sounds()
	_build_effect_pool()
	var effect_follow:=preload("res://scripts/tracer_follow_090.gd").new();add_child(effect_follow);effect_follow.setup(self)
	_build_radio()
	ambience = AmbienceScript.new()
	add_child(ambience)
	ambience.setup(player, world)
	music = MusicScript.new()
	add_child(music)
	field_menu = MenuScript.new()
	add_child(field_menu)
	field_menu.setup(player)
	weapon.backpack_requested.connect(_open_backpack)
	field_menu.loadout_provider = _loadout_labels
	field_menu.loadout_icon_provider = _loadout_icons
	field_menu.loadout_selected.connect(_select_loadout_weapon)
	field_menu.loadout_dropped.connect(_drop_loadout_weapon)
	weapon_inventory.changed.connect(_refresh_loadout)
	field_menu.set_campaign_identity(extended_campaign)
	field_menu.restart_requested.connect(new_campaign)
	field_menu.home_requested.connect(_return_home0992)
	field_menu.quit_requested.connect(_quit_game)
	field_menu.settings_changed.connect(_save_settings)
	field_menu.resumed.connect(func():
		if xr_enabled: _feedback("RELEASE CONTROLS TO RESUME", 2.5))
	if FileAccess.file_exists("user://settings.json"):
		var settings = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
		if settings is Dictionary: field_menu.apply_settings(settings)
	world.set_graphics_quality(field_menu.graphics_quality)
	combat_hud.set_hud_size(field_menu.hud_size)
	combat_hud.style=field_menu.hud_style
	weapon.set_weapon_settings(field_menu.get_settings().get("weapon_settings", {}))
	field_builder = load("res://scripts/field_builder.gd").new()
	add_child(field_builder)
	field_builder.setup(player, weapon, self)
	ammo_pickups._builder=field_builder
	item_catalog_088=load("res://scripts/item_catalog_service_088.gd").new();add_child(item_catalog_088)
	item_catalog_088.setup(self,OS.get_cmdline_user_args().has("--playtest-catalog"))
	field_menu.set_item_catalog(item_catalog_088)
	weapon.construction_provider = field_builder
	building_input = load("res://scripts/building_input.gd").new()
	add_child(building_input)
	building_input.setup(player, weapon, field_builder, self)
	_load_progress(true)
	_begin_chapter()
	vertical_combat = load("res://scripts/vertical_combat_initialization.gd").new()
	add_child(vertical_combat)
	vertical_combat.setup(player, field_menu)
	# No automatic calibration on startup or map entry.
	if not xr_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	network_bridge=preload("res://scripts/net_bridge1000.gd").new();add_child(network_bridge);network_bridge.setup(self)
	if not "--smoke" in args:_show_front_menu()
	if "--smoke" in args:
		get_tree().create_timer(12).timeout.connect(func(): print("SMOKE_OK"); _quit_game(0, "smoke_complete"))
	if "--capture" in args:
		get_tree().create_timer(4).timeout.connect(_capture)

	var sound_cues099:=preload("res://scripts/sound_cues099.gd").new();add_child(sound_cues099);sound_cues099.setup(self)
	var pickup_focus0992:=preload("res://scripts/pickup_focus0992.gd").new();add_child(pickup_focus0992);pickup_focus0992.setup(self)

func _capture():
	await RenderingServer.frame_post_draw
	var output = ProjectSettings.globalize_path("res://../reports/ashfall-preview.png")
	get_viewport().get_texture().get_image().save_png(output)
	print("CAPTURE ", output)

func _on_xr_session_event(reason: String):
	print("XR_SESSION ", reason, " utc=", Time.get_datetime_string_from_system(true))
	telemetry.record_event(reason)
	if _xr_terminal or _quitting:return
	if reason in ["session_visible","session_synchronized","session_stopping"]:
		_suspend_xr_input()
		if reason=="session_stopping":_set_xr_render_suspended(true)
	elif reason in ["session_begun","session_focussed"]:
		_set_xr_render_suspended(false)
		if reason=="session_focussed":
			_xr_focus_suspended=false
			if is_instance_valid(player):
				player.require_neutral_input()
				player.input_enabled=_xr_input_was_enabled and (field_menu==null or not field_menu.is_open) and not player.vertical_combat_initializing

func _suspend_xr_input()->void:
	if not _xr_focus_suspended and is_instance_valid(player):_xr_input_was_enabled=player.input_enabled
	_xr_focus_suspended=true
	if is_instance_valid(player):player.input_enabled=false;player.require_neutral_input()
	if is_instance_valid(weapon):
		for gun in weapon.weapons:
			if gun.has_method("_suspend_gestures"):gun._suspend_gestures()

func _set_xr_render_suspended(value:bool)->void:
	if not xr_enabled or _xr_render_suspended==value:return
	_xr_render_suspended=value
	# Preserve the stereo viewport's format through native session teardown.
	# Switching use_xr to false here caused 2-layer textures to meet mono buffers.
	RenderingServer.viewport_set_active(get_viewport().get_viewport_rid(),not value)
	if value:
		for view in find_children("*","SubViewport",true,false):
			_xr_saved_viewports[view.get_instance_id()]=view.render_target_update_mode
			view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	else:
		for id in _xr_saved_viewports:
			var view=instance_from_id(id)
			if is_instance_valid(view):view.render_target_update_mode=_xr_saved_viewports[id]
		_xr_saved_viewports.clear()

func _on_tracking_changed(available: bool):
	print("XR_TRACKING available=", available, " utc=", Time.get_datetime_string_from_system(true))

func _on_xr_session_lost(reason: String):
	if _xr_terminal or _quitting:return
	print("XR_SESSION_LOST reason=", reason, " utc=", Time.get_datetime_string_from_system(true))
	_xr_terminal=true
	_suspend_xr_input()
	_set_xr_render_suspended(true)
	_quit_game(3, reason)

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game(0, "window_close")

func _quit_game(exit_code: int = 0, reason: String = "menu_quit"):
	if _quitting: return
	_quitting = true
	if xr_enabled:
		_xr_terminal=true
		_suspend_xr_input()
		_set_xr_render_suspended(true)
	var telemetry_error = telemetry.finish(reason, exit_code)
	if telemetry_error != OK: push_warning("Session diagnostics could not be saved: " + str(telemetry_error))
	get_tree().paused = true
	_stop_audio_tree(self)
	# The audio mixer releases active playback references on its next ticks.
	# Let it drain before the engine tears down resources and OpenXR.
	await get_tree().create_timer(0.15, true).timeout
	get_tree().quit(exit_code)

func _stop_audio_tree(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children(): _stop_audio_tree(child)

func _build_ui():
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(margin)
	var col = VBoxContainer.new()
	margin.add_child(col)
	var top = _hud_panel(col)
	mission_label = Label.new()
	mission_label.add_theme_font_size_override("font_size", 22)
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(mission_label)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 16)
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(hud)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var bottom = _hud_panel(col)
	_hud_bottom = bottom.get_parent()
	center_label = Label.new()
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 20)
	center_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(center_label)
	training_label = Label.new()
	training_label.add_theme_font_size_override("font_size", 18)
	training_label.modulate = Color("8bdadc")
	training_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(training_label)
	radio_label = Label.new()
	radio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio_label.add_theme_font_size_override("font_size", 18)
	radio_label.modulate = Color("c8e4e7")
	bottom.add_child(radio_label)
	var controls = Label.new()
	_hud_controls = controls
	controls.text = "WASD move   |   Mouse aim / fire   |   Space jump   |   E climb   |   G glide   |   R reload steps   |   F relay   |   Esc release mouse"
	controls.add_theme_font_size_override("font_size", 14)
	controls.modulate = Color("90a2b3")
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(controls)
	var cross = Label.new()
	_desktop_crosshair=cross
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 22)
	cross.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	cross.add_theme_constant_override("outline_size", 4)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.position -= Vector2(8, 15)
	ui_layer.add_child(cross)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.8, 0.05, 0.02, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(overlay)
	vr_label = Label3D.new()
	vr_label.font_size = 28
	vr_label.pixel_size = 0.00135
	vr_label.no_depth_test = false
	vr_label.modulate = Color("b8eced")
	vr_label.position = Vector3(-0.22, -0.30, -1.1)
	vr_label.outline_size = 5
	player.get_view_camera().add_child(vr_label)
	vr_label.visible = xr_enabled
	vr_cue = Label3D.new()
	vr_cue.font_size = 20
	vr_cue.pixel_size = 0.0007
	vr_cue.position = Vector3(0, -0.395, -0.80)
	vr_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vr_cue.outline_size = 5
	vr_cue.modulate = Color("c8e4e7")
	player.get_view_camera().add_child(vr_cue)
	vr_cue.visible = xr_enabled
	ui_layer.visible = not xr_enabled

func _hud_panel(parent: VBoxContainer) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.024, 0.033, 0.72)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.border_width_left = 2
	style.border_color = Color(0.27, 0.65, 0.68, 0.8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var contents := VBoxContainer.new()
	panel.add_child(contents)
	return contents

func _configure_missions() -> void:
	var ids := ["relay", "turbine", "uplink", "extraction"]
	var labels := ["RELAY", "TURBINE", "UPLINK", "EXTRACT"]
	var station_names := ["VALLEY RELAY", "TURBINE BYPASS", "SUMMIT UPLINK", "EXTRACTION"]
	for i in range(4):
		missions.append({"id": ids[i], "title": CHAPTERS[i], "order": ORDERS[i], "radio": RADIO[i], "audio": "mara_%02d" % (i + 1), "label": labels[i], "station": station_names[i], "count": [4,6,8,6][i]})
	if extended_campaign:
		campaign_extension = ExtensionScript.new()
		campaign_extension.build(world)
		load("res://scripts/extension_detail.gd").new().build(world)
		missions.insert(3, {"id":"dam_crown", "title":"04  /  CROSSCURRENT", "order":"Disable both interference units", "radio":"MARA: Two interference units are burying our signal. Shoot the orange cores on the dam crown. Either order. You do not need to clear every guard.", "audio":"", "label":"ARRAY", "station":"", "count":4})
		missions.insert(4, {"id":"spillway", "title":"05  /  SPILLWAY", "order":"Open spillway gate and exit", "radio":"MARA: The array is down. Descend into the spillway. Activate the isolator to open the southern gate, then get through. Keep moving; you do not need to clear the guards.", "audio":"", "label":"ISOLATOR", "station":"SPILLWAY ISOLATOR", "count":4})
		missions[5].title = "06  /  DOWNDRAFT"
		missions[2].radio = "MARA: Power is holding. Get to the summit uplink. I need a clean channel before we can bring anyone into this valley."
		missions[2].audio = "mara_uplink_extended"
		missions[3].radio = "MARA: I have your signal, but security is drowning it out. Two interference units on the dam crown. Break both antenna cores. You do not need to clear every patrol. Keep moving."
		missions[3].audio = "mara_dam_crown"
		missions[4].radio = "MARA: That is a clean channel. There is a maintenance route back to the pad. Reach the isolator on the lower spillway deck, release the gate, and get through."
		missions[4].audio = "mara_spillway"
		world.objective_positions.append(campaign_extension.mission_positions[0])
		world.objective_positions.append(campaign_extension.isolator_position)
		world.encounter_spawns.append(campaign_extension.mission_spawns[0])
		world.encounter_spawns.append(campaign_extension.mission_spawns[1])
	world.objective_positions.append(world.extraction_position + Vector3(0, 0.8, 0))
	world.encounter_spawns.append(world.extraction_spawn_points)

func mission_id() -> String:
	return str(missions[chapter].id) if chapter >= 0 and chapter < missions.size() else "complete"

func _objective_position() -> Vector3:
	if mission_id() == "spillway" and spillway_gate and spillway_gate.is_open:
		return campaign_extension.exit_position
	if mission_id() == "dam_crown":
		for unit in interference_units:
			if not unit.is_disabled: return unit.global_position + Vector3.UP
	return world.objective_positions[mini(chapter, world.objective_positions.size() - 1)]

func _checkpoint_position() -> Vector3:
	if is_instance_valid(active_sandbox_map) and "spawn" in active_sandbox_map:return active_sandbox_map.spawn
	if is_instance_valid(active_sandbox_map):return active_sandbox_map.spawn
	if extended_campaign:
		if mission_id() == "dam_crown": return campaign_extension.safe_spawns[0]
		if mission_id() == "spillway": return campaign_extension.safe_spawns[1]
		if mission_id() == "extraction": return campaign_extension.exit_position + Vector3(0, 0.4, -0.5)
	return world.player_spawn if chapter == 0 else world.objective_positions[mini(chapter - 1, world.objective_positions.size() - 1)] + Vector3(0, 1, 3)

func _build_objectives():
	waypoint = Label3D.new()
	waypoint.font_size = 36
	waypoint.pixel_size = 0.012
	waypoint.modulate = Color("79e5e4")
	waypoint.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	waypoint.no_depth_test = true
	waypoint.outline_size = 10
	add_child(waypoint)
	for i in range(world.objective_positions.size()):
		var anchor = Node3D.new()
		anchor.position = world.objective_positions[i]
		add_child(anchor)
		objective_nodes.append(anchor)
		if missions[i].id == "dam_crown": continue
		var base = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.8, 1.2, 0.65)
		base.mesh = box
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color("293944")
		mat.metallic = 0.7
		mat.roughness = 0.35
		base.material_override = mat
		anchor.add_child(base)
		var screen = MeshInstance3D.new()
		var panel = BoxMesh.new()
		panel.size = Vector3(0.65, 0.4, 0.03)
		screen.mesh = panel
		screen.position = Vector3(0, STATION_SCREEN_HEIGHT, 0.34)
		var lightmat = StandardMaterial3D.new()
		lightmat.albedo_color = Color("36d6de")
		lightmat.emission_enabled = true
		lightmat.emission = Color("36d6de")
		lightmat.emission_energy_multiplier = 2.0
		screen.material_override = lightmat
		anchor.add_child(screen)
		var label = Label3D.new()
		label.name = "StationLabel"
		label.text = ""
		label.position.y = 2.0
		label.font_size = 40
		label.pixel_size = 0.0035
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		anchor.add_child(label)
	if extended_campaign:
		for pos in campaign_extension.jammer_positions:
			var unit = InterferenceScript.new()
			unit.position = pos
			add_child(unit)
			unit.disabled.connect(_on_interference_disabled)
			interference_units.append(unit)
		spillway_gate = GateScript.new()
		spillway_gate.position = campaign_extension.gate_position
		add_child(spillway_gate)

func _begin_chapter():
	if field_consumables: field_consumables.reset_supplies(_checkpoint_position())
	if practice_dummy:
		practice_dummy.reset_target()
		practice_dummy.global_position = _checkpoint_position()+Vector3(-3,-1,-6)
	for projectile in get_tree().get_nodes_in_group("ashfall_projectile"):
		if is_instance_valid(projectile):projectile.queue_free()
	if rescue_dummy:
		rescue_dummy.global_position=_checkpoint_position()+Vector3(-4,.45 if is_instance_valid(active_sandbox_map) else -1,-3)
		rescue_dummy.reset_training()
	if revive_paddles:revive_paddles.stow()
	if weapon_inventory != null: weapon_inventory.relocate_pickups(_checkpoint_position())
	if ammo_pickups != null:
		ammo_pickups.global_position = _checkpoint_position()
		ammo_pickups.reset_pickups()
	if body_visual != null: body_visual.reset_pose()
	if field_builder != null: field_builder.reset_builds()
	if world_ping: world_ping.clear_all()
	RagdollScript.clear_all(self)
	if impact_marks: impact_marks.clear_all()
	world.reset_extraction_arrival()
	# Defeated hosts leave the combat list before their short death/audio tween ends.
	# Clear those hosts too so repeated checkpoint resets cannot accumulate them.
	for child in get_children():
		if child is EnemyScript:
			child.set_physics_process(false)
			child.set_process(false)
			child.collision_layer = 0
			child.collision_mask = 0
			if child.defeated.is_connected(_enemy_defeated): child.defeated.disconnect(_enemy_defeated)
			var hit_callback := _damage_player.bind(child)
			if child.hit_player.is_connected(hit_callback): child.hit_player.disconnect(hit_callback)
			child.queue_free()
	enemies.clear()
	for unit in interference_units:
		if mission_id() == "dam_crown": unit.reset()
		unit.set_active(mission_id() == "dam_crown")
		unit.set_paused(paused)
	if spillway_gate:
		spillway_gate.reset()
		spillway_gate.set_paused(paused)
	if is_instance_valid(active_sandbox_map):
		if active_sandbox_map.has_method("refresh_loot"):active_sandbox_map.refresh_loot()
		complete=false;encounter_active=false;radio_time=0;radio_text="";_caption_pending=false;toast_time=0
		if radio_audio:radio_audio.stop()
		mission_label.text="SANDBOX RANGE";waypoint.hide()
		for unit in interference_units:unit.set_active(false)
		return
	if chapter >= missions.size():
		_finish_campaign()
		return
	complete = false
	radio_text = missions[chapter].radio
	radio_time = 17.0
	if radio_audio: radio_audio.stop()
	if not str(missions[chapter].audio).is_empty(): _play_radio(missions[chapter].audio)
	mission_label.text = missions[chapter].order
	waypoint.visible = true
	waypoint.global_position = world.objective_positions[chapter] + Vector3(0, 4, 0)
	var objective = world.objective_positions[chapter]
	var points = world.enemy_spawn_points
	var grouped = world.get("encounter_spawns")
	if grouped is Array and grouped.size() > chapter:
		points = grouped[chapter]
	var count: int = missions[chapter].count
	encounter_active = mission_id() != "relay"
	for i in range(count):
		var enemy = EnemyScript.new()
		var p: Vector3
		if points.size() > 0:
			p = points[i % points.size()]
		else:
			p = objective + Vector3(cos(i * 1.6) * 9, 1, sin(i * 1.6) * 9)
		enemy.position = p
		enemy.setup(player, 3 if mission_id() == "extraction" and i == count - 1 else i % 3)
		enemy.set_difficulty(float(field_menu.get_settings().get("difficulty", 0.5)))
		enemy.damage_multiplier=field_menu.enemy_damage_multiplier
		add_child(enemy)
		enemy.set_navigation_provider(navigation_routes)
		if enemy.has_method("set_guard_heading"):
			var approach: Vector3 = world.player_spawn if chapter == 0 else world.objective_positions[chapter - 1]
			enemy.set_guard_heading(approach - p)
		enemy.defeated.connect(_enemy_defeated)
		enemy.hit_player.connect(_damage_player.bind(enemy))
		enemies.append(enemy)
		enemy.set_physics_process(encounter_active and not paused)
	for i in objective_nodes.size():
		objective_nodes[i].visible = i >= chapter
	print("MISSION_BEGIN ", chapter, " enemies=", enemies.size())


func _process(delta):
	if _quitting: return
	ui_layer.visible=not xr_enabled and not front_end_active
	vr_cue.visible=xr_enabled and not front_end_active
	vr_label.visible=xr_enabled and not front_end_active
	if _desktop_crosshair!=null:
		var active_gun:Node3D=weapon.weapons[weapon.selected]
		_desktop_crosshair.visible=not front_end_active and not paused and not (active_gun.has_method("get_scope_overlay_active") and active_gun.get_scope_overlay_active())
	_update_upright_vr_labels()
	var measured_gpu_ms := 0.0
	if DisplayServer.get_name() != "headless":
		measured_gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	var focused := xr_enabled and _xr_interface != null and _xr_interface.is_initialized() and _xr_interface.get_session_state() == OpenXRInterface.SESSION_STATE_FOCUSED
	telemetry.sample_frame(delta, measured_gpu_ms, focused, xr_enabled and player.is_hand_input_ready(player.left_hand), xr_enabled and player.is_hand_input_ready(player.right_hand))
	var should_pause = front_end_active or (field_menu != null and field_menu.is_open and not field_menu.backpack_is_open()) or (xr_enabled and (_xr_focus_suspended or not player.tracking_available)) or player.vertical_combat_initializing
	if network_bridge!=null and network_bridge.playing():should_pause=false
	if paused != should_pause:
		paused = should_pause
		for projectile in get_tree().get_nodes_in_group("ashfall_projectile"):
			if is_instance_valid(projectile):projectile.set_paused(paused)
		for corpse in get_tree().get_nodes_in_group("ragdolls"):
			corpse.set_paused(paused)
		for enemy in enemies:
			if is_instance_valid(enemy): enemy.set_physics_process(not paused and encounter_active)
		if radio_audio: radio_audio.stream_paused = paused
		if ambience: ambience.set_paused(paused)
		if impact_marks: impact_marks.set_paused(paused)
		if music: music.set_paused(paused)
		for unit in interference_units: unit.set_paused(paused)
		if spillway_gate: spillway_gate.set_paused(paused)
		vr_label.visible = xr_enabled and not paused
		vr_cue.visible = xr_enabled and not paused
	# Available inventory props persist in every mission and throughout combat.
	if weapon_pickup_props: weapon_pickup_props.visible = true
	if paused: return
	if network_bridge!=null and network_bridge.live():
		_update_effect_pool(delta);toast_time=maxf(0,toast_time-delta);damage_timer=maxf(0,damage_timer-delta);radio_time=0;waypoint.hide()
		return
	_awareness_timer -= delta
	if _awareness_timer <= 0.0:
		_awareness_timer = 0.2
		_light_exposure = world.get_light_exposure(player.get_view_camera().global_position)
		_enemy_awareness = 0.0
		for enemy in enemies:
			if is_instance_valid(enemy):
				_enemy_awareness = maxf(_enemy_awareness, enemy.detection_level)
		if music:
			music.set_intensity(_enemy_awareness if encounter_active and not complete else 0.0)
			music.set_extraction(mission_id() in ["extraction", "complete"])
	if music: music.set_radio_active(radio_audio != null and radio_audio.playing)
	play_time += delta
	if not encounter_active and mission_id() == "relay" and player.global_position.z < 1.0:
		_activate_encounter()
	damage_timer = maxf(0, damage_timer - delta)
	toast_time = maxf(0, toast_time - delta)
	radio_time = maxf(0, radio_time - delta)
	perf_timer += delta
	frame_samples.append(delta * 1000.0)
	if frame_samples.size() > 1000: frame_samples.pop_front()
	if DisplayServer.get_name() != "headless":
		var gpu_ms = measured_gpu_ms
		if gpu_ms > 0:
			gpu_samples.append(gpu_ms)
			if gpu_samples.size() > 1000: gpu_samples.pop_front()
	if perf_timer >= 30:
		perf_timer = 0
		var sum = 0.0
		for sample in frame_samples: sum += sample
		print("PERF process_callback_ms=", snappedf(sum / max(1, frame_samples.size()), 0.01), " xr=", xr_enabled, " enemies=", enemies.size())
		if not gpu_samples.is_empty():
			var ordered = gpu_samples.duplicate()
			ordered.sort()
			print("GPU_VIEWPORT median_ms=", ordered[int(ordered.size() * 0.5)], " p95_ms=", ordered[mini(ordered.size()-1, int(ordered.size()*0.95))], " xr=", xr_enabled, " resolution=", get_viewport().size)
	if player.global_position.y < -25 and not dead: _damage_player(200)
	if health < 100 and damage_timer <= 0 and not dead: health = minf(100, health + delta * 5)
	overlay.color.a = clampf(damage_timer * 0.03, 0, 0.22)
	var ammo_text = str(weapon.ammo) + " / " + str(weapon.magazine_size)
	var target_text = ""
	if not encounter_active: target_text = "STAGING AREA  /  ADVANCE THROUGH THE GATE WHEN READY"
	if chapter < missions.size() and not complete:
		var dist = player.global_position.distance_to(_objective_position())
		var station_label = objective_nodes[chapter].get_node_or_null("StationLabel")
		if station_label:
			station_label.text = ""
		waypoint.global_position = _objective_position() + Vector3(0, 4, 0)
		waypoint.text = "%02d / %s\n%d m" % [chapter + 1, _objective_label(), int(dist)]
		waypoint.visible = dist > 7
		target_text = str(missions[chapter].label) + " " + str(int(dist)) + " m"
		if not encounter_active: target_text = "STAGING AREA / ADVANCE WHEN READY"
		if mission_id() == "dam_crown":
			var remaining := 0
			for unit in interference_units:
				if not unit.is_disabled: remaining += 1
			target_text = "SABOTAGE ORANGE CORES | %d REMAINING" % remaining
		elif mission_id() == "spillway":
			if spillway_gate.is_open:
				target_text = "ESCAPE THROUGH THE OPEN GATE"
				_check_spillway_exit()
			elif dist < 3.2:
				target_text = "GRIP SCREEN / F TO OPEN SPILLWAY"
		elif dist < 3.2:
			if enemies.is_empty():
				target_text = "GRIP SCREEN / F TO ACTIVATE"
			else: target_text = "CLEAR SECURITY | " + str(enemies.size()) + " REMAINING"
	var concealment := "IN SHADOW" if _light_exposure < 0.28 else ("PARTLY LIT" if _light_exposure < 0.6 else "EXPOSED TO LIGHT")
	var awareness := "ALERT" if _enemy_awareness >= 0.99 else ("SUSPICIOUS" if _enemy_awareness > 0.15 else "UNDETECTED")
	var training_hint: String = training.get_hint(false) if not encounter_active else ""
	_update_compact_hud(delta, ammo_text, target_text, concealment, awareness, training_hint)

func _caption_chunks(value: String, width: int = 48) -> PackedStringArray:
	var lines := _wrap_text(value, width).strip_edges().split("\n")
	var pages: PackedStringArray = []
	for i in range(0, lines.size(), 2):
		var page := lines[i].strip_edges()
		if i + 1 < lines.size(): page += "\n" + lines[i + 1].strip_edges()
		pages.append(page)
	return pages

func _update_upright_vr_labels() -> void:
	if not is_instance_valid(player): return
	var camera:Camera3D = player.get_view_camera()
	var facing := preload("res://scripts/upright_ui.gd").view_basis(camera.global_basis)
	if is_instance_valid(vr_label): vr_label.global_transform = Transform3D(facing, camera.global_position + facing * Vector3(-.22,-.30,-1.1))
	if is_instance_valid(vr_cue): vr_cue.global_transform = Transform3D(facing, camera.global_position + facing * Vector3(0,-.395,-.80))

func _update_compact_hud(delta: float, ammo_text: String, target_text: String, concealment: String, awareness: String, training_hint: String) -> void:
	for i in range(objective_nodes.size()):
		var station_label := objective_nodes[i].get_node_or_null("StationLabel") as Label3D
		if station_label:
			station_label.visible = false
	if radio_time > 0 and (radio_text != _caption_source or radio_time > _last_radio_remaining + 1.0):
		_caption_source = radio_text
		_caption_pages = _caption_chunks(radio_text)
		_caption_index = 0
		_caption_clock = 0.0
		_caption_pending = not radio_text.is_empty()
	_last_radio_remaining = radio_time
	var action := ""
	if (dead or complete) and toast_time > 0:
		action = toast
	elif target_text.begins_with("GRIP ") or target_text.begins_with("CLEAR SECURITY"):
		action = target_text.replace(String.chr(7), "|")
	elif toast_time > 0:
		action = toast
	var subtitle := ""
	if action.is_empty() and _caption_pending:
		subtitle = _caption_pages[_caption_index]
		_caption_clock += delta
		# Reading time is based on page length; interruption pauses the page.
		if _caption_clock >= maxf(3.5, subtitle.length() / 16.0):
			_caption_clock = 0.0
			_caption_index += 1
			if _caption_index >= _caption_pages.size(): _caption_pending = false
	var hint := training_hint if action.is_empty() and subtitle.is_empty() and not encounter_active else ""
	if action.is_empty() and subtitle.is_empty() and (target_text.begins_with("SABOTAGE ") or target_text.begins_with("ESCAPE ")):
		hint = target_text
	var cue := action if not action.is_empty() else (subtitle if not subtitle.is_empty() else hint)
	if not cue.is_empty() and subtitle.is_empty():
		var cue_pages := _caption_chunks(cue)
		# Actions longer than two lines cycle without expanding into the aim area.
		cue = cue_pages[int(play_time / 4.0) % cue_pages.size()]
	center_label.text = action
	radio_label.text = subtitle
	training_label.text = hint
	center_label.visible = not action.is_empty()
	radio_label.visible = not subtitle.is_empty()
	training_label.visible = not hint.is_empty()
	_hud_controls.visible = false
	_hud_controls.text = "TAB field menu  |  F interact  |  R reload  |  Esc release mouse"
	_hud_bottom.visible = center_label.visible or radio_label.visible or training_label.visible or _hud_controls.visible
	hud.text = ""
	vr_label.text = ""
	# Keep spoken story subtitles and terminal outcomes, remove repeated status.
	var brief_message: String = subtitle if not subtitle.is_empty() else (str(toast) if toast_time > 0.0 else "")
	vr_cue.text = _caption_chunks(brief_message, 42)[0] if not brief_message.is_empty() else ""
	center_label.visible = (dead or complete) and not action.is_empty()
	training_label.visible = false
	_hud_bottom.visible = center_label.visible or radio_label.visible

func _objective_label() -> String:
	if mission_id() == "spillway" and spillway_gate and spillway_gate.is_open: return "EXIT"
	return str(missions[chapter].label) if chapter < missions.size() else "COMPLETE"

func _compact_status(ammo_text: String, concealment: String, awareness: String) -> String:
	var objective := "STAGING | ADVANCE WHEN READY"
	if complete: objective = "EXTRACTION COMPLETE"
	elif encounter_active and chapter < world.objective_positions.size():
		objective = _objective_label() + " " + str(int(player.global_position.distance_to(_objective_position()))) + "m"
		if mission_id() == "dam_crown":
			var remaining := 0
			for unit in interference_units:
				if not unit.is_disabled: remaining += 1
			objective = "SHOOT 1 CORE" if remaining == 1 else "SHOOT %d CORES" % remaining
	if encounter_active and not complete:
		var light_word: String = {"IN SHADOW": "SHADOW", "PARTLY LIT": "PART LIT", "EXPOSED TO LIGHT": "LIT", "EXPOSED": "LIT"}.get(concealment, concealment)
		var awareness_word := "UNSEEN" if awareness == "UNDETECTED" else awareness
		objective += " | " + light_word + " / " + awareness_word
	return str(int(health)) + " HP | " + weapon.weapon_name + " " + ammo_text + "\n" + objective

func _wrap_text(text_value: String, width: int) -> String:
	var result = ""
	var line_length = 0
	for word in text_value.split(" "):
		if line_length + word.length() > width:
			result += "\n"
			line_length = 0
		result += word + " "
		line_length += word.length() + 1
	return result

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_I and not xr_enabled and not paused and not dead and not complete:
			if field_menu.is_open:field_menu.set_open(false)
			else:_open_backpack()
			get_viewport().set_input_as_handled();return
		if event.keycode == KEY_F: _activate_objective()
		if event.keycode == KEY_F5: _save_progress()
		if event.keycode == KEY_F9: load_checkpoint()
		if event.keycode == KEY_HOME and complete: new_campaign()
		if not xr_enabled and not paused and not dead and not complete and player.input_enabled:
			if event.keycode == KEY_H:_desktop_pickup_ground()
			if event.keycode == KEY_K:weapon_inventory.drop_weapon(weapon.selected)

func _desktop_pickup_ground()->bool:
	# Desktop debug uses the same finite inventory and actual world occlusion.
	if xr_enabled or paused or dead or complete or not weapon_inventory._can_interact():return false
	var camera:Camera3D=player.get_view_camera()
	var forward:Vector3=-camera.global_basis.z.normalized()
	var best:=-1
	var best_dot:=.80
	var best_distance:=INF
	for index in weapon_inventory.pickups:
		var prop:Node3D=weapon_inventory.pickups[index]
		var offset:=prop.global_position-camera.global_position
		var distance:=offset.length()
		if distance>.0 and distance<=2.2:
			var alignment:=forward.dot(offset/distance)
			if alignment<best_dot or (is_equal_approx(alignment,best_dot) and distance>=best_distance):continue
			var query:=PhysicsRayQueryParameters3D.create(camera.global_position,prop.global_position,1,[player.get_rid()])
			query.hit_from_inside=true
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
			best=index;best_dot=alignment;best_distance=distance
	if best<0 or not weapon_inventory.pickup_weapon(best):return false
	if weapon.select_inventory_weapon(best):weapon.set_holstered(false)
	return true

func _activate_objective(interaction_hand: Node3D = null):
	if paused or complete or dead or chapter >= missions.size(): return
	if field_menu and field_menu.is_open: return
	if xr_enabled and not _valid_objective_hand(interaction_hand): return
	if mission_id() == "dam_crown": return
	if not xr_enabled and player.global_position.distance_to(world.objective_positions[chapter]) > 3.2: return
	if mission_id() == "spillway":
		if not spillway_gate.is_open:
			spillway_gate.activate()
			_feedback("GATE OPEN | EXIT", 4.0)
		return
	if not enemies.is_empty(): return
	_advance_mission()

func _on_interference_disabled() -> void:
	if paused or complete or dead or mission_id() != "dam_crown": return
	for unit in interference_units:
		if not unit.is_disabled: return
	_advance_mission()

func _check_spillway_exit() -> void:
	if paused or dead or complete or mission_id() != "spillway" or not spillway_gate.is_open: return
	var offset: Vector3 = player.global_position - campaign_extension.exit_position
	if absf(offset.x) < 1.8 and absf(offset.z) < 1.8 and offset.y >= -0.25 and offset.y < 2.5:
		_advance_mission()

func _advance_mission() -> void:
	var completed_id := mission_id()
	chapter += 1
	health = 100
	shield = 100.0
	if combat_hud: combat_hud.clear_damage_indicator()
	var saved := _save_progress()
	_play_sound("relay")
	var result_text := "ARRAY SILENCED" if completed_id == "dam_crown" else ("SPILLWAY CLEARED" if completed_id == "spillway" else "RELAY SYNCHRONIZED")
	_feedback(result_text + (" / CHECKPOINT SAVED" if saved else " / CHECKPOINT WRITE FAILED"))
	_begin_chapter()

func _on_shot(origin: Vector3, direction: Vector3, damage: float):
	if network_bridge!=null and network_bridge.live():network_bridge.shot(origin,[direction]);return
	if paused or dead or complete: return
	if not is_finite(damage) or damage <= 0: return
	damage*=field_menu.player_damage_multiplier
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.notify_gunshot(origin)
	if xr_enabled:
		var obstruction = Ballistics.create(get_tree(), player.get_view_camera().global_position, origin, [], 1|8)
		var blocked = get_world_3d().direct_space_state.intersect_ray(obstruction)
		if not blocked.is_empty():
			_impact(blocked.position, blocked.normal)
			if impact_marks: impact_marks.add_hit(blocked.position, blocked.normal, blocked.collider, false)
			_feedback("MUZZLE BLOCKED", 0.4)
			return
	var query = Ballistics.create(get_tree(), origin, origin + direction * 180, [player.get_rid()])
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	var end = origin + direction * 100
	if not result.is_empty():
		end = result.position
		var node = result.collider
		if impact_marks: impact_marks.add_hit(result.position, result.normal, node, false)
		if ambience: ambience.play_impact(end, ambience.surface_type(node))
		if node.has_method("take_damage"):
			if not node.is_in_group("practice_targets"): _activate_encounter()
			_apply_target_damage(node,preload("res://scripts/one_star0991.gd").hit_damage(node,result.position,damage,weapon.weapons[weapon.selected]))
			if node.has_method("get_hit_feedback"):
				var message: String = node.get_hit_feedback()
				if not message.is_empty(): _feedback(message, 0.8)
			elif node is EnemyScript and node.variant == 3:
				_play_sound("hit")
				if node.last_damage_blocked: _feedback("ARMORED | WAIT FOR OPEN CORE", 0.6)
			else:
				_play_sound("hit")
		elif node.is_in_group("field_construction") and node.has_method("hit"):
			node.hit(damage, end, direction)
		_impact(end, result.normal)
	_tracer(origin, end)

func _on_pellet_shot(origin: Vector3, directions: Array[Vector3], pellet_damage: float):
	if network_bridge!=null and network_bridge.live():network_bridge.shot(origin,directions);return
	if paused or dead or complete or not origin.is_finite() or not is_finite(pellet_damage) or pellet_damage <= 0.0: return
	pellet_damage*=field_menu.player_damage_multiplier
	# A discharge is one audible event, with bounded rays and one damage call per target.
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.notify_gunshot(origin)
	if xr_enabled:
		var obstruction = Ballistics.create(get_tree(), player.get_view_camera().global_position, origin, [], 1|8)
		var blocked = get_world_3d().direct_space_state.intersect_ray(obstruction)
		if not blocked.is_empty():
			_impact(blocked.position, blocked.normal)
			if impact_marks: impact_marks.add_hit(blocked.position, blocked.normal, blocked.collider, true)
			_feedback("MUZZLE BLOCKED", 0.4)
			return
	var grouped_damage: Dictionary = {}
	var grouped_contacts: Dictionary = {}
	for index in range(mini(8, directions.size())):
		var direction: Vector3 = directions[index]
		if not direction.is_finite() or direction.length_squared() < 0.01: continue
		direction = direction.normalized()
		var query = Ballistics.create(get_tree(), origin, origin + direction * 40.0, [player.get_rid()])
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		var end = origin + direction * 40.0
		if not result.is_empty():
			end = result.position
			var node = result.collider
			if impact_marks: impact_marks.add_hit(result.position, result.normal, node, true)
			if ambience: ambience.play_impact(end, ambience.surface_type(node))
			if node.has_method("take_damage") or (node.is_in_group("field_construction") and node.has_method("hit")):
				var falloff := lerpf(1.0, 0.25, clampf((origin.distance_to(end) - 8.0) / 17.0, 0.0, 1.0))
				var located_damage:float=preload("res://scripts/one_star0991.gd").hit_damage(node,end,pellet_damage*falloff,weapon.weapons[weapon.selected])
				grouped_damage[node] = float(grouped_damage.get(node, 0.0)) + located_damage
				grouped_contacts[node] = {"position": end, "direction": direction}
			_impact(end, result.normal)
		_tracer(origin, end)
	var announced := false
	for node in grouped_damage:
		# An objective hit can synchronously advance the mission and retire guards.
		if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
		if node.is_in_group("field_construction") and node.has_method("hit"):
			var contact: Dictionary = grouped_contacts[node]
			node.hit(float(grouped_damage[node]), contact.position, contact.direction)
			continue
		if not node.is_in_group("practice_targets"): _activate_encounter(false)
		_apply_target_damage(node,float(grouped_damage[node]))
		if announced: continue
		announced = true
		if node.has_method("get_hit_feedback"):
			var message: String = node.get_hit_feedback()
			if not message.is_empty(): _feedback(message, 0.8)
		elif node is EnemyScript and node.variant == 3:
			_play_sound("hit")
			if node.last_damage_blocked: _feedback("ARMORED | WAIT FOR OPEN CORE", 0.6)
		else:
			_play_sound("hit")

func _activate_encounter(announce: bool = true):
	if network_bridge!=null and network_bridge.live():return
	if encounter_active: return
	encounter_active = true
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.set_physics_process(true)
	if announce: _feedback("SECURITY ALERT", 2.0)

func _build_effect_pool():
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.008
	cylinder.bottom_radius = 0.008
	cylinder.height = 1.0
	cylinder.radial_segments = 4
	var ball = SphereMesh.new()
	ball.radius = 0.045
	ball.height = 0.09
	ball.radial_segments = 8
	ball.rings = 4
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ffe5a0")
	for i in range(EFFECT_POOL_SIZE):
		for kind in range(2):
			var mesh = MeshInstance3D.new()
			mesh.name = ("Tracer" if kind == 0 else "Impact") + str(i)
			mesh.mesh = cylinder if kind == 0 else ball
			mesh.material_override = mat
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.visible = false
			add_child(mesh)
			if kind == 0:
				_tracers.append(mesh)
				_tracer_times.append(0.0)
				_tracer_emitters.append(weakref(null));_tracer_ends.append(Vector3.ZERO)
			else:
				_impacts.append(mesh)
				_impact_times.append(0.0)

func _update_effect_pool(delta: float):
	for i in range(_tracers.size()):
		_tracer_times[i] = maxf(0, _tracer_times[i] - delta)
		_impact_times[i] = maxf(0, _impact_times[i] - delta)
		_tracers[i].visible = _tracer_times[i] > 0
		if _tracers[i].visible:
			var gun:Node3D=_tracer_emitters[i].get_ref()
			if is_instance_valid(gun) and gun.is_visible_in_tree():
				preload("res://scripts/tracer_follow_090.gd").draw(_tracers[i],gun.get_shot_transform().origin,_tracer_ends[i])
		_impacts[i].visible = _impact_times[i] > 0

func _tracer(a: Vector3, b: Vector3):
	if _tracers.is_empty() or a.distance_to(b) < 0.01: return
	var mesh = _tracers[_tracer_cursor]
	_tracer_emitters[_tracer_cursor]=weakref(preload("res://scripts/tracer_follow_090.gd").emitter(weapon,a))
	_tracer_ends[_tracer_cursor]=b
	_tracer_times[_tracer_cursor] = 0.045
	_tracer_cursor = (_tracer_cursor + 1) % EFFECT_POOL_SIZE
	mesh.position = (a + b) / 2
	mesh.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	mesh.scale = Vector3(1, a.distance_to(b), 1)
	mesh.visible = true

func _impact(pos: Vector3, normal: Vector3):
	if _impacts.is_empty(): return
	var mesh = _impacts[_impact_cursor]
	_impact_times[_impact_cursor] = 0.11
	_impact_cursor = (_impact_cursor + 1) % EFFECT_POOL_SIZE
	mesh.position = pos + normal * 0.025
	mesh.visible = true

func _enemy_defeated(enemy):
	if not enemies.has(enemy): return
	enemies.erase(enemy)
	total_kills += 1
	if ammo_pickups != null:
		ammo_pickups.spawn_box("builds",enemy.global_position+Vector3.UP*.75,6)
	if enemies.is_empty():
		var next_action := "DISABLE THE INTERFERENCE UNITS" if mission_id() == "dam_crown" else ("USE THE ISOLATOR AND EXIT" if mission_id() == "spillway" else "ACTIVATE THE RELAY")
		_feedback(next_action, 3.0)
		_play_sound("relay")

func _damage_player(amount: float, source: Node3D = null,direct_health:bool=false):
	if network_bridge!=null and network_bridge.live():
		if network_bridge.net.server:network_bridge.net.hurt(network_bridge.net.me(),amount,0,false,direct_health)
		return
	if paused or dead or complete: return
	if not is_finite(amount) or amount <= 0.0: return
	var before_pools := maxf(health,0)+maxf(shield,0)
	_apply_damage_layers(amount,direct_health)
	if combat_hud:combat_hud.notify_incoming(maxf(0,before_pools-maxf(health,0)-maxf(shield,0)))
	if combat_hud and is_instance_valid(source):
		var attack_origin:Vector3=source.get_weapon_muzzle_transform().origin if source.has_method("get_weapon_muzzle_transform") else source.global_position
		combat_hud.notify_damage(attack_origin)
	if field_menu and field_menu.vignette_enabled: field_menu.flash_damage()
	damage_timer = 5.0
	_play_sound("hurt")
	if xr_enabled and player.right_hand:
		player.right_hand.trigger_haptic_pulse("haptic", 0, 0.5, 0.12, 0)
	if health <= 0:
		dead = true
		_feedback("RESTORING CHECKPOINT", 3.0)
		var generation := _recovery_generation
		get_tree().create_timer(2.5).timeout.connect(func():
			if dead and generation == _recovery_generation:
				_respawn())

func _respawn():
	_recovery_generation += 1
	dead = false
	health = 100
	shield = 100.0
	if combat_hud: combat_hud.clear_damage_indicator()
	damage_timer = 0
	player.reset_motion()
	weapon.reset_weapon()
	if world.has_method("reset_environment_damage"): world.reset_environment_damage()
	player.global_position = _checkpoint_position()
	_begin_chapter()

func _finish_campaign():
	complete = true
	waypoint.visible = false
	if world.has_method("start_extraction_arrival"): world.start_extraction_arrival()
	mission_label.text = "CAMPAIGN COMPLETE"
	radio_text = "MARA: I can hear them. All of them. Evacuation is inbound. You brought the valley back. Come home."
	radio_time = 60
	_play_radio("mara_finish")
	_feedback("CAMPAIGN COMPLETE", 5.0)
	print("CAMPAIGN_COMPLETE time=", play_time, " kills=", total_kills)

func _save_progress() -> bool:
	var data = {"version": 1, "chapter": chapter, "kills": total_kills, "play_time": play_time}
	var error: Error
	if extended_campaign:
		error = CampaignProgress.write_progress(EXPANDED_SAVE_PATH, {"mission_id": mission_id(), "kills":total_kills, "play_time":play_time})
	else:
		error = SaveStore.write_save(SAVE_PATH, data)
	if error == OK:
		print("SAVE_OK chapter=", chapter)
		return true
	push_warning("Save unavailable: " + str(error))
	return false

func _load_progress(allow_recovery: bool = false) -> bool:
	if extended_campaign:
		# Opt-in expansion has a separate slot; never read or migrate legacy here.
		var result := CampaignProgress.read_progress(EXPANDED_SAVE_PATH, "", allow_recovery)
		if result.state != "valid": return false
		chapter = CampaignProgress.MISSIONS.find(result.data.mission_id)
		total_kills = result.data.kills
		play_time = result.data.play_time
		player.global_position = _checkpoint_position()
		return true
	var data := SaveStore.read_save(SAVE_PATH, allow_recovery)
	if data.is_empty(): return false
	chapter = int(clampf(float(data.get("chapter", 0)), 0, CHAPTERS.size()))
	total_kills = int(clampf(float(data.get("kills", 0)), 0, 1000000))
	play_time = clampf(float(data.get("play_time", 0)), 0, 31536000)
	player.global_position = _checkpoint_position()
	return true

func load_checkpoint() -> bool:
	if not _load_progress(true):
		_feedback("CHECKPOINT UNAVAILABLE", 2.0)
		return false
	_recovery_generation += 1
	dead = false
	complete = false
	health = 100
	shield = 100.0
	if combat_hud: combat_hud.clear_damage_indicator()
	damage_timer = 0
	player.reset_motion()
	player.require_neutral_input()
	weapon.reset_weapon()
	if world.has_method("reset_environment_damage"): world.reset_environment_damage()
	_begin_chapter()
	_feedback("CHECKPOINT RESTORED", 2.0)
	return true

func new_campaign():
	if network_bridge!=null and network_bridge.live():
		if network_bridge.net.is_host():network_bridge.net.request("restart")
		return
	_recovery_generation += 1
	dead = false
	complete = false
	player.reset_motion()
	player.require_neutral_input()
	weapon.reset_weapon()
	if world.has_method("reset_environment_damage"): world.reset_environment_damage()
	chapter = 0
	health = 100
	shield = 100.0
	if combat_hud: combat_hud.clear_damage_indicator()
	damage_timer = 0
	total_kills = 0
	play_time = 0
	player.global_position = _checkpoint_position()
	if training: training.reset()
	_save_progress()
	_begin_chapter()

func _save_settings(settings: Dictionary):
	if network_bridge!=null and network_bridge.live():settings=network_bridge.personal_settings(settings)
	if combat_hud:combat_hud.style=str(settings.get("hud_style","reference"))
	if combat_hud: combat_hud.set_hud_size(float(settings.get("hud_size", 1.0)))
	if world and world.has_method("set_graphics_quality"):
		world.set_graphics_quality(str(settings.get("graphics_quality", "high")))
	if weapon: weapon.set_weapon_settings(settings.get("weapon_settings", {}))
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_difficulty(float(settings.get("difficulty", 0.5)))
			enemy.damage_multiplier=field_menu.enemy_damage_multiplier
	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(settings))

func _build_radio():
	if AudioServer.get_bus_index("Voice") < 0:
		AudioServer.add_bus()
		var idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Voice")
		var high = AudioEffectHighPassFilter.new()
		high.cutoff_hz = 280
		AudioServer.add_bus_effect(idx, high)
		var low = AudioEffectLowPassFilter.new()
		low.cutoff_hz = 3600
		AudioServer.add_bus_effect(idx, low)
	radio_audio = AudioStreamPlayer.new()
	radio_audio.bus = "Voice"
	radio_audio.volume_db = -1
	add_child(radio_audio)

func _play_radio(name_value: String):
	if radio_audio == null: return
	radio_audio.stop()
	var path = "res://assets/audio/" + name_value + ".wav"
	if ResourceLoader.exists(path):
		radio_audio.stream = load(path)
		radio_time = maxf(radio_time, radio_audio.stream.get_length() + 1.0)
		radio_audio.play()

func _feedback(message: String, duration: float = 2.4):
	toast = message
	toast_time = duration

func _build_sounds():
	AudioBank.ensure_buses()
	AudioBank.warmup(["hit", "hurt", "relay"])
	for key in ["hit", "hurt", "relay"]:
		sounds[key] = AudioBank.sample(key)
	for i in range(8):
		var audio := AudioStreamPlayer.new()
		audio.bus = "SFX"
		audio.volume_db = -12.0
		add_child(audio)
		_cue_players.append(audio)

func _play_sound(key: String):
	if not sounds.has(key) or _cue_players.is_empty(): return
	var audio := _cue_players[_cue_cursor]
	_cue_cursor = (_cue_cursor + 1) % _cue_players.size()
	audio.stop()
	audio.stream = AudioBank.sample(key, _cue_variant)
	_cue_variant += 1
	audio.play()






func _objective_grip_targets() -> Array:
	var targets := _station_grip_targets()
	if weapon_pickup_props and not paused and not dead and not complete and not (field_menu and field_menu.is_open):
		targets.append_array(weapon_pickup_props.get_grip_targets())
	if field_consumables:targets.append_array(field_consumables.get_grip_targets())
	if ammo_pickups and not paused and not field_menu.is_open:targets.append_array(ammo_pickups.get_grip_targets())
	return targets

func _station_grip_targets() -> Array:
	if paused or dead or complete or chapter >= missions.size(): return []
	if field_menu and field_menu.is_open: return []
	if mission_id() == "dam_crown": return []
	if mission_id() == "spillway":
		if not spillway_gate or spillway_gate.is_open: return []
	elif not enemies.is_empty(): return []
	if chapter >= objective_nodes.size(): return []
	# Exposed front of the visible cyan screen, not the buried station origin.
	return [{"id": mission_id(), "position": objective_nodes[chapter].to_global(Vector3(0, STATION_SCREEN_HEIGHT, .37))}]

func _valid_objective_hand(hand: Node3D, target_id: String = "") -> bool:
	if hand == null or not player.tracking_available or not player.is_hand_input_ready(hand): return false
	if not player.is_hand_grip_reserved(hand): return false
	if target_id.is_empty(): target_id = mission_id()
	var selected: Dictionary = {}
	for target in _objective_grip_targets():
		if target.id == target_id and (not target.has("hand") or target.hand==hand): selected = target; break
	if selected.is_empty(): return false
	if target_id.begins_with("inventory_pickup:"):
		return weapon_inventory.get_aimed_pickup(hand)==int(target_id.trim_prefix("inventory_pickup:"))
	if target_id.begins_with("supply:"):return ammo_pickups.is_valid_target(target_id,hand)
	if target_id.begins_with("consumable:"):return field_consumables!=null and hand.global_position.distance_to(selected.position)<=float(selected.get("reach",.35))
	var point: Vector3 = selected.position
	if hand.global_position.distance_to(point) > .35: return false
	var ray := PhysicsRayQueryParameters3D.create(hand.global_position, point, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.position.distance_to(point) <= .012

func _on_objective_grip(target_id: String, hand: Node3D) -> void:
	if not _valid_objective_hand(hand, target_id): return
	if target_id.begins_with("supply:"):
		ammo_pickups.handle_grip(target_id,hand)
		return
	if target_id.begins_with("consumable:"):
		field_consumables.handle_grip(target_id,hand)
		return
	if target_id.begins_with("inventory_pickup:"):
		if weapon_inventory.handle_grip(target_id, hand):
			var picked := int(target_id.trim_prefix("inventory_pickup:"))
			if weapon.select_inventory_weapon(picked): weapon.set_holstered(false)
		return
	if target_id.begins_with("weapon_pickup:"):
		var index := int(target_id.trim_prefix("weapon_pickup:"))
		if index == weapon.selected or weapon.select_weapon(index):
			weapon.set_holstered(false)
		return
	if target_id != mission_id(): return
	_activate_objective(hand)

func _on_melee_contact(target:Node3D,point:Vector3,amount:float,direction:Vector3)->void:
	if network_bridge!=null and network_bridge.live():network_bridge.melee(target,point,amount,direction);return
	if paused or dead or complete or not is_instance_valid(target) or not point.is_finite() or not is_finite(amount):return
	amount=clampf(amount,25,75)*field_menu.player_damage_multiplier
	if target.is_in_group("field_construction") and target.has_method("hit"):
		target.hit(amount,point,direction)
	elif target.has_method("take_melee_damage"):
		if not target.is_in_group("practice_targets"):_activate_encounter(false)
		_apply_target_damage(target,amount,true)
	elif target.has_method("take_damage"):
		# Current authored guards have health/armor, no personal shield pool.
		if not target.is_in_group("practice_targets"):_activate_encounter(false)
		_apply_target_damage(target,amount)
	_impact(point,-direction);_play_sound("hit")

func take_melee_damage(amount:float)->void:
	# Explicit direct-HP route. Directional shields never intercept melee or area damage.
	_damage_player(amount,null,true)

func _apply_damage_layers(amount: float,direct_health:bool=false) -> void:
	if not is_finite(amount) or amount <= 0.0: return
	if direct_health:health=clampf(health-amount,0,100);return
	var absorbed := minf(maxf(shield, 0.0), amount)
	shield = clampf(shield - absorbed, 0.0, 100.0)
	health = clampf(health - (amount - absorbed), 0.0, 100.0)

func _open_backpack() -> void:
	if paused or dead or complete or not field_menu: return
	field_menu.set_open(true)
	field_menu.settings_page = "loadout"
	field_menu.selected = 0
	field_menu._refresh()

func _loadout_labels() -> Array[String]:
	var labels:Array[String]=[];var actions:Array=weapon_inventory.slot_actions()
	for i in 6:labels.append(weapon_inventory.action_label(actions[i]) if i<actions.size() else ("LOCKED" if i>=weapon_inventory.capacity else "EMPTY"))
	return labels
func _loadout_icons() -> Array[Texture2D]:
	var icons:Array[Texture2D]=[];var actions:Array=weapon_inventory.slot_actions()
	for i in 6:icons.append(weapon_inventory.action_icon(actions[i]) if i<actions.size() else load("res://assets/ui/inventory_locked.svg" if i>=weapon_inventory.capacity else "res://assets/ui/inventory_empty.svg"))
	return icons
func _refresh_loadout() -> void:
	if field_menu and field_menu.settings_page=="loadout":field_menu._refresh()
func _drop_loadout_weapon(index:int)->void:
	var actions:Array=weapon_inventory.slot_actions()
	if index>=0 and index<actions.size():weapon_inventory.drop_action(actions[index])
func _select_loadout_weapon(index:int)->void:
	var actions:Array=weapon_inventory.slot_actions()
	if not field_menu or index<0 or index>=actions.size():return
	field_menu.set_open(false);weapon_inventory.select_action(actions[index]);player.require_neutral_input()

func _construction_protected_targets() -> Array:
	var targets: Array = []
	for station in objective_nodes:
		if is_instance_valid(station): targets.append({"position": station.to_global(Vector3(0, STATION_SCREEN_HEIGHT, .37))})
	# Loose loot may overlap construction; only mission controls are protected.
	for unit in interference_units:
		if is_instance_valid(unit): targets.append({"position": unit.global_position})
	if is_instance_valid(spillway_gate): targets.append({"position": spillway_gate.global_position})
	return targets





func _on_explosive_launch(spec:Dictionary)->void:
	if network_bridge!=null and network_bridge.live():network_bridge.explosive(spec);return
	if paused or dead or complete:return
	var projectile=load("res://scripts/explosive_projectile.gd").new()
	add_child(projectile);projectile.add_to_group("ashfall_projectile");projectile.setup(self,spec)
	_activate_encounter(false)
func apply_explosive_damage(point:Vector3,radius:float,power:float,falloff:bool)->void:
	if paused or dead or complete or not point.is_finite() or radius<=0 or power<=0:return
	var targets:Array=[]
	for enemy in get_tree().get_nodes_in_group("enemies"):targets.append(enemy)
	for dummy in get_tree().get_nodes_in_group("practice_targets"):targets.append(dummy)
	for build in get_tree().get_nodes_in_group("field_construction"):targets.append(build)
	var decisions:Array[Dictionary]=[]
	for target in targets:
		if not is_instance_valid(target) or target.is_queued_for_deletion():continue
		var center:Vector3=target.global_position+Vector3.UP*.7 if target.is_in_group("enemies") else target.global_position
		var distance:=point.distance_to(center)
		if distance>radius:continue
		var amount:=power*(maxf(0,1-distance/radius) if falloff else 1.0)
		if amount>0:decisions.append({"target":target,"amount":amount})
	var head:Vector3=player.get_view_camera().global_position
	var self_distance:=point.distance_to(head)
	var self_damage:=power*(maxf(0,1-self_distance/radius) if falloff else 1.0) if self_distance<=radius else 0.0
	# Snapshot targets first: destroying one panel cannot change this blast's hits.
	for decision in decisions:
		var target:Node=decision.target
		if not is_instance_valid(target) or target.is_queued_for_deletion():continue
		var damage:float=decision.amount*field_menu.player_damage_multiplier
		if target.is_in_group("field_construction"):target.hit(damage,point,Vector3.UP)
		elif target.has_method("take_damage"):_apply_target_damage(target,damage)
	if self_damage>0:_damage_player(self_damage)
	if falloff:_impact(point,Vector3.UP)


func _apply_target_damage(target:Node,amount:float,direct_health:bool=false)->void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():return
	var before:=DamageFeedback.snapshot(target)
	if direct_health and target.has_method("take_melee_damage"):target.take_melee_damage(amount)
	else:target.take_damage(amount)
	if not is_instance_valid(target):return
	var applied:=DamageFeedback.loss(before,target)
	if combat_hud:combat_hud.notify_outgoing(applied.amount,target.get_instance_id(),applied.shield>0)

func _show_front_menu()->void:
	front_end_active=true;player.input_enabled=false;player.reset_motion();weapon.hide()
	ui_layer.hide();vr_label.hide();vr_cue.hide()
	combat_hud.hide()
	_title_was_holstered=weapon.is_holstered;weapon.is_holstered=true;weapon._apply_selection()
	front_menu=preload("res://scripts/front_menu1000.gd").new();add_child(front_menu);front_menu.setup(player)
	front_menu.play_requested.connect(_start_from_title)
	front_menu.settings_requested.connect(func():
		front_menu.set_active(false);field_menu.front_menu_visible=false;field_menu.set_open(true);field_menu.settings_from_home0992=true;field_menu.settings_page="root";field_menu._refresh())
	front_menu.quit_requested.connect(_quit_game)
	field_menu.resumed.connect(func():
		if front_end_active:
			player.input_enabled=false;field_menu.front_menu_visible=true;front_menu.set_active(true))
	field_menu.front_menu_visible=true;front_menu.set_active(true)
func _start_from_title()->void:
	if not front_end_active:return
	front_end_active=false;front_menu.set_active(false);field_menu.front_menu_visible=false
	combat_hud.show()
	front_menu.leave_lobby()
	weapon.is_holstered=_title_was_holstered;weapon._apply_selection();weapon.show();player.input_enabled=true;player.require_neutral_input()
	if OS.get_cmdline_user_args().has("--scope-playtest"):
		weapon_inventory.capacity=6
		if not weapon_inventory.has_weapon(13):weapon_inventory.pickup_weapon(13)
		weapon.select_inventory_weapon(13)
	#0993 map entry retains the existing calibration; initialization is an explicit menu action.
	if not xr_enabled:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _return_home0992()->void:
	if network_bridge!=null and network_bridge.live() and not network_bridge.applying and network_bridge.net.stage in ["match","results","loading","countdown"]:
		if network_bridge.net.is_host():network_bridge.net.request("home")
		else:network_bridge.leave_session()
		return
	if front_menu==null:return
	if revive_paddles:revive_paddles.stow()
	if field_consumables:field_consumables.stow(false)
	front_end_active=true;player.input_enabled=false;player.reset_motion();weapon.hide()
	_title_was_holstered=weapon.is_holstered;weapon.is_holstered=true;weapon._apply_selection()
	combat_hud.hide();ui_layer.hide();vr_label.hide();vr_cue.hide()
	field_menu.front_menu_visible=true;front_menu.page="lobby";front_menu.set_active(true)
