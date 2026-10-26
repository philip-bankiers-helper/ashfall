extends SceneTree
var failures:=0
var checks:=0
func check(ok:bool,label:String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false)
	actor.set_process(false);actor.set_physics_process(false);actor.xr_enabled=true
	var menu=load("res://scripts/menu.gd").new();root.add_child(menu);menu.setup(actor);menu.set_process(false)
	var board:MeshInstance3D=menu._panel.get_child(0)
	for height in [1.1,1.65,2.0]:
		for yaw in [-1.5,0.0,2.0]:
			actor.xr_camera.global_transform=Transform3D(Basis.from_euler(Vector3(.6,yaw,.2)),Vector3(3,height,-2))
			menu.set_open(true)
			var center:=Vector3.ZERO
			for corner in [Vector3(-.65,-.74,0),Vector3(.65,-.74,0),Vector3(.65,.74,0),Vector3(-.65,.74,0)]:center+=board.to_global(corner)*.25
			var camera=actor.get_view_camera()
			var forward:Vector3=-camera.global_basis.z;forward.y=0;forward=forward.normalized()
			check(absf(center.y-height)<.001 and center.distance_to(camera.global_position+forward*1.6)<.001,"actual board rectangle centered at eyeheight %.2f yaw%.1f"%[height,yaw])
			check(menu._panel.global_basis.y.dot(Vector3.UP)>.999,"head pitch/roll do not tilt or elevate panel")
			var before:Transform3D=menu._panel.global_transform
			camera.global_position+=Vector3(.2,.1,.1);camera.rotation.x=-.5;menu._process(.02)
			check(menu._panel.global_transform.is_equal_approx(before),"open panel remains world-stable during subsequent head movement")
			menu.set_open(false)
	menu.free();actor.free();await process_frame
	print("MENU_EYE_LEVEL_RESULT checks=",checks," failures=",failures," native_render_verified=false")
	quit(failures)
