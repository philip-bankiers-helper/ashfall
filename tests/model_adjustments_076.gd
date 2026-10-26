extends "res://tests/model_layout_075.gd"
func run()->void:
	# Exercise the retained, actually instantiated lightweight catalog assets.
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false);game.field_menu.set_open(false)
	for gun in game.weapon.weapons:gun.set_process(false);gun.set_physics_process(false)
	check(not ResourceLoader.has_cached("res://assets/models/tactical_1911/tactical_1911.glb") and not ResourceLoader.has_cached("res://assets/models/ump_aggressor/ump_aggressor.glb"),"lightweight start does not load imported gun meshes/textures")
	var px4=game.weapon.weapons[2];px4.show();px4.model.show()
	check(px4.model.get_node("PX4Grip075").position.is_equal_approx(Vector3(0,-.07,-.09)),"authored PX4 whole grip moved4cm rearward")
	check(px4.model.get_node("PX4ForwardTrigger075").position==Vector3(0,0,.04),"PX4 complete trigger and guard move with grip")
	check(absf(px4.magazine.position.z+.11)<.00001,"PX4 actual seated magazine moves4cm rearward")
	check(px4.get_magazine_insert_point().is_equal_approx(Vector3(0,-.18,-.11)),"PX4 physical insertion target follows rearward well")
	check(px4.get_magazine_offer_point().is_equal_approx(Vector3(0,-.278,-.11)),"PX4 offered magazine follows rearward well")
	px4.reload_state="held_mag";px4._process(0)
	check(px4.guide.position.distance_to(px4.get_magazine_insert_point())<.00001,"PX4 actual runtime insertion cue follows target")
	check(absf(px4.insertion_arrow.position.z+.11)<.00001,"PX4 visible insertion arrow follows moved lower assembly")
	check(px4.get_shot_transform().origin.distance_to(px4.model.to_global(Vector3(0,.045,-.29)))<.00001,"PX4 firing datum remains at original muzzle")
	for index in [17,18,19,20]:
		var gun=game.weapon.weapons[index];gun.show();gun.model.show()
		var core:Node3D=gun.model.get_node("CatalogGripCore");var z:float=-.040 if index in [17,18] else -.035
		check(absf(core.position.z-z)<.000001,"authored "+gun.profile_id+" requested grip center")
		check(core.is_visible_in_tree(),"authored "+gun.profile_id+" fallback visibly retained")
		check(not gun.get_meta("imported_tactical_1911",false),"lightweight "+gun.profile_id+" does not load downloaded meshes")
		check(absf(gun.magazine.position.z-(-.15 if index==17 else -.015))<.00001,gun.profile_id+" magazine stays at unrequested original location")
		var trigger_point:=Vector3(0,-.05,-.04+(-.065 if index in [17,18] else -.060))
		check(not core.mesh.get_aabb().has_point(core.to_local(gun.model.to_global(trigger_point))),gun.profile_id+" relocated guard keeps trigger ahead of actual grip core")
	var rocket=game.weapon.weapons[27];rocket._apply_recoil_visual()
	check(absf(rocket.ROCKET_GRIP.z-(.20-.839)*.5)<.000001,"rocket primary grip is actual tube longitudinal midpoint")
	check(rocket.model.to_global(rocket.ROCKET_GRIP).distance_to(rocket.to_global(rocket.DEFAULT_HAND_CONTACT))<.00001,"rocket grip remains seated in tracked fist after center shift")
	check(rocket.ROCKET_INSERT==Vector3(0,.045,-.96) and rocket.ROCKET_OFFER==Vector3(0,.045,-1.15),"rocket model-relative load acceptance unchanged")
	var ump=game.weapon.weapons[6]
	check(not ump.uses_aggressor_model() and ump.model.find_child("AggressorBody",true,false)==null,"lightweight UMP procedural fallback retained")
	var builder=load("res://scripts/field_builder.gd").new();root.add_child(builder)
	for breaking in [false,true]:
		builder._play_build_sound(Vector3(1,2,3),breaking)
		var voice:AudioStreamPlayer3D=builder._audio_voices[(builder._audio_cursor+7)%8]
		check(voice.volume_db==2 and voice.unit_size==8 and voice.max_distance==48,"actual build voice has10dB louder gain and stronger distance reach")
		check(voice.global_position==Vector3(1,2,3),"placement/break sound retains event position")
		var wav:AudioStreamWAV=voice.stream;var peak:=0
		for i in range(0,wav.data.size(),2):peak=maxi(peak,absi(wav.data.decode_s16(i)))
		check(peak>1000 and peak<32767,"build transient non-silent and PCM not clipped")
	var limited:=false
	for i in AudioServer.get_bus_effect_count(0):
		var effect=AudioServer.get_bus_effect(0,i)
		if effect is AudioEffectHardLimiter:limited=effect.ceiling_db<=-1
	check(limited,"master peak ceiling protects coincident louder build/weapon effects")
	builder.free();game._quitting=true;game.weapon.shutdown();game._stop_audio_tree(game);game.queue_free();await create_timer(.2).timeout
	ProjectSettings.set_setting("ashfall/lightweight_models",null)
	print("MODEL_ADJUSTMENTS_076 checks=",checks," failures=",failures," xr_off=true headset_verified=false");quit(failures)
