extends SceneTree
const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ",label)
	else: failed += 1; printerr("FAIL ",label)
func box(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var b := StaticBody3D.new()
	b.position=at
	var s := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=size; s.shape=shape; b.add_child(s); parent.add_child(b)
func run() -> void:
	# Both authored directions and short/tall campaign stair proportions.
	for config in [Vector3(4,.25,.7),Vector3(20,.2,.6),Vector3(43,.2,.5),Vector3(13,.2,.5),Vector3(80,.2,.4),Vector3(30,.2,.6)]:
		for reverse in [false,true]:
			var count:=int(config.x)
			var rise:float=config.y
			var tread:float=config.z
			var direction:=1.0 if reverse else -1.0
			var run_length:float=count*tread
			var height:float=count*rise
			var world:=World.new()
			root.add_child(world); world.mats["yellow"]=StandardMaterial3D.new()
			world._stairs(Vector3.ZERO,count,rise,tread,4,reverse)
			box(world,Vector3(8,.3,4),Vector3(0,-.15,-direction*(tread+2)))
			box(world,Vector3(8,.3,4),Vector3(0,height-.15,direction*(run_length+2)))
			await physics_frame
			var support:Node3D=get_nodes_in_group("stair_support")[0]
			check(support.get_child_count()==2 and support.get_child(0) is CollisionShape3D,"invisible collision only, no helper mesh %s/%s" %[config,reverse])
			var under_ray:=PhysicsRayQueryParameters3D.create(Vector3(0,height*.5-.5,direction*run_length*.5),Vector3(0,height*.5-1.5,direction*run_length*.5),1)
			check(world.get_world_3d().direct_space_state.intersect_ray(under_ray).is_empty(),"open space below thin ramp %s/%s" %[config,reverse])
			var under_player:=Player.new()
			root.add_child(under_player); under_player.setup(false); under_player.set_physics_process(false)
			under_player.position=Vector3(-.5,height*.5-.55,direction*run_length*.5)-under_player.get_view_camera().position
			under_player._sync_head_shape()
			await physics_frame
			check(under_player.move_and_collide(Vector3(1,0,0))==null,"real head sweep beneath visible open stairs %s/%s" %[config,reverse])
			under_player.free()
			var ray_error:=0.0
			for i in range(201):
				var travel:float=lerpf(-tread,run_length,float(i)/200)
				var q:=PhysicsRayQueryParameters3D.create(Vector3(0,height+2,direction*travel),Vector3(0,-1,direction*travel),1)
				var hit:=world.get_world_3d().direct_space_state.intersect_ray(q)
				var expected:=clampf((travel+tread)*rise/tread,0,height)
				if hit.is_empty(): ray_error=999; printerr("RAY_MISS i=",i," travel=",travel," config=",config," reverse=",reverse)
				else: ray_error=maxf(ray_error,absf(hit.position.y-expected))
			check(ray_error<.003,"201 actual support rays continuous profile error=%s %s/%s" %[ray_error,config,reverse])
			for ascending in [true,false]:
				var p:=Player.new()
				root.add_child(p); p.setup(false); p.set_physics_process(false)
				p.position=Vector3(0,0,-direction*(tread+.5)) if ascending else Vector3(0,height,direction*(run_length+.5))
				await physics_frame
				var movement:=Vector3(0,0,direction if ascending else -direction)
				var max_jump:=0.0
				var max_error:=0.0
				var prev:float=p.get_view_camera().global_position.y
				var ticks:=int((run_length+tread+1.4)/6.5*Engine.physics_ticks_per_second)+10
				for tick in range(ticks):
					p.apply_locomotion_motion(movement,movement,false,false,1.0/Engine.physics_ticks_per_second)
					await physics_frame
					var head:Vector3=p.get_view_camera().global_position
					max_jump=maxf(max_jump,absf(head.y-prev)); prev=head.y
					var along:float=p.position.z*direction
					var expected:=clampf((along+tread)*rise/tread,0,height)
					max_error=maxf(max_error,absf(p.position.y-expected))
				check(max_error<.025,"actual full locomotion support error=%s ascent=%s %s/%s" %[max_error,ascending,config,reverse])
				check(max_jump<.065,"actual camera no tread-sized jumps max=%s ascent=%s %s/%s" %[max_jump,ascending,config,reverse])
				check(absf(p.position.y-(height if ascending else 0))<.025,"landing transition exact ascent=%s %s/%s" %[ascending,config,reverse])
				p.free(); await physics_frame
			world.free(); await physics_frame
	print("STAIR_RAMP_038 passed=",passed," failed=",failed)
	quit(1 if failed else 0)







