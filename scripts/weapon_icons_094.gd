extends RefCounted
static var _cache:Dictionary={}
static func icon(index:int)->Texture2D:
	if not _cache.has(index):
		var path:="res://assets/ui/catalog0991/weapon_%d.png"%index
		if not ResourceLoader.exists(path):path="res://assets/ui/catalog094/weapon_%d.png"%index
		if not ResourceLoader.exists(path):path="res://assets/ui/wheel_weapon_%d.svg"%index
		_cache[index]=load(path)
		if index in [14,15,16,29]:
			#0992 user correction: reverse the accepted0991 thumbnail orientation.
			# This shared provider feeds the wheel, backpack and desktop inventory.
			var image:Image=_cache[index].get_image();image.rotate_180();_cache[index]=ImageTexture.create_from_image(image)
	return _cache[index]
