extends SceneTree
const Pickups = preload("res://scripts/ammo_pickups.gd")
class Actor extends Node3D:
	var input_enabled := true
	var tracking_available := true
class Rack extends Node:
	var reserve := {"rifle":0,"pistol":0,"shells":0}
	var cap := {"rifle":180,"pistol":72,"shells":48}
	var requests := 0
	func add_reserve(family: String, amount: int) -> int:
		requests += 1
		if not reserve.has(family) or amount <= 0: return 0
		var accepted: int = mini(amount,cap[family]-reserve[family])
		reserve[family] += accepted
		return accepted
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ",label)
	else: failed += 1; printerr("FAIL ",label)
func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var actor := Actor.new()
	scene.add_child(actor)
	var rack := Rack.new()
	scene.add_child(rack)
	var pickups := Pickups.new()
	scene.add_child(pickups)
	pickups.set_physics_process(false)
	# This fixture tests partial-cap semantics at historical small quantities.
	# 061's expanded defaults are covered by equipment_integration_061.
	pickups.rifle_amount=60;pickups.pistol_amount=24;pickups.shells_amount=12
	pickups.setup(actor,rack,[Vector3(0,.3,0),Vector3(3,.3,0),Vector3(6,.3,0)])
	check(pickups.boxes.size() == 3,"three original family boxes only")
	check(pickups.find_children("*","CollisionObject3D",true,false).is_empty(),"supply meshes add no traversal blocker")
	actor.position = Vector3(20,0,0)
	pickups._physics_process(.2)
	check(rack.requests == 0,"distant boxes cannot grant ammunition")
	actor.position = Vector3.ZERO
	actor.input_enabled = false
	pickups._physics_process(.2)
	check(rack.requests == 0,"paused input blocks collection")
	actor.input_enabled = true
	actor.tracking_available = false
	pickups._physics_process(.2)
	check(rack.requests == 0,"tracking loss blocks collection")
	actor.tracking_available = true
	var awards: Array = []
	pickups.collected.connect(func(family,amount): awards.append([family,amount]))
	pickups._physics_process(.2)
	check(rack.reserve.rifle == 60 and rack.reserve.pistol == 0 and rack.reserve.shells == 0,"rifle box grants only its family")
	check(not pickups.boxes[0].visible and awards == [["rifle",60]],"positive accepted grant hides box and emits actual amount")
	pickups._physics_process(.2)
	check(rack.reserve.rifle == 60 and rack.requests == 1,"collected box cannot grant twice")
	actor.position.x = 3
	rack.reserve.pistol = 72
	pickups._physics_process(.2)
	check(pickups.boxes[1].visible and not pickups.boxes[1].get_meta("collected"),"full reserve never consumes supply")
	rack.reserve.pistol = 70
	pickups._physics_process(.2)
	check(rack.reserve.pistol == 72 and awards[-1] == ["pistol",2] and not pickups.boxes[1].visible,"partial accepted grant respects cap and reports actual2")
	actor.position.x = 6
	pickups._physics_process(.2)
	check(rack.reserve.shells == 12 and awards[-1] == ["shells",12],"shell box grants its family amount")
	pickups.reset_pickups()
	check(pickups.boxes[0].visible and pickups.boxes[1].visible and pickups.boxes[2].visible,"chapter reset restores all supply visuals")
	pickups.position.x = 100
	pickups._physics_process(.2)
	check(rack.reserve.shells == 12,"moved checkpoint collection uses global distance")
	actor.position.x = 106
	pickups._physics_process(.2)
	check(rack.reserve.shells == 24,"translated checkpoint supply collects once at new global position")
	pickups.reset_pickups()
	actor.position.y = -4
	pickups._physics_process(.2)
	check(rack.reserve.shells == 24,"supply cannot collect through floor from another elevation")
	actor.position = Vector3(107.001,0,0)
	pickups._physics_process(.2)
	check(rack.reserve.shells == 24,"just outside1m cannot collect")
	actor.position.x = 107
	pickups._physics_process(.2)
	check(rack.reserve.shells == 36,"exact1m boundary can collect")
	pickups.reset_pickups()
	pickups.rifle_amount = 0
	actor.position.x = 100
	pickups._physics_process(.2)
	check(rack.reserve.rifle == 60 and pickups.boxes[0].visible,"zero configured amount cannot consume supply")
	print("AMMO_PICKUPS_040_RESULT ",passed," passed ",failed," failed")
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)
