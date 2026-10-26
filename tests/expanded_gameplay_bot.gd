extends "res://tests/gameplay_bot.gd"
var transitions: Array[Dictionary] = []
var tracked_mission := "relay"
var legacy_hash_before := ""
var jammer_shots := 0
var aiming_at_jammer := false

func _ready() -> void:
	legacy_hash_before = FileAccess.get_sha256("user://campaign.json") if FileAccess.file_exists("user://campaign.json") else "missing"
	super._ready()
	# Startup may restore an old isolated checkpoint before new_campaign().
	# Only transitions during the actual fresh traversal belong in evidence.
	transitions.clear()
	if not extended_campaign:
		push_error("Expanded bot requires --extended")
		get_tree().quit(2)
		return
	var authored: Dictionary = campaign_extension.route_waypoints
	routes[3] = Array(authored.crown_entry)
	var spillway: Array = Array(authored.spillway_entry)
	spillway.append_array(Array(authored.spillway_stairs))
	# Isolator interaction happens before walking through the production gate.
	spillway.append_array(Array(authored["return"]).slice(0,3))
	routes.append(spillway)
	routes.append(Array(authored["return"]).slice(2))
	weapon.shot.connect(func(_a,_b,_c):
		if aiming_at_jammer: jammer_shots += 1)
	weapon.pellet_shot.connect(func(_a,_b,_c):
		if aiming_at_jammer: jammer_shots += 1)

func _process(delta):
	super._process(delta)
	if mission_id() == "dam_crown" and previous_chapter == chapter and player.global_position.y > 23.0 and player.global_position.z < -86.0 and not captures.has("dam-crown"):
		_capture_bot_frame("dam-crown")
	if mission_id() == "spillway" and previous_chapter == chapter and player.global_position.y > 5.8 and player.global_position.y < 7.5 and player.global_position.z > -57.0 and not captures.has("spillway"):
		_capture_bot_frame("spillway")

func _begin_chapter():
	var outgoing := tracked_mission
	var incoming := mission_id()
	var survivors: int = enemies.size()
	var prior_kills: int = total_kills
	super._begin_chapter()
	if outgoing != incoming and outgoing in ["dam_crown","spillway"]:
		var entry := {"mission":outgoing,"next":incoming,"survivors":survivors,"despawn_score_delta":total_kills-prior_kills,"position":str(player.global_position)}
		transitions.append(entry)
		print("EXPANDED_SURVIVOR_TRANSITION ",JSON.stringify(entry))
	tracked_mission = incoming

func bot_targets() -> Array:
	# Capture targeting phase before emitted shot synchronously advances mission.
	aiming_at_jammer = mission_id() == "dam_crown"
	if mission_id() == "dam_crown":
		return interference_units.filter(func(unit): return not unit.is_disabled and player.global_position.distance_to(unit.global_position) < 5.0)
	if mission_id() == "spillway": return []
	return enemies

func bot_should_glide() -> bool: return false
func bot_time_limit() -> float: return 300.0
func bot_report_suffix() -> String: return "-expanded"
func _quit_game(exit_code: int = 0, reason: String = "menu_quit"):
	if reason == "test_complete" and complete and DisplayServer.get_name() != "headless":
		# Post-report presentation observation; excluded from traversal metrics.
		await get_tree().create_timer(12.0).timeout
		await _capture_bot_frame("finish-after-12s")
	await super._quit_game(exit_code, reason)

func bot_extra_report() -> Dictionary:
	var legacy_after := FileAccess.get_sha256("user://campaign.json") if FileAccess.file_exists("user://campaign.json") else "missing"
	return {"expanded":true,"mission":mission_id(),"survivor_transitions":transitions,"jammer_shots":jammer_shots,"legacy_unchanged":legacy_after==legacy_hash_before,"objective_combat":"production weapon raycasts, no guard targeting in new missions"}

