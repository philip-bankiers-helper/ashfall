extends SceneTree
class Builder extends "res://scripts/field_builder.gd":
	func _connected_to_supported(_entries:Array)->bool:return true
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	var builder:=Builder.new();root.add_child(builder);builder.setup(null,null,null)
	check(is_equal_approx(builder.minimum_vertical_placement_distance,.4572),"18in vertical-only minimum")
	check(builder.minimum_placement_distance==0,"horizontal minimum remains unchanged")
	for sign_value in [-1.0,1.0]:
		var origin:=Vector3(sign_value*.5,.15,sign_value*.3)
		var direction:=Vector3(0,-.35,-sign_value).normalized()
		var raw:=builder.Grid.intersections(origin,direction,Vector3.ZERO,builder.grid_spacing,0,6)
		check(raw[0].kind=="wall" and raw[0].distance<.4572,"fixture really crosses close vertical plane first")
		var candidates:=builder._placement_candidates(origin,direction,6)
		check(candidates[0].kind=="floor" and candidates[0].distance<.4572,"close wall skipped while nearby horizontal floor remains eligible")
		var state:={"eligible":true,"tracking":true,"trigger":false,"origin":origin,"direction":direction,"head":Vector3(100,100,100)}
		builder._cancel();builder.tick_input(state);state.trigger=true;builder.tick_input(state)
		check(builder.preview_valid and builder.kinds[builder.piece_index]=="floor","actual trigger chooses horizontal extension past close wall")
		var end:Vector3=builder._lightning.points[-1]
		check(builder._lightning.points[0]==origin and (end-origin).normalized().is_equal_approx(direction),"beam extends straight from active hand")
		check(not end.is_equal_approx(builder.preview.global_position),"beam does not bend toward snapped tile centre")
		check(absf(end.y)<.00001,"beam stops on actual aimed floor plane")
		state.cancel=true;builder.tick_input(state);check(not builder._lightning.visible,"cancel clears ray immediately")
	for depth in [.1,.4571,.4572,.6]:
		var origin:=Vector3(.5,1,depth)
		var candidates:=builder._placement_candidates(origin,Vector3.FORWARD,6)
		check(not candidates.is_empty() and candidates[0].kind=="wall" and candidates[0].distance>=.4572-.00001,"vertical near cutoff respected depth "+str(depth))
		if depth>=.4572:check(is_equal_approx(candidates[0].distance,depth),"18in boundary accepted without moving lattice")
	var floors:=builder._placement_candidates(Vector3(.5,.1,.5),Vector3.DOWN,6)
	check(floors[0].kind=="floor" and is_equal_approx(floors[0].distance,.1),"10cm horizontal floor remains selectable")
	# A preferred wall cannot slip back inside the cutoff through hysteresis.
	var stale:=builder._placement_candidates(Vector3(.5,1,.48),Vector3.FORWARD,6)[0]
	builder._preferred_candidate=stale
	builder._update_placement({"origin":Vector3(.5,1,.44),"direction":Vector3.FORWARD,"head":Vector3(100,100,100)})
	check(builder.preview_valid and builder._preferred_candidate.distance>=.4572,"hysteresis cannot restore excluded close wall")
	var entry:=builder._plan_entry("wall",stale.at,{"found":false,"max_y":-INF,"min_y":INF,"rids":[]})
	check(builder._entry_clear(entry,[],{"origin":Vector3(.5,1,.2),"direction":Vector3.FORWARD,"head":Vector3(100,100,100)})=="vertical_minimum_distance","commit safety rechecks close vertical primary")
	var bolt=load("res://scripts/build_lightning_085.gd").new();root.add_child(bolt)
	for direction in [Vector3.FORWARD,Vector3.UP,Vector3(1,-.4,-1).normalized()]:
		var start:=Vector3(.2,1.2,.3);var end:Vector3=start+direction*4
		bolt.update_bolt(start,end,true)
		check(bolt.strands.size()==10,"half original twenty squiggles")
		check(is_equal_approx(bolt.HALF_WIDTH,.004),"all ribbons twice former width")
		var colors:={};var intervals:={}
		for color in bolt.strand_colors:colors[color.to_html()]=int(colors.get(color.to_html(),0))+1
		check(colors.get(Color("58ff44").to_html())==6 and colors.get(Color("050706").to_html())==2 and colors.get(Color.WHITE.to_html())==2,"six green plus two black and two white")
		for path in bolt.strands:
			check(path[0]==start and path[-1].is_equal_approx(end),"all strands share true ray endpoints")
			var previous:=-1.0
			for point in path:
				var forward:float=(point-start).dot(direction)
				check(point.is_finite() and forward>=previous-.00001,"irregular strand advances along straight centreline")
				previous=forward
		for spacing in bolt.strand_spacings:
			for interval in spacing:
				check(interval>0 and interval<=.4572+.00001,"random bend periods bounded by18in")
				intervals[roundi(interval*10000)]=true
		check(intervals.size()>15,"mixed random intervals instead of repeated sinusoid spacing")
		check(bolt.material_override.vertex_color_use_as_albedo and not bolt.material_override.no_depth_test,"coloured ribbons remain world-depth tested")
	bolt.update_bolt(Vector3.ZERO,Vector3.ZERO,false)
	check(not bolt.visible and bolt.strands.is_empty() and bolt.mesh.get_surface_count()==0,"disable removes all lightning geometry")
	bolt.free();builder.free();await process_frame
	print("BUILD_FEEDBACK_088 checks=",checks," failures=",failures," xr_off=true unchanged_world_lattice=true");quit(failures)
