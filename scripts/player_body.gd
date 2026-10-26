extends Node3D
## Original render-only field suit. Existing gloves and head collision retain authority.
var actor: Node3D
var pieces: Dictionary = {}
var shoulders: Array[Vector3] = []
var wrists: Array[Vector3] = []
var elbows: Array[Vector3] = []
var phase := 0.0
var eye_height := 1.65
var _built := false
var _yaw_basis := Basis.IDENTITY
var _flight_trails097:Array[Node3D]=[]
func setup(value: Node3D) -> void:
	actor = value
	process_priority = 100
	if not _built: _build()
	reset_pose()
func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = .9
	result.metallic = .03
	return result
func _piece(label: String, mesh: Mesh, mat: Material):
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(instance)
	pieces[label] = instance
func _build():
	_built = true
	if not preload("res://scripts/asset_quality.gd").lightweight() and ProjectSettings.get_setting("ashfall/full_suit_preview_088",true):
		preload("res://scripts/field_suit_088.gd").build(self)
		return
	var cloth := material(Color(.10,.14,.16))
	var armor := material(Color(.17,.20,.19))
	var rubber := material(Color(.045,.055,.06))
	var torso := CylinderMesh.new()
	torso.height = 1
	torso.top_radius = .20
	torso.bottom_radius = .16
	torso.radial_segments = 12
	_piece("Jacket",torso,cloth)
	var plate := BoxMesh.new()
	plate.size = Vector3(.29,.27,.035)
	_piece("ChestPlate",plate,armor)
	var pelvis := BoxMesh.new()
	pelvis.size = Vector3(.31,.18,.22)
	_piece("Belt",pelvis,rubber)
	for side in ["L","R"]:
		for part in ["UpperArm","Forearm","Thigh","Shin"]:
			var mesh := CapsuleMesh.new()
			mesh.height = 1
			mesh.radius = .5
			mesh.radial_segments = 8
			mesh.rings = 2
			_piece(side+part,mesh,cloth if part != "Shin" else armor)
		var boot := BoxMesh.new()
		boot.size = Vector3(.13,.13,.25)
		_piece(side+"Boot",boot,rubber)
	if not preload("res://scripts/asset_quality.gd").lightweight():preload("res://scripts/field_suit_088.gd").upgrade_arms(self)
func reset_pose():
	phase = 0
	update_pose(0.0, true)
func _process(delta: float):
	update_pose(delta)
func _segment(label: String, start: Vector3, finish: Vector3, diameter: float):
	var direction := finish-start
	var length_value := maxf(.001,direction.length())
	var basis := Basis(Quaternion(Vector3.UP,direction.normalized())) if direction.length_squared()>.000001 else Basis.IDENTITY
	pieces[label].global_transform = Transform3D(basis.scaled_local(Vector3(diameter,length_value,diameter)),(start+finish)*.5)
func _wrist(hand: Node3D, side: float, head: Vector3) -> Vector3:
	if actor.xr_enabled and is_instance_valid(hand):
		var glove := hand.get_node_or_null("ArticulatedGlove") as Node3D
		if glove != null:
			var adapter:=glove.get_node_or_null("SkinnedGlove086")
			if adapter!=null and adapter.skeleton!=null:
				var bone:int=adapter.skeleton.find_bone("Wrist_L" if side<0 else "Wrist_R")
				if bone>=0:return adapter.skeleton.to_global(adapter.skeleton.get_bone_global_pose(bone).origin)
			return glove.to_global(Vector3(0,0,.08))
		return hand.global_position
	return head + _yaw_basis*Vector3(side*.29,-.46,-.40)
