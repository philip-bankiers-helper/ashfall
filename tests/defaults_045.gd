extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var menu=load("res://scripts/menu.gd").new();root.add_child(menu);menu.setup(actor);menu.set_process(false)
	check(menu.weapon_settings.motion_damping==1.0 and menu.weapon_settings.offhand_influence==0.0,"fresh actual menu defaults100percent damping zero offhand")
	menu.apply_settings({});check(menu.weapon_settings.motion_damping==1.0 and menu.weapon_settings.offhand_influence==0.0,"missing saved settings uses new defaults")
	var saved:Dictionary=menu.get_settings()
	saved.weapon_settings={"motion_damping":.17,"offhand_influence":.73,"grip_toggle":true}
	saved.hud_size=1.4;saved.difficulty=.8;saved.enemy_damage_multiplier=2.0;saved.player_damage_multiplier=.5
	saved.audio_volumes={"Music":.22,"SFX":.45,"Ambience":.33,"Voice":.66}
	saved.dominant_hand="left";saved.walk_speed_multiplier=1.3;saved.forward_reference="hand";saved.sprint_binding="left_grip"
	menu.apply_settings(saved)
	check(menu.weapon_settings==saved.weapon_settings,"explicit saved custom weapon values preserved")
	var roundtrip:Dictionary=menu.get_settings()
	check(roundtrip.hud_size==1.4 and roundtrip.difficulty==.8 and roundtrip.audio_volumes==saved.audio_volumes and roundtrip.dominant_hand=="left" and roundtrip.walk_speed_multiplier==1.3 and roundtrip.forward_reference=="hand" and roundtrip.sprint_binding=="left_grip","saved unrelated HUD audio difficulty movement handedness preserved")
	check(roundtrip.enemy_damage_multiplier==2.0 and roundtrip.player_damage_multiplier==.5,"separate damage multipliers preserved")
	var encoded:=JSON.stringify(roundtrip);var decoded:Dictionary=JSON.parse_string(encoded)
	menu.apply_settings(decoded);check(menu.get_settings()==roundtrip,"actual serialized settings roundtrip retains explicit weapon and unrelated choices")
	for missing_key in ["motion_damping","offhand_influence"]:
		var partial:Dictionary=roundtrip.duplicate(true);partial.weapon_settings.erase(missing_key);menu.apply_settings(partial)
		check(menu.weapon_settings[missing_key]==menu.WEAPON_SETTINGS_DEFAULTS[missing_key],"missing weapon key gets current default "+missing_key)
		var retained:String="offhand_influence" if missing_key=="motion_damping" else "motion_damping"
		check(menu.weapon_settings[retained]==roundtrip.weapon_settings[retained],"present sibling custom setting retained "+retained)
	menu.apply_settings(roundtrip);var before_reset:Dictionary=menu.get_settings();menu.reset_weapon_settings();var after_reset:Dictionary=menu.get_settings()
	check(after_reset.weapon_settings==menu.WEAPON_SETTINGS_DEFAULTS,"explicit weapon reset uses100percent zero defaults")
	before_reset.erase("weapon_settings");after_reset.erase("weapon_settings")
	check(before_reset==after_reset,"weapon reset changes no unrelated setting")
	var zero:Dictionary=roundtrip.duplicate(true);zero.weapon_settings={"motion_damping":0.0,"offhand_influence":1.0,"grip_toggle":false};menu.apply_settings(zero)
	check(menu.weapon_settings.motion_damping==0.0 and menu.weapon_settings.offhand_influence==1.0,"old explicitzero damping and full offhand are valid customs not migrated")
	menu.reset_movement_settings();check(menu.weapon_settings.motion_damping==0.0 and menu.weapon_settings.offhand_influence==1.0,"movement reset preserves custom weapon settings")
	for malformed in [null,"bad",{"motion_damping":"bad","offhand_influence":NAN}]:
		var invalid:Dictionary=roundtrip.duplicate(true);invalid.weapon_settings=malformed;menu.apply_settings(invalid)
		check(menu.weapon_settings.motion_damping==1.0 and menu.weapon_settings.offhand_influence==0.0,"malformed weapon settings use current safe defaults")
	menu.settings_page="weapons";menu._refresh();check(menu._labels()[0].contains("100%") and menu._labels()[1].contains("0%"),"actual weapon settings labels reflect defaults")
	menu.queue_free();actor.queue_free();await process_frame
	print("DEFAULTS_045 checks=",checks," failures=",failures," headset_tested=false");quit(failures)
