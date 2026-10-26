extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	print("PASS " if value else "FAIL ", label)
	if not value: failures += 1
func run():
	var world=load("res://scripts/world.gd").new()
	root.add_child(world)
	world.build()
	var extension=load("res://scripts/campaign_extension.gd").new()
	extension.build(world)
	load("res://scripts/extension_detail.gd").new().build(world)
	var labels: Array[String]=[]
	for node in world.find_children("*", "Label3D", true, false): labels.append(node.text)
	labels.sort()
	var allowed=["ARRAY","DAM CROWN","EXIT","EXTRACTION","MANUAL RELEASE","RELAY","ROOF ACCESS","SPILLWAY","TURBINE","UPLINK"]
	check(labels.size()==12, "six mission map has exactly twelve concise labels including duplicate extraction signs")
	for text in labels: check(text in allowed, "necessary navigation/operation label: "+text)
	check(not "TRANSMIT / HOLD THE LINE" in labels,"requested slogan absent")
	world.start_extraction_arrival()
	check(world.rescue_craft.find_children("*", "Label3D", true, false).is_empty(),"rescue craft has no decorative lettering")
	world.reset_extraction_arrival()
	world.free()
	print("MAP_TEXT_RESULT failures=",failures," labels=",labels," headset_tested=false")
	quit(0 if failures==0 else 1)
