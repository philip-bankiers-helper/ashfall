extends RefCounted
## Deliberately small merge surface. Call after the lobby has restored its pose/environment.
static func select(game: Node, id: String) -> void:
	var current: Node3D = game.active_sandbox_map
	if id=="valley" and not is_instance_valid(current): return
	if is_instance_valid(current):
		var current_id: String = str(current.get("MAP_ID")) if current.get_script().get_script_constant_map().has("MAP_ID") else "range"
		if current_id == id:
			if id == "cyber_bird": game.player.get_world_3d().environment = current._environment
			return
		if current.has_method("leave"): current.leave()
		game.active_sandbox_map = null
		current.get_parent().remove_child(current)
		current.queue_free()
	if id == "cyber_bird":
		var city := preload("res://scripts/cyber_bird.gd").new()
		game.add_child(city)
		city.enter(game)
	elif id == "range":
		var practice := preload("res://scripts/sandbox_map_091.gd").new()
		game.add_child(practice)
		practice.enter(game)
	else:
		game.world.show()
		game.new_campaign()
