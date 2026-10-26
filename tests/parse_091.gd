extends SceneTree
func _initialize()->void:
	var failures:=0
	for file in ["front_menu_091","lobby_map_091","lobby_gallery_091","sandbox_map_091","reticle_bounce_071","revive_paddles","revive_discharge_fx_091","mp9_laser_091","field_builder","main"]:
		var script:=load("res://scripts/"+file+".gd") as GDScript
		if script==null or not script.can_instantiate():failures+=1
	print("PARSE_091 checks=10 failures=",failures);quit(failures)
