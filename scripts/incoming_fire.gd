extends Node3D
## Original chunky low-view directional chains, never a full-screen damage vignette.
const DURATION:=1.0
const MAX_ATTACKS:=4
const CHUNKS:=4
var camera:Camera3D
var chains:Array[MeshInstance3D]=[]
var materials:Array[StandardMaterial3D]=[]
var attacks:Array[Dictionary]=[]
func setup(view:Camera3D)->void:
	camera=view
	for i in range(MAX_ATTACKS):
		var chain:=MeshInstance3D.new()
		chain.layers=1<<19 # Headset UI must not be drawn into a weapon optic viewport.
		chain.name="IncomingFireChain%d"%i
		var mesh:=ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in range(CHUNKS):
			var width:float=[.23,.18,.135,.095][part]
			var height:float=[.085,.073,.061,.05][part]
			var y:float=[0,.105,.193,.265][part]
			# Thick open chevron, not a filled triangle or text character.
			var points:Array[Vector3]=[Vector3(-width*.5,y-height*.35,0),Vector3(0,y+height*.5,0),Vector3(width*.5,y-height*.35,0),Vector3(width*.5-.025,y-height*.65,0),Vector3(0,y+height*.03,0),Vector3(-width*.5+.025,y-height*.65,0)]
			for index in [0,1,4,0,4,5,1,2,3,1,3,4]:mesh.surface_add_vertex(points[index])
		mesh.surface_end()
		chain.mesh=mesh
		chain.set_meta("chunk_widths",[.23,.18,.135,.095])
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test=true
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		material.albedo_color=Color(.98,.045,.035,1)
		chain.material_override=material
		chain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chain)
		chains.append(chain);materials.append(material)
		chain.hide()
func notify_damage(source_world:Vector3)->void:
	if not source_world.is_finite() or camera==null:return
	var bearing:=bearing_from_view(camera.global_transform,source_world)
	# Repeated hits from one direction refresh one chain; distinct attackers keep separate cues.
	for attack in attacks:
		if absf(wrapf(bearing-bearing_from_view(camera.global_transform,attack.source),-PI,PI))<deg_to_rad(12):
			attack.source=source_world;attack.remaining=DURATION
			refresh(0)
			return
	if attacks.size()>=MAX_ATTACKS:attacks.pop_front()
	attacks.append({"source":source_world,"remaining":DURATION})
	refresh(0)
func clear()->void:
	attacks.clear()
	for chain in chains:chain.hide()
func refresh(delta:float)->void:
	if camera==null:return
	for index in range(attacks.size()-1,-1,-1):
		attacks[index].remaining=maxf(0,float(attacks[index].remaining)-maxf(delta,0))
		if attacks[index].remaining<=0:attacks.remove_at(index)
	for i in range(chains.size()):
		var chain:=chains[i]
		chain.visible=i<attacks.size()
		if not chain.visible:continue
		var attack:Dictionary=attacks[i]
		var bearing:=bearing_from_view(camera.global_transform,attack.source)
		# All bearings remain low and visible, including rear hits. Direction uses yaw only;
		# no camera rotation, screen vignette or random source is introduced.
		chain.position=Vector3(sin(bearing)*.18,-.54-cos(bearing)*.09,-1.10)
		chain.rotation.z=-bearing
		chain.set_meta("bearing",bearing)
		chain.set_meta("source_world",attack.source)
		var color:=materials[i].albedo_color
		color.a=clampf(float(attack.remaining)/DURATION,0,1)
		materials[i].albedo_color=color
static func bearing_from_view(view:Transform3D,source_world:Vector3)->float:
	var offset:=source_world-view.origin;offset.y=0
	if offset.length_squared()<.000001:return 0
	var forward:Vector3=-view.basis.z;forward.y=0
	if forward.length_squared()<.000001:forward=Vector3.FORWARD
	forward=forward.normalized()
	var right:=forward.cross(Vector3.UP).normalized()
	return atan2(offset.dot(right),offset.dot(forward))
