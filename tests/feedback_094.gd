extends SceneTree
var game:Node3D
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	game=load("res://scripts/main.gd").new();root.add_child(game);game._start_from_title()
	for node in game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	game.set_process(false)
	await physics_frame;await physics_frame
	var rack:Node3D=game.weapon
	var fit=preload("res://scripts/playtest_fit_088.gd")
	for spec in [[11,Vector3(0,0,.0127)],[3,Vector3(0,-.0127,.0127)],[8,Vector3(0,0,.0381)],[21,Vector3(0,0,.0127)]]:
		var gun:Node3D=rack.weapons[spec[0]]
		if "guns" in gun:gun=gun.guns[0]
		var pose:Transform3D=gun.get_shot_transform()
		check((fit.hand_offset(gun)*gun.model.global_basis.get_scale().x).is_equal_approx(spec[1]),"physical hand delta "+str(spec[0]))
		check(gun.get_shot_transform().is_equal_approx(pose),"hand calibration preserves firing pose "+str(spec[0]))
	var size:=Vector2.ZERO
	for index in [3,9,17,18,23]:
		var sight:Node3D=rack.weapons[index].get_meta("reflex_sight")
		var scale:Vector3=sight.global_basis.get_scale()
		var window:Vector2=sight.WINDOW_SIZE*Vector2(scale.x,scale.y)
		if size==Vector2.ZERO:size=window
		check(window.is_equal_approx(size),"consistent physical reflex aperture "+str(index))
		check(sight.style=="holographic","shared detailed reflex style "+str(index))
		var ribs:=sight.find_children("EmbeddedReflexRib094*","MeshInstance3D",true,false)
		check(ribs.size()==10,"five detail ribs each side "+str(index))
		for rib in ribs:
			check(rib.position.z>=-.0181 and rib.position.z<=-.0019,"rib inside housing depth")
			check(absf(rib.position.x)-rib.mesh.get_aabb().size.x*.5<sight.WINDOW_SIZE.x*.5+.003,"rib intersects housing side")
	for index in [1,20,21,25]:
		check(not rack.weapons[index].has_meta("reflex_sight") or not rack.weapons[index].get_meta("reflex_sight").visible,"ring/iron optic allowance retained "+str(index))
	for index in rack.ACTIVE_WEAPON_INDICES:
		var gun:Node3D=rack.weapons[index]
		if index in [11,12]:gun=gun.guns[0]
		if gun.ammo_panel==null:continue
		var panel:Node3D=gun.ammo_panel;panel.update_display(29,69,false,game.player.get_view_camera())
		check(panel.rows[0].text=="29" and panel.rows[1].text=="69","live readout values "+str(index))
		check(panel.rows[0].font_size==38 and is_equal_approx(panel.rows[0].pixel_size,.00055),"same visible font "+str(index))
		check(panel.upper_face.material_override.albedo_color.is_equal_approx(Color("008bca")) and panel.face.material_override.albedo_color.is_equal_approx(Color("1b252b")),"reference blue/charcoal "+str(index))
		check(is_zero_approx(panel.rotation.length()),"counter points backward "+str(index))
		check(is_equal_approx(panel.dimensions.y,.044),"equal stacked row spacing "+str(index))
	var dt:Node3D=rack.weapons[1];dt.hinge.rotation.x=-.72;dt._update_reload_affordances()
	check(absf(dt.shell_offer.global_basis.y.normalized().dot(-dt.hinge.global_basis.z.normalized()))>.9999,"offered shells parallel to opened barrels")
	check(absf(dt.shell_offer.basis.y.y)>.6 and dt.shell_offer.basis.y.z<-.6,"shells tilt from old vertical pose along barrels")
	var spr:Node3D=rack.weapons[13]
	var housing:Node3D=spr.optic.get_node("LongSPRScopeHousing094")
	check(housing.get_child_count()>=30,"finished long SPR enclosure")
	check(housing.get_node_or_null("RecessedSPRObjective094")!=null,"recessed objective seated in enclosure")
	check(is_equal_approx(spr.optic.reticle_world_center().distance_to(spr.optic.lens.global_position),1.0),"SPR fixed1m optical marking preserved")
	var mag:Node3D=rack.weapons[7];var finish_count:=0
	for part in mag.cylinder.find_children("*","MeshInstance3D",true,false):
		if part.material_override!=null and part.material_override.albedo_texture!=null:
			finish_count+=1
			check(is_equal_approx(part.material_override.metallic,.22059628),"Magnum donor metal response")
			check(is_equal_approx(part.material_override.roughness,.43948251),"Magnum donor roughness")
	check(finish_count>0,"Magnum donor steel crop used on cylinder")
	for gun in rack.weapons[12].guns:
		var hidden:Array=gun.model.find_children("InsideMatadorBore094*","Label3D",true,false)
		check(hidden.size()==2,"two recessed Matador messages")
		for label in hidden:
			check(label.text=="Don't look\nunder here.","exact Matador secret words")
			check(not label.no_depth_test and not label.double_sided,"secret respects body occlusion and front face")
			var local:Vector3=gun.model.to_local(label.global_position)
			check(local.z>-.37 and local.z<-.3635,"message recessed inside barrel rim")
			check(is_equal_approx(label.visibility_range_end,.14),"secret limited to close inspection")
	var icons=preload("res://scripts/weapon_icons_094.gd")
	var hashes:Dictionary={}
	for index in rack.ACTIVE_WEAPON_INDICES:
		var icon:Texture2D=icons.icon(index)
		check(icon.resource_path.ends_with("catalog094/weapon_%d.png"%index),"real model icon routed "+str(index))
		check(icon.get_width()==512 and icon.get_height()==256,"high resolution icon "+str(index))
		var image:Image=icon.get_image();var bytes:=image.get_data()
		var digest:=bytes.hex_encode().sha256_text()
		check(not hashes.has(digest),"distinct weapon image "+str(index));hashes[digest]=true
		check(image.detect_alpha()!=Image.ALPHA_NONE,"transparent icon background "+str(index))
		var opaque:=0
		for y in range(0,256,8):
			for x in range(0,512,8):
				if image.get_pixel(x,y).a>.2:opaque+=1
		check(opaque>8,"render contains actual geometry "+str(index))
	await check_zone(Vector3(1000,20,1000),0.0)
	await check_zone(Vector3(1010,20,1000),.30)
	game.queue_free();await process_frame;await process_frame
	print("FEEDBACK_094 checks=",checks," failures=",failures," xr_runtime=off headset_tested=false")
	quit(0 if failures==0 else 1)
