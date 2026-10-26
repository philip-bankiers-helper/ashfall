extends SceneTree
## Inspect the actual production draw materials. Native raster acceptance is separate.
class Rack extends Node3D:
	var weapons:Array=[]
	var selected:=0
	var is_holstered:=false
	var is_selecting:=false
class Game extends Node:
	var paused:=false
	var dead:=false
	var complete:=false
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false)
	actor.set_process(false);actor.set_physics_process(false)
	var rack:=Rack.new();root.add_child(rack)
	var game:=Game.new();root.add_child(game)
	var reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(reticle)
	reticle.setup(actor,rack,game);reticle.set_process(false)
	check(reticle.get_child_count()==8,"all four outline and red arms exist")
	for index in reticle.get_child_count():
		var part:MeshInstance3D=reticle.get_child(index)
		var material:StandardMaterial3D=part.material_override
		var red:bool=index>=4
		check(material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"arm %d uses late transparent pass rather than opaque sorting"%index)
		check(material.no_depth_test and is_equal_approx(material.albedo_color.a,1.0),"arm %d stays solid and ignores scene depth"%index)
		check(material.render_priority==(120 if red else 119),"arm %d explicit outline-before-red ordering"%index)
		check(material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED and part.layers==1<<19,"arm %d remains unlit and excluded from scope scenes"%index)
		var half:Vector2=part.mesh.size*.5
		check(absf(part.position.x)>half.x or absf(part.position.y)>half.y,"arm %d leaves the exact center empty"%index)
	check(is_equal_approx(reticle.SIZE_MULTIPLIER,4.0),"accepted distance scale factor retained")
	reticle.queue_free();actor.queue_free();rack.queue_free();game.queue_free()
	await process_frame
	print("CROSSHAIR_054_ORDER checks=",checks," failures=",failures," actual_materials=true gpu_rendered=false headset_tested=false")
	quit(1 if failures else 0)
