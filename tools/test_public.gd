extends SceneTree
## Distribution-specific checks: exported routing, audible original replacements,
## content identity and intact inventory/supply contracts. Does not start XR.
var checks := 0
var failures := 0
var audio_paths: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PUBLIC_CHECK_FAILED ", label)

func collect_routes(value: Variant) -> void:
	if value is Dictionary:
		for child in value.values(): collect_routes(child)
	elif value is Array:
		for child in value: collect_routes(child)
	elif value is String:
		check(value.begins_with("res://assets/audio/") and value.ends_with(".wav"), "Audio route stays in the distributed audio bank")
		audio_paths[value] = true

func run() -> void:
	check(not XRServer.primary_interface or not XRServer.primary_interface.is_initialized(), "Validation does not initialize XR")
	for version in ["096", "097", "099", "0991", "0992"]:
		var path := "res://assets/audio/reference%s/manifest.json" % version
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(manifest is Dictionary, "Audio manifest parses: " + version)
		if not manifest is Dictionary: continue
		for key in manifest.keys(): check(key in ["generic", "weapons", "actions"], "No private extraction metadata in " + version)
		for key in ["generic", "weapons", "actions"]:
			check(manifest.has(key) and manifest[key] is Dictionary, "Routing dictionary present: " + key)
		collect_routes(manifest)
	check(audio_paths.size() > 100, "Full reference-compatible audio bank is routed")
	for path in audio_paths:
		check(ResourceLoader.exists(path), "Routed WAV is an importable resource: " + path)
		var sound := AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else load(path) as AudioStreamWAV
		check(sound != null, "Routed WAV loads: " + path)
		if sound == null: continue
		check(sound.mix_rate > 0 and sound.get_length() > 0, "Routed WAV has a playable duration: " + path)
		check(sound.format == AudioStreamWAV.FORMAT_16_BITS, "Public WAV is PCM16: " + path)
		var nonzero := false
		for offset in range(0, sound.data.size() - 1, 2):
			if abs(sound.data.decode_s16(offset)) > 16:
				nonzero = true
				break
		check(nonzero, "Public replacement is audible rather than an empty placeholder: " + path)
	var routes = load("res://scripts/reference_audio_099.gd")
	for kind in ["menu_click", "item_equip", "revive_facing", "revive_discharge", "revive_ready_full0992", "katana_shield_raise"]:
		check(routes.generic(kind, 0) != null, "Direct interaction cue still routes: " + kind)
	var inventory = load("res://scripts/weapon_inventory.gd").new()
	check(inventory.SLOT_LIMIT == 6 and inventory.capacity == 3, "Six carried slots with three initially unlocked")
	inventory.capacity = 99
	check(inventory.capacity == 6, "Capacity never expands beyond six")
	inventory.free()
	var supplies = load("res://scripts/supply_catalog_088.gd")
	check(supplies.AMOUNTS == {"pistol":16,"smg":20,"rifle":32,"shells":6,"sniper":5,"builds":6}, "Five ammunition families and build supply quantities remain intact")
	var network: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/network_content1000.json"))
	check(network is Dictionary and str(network.get("content_id", "")).length() == 64, "Public multiplayer fingerprint exists")
	check(network is Dictionary and network.get("content_id", "") != "0d564d02159e557111752545902b9ce1e10248d63273994369633b0873dd1ee1", "Public audio changes cannot falsely match the private build")
	if failures == 0:
		print("PUBLIC_CHECKS_OK checks=", checks, " routed_wavs=", audio_paths.size(), " xr=off")
	else:
		printerr("PUBLIC_CHECKS_FAILED failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
