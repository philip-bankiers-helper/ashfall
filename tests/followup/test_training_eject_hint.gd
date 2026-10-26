extends SceneTree
var failures:=0
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
	var player=load("res://scripts/player.gd").new();root.add_child(player);player.setup(false);player.set_process(false);player.set_physics_process(false)
	var training=load("res://scripts/training.gd").new();root.add_child(training);training.player=player
	player.dominant_hand="left";player.sprint_binding="left_stick_click"
	check(training.manual_eject_hint().contains("stick down") and not training.manual_eject_hint().contains("click"),"left click sprint never instructed as rifle eject")
	player.sprint_binding="left_grip"
	check(training.manual_eject_hint().contains("click"),"left grip sprint permits weapon stick click eject hint")
	player.dominant_hand="right";player.sprint_binding="left_stick_click"
	check(training.manual_eject_hint().contains("click"),"right dominant click eject hint remains valid")
	training.free();player.free();await process_frame
	print("TRAINING_EJECT_HINT checks=3 failures=",failures);quit(failures)