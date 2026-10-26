extends SceneTree
class Reserve extends Node:
	var rounds:=10000
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":rounds}
	func consume_weapon_reserve(_slot:int,count:int)->int:
		var used:=mini(count,rounds);rounds-=used;return used
	func refund_weapon_reserve(_slot:int,count:int)->int:rounds+=count;return count
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	var actor:Node3D=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var reserve:=Reserve.new();root.add_child(reserve)
	for family in ["dual_pistols","dual_matadors"]:
		var pair:Node3D=load("res://scripts/"+family+".gd").new();root.add_child(pair);pair.setup(actor,false);pair.set_process(false);pair.set_physics_process(false)
		for gun in pair.guns:
			gun.ammo_provider=reserve
			for hz in [30,72,90,120]:
				var dt:float=1.0/float(hz)
				for mode in ["rise","pitch","down_up","empty_trigger"]:
					gun.spin_elapsed=gun.SPIN_SECONDS;gun._reset_flick();gun.ammo=0 if mode=="empty_trigger" else 3;gun.reload_state="needs_mag" if gun.ammo==0 else "ready"
					var total:int=gun.ammo+reserve.rounds;var t:=0.0
					for i in ceili(.12/dt):
						t+=dt;gun.flick_sample(Vector3(.005*sin(t*14),0,0),Vector3.FORWARD,dt,true,mode=="empty_trigger")
					for i in ceili(.20/dt):
						t+=dt;var u:=float(i+1)/ceili(.20/dt);var point:=Vector3.ZERO;var forward:=Vector3.FORWARD
						if mode=="pitch":forward=Basis(Vector3.RIGHT,u*.85)*Vector3.FORWARD
						elif mode=="down_up":point.y=-.035*sin(u*TAU)+u*.12
						else:point.y=u*.15
						gun.flick_sample(point,forward,dt,true,mode=="empty_trigger")
					check(gun.ammo==gun.magazine_size and gun.spin_elapsed==0,family+" reliable "+mode+" "+str(hz)+"Hz hand"+str(gun.side))
					check(gun.ammo+reserve.rounds==total,"flip conserves loaded plus reserve ammunition")
				for mode in ["down","sideways","small_jitter","invalid","firing"]:
					gun.spin_elapsed=gun.SPIN_SECONDS;gun._reset_flick();gun.ammo=3;gun.reload_state="ready"
					for i in ceili(.15/dt):gun.flick_sample(Vector3.ZERO,Vector3.FORWARD,dt,true,false)
					for i in ceili(.2/dt):
						var u:=float(i+1)/ceili(.2/dt)
						var point:=Vector3.DOWN*u*.15 if mode=="down" else (Vector3.RIGHT*u*.20 if mode=="sideways" else (Vector3.UP*.01*sin(u*TAU*3) if mode=="small_jitter" else Vector3.UP*u*.15))
						gun.flick_sample(point,Vector3.FORWARD,dt,mode!="invalid",mode=="firing")
					check(gun.ammo==3 and gun.spin_elapsed==gun.SPIN_SECONDS,family+" rejects "+mode+" "+str(hz)+"Hz")
		pair.queue_free()
	actor.queue_free();reserve.queue_free();await process_frame;await process_frame
	print("FLIP_093 checks=",checks," failures=",failures," frame_rates=30,72,90,120 synthetic=true xr_runtime=off");quit(failures)
