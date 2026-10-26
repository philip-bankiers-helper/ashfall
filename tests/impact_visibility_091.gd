extends "res://tests/integration.gd"

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("AshfallVR-Standalone091-Playtest"):
		quit(2); return
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game._start_from_title()
	stop_audio(game)
	game.xr_enabled = false
	game.paused = false
	game.dead = false
	game.complete = false
	await physics_frame
	await physics_frame
	# The real blue facade and raised steel ribs used to be render-only and hid
	# marks attached to the concrete9cm behind them. Match the actual front faces.
	for sample in [[Vector3(-18,5.1,-36.9),-36.905],[Vector3(-18,5.2,-36.7),-36.775],[Vector3(-22.5,3.9,-36.9),-36.905]]:
		var target:Vector3=sample[0];var origin:=target+Vector3(0,0,8)
		var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,target-Vector3(0,0,1),1|8))
		check(not hit.is_empty() and hit.collider.is_in_group("rendered_ballistic_surface"),"real turbine facade is nearest rendered shot surface "+str(target))
		if hit.is_empty():continue
		check(absf(hit.position.z-float(sample[1]))<.0001,"turbine plate/rib hit matches visible mesh front")
		check(hit.collider.collision_layer==8 and not hit.collider.is_in_group("climbable"),"exact facade surface adds no locomotion/climb steps")
		game.impact_marks.clear_all();var before:int=game.impact_marks.accepted;game.weapon.shot.emit(origin,Vector3.FORWARD,1.)
		check(game.impact_marks.accepted==before+1 and game.impact_marks.marks[0].visible,"live weapon signal creates a facade mark")
		if game.impact_marks.accepted==before+1:
			var mark:MeshInstance3D=game.impact_marks.marks[0];var follows:=true
			for vertex in mark.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:follows=follows and absf((mark.global_transform*vertex).z-float(sample[1])-.003)<.0001
			check(follows,"all facade patch vertices remain3mm in front of actual visible steel")
	# Regression: original painted floor/roof stripes stood above collision and hid marks.
	for target in [Vector3(0,0,-35),Vector3(0,24.6,-91)]:
		var start:Vector3=target+Vector3.UP*10
		var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,target-Vector3.UP,1|8))
		check(not hit.is_empty() and hit.collider.is_in_group("painted_ballistic_surface"),"paint stripe is actual nearest ballistic surface "+str(target))
		if hit.is_empty():continue
		var body:StaticBody3D=hit.collider
		check(body.collision_layer==8 and not body.is_in_group("climbable"),"paint adds no foot/head/climb obstruction")
		var top:float=body.position.y+(body.get_child(0).shape as BoxShape3D).size.y/2
		check(absf(hit.position.y-top)<.0001,"ballistic hit matches exact visible paint box top")
		var support:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,target-Vector3.UP,1))
		check(not support.is_empty() and support.position.y<hit.position.y-.01,"locomotion keeps original continuous slab below paint")
		game.impact_marks.clear_all()
		game.weapon.shot.emit(start,Vector3.DOWN,1.)
		check(game.impact_marks.accepted>0 and game.impact_marks.marks[0].visible,"actual shot creates mark over raised paint")
		var mark:MeshInstance3D=game.impact_marks.marks[0]
		var attached:=true
		for vertex in mark.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			attached=attached and absf((mark.global_transform*vertex).y-top-.003)<.0001
		check(attached,"all nine patch vertices exactly3mm above rendered paint, no global floating offset")
	game.impact_marks.clear_all()
	var bodies: Array[StaticBody3D] = []
	collect_bodies(game.world, bodies)
	var tested := {}
	for body in bodies:
		var category := str(body.get_meta("surface", "unknown"))
		var ancestor: Node = body
		while ancestor != null:
			if ancestor.name.to_lower().contains("rock_07"): category = "rock"
			ancestor = ancestor.get_parent()
		if body.is_in_group("ballistic_proxy_ignore"): continue
		if tested.has(category): continue
		if category not in ["rock", "concrete", "metal", "gravel"]: continue
		for shape in body.get_children():
			if not shape is CollisionShape3D: continue
			var center: Vector3 = shape.global_transform * shape.shape.get_debug_mesh().get_aabb().get_center()
			for approach in [Vector3.UP, Vector3(1, .3, 1).normalized(), Vector3(-1, .4, 1).normalized()]:
				var origin: Vector3 = center + approach * 10
				var query := PhysicsRayQueryParameters3D.create(origin, center, 1|8)
				var excludes:Array[RID]=[]
				for proxy in get_nodes_in_group("ballistic_proxy_ignore"):
					if proxy is CollisionObject3D: excludes.append(proxy.get_rid())
				query.exclude=excludes
				var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty() or hit.collider != body: continue
				game.impact_marks.clear_all()
				var before: int = game.impact_marks.accepted
				# Emit the live weapon signal: exercises the real connection, Main raycast,
				# world collider filtering and persistent-mark spawn, not add_hit alone.
				game.weapon.shot.emit(origin, (center-origin).normalized(), 1.0)
				if game.impact_marks.accepted == before:
					continue
				var mark: MeshInstance3D = game.impact_marks.marks[0]
				check(mark.visible and mark.is_visible_in_tree(), category + " live shot creates visible world mark")
				check(mark.global_position.distance_to(hit.position + hit.normal*.003) < .0001, category + " hit location and depth offset match ray")
				check(mark.global_basis.z.normalized().dot(hit.normal) > .999, category + " quad faces surface normal")
				check(mark.scale.x >= .076, category + " readable rifle footprint >=7.6cm")
				check(mark.material_override.cull_mode == BaseMaterial3D.CULL_DISABLED and mark.material_override.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, category + " both eye-facing sides and shadow-independent contrast")
				game.impact_marks._process(40)
				check(mark.visible and mark.material_override.albedo_color.a == 1, category + " persists opaque beyond prior30second expiry")
				print("MAP_HIT category=", category, " collider=", body.get_path(), " origin=", origin, " hit=", hit.position, " normal=", hit.normal)
				if category == "rock":
					check(body.collision_layer == 8, "rock hit uses original visible trimesh layer8, not raised support hull")
					var verts:PackedVector3Array = mark.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					var attached:=true
					for vertex in verts:
						var world_vertex:Vector3 = mark.global_transform*vertex
						var probe:=PhysicsRayQueryParameters3D.create(world_vertex+hit.normal*2,world_vertex-hit.normal*2,8)
						var sampled:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(probe)
						attached=attached and not sampled.is_empty() and sampled.collider==body and sampled.position.distance_to(world_vertex)<.004
					check(attached, "all9 rock mark vertices lie within4mm of original visible surface")
				tested[category] = true
				break
			if tested.has(category): break
	check(tested.has("rock"), "actual irregular campaign rock hit accepted")
	check(tested.has("concrete"), "actual campaign concrete floor/wall hit accepted")
	check(tested.has("metal"), "actual campaign metal hit accepted")
	var proxies := get_nodes_in_group("ballistic_proxy_ignore")
	check(not proxies.is_empty(), "actual campaign exposes separate locomotion hull proxies")
	if not proxies.is_empty():
		check(not game.impact_marks.add_hit(Vector3.ZERO,Vector3.UP,proxies[0]), "support hull cannot receive floating bullet mark")
	# Oblique shots at the real campaign ground: both rifle and pellet handlers.
	for origin in [Vector3(3,3,-35), Vector3(-3,3,-35)]:
		game.impact_marks.clear_all()
		var before: int = game.impact_marks.accepted
		var dir: Vector3 = (Vector3(0,0,-35)-origin).normalized()
		game.weapon.shot.emit(origin, dir, 1.0)
		check(game.impact_marks.accepted > before and game.impact_marks.marks[0].visible, "angled actual floor shot leaves persistent mark origin="+str(origin))
		var edge_mark:MeshInstance3D=game.impact_marks.marks[0]
		var follows_visible:=true
		for vertex in edge_mark.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var world_vertex:Vector3=edge_mark.global_transform*vertex
			var surface_hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(world_vertex+Vector3.UP,world_vertex-Vector3.UP,1|8))
			follows_visible=follows_visible and not surface_hit.is_empty() and absf(world_vertex.y-surface_hit.position.y-.003)<.0001
		check(follows_visible,"oblique paint-edge patch follows real stripe and slab with3mm clearance")
	game.impact_marks.clear_all()
	var before_pellet: int = game.impact_marks.accepted
	var directions: Array[Vector3] = [Vector3.DOWN]
	game._on_pellet_shot(Vector3(0,3,-35),directions,1.0)
	check(game.impact_marks.accepted == before_pellet+1 and game.impact_marks.marks[0].scale.x >= .04, "actual pellet handler creates4cm minimum mark")
	game.impact_marks.clear_all()
	game.xr_enabled = true
	game.player.get_view_camera().global_position = Vector3(0,2,-35)
	var before_blocked: int = game.impact_marks.accepted
	game._on_shot(Vector3(0,-1,-35),Vector3.DOWN,1.0)
	var visible_floor:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,3,-35),Vector3(0,-2,-35),1|8))
	check(game.impact_marks.accepted == before_blocked+1 and absf(game.impact_marks.marks[0].global_position.y-visible_floor.position.y-.003)<.001, "actual XR muzzle obstruction creates persistent mark at visible floor rather than transient flash only")
	game.xr_enabled = false
	var texture: Image = game.impact_marks._build_texture().get_image()
	check(texture.get_pixel(32,32).r < .04 and texture.get_pixel(49,32).r > .4, "authored texture has black center and pale fractured rim")
	game.impact_marks._process(100)
	check(not game.impact_marks.marks[0].visible, "marks expire after90seconds")
	check(game.impact_marks.marks.size() == 512, "persistent mesh pool remains bounded512")
	var stair_supports: Array = get_nodes_in_group("stair_support")
	check(not stair_supports.is_empty() and not game.impact_marks.add_hit(stair_supports[0].global_position,Vector3.UP,stair_supports[0]), "invisible stair comfort surface cannot receive floating persistent marks")
	stop_audio(game)
	await create_timer(.1).timeout
	game.queue_free()
	await process_frame
	await create_timer(.1).timeout
	print("IMPACT089_RESULT passes=", passed, " failures=", failures.size(), " real_map=true actual_weapon_signal=true headset_tested=false rendered_visibility_unverified=true")
	quit(0 if failures.is_empty() else 1)

func collect_bodies(node: Node, bodies: Array[StaticBody3D]) -> void:
	if node is StaticBody3D: bodies.append(node)
	for child in node.get_children(): collect_bodies(child, bodies)
