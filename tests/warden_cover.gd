extends SceneTree
const Enemy=preload("res://scripts/enemy.gd")
var total:=0.0
var passed:=0
var failed:=0
func check(value:bool,label:String):
 if value: passed+=1
 else: failed+=1
 print("PASS " if value else "FAIL ",label)
func box(pos:Vector3,size:Vector3):
 var b=StaticBody3D.new()
 var c=CollisionShape3D.new()
 var s=BoxShape3D.new()
 s.size=size
 c.shape=s
 b.add_child(c)
 root.add_child(b)
 b.position=pos
 return b
func _initialize(): call_deferred("run")
func run():
 box(Vector3(0,-.5,0),Vector3(40,1,40))
 var target=Node3D.new()
 root.add_child(target)
 var boss=Enemy.new()
 boss.setup(target,3)
 root.add_child(boss)
 boss.position=Vector3(0,3,8)
 boss.set_physics_process(false)
 boss.hit_player.connect(func(amount):total+=amount)
 await physics_frame
 check(boss.health==350 and boss.healthmax==350,"health and variant")
 check(boss._rotors.size()==2,"twin rotor geometry")
 boss._change_state(boss.State.WINDUP)
 check(not boss._warden_area,"first attack burst")
 boss.locked_aim=Vector3(0,1.35,0)
 boss._fire(Vector3(0,1.35,0))
 check(is_equal_approx(total,16),"burst damage16")
 boss._change_state(boss.State.WINDUP)
 check(boss._warden_area,"second attack marked ground")
 check(boss._impact_point.distance_to(Vector3(0,.06,0))<.01,"fixed ground mark")
 total=0
 boss._resolve_warden_impact(Vector3(0,1.35,0))
 check(is_equal_approx(total,18),"stationary impact max18")
 total=0
 target.position=Vector3(3,0,0)
 boss._resolve_warden_impact(Vector3(3,1.35,0))
 check(total==0,"outside marked zone safe")
 target.position=Vector3(0,3,0)
 boss._resolve_warden_impact(Vector3(0,4.35,0))
 check(total==0,"airborne above mark safe")
 target.position=Vector3(1,0,0)
 var cover=box(Vector3(.5,1,0),Vector3(.15,2,3))
 await physics_frame
 boss._resolve_warden_impact(Vector3(1,1.35,0))
 check(total==0,"cover blocks blast")
 boss._change_state(boss.State.RECOVER)
 boss.take_damage(176)
 check(boss.boss_phase==2 and boss.health==174,"half-health phase transition")
 boss.take_damage(999)
 check(boss.state==boss.State.DEAD and not boss._impact_marker.visible,"death cancels warning")
 print("BOSS_TESTS ",passed," passed ",failed," failed")
 await shutdown_audio_and_scene()
 quit(0 if failed==0 else 1)
func shutdown_audio_and_scene():
 for voice in root.find_children("*", "AudioStreamPlayer3D", true, false):
  voice.stop()
  voice.stream=null
 for child in root.get_children(): child.queue_free()
 await process_frame
 Enemy._sound_bank.clear()
 # Fixed-fps headless simulation outruns the real audio mixer. Let queued
 # playback releases reach that thread before destroying AudioServer.
 OS.delay_msec(100)
 await process_frame

