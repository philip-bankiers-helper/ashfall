extends RefCounted
## Original nonmagnifying two-ring alignment sight with a separate solid bead.
## Al's supplied CX4/S85/AK sight image is the visual reference (062).
## Both markers are geometrically zeroed against the weapon's unchanged bore.
const LIVE_WEAPON_LAYER:=1<<18
const REAR_HEIGHT:=.135
const ZERO_DISTANCE:=80.0
static func build(parent:Node3D,profile:String,rear_z:float,front_z:float,muzzle:Vector3,metal:Material)->Node3D:
	var assembly:=Node3D.new();assembly.name="RingAndFrontDotSights";parent.add_child(assembly)
	var glow:=StandardMaterial3D.new();glow.albedo_color=Color(.96,.025,.76);glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	# Al retained a solid RED aiming dot; ring tint must not recolour the bead.
	var dot:=StandardMaterial3D.new();dot.albedo_color=Color(1,.045,.025);dot.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var rear_height:=REAR_HEIGHT-(.01/1.12 if profile=="s85" else 0.0)
	var target:=muzzle+Vector3.FORWARD*ZERO_DISTANCE
	var front_height:=lerpf(rear_height,target.y,(front_z-rear_z)/(target.z-rear_z))
	# The source image shows a thin large rear ring and smaller forward ring.
	# Keep existing rear size/height: a cropped image does not establish metres.
	# The existing solid bead remains inside the forward ring.
	_box(assembly,Vector3(.042,.010,.025),Vector3(0,.091,rear_z),metal,"RearRingFoot")
	for side in [-1,1]:_box(assembly,Vector3(.005,.031,.012),Vector3(side*.018,.109,rear_z),metal,"RearRingSupport")
	_ring(assembly,.016,.0167,Vector3(0,rear_height,rear_z),metal,"RearAlignmentRing")
	_ring(assembly,.0156,.0164,Vector3(0,rear_height,rear_z+.0025),glow,"RearRingLuminousEdge")
	var front:=Node3D.new();front.name="FrontAssembly";assembly.add_child(front)
	_box(front,Vector3(.010,front_height-.067,.017),Vector3(0,(front_height+.067)*.5-.0025,front_z),metal,"FrontPost")
	# Raised guards frame the bead without crossing the sight line.
	for side in [-1,1]:
		var guard:=_box(front,Vector3(.005,.029,.018),Vector3(side*.016,front_height-.005,front_z),metal,"FrontGuard")
		guard.rotation.z=side*(-.16 if profile=="akm" else -.05)
	var middle_z:=(rear_z+front_z)*.5
	var middle_height:=lerpf(rear_height,front_height,.5)
	_ring(front,.0098,.0104,Vector3(0,middle_height,middle_z),glow,"FrontAlignmentRing")
	var bead:=MeshInstance3D.new();bead.name="SolidFrontDot"
	var sphere:=SphereMesh.new();sphere.radius=.0022;sphere.height=.0044;sphere.radial_segments=12;sphere.rings=6
	bead.mesh=sphere;bead.material_override=dot;bead.position=Vector3(0,front_height,front_z);_add(front,bead)
	for item in [["RearReference",rear_z,rear_height],["FrontReference",front_z,front_height]]:
		var marker:=Marker3D.new();marker.name=item[0];marker.position=Vector3(0,item[2],item[1]);assembly.add_child(marker)
	for label in ["RearRingFoot","RearRingSupport","RearRingSupport2","RearAlignmentRing","FrontPost","FrontGuard","FrontGuard2"]:
		var support:=assembly.find_child(label,true,false) as Node3D
		if support!=null:support.hide()
	# Names with automatic @ suffixes also belong to the physical gray supports.
	for part in assembly.find_children("*","MeshInstance3D",true,false):
		if part.material_override==metal:part.hide()
	assembly.set_meta("floating_rings_088",true)
	assembly.set_meta("zero_distance",ZERO_DISTANCE);assembly.set_meta("bore_origin",muzzle);assembly.set_meta("style","physical_two_rings_solid_front_dot")
	assembly.set_meta("visual_reference","Al supplied CX4/S85/AK sight image, conversation2026-10-20; absolute dimensions not recoverable from crop")
	return assembly
static func _box(parent:Node3D,size:Vector3,at:Vector3,material:Material,label:String)->MeshInstance3D:
	var part:=MeshInstance3D.new();part.name=label;var mesh:=BoxMesh.new();mesh.size=size;part.mesh=mesh;part.position=at;part.material_override=material;_add(parent,part);return part
static func _ring(parent:Node3D,inner:float,outer:float,at:Vector3,material:Material,label:String)->void:
	var part:=MeshInstance3D.new();part.name=label;var mesh:=TorusMesh.new();mesh.inner_radius=inner;mesh.outer_radius=outer;mesh.rings=48;mesh.ring_segments=8
	part.mesh=mesh;part.rotation.x=PI*.5;part.position=at;part.material_override=material;_add(parent,part)
static func _add(parent:Node3D,mesh:MeshInstance3D)->void:
	mesh.layers=LIVE_WEAPON_LAYER;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh)

static func eye_aligned(assembly:Node3D,eye:Vector3,forward:Vector3)->bool:
	if not is_instance_valid(assembly):return false
	var rear:Node3D=assembly.get_node("RearReference")
	var front:Node3D=assembly.get_node("FrontReference")
	var axis:Vector3=(front.global_position-rear.global_position).normalized()
	var offset:Vector3=rear.global_position-eye
	var distance:=offset.dot(axis)
	# Bound eye relief and require both position and gaze alignment. Hip fire stays visible.
	return distance>.025 and distance<.65 and (offset-axis*distance).length()<.024 and forward.normalized().dot(axis)>.985

static func views_aligned(assembly:Node3D,views:Array)->bool:
	for view in views:
		if eye_aligned(assembly,view.origin,-view.basis.z):return true
	return false

static func is_viewing_through(assembly:Node3D,view_camera:Camera3D)->bool:
	if not is_instance_valid(assembly) or not assembly.is_visible_in_tree():return false
	var views:Array[Transform3D]=[]
	var interface:=XRServer.primary_interface
	# Match MP5/RFB: use actual runtime eye poses, never guess IPD from head centre.
	if view_camera is XRCamera3D and interface!=null and interface.is_initialized() and view_camera.get_parent() is XROrigin3D:
		for index in interface.get_view_count():
			views.append(interface.get_transform_for_view(index,view_camera.get_parent().global_transform))
	else:views.append(view_camera.global_transform)
	return views_aligned(assembly,views)
