extends SceneTree
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var ledge:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(4,1.2,4);collision.shape=shape;ledge.add_child(collision);root.add_child(ledge);ledge.position=Vector3(0,.6,-3)
	for outside in [0.001,.005,.04,.09,.16]:
		for margin in [0.0,.001,.006,-.006]:
			var p=load("res://scripts/player.gd").new();root.add_child(p);p.setup(false);p.xr_enabled=true;p.tracking_available=true;p.xr_camera.position.y=1.65;p.set_process(false);p.set_physics_process(false);p.position=Vector3(0,1.2+margin-1.65,-1+outside)
			await physics_frame
			var result:bool=p.try_start_release_mantle(Vector3(0,1.12,-1.01))
			var wanted:bool=outside<=.09 and margin>=0
			print("BOUNDARY outside=",outside," margin=",margin," result=",result," feet=",p.position," head=",p.xr_camera.global_position)
			check(result==wanted,"goggle-overlap lip release outside=%s margin=%s"%[outside,margin])
			if result:check(p.is_supported() and absf(p.position.y-1.2)<.02 and p.xr_camera.global_position.z< -1,"completion stands on real top")
			p.free();await physics_frame
	# At a diagonal corner, overlap may finish only when the goggles are at/above top.
	for margin in [.001,-.006]:
		var p=load("res://scripts/player.gd").new();root.add_child(p);p.setup(false);p.xr_enabled=true;p.tracking_available=true;p.xr_camera.position.y=1.65;p.set_process(false);p.set_physics_process(false);p.position=Vector3(2.03,1.2+margin-1.65,-.97);await physics_frame
		check(p.try_start_release_mantle(Vector3(1.99,1.12,-1.01))==(margin>0),"diagonal corner preserves above/below top boundary")
		p.free();await physics_frame
	var roof:=StaticBody3D.new();var roof_collision:=CollisionShape3D.new();var roof_shape:=BoxShape3D.new();roof_shape.size=Vector3(4,.1,3);roof_collision.shape=roof_shape;roof.add_child(roof_collision);root.add_child(roof);roof.position=Vector3(0,1.55,-1.5)
	var blocked=load("res://scripts/player.gd").new();root.add_child(blocked);blocked.setup(false);blocked.xr_enabled=true;blocked.tracking_available=true;blocked.xr_camera.position.y=1.65;blocked.set_process(false);blocked.set_physics_process(false);blocked.position=Vector3(0,1.201-1.65,-.96);await physics_frame
	var before:Vector3=blocked.position
	check(not blocked.try_start_release_mantle(Vector3(0,1.12,-1.01)),"low ceiling blocks edge-overlap completion before origin changes")
	check(blocked.position.distance_to(before)<.001,"blocked finish has no partial inward teleport")
	blocked.free();roof.free();ledge.free();await physics_frame
	print("MANTLE_BOUNDARY_052 checks=",checks," failures=",failures," screenshot_matched=false real_physics=true")
	quit(failures)
