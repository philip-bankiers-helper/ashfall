extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var script=load("res://scripts/main.gd")
	if script==null:quit(1);return
	var game=Node3D.new();game.set_script(script);root.add_child(game)
	for i in 8:await process_frame
	if game.get("network_bridge")==null:push_error("Missing multiplayer bridge");quit(1);return
	print("BOOT1000_OK maps=",game.front_menu.Maps1000.IDS," net=",game.network_bridge.net.stage)
	game._quitting=true;game.set_process(false);game.queue_free()
	await process_frame;await process_frame
	quit(0)
