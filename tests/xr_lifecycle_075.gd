extends SceneTree
class Fixture extends "res://scripts/main.gd":
	var exit_requests:Array=[]
	func _quit_game(code:int=0,reason:String="menu_quit"):
		exit_requests.append({"code":code,"reason":reason});_quitting=true
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run()->void:
	check(not root.use_xr,"test never enables XR runtime")
	var game:=Fixture.new();root.add_child(game);await process_frame;freeze(game);game.field_menu.set_open(false);game.player.vertical_combat_initializing=false;game.player.tracking_available=true;game.player.input_enabled=true;game.xr_enabled=true
	var optical:=SubViewport.new();game.add_child(optical);optical.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var mode_before:bool=root.use_xr
	for cycle in 5:
		game._on_xr_session_event("session_focussed");game._process(0)
		var clock:float=game.play_time;var health:float=game.health;var ammo:int=game.weapon.weapons[game.weapon.selected].ammo
		game._on_xr_session_event("session_visible");game._process(.1)
		check(game._xr_focus_suspended and game.paused and not game.player.input_enabled,"system overlay pauses input immediately")
		check(not game._xr_render_suspended and root.use_xr==mode_before,"visible overlay retains existing stereo rendering mode")
		check(game.play_time==clock and game.health==health and game.weapon.weapons[game.weapon.selected].ammo==ammo,"overlay does not advance gameplay or consume ammunition")
		check(game.exit_requests.is_empty(),"normal system-menu focus loss never quits")
		check(game.weapon.weapons[game.weapon.selected]._requires_trigger_release,"overlay requires trigger release before firing resumes")
		game._on_xr_session_event("session_focussed");game.player.tracking_available=true;game._process(0)
		check(not game.paused and game.player.input_enabled,"focus return restores eligible input")
		game._on_xr_session_event("session_stopping")
		check(game._xr_render_suspended and optical.render_target_update_mode==SubViewport.UPDATE_DISABLED,"stopped session suspends drawing including scope viewport")
		game._on_xr_session_event("session_stopping")
		game._on_xr_session_event("session_begun")
		check(not game._xr_render_suspended and optical.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"session restart restores saved rendering once")
		check(game._xr_focus_suspended and not game.player.input_enabled,"session begun alone cannot restore controller input")
	game._on_xr_session_event("session_focussed");game.field_menu.set_open(true);game._on_xr_session_event("session_visible");game._on_xr_session_event("session_focussed")
	check(not game.player.input_enabled,"focus return respects existing settings menu gate")
	game._on_xr_session_lost("instance_exiting")
	check(game._xr_terminal and game._xr_render_suspended and root.use_xr==mode_before,"terminal loss quiesces drawing without switching stereo to mono")
	check(game.exit_requests.size()==1 and game.exit_requests[0].code==3,"terminal runtime exit requests exactly one controlled shutdown")
	game._on_xr_session_lost("session_loss_pending");game._on_xr_session_event("session_focussed")
	check(game.exit_requests.size()==1 and game._xr_render_suspended,"late callbacks cannot restart terminal rendering or duplicate quit")
	# Restore the headless root for fixture teardown; this does not initialize XR.
	RenderingServer.viewport_set_active(root.get_viewport_rid(),true);game.weapon.shutdown();game._stop_audio_tree(game);game.queue_free();await create_timer(.2).timeout
	print("XR_LIFECYCLE_075 checks=",checks," failures=",failures," synthetic_events=true native_meta_overlay_verified=false");quit(failures)
