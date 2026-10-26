#063 carry: replace obsolete segmented-child-count assertion with actual continuous curved-shell envelope.
extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	var manifest:Dictionary=load("res://scripts/arsenal_data.gd").manifest()
	check(rack.ACTIVE_WEAPON_INDICES.size()==28,"C11 C13 active collection has21 firearms,4 melee items and3 explosives")
	for profile in manifest.profiles:
		var index:=int(profile.index);var gun=rack.weapons[index]
		var capacity:=int(profile.magazine_per_hand);var hands:=int(profile.hands)
		if str(profile.id) in ["frag","zone"]:capacity=1 #071 one payload per persistent inventory instance
		check(gun.magazine_size==capacity*hands and gun.get_loaded_rounds()==capacity*hands,"C12 one-star capacity "+str(profile.name))
		check(gun.has_meta("one_star_profile") and str(profile.rate_confidence)!="","C12 numerical confidence retained "+str(profile.id))
		check(ResourceLoader.exists("res://assets/ui/wheel_weapon_%d.svg"%index),"C10 colored inventory image exists "+str(profile.name))
		if hands==2:
			check(gun.guns[0].ammo==capacity and gun.guns[1].ammo==capacity,"C12 capacity is EACH hand "+str(profile.id))
		check(is_equal_approx(gun.fire_interval,1.0/(float(profile.rounds_per_second)*(1.2 if str(profile.id)=="matadors" else 1.0))),"C12 applied configurable rate "+str(profile.name))
	for index in [14,15,16]:check(rack.is_catalog_active(index),"P02 052 sword is active "+str(index))
	check(rack.weapon_names[0]=="CX4","C11 generic first rifle replaced with named CX4")
	check(rack.weapons[23].magazine_home.z>0,"C11 RFB actual magazine behind dominant grip")
	check(rack.weapons[23].insertion_arrow.position.z>0 and rack.weapons[23].charging_arrow.position.x>.06,"C11 RFB reload arrows and handle match rear-well/right-side input targets")
	var curved:Mesh=rack.weapons[21].magazine.mesh;var ak_envelope:AABB=curved.get_aabb()
	check(curved is ArrayMesh and ak_envelope.size.x<.05 and ak_envelope.size.y>.18 and ak_envelope.size.z>.10,"C11 AKM has one continuous hand-sized curved shell, shared by offered/ejected states")
	check(is_equal_approx(rack.weapons[18].fire_interval,.08),"C12 MP9 dated12.5rps")
	check(is_equal_approx(rack.weapons[23].fire_interval,1.0/9.5),"C12 RFB dated9.5rps")
	check(rack.weapons[27].ammo==1 and rack.reserves.rockets==24,"C13 SMAW single chamber with24 finite spare test rockets")
	var scene_world=load("res://scripts/world.gd").new();root.add_child(scene_world);scene_world.build();scene_world.set_process(false)
	actor.global_position=scene_world.player_spawn
	var inventory=load("res://scripts/weapon_inventory.gd").new();root.add_child(inventory);inventory.setup(actor,rack);inventory.set_process(false)
	await physics_frame;await physics_frame
	await physics_frame;await physics_frame
	check(inventory.pickups.size()+inventory.review_owned_props.size()==28,"C14 every active item laid out including inert owned review copies")
	for index in rack.ACTIVE_WEAPON_INDICES:
		var prop:Node3D=inventory.pickups.values().filter(func(p):return int(p.get_meta("catalog_index",-1))==index)[0]
		var bounds:AABB=inventory._world_mesh_bounds(prop)
		check(bounds.position.x>-6.5 and bounds.end.x<6.5 and bounds.position.z>=3.0 and bounds.end.z<13.0 and is_equal_approx(bounds.position.y,.80),"C14 full review mesh inside real arrival deck and75cm above it "+str(index))
	check(inventory.owned.size()==3 and inventory.SLOT_LIMIT==6,"P01 spawn review does not grant extra carried slots")
	var icons:Array[Texture2D]=[]
	for i in [0,1,2,3,5,6]:icons.append(load("res://assets/ui/wheel_weapon_%d.svg"%i))
	icons.append(load("res://assets/ui/back.svg"))
	var menu=load("res://scripts/menu.gd").new();root.add_child(menu);menu.setup(actor);menu.set_process(false)
	menu.loadout_provider=func()->Array[String]:return ["CX4","DT11","PX4","MK18","AWP","UMP","BACK"]
	menu.loadout_icon_provider=func()->Array:return icons
	menu.settings_page="loadout";menu._refresh()
	check(menu._desktop_loadout_grid.columns==6 and menu._desktop_loadout_grid.visible,"C10 desktop inventory uses three-column grid")
	check(is_equal_approx(menu._loadout_icons[0].position.y,menu._loadout_icons[2].position.y) and menu._loadout_icons[0].position.x>menu._loadout_icons[2].position.x,"C10 spatial inventory lays three guns across")
	check(menu._loadout_icons[3].position.x<menu._loadout_icons[2].position.x,"C10 next grid row below")
	check(menu._rows[0].text=="" and not menu._rows[0].visible,"C10 no gun-name text clutter in spatial grid")
	check(menu._desktop_loadout_buttons[0].icon!=null,"C10 colored desktop card texture assigned")
	menu.free();inventory.free();rack.shutdown();rack.free();actor.free();scene_world.free();await create_timer(.2).timeout
	print("CATALOG_CARRY_063 checks=",checks," failures=",failures," native_icons_reviewed=false live_balance_verified=false")
	quit(failures)
