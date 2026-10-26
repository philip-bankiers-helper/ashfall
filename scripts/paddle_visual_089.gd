extends RefCounted
const Items=preload("res://scripts/field_item_models.gd")
static func build(paddle:Node3D)->void:
	var geometry:=Node3D.new();geometry.name="HospitalPaddle090";paddle.add_child(geometry)
	geometry.scale=Vector3.ONE*1.30
	geometry.rotation.x=PI*.5 # Electrode normal now points along fingertips (-Z), not down.
	paddle=geometry
	var steel:=Items.material(Color("909b9d"),.86,.28)
	var dark:=Items.material(Color("323c4b"),.48,.45)
	var trim:=Items.material(Color("ce3443"),.48,.36)
	var rubber:=Items.material(Color("10191d"),.05,.88)
	Items._box(paddle,"RoundedInsulatedHousing",Vector3(.096,.028,.135),Vector3.ZERO,dark,.012)
	Items._box(paddle,"BrushedElectrodePlate",Vector3(.087,.006,.125),Vector3(0,-.016,0),steel,.008)
	Items._box(paddle,"InsetStatusStrip",Vector3(.067,.003,.010),Vector3(0,.015,-.044),trim,.002)
	Items._box(paddle,"RedInsulatorBand",Vector3(.099,.006,.138),Vector3(0,-.010,0),trim,.010)
	# Hospital-style raised loop: two supports and a padded transverse hand grip.
	for x in [-.034,.034]:Items._box(paddle,"HandleSupportLeft" if x<0 else "HandleSupportRight",Vector3(.012,.055,.035),Vector3(x,.044,.018),dark,.005)
	Items._box(paddle,"InsulatedFingerHandle",Vector3(.080,.025,.035),Vector3(0,.078,.018),rubber,.010)
	for i in 9:Items._box(paddle,"GripRib%d"%i,Vector3(.002,.026,.038),Vector3(-.032+i*.008,.078,.018),dark,.001)
	for side in [-1,1]:
		Items._box(paddle,"SideFrame",Vector3(.009,.045,.072),Vector3(side*.043,.035,-.008),dark,.004)
		Items._cylinder(paddle,"RedChargeButton",.010,.003,Vector3(side*.031,.059,-.024),trim)
		Items._cylinder(paddle,"InsetButtonCenter",.005,.004,Vector3(side*.031,.061,-.024),steel)
	for side in [-1,1]:
		for z in [-.048,.048]:
			Items._cylinder(paddle,"RecessedFastener",.003,.002,Vector3(side*.037,.015,z),steel)
	Items._ring(paddle,"CableGrommet",.008,.003,Vector3(0,.078,.038),dark).rotation.x=PI*.5
