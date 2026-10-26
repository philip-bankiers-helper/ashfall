extends SceneTree
func _initialize()->void:
	var failures:=0
	for name in ["closure_flick","dt11","revolver","precision_rifle","awp_scope","spr","player","menu","weapon","dual_pistols","arsenal_data","catalog_firearm","explosive_weapon","explosive_projectile","weapon_rack","weapon_inventory","field_builder","main"]:
		var script=load("res://scripts/"+name+".gd")
		if script==null or not script.can_instantiate():failures+=1;print("FAIL load ",name)
	print("PARSE_050 failures=",failures)
	quit(failures)
