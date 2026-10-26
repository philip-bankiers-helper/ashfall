extends Node
## Cosmetic short-lived beams follow their emitter; hit points stay in world space.
var game:Node3D
func setup(owner_game:Node3D)->void:
	game=owner_game;process_priority=120
func _process(delta:float)->void:
	game._update_effect_pool(delta)
static func emitter(rack:Node,origin:Vector3)->Node3D:
	if not is_instance_valid(rack) or rack.weapons.is_empty():return null
	var active:Node3D=rack.weapons[rack.selected]
	var candidates:Array=active.guns if "guns" in active else [active]
	var best:Node3D=null;var distance:=INF
	for gun in candidates:
		var d:float=gun.get_shot_transform().origin.distance_to(origin)
		if d<distance:distance=d;best=gun
	return best if distance<.25 else null
static func draw(mesh:MeshInstance3D,a:Vector3,b:Vector3)->void:
	if a.distance_squared_to(b)<.000001:mesh.hide();return
	mesh.global_position=(a+b)*.5
	mesh.global_basis=Basis(Quaternion(Vector3.UP,(b-a).normalized())).scaled_local(Vector3(1,a.distance_to(b),1))
