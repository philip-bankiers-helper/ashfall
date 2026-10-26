extends SceneTree
const Grid=preload("res://scripts/build_grid.gd")
const Builder=preload("res://scripts/field_builder.gd")
class Actor extends Node3D:
 var tracking_available:=true
class Game extends Node:
 var paused:=false
 var targets:Array=[]
 func _construction_protected_targets()->Array:return targets
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run()->void:
 var side:float=Builder.PANEL_SIDE
 for sign_value in [-1.0,1.0]:
  var origin:=Vector3(sign_value*.02,1.2,sign_value*.02)
  for ray in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK,Vector3.UP,Vector3.DOWN]:
   var crossings=Grid.intersections(origin,ray,Vector3.ZERO,side,0,6)
   check(not crossings.is_empty(),"available cardinal intersections")
   var previous:float=-1
   for crossing in crossings:
    check(crossing.distance>=0 and crossing.distance<=6 and crossing.distance>=previous,"ordered forward intersections in six-meter range")
    previous=crossing.distance
    check(absf(crossing.at.origin[crossing.axis]/side-roundf(crossing.at.origin[crossing.axis]/side))<.0001,"positive and negative intersections share global planes")
 check(Grid.intersections(Vector3(.02,1,.5),Vector3.LEFT,Vector3.ZERO,side,0,.019).is_empty(),"maximum reach excludes next plane")
 var exact=Grid.intersections(Vector3(.02,1,.5),Vector3.LEFT,Vector3.ZERO,side,0,.02)
 check(exact.size()==1 and absf(exact[0].distance-.02)<.000001,"two-centimeter plane remains selectable at exact reach")
 var scene:=Node3D.new();root.add_child(scene);var actor:=Actor.new();scene.add_child(actor);var game:=Game.new();scene.add_child(game)
 var builder=Builder.new();scene.add_child(builder);builder.setup(actor,null,game);builder.set_physics_process(false)
 var ground:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(40,.2,40);collision.shape=shape;ground.add_child(collision);ground.position=Vector3(0,-.1,0);scene.add_child(ground);await physics_frame;await physics_frame
 var state:={"eligible":true,"tracking":true,"trigger":false,"cycle":false,"origin":Vector3(.5,1.2,.02),"direction":Vector3.FORWARD,"head":Vector3(20,20,20)}
 builder.tick_input(state);state.trigger=true;builder.tick_input(state)
 check(builder.preview_valid and builder.pieces.is_empty() and absf(builder._placement.origin.z)<.0001,"actual hold previews closest supported wall two centimeters away")
 var shown:Transform3D=builder._placement
 state.cycle=true;builder.tick_input(state)
 check(builder._placement==shown and builder.kinds[builder.piece_index]=="wall" and not builder.reserves_shape_button(),"legacy cycle cannot change geometry; B unreserved")
 state.trigger=false;builder.tick_input(state)
 check(builder.pieces.size()==1 and builder.pieces[0].global_transform==shown and builder.charges==998,"release commits preview once")
 builder.tick_input(state);check(builder.pieces.size()==1,"continued release cannot repeat")
 state.trigger=true;builder.tick_input(state)
 check(builder.preview_valid and absf(builder._placement.origin.z+side)<.0001,"occupied first grid face skipped for next eligible face")
 builder._cancel();builder.reset_builds();await physics_frame;await physics_frame
 builder.charges=0;state.trigger=false;builder.tick_input(state);state.trigger=true;builder.tick_input(state)
 check(not builder.preview_valid and builder.invalid_reason=="capacity","insufficient charges blocks complete plan")
 state.trigger=false;builder.tick_input(state);check(builder.pieces.is_empty(),"capacity failure does not spend or place")
 builder.reset_builds();builder.placement_range=.019;state.trigger=false;builder.tick_input(state);state.trigger=true;builder.tick_input(state)
 check(not builder.preview_valid and builder.invalid_reason=="reach","runtime respects maximum ray reach")
 builder.reset_builds();builder.placement_range=6;state.trigger=false;builder.tick_input(state);state.trigger=true;builder.tick_input(state)
 check(builder.preview_valid,"supported preview before world anchor disappears")
 ground.free();await physics_frame;await physics_frame
 builder._commit()
 check(builder.pieces.is_empty() and builder.charges==999 and builder.invalid_reason=="unsupported","commit rechecks lost support without partial spend")
 builder.reset_builds();builder._capture_floor_grid({"origin":Vector3(-200,70,90)})
 check(builder.grid_origin==Vector3.ZERO and builder._level_y==0 and builder._floor_grid_origin==Vector2.ZERO,"reset and player movement cannot reanchor map lattice")
 check(builder.kinds==["wall","floor"],"no selectable ramp or manual type")
 builder.reset_builds();scene.queue_free();await process_frame;OS.delay_msec(180);await process_frame;await create_timer(.2).timeout
 print("BUILD_AUDIT_073 checks=",checks," failures=",failures," physics=true headset_tested=false");quit(failures)
