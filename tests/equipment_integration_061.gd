extends "res://tests/integration.gd"
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("reports/QA/test-appdata"):quit(2);return
	var game=load("res://scripts/main.gd").new();root.add_child(game)
	game.set_process(false);game.player.set_physics_process(false);game.weapon.set_process(false)
	game.field_consumables.set_process(false);game.practice_dummy.set_process(false)
	for gun in game.weapon.weapons:gun.set_process(false)
	for enemy in game.enemies:enemy.set_physics_process(false)
	stop_audio(game)
	game.paused=false;game.dead=false;game.complete=false;game.player.input_enabled=true;game.player.tracking_available=true
	game.field_menu.player_damage_multiplier=1.0
	await physics_frame;await physics_frame
	check(game.field_consumables.pickups.size()==12 and game.practice_dummy.is_in_group("practice_targets"),"Main creates actual supplies and practice target")
	check(game.weapon.reserves.rifle==2400 and game.weapon.reserves.pistol==1200 and game.weapon.reserves.shells==480 and game.weapon.reserves.rockets==24,"Main uses substantially larger finite testing reserves")
	check(game.weapon_inventory.SLOT_LIMIT==6,"six weapon slot limit preserved")
	game.encounter_active=false
	var target=game.practice_dummy
	game._on_shot(target.global_position+Vector3(0,1.12,1.0),Vector3.FORWARD,22)
	check(target.shield==78 and target.health==100,"production hitscan hits practice target")
	check(not game.encounter_active,"practice shot does not activate encounter")
	check(game.combat_hud.outgoing_number.text=="22" and game.combat_hud.outgoing_number.visible,"production hitscan reports actual damage on lower HUD")
	game.combat_hud.clear_damage_indicator();target.reset_target()
	var pellets:Array[Vector3]=[Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD]
	game._on_pellet_shot(target.global_position+Vector3(0,1.12,1),pellets,9)
	check(target.shield==73 and game.combat_hud.outgoing_number.text=="27","production shotgun aggregates pellets into one damage event")
	game._on_melee_contact(target,target.global_position+Vector3.UP,25,Vector3.FORWARD)
	check(target.health==75 and target.shield==73 and not game.encounter_active,"production melee bypasses target shield without encounter")
	game.combat_hud.clear_damage_indicator();target.reset_target()
	game.apply_explosive_damage(target.global_position+Vector3(0,.7,0),1,40,false)
	check(target.shield==60 and game.combat_hud.outgoing_number.text=="40" and not game.encounter_active,"production area damage includes practice targets and actual-loss HUD")
	game._damage_player(13);check(game.shield==87,"incoming damage keeps normal shield layering")
	check(game.combat_hud.incoming_number.visible and game.combat_hud.incoming_number.text=="-13","Main displays actual incoming loss")
	game.field_consumables.collect(9);game.field_consumables.collect(2);game.field_consumables.equip("banana");game.field_consumables.peel_count=4;game.health=50
	game.field_consumables.open_item();game.field_consumables.consume_at_mouth(.6,true,false)
	check(game.health==100 and game.field_consumables.stock.banana==0,"actual game banana heals and consumes finite stock")
	game._begin_chapter()
	check(game.field_consumables.stock.banana==0 and game.field_consumables.capacity==3 and game.practice_dummy.health==100,"checkpoint resets target and finite supply once")
	stop_audio(game)
	# Main's short tracer/impact timers finish while their authored nodes still exist.
	await create_timer(1.0).timeout
	game.queue_free();await process_frame;await process_frame
	print("EQUIPMENT_INTEGRATION_061_RESULT passes=",passed," failures=",failures.size()," synthetic=true headset_tested=false")
	quit(0 if failures.is_empty() else 1)

