extends RefCounted
class Builder extends "res://scripts/field_builder.gd":
	func _connected_to_supported(_entries:Array)->bool:return true
static func run(t:SceneTree)->void:
	var game:Node=t.game;var player:Node3D=game.player;var rack:Node3D=game.weapon
	player.xr_enabled=false;player.input_enabled=true;player.inventory_open=false;player.head_obstructed=false;player._grabs.clear();player.left_hand_reserved=false
	var hud:=preload("res://scripts/reference_hud_090.gd").new();game.add_child(hud);hud.setup(game);game.health=100;game.shield=65;hud.refresh()
	t.check(hud.health_text.text=="100" and hud.shield_text.text=="65","HUD shows current counts only")
	for label in [hud.health_text,hud.shield_text,hud.status]:t.check(label.vertical_alignment==VERTICAL_ALIGNMENT_CENTER and label.horizontal_alignment==(HORIZONTAL_ALIGNMENT_CENTER if label==hud.status else HORIZONTAL_ALIGNMENT_LEFT),"HUD text vertically centered, meter counts left aligned")
	t.check(not hud.status.visible and not hud.notice_background.visible and not hud.death_notice.visible,"idle notices and their rows disappear")
	for yaw in [0.0,.4,PI-.01,-PI+.01,PI*.5]:
		player.get_view_camera().global_basis=Basis(Vector3.UP,yaw);hud.refresh()
		var count:=0
		for mark in hud.compass_marks:
			if mark.visible:count+=1;t.check(mark.position.y<hud.health_text.position.y and not mark.text.is_valid_float(),"scrolling compass labels below health without degrees")
		t.check(count>=8,"compass stays populated across north wrap")
	hud.set_zone_notice("ZONE SHRINKING 51");hud.refresh();t.check(hud.status.visible and hud.notice_background.visible,"zone notice can appear when active")
	hud.set_zone_notice("");hud.notify_death("PLAYER DIED / UMP",.5);hud.tick_notices(.1);t.check(hud.death_notice.visible,"real death event can show feed")
	hud.tick_notices(.5);hud.refresh();t.check(not hud.status.visible and not hud.death_notice.visible,"notices expire to no idle row");hud.queue_free()
	player.get_view_camera().global_basis=Basis.IDENTITY
	for i in [0,21,25]:
		var gun:Node3D=rack.weapons[i];t.check(gun.has_meta("ring_sight") and gun.get_meta("ring_sight").visible,"original floating ring and dot restored "+str(i))
	for i in [1,2,6,7,8,10,19,20,24]:
		var gun:Node3D=rack.weapons[i];t.check(not gun.has_meta("reflex_sight") or not gun.get_meta("reflex_sight").visible or gun.get_meta("reflex_sight").style!="holographic","no unwanted holographic sight "+str(i))
	for i in [3,9,18,23]:t.check(rack.weapons[i].get_meta("reflex_sight").style=="holographic","explicit holo allowlist "+str(i))
	t.check(not rack.weapons[18].allows_world_reticle() and rack.weapons[18].get_children().any(func(child:Node):return child.get_script()==preload("res://scripts/mp9_laser_091.gd")),"MP9 red dot retained and physical laser replaces crosshair")
	var mp9:Node3D=rack.weapons[18];var mp9_rest:Transform3D=mp9.global_transform;mp9.show();mp9.global_position=Vector3(0,5,0)
	var laser:Node3D=mp9.get_children().filter(func(child:Node):return child.get_script()==preload("res://scripts/mp9_laser_091.gd"))[0]
	var laser_wall:=StaticBody3D.new();laser_wall.collision_layer=1;var wall_shape:=CollisionShape3D.new();wall_shape.shape=BoxShape3D.new();wall_shape.shape.size=Vector3(4,4,.1);laser_wall.add_child(wall_shape);game.add_child(laser_wall);laser_wall.global_position=mp9.get_shot_transform().origin+Vector3.FORWARD*2;await t.physics_frame
	for shift in [0.0,.3]:
		mp9.global_position.x=shift;laser._process(0)
		t.check(laser.visual.visible and laser.mesh.get_surface_count()==1,"actual MP9 beam draws from current gun pose")
		var vertices:PackedVector3Array=laser.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var beam_start:Vector3=(vertices[0]+vertices[1])*.5;var beam_end:Vector3=(vertices[2]+vertices[5])*.5
		t.check(beam_start.distance_to(mp9.get_shot_transform().origin)<.001 and beam_end.distance_to(beam_start)<2.01,"laser follows strafing muzzle and clips to world surface")
	t.check(laser.process_priority<mp9.get_meta("reflex_sight").process_priority,"MP9 beam publishes current aim before optic redraw")
	laser_wall.queue_free();mp9.global_transform=mp9_rest;mp9.hide()
	var spr:Node3D=rack.weapons[13];t.check(spr.optic._material.shader.code.contains("virtual_hit") and spr.optic.RETICLE_DEPTH_METRES==1.0,"SPR reticle on a fixed virtual plane independent of target distance")
	var pads:Node3D=game.revive_paddles;pads.equip()
	for relative in [Vector3.ZERO,Vector3(50,-20,70),Vector3(-50,20,-70),Vector3.UP]:
		t.check(pads._faces_together(relative,Vector3.RIGHT,Vector3.LEFT),"paddle facing ignores X/Y/Z and separation")
		t.check(not pads._faces_together(relative,Vector3.RIGHT,Vector3.RIGHT),"parallel electrodes do not charge")
		pads._clear_charge();pads.step_contacts(.05,Vector3.ZERO,relative,true,Vector3.RIGHT,Vector3.LEFT);pads.step_contacts(.05,Vector3.ZERO,relative,true,Vector3.RIGHT,Vector3.LEFT)
		t.check(pads.charge>0,"actual stationary orientation-only charging at arbitrary positions")
	pads._process(0);var meter:Transform3D=pads._meter.global_transform
	for paddle in pads._paddles:paddle.global_position+=Vector3(3,1,-2)
	pads._process(0);t.check(pads._meter.global_transform.is_equal_approx(meter),"revive meter does not follow paddle locations")
	t.check(pads._fill.material_override.albedo_color.b>.7,"revive progress is blue")
	# Earlier charge-rate loops now intentionally create automatic completion arcs.
	# Advance those bounded effects before isolating the chest-contact discharge.
	for effect in game.get_children().filter(func(n:Node):return n.get_script()==preload("res://scripts/revive_discharge_fx_091.gd")):effect._process(.6)
	await t.process_frame
	var target:=preload("res://scripts/rescue_training_dummy.gd").new();game.add_child(target);target.position=Vector3(0,3,-4)
	var contacts:Array=target.revive_contacts();pads.charge=1;pads.charge_ready=true
	pads._paddles[0].global_position=contacts[0];pads._paddles[1].global_position=contacts[1]
	t.check(pads.step_contacts(.01,contacts[0],contacts[1],true,Vector3.RIGHT,Vector3.LEFT) and not target.downed,"charged paddles actually revive on chest contacts")
	var effects:Array=game.get_children().filter(func(n:Node):return n.get_script()==preload("res://scripts/revive_discharge_fx_091.gd"))
	t.check(effects.size()==1 and effects[0].mesh.get_surface_count()==1,"successful revive creates blue-white lightning geometry")
	if not effects.is_empty():effects[0]._process(.6)
	await t.process_frame
	t.check(game.get_children().filter(func(n:Node):return n.get_script()==preload("res://scripts/revive_discharge_fx_091.gd")).is_empty(),"revive lightning expires without accumulating effects")
	target.queue_free()
	pads.stow()
	var consum:Node3D=game.field_consumables
	consum.items.clear();consum.stock={"shaker":0,"soda":0,"banana":0}
	for kind in ["soda","shaker","banana"]:
		var id:String="check_"+kind;consum.items[id]={"kind":kind};consum.stock[kind]=1;consum.equip_instance(id)
		consum.phase="consume";consum.peel_count=4;consum._shake_distance=10;consum._shake_seconds=10;consum._reversals=10
		t.check(consum.toggle_selected() and consum.toggle_selected(),"double A stow / draw "+kind)
		t.check(consum.phase==("shake" if kind=="shaker" else "open") and consum.peel_count==0 and consum._shake_distance==0,"preparation resets "+kind)
		t.check(consum.stock[kind]==1 and consum.items.has(id),"redraw preserves actual consumable stock "+kind)
		if kind!="banana":
			consum._process(0);var expected:Transform3D=player.get_view_camera().global_transform.translated_local(Vector3(.20,-.18,-.38)+Vector3(-.0254,-.0381,0))
			t.check(consum.held_prop.global_transform.is_equal_approx(expected),"drink prop shifted left1in and down1.5in "+kind)
		consum.stow()
	consum.items={"a":{"kind":"soda"},"b":{"kind":"soda"}};consum.stock={"soda":2,"shaker":0,"banana":0}
	var service:=preload("res://scripts/item_catalog_service_088.gd").new();game.add_child(service);service.setup(game,true)
	var found:=false
	for card in service.cards():
		t.check(not(card.kind=="supply" and card.family=="rockets"),"no rocket ammo catalog card")
		if card.kind=="slot" and card.get("action","").begins_with("consumable:"):found=true;t.check(card.count==2 and not card.title.contains("2"),"consumable count beside image, absent from name")
	t.check(found,"two sodas occupy a real backpack stack")
	t.check(game.ammo_pickups.spawn_box("rockets",Vector3.ZERO)==null and rack.add_reserve("rockets",100)==0,"rocket supply cannot spawn or refill")
	service.queue_free();consum.items.clear();consum.stock={"soda":0,"shaker":0,"banana":0};consum.selected_kind=""
	# Four M60 contacts require four press edges; moving a held grip cannot start the next stroke.
	var m60:Node3D=rack.weapons[8];m60.reset_weapon();m60.begin_reload();var start:Vector3=m60.get_box_offer();m60.reload_sample(start,false,true);m60.reload_sample(start,true,true);m60.reload_sample(m60.get_box_seat(),true,true)
	t.check(m60.reload_state=="needs_feed","M60 first continuous box stroke seats box")
	for spec in [["needs_feed",Vector3.RIGHT*m60.feed_direction()*.09,"box_seated"],["box_seated",Vector3.DOWN*.08,"needs_charge"],["needs_charge",Vector3.BACK*.11,"ready"]]:
		start=m60.get_reload_grab_point();m60.reload_sample(start,true,true);m60.reload_sample(start+spec[1],true,true)
		t.check(m60.reload_state==spec[0],"M60 held grip cannot start next stroke "+str(spec[0]))
		m60.reload_sample(start,false,true);m60.reload_sample(start,true,true);m60.reload_sample(start+spec[1],true,true)
		t.check(m60.reload_state==spec[2],"M60 fresh grip advances distinct stroke "+str(spec[0]))
	# Exact launcher budget, surviving real drop / pickup, final shot removes the instance.
	var rocket:Node3D=rack.weapons[27];game.weapon_inventory.owned.assign([0,27]);rack.selected=27;rack.is_holstered=false;rack._apply_selection();rocket.reset_weapon();rocket.global_position=Vector3(0,3,0)
	for shot in 3:
		t.check(rocket.ammo==1 and rocket.rocket_reserve==2-shot,"launcher starts each actual shot with correct finite reserve")
		rocket.update_ammo_display();t.check(rocket.ammo_label.text=="1\n%d"%(2-shot) and rocket.ammo_panel.visible,"launcher counter chamber above reserve")
		rocket.launch_payload(Vector3.FORWARD*20);t.check(rocket.ammo==0,"actual rocket launch spends chamber")
		if shot<2:
			if shot==0:
				t.check(game.weapon_inventory.drop_weapon(27) and game.weapon_inventory.pickup_weapon(27),"partly spent launcher drops and re-picks")
				t.check(rocket.ammo==0 and rocket.rocket_reserve==2,"drop preserves empty chamber and remaining rocket budget")
			rocket.grab_magazine();rocket.insert_magazine()
	await t.process_frame
	t.check(not game.weapon_inventory.has_weapon(27),"third fired rocket despawns launcher inventory instance")
	var terrain:=StaticBody3D.new();terrain.collision_layer=1;terrain.add_to_group("construction_terrain");var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(20,10,20);terrain.add_child(shape);game.add_child(terrain);terrain.position=Vector3(0,45,0)
	var builder:=Builder.new();game.add_child(builder);builder.setup(null,null,null);builder.set_physics_process(false);await t.physics_frame
	var state:={"origin":Vector3(0,52,2),"direction":Vector3.FORWARD,"head":Vector3(1000,1000,1000)};var excluded:Array[RID]=[]
	for y in [45.5,46.0,47.0,48.0,48.4,48.7,49.5,50.0]:
		builder._planned.clear();var candidate:={"kind":"wall","axis":2,"at":Transform3D(Basis.IDENTITY,Vector3(0,y,0)),"base_y":y-builder.grid_spacing*.5,"distance":2.0};var accepted:bool=builder._evaluate_grid_candidate(candidate,state,excluded)
		t.check(not accepted if y<=48.4 else accepted,"wall burial respects highest exposed corner y="+str(y))
	var roof:=StaticBody3D.new();roof.collision_layer=1;var roof_shape:=CollisionShape3D.new();roof_shape.shape=BoxShape3D.new();roof_shape.shape.size=Vector3(10,.2,10);roof.add_child(roof_shape);game.add_child(roof);roof.position=Vector3(0,56,0);await t.physics_frame
	t.check(not builder._wall_fully_buried_091(Transform3D(Basis.IDENTITY,Vector3(0,52,0)),excluded),"overhead roof is not mistaken for buried terrain")
	var real_candidates:Array=builder.Grid.intersections(Vector3(0,50.5,.1),Vector3(0,-.8,-.5),Vector3.ZERO,builder.grid_spacing,0,6);var checked:=0
	for candidate in real_candidates:
		if candidate.kind=="wall" and candidate.at.origin.y+builder.wall_height*.5<50:
			builder._planned.clear();t.check(not builder._evaluate_grid_candidate(candidate,state,excluded) and builder.invalid_reason=="buried_wall","actual grid candidate below terrain rejects with real base_y");checked+=1
	t.check(checked>0,"deep burial exercised through real global-grid candidates")
	terrain.rotation.z=.2;await t.physics_frame;builder._planned.clear()
	t.check(builder._evaluate_grid_candidate({"kind":"wall","axis":2,"at":Transform3D(Basis.IDENTITY,Vector3(0,48.55,0)),"base_y":48.55-builder.grid_spacing*.5,"distance":2.0},state,excluded),"vertical panel with an exposed corner on a slope stays eligible")
	roof.queue_free()
	builder.queue_free();terrain.queue_free()
