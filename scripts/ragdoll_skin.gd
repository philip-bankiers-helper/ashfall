extends Node3D
## Continuous GPU-skinned corpse driven by the existing bounded rigid anatomy.
var skeleton: Skeleton3D
var bodies: Array = []
var body_for_bone: PackedInt32Array
var body_offsets: Array[Transform3D] = []
var last_update_usec := 0
var last_setup_usec := 0

func setup(source_model: Node3D, source_skeleton: Skeleton3D, corpse: Node3D, adapter: Node3D) -> void:
	var started := Time.get_ticks_usec()
	name = "ContinuousCorpseSkin"
	bodies.assign(corpse.bodies)
	var copied: Node3D = source_model.duplicate()
	add_child(copied)
	copied.global_transform = source_model.global_transform
	skeleton = copied.find_child("Skeleton3D", true, false)
	var animation: AnimationPlayer = copied.find_child("AnimationPlayer", true, false)
	if animation:
		animation.stop()
		animation.set_process(false)
		animation.set_physics_process(false)
	for bone in range(skeleton.get_bone_count()):
		skeleton.set_bone_pose_position(bone, source_skeleton.get_bone_pose_position(bone))
		skeleton.set_bone_pose_rotation(bone, source_skeleton.get_bone_pose_rotation(bone))
		skeleton.set_bone_pose_scale(bone, source_skeleton.get_bone_pose_scale(bone))
		var body_index: int = adapter._body_index(String(skeleton.get_bone_name(bone)))
		body_for_bone.append(body_index)
		var bone_world := source_skeleton.global_transform * source_skeleton.get_bone_global_pose(bone)
		body_offsets.append(bodies[body_index].global_transform.affine_inverse() * bone_world)
	skeleton.force_update_all_bone_transforms()
	update_skin()
	last_setup_usec = Time.get_ticks_usec() - started

func _physics_process(_delta: float) -> void:
	if get_parent().get("_paused") == true: return
	update_skin()

func update_skin() -> void:
	var started := Time.get_ticks_usec()
	var world_to_skeleton := skeleton.global_transform.affine_inverse()
	# Imported bone indices are parent-before-child. Each local transform is
	# derived from the newly driven parent, retaining the exact death-pose offset.
	for bone in range(skeleton.get_bone_count()):
		var desired: Transform3D = world_to_skeleton * bodies[body_for_bone[bone]].global_transform * body_offsets[bone]
		var parent := skeleton.get_bone_parent(bone)
		var local := skeleton.get_bone_global_pose(parent).affine_inverse() * desired if parent >= 0 else desired
		skeleton.set_bone_pose_position(bone, local.origin)
		skeleton.set_bone_pose_rotation(bone, local.basis.orthonormalized().get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone, local.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	last_update_usec = Time.get_ticks_usec() - started
