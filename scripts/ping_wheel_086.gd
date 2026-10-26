extends "res://scripts/weapon_wheel.gd"
## Shared geometry, physical size, player translation and ray picking with the item wheel.
func _ready()->void:
	SLOT_ACTIONS=[]
	for i in 8:SLOT_ACTIONS.append("ping_%d"%i)
	super._ready()
	for i in 8:
		var icon:=Sprite3D.new();icon.texture=load("res://assets/ui/ping0993_5.svg" if i==5 else "res://assets/ui/ping072_%d.svg"%i);icon.pixel_size=.0015
		icon.position=slot_position(i,.225)+Vector3(0,0,.022);icon.no_depth_test=true;icon.render_priority=124;add_child(icon)
func _set_highlight(index:int)->void:
	highlighted=index
	for i in _materials.size():_materials[i].albedo_color=Color("b16a20") if i==index else Color("16313a")
