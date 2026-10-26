extends SceneTree
var files:PackedStringArray=[]
func walk(path:String)->void:
	for file in DirAccess.get_files_at(path):files.append(path.path_join(file))
	for folder in DirAccess.get_directories_at(path):walk(path.path_join(folder))
func _initialize()->void:
	walk("res://");var bad:Array=[];var missing:Array=[]
	for path in files:
		if path.begins_with("res://tests/") or path.begins_with("res://newtests/") or path.begins_with("res://reports/") or path.ends_with(".ps1") or path.ends_with(".cmd"):bad.append(path)
	for path in ["res://scripts/upright_ui.gd","res://scripts/reticle_bounce_071.gd","res://scripts/recoil_endpoint_experiment.gd","res://scripts/revive_paddles.gd","res://scripts/rescue_training_dummy.gd","res://scripts/build_grid.gd","res://scripts/team_marks.gd","res://scripts/uzi_vertical_prefix.gd","res://scripts/smaw_tube_065.gd","res://scripts/field_item_models.gd","res://scripts/authored_catalog_detail.gd","res://scripts/authored_ring_dot_sight.gd","res://scripts/handgun_finish_063.gd","res://scripts/heavy_model_finish.gd","res://scripts/short_knife.gd","res://scripts/long_gun_finish_064.gd","res://scripts/remaining_firearm_finish.gd","res://scripts/matador_finish_064.gd","res://scripts/explosive_finish_064.gd","res://assets/materials/field_guard_064.gdshader","res://assets/ui/wheel_weapon_29.svg"]:
		if not ResourceLoader.exists(path):missing.append(path)
	for path in ["res://scripts/front_menu_090.gd","res://scripts/reference_hud_090.gd","res://scripts/common_reflex_090.gd","res://scripts/tracer_follow_090.gd","res://assets/audio/sfx/revive_shepard_00.wav","res://assets/audio/sfx/sword_swing_00.wav","res://assets/audio/sfx/katana_shield_00.wav"]:
		if not ResourceLoader.exists(path):missing.append(path)
	for path in ["res://scripts/front_menu_091.gd","res://scripts/lobby_map_091.gd","res://scripts/lobby_gallery_091.gd","res://scripts/sandbox_map_091.gd","res://scripts/revive_discharge_fx_091.gd","res://scripts/mp9_laser_091.gd","res://assets/materials/lobby_facade_091.gdshader","res://assets/data/reticle_motion_091.json","res://assets/audio/sfx/katana_shield_raise_00.wav"]:
		if not ResourceLoader.exists(path):missing.append(path)
	for path in ["res://scripts/spr_housing_094.gd","res://scripts/optic_material_094.gd","res://scripts/matador_secret_094.gd","res://scripts/magnum_finish_094.gd","res://scripts/weapon_icons_094.gd"]:
		if not ResourceLoader.exists(path):missing.append(path)
	for index in [0,1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,23,24,25,26,27,28,29]:
		if not ResourceLoader.exists("res://assets/ui/catalog094/weapon_%d.png"%index):missing.append(str(index))
	if not FileAccess.file_exists("res://assets/ui/catalog094/ATTRIBUTION.txt"):missing.append("catalog attribution")
	for path in ["res://scripts/reference_audio_096.gd","res://assets/audio/reference096/manifest.json"]:
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):missing.append(path)
	if not FileAccess.file_exists("res://assets/audio/reference096/ATTRIBUTION.txt"):missing.append("reference audio attribution")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/reference_062.json"))
	var observed:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/recoil_observed_067.json"))
	var profile_present:bool=FileAccess.file_exists("res://assets/data/recoil_observed_067.json")
	var passed:bool=profile_present and bad.is_empty() and missing.is_empty() and ProjectSettings.get_setting("application/config/version")=="0.9.6" and ProjectSettings.get_setting("application/config/custom_user_dir_name")=="AshfallVR-Standalone096-Playtest"
	for id in ["px4","tec9","mp9","fal","rfb","mp5","katana","excalibur","knife","akm","p90","cx4","frag","cyberblade","awp","dt11","m1014","magnum","fal_alt","ump_alt","katana_alt","dt11_alt","frag_alt","mk18","s85","uzi","matadors","spr","m60","m60_reload087","smaw"]:
		var folder:String="res://assets/models/download_"+id+"/"
		passed=passed and ResourceLoader.exists(folder+"model.glb") and not FileAccess.get_file_as_string(folder+"ATTRIBUTION.txt").is_empty()
		var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"asset-provenance.json"))
		passed=passed and FileAccess.get_file_as_string(folder+"ATTRIBUTION.txt").contains(str(data.asset.license)) and data.id==id and int(data.source_triangles)==int(data.body_triangles)+int(data.magazine_triangles)+int(data.moving_triangles)+int(data.get("omitted_triangles",0))
	passed=passed and is_equal_approx(manifest.movement.player_head_top_height_m,1.524) and is_equal_approx(manifest.movement.player_eye_height_m,1.404) and is_equal_approx(manifest.dimensions.sword_grip_from_outer_pommel_m,.2032) and observed.profiles.size()==5
	passed=passed and ProjectSettings.get_setting("ashfall/awp_zoom_damping_experiment",false)==true
	passed=passed and ResourceLoader.exists("res://assets/models/ump_aggressor/ump_aggressor.glb") and FileAccess.get_file_as_string("res://assets/models/ump_aggressor/ATTRIBUTION.txt").contains("REEESkins")
	passed=passed and is_equal_approx(preload("res://scripts/ump_aggressor_model.gd").DISPLAY_SCALE,.7182)
	passed=passed and ResourceLoader.exists("res://assets/models/tactical_1911/tactical_1911.glb") and FileAccess.get_file_as_string("res://assets/models/tactical_1911/ATTRIBUTION.txt").contains("Vlasov Daniil")
	passed=passed and is_equal_approx(preload("res://scripts/explosive_weapon.gd").ROCKET_GRIP.z,-.3195)
	passed=passed and ResourceLoader.exists("res://assets/materials/build_panel_user.png")
	var tile:Image=load("res://assets/materials/build_panel_user.png").get_image();tile.convert(Image.FORMAT_RGB8);tile.clear_mipmaps()
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(tile.get_data());passed=passed and digest.finish().hex_encode()=="8a35e7d2645cecb95a3ecc9fb89d0d31aa6032f9fd5d4b6fb68e448b2c26c883"
	var rifle=load("res://scripts/precision_rifle.gd").new();passed=passed and is_equal_approx(rifle.scoped_damping_multiplier(4.0,true),2.0);rifle.free()
	var preserved:Dictionary={"res://assets/data/one_star_050.json":"4733a7968f6e18be705d7af4c09ecc18d03827d4019d69ab8a4df276c0137833","res://assets/data/recoil_observed_061.json":"dd6fb848e06a503104d87dd9e9ff8feaa08cf4bb5812fba3d0118dc9d0e6cb7c","res://assets/data/recoil_observed_062.json":"ca5c794e681216cd73ef7d17c8de7e01f14e89184232806b135cd0e4546df5cb","res://assets/data/recoil_observed_066.json":"889e1eb6e14f591295e10918fa29524e232c7444963a633cf3e4fcea29ae28f4","res://assets/data/recoil_observed_067.json":"cb494da42fc7900d049d4104e1c680e775fff43e2fe4b84f4e6f1f5627b83930","res://assets/data/reference_062.json":"2ff58d2f9b8fbbfa863f6408ed32053b50191ffd7f82a364b95688eb9760ad82"}
	for resource in preserved:passed=passed and FileAccess.get_sha256(resource)==preserved[resource]
	passed=passed and is_equal_approx(preload("res://scripts/blade_assets.gd").SWORD_LENGTH,1.4101590361445784)
	for resource in ["res://assets/ui/item_banana.svg","res://assets/ui/item_soda.svg","res://assets/ui/item_shaker.svg","res://assets/ui/settings_0.svg","res://scripts/measurement_calibration.gd"]:passed=passed and ResourceLoader.exists(resource)
	passed=passed and is_equal_approx(preload("res://scripts/player.gd").DEFAULT_PLAYER_TOP_HEIGHT_M,1.8288) and is_equal_approx(preload("res://scripts/field_consumables.gd").CONSUME_HEADSET_RADIUS_M,.45)
	for path in ["res://scripts/grip_hand_086.gd","res://scripts/banana_peel_086.gd","res://scripts/ping_wheel_086.gd","res://assets/hands/xrtools086/Hand_Glove_low_L.gltf","res://assets/hands/xrtools086/Hand_Glove_low_R.gltf","res://assets/hands/xrtools086/textures_glove_caucasian_dark_camo.png","res://assets/hands/xrtools086/textures_glove_fingerless_occlusionRoughnessMetallic.png"]:passed=passed and ResourceLoader.exists(path)
	passed=passed and FileAccess.get_file_as_string("res://assets/hands/xrtools086/License.md").contains("Miodrag Sejic") and FileAccess.get_file_as_string("res://assets/hands/xrtools086/ATTRIBUTION.txt").contains("CC0-1.0")
	passed=passed and ResourceLoader.exists("res://scripts/downloaded_m60_087.gd") and FileAccess.file_exists("res://assets/models/download_m60/reload-fit.json")
	var m60_fit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/download_m60/reload-fit.json"))
	passed=passed and is_equal_approx(float(m60_fit.overall_length),1.39879070856) and str(m60_fit.hinge_provenance).contains("no skeleton")
	print("PACKAGE_AUDIT_096 ",JSON.stringify({"passed":passed,"version":ProjectSettings.get_setting("application/config/version"),"profile":ProjectSettings.get_setting("application/config/custom_user_dir_name"),"file_count":files.size(),"qa_or_launcher_files":bad,"missing_required_resources":missing,"historical_reference_head_top_m":manifest.movement.player_head_top_height_m,"runtime_head_top_m":preload("res://scripts/player.gd").DEFAULT_PLAYER_TOP_HEIGHT_M,"runtime_eye_m":preload("res://scripts/player.gd").DEFAULT_EYE_HEIGHT_M,"observed_profile_count":observed.profiles.size(),"preserved_data_hashes":preserved,"sword_calibrated_si_length_m":preload("res://scripts/blade_assets.gd").SWORD_LENGTH,"measurement_correction_factor":48.0/41.5,"xr_mode":"off","native_rendered":false,"shader_gpu_compiled":false,"source_hands":"CC0 Godot XR Tools tactical gloves"}))
	quit(0 if passed else 1)
