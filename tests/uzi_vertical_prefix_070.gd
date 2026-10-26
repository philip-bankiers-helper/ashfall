extends SceneTree
class Actor extends Node3D:
 var right_hand:XRController3D
 var left_hand:XRController3D
 var dominant_hand:="right"
 var view:Camera3D
 var _grabs:Dictionary={}
 func get_weapon_hand()->XRController3D:return null
 func get_support_hand()->XRController3D:return null
 func get_view_camera()->Camera3D:return view
const Prefix=preload("res://scripts/uzi_vertical_prefix.gd")
var failures:Array=[]
var checks:=0
var elapsed:=0.0
var rows:Array=[]
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func record(_origin:Vector3,d:Vector3,_power:float,side:int,sink:Array)->void:
 sink.append({"t":elapsed,"side":side,"pitch":asin(clampf(d.y,-1,1)),"yaw":atan2(d.x,-d.z)})
func pellets(_origin:Vector3,directions:Array,_power:float,sink:Array)->void:
 sink.append(directions.duplicate())
func make_pair(actor,baseline:bool,shotgun:bool):
 var pair=load("res://tests/fixtures/dual_pistols_069.gd" if baseline else "res://scripts/dual_pistols.gd").new()
 root.add_child(pair);pair.shotgun_mode=shotgun;pair.setup(actor,false);pair.set_process(false);pair.set_physics_process(false)
 load("res://scripts/arsenal_data.gd").apply(pair,12 if shotgun else 11)
 return pair
func run()->void:
 # Explicit rollback regression:071 endpoint experiments supersede this finite070 prefix.
 ProjectSettings.set_setting("ashfall/recoil_endpoint_experiments",false)
 var actor:=Actor.new();root.add_child(actor);actor.view=Camera3D.new();actor.add_child(actor.view)
 for hz in [72,90,120,240]:
  var base=make_pair(actor,true,false);var candidate=make_pair(actor,false,false)
  var bs:Array=[];var cs:Array=[]
  for gun in base.guns:gun.shot.connect(record.bind(gun.side,bs))
  for gun in candidate.guns:gun.shot.connect(record.bind(gun.side,cs))
  var boundary_pitch:=0.0
  for step in range(int(2.4*hz)+1):
   elapsed=float(step)/hz
   for pair in [base,candidate]:
    for gun in pair.guns:
     gun._process(0.0 if step==0 else 1.0/hz)
     if elapsed<1.6:gun.fire()
   for side in 2:
    var b=base.guns[side];var c=candidate.guns[side]
    check(abs(b.recoil_yaw-c.recoil_yaw)<1e-7,"yaw drift")
    check(abs(b.recoil_pitch-c._uzi_baseline_pitch)<1e-7,"hidden baseline drift")
    check(is_finite(c.recoil_pitch) and c.recoil_pitch>=0,"invalid pitch")
    if elapsed>.82 and elapsed<.86:boundary_pitch=rad_to_deg(c.recoil_pitch)
  check(bs.size()==40 and cs.size()==40,"full 20 per hand")
  for i in mini(bs.size(),cs.size()):
   check(bs[i].side==cs[i].side and abs(bs[i].t-cs[i].t)<1e-9,"cadence changed")
   check(abs(bs[i].yaw-cs[i].yaw)<1e-6,"emitted yaw changed")
   if cs[i].t<=Prefix.DURATION:
    check(abs(rad_to_deg(cs[i].pitch)-Prefix.pitch_degrees(cs[i].t))<.002,"prefire prefix mismatch")
  check(abs(cs[0].pitch)<1e-7 and abs(cs[1].pitch)<1e-7,"first shot not resting")
  rows.append({"hz":hz,"shots":cs.duplicate(true),"boundary_pitch_deg":boundary_pitch})
  # Actual partial release/repress; short pause stays in the existing hold.
  for c in candidate.guns:
   c.reset_weapon();c.fire();c._process(.10)
   var short_clock=c._uzi_prefix_time;c.fire()
   check(c._uzi_prefix_time==short_clock,"short hold reset")
   c._process(.20);var released=c.recoil_pitch
   c.fire()
   check(abs(c.recoil_pitch-released)<1e-7,"repress snapped")
   check(c._uzi_prefix_time==0,"repress clock")
   c._process(.81)
   check(c.recoil_pitch==0 and c._uzi_baseline_pitch==0 and not c._uzi_prefix_active,"idle reset")
   c.reset_weapon();c.fire();check(c.reload_flick(),"reload flick")
   for i in 100:c._process(.01)
   check(not c._uzi_prefix_active and c.recoil_pitch==0,"reload retains stale prefix")
   c.reset_weapon();check(c._uzi_prefix_time==0 and c._uzi_baseline_pitch==0,"explicit reset")
  base.shutdown();base.free();candidate.shutdown();candidate.free()
 # Probe exact boundary without a shot kick: position continuity, not derivative fit.
 var probe=make_pair(actor,false,false);var g=probe.guns[0]
 g.fire();g._uzi_prefix_time=Prefix.DURATION-.000001
 var before=g._uzi_corrected_pitch();g._recover_recoil(.000001)
 check(abs(g.recoil_pitch-before)<.000001,"boundary jump")
 probe.shutdown();probe.free()
 # Matador complete emitted pellet traces and state must remain baseline-identical.
 var mb=make_pair(actor,true,true);var mc=make_pair(actor,false,true)
 check(mb.guns[0].shotgun_mode and mc.guns[0].shotgun_mode,"matador slot")
 var bp:Array=[];var cp:Array=[]
 for gun in mb.guns:gun.pellet_shot.connect(pellets.bind(bp))
 for gun in mc.guns:gun.pellet_shot.connect(pellets.bind(cp))
 for i in 8:
  for side in 2:
   var b=mb.guns[side];var c=mc.guns[side]
   b._semi_armed=true;c._semi_armed=true;b._process(.33);c._process(.33);b.fire();c.fire()
   check(abs(b.recoil_pitch-c.recoil_pitch)<1e-9 and abs(b.recoil_yaw-c.recoil_yaw)<1e-9 and b.ammo==c.ammo,"matador changed")
 check(bp.size()==16 and cp.size()==16,"matador emission count")
 var maximum_pellet_delta:=0.0
 for i in mini(bp.size(),cp.size()):
  for j in bp[i].size():
   var delta:float=bp[i][j].distance_to(cp[i][j]);maximum_pellet_delta=maxf(maximum_pellet_delta,delta)
   check(delta<1e-6,"matador emitted pellet delta="+str(delta))
 print("MATADOR_FLOAT_COMPARISON maximum_unit_vector_delta=",maximum_pellet_delta," tolerance=0.000001")
 mb.shutdown();mb.free();mc.shutdown();mc.free()
 var out:=OS.get_environment("UZI070_OUTPUT")
 if not out.is_empty():
  var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":rows},"\t"));f.close()
 print("UZI070_TEST checks=",checks," failures=",failures.size())
 quit(0 if failures.is_empty() else 1)



