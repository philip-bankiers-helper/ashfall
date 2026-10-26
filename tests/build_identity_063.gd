extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame
	game.set_process(false)
	var identity:Dictionary=game.telemetry.snapshot().build_identity
	check(str(ProjectSettings.get_setting("application/config/version",""))=="0.6.3","actual project resource identifies062")
	check(identity.get("version","")=="0.6.3","actual Main telemetry identifies062 instead of historical047")
	check(identity.get("executable","")==OS.get_executable_path(),"telemetry retains actual launching executable path")
	game.field_menu.settings_page="root";game.field_menu.audio_page=false;game.field_menu._refresh()
	check(game.field_menu._spatial_title.text.contains("0.6.3") and game.field_menu._desktop_title.text.contains("0.6.3"),"actual VR and desktop menu labels agree with build")
	game._quitting=true;game.weapon.shutdown();game._stop_audio_tree(game);game.queue_free();await create_timer(.2).timeout
	print("BUILD_IDENTITY_063 checks=",checks," failures=",failures," actual_main=true physical_acceptance=false")
	quit(failures)
