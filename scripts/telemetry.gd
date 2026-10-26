class_name AshTelemetry
extends RefCounted
## Caller feeds observed state; this class never probes hardware or uploads data.
const SAMPLE_CAP := 2048
const EVENT_CAP := 128
const CHECKPOINT_SECONDS := 30.0
const EVENT_NAMES := ["session_start","startup_failed","state_change","session_begun","session_synchronized","session_visible","session_focussed","session_stopping","session_loss_pending","instance_exiting","window_close","menu_quit","smoke_complete","test_complete","running"]
var _rng := RandomNumberGenerator.new()
var _process_samples: Array[float] = []
var _gpu_samples: Array[float] = []
var _events: Array[Dictionary] = []
var _process_seen := 0
var _gpu_seen := 0
var _gpu_missing := 0
var _frames := 0
var _elapsed := 0.0
var _focused := 0.0
var _left_ready := 0.0
var _right_ready := 0.0
var _both_ready := 0.0
var _gpu_poll := 0.0
var _checkpoint := 0.0
var _xr_enabled := false
var _started := ""
var _path := ""
var _finalized := false
var _last_state := ""
var _write_count := 0
var _build_identity: Dictionary = {}

func set_build_identity(version: String, executable: String) -> void:
	# Local diagnostic record independent of bounded event history.
	_build_identity = {"version":version,"executable":executable}

func begin(xr_enabled: bool, output_path: String = "") -> void:
	_process_samples.clear(); _gpu_samples.clear(); _events.clear()
	_process_seen = 0; _gpu_seen = 0; _gpu_missing = 0; _frames = 0
	_elapsed = 0.0; _focused = 0.0; _left_ready = 0.0; _right_ready = 0.0; _both_ready = 0.0
	_gpu_poll = 0.0; _checkpoint = 0.0; _finalized = false; _last_state = ""; _write_count = 0
	_xr_enabled = xr_enabled
	_started = Time.get_datetime_string_from_system(true)
	_rng.seed = 719341
	_path = output_path
	if _path.is_empty():
		_path = "user://logs/session-" + _started.replace(":", "").replace("-", "") + "-" + str(Time.get_ticks_msec()) + ".json"
	record_event("session_start")

func sample_frame(delta: float, viewport_gpu_ms: float, focused: bool, left_ready: bool, right_ready: bool) -> void:
	if _finalized or not is_finite(delta) or delta <= 0.0: return
	_frames += 1
	_elapsed += delta
	_checkpoint += delta
	_process_seen += 1
	_reservoir(_process_samples, delta * 1000.0, _process_seen)
	# XR-specific durations cannot accrue during desktop debug runs.
	if _xr_enabled:
		if focused: _focused += delta
		if focused and left_ready: _left_ready += delta
		if focused and right_ready: _right_ready += delta
		if focused and left_ready and right_ready: _both_ready += delta
	var state := "%s/%s/%s" % [focused, left_ready, right_ready]
	if state != _last_state:
		_last_state = state
		record_event("state_change", {"focused":focused,"left_ready":left_ready,"right_ready":right_ready})
	# Viewport timestamps can repeat between callbacks. Sample at <=10 Hz.
	_gpu_poll += delta
	if _gpu_poll >= 0.1:
		_gpu_poll = fmod(_gpu_poll, 0.1)
		if is_finite(viewport_gpu_ms) and viewport_gpu_ms > 0.0:
			_gpu_seen += 1
			_reservoir(_gpu_samples, viewport_gpu_ms, _gpu_seen)
		else: _gpu_missing += 1
	if _checkpoint >= CHECKPOINT_SECONDS:
		_checkpoint = 0.0
		write_checkpoint()

func _reservoir(values: Array[float], value: float, seen: int) -> void:
	if values.size() < SAMPLE_CAP: values.append(value); return
	var index := _rng.randi_range(0, seen - 1)
	if index < SAMPLE_CAP: values[index] = value

func record_event(reason: String, state: Dictionary = {}) -> void:
	# Whitelist fields. Never persist caller-supplied device names/IDs or paths.
	var event := {"elapsed_seconds":_elapsed,"utc":Time.get_datetime_string_from_system(true),"reason":reason if reason in EVENT_NAMES else "other"}
	for key in ["focused","left_ready","right_ready"]:
		if state.get(key) is bool: event[key] = state[key]
	if _events.size() >= EVENT_CAP: _events.pop_front()
	_events.append(event)

func _stats(values: Array[float], observed: int) -> Dictionary:
	if values.is_empty(): return {"available":false,"observed_count":observed,"retained_count":0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted: total += value
	return {"available":true,"observed_count":observed,"retained_count":sorted.size(),"sampling":"bounded_uniform_reservoir","mean_ms":total/sorted.size(),"p50_ms":sorted[int((sorted.size()-1)*0.50)],"p95_ms":sorted[int((sorted.size()-1)*0.95)],"p99_ms":sorted[int((sorted.size()-1)*0.99)],"retained_max_ms":sorted[-1]}

func snapshot(exit_reason: String = "running", exit_code: int = 0) -> Dictionary:
	return {"schema_version":1,"build_identity":_build_identity.duplicate(),"started_utc":_started,"updated_utc":Time.get_datetime_string_from_system(true),"engine":Engine.get_version_info().string,"xr_enabled":_xr_enabled,"observation_seconds":_elapsed,"frame_callbacks":_frames,"focus_seconds":_focused,"left_controller_ready_while_focused_seconds":_left_ready,"right_controller_ready_while_focused_seconds":_right_ready,"both_controllers_ready_while_focused_seconds":_both_ready,"process_callback_interval":_stats(_process_samples,_process_seen),"viewport_gpu_render_time":_stats(_gpu_samples,_gpu_seen),"gpu_missing_polls":_gpu_missing,"gpu_poll_hz_max":10,"events":_events.duplicate(true),"event_history_cap":EVENT_CAP,"finalized":_finalized,"exit_reason":exit_reason if exit_reason in EVENT_NAMES else "other","exit_code":exit_code,"physical_headset_test_claim":"not established by telemetry; requires human confirmation","timing_scope":"Process callback intervals are not GPU time. Viewport GPU measurements exclude runtime/compositor/Link; percentiles use bounded approximate sampling and do not prove headset frame rate or comfort."}

func write_checkpoint(exit_reason: String = "running", exit_code: int = 0) -> Error:
	if _path.is_empty(): return ERR_UNCONFIGURED
	var directory := ProjectSettings.globalize_path(_path.get_base_dir())
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK: return error
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(snapshot(exit_reason,exit_code),"\t"))
	file.close()
	_write_count += 1
	return OK

func finish(reason: String, exit_code: int = 0) -> Error:
	if _finalized: return OK
	record_event(reason)
	_finalized = true
	return write_checkpoint(reason,exit_code)

func get_output_path() -> String:
	return _path



