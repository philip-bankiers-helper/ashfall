extends SceneTree
var game: Node3D
var actor: CharacterBody3D
var city: Node3D
var checks:=0
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func walk_to(target:Vector3,label:String):
	var ticks:=0
	while Vector2(actor.global_position.x-target.x,actor.global_position.z-target.z).length()>.075 and ticks<1800:
		var direction:=target-actor.global_position;direction.y=0;direction=direction.normalized()
		actor.apply_locomotion_motion(direction,direction,false,false,1.0/90.0)
		await physics_frame
		ticks+=1
	check(Vector2(actor.global_position.x-target.x,actor.global_position.z-target.z).length()<.10,label+" horizontal arrival")
	check(absf(actor.global_position.y-target.y)<.12,label+" standing elevation actual="+str(actor.global_position.y)+" expected="+str(target.y))
	check(not actor.head_obstructed,label+" head clear")
func run():
	game=load("res://scripts/main.gd").new();root.add_child(game)
	game.front_menu.activate(4);game.front_menu.activate(13);game.front_menu.activate(0)
	for frame in 5:await physics_frame
	freeze(game);actor=game.player;city=game.active_sandbox_map;actor.xr_enabled=false;actor.input_enabled=true
	for id in [0,100]:
		var b:Dictionary=city.buildings.filter(func(v:Dictionary):return v.id==id)[0]
		actor.global_position=city.global_position+b.center+Vector3(b.stair_x-1.3,0,-5.05);actor.reset_motion()
		await physics_frame
		await walk_to(city.global_position+b.center+Vector3(b.stair_x-1.3,2.1,4),"%d ascending first flight"%id)
		await walk_to(city.global_position+b.center+Vector3(b.stair_x+1.3,2.1,4),"%d crossing mid landing"%id)
		await walk_to(city.global_position+b.center+Vector3(b.stair_x+1.3,4.2,-5.05),"%d ascending return flight"%id)
		await walk_to(city.global_position+b.center+Vector3(b.stair_x-1.3,4.2,-5.05),"%d crossing upper landing"%id)
		var bays:=int(float(b.width)/6)
		var u:float=-float(b.width)*.5+float(b.width)/bays*(int(bays/2)+.5)
		actor.global_position=city.global_position+b.center+Vector3(u,0,float(b.depth)*.5+3);actor.reset_motion()
		await walk_to(city.global_position+b.center+Vector3(u,0,float(b.depth)*.5-3),"%d open alternate entrance"%id)
	var bridge:Dictionary=city.routes.filter(func(v:Dictionary):return v.kind=="bridge")[0]
	actor.global_position=bridge.from;actor.reset_motion()
	await walk_to(bridge.to,"Full sky bridge")
	game.weapon_inventory.capacity=6
	check(game.field_consumables.collect(0),"Original heal provider collects a real city heal")
	check(game.field_consumables.stock.shaker==1,"Heal creates one accepted inventory item")
	var ammo:Node3D=city._city_ammo[0]
	var family:String=ammo.get_meta("family")
	var before:int=game.weapon.reserves[family]
	var quantity:int=ammo.get_meta("amount")
	check(game.ammo_pickups.collect_box(ammo)==quantity,"Real supply provider awards original quantity")
	check(game.weapon.reserves[family]==before+quantity,"Supply updates real reserve pool exactly once")
	check(game.ammo_pickups.collect_box(ammo)==0,"Supply cannot be collected twice")
	game.new_campaign()
	for frame in 5:await physics_frame
	check(actor.global_position.distance_to(city.spawn)<.1,"Restart returns to city safe spawn")
	check(game.mission_label.text=="CYBER BIRD","Restart retains selected city")
	var f:=FileAccess.open(OS.get_cmdline_user_args()[0]+"/TRAVERSAL-CYBER-BIRD.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"input":"Actual AshPlayer.apply_locomotion_motion; deterministic desktop directions","headset_tested":false,"xr_mode":"off"},"\t"));f.close()
	print("TRAVERSAL checks=",checks," failures=",failures.size())
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
