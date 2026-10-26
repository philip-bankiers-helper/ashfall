extends SceneTree
const Enemy=preload("res://scripts/enemy.gd")
const World=preload("res://scripts/world.gd")
class Target extends CharacterBody3D:
	var exposure_provider:Node
var checks:=0
var failures:=0
var target:Target
var enemy
var rows:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func solid(position:Vector3,size:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new();body.position=position
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;collision.shape=box;body.add_child(collision);root.add_child(body);return body
func reset()->void:
	enemy.detection_level=0;enemy.alert_memory=0;enemy._has_sight=false;enemy._has_last_known=false;enemy._has_sensed_aim=false;enemy._radio_cooldown=999;enemy._cue_time=0
	target.position=Vector3.ZERO;target.velocity=Vector3.ZERO
func acquisition(distance:float,difficulty:float,speed:float)->float:
	reset();enemy.position=Vector3(0,0,distance);enemy.set_difficulty(difficulty);enemy.set_guard_heading(Vector3.FORWARD)
	const DT:=.02
	for frame in range(2000):
		var elapsed:=float(frame)*DT
		var phase:=elapsed*speed/.35
		target.position.x=.35*sin(phase) if speed>0 else 0.0
		target.velocity=Vector3(speed*cos(phase),0,0)
		var aim:=target.position+Vector3.UP*1.35
		enemy._update_detection(aim,enemy.position.distance_to(target.position),DT)
		if enemy._has_sight:return float(frame+1)*DT
	return 40.0
func value(lighting:String,distance:float,difficulty:float,speed:float)->float:
	for row in rows:
		if row.light==lighting and row.distance==distance and row.difficulty==difficulty and row.speed==speed:return row.seconds
	return -1
func run()->void:
	target=Target.new();root.add_child(target)
	var world:=World.new();root.add_child(world);target.exposure_provider=world
	var sun:=DirectionalLight3D.new();sun.rotation.x=-PI/2;sun.light_energy=1.15;world.add_child(sun);world.sun_light=sun
	var lamp:=OmniLight3D.new();lamp.position=Vector3(0,2,.8);lamp.omni_range=6;lamp.light_energy=2;world.add_child(lamp);world.authored_lights.append(lamp);lamp.hide()
	var floor:=solid(Vector3(0,-.2,0),Vector3(100,.4,100))
	enemy=Enemy.new();enemy.setup(target,0);root.add_child(enemy);enemy.set_physics_process(false);enemy.set_process(false)
	await physics_frame
	check(is_equal_approx(world.get_light_exposure(Vector3(0,1.35,0)),.84),"actual direct sun exposure contract is .84")
	check(is_equal_approx(enemy._contrast_visibility(.84),.8688) and is_equal_approx(enemy._contrast_visibility(1.0),1.0),"fully lit response exactly preserved without global delay")
	check(enemy._contrast_visibility(.12)<.13,"ambient contrast reduced below .13 by common curve")
	var roof:StaticBody3D
	for lighting in ["sun","roof","roof_lamp"]:
		if lighting=="roof":roof=solid(Vector3(0,3,0),Vector3(6,.2,6));await physics_frame
		if lighting=="roof_lamp":lamp.show()
		var exposure:=world.get_light_exposure(Vector3(0,1.35,0))
		print("EXPOSURE ",lighting,"=",exposure)
		if lighting=="roof":check(is_equal_approx(exposure,.12),"actual roof removes sun but preserves ambient .12")
		if lighting=="roof_lamp":check(exposure>.4 and exposure<.84,"actual in-range lamp illuminates shaded target")
		for distance in [3.0,8.0,20.0,45.0]:
			for difficulty in [0.0,.5,1.0]:
				for speed in [0.0,2.0,4.5]:
					var seconds:=acquisition(distance,difficulty,speed)
					rows.append({"light":lighting,"distance":distance,"difficulty":difficulty,"speed":speed,"seconds":seconds,"exposure":exposure})
					check(seconds<40,"finite acquisition in real light/motion/distance matrix")
					if distance==3.0:check(seconds<=.42,"nearby clear silhouette retains <=420ms detection")
	for distance in [8.0,20.0,45.0]:
		for speed in [0.0,2.0,4.5]:
			check(value("roof",distance,1.0,speed)>value("sun",distance,0.0,speed),"hard roof concealment outlasts easy sunlight at matched motion/range")
			check(value("roof",distance,1.0,speed)<value("roof",distance,0.0,speed),"hard still acquires faster than easy in same shade")
			check(value("roof_lamp",distance,1.0,speed)<value("roof",distance,1.0,speed),"real nearby light defeats part of roof concealment")
	for lighting in ["sun","roof","roof_lamp"]:
		for difficulty in [0.0,.5,1.0]:
			check(value(lighting,20.0,difficulty,2.0)<value(lighting,20.0,difficulty,0.0),"actual lateral target movement remains more salient than stillness")
		check(value(lighting,45.0,1.0,0.0)>value(lighting,8.0,1.0,0.0),"distant silhouettes acquire slower than near ones")
	lamp.position=Vector3(0,2,20);check(is_equal_approx(world.get_light_exposure(Vector3(0,1.35,0)),.12),"lamp beyond actual range contributes no false visibility")
	lamp.position=Vector3(2,2,0);var lamp_cover:=solid(Vector3(1,1.8,0),Vector3(.1,2,1));await physics_frame
	check(is_equal_approx(world.get_light_exposure(Vector3(0,1.35,0)),.12),"actual opaque panel blocks local lamp contribution")
	var wall:=solid(Vector3(0,1.5,5),Vector3(20,3,.3));await physics_frame
	reset();enemy.position=Vector3(0,0,20);enemy.set_guard_heading(Vector3.FORWARD);enemy.set_difficulty(1.0)
	for frame in range(800):
		target.position.x=.35*sin(frame*.1);target.velocity=Vector3(4.5,0,0);enemy._update_detection(target.position+Vector3.UP*1.35,20,.02)
	check(not enemy._has_sight and enemy.detection_level==0 and not enemy._has_last_known,"unknown moving target behind opaque cover never acquires or leaks last location")
	check(is_equal_approx(enemy._pressure_scale(),2.35) and enemy.get_damage_scale()==3.0 and is_equal_approx(enemy._dodge_window(),.28),"hard pressure damage and fair dodge window unchanged")
	var file:=FileAccess.open("user://concealment-matrix.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "));file.close()
	print("MATRIX_ROWS ",rows.size()," MATRIX_JSON ",ProjectSettings.globalize_path("user://concealment-matrix.json"))
	enemy._voice.stop();enemy._impact_voice.stop();enemy.free();target.free();world.free();wall.free();lamp_cover.free();roof.free();floor.free();await process_frame;await create_timer(.15).timeout
	print("CONCEALMENT_047 checks=",checks," failures=",failures," native_gpu_tested=false headset_tested=false");quit(0 if failures==0 else 1)
