extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func visible_count(marks)->int:
	var count:=0
	for mark in marks.marks:
		if mark.visible:count+=1
	return count
func run()->void:
	var wall:=StaticBody3D.new();wall.collision_layer=1;root.add_child(wall);wall.position=Vector3(0,0,-5)
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(10,10,.2);collider.shape=box;wall.add_child(collider)
	var marks=load("res://scripts/impact_marks.gd").new();root.add_child(marks);marks.set_process(false);await physics_frame;await physics_frame
	var point:=Vector3(0,0,-4.9)
	for i in 40:check(marks.add_hit(point+Vector3(float(i%2)*.00001,0,0),Vector3.BACK,wall,i%2==0),"near-identical verified hit accepted "+str(i))
	check(visible_count(marks)==40 and marks.sequence==40,"all forty overlapping rifle/pellet impacts have independent rendered meshes")
	var no_depth_writes:=true
	for mark in marks.marks:
		no_depth_writes=no_depth_writes and mark.material_override.depth_draw_mode==BaseMaterial3D.DEPTH_DRAW_DISABLED and not mark.material_override.no_depth_test
	check(no_depth_writes,"overlapping transparent patches read world depth without writing competing depth")
	check(marks.CAPACITY>=180,"global pool can show a full sustained M60 pass plus other impacts")
	for i in marks.CAPACITY+5:marks.add_hit(point,Vector3.BACK,wall,false)
	check(marks.marks.size()==marks.CAPACITY and visible_count(marks)==marks.CAPACITY,"only global oldest-first capacity bounds dense impacts")
	marks._process(marks.LIFETIME+1);check(visible_count(marks)==0,"global lifetime expires every mark")
	marks.free();wall.free();await create_timer(.1).timeout;print("DENSE_IMPACTS_061 checks=",checks," failures=",failures," actual_physics=true native_rendered=false");quit(failures)
