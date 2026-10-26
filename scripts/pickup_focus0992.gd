extends Node
var game:Node
func setup(value:Node)->void:game=value;process_priority=124
static func nearest(hand:Node3D,targets:Array)->Dictionary:
	var best:Dictionary={};var distance:=INF
	for target in targets:
		var id:=str(target.get("id",""))
		if target.get("hand")!=hand or not (id.begins_with("inventory_pickup:") or id.begins_with("supply:") or id.begins_with("consumable:pickup:")):continue
		var d:float=hand.global_position.distance_to(target.position)
		if d<distance:distance=d;best=target
	return best
func _process(_delta:float)->void:
	var targets:Array=game._objective_grip_targets()
	for hand in [game.player.left_hand,game.player.right_hand]:
		var winner:=nearest(hand,targets);var id:=str(winner.get("id",""))
		for spec in [[game.weapon_inventory,"inventory_pickup:"],[game.ammo_pickups,"supply:"],[game.field_consumables,"consumable:pickup:"]]:
			var source:Node=spec[0]
			if source.aim_rings.has(hand) and not id.begins_with(spec[1]):source.aim_rings[hand].hide()
