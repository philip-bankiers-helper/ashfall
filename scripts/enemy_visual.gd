extends Node3D
## Isolated Irondust visual adapter. No authority over movement, aim or damage.
const MODEL = preload("res://assets/enemies/irondust/soldier_clean.tscn")
var model: Node3D
var skeleton: Skeleton3D
var owner_body: CharacterBody3D
var phase := 0.0
var previous := Vector3.ZERO
var locomotion := 0.0
var controlled: Array[int] = []
var source_meshes: Array[MeshInstance3D] = []
var last_bake_vertices := 0
var last_bake_usec := 0
var head_hit_shape:CollisionShape3D

func setup(body: CharacterBody3D, threat_material: Material, heavy: bool) -> void:
	name = "DetailedEnemy"
	owner_body = body
	previous = body.global_position
	model = MODEL.instantiate()
	add_child(model)
	model.scale = Vector3(94 if heavy else 90, 90, 90)
	# Imported soldier faces +Z; gameplay weapons and observed aim face -Z.
	model.rotation.y = PI
	model.position.y = 0.055
	skeleton = model.find_child("Skeleton3D", true, false)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if player:
		player.stop()
		player.set_process(false)
		player.set_physics_process(false)
	for bone in ["hips", "chest", "head", "upper_arm_L", "forearm_L", "hand_L", "upper_arm_R", "forearm_R", "hand_R", "thigh_L", "shin_L", "foot_L", "thigh_R", "shin_R", "foot_R"]:
		var index := skeleton.find_bone(bone)
		if index >= 0: controlled.append(index)
	_collect(model)
	# Same animated threat material as the original optic; attacks remain driven
	# exclusively by enemy state. No hidden target is queried here.
	var optic := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.13, 0.025, 0.025)
	optic.mesh = box
	optic.material_override = threat_material
	optic.position = Vector3(0, 1.66, -0.135)
	add_child(optic)
	var gun_material := StandardMaterial3D.new()
	gun_material.albedo_color = Color(0.12, 0.15, 0.16)
	gun_material.metallic = 0.8
	gun_material.roughness = 0.48
	var turret: Node3D = body.get("_turret")
	# Retain every gameplay muzzle transform while reducing the legacy barrel
	# diameter to the soldier's wrist/weapon proportions.
	for child in turret.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh and child.position.y < 0.0:
			child.mesh.top_radius *= 0.66
			child.mesh.bottom_radius *= 0.66
	for side in [-1.0, 1.0]:
		for part in [{"size": Vector3(0.12,0.10,0.20), "position": Vector3(side*0.408,-0.3,-0.1)}, {"size": Vector3(0.045,0.08,0.08), "position": Vector3(side*0.408,-0.355,-0.2)}]:
			var housing := MeshInstance3D.new()
			var housing_mesh := BoxMesh.new()
			housing_mesh.size = part.size
			housing.mesh = housing_mesh
			housing.material_override = gun_material
			turret.add_child(housing)
			housing.position = part.position
	head_hit_shape=CollisionShape3D.new();head_hit_shape.name="AnimatedHeadHitShape086"
	var head_box:=BoxShape3D.new();head_box.size=Vector3(.28,.32,.28);head_hit_shape.shape=head_box;body.add_child(head_hit_shape)
	update_pose(0.0, true, false, 0.0, 0.0)

func _collect(node: Node) -> void:
	if node is MeshInstance3D and node.visible: source_meshes.append(node)
	for child in node.get_children(): _collect(child)

