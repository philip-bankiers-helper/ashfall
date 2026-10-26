extends SceneTree
class Actor extends CharacterBody3D:
	var xr_enabled:=true
	var input_enabled:=true
	var climbing_right:=false
	var head_obstructed:=false
	var tracked:=true
	var right_hand:=XRController3D.new()
	var left_hand:=XRController3D.new()
	var dominant_hand:="right"
	var last_checked:XRController3D
	var camera:=Camera3D.new()
	func get_weapon_hand():return left_hand if dominant_hand=="left" else right_hand
	func weapon_hand_climbing():return climbing_right
	func is_hand_input_ready(hand):
		last_checked=hand
		return tracked
	func get_view_camera():return camera
class Rack extends Node3D:
	var is_holstered:=false
	var is_selecting:=false
	var weapons:Array=[]
	var selected:=0
class Game extends Node:
	var paused:=false
	var dead:=false
	var complete:=false
var failures:=0
var checks:=0
func check(ok:bool,text:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",text)
func _initialize():call_deferred("run")
func run():
	var scene:=Node3D.new();root.add_child(scene)
	var actor:=Actor.new();scene.add_child(actor)
	actor.add_child(actor.camera);actor.add_child(actor.right_hand);actor.add_child(actor.left_hand)
	actor.collision_layer=2
	var rack:=Rack.new();scene.add_child(rack)
	var game:=Game.new();scene.add_child(game)
	var weapon=load("res://scripts/weapon.gd").new();rack.add_child(weapon)
	weapon.set_process(false);weapon.set_physics_process(false)
	rack.weapons=[weapon]
	var raw:=Transform3D(Basis(Vector3.UP,0.35)*Basis(Vector3.RIGHT,PI/2),Vector3(0,1.5,0))
	weapon.global_transform=weapon.corrected_grip_transform(raw)
	var origin:Vector3=weapon.to_global(Vector3(0,0.045,-0.69))
	var direction:Vector3=-weapon.global_basis.z
	actor.camera.global_position=origin-direction*0.3
	var target:=StaticBody3D.new();target.collision_layer=4
	var collider:=CollisionShape3D.new();collider.shape=SphereShape3D.new();collider.shape.radius=0.5
	target.add_child(collider);scene.add_child(target);target.global_position=origin+direction*10
	var reticle=load("res://scripts/aim_reticle.gd").new();scene.add_child(reticle)
	reticle.setup(actor,rack,game);reticle.set_process(false)
	await physics_frame;await physics_frame
	reticle.update_reticle()
	check(reticle.visible,"valid VR weapon shows crosshair")
	check(reticle.last_hit.get("collider")==target,"corrected weapon ray hits known layer-four target")
	check(reticle.ray_origin.is_equal_approx(origin) and reticle.ray_direction.is_equal_approx(direction),"crosshair uses actual muzzle and corrected barrel direction")
	check(absf(origin.distance_to(reticle.hit_position)-9.5)<0.01,"target surface hit is accurate")
	check(reticle.global_position.distance_to(reticle.hit_position)<0.016,"surface backoff limited to 1.5 cm")
	actor.dominant_hand="left";reticle.update_reticle()
	check(actor.last_checked==actor.left_hand,"left dominant reticle checks actual firing hand")
	actor.camera.rotation.y=1.2;reticle.update_reticle()
	check(reticle.last_hit.get("collider")==target,"turning head does not steer aim")
	for state in ["is_holstered","is_selecting"]:
		rack.set(state,true);reticle.update_reticle();check(not reticle.visible,state+" hides reticle");rack.set(state,false)
	game.paused=true;reticle.update_reticle();check(not reticle.visible,"pause hides reticle");game.paused=false
	actor.tracked=false;reticle.update_reticle();check(not reticle.visible,"tracking loss hides reticle");actor.tracked=true
	weapon.reload_state="needs_mag";reticle.update_reticle();check(not reticle.visible,"reload hides reticle");weapon.reload_state="ready"
	actor.xr_enabled=false;reticle.update_reticle();check(not reticle.visible,"desktop retains existing crosshair only");actor.xr_enabled=true
	weapon.magazine_size=2;target.position=Vector3(50,50,50)
	await physics_frame;await physics_frame
	reticle.update_reticle()
	check(reticle.visible and absf(reticle.ray_origin.distance_to(reticle.hit_position)-40)<0.01,"shotgun center aim bounded to forty metres")
	check(reticle.scale.x<=2.40 and reticle.get_child_count()==8,"fourfold bounded size and fixed eight-arm hollow pool")
	check(reticle.scale.x>0.35,"larger apparent size than previous crosshair at forty metres")
	for part in reticle.white_parts:
		check(part.material_override.albedo_color.r>0.95 and part.material_override.albedo_color.g<0.1,"foreground cross is high-contrast red")
		check(absf((part.global_position-reticle.global_position).dot(reticle.global_basis.z.normalized())-0.01)<0.00001,"red arm depth separation is one world centimetre")
		check(part.material_override.no_depth_test,"foreground cross remains whole on the ray-selected contact surface")
	var wall:=StaticBody3D.new();wall.collision_layer=1
	var wall_shape:=CollisionShape3D.new();wall_shape.shape=SphereShape3D.new();wall_shape.shape.radius=0.06
	wall.add_child(wall_shape);scene.add_child(wall);wall.global_position=actor.camera.global_position.lerp(reticle.ray_origin,0.5)
	await physics_frame;await physics_frame
	reticle.update_reticle();check(not reticle.visible,"head-to-muzzle obstruction hides impossible aim")
	scene.free()
	print("AIM_RETICLE_RESULT checks=",checks," failures=",failures," headset_tested=false")
	quit(failures)





