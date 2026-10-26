extends SceneTree
class Game extends Node:
 var paused:=false
 var dead:=false
 var complete:=false
var passes:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passes+=1;print("PASS ",label)
 else:failures+=1;printerr("FAIL ",label)
func run():
 var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
 var trackers:Array=[]
 for hand in [actor.left_hand,actor.right_hand]:
  var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="paired_reticle_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip"
  t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
  t.set_input("grip",0.);t.set_input("trigger",0.);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false);trackers.append(t)
 await process_frame;actor.update_hand_input_rearm(.2);actor.xr_enabled=true
 var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
 var game:=Game.new();root.add_child(game)
 var cross=load("res://scripts/aim_reticle.gd").new();root.add_child(cross);cross.setup(actor,rack,game);cross.set_process(false)
 for side in ["right","left"]:
  actor.dominant_hand=side;rack.selected=11;rack.is_holstered=false;rack.is_selecting=false;rack._apply_selection()
  var pair=rack.weapons[11];pair.set_process(false);pair.set_physics_process(false);pair.refresh_hands();pair.stowed.assign([false,false])
  pair.guns[0].global_transform=Transform3D(Basis(Vector3.UP,.12),Vector3(.3,1.3,-.2));pair.guns[1].global_transform=Transform3D(Basis(Vector3.UP,-.12),Vector3(-.3,1.3,-.2))
  cross.update_reticle()
  check(not cross.visible and cross._paired_children.size()==2,side+" pair uses two independent world reticles")
  for i in range(2):
   var child=cross._paired_children[i];var pose:Transform3D=pair.guns[i].get_shot_transform()
   check(child.visible and child.ray_origin.distance_to(pose.origin)<.00001 and child.ray_direction.dot(-pose.basis.z)>.9999,side+" exact physical muzzle reticle%d"%i)
   check(rack.get_hand_grip_pose(pair.hand_for(i))==1.,side+" both gun hands curl rendered glove%d"%i)
  actor._grabs[pair.hand_for(1)]=Vector3.ZERO;cross.update_reticle()
  check(cross._paired_children[0].visible and not cross._paired_children[1].visible,side+" offhand wall anchor hides only its gun reticle")
  actor._grabs.clear();pair.stowed.assign([true,false]);cross.update_reticle()
  check(cross._paired_children[0].visible and cross._paired_children[0]._hand_override==pair.hand_for(1) and not cross._paired_children[1].visible,side+" stowed primary leaves only offhand reticle")
  check(rack.get_hand_grip_pose(pair.hand_for(0))==0. and rack.get_hand_grip_pose(pair.hand_for(1))==1.,side+" stow frees exact rendered hand")
  rack.is_holstered=true;cross.update_reticle();check(not cross._paired_children[0].visible and not cross._paired_children[1].visible,side+" whole bundle holster hides both crosshairs")
  pair.stowed.assign([false,false])
 for gun in rack.weapons:gun.shutdown()
 rack.queue_free();cross.queue_free();game.queue_free();actor.queue_free();await process_frame;await create_timer(.3).timeout
 for tracker in trackers:XRServer.remove_tracker(tracker)
 print("PAIRED_RETICLE_042_RESULT passes=",passes," failures=",failures);quit(0 if failures==0 else 1)
