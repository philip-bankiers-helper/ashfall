class_name AshRagdoll
extends Node3D
## Real rigid-body wrecks. No collision layer: world contact without blocking actors.
const MAX_CORPSES := 6
const MAX_BODIES := 48
const LIFETIME := 12.0
var bodies: Array[RigidBody3D] = []
var joints: Array[ConeTwistJoint3D] = []
var age := 0.0
var origin := Vector3.ZERO
var _paused := false
var _saved_motion: Array = []

func set_paused(value: bool) -> void:
	if value == _paused: return
	_paused = value
	if value:
		_saved_motion.clear()
		for body in bodies:
			_saved_motion.append([body.linear_velocity,body.angular_velocity,body.freeze])
			body.freeze = true
	else:
		for i in range(bodies.size()):
			bodies[i].freeze = _saved_motion[i][2]
			bodies[i].linear_velocity = _saved_motion[i][0]
			bodies[i].angular_velocity = _saved_motion[i][1]
		_saved_motion.clear()

static func clear_all(context: Node) -> void:
	if context == null or not context.is_inside_tree(): return
	for corpse in context.get_tree().get_nodes_in_group("ragdolls"):
		corpse.retire()

static func spawn(parent: Node3D, pose: Transform3D, impulse: Vector3 = Vector3.ZERO, variant: int = 0, visual: Node3D = null) -> Node3D:
	if parent == null or not parent.is_inside_tree(): return null
	var active := parent.get_tree().get_nodes_in_group("ragdolls")
	while active.size() >= MAX_CORPSES:
		var oldest = active.pop_front()
		oldest.retire()
	var corpse = load("res://scripts/ragdoll.gd").new()
	parent.add_child(corpse)
	corpse.global_transform = Transform3D(pose.basis.orthonormalized(),pose.origin)
	corpse.origin = pose.origin
	corpse.add_to_group("ragdolls")
	corpse._build(variant)
	if is_instance_valid(visual): corpse._copy_visual(visual)
	var kick := impulse.limit_length(12.0) if impulse.is_finite() else Vector3.ZERO
	corpse.bodies[0].apply_central_impulse(kick + Vector3(0,1.4,0))
	corpse.bodies[0].apply_torque_impulse(Vector3(0.6,0.1,0.4))
	return corpse

func _body(label: String, center: Vector3, size: Vector3, weight: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = label
	body.position = center
	body.mass = weight
	body.collision_layer = 0
	body.collision_mask = 1
	body.continuous_cd = true
	body.linear_damp = 0.35
	body.angular_damp = 1.8
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.75
	body.physics_material_override.bounce = 0.02
	add_child(body)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	var mesh := MeshInstance3D.new()
	mesh.name = "FallbackArmor"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.19,0.24,0.25)
	material.metallic = 0.75
	material.roughness = 0.5
	mesh.material_override = material
	body.add_child(mesh)
	bodies.append(body)
	return body

func _joint(a: RigidBody3D, b: RigidBody3D, anchor: Vector3, swing: float) -> void:
	var joint := ConeTwistJoint3D.new()
	joint.position = anchor
	joint.rotation.z = PI/2
	joint.swing_span = swing
	joint.twist_span = 0.4
	joint.bias = 0.2
	joint.softness = 0.85
	joint.exclude_nodes_from_collision = true
	add_child(joint)
	joint.node_a = joint.get_path_to(a)
	joint.node_b = joint.get_path_to(b)
	joints.append(joint)

func _build(variant: int) -> void:
	var torso := _body("Torso",Vector3(0,1.04,0),Vector3(0.68,0.52,0.4),12)
	var head := _body("Turret",Vector3(0,1.5,0),Vector3(0.44,0.24,0.36),3)
	_joint(torso,head,Vector3(0,1.34,0),0.55)
	for side in [-1.0,1.0]:
		var arm := _body("Arm",Vector3(side*0.48,1.08,0),Vector3(0.2,0.32,0.32),3)
		_joint(torso,arm,Vector3(side*0.35,1.18,0),1.15)
		if variant in [1,3]:
			var pod := _body("Rotor",Vector3(side*(1.1 if variant==3 else 0.7),0.92,0),Vector3(0.45,0.18,0.45),4)
			_joint(torso,pod,Vector3(side*0.38,0.94,0),0.65)
		else:
			var thigh := _body("UpperLeg",Vector3(side*0.26,0.55,0),Vector3(0.17,0.34,0.19),4)
			var shin := _body("LowerLeg",Vector3(side*0.26,0.19,0),Vector3(0.21,0.3,0.28),3)
			_joint(torso,thigh,Vector3(side*0.26,0.78,0),0.9)
			_joint(thigh,shin,Vector3(side*0.26,0.37,0),0.75)

func _copy_visual(source: Node3D) -> void:
	var detailed := source.find_child("DetailedEnemy", true, false)
	if detailed != null and detailed.has_method("configure_ragdoll"):
		detailed.configure_ragdoll(self)
	for body in bodies: body.get_node("FallbackArmor").hide()
	_copy_meshes(source)

func _copy_meshes(node: Node) -> void:
	if node.has_method("bake_for_ragdoll") and node.call("bake_for_ragdoll", self):
		for child in node.get_children():
			if child != node.get("model"): _copy_meshes(child)
		return
	if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh != null:
		var closest := bodies[0]
		var best := INF
		for body in bodies:
			var distance := body.global_position.distance_squared_to(node.global_position)
			if distance < best:
				best = distance
				closest = body
		var mesh := MeshInstance3D.new()
		mesh.mesh = node.mesh
		mesh.material_override = node.material_override
		for surface in range(node.mesh.get_surface_count()):
			mesh.set_surface_override_material(surface, node.get_surface_override_material(surface))
		mesh.cast_shadow = node.cast_shadow
		closest.add_child(mesh)
		mesh.global_transform = node.global_transform
	for child in node.get_children(): _copy_meshes(child)

func _physics_process(delta: float) -> void:
	if _paused: return
	age += delta
	if age >= LIFETIME:
		retire()
		return
	for body in bodies:
		if not body.global_position.is_finite() or body.global_position.distance_to(origin)>40.0:
			retire()
			return
		body.linear_velocity = body.linear_velocity.limit_length(12.0)
		body.angular_velocity = body.angular_velocity.limit_length(9.0)

func retire() -> void:
	remove_from_group("ragdolls")
	set_physics_process(false)
	for body in bodies:
		body.freeze = true
		body.collision_mask = 0
	hide()
	queue_free()