func update_pose(delta: float, grounded: bool, aiming: bool, recoil: float, aim_pitch: float) -> void:
	if skeleton == null: return
	var displacement := owner_body.global_position - previous
	previous = owner_body.global_position
	var travel := Vector2(displacement.x, displacement.z).length()
	if travel > 1.0: travel = 0.0
	phase = fmod(phase + travel / 1.15 * TAU, TAU)
	var speed := travel / maxf(delta, 0.001)
	locomotion = move_toward(locomotion, clampf(speed / 1.4, 0, 1) if grounded else 0.0, delta * 7.0)
	for index in controlled:
		var rest := skeleton.get_bone_rest(index)
		skeleton.set_bone_pose_position(index, rest.origin)
		skeleton.set_bone_pose_rotation(index, rest.basis.get_rotation_quaternion())
	var pose_axes := skeleton.global_basis.orthonormalized().inverse()
	var local_motion := pose_axes * displacement
	var direction := Vector3(local_motion.x, 0, local_motion.z).normalized()
	if direction.length_squared() < 0.01: direction = pose_axes * -global_basis.z.normalized()
	var swing_axis := direction.cross(Vector3.UP).normalized()
	for side in ["L", "R"]:
		var swing := sin(phase + (0.0 if side == "L" else PI))
		_rotate("thigh_" + side, swing_axis, swing * 0.42 * locomotion)
		_rotate("shin_" + side, Vector3.RIGHT, -(0.10 + maxf(0, -swing) * 0.62 * locomotion))
		_rotate("foot_" + side, Vector3.RIGHT, 0.10 - swing * 0.18 * locomotion)
	var pitch_axis := pose_axes * global_basis.x.normalized()
	_rotate("chest", pitch_axis, clampf(aim_pitch * 0.25 - recoil * 0.08, -0.15, 0.15))
	_rotate("head", pitch_axis, clampf(aim_pitch * 0.65, -0.4, 0.4))
	for side in ["L", "R"]:
		var shoulder := skeleton.get_bone_global_pose(skeleton.find_bone("upper_arm_" + side)).origin
		var turret: Node3D = owner_body.get("_turret")
		var shoulder_in_weapon := turret.to_local(skeleton.to_global(shoulder))
		var sign_side := signf(shoulder_in_weapon.x)
		# The grip follows the retained weapon transform, including aim/recoil;
		# two-bone IK reaches it exactly rather than pointing an overlong forearm.
		var hand := skeleton.global_transform.affine_inverse() * turret.to_global(Vector3(sign_side * 0.408, -0.37, -0.10))
		var upper_length := skeleton.get_bone_rest(skeleton.find_bone("forearm_" + side)).origin.length()
		var lower_length := skeleton.get_bone_rest(skeleton.find_bone("hand_" + side)).origin.length()
		var offset := hand - shoulder
		var distance := clampf(offset.length(), 0.0001, upper_length + lower_length - 0.00001)
		var axis := offset.normalized()
		var hint := pose_axes * (global_basis.orthonormalized() * Vector3(sign_side, -0.35, 0.4))
		var bend := (hint - axis * hint.dot(axis)).normalized()
		var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
		var elbow := shoulder + axis * along + bend * sqrt(maxf(0, upper_length * upper_length - along * along))
		_aim_segment("upper_arm_" + side, "forearm_" + side, elbow)
		_aim_segment("forearm_" + side, "hand_" + side, hand)
		var finger_direction := skeleton.to_local(turret.to_global(Vector3(sign_side * 0.408, -0.385, -0.22)))
		_aim_segment("hand_" + side, "f_middle_01_" + side, finger_direction)
	skeleton.force_update_all_bone_transforms()
	_sync_head_hit_shape()

func _sync_head_hit_shape()->void:
	if not is_instance_valid(head_hit_shape):return
	var head_pose:Transform3D=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("head"))
	var ratio:float=owner_body._visual.scale.y
	var direction:Basis=head_pose.basis.orthonormalized()
	head_hit_shape.global_transform=Transform3D(direction,head_pose.origin+direction.y*.065*ratio)
	(head_hit_shape.shape as BoxShape3D).size=Vector3(.28,.32,.28)*ratio

func _rotate(bone_name: String, axis: Vector3, angle: float) -> void:
	var index := skeleton.find_bone(bone_name)
	var parent := skeleton.get_bone_parent(index)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var current := skeleton.get_bone_global_pose(index).basis
	var rotated := Basis(Quaternion(axis, angle)) * current
	skeleton.set_bone_pose_rotation(index, (parent_basis.inverse() * rotated).orthonormalized().get_rotation_quaternion())

func _aim_segment(bone_name: String, child_name: String, destination: Vector3) -> void:
	var index := skeleton.find_bone(bone_name)
	var child := skeleton.find_bone(child_name)
	var pose := skeleton.get_bone_global_pose(index)
	var shaft := skeleton.get_bone_global_pose(child).origin - pose.origin
	var wanted := destination - pose.origin
	if shaft.length_squared() < 0.000000001 or wanted.length_squared() < 0.000000001: return
	var rotation := Basis(Quaternion(shaft.normalized(), wanted.normalized()))
	var parent_basis := skeleton.get_bone_global_pose(skeleton.get_bone_parent(index)).basis
	skeleton.set_bone_pose_rotation(index, (parent_basis.inverse() * rotation * pose.basis).orthonormalized().get_rotation_quaternion())

