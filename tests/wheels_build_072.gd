extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run()->void:
 var wheel=load("res://scripts/weapon_wheel.gd").new();root.add_child(wheel);wheel.show();wheel.set_owned_indices([0,1,2,3,4,5])
 for i in 8:
  check(absf(absf(wheel.slot_bounds(i).x-wheel.slot_bounds(i).y)-PI/4)<.0001,"equal inventory sector "+str(i))
  var point:Vector3=wheel.slot_position(i,.2);wheel.point(Transform3D(Basis.IDENTITY,point+Vector3.BACK))
  check(wheel.highlighted==i,"actual ray selects inventory sector "+str(i))
 check(wheel.SLOT_ACTIONS[4]=="backpack" and wheel.SLOT_ACTIONS[3]=="revive","bottom backpack and lower-right revive")
 check(wheel.ITEM_SLOTS.map(func(i):return wheel.SLOT_ACTIONS[i])==["weapon_0","weapon_1","weapon_2","weapon_3","weapon_4","weapon_5"],"six ordinary slots preserve sorted order")
 var marks=load("res://scripts/team_marks.gd").new();root.add_child(marks);marks.set_physics_process(false)
 check(marks.ACTIONS[0]=="treasure" and marks.TITLES[0]=="TREASURE","yellow X matches reference treasure meaning")
 var state:={"eligible":true,"pressed":false,"pose":Transform3D.IDENTITY,"hit":{"position":Vector3(0,2,0),"normal":Vector3.UP},"choice":Vector2.ZERO}
 marks.consume_state(state,.01)
 for i in 8:
  var angle:=PI/2-float(i)*PI/4;state.choice=Vector2(cos(angle),sin(angle));state.pressed=true;marks.consume_state(state,.4)
  check(marks.wheel_open and marks.selected_color==i,"actual hold selects semantic sector "+str(i))
  check(marks._header.text==marks.TITLES[i],"semantic header "+str(i))
  state.pressed=false;marks.consume_state(state,.01)
  check(marks.records[-1].action==marks.ACTIONS[i] and not marks.records[-1].networked,"local action payload "+str(i))
  var column=marks._visuals[-1].get_node("DottedSkyColumn")
  check(is_equal_approx(column.multimesh.mesh.radius*2,.6096*1.2) and column.multimesh.instance_count==76,"08620percent wider oval column, bottom2dots replaced by icon")
  for offset in [-.38,.38]:check(marks.sector_for_direction(Vector2(cos(angle+offset),sin(angle+offset)))==i,"sector edge interior "+str(i))
 state.pressed=true;marks.consume_state(state,.1);state.pressed=false;marks.consume_state(state,.01)
 check(marks.records[-1].action=="move" and marks.records[-1].color=="green","086tap retains most recently selected green move")
 check(is_equal_approx(marks.INNER_RADIUS/marks.OUTER_RADIUS,.3),"ping inner radius 30 percent")
 var grid=load("res://scripts/build_grid.gd");var builder=load("res://scripts/field_builder.gd").new();root.add_child(builder)
 check(builder.minimum_placement_distance==0,"no artificial near range")
 var near=grid.intersections(Vector3(.02,1,.5),Vector3.LEFT,Vector3.ZERO,builder.grid_spacing,0,6)
 check(not near.is_empty() and absf(near[0].distance-.02)<.001,"two-centimeter first lattice intersection")
 var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(5,5,5);shape.shape=box;body.add_child(shape);root.add_child(body);await physics_frame
 var exclusions:Array[RID]=[]
 var geometry:Dictionary=builder._geometry("wall");var entry={"kind":"wall","at":Transform3D.IDENTITY,"mesh":geometry.mesh,"shape":geometry.shape,"support":false,"ground":{"found":false}}
 check(builder._entry_clear(entry,exclusions,{"head":Vector3(10,10,10)})=="","panel accepts overlapping world object")
 check(builder._entry_clear(entry,exclusions,{"head":Vector3.ZERO})=="head_clearance","near placement still protects head")
 body.collision_layer=2;builder._actor=body;await physics_frame;await physics_frame
 check(builder._entry_clear(entry,exclusions,{"head":Vector3(10,10,10)})=="player_clearance","world overlap permission never permits intersecting player collider")
 body.queue_free();builder.queue_free();wheel.queue_free();marks.queue_free();await process_frame
 print("WHEELS_BUILD_072 checks=",checks," failures=",failures," headset_tested=false");quit(failures)
