extends SceneTree
const Models=preload("res://scripts/field_item_models.gd")
const Supplies=preload("res://scripts/field_consumables.gd")
const Ammo=preload("res://scripts/ammo_pickups.gd")
var passed:=0
var failures:=0
var measurements:Array[Dictionary]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failures+=1;printerr("FAIL ",label)

func inspect(node:Node3D,title:String)->Dictionary:
	var triangles:=0;var bad_vectors:=0;var nondegenerate:=0;var reversed:=0;var surfaces:=0
	var bounds:=AABB();var have_bounds:=false
	var meshes:=node.find_children("*","MeshInstance3D",true,false)
	for part in meshes:
		var relative:Transform3D=node.global_transform.affine_inverse()*part.global_transform
		var local:AABB=relative*part.mesh.get_aabb()
		bounds=bounds.merge(local) if have_bounds else local;have_bounds=true
		for i in range(part.mesh.get_surface_count()):
			surfaces+=1
			var data:Array=part.mesh.surface_get_arrays(i)
			var vertices:PackedVector3Array=data[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=data[Mesh.ARRAY_NORMAL]
			var indices:PackedInt32Array=data[Mesh.ARRAY_INDEX] if data[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			if indices.is_empty():
				for k in range(vertices.size()):indices.append(k)
			for vertex in vertices:
				if not vertex.is_finite():bad_vectors+=1
			for normal in normals:
				if not normal.is_finite() or normal.length_squared()<.1:bad_vectors+=1
			for q in range(0,indices.size(),3):
				triangles+=1
				var a:=indices[q];var b:=indices[q+1];var c:=indices[q+2]
				var face:Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
				if face.length_squared()<.000000000000001:continue
				nondegenerate+=1
				if face.dot(normals[a]+normals[b]+normals[c])>0:reversed+=1
	var row:Dictionary={"model":title,"meshes":meshes.size(),"surfaces":surfaces,"triangles":triangles,"nondegenerate":nondegenerate,"reversed":reversed,"bad_vectors":bad_vectors,"size":[bounds.size.x,bounds.size.y,bounds.size.z]}
	measurements.append(row)
	check(bad_vectors==0,title+" finite mesh vertices and normals")
	check(reversed==0,title+" outward normals match Godot clockwise front faces")
	check(triangles>200 and triangles<8000,title+" bounded detail triangle budget")
	check(surfaces<=8 and meshes.size()<=2,title+" static detail batched into eight or fewer surfaces")
	check(node.find_children("*","CollisionObject3D",true,false).is_empty() and node.find_children("*","CollisionShape3D",true,false).is_empty(),title+" visual detail adds no interaction blocker")
	return {"row":row,"bounds":bounds}

func run()->void:
	# 077 retained authored asset coverage; downloaded versions have separate tracker/geometry tests.
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var scene:=Node3D.new();root.add_child(scene)
	for kind in ["soda","shaker","banana","backpack"]:
		var prop:Node3D=Supplies.make_prop(kind);scene.add_child(prop)
		var evidence:=inspect(prop,kind);var box:AABB=evidence.bounds
		check(prop.name=="Field_"+kind and prop.get_meta("model_revision","")==Models.REVISION,kind+" keeps stable prop root and revision")
		check(prop.get_node("ItemTitle").position.y==.25 and prop.get_node("ItemTitle").text==Supplies.TITLES.get(kind,"BACKPACK +1 POUCH"),kind+" retains existing label")
		check(box.size.x<.34 and box.size.y<.40 and box.size.z<.26,kind+" stays within original handheld prop envelope")
		if kind!="backpack":
			check(prop.has_node("Cap") and prop.get_node("Cap").visible,kind+" retains removable direct-child Cap")
			prop.get_node("Cap").hide()
			check(not prop.get_node("Cap").visible and prop.get_node("ModelSurfaces").visible,kind+" opening changes visible cover without deleting body")
		prop.queue_free()
	for family in range(3):
		var prop:=Node3D.new();scene.add_child(prop);prop.set_meta("family",["rifle","pistol","shells"][family]);prop.set_meta("collected",false)
		Models.ammo_supply(prop,family)
		var evidence:=inspect(prop,"ammo%d"%family)
		check(not prop.get_meta("collected") and prop.get_meta("family")==["rifle","pistol","shells"][family],"ammo%d preserves finite collection metadata"%family)
		check(evidence.bounds.size.x<.34 and evidence.bounds.size.z<.25,"ammo%d preserves supply footprint"%family)
		check(prop.get_meta("visual_parts").has("RoundGlyph0/Case") or prop.get_meta("visual_parts").has("Case"),"ammo%d retains raised round family glyphs"%family)
		prop.queue_free()
	var report:=FileAccess.open("user://equipment-model-metrics.json",FileAccess.WRITE)
	if report:report.store_string(JSON.stringify(measurements,"\t"));report.close()
	scene.queue_free();await process_frame;await process_frame
	print("EQUIPMENT_MODELS_062_RESULT passes=",passed," failures=",failures," headless=true xr=false pixels_verified=false")
	quit(0 if failures==0 else 1)