func check_zone(point:Vector3,slope:float)->void:
	var floor:=StaticBody3D.new();root.add_child(floor);floor.position=point;floor.rotation.z=slope;floor.collision_layer=1
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(4,.2,4);collision.shape=box;collision.position.y=-.1;floor.add_child(collision)
	await physics_frame
	var grenade:Node3D=load("res://scripts/explosive_projectile.gd").new();root.add_child(grenade)
	grenade.setup(game,{"kind":"zone","origin":point+Vector3(0,.8,0),"velocity":Vector3(0,-1,0)})
	var frames:=0
	while not grenade.stuck and frames<100:await physics_frame;frames+=1
	await process_frame;await physics_frame
	check(grenade.stuck and grenade.freeze,"thrown zone actually rests slope "+str(slope))
	check(grenade.collision_layer==0 and grenade.collision_mask==0,"resting zone no blocking collider")
	if grenade.has_meta("zone_support_normal094"):
		var normal:Vector3=grenade.get_meta("zone_support_normal094");var support:Vector3=grenade.get_meta("zone_support_point094");var minimum:=INF
		for part in grenade.find_children("*","MeshInstance3D",true,false):
			if part==grenade.zone_visual or not part.is_visible_in_tree():continue
			for corner in 8:minimum=minf(minimum,(part.to_global(part.get_aabb().get_endpoint(corner))-support).dot(normal))
		check(absf(minimum-.004)<.0002,"actual art clears supporting plane4mm "+str(slope))
		check(grenade.global_basis.y.dot(floor.global_basis.y)>.999,"grenade rests upright on support slope")
	else:check(false,"zone support was captured")
	var shapes:Array=grenade.find_children("*","CollisionShape3D",true,false)
	check(shapes.size()==1 and is_equal_approx(shapes[0].shape.radius,.035),"flight collider unchanged")
	check(grenade._warning_duration==float(grenade.tuning.get("zone_activation_delay",2.7)),"zone fuse unchanged")
	grenade.free();floor.free()
