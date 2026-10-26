extends SceneTree
const Grid=preload("res://scripts/build_grid.gd")
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1;print("PASS " if value else "FAIL ",label)
	if not value:failures+=1
func run()->void:
	var side:float=preload("res://scripts/field_builder.gd").PANEL_SIDE
	for sign_value in [-1.0,1.0]:
		var origin:=Vector3(sign_value*side*.5,side*.5,sign_value*side*.5)
		for ray in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN,Vector3(1,1,1).normalized()]:
			var candidates:=Grid.intersections(origin,ray,Vector3.ZERO,side,1,6)
			check(not candidates.is_empty(),"finite plane for "+str(ray))
			for c in candidates:
				check(c.distance>=1-.0001 and c.distance<=6+.0001,"near/far bounds")
				check(absf(fposmod(c.at.origin[c.axis],side))<.0001 or absf(fposmod(c.at.origin[c.axis],side)-side)<.0001,"shared lattice plane negative/positive")
				check(c.kind==("floor" if c.axis==1 else "wall"),"geometric face kind")
	var mark=load("res://scripts/team_marks.gd").new();root.add_child(mark);mark.set_physics_process(false)
	var state:={"eligible":true,"pressed":false,"pose":Transform3D.IDENTITY,"hit":{"position":Vector3(2,1,-4),"normal":Vector3.UP},"choice":Vector2.ZERO}
	mark.consume_state(state,.01);state.pressed=true;mark.consume_state(state,.1);state.pressed=false;mark.consume_state(state,.01)
	check(mark.records.size()==1 and mark.records[0].color=="blue","tap creates blue surface mark")
	for selection in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
		state.pressed=true;state.choice=selection;mark.consume_state(state,.4)
		check(mark.wheel_open,"hold opens directional wheel")
		state.pressed=false;mark.consume_state(state,.01)
	check(mark.records.map(func(p):return p.color)==["blue","white","blue","yellow","purple"],"four cardinal directions select semantic colors")
	check(JSON.parse_string(JSON.stringify(mark.records)).size()==5,"payload serializes without objects")
	state.pressed=true;mark.consume_state(state,.4);state.eligible=false;mark.consume_state(state,.01);state.eligible=true;state.pressed=false;mark.consume_state(state,.01)
	check(mark.records.size()==5 and not mark.wheel_open,"menu/tracking cancellation does not mark")
	mark.queue_free()
	print("BUILD_MARKS_071 checks=",checks," failures=",failures," headset_tested=false")
	quit(failures)