func _body_index(bone_name: String) -> int:
	if bone_name.begins_with("head") or bone_name.begins_with("neck"): return 1
	var left := bone_name.ends_with("_L")
	var right := bone_name.ends_with("_R")
	if left or right:
		if bone_name.begins_with("thigh"): return 6 if left else 3
		if bone_name.begins_with("shin") or bone_name.begins_with("foot") or bone_name.begins_with("toe") or bone_name.begins_with("heel"): return 7 if left else 4
		return 5 if left else 2
	return 0

func configure_ragdoll(corpse: Node3D) -> void:
	# Match existing rigid bodies and joint anchors to this exact death pose.
	# Leaving the original mech rest anchors causes an immediate shoulder tear.
	skeleton.force_update_all_bone_transforms()
	var hips := _bone_world("hips")
	var chest := _bone_world("chest")
	var head := _bone_world("head")
	_set_rigid_segment(corpse.bodies[0], hips, chest + Vector3.UP * 0.11, 0.36, 0.28)
	_set_rigid_segment(corpse.bodies[1], head - Vector3.UP * 0.055, head + Vector3.UP * 0.13, 0.19, 0.22)
	_set_joint(corpse.joints[0], _bone_world("neck"), Vector3.UP)
	for side in ["R", "L"]:
		var arm_index := 2 if side == "R" else 5
		var joint_index := 1 if side == "R" else 4
		var shoulder := _bone_world("upper_arm_" + side)
		var wrist := _bone_world("hand_" + side)
		var hip := _bone_world("thigh_" + side)
		var knee := _bone_world("shin_" + side)
		var ankle := _bone_world("foot_" + side)
		_set_rigid_segment(corpse.bodies[arm_index], shoulder, wrist, 0.14, 0.16)
		_set_rigid_segment(corpse.bodies[arm_index + 1], hip, knee, 0.16, 0.19)
		_set_rigid_segment(corpse.bodies[arm_index + 2], knee, ankle, 0.16, 0.20)
		_set_joint(corpse.joints[joint_index], shoulder, wrist - shoulder)
		_set_joint(corpse.joints[joint_index + 1], hip, knee - hip)
		_set_joint(corpse.joints[joint_index + 2], knee, ankle - knee)
	# Joint3D captures body-local anchor frames when node paths are configured.
	# Explicitly rebuild those frames after all posed bodies/anchors are placed.
	for joint in corpse.joints:
		var path_a: NodePath = joint.node_a
		var path_b: NodePath = joint.node_b
		joint.node_a = NodePath()
		joint.node_b = NodePath()
		joint.node_a = path_a
		joint.node_b = path_b
func _bone_world(bone: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin

func _set_rigid_segment(rigid: RigidBody3D, start: Vector3, finish: Vector3, width: float, depth: float) -> void:
	var direction := finish - start
	rigid.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, direction.normalized())), (start + finish) * 0.5)
	for child in rigid.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			child.shape.size = Vector3(width, maxf(0.1, direction.length() * 0.85), depth)

func _set_joint(joint: ConeTwistJoint3D, anchor: Vector3, direction: Vector3) -> void:
	joint.global_transform = Transform3D(Basis(Quaternion(Vector3.RIGHT, direction.normalized())), anchor)

func bake_for_ragdoll(corpse: Node3D) -> bool:
	# Compatibility hook name retained; no CPU mesh partitioning or bake occurs.
	var follower = preload("res://scripts/ragdoll_skin.gd").new()
	corpse.add_child(follower)
	follower.setup(model, skeleton, corpse, self)
	last_bake_vertices = 0
	last_bake_usec = 0
	return true


func get_muzzle_transform()->Transform3D:
	# Marker lives under the same turret as the visible barrel and glove IK targets.
	# Its inherited transform includes visual sway, animated aim, recoil and body scale.
	var marker:Marker3D=owner_body.get("_weapon_muzzle")
	return marker.global_transform if is_instance_valid(marker) else global_transform