func update_pose(delta: float, force := false):
	if not is_instance_valid(actor) or not _built: return
	if actor.xr_enabled and not actor.tracking_available:
		hide()
		return
	if not force and not actor.input_enabled: return
	show()
	var camera: Camera3D = actor.get_view_camera()
	var head := camera.global_position
	eye_height = clampf(head.y-actor.global_position.y,.55,2.2)
	var forward := -camera.global_basis.z
	forward.y = 0
	if forward.length_squared()>.001:
		forward = forward.normalized()
		_yaw_basis = Basis.looking_at(forward,Vector3.UP)
	var right := _yaw_basis.x
	var rear := _yaw_basis.z
	var hip_height := minf(eye_height*.49,eye_height-.28)
	var hip := Vector3(head.x,actor.global_position.y+hip_height,head.z)+rear*.12
	var shoulder_center := head-Vector3.UP*minf(.29,eye_height*.25)+rear*.12
	var chest_height := maxf(.16,shoulder_center.y-hip.y)
	pieces.Jacket.global_transform = Transform3D(_yaw_basis.scaled_local(Vector3(1,chest_height,1)),hip+Vector3.UP*chest_height*.5)
	pieces.ChestPlate.global_transform = Transform3D(_yaw_basis,hip+Vector3.UP*chest_height*.58-rear*.18)
	pieces.ChestPlate.scale.y = minf(1,chest_height/.30)
	pieces.Belt.global_transform = Transform3D(_yaw_basis,hip)
	shoulders.clear(); wrists.clear(); elbows.clear()
	var speed := Vector2(actor.velocity.x,actor.velocity.z).length()
	phase += maxf(0,delta)*minf(speed,10)*2.2
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		var prefix := "L" if index == 0 else "R"
		var shoulder := shoulder_center+right*side*.205
		var hand: Node3D = actor.left_hand if index == 0 else actor.right_hand
		var wrist := _wrist(hand,side,head)
		# Analytic two-bone bend; stretch only for out-of-reach tracked poses.
		var offset := wrist-shoulder
		var distance := maxf(.001,offset.length())
		var length_value := maxf(.32,distance*.501)
		var axis := offset/distance
		var hint := right*side*.75+rear*.3-Vector3.UP*.55
		var bend := hint-axis*hint.dot(axis)
		if bend.length_squared()<.001: bend = axis.cross(Vector3.UP)
		bend = bend.normalized()
		var elbow := shoulder+axis*distance*.5+bend*sqrt(maxf(0,length_value*length_value-distance*distance*.25))
		_segment(prefix+"UpperArm",shoulder,elbow,.105)
		_segment(prefix+"Forearm",elbow,wrist,.085)
		# A tracked hand may touch the visor. Omit only the sleeve segment inside
		# the eye clearance so no suit geometry can envelope the near camera.
		pieces[prefix+"UpperArm"].visible = Geometry3D.get_closest_point_to_segment(head,shoulder,elbow).distance_to(head)>.17
		pieces[prefix+"Forearm"].visible = Geometry3D.get_closest_point_to_segment(head,elbow,wrist).distance_to(head)>.17
		shoulders.append(shoulder); wrists.append(wrist); elbows.append(elbow)
		var stride := sin(phase+index*PI)*minf(speed*.045,.25)
		var foot := Vector3(head.x,actor.global_position.y+.07,head.z)+right*side*.115+rear*(.10+stride)
		if actor.is_inside_tree():
			var ray := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.35,foot-Vector3.UP*.5,5,[actor.get_rid()])
			var ground := actor.get_world_3d().direct_space_state.intersect_ray(ray)
			if not ground.is_empty(): foot.y = ground.position.y+.07
		foot.y += maxf(0,sin(phase+index*PI))*minf(speed*.012,.065)
		var leg_hip := hip+right*side*.105
		var knee := (leg_hip+foot)*.5-rear*minf(.12,eye_height*.10)
		_segment(prefix+"Thigh",leg_hip,knee,.14)
		_segment(prefix+"Shin",knee,foot,.115)
		pieces[prefix+"Boot"].global_transform = Transform3D(_yaw_basis,foot-rear*.045)
