extends SceneTree
const Enemy=preload("res://scripts/enemy.gd")
var player:Node3D
var failures:=0
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures+=1
func _initialize():call_deferred("run")
func create_boss(distance:float):
 var boss=Enemy.new()
 boss.position=Vector3(0,0,-distance)
 boss.setup(player,3)
 root.add_child(boss)
 return boss
func run():
 var floor=StaticBody3D.new()
 var collision=CollisionShape3D.new()
 var shape=BoxShape3D.new()
 shape.size=Vector3(200,1,400)
 collision.shape=shape
 floor.add_child(collision)
 floor.position.y=-.5
 root.add_child(floor)
 player=Node3D.new()
 root.add_child(player)
 var boss=create_boss(20)
 boss.set_physics_process(false)
 boss.take_damage(34)
 check(is_equal_approx(boss.health,341.5) and boss.last_damage_blocked,"closed armor takes8.5")
 boss._change_state(boss.State.WINDUP)
 boss.state_time=.9
 check(not boss._core_is_open(),"early windup armored")
 boss.state_time=1.06
 check(boss._core_is_open(),"late burst telegraph exposed")
 boss._change_state(boss.State.RECOVER)
 boss.take_damage(34)
 check(is_equal_approx(boss.health,307.5) and not boss.last_damage_blocked,"recovery takesfull34")
 boss._change_state(boss.State.PURSUE)
 check(not boss.core_exposed,"pursuit closes core")
 boss.queue_free()
 await physics_frame
 var regular=Enemy.new()
 regular.setup(player,0)
 root.add_child(regular)
 regular.set_physics_process(false)
 regular.take_damage(34)
 check(regular.health==51 and not regular.last_damage_blocked,"regular damage unchanged")
 regular.queue_free()
 await physics_frame
 await simulate(20.0,1)
 await simulate(80.0,1)
 await simulate(20.0,2)
 print("ARMOR_FAILURES=",failures)
 await shutdown_audio_and_scene()
 quit(0 if failures==0 else 1)
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
func simulate(distance:float,hit_every:int):
 var boss=create_boss(distance)
 var attacks=0
 var previous_state=boss.state
 var shots=0
 var ammo=24
 var until_shot=0.0
 var frames=0
 while is_instance_valid(boss) and boss.health>0 and frames<2700:
  await physics_frame
  frames+=1
  if boss.state==boss.State.RECOVER and previous_state!=boss.State.RECOVER: attacks+=1
  previous_state=boss.state
  until_shot-=1.0/90.0
  if until_shot<=0 and boss.health>0:
   shots+=1
   ammo-=1
   if shots%hit_every==0: boss.take_damage(34)
   until_shot=.115
   if ammo==0:
    ammo=24
    until_shot=2.0
 var killed=is_instance_valid(boss) and boss.health<=0
 print("BALANCE distance=",distance," hit_every=",hit_every," seconds=",frames/90.0," shots=",shots," attacks=",attacks," killed=",killed)
 check(killed and attacks>=1,"boss attacks before perfect-fire death at"+str(distance)+"m")
 if is_instance_valid(boss):boss.queue_free()
 await physics_frame
