extends Node3D
## Original gaze-operated height initialization. Runtime poses remain untouched.
signal active_changed(active: bool)
signal completed(measurement: Dictionary)

const HOLD_SECONDS := 1.25
const GAZE_CONE_DEGREES := 15.0
const INITIAL_RIGHT_DEGREES := 18.0
const DISTANCE_M := 1.7
const RING_RADIUS := .205
const SUCCESS_SECONDS := .55
var player: AshPlayer
var field_menu: AshMenu
var active := false
var progress := 0.0
var state := "idle"
var _placed := false
var _startup_height_applied := false
var _startup := false
var _resume_input := true
var _success_remaining := 0.0
var _panel: Node3D
var _ring: MeshInstance3D
var _status: Label3D
var _chime: AudioStreamPlayer

func setup(actor: AshPlayer, menu: AshMenu = null) -> void:
	player = actor
	field_menu = menu
	process_priority = 150
	_build_graphic()
	if field_menu != null:
		field_menu.vertical_combat_reinitialize_requested.connect(begin)

func begin(startup: bool = false) -> void:
	if not is_instance_valid(player): return
	if not active: _resume_input = player._input_requested
	_startup = startup
	_startup_height_applied = false
	active = true
	state = "await_tracking"
	progress = 0.0
	_placed = false
	_panel.hide()
	player.reset_motion()
	player.vertical_combat_initializing = true
	active_changed.emit(true)

func cancel() -> void:
	if not active: return
	_finish()

func _process(delta: float) -> void:
	if not active or not is_instance_valid(player): return
	if state == "complete":
		_success_remaining -= maxf(delta, 0.0)
		if _success_remaining <= 0.0: _finish()
		return
	# Tracking loss suspends the target and resets the hold. An absent headset
	# cannot initialize or leave a nearly-complete countdown behind.
	if not player.tracking_available:
		progress = 0.0; _placed = false; _panel.hide(); state = "await_tracking"
		return
	if is_instance_valid(field_menu) and field_menu.is_open:
		progress = 0.0; _placed = false; _panel.hide(); state = "await_gaze"
		return
	if _startup and not _startup_height_applied:
		if player.initialize_vertical_combat_system().is_empty(): return
		_startup_height_applied = true
	if not _placed: _place_target()
	var camera := player.get_view_camera()
	advance_gaze(delta, camera.global_position, -camera.global_basis.z)

func _place_target() -> void:
	var camera := player.get_view_camera()
	var direction := (-camera.global_basis.z).rotated(Vector3.UP, -deg_to_rad(INITIAL_RIGHT_DEGREES)).normalized()
	_panel.global_position = camera.global_position + direction*DISTANCE_M
	_panel.look_at(camera.global_position, Vector3.UP, true)
	_panel.show()
	_placed = true
	state = "await_gaze"
	_update_progress_graphic()

func advance_gaze(delta: float, eye: Vector3, forward: Vector3) -> void:
	if not active or not _placed or state == "complete" or not is_finite(delta) or delta <= 0.0: return
	var target := (_panel.global_position-eye).normalized()
	var looking := forward.normalized().dot(target) >= cos(deg_to_rad(GAZE_CONE_DEGREES))
	progress = minf(1.0, progress+delta/HOLD_SECONDS) if looking else 0.0
	state = "holding" if looking else "await_gaze"
	_update_progress_graphic()
	if progress >= 1.0:
		var measurement := player.initialize_vertical_combat_system()
		if measurement.is_empty(): progress = 0.0; return
		state = "complete"
		_success_remaining = SUCCESS_SECONDS
		_status.text = "INITIALIZED / TOP %.3f m" % float(measurement.world_head_top_baseline_m)
		_chime.play()
		completed.emit(measurement)

func _finish() -> void:
	active = false; state = "idle"; _placed = false; _panel.hide()
	player.vertical_combat_initializing = false
	player.input_enabled = _resume_input and (not is_instance_valid(field_menu) or not field_menu.is_open)
	player.require_neutral_input()
	active_changed.emit(false)

func _exit_tree() -> void:
	if is_instance_valid(_chime):
		_chime.stop()
		_chime.stream = null

