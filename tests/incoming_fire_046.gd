extends "res://tests/integration.gd"
class AttackSource extends Node3D:
	var muzzle_offset:=Vector3(3,0,-4)
	func get_weapon_muzzle_transform()->Transform3D:
		return Transform3D(global_basis,to_global(muzzle_offset))
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("reports/QA/test-appdata"):
		printerr("Isolated QA profile required");quit(2);return
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame;await physics_frame
	stop_audio(game)
	game.set_process(false);game.player.set_process(false);game.player.set_physics_process(false)
	for gun in game.weapon.weapons:gun.set_process(false);gun.set_physics_process(false)
	for enemy in game.enemies:enemy.set_physics_process(false)
	game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	game.combat_hud.set_process(false)
	var camera:Camera3D=game.player.get_view_camera()
	camera.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,1.65,0))
	var hud=game.combat_hud
	var cue=hud.incoming_fire
	var source:=AttackSource.new();game.add_child(source);source.global_position=Vector3(-3,1.65,-6)
	game.field_menu.vignette_enabled=false;game.field_menu._damage_time=0
	game.shield=100;game.health=100
	game._damage_player(2,source)
	check(game.shield==98,"actual damage hook applies shield damage")
	check(hud.hit_source.is_equal_approx(source.get_weapon_muzzle_transform().origin),"actual damage hook uses animated muzzle origin rather than enemy root")
	check(cue.attacks.size()==1 and cue.chains[0].visible,"actual damage hook displays chunky chain")
	check(game.field_menu._damage_time==0 and not game.field_menu.vignette_enabled,"vignette-off setting prevents damage screen pulse")
	check(cue.chains[0].mesh.get_faces().size()==48,"chain has four original thick open chevron chunks")
	var widths:Array=cue.chains[0].get_meta("chunk_widths")
	check(widths[0]>.2 and widths[0]>widths[1] and widths[1]>widths[2] and widths[2]>widths[3],"large near-player chunk tapers toward threat")
	for bearing in [0.0,PI/2,-PI/2,PI]:
		hud.clear_damage_indicator()
		source.muzzle_offset=Vector3.ZERO
		source.global_position=camera.global_position+Vector3(sin(bearing)*10,8,-cos(bearing)*10)
		game._damage_player(.1,source)
		check(absf(wrapf(float(cue.chains[0].get_meta("bearing"))-bearing,-PI,PI))<.001,"actual attack bearing front/right/left/rear %s"%bearing)
		var highest:=-INF
		for vertex in cue.chains[0].mesh.get_faces():
			var point:Vector3=cue.chains[0].transform*vertex
			highest=maxf(highest,point.y)
		check(highest<-.30 and cue.chains[0].position.z< -1,"all directional geometry remains large and low including rear hits")
		hud.refresh(.5)
		check(cue.materials[0].albedo_color.a>.49 and cue.materials[0].albedo_color.a<.51,"bounded half-duration fade")
		hud.refresh(.6)
		check(cue.attacks.is_empty() and not cue.chains[0].visible,"chain expires after one second")
	hud.clear_damage_indicator()
	source.global_position=Vector3(10,1.65,0)
	game._damage_player(.1,source)
	camera.global_basis=Basis(Vector3.UP,-PI/2)
	hud.refresh(0)
	check(absf(float(cue.chains[0].get_meta("bearing")))<.001,"chain bearing recomputes when head turns toward real attacker")
	camera.global_basis=Basis.IDENTITY
	hud.clear_damage_indicator()
	for i in range(7):
		source.global_position=camera.global_position+Vector3(sin(i*.8)*10,0,-cos(i*.8)*10)
		game._damage_player(.1,source)
	check(cue.attacks.size()==4 and cue.chains.size()==4,"multi-attacker chain count and mesh pool bounded at four")
	var last_source:Vector3=source.global_position
	game._damage_player(.1,source)
	check(cue.attacks.size()==4 and cue.attacks[-1].source==last_source,"same attacker refreshes existing cue without extra chain")
	game.paused=true;hud.refresh(0)
	check(cue.attacks.is_empty() and not hud.visible,"pause clears every chain without stale replay")
	game.paused=false;hud.refresh(0)
	check(cue.attacks.is_empty() and hud.visible,"resume does not replay old damage direction")
	hud.clear_damage_indicator();game._damage_player(.1)
	check(cue.attacks.is_empty(),"unknown damage origin never creates random direction")
	game._damage_player(0,source)
	check(cue.attacks.is_empty(),"zero damage never creates incoming-fire cue")
	game.field_menu.vignette_enabled=true;game._damage_player(.1,source)
	check(game.field_menu._damage_time>0,"explicit vignette-on setting retains optional damage pulse")
	game.dead=true;hud.refresh(0)
	check(cue.attacks.is_empty(),"death clears chains")
	# Match production quit cleanup: Dummy mixer drops playback references on
	# its real-time audio ticks, not two arbitrarily fast headless process frames.
	stop_audio(game);game._stop_audio_tree(game)
	game.queue_free();await process_frame;await process_frame
	await create_timer(.25,true).timeout
	print("INCOMING_FIRE_046 checks=",passed+failures.size()," failures=",failures.size()," synthetic=true headset_tested=false")
	quit(0 if failures.is_empty() else 1)
