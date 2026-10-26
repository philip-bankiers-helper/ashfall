extends Node3D
## A selectable standalone practice map. The campaign world remains preserved.
var spawn:=Vector3.ZERO
func enter(game:Node)->void:
	name="StandaloneSandboxRange091";position=Vector3(0,0,600)
	var art=preload("res://scripts/field_item_models.gd")
	var floor_mat:Material=art.material(Color("48545b"),.35,.65);var wall_mat:Material=art.material(Color("26343a"),.4,.62)
	for spec in [[Vector3(0,-.2,0),Vector3(90,.4,100)],[Vector3(0,8,-38),Vector3(90,16,.3)],[Vector3(-45,4,0),Vector3(.3,8,100)],[Vector3(45,4,0),Vector3(.3,8,100)]]:
		art._box(self,"RangeSurface",spec[1],spec[0],floor_mat if spec[1].y<1 else wall_mat,.01)
		var body:=StaticBody3D.new();body.add_to_group("climbable")
		if spec[1].y<1:body.add_to_group("construction_terrain")
		var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=spec[1];body.add_child(shape);add_child(body);body.position=spec[0]
	var origin:Vector3=game.player.global_position;spawn=global_position+Vector3(0,.2,8);var shift:=spawn-origin
	game.player.global_position=spawn;game.player.reset_motion();game.world.hide()
	for prop in game.weapon_inventory.pickups.values():prop.global_position+=shift
	for prop in game.weapon_inventory.review_owned_props.values():prop.global_position+=shift
	for id in game.weapon_inventory.review_positions:game.weapon_inventory.review_positions[id]+=shift
	game.active_sandbox_map=self;game._begin_chapter()
	if game.training:game.training.reset()
