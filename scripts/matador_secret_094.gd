extends RefCounted
static func build(model:Node3D)->void:
	for side in [-1.0,1.0]:
		var label:=Label3D.new();label.name="InsideMatadorBore094_Left" if side<0 else "InsideMatadorBore094_Right"
		label.text="Don't look\nunder here.";label.font_size=32;label.pixel_size=.000065
		label.position=Vector3(side*.021,.0694,-.367);label.rotation.y=PI
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		label.modulate=Color("ded7c7");label.outline_size=0;label.double_sided=false;label.no_depth_test=false
		label.billboard=BaseMaterial3D.BILLBOARD_DISABLED;label.visibility_range_end=.14;label.layers=1<<18
		label.set_meta("inside_depth_metres",.003);model.add_child(label)
