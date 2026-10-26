extends RefCounted
static var _finish:StandardMaterial3D
static func apply(cylinder:Node3D,receiver:StandardMaterial3D)->void:
	if _finish==null:
		_finish=receiver.duplicate();var image:=receiver.albedo_texture.get_image()
		if image.is_compressed():image.decompress()
		_finish.albedo_texture=ImageTexture.create_from_image(image.get_region(Rect2i(5,8,266,240)))
		_finish.albedo_color=Color.WHITE;_finish.texture_repeat=true
	for part in cylinder.find_children("*","MeshInstance3D",true,false):
		var original:=part.material_override as StandardMaterial3D
		if original!=null and original.albedo_color.is_equal_approx(Color("59646b")):part.material_override=_finish
