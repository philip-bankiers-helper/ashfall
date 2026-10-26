extends RefCounted
## An open, long optical enclosure; every screw and rib seats in a solid wall.
const Finish=preload("res://scripts/optic_material_094.gd")
static func build(scope:Node3D,gun:Node3D)->void:
	var housing:=Node3D.new();housing.name="LongSPRScopeHousing094";scope.add_child(housing)
	var metal:=Finish.metal("30383e",.48)
	var edge:=Finish.metal("525c61",.43)
	var rubber:=StandardMaterial3D.new();rubber.albedo_color=Color("10171b");rubber.roughness=.8
	# Wide rear ocular transitions to a narrower objective tube, as in the reference.
	for side in [-1.0,1.0]:
		_box(gun,housing,Vector3(.010,.083,.120),Vector3(side*.061,.151,.001),metal,.003)
		_box(gun,housing,Vector3(.122,.010,.120),Vector3(0,.151+side*.0375,.001),metal,.003)
		_box(gun,housing,Vector3(.012,.085,.018),Vector3(side*.061,.151,.070),rubber,.002)
		_box(gun,housing,Vector3(.130,.011,.018),Vector3(0,.151+side*.038,.070),rubber,.002)
		for row in 5:
			_box(gun,housing,Vector3(.003,.029,.003),Vector3(side*.066,.151,-.040+row*.014),edge,.0007)
		for z in [-.045,.048]:
			var screw:=_cylinder(housing,.004,.0028,edge)
			screw.rotation.z=PI*.5;screw.position=Vector3(side*.066,.131,z);screw.name="SeatedSPRScrew094"
	var tube:=MeshInstance3D.new();tube.name="LongSPRObjectiveTube094"
	var tube_mesh:=CylinderMesh.new();tube_mesh.top_radius=.035;tube_mesh.bottom_radius=.035;tube_mesh.height=.155;tube_mesh.radial_segments=48;tube_mesh.cap_top=false;tube_mesh.cap_bottom=false
	tube.mesh=tube_mesh;tube.material_override=metal;tube.position=Vector3(0,.151,-.133);tube.rotation.x=PI*.5;tube.layers=1<<18;housing.add_child(tube)
	for depth in [-.065,-.083,-.18,-.204]:
		var band:=MeshInstance3D.new();var band_mesh:=TorusMesh.new();band_mesh.inner_radius=.033;band_mesh.outer_radius=.038;band_mesh.rings=40;band_mesh.ring_segments=12
		band.mesh=band_mesh;band.material_override=edge if depth==-.083 else rubber;band.position=Vector3(0,.151,depth);band.rotation.x=PI*.5;band.layers=1<<18;housing.add_child(band)
	var ring:=MeshInstance3D.new();ring.name="RecessedSPRObjective094"
	var torus:=TorusMesh.new();torus.inner_radius=.032;torus.outer_radius=.039;torus.rings=40;torus.ring_segments=12
	ring.mesh=torus;ring.material_override=rubber;ring.rotation.x=PI*.5;ring.position=Vector3(0,.151,-.219);ring.layers=1<<18;housing.add_child(ring)
	var glass:=MeshInstance3D.new();glass.name="FrontObjectiveGlass094"
	var disk:=CylinderMesh.new();disk.top_radius=.031;disk.bottom_radius=.031;disk.height=.001;disk.radial_segments=40
	glass.mesh=disk;glass.rotation.x=PI*.5;glass.position=Vector3(0,.151,-.207)
	var tint:=StandardMaterial3D.new();tint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;tint.albedo_color=Color(.045,.28,.29,.19);tint.metallic=.55;tint.roughness=.12
	glass.material_override=tint;glass.layers=1<<18;housing.add_child(glass)
	_box(gun,housing,Vector3(.060,.013,.15),Vector3(0,.104,-.027),metal,.003)
	var top:=_cylinder(housing,.014,.013,metal);top.position=Vector3(0,.197,-.027)
	var cap:=_cylinder(housing,.015,.003,edge);cap.position=Vector3(0,.205,-.027)
	var knob:=_cylinder(housing,.016,.014,metal);knob.rotation.z=PI*.5;knob.position=Vector3(.073,.151,-.017)
	var knob_cap:=_cylinder(housing,.0165,.003,edge);knob_cap.rotation.z=PI*.5;knob_cap.position=Vector3(.082,.151,-.017)
	for i in 12:
		var angle:=TAU*float(i)/12
		_box(gun,housing,Vector3(.0025,.004,.004),Vector3(.083,.151+sin(angle)*.013,-.017+cos(angle)*.013),rubber,.0005)
static func _box(gun:Node3D,parent:Node3D,size:Vector3,point:Vector3,material:Material,bevel:float)->MeshInstance3D:
	var part:MeshInstance3D=gun._beveled(size,point,material,bevel,parent);part.layers=1<<18
	return part
static func _cylinder(parent:Node3D,radius:float,height:float,material:Material)->MeshInstance3D:
	var part:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=32;part.mesh=mesh;part.material_override=material;part.layers=1<<18;parent.add_child(part)
	return part
