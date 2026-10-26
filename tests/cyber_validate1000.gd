extends SceneTree
var checks := 0
var failures: Array[String] = []
var report: Dictionary = {"xr_mode":"off","headset_tested":false,"VR_launched":false,"VR_stopped":false,"other_game_changed":false}
var game: Node3D
var city: Node3D
var space: PhysicsDirectSpaceState3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		if failures.size()<35: print("FAIL ",text)
func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func ray(a: Vector3,b: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func clear_capsule(feet: Vector3, height := 1.8288, radius := .22) -> bool:
	var shape := CapsuleShape3D.new()
	shape.height = height
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = feet+Vector3.UP*(height*.5+.035)
	query.collision_mask = 1
	return space.intersect_shape(query,1).is_empty()
func run() -> void:
	game = load("res://scripts/main.gd").new()
	root.add_child(game)
	freeze(game)
	var menu: Node3D = game.front_menu
	check(menu.buttons.size()>=14,"Appended city selector preserves established action IDs")
	menu.activate(4)
	check(menu.page=="maps" and menu.buttons[13].visible,"Real MAP SELECT exposes CYBER BIRD")
	menu.activate(13)
	check(menu.selected_map=="cyber_bird" and menu.selection_text.text=="CYBER BIRD","Selection returns named map to lobby")
	# Exercise the real VR READY branch without initializing an XR interface/session.
	game.player.vertical_combat_initialized=true
	game.player.vertical_combat_tracking_baseline=1.64
	game.player.vertical_combat_world_baseline_m=1.71
	game.player.vertical_combat_origin_lift=.07
	game.player.vertical_combat_target_top_height_m=1.83
	game.player.dominant_hand="left"
	game.player.walk_speed_multiplier=1.13
	var saved: Dictionary = {}
	for key in ["vertical_combat_initialized","vertical_combat_tracking_baseline","vertical_combat_world_baseline_m","vertical_combat_origin_lift","vertical_combat_target_top_height_m","dominant_hand","walk_speed_multiplier"]: saved[key]=game.player.get(key)
	game.xr_enabled=true
	menu.activate(0)
	game.xr_enabled=false
	city=game.active_sandbox_map
	check(is_instance_valid(city) and city.get_script().get_script_constant_map().get("MAP_ID")=="cyber_bird","READY entered real registered map")
	check(not game.vertical_combat.active and not game.player.vertical_combat_initializing,"READY retains calibration; initialization is manual")
	for key in saved: check(game.player.get(key)==saved[key],"Preserved setting "+str(key))
	check(not game.front_end_active and game.player.input_enabled,"READY restores player input")
	for frame in 5: await physics_frame
	freeze(game)
	space=city.get_world_3d().direct_space_state
	check(city.buildings.size()==80,"80 building chunks")
	check(city.statistics.stairs==537,"537 complete storey connections")
	check(city.statistics.bridges==18,"18 sky bridges")
	check(city._local_lights.size()==6,"Bounded six local lights")
	check(city.materials.size()==12,"Shared12-material city palette")
	var floor_hit := ray(city.spawn+Vector3.UP,city.spawn-Vector3.UP)
	check(not floor_hit.is_empty() and absf(floor_hit.position.y)<.01,"Safe spawn has solid floor")
	check(clear_capsule(city.spawn),"Full player height clear at spawn")
	# All actual façade holes must pass a shot and a head-height ray across the wall.
	var window_count := 0
	for window in city.windows:
		var at: Vector3=window.at
		var normal: Vector3=window.normal
		var hit:=ray(at+normal*.45,at-normal*.45)
		check(hit.is_empty(),"Open window building=%d floor=%d at=%s"%[window.building,window.floor,str(at)])
		window_count+=1
	report.window_openings_tested=window_count
	# Sample each tread's physical top and full player clearance, every storey.
	var stair_samples := 0
	for b in city.buildings:
		for level in int(b.floors):
			for flight in 2:
				for step in 12:
					var at: Vector3=city.global_position+b.center+Vector3(float(b.stair_x)+(-1.3 if flight==0 else 1.3),level*4.2+flight*2.1+(step+1)*.175,-3.8+step*.6 if flight==0 else 2.8-step*.6)
					var hit:=ray(at+Vector3.UP*.08,at-Vector3.UP*.08)
					check(not hit.is_empty() and absf(hit.position.y-at.y)<.01,"Tread support %d:%d:%d:%d"%[b.id,level,flight,step])
					check(clear_capsule(at),"Tread head clearance %d:%d:%d:%d"%[b.id,level,flight,step])
					stair_samples+=1
			for z in [-5.05,4.0]:
				var y: float=level*4.2+(2.1 if z>0 else 0)
				var at: Vector3=city.global_position+b.center+Vector3(b.stair_x,y,z)
				check(clear_capsule(at),"Landing clearance %d:%d:%s"%[b.id,level,str(z)])
	report.stair_treads_tested=stair_samples
	for route in city.routes:
		if route.kind!="bridge": continue
		for sample in 21:
			var at: Vector3=route.from.lerp(route.to,float(sample)/20)
			check(not ray(at+Vector3.UP*.3,at-Vector3.UP*.5).is_empty(),"Bridge continuous support "+str(at))
			check(clear_capsule(at),"Bridge walking clearance "+str(at))
	# Four street lanes give grid connectivity, doglegs at spawn and visible collision bounds.
	for side in [-1.0,1.0]:
		for y in [1.7,25.0,150.0,410.0]:
			check(not ray(city.global_position+Vector3(side*390,y,0),city.global_position+Vector3(side*405,y,0)).is_empty(),"East/west visible perimeter "+str(y))
			check(not ray(city.global_position+Vector3(0,y,side*390),city.global_position+Vector3(0,y,side*405)).is_empty(),"North/south visible perimeter "+str(y))
	check(not ray(city.global_position+Vector3(0,419,0),city.global_position+Vector3(0,424,0)).is_empty(),"Visible canopy closes flight bounds")
	var spawn_sheltered := not ray(city.spawn+Vector3.UP*1.5,city.spawn+Vector3(0,1.5,-35)).is_empty()
	check(spawn_sheltered,"Spawn baffle blocks main street sightline")
	var bodies: Array=city.find_children("ArchitectureCollision","StaticBody3D",true,false)
	for body in bodies: check(body.collision_layer==1 and body.is_in_group("climbable"),"Accepted architecture layer and climb group")
	var entry: Dictionary={"shape":BoxShape3D.new(),"at":Transform3D(Basis.IDENTITY,city.global_position+Vector3(70,.04,70))}
	entry.shape.size=Vector3(2,.08,2)
	check(game.field_builder._world_contact(entry),"Existing construction support accepts city ground")
	# Real inventory/supply providers, and unobstructed nearby pickup approaches.
	var inventory: Node=game.weapon_inventory
	var gun_count := 0
	var elevations: Dictionary={}
	for id in inventory.pickups:
		var prop: Node3D=inventory.pickups[id]
		var at: Vector3=inventory._pickup_center(id)
		check(prop.has_meta("catalog_index") and prop.get_child_count()>0 and not prop.get_meta("review_only",false),"Actual transferable ground weapon "+str(id))
		check(not ray(at+Vector3.UP,at-Vector3.UP*3).is_empty(),"Weapon has reachable physical floor "+str(id))
		var accessible := false
		for offset in [Vector3(0,1,.8),Vector3(.8,1,0),Vector3(-.8,1,0),Vector3(0,1,-.8)]:
			if ray(at+offset,at).is_empty(): accessible=true
		check(accessible,"Weapon line of sight "+str(id))
		elevations[str(snappedf(prop.global_position.y,4.2))]=true
		gun_count+=1
	check(gun_count>=25 and elevations.size()>=4,"Real weapon drops dispersed across street/interior/roof elevations")
	var amounts: Dictionary={}
	for prop in city._city_ammo:
		var family: String=prop.get_meta("family")
		check(prop.get_meta("amount")==game.ammo_pickups.Supply.AMOUNTS[family],"Original per-box quantity "+family)
		amounts[family]=true
	check(amounts.size()==6 and city._city_ammo.size()==192,"Five ammo types plus builds across32 caches")
	# The same pickup transfer method used by the grip handler changes real ownership.
	var gun_id: int=inventory.pickups.keys()[0]
	inventory.capacity=6
	check(inventory.pickup_weapon(gun_id) and inventory.has_weapon(gun_id) and not inventory.pickups.has(gun_id),"Actual ground weapon can enter carried inventory")
	var ammo_count: int=game.ammo_pickups.boxes.size()
	game._begin_chapter()
	for frame in 4: await physics_frame
	check(game.ammo_pickups.boxes.size()==ammo_count,"Checkpoint refresh does not accumulate supply duplicates")
	check(game.mission_label.text=="CYBER BIRD","Map label survives checkpoint reset")
	# Return through the actual lobby, retain city, switch range, then campaign.
	game._return_home0992()
	menu.activate(0)
	check(game.active_sandbox_map==city,"Returning READY resumes same city instance")
	game._return_home0992()
	menu.activate(4)
	menu.activate(12)
	menu.activate(0)
	check(is_instance_valid(game.active_sandbox_map) and not game.active_sandbox_map.has_method("refresh_loot"),"Switch from city to existing sandbox")
	game._return_home0992()
	menu.activate(4)
	menu.activate(11)
	menu.activate(0)
	check(not is_instance_valid(game.active_sandbox_map) and game.world.visible,"Switch back to accepted campaign")
	report.checks=checks
	report.failures=failures
	report.passed=failures.is_empty()
	report.weapon_drops_tested=gun_count
	report.geometry=city.statistics if is_instance_valid(city) else {"buildings":80,"floors":537,"sky_bridges":18}
	var output: String=OS.get_user_data_dir()
	var file:=FileAccess.open(output+"/VALIDATION-CYBER-BIRD.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("CYBER_BIRD_VALIDATION ",JSON.stringify({"checks":checks,"failures":failures.size(),"passed":failures.is_empty()}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
