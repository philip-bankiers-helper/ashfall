extends "res://tests/inventory_041.gd"
func run()->void:
	var actor:=Actor.new();root.add_child(actor)
	var floor_body:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new();shape.size=Vector3(30,.2,30);collision.shape=shape
	floor_body.add_child(collision);floor_body.position.y=-.1;root.add_child(floor_body)
	await physics_frame
	var rack:=Rack.new();root.add_child(rack)
	for i in range(12):
		var gun:=Gun.new();rack.add_child(gun);rack.weapons.append(gun)
	var inventory=load("res://scripts/weapon_inventory.gd").new();root.add_child(inventory)
	inventory.setup(actor,rack);inventory.set_process(false)
	check(inventory.SLOT_LIMIT==6,"carried weapon cap is exactly six")
	check(inventory.owned_indices()==[0,2,4],"initial loadout remains three original weapons")
	check(inventory.pickup_weapon(1) and inventory.pickup_weapon(3) and inventory.pickup_weapon(5),"three additional weapons fill six carried slots")
	check(inventory.owned_indices().size()==6 and inventory.pickups.size()==6,"six carried and six world props account for twelve original instances")
	check(not inventory.pickup_weapon(6) and inventory.pickups.has(6),"seventh generic pickup rejected without deleting world gun")
	for i in range(6):check(rack.weapons[i].ammo==7,"pickup preserves loaded rounds slot%d"%i)
	check(inventory.drop_weapon(3) and inventory.pickup_weapon(6),"drop creates one vacancy and replacement fills sixth slot")
	check(inventory.owned_indices().size()==6 and inventory.pickups.has(3) and not inventory.pickups.has(6),"replacement neither duplicates nor loses represented guns")
	inventory.free();rack.free();actor.free();floor_body.free()
	await process_frame
	print("INVENTORY_SIX_045 checks=",passed+failures.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

