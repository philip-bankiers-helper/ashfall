extends Node3D
## Decorative starting weapon rack. Existing owned weapons only, no inventory/ammo grants.
var grips:Array[Marker3D]=[]
func setup(rack:Node3D,origin:Vector3)->void:
	global_position=origin
	var finish:=StandardMaterial3D.new();finish.albedo_color=Color(0.09,0.12,0.13);finish.metallic=0.65;finish.roughness=0.7
	var shelf:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(maxf(1.1, rack.weapons.size() * .56),0.05,0.9)
	shelf.mesh=box;shelf.material_override=finish;shelf.position=Vector3(0,-0.23,-0.22);add_child(shelf)
	# Starting staging pad is at world Y=0; supports meet the shelf underside.
	var leg_height:=maxf(0.05,origin.y-0.255)
	for side in [-1.0,1.0]:
		var leg:=MeshInstance3D.new();var leg_mesh:=BoxMesh.new()
		leg_mesh.size=Vector3(0.055,leg_height,0.7)
		leg.mesh=leg_mesh;leg.material_override=finish
		leg.position=Vector3(side*0.46,-0.255-leg_height*0.5,-0.22)
		shelf.add_child(leg)
		# Shelf already contributes its own translation; keep support endpoints exact.
		leg.position-=shelf.position
	for index in range(rack.weapons.size()):
		var mount:=Node3D.new();mount.position=Vector3((index - (rack.weapons.size()-1)*.5)*.56,0,0)
		add_child(mount)
		var copy:Node3D=rack.weapons[index].model.duplicate(0)
		copy.transform=Transform3D(Basis.IDENTITY.scaled(rack.weapons[index].model.scale),Vector3.ZERO)
		copy.visible=true
		# No source weapon node, collision, audio, scripts or signals are copied.
		_strip_scripts(copy)
		mount.add_child(copy)
		var grip:=Marker3D.new();grip.position=Vector3(0,-0.08,0)
		mount.add_child(grip);grips.append(grip)
func get_grip_targets()->Array:
	var result:Array=[]
	for index in range(grips.size()):result.append({"id":"weapon_pickup:"+str(index),"position":grips[index].global_position})
	return result
func _strip_scripts(node:Node)->void:
	node.set_script(null)
	node.set_process(false);node.set_physics_process(false);node.set_process_unhandled_input(false)
	for child in node.get_children():
		if child.name=="AmmoReadoutPanel":node.remove_child(child);child.free()
		else:_strip_scripts(child)

