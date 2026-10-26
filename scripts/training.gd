class_name AshTraining
extends Node
## Optional, nonblocking hints. The caller decides when/where to display them.
var player: AshPlayer
var weapon
var _progress: Dictionary = {}
var _start_position := Vector3.ZERO
var _previous_reload := "ready"

func setup(actor: AshPlayer, rifle: Node3D) -> void:
	player = actor
	weapon = rifle
	reset()

func reset() -> void:
	_progress.clear()
	if is_instance_valid(player): _start_position = player.global_position
	_previous_reload = weapon.reload_state if is_instance_valid(weapon) else "ready"

func mark_progress(step: String) -> void:
	if step in ["move", "climb", "glide", "reload"]:
		_progress[step] = true

func get_progress() -> Dictionary:
	return _progress.duplicate()

func _controls_ready() -> bool:
	if not is_instance_valid(player) or not is_instance_valid(weapon): return false
	if not player.input_enabled or player.head_obstructed: return false
	if player.xr_enabled:
		return player.tracking_available and player.is_hand_input_ready(player.left_hand) and player.is_hand_input_ready(player.right_hand)
	return true

func _process(_delta: float) -> void:
	observe_progress()

func observe_progress() -> void:
	if not _controls_ready(): return
	var displacement := player.global_position - _start_position
	if Vector2(displacement.x, displacement.z).length() >= 1.5:
		mark_progress("move")
	if player.climbing: mark_progress("climb")
	if player.gliding: mark_progress("glide")
	if _previous_reload in ["needs_rack", "open_loaded"] and weapon.reload_state == "ready" and weapon.ammo > 0:
		mark_progress("reload")
	_previous_reload = weapon.reload_state

func get_hint(include_reload: bool = true) -> String:
	if not _controls_ready(): return ""
	observe_progress()
	var vr := player.xr_enabled
	if not include_reload and (weapon.reload_state != "ready" or weapon.ammo <= 0): return ""
	var specific_hint: String = weapon.get_reload_hint() if weapon.has_method("get_reload_hint") else ""
	if include_reload and not specific_hint.is_empty() and (weapon.reload_state != "ready" or weapon.ammo <= 0): return specific_hint
	match weapon.reload_state:
		"needs_mag":
			return "Grip magazine below weapon; insert upward." if vr else "R: insert magazine."
		"held_mag":
			return "Insert magazine into lit well." if vr else "R: insert magazine."
		"needs_rack":
			return "Release grip; grip and pull bolt." if vr else "R: rack bolt."
	if weapon.ammo <= 0:
		return manual_eject_hint() + "." if vr else "R: reload."
	if player.climbing and not _progress.has("glide"):
		return "Pull down: climb. Release and spread arms: glide." if vr else "E: climb. Release, then G: glide."
	if not _progress.has("move"):
		return "Left stick: move. Right stick: turn." if vr else "WASD: move. Mouse: aim. Space: jump."
	if not _progress.has("climb"):
		return "Touch wall; grip and pull down." if vr else "Face wall; hold E to climb."
	if not _progress.has("glide"):
		return "Release ledge; spread arms to glide." if vr else "Jump from ledge; G: glide."
	if not _progress.has("reload"):
		if not include_reload: return ""
		if not specific_hint.is_empty(): return specific_hint
		return manual_eject_hint() + "; insert magazine, then rack." if vr else "R: eject, insert, rack."
	return ""


func manual_eject_hint() -> String:
	if player.dominant_hand == "left" and player.sprint_binding == "left_stick_click":
		return "pull the weapon-hand stick down to eject"
	return "click the weapon-hand stick to eject"