func _build_graphic() -> void:
	_panel = Node3D.new(); _panel.name = "InitializeVerticalCombatSystem"; add_child(_panel)
	var back := MeshInstance3D.new(); var quad := QuadMesh.new(); quad.size = Vector2(.98,.76); back.mesh = quad
	var background := _material(Color(.012,.028,.045,.93)); background.render_priority = 80
	back.material_override = background; _panel.add_child(back)
	var ring_track := MeshInstance3D.new(); ring_track.mesh = _arc_mesh(1.0); ring_track.material_override = _material(Color(.11,.24,.29)); ring_track.position = Vector3(0,.10,.003); _panel.add_child(ring_track)
	ring_track.material_override.render_priority = 82
	_ring = MeshInstance3D.new(); _ring.material_override = _material(Color(.21,.9,1.0)); _ring.position = Vector3(0,.10,.006); _panel.add_child(_ring)
	for visual in [back,ring_track,_ring]: visual.layers = 1<<19
	# Four rising chevrons form an original vertical-combat insignia.
	var insignia := Label3D.new(); insignia.text = "\u25b2\n\u25b2"; insignia.font_size = 52; insignia.pixel_size = .0012; insignia.position = Vector3(0,.15,.009); insignia.modulate = Color(.98,.64,.23); insignia.no_depth_test = true; insignia.render_priority = 86; insignia.outline_render_priority = 85; insignia.layers = 1<<19; _panel.add_child(insignia)
	_text("INITIALIZE", 42, Vector3(0,-.18,.009), Color(.96,.98,1))
	_text("VERTICAL COMBAT SYSTEM", 28, Vector3(0,-.245,.009), Color(.62,.85,.9))
	_status = _text("TURN TO LOOK / HOLD GAZE", 19, Vector3(0,-.315,.009), Color(.98,.69,.34))
	_chime = AudioStreamPlayer.new(); _chime.stream = _completion_chime(); _chime.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"; _chime.volume_db = -14; add_child(_chime)
	_panel.hide()

func _text(value: String, size: int, at: Vector3, color: Color) -> Label3D:
	var label := Label3D.new(); label.text = value; label.font_size = size; label.pixel_size = .00115; label.outline_size = 2; label.position = at; label.modulate = color; label.no_depth_test = true; label.render_priority = 86; label.outline_render_priority = 85; label.layers = 1<<19; _panel.add_child(label)
	return label

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.no_depth_test = true; material.albedo_color = color; material.cull_mode = BaseMaterial3D.CULL_DISABLED; material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; material.render_priority = 84; material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material

func _arc_mesh(fraction: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if fraction <= 0.0: return mesh
	var vertices := PackedVector3Array(); var count := maxi(1, ceili(96*fraction))
	for segment in range(count):
		var a := PI*.5 - TAU*fraction*float(segment)/float(count)
		var b := PI*.5 - TAU*fraction*float(segment+1)/float(count)
		var inner_a := Vector3(cos(a),sin(a),0)*(RING_RADIUS-.009)
		var outer_a := Vector3(cos(a),sin(a),0)*(RING_RADIUS+.009)
		var inner_b := Vector3(cos(b),sin(b),0)*(RING_RADIUS-.009)
		var outer_b := Vector3(cos(b),sin(b),0)*(RING_RADIUS+.009)
		vertices.append_array(PackedVector3Array([inner_a,outer_a,outer_b,inner_a,outer_b,inner_b]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = vertices; mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _update_progress_graphic() -> void:
	_ring.mesh = _arc_mesh(progress)
	_status.text = "HOLD GAZE / %.1f s" % ((1.0-progress)*HOLD_SECONDS) if progress > 0.0 else "TURN TO LOOK / HOLD GAZE"

func _completion_chime() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = 22050
	var bytes := PackedByteArray(); var count := int(.42*stream.mix_rate); bytes.resize(count*2)
	for i in range(count):
		var t := float(i)/stream.mix_rate
		var envelope := minf(1.0,t/.008)*pow(maxf(0.0,1.0-t/.42),2.0)
		var frequency := 660.0 if t < .13 else (880.0 if t < .26 else 1100.0)
		var sample := int(sin(TAU*frequency*t)*envelope*10000.0)
		bytes.encode_s16(i*2,sample)
	stream.data = bytes
	return stream
