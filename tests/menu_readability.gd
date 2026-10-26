extends SceneTree
const Player = preload("res://scripts/player.gd")
const Menu = preload("res://scripts/menu.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(Color(0.035, 0.045, 0.06))
	var player := Player.new()
	root.add_child(player)
	player.setup(false)
	player.set_physics_process(false)
	var menu := Menu.new()
	root.add_child(menu)
	menu.setup(player)
	menu.set_process(false)
	menu.set_open(true)
	menu._choose(5)
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../reports/menu-desktop-game.png")
	menu._desktop_layer.visible = false
	menu._panel.visible = true
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../reports/menu-spatial-game.png")
	print("MENU_READABILITY_CAPTURE xr=false synthetic_camera=true")
	quit()
