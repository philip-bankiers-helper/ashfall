extends Node3D
## Synthetic dual-view workload only. No XR, Link, compositor or head tracking.
const WorldScript = preload("res://scripts/world.gd")
const EYE_SIZE := Vector2i(1832, 1920)
const IPD := 0.064
const FOV := 90.0
const VIEWS := [
	{"name":"relay", "position":Vector3(1, 2.0, -8), "target":Vector3(0, 2, -20)},
	{"name":"gallery", "position":Vector3(10.5, 2.2, -28), "target":Vector3(20, 2.6, -39)},
	{"name":"uplink", "position":Vector3(12, 17.8, -61), "target":Vector3(16, 18, -72)}
]
var eyes: Array[SubViewport] = []
var cameras: Array[Camera3D] = []
var quality := "balanced"
var output := "user://stereo-benchmark.json"
var logic_only := false
var warmup := 3.0
var duration := 6.0
var phase_time := 0.0
var view_index := 0
var rows: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var quality_config: Dictionary
var finished := false

func _ready() -> void:
	# Independent scene timer still fires if a child fixture's process callback
	# hits a script error before advancing its benchmark phase.
	get_tree().create_timer(45.0, true).timeout.connect(func():
		if not finished:
			push_error("STEREO_BENCHMARK_WATCHDOG: exceeded 45 seconds")
			get_tree().quit(4))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="): quality = arg.trim_prefix("--quality=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--logic-only": logic_only = true
	if quality not in ["balanced", "high"]:
		push_error("Unsupported benchmark quality"); get_tree().quit(2); return
	if DisplayServer.get_name() == "headless" and not logic_only:
		push_error("Headless cannot measure GPU; use --logic-only"); get_tree().quit(2); return
	var xr := XRServer.find_interface("OpenXR")
	if xr != null and xr.is_initialized():
		push_error("Benchmark refuses initialized OpenXR; launch with --xr-mode off"); get_tree().quit(2); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world = _create_world()
	quality_config = world.set_graphics_quality(quality)
	var root_view := get_viewport()
	root_view.disable_3d = true
	RenderingServer.viewport_set_measure_render_time(root_view.get_viewport_rid(), not logic_only)
	for side in range(2):
		var view := SubViewport.new()
		view.name = "LeftEye" if side == 0 else "RightEye"
		view.size = EYE_SIZE
		view.world_3d = get_world_3d()
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.msaa_3d = Viewport.MSAA_4X if quality == "high" else Viewport.MSAA_2X
		view.positional_shadow_atlas_size = 4096 if quality == "high" else 2048
		add_child(view)
		RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), not logic_only)
		var camera := Camera3D.new()
		camera.fov = FOV
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.near = 0.05
		camera.far = 300.0
		view.add_child(camera)
		camera.current = true
		eyes.append(view); cameras.append(camera)
		# Root displays scaled eye textures with 2D only, avoiding a third 3D view.
		var preview := TextureRect.new()
		preview.texture = view.get_texture()
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.position = Vector2(side * 640, 0)
		preview.size = Vector2(640, 720)
		add_child(preview)
	if logic_only: warmup = 0.02; duration = 0.04
	print("STEREO_BENCHMARK_START quality=",quality," eye_size=",EYE_SIZE," ipd_m=",IPD," fov_vertical=",FOV," logic_only=",logic_only)
	_move_cameras(0)

func _create_world() -> Node3D:
	var world = WorldScript.new()
	add_child(world)
	world.build()
	return world

func _move_cameras(t: float) -> void:
	var view: Dictionary = VIEWS[view_index]
	var center: Vector3 = view.position + Vector3(sin(t * 0.8) * 0.6, sin(t * 0.6) * 0.08, cos(t * 0.8) * 0.25)
	var basis := Basis.looking_at(view.target - center, Vector3.UP)
	for side in range(2):
		cameras[side].global_transform = Transform3D(basis, center + basis.x * (-IPD * 0.5 if side == 0 else IPD * 0.5))

func _process(delta: float) -> void:
	if finished or cameras.size() != 2: return
	phase_time += delta
	_move_cameras(phase_time)
	if phase_time > warmup and not logic_only:
		var left := RenderingServer.viewport_get_measured_render_time_gpu(eyes[0].get_viewport_rid())
		var right := RenderingServer.viewport_get_measured_render_time_gpu(eyes[1].get_viewport_rid())
		if left > 0.0 and right > 0.0:
			samples.append({"left_gpu_ms":left,"right_gpu_ms":right,"eye_sum_ms":left+right,"process_delta_ms":delta*1000.0,"root_2d_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())})
	if phase_time >= warmup + duration:
		rows.append({"view":VIEWS[view_index].name,"samples":samples.duplicate(true),"sample_count":samples.size(),"statistics":_statistics()})
		print("STEREO_VIEW_END ",VIEWS[view_index].name," samples=",samples.size())
		samples.clear(); phase_time = 0; view_index += 1
		if view_index >= VIEWS.size(): _finish()

func _statistics() -> Dictionary:
	var stats := {}
	for key in ["left_gpu_ms","right_gpu_ms","eye_sum_ms","process_delta_ms","root_2d_gpu_ms"]:
		var values: Array[float] = []
		for sample in samples: values.append(sample[key])
		values.sort()
		if values.is_empty(): stats[key] = {"available":false}; continue
		var total := 0.0
		for value in values: total += value
		stats[key] = {"mean":total/values.size(),"median":values[int(values.size()*0.5)],"p95":values[mini(int(values.size()*0.95),values.size()-1)],"max":values[-1]}
	return stats

func _finish() -> void:
	finished = true
	var result := {"synthetic_stereo":true,"physical_headset_tested":false,"logic_only":logic_only,"quality":quality,"quality_config":quality_config,"per_eye_width":EYE_SIZE.x,"per_eye_height":EYE_SIZE.y,"ipd_m":IPD,"vertical_fov_degrees":FOV,"warmup_seconds_per_view":warmup,"sample_seconds_per_view":duration,"adapter":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"root_3d_disabled":get_viewport().disable_3d,"shared_campaign_world":eyes[0].world_3d == eyes[1].world_3d,"rows":rows,"limits":"Two independent cameras, not OpenXR multiview. Excludes runtime/compositor/Link, distortion, physical tracking, dynamic enemies, weapon and campaign UI. Eye GPU sum is workload evidence, not headset frame time or predicted FPS."}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null: push_error("Cannot write benchmark output"); get_tree().quit(2); return
	file.store_string(JSON.stringify(result,"\t")); file.close()
	var valid := logic_only or rows.all(func(row): return row.sample_count >= 10)
	print("STEREO_BENCHMARK_END valid=",valid," output=",output)
	get_tree().quit(0 if valid else 3)
