extends RefCounted
static var _grain:ImageTexture
static func metal(color:String="30383d",roughness:float=.36)->StandardMaterial3D:
	if _grain==null:
		var image:=Image.create(128,128,false,Image.FORMAT_RGB8);var rng:=RandomNumberGenerator.new();rng.seed=940173
		for y in 128:
			for x in 128:
				var value:=rng.randf_range(.90,1.0);image.set_pixel(x,y,Color(value,value,value))
		_grain=ImageTexture.create_from_image(image)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(color);mat.albedo_texture=_grain;mat.metallic=.78;mat.roughness=roughness
	mat.uv1_triplanar=true;mat.uv1_scale=Vector3(12,12,12);return mat
