extends "res://tests/integration.gd"
class Actor extends Node3D:
	var input_enabled := true
	var mantling := false
	var head_obstructed := false
	var left_hand_reserved := false
	var left_hand := XRController3D.new()
	var right_hand := XRController3D.new()
	var camera := Camera3D.new()
	var _grabs := {}
	func _init():
		add_child(left_hand); add_child(right_hand); add_child(camera)
		camera.position.y=1.65
	func get_view_camera(): return camera
	func get_support_hand(): return left_hand
	func is_hand_input_ready(_hand): return true
class Gun extends Node3D:
	var ammo := 7
	var reload_state := "ready"
	var chamber := true
	var model := Node3D.new()
	func _init():
		add_child(model)
		var mesh := MeshInstance3D.new(); var shape:=BoxMesh.new(); shape.size=Vector3(.12,.2,.5); mesh.mesh = shape; model.add_child(mesh)
		var text := Label3D.new(); text.text = "REMOVE"; model.add_child(text)
class Rack extends Node3D:
	var weapons := []
	var selected := 0
	var is_holstered := false
	var is_selecting := false
	var inventory: Node
	var wheel: Node
	var reload_state := "ready"
	func _apply_selection(): pass
func run() -> void:
	var actor := Actor.new(); root.add_child(actor)
	var floor_body:=StaticBody3D.new(); var collision:=CollisionShape3D.new(); var floor_shape:=BoxShape3D.new()
	floor_shape.size=Vector3(20,.2,20); collision.shape=floor_shape; floor_body.add_child(collision); floor_body.position.y=-.1; root.add_child(floor_body)
	await physics_frame
	var rack := Rack.new(); root.add_child(rack)
	for i in range(5):
		var gun := Gun.new(); rack.add_child(gun); rack.weapons.append(gun)
	var inventory = load("res://scripts/weapon_inventory.gd").new(); root.add_child(inventory)
	inventory.setup(actor, rack)
	check(inventory.owned_indices() == [0,2,4], "three carried slots and five distinct types")
	check(inventory.pickups.size() == 2 and inventory.pickups.has(1) and inventory.pickups.has(3), "unowned types have exactly one ground instance")
	check(not inventory.pickup_weapon(1), "full inventory refuses pickup without losing ground instance")
	check(inventory.drop_weapon(0) and rack.selected == 2, "dropping selected weapon chooses owned fallback")
	check(not inventory.drop_weapon(0) and inventory.pickups.size() == 3, "duplicate drop cannot clone gun")
	check(inventory.pickup_weapon(1) and not inventory.pickup_weapon(1), "single pickup consumes exactly one world instance")
	for i in range(20):
		check(inventory.drop_weapon(1) and inventory.pickup_weapon(1), "repeat transfer " + str(i))
	check(rack.weapons[1].ammo == 7 and rack.weapons[1].chamber, "rounds and chamber preserved through twenty transfers")
	check(not inventory.pickup_weapon(-1) and not inventory.drop_weapon(99), "invalid type does not mutate ownership")
	inventory.drop_weapon(1)
	for hand in [actor.left_hand, actor.right_hand]:
		# Aim assist deliberately chooses one best target, not an arbitrary supplied ID.
		# Separate the old fixture's coincident dropped props before each hand test.
		for index in inventory.pickups:
			inventory.pickups[index].global_position=Vector3(0,1,-.8) if index==1 else Vector3(5+index,1,-5)
		hand.global_position = inventory.pickups[1].global_position
		check(inventory.handle_grip("inventory_pickup:1", hand), "either tracked hand picks up")
		inventory.drop_weapon(1)
	actor.left_hand.global_position = inventory.pickups[1].global_position
	actor._grabs[actor.left_hand] = Vector3.ZERO
	check(not inventory.handle_grip("inventory_pickup:1", actor.left_hand), "existing climb grip retains priority")
	actor._grabs.clear(); rack.reload_state = "reloading"
	check(inventory.get_grip_targets().is_empty(), "reload suppresses pickup targets")
	rack.reload_state = "ready"; actor.input_enabled = false
	check(inventory.get_grip_targets().is_empty(), "menu-disabled input suppresses pickup")
	actor.input_enabled = true
	var before: Array = inventory.owned_indices()
	inventory.relocate_pickups(Vector3(10,0,10))
	check(inventory.owned_indices() == before and inventory.pickups.size() == 3, "chapter relocation preserves ownership and finite ground instances")
	var labels := 0
	for prop in inventory.pickups.values():
		labels += prop.find_children("*", "Label3D", true, false).size()
	check(labels == 0, "ground weapon meshes contain no text")
	inventory.drop_weapon(2); inventory.drop_weapon(4)
	check(inventory.owned.is_empty() and rack.is_holstered, "last gun drop safely holsters")
	print("INVENTORY_041_RESULT passes=",passed," failures=",failures.size()," synthetic=true headset_tested=false")
	quit(0 if failures.is_empty() else 1)
