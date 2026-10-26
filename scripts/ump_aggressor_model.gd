extends RefCounted
## User supplied REEESkins CC-BY-4.0 asset; see assets/models/ump_aggressor/ATTRIBUTION.txt.
const ASSET_PATH="res://assets/models/ump_aggressor/ump_aggressor.glb"
const MAGAZINE_HOME:=Vector3(.000090475,-.147870724,-.214390603)
const DISPLAY_SCALE:=.7182 #089 five percent larger than088
static func scaled_mesh(source:Mesh)->ArrayMesh:
	var result:=ArrayMesh.new()
	for surface in source.get_surface_count():
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.append_from(source,surface,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*DISPLAY_SCALE),Vector3.ZERO))
		tool.set_material(source.surface_get_material(surface));tool.commit(result)
	return result
static func build(w:Node3D)->void:
	w.model=Node3D.new();w.model.name="AggressorUMP";w.add_child(w.model)
	w.model.scale=Vector3.ONE*DISPLAY_SCALE
	var alternative:bool=preload("res://scripts/model_variants.gd").choose("ump")=="ump_alt"
	var asset:Node3D=load("res://assets/models/download_ump_alt/model.glb" if alternative else ASSET_PATH).instantiate()
	var source_body:MeshInstance3D=asset.find_child("Body" if alternative else "AggressorBody",true,false)
	var source_mag:MeshInstance3D=asset.find_child("Magazine" if alternative else "AggressorMagazine",true,false)
	w.set_meta("downloaded_model_variant_082","ump_alt" if alternative else "ump")
	var body:=MeshInstance3D.new();body.name="AggressorBody";body.mesh=source_body.mesh;w.model.add_child(body)
	w.magazine=MeshInstance3D.new();w.magazine.name="DetachableAggressorMagazine";w.magazine.mesh=source_mag.mesh;w.magazine.position=MAGAZINE_HOME;w.model.add_child(w.magazine)
	var detached_mesh:=scaled_mesh(source_mag.mesh)
	w.loose_magazine=MeshInstance3D.new();w.loose_magazine.name="HeldAggressorMagazine";w.loose_magazine.mesh=detached_mesh;w.add_child(w.loose_magazine);w.loose_magazine.hide()
	w.hip_source=Node3D.new();w.hip_source.name="FreshAggressorMagazine";w.add_child(w.hip_source)
	var offered:=MeshInstance3D.new();offered.mesh=detached_mesh;w.hip_source.add_child(offered);w.hip_source.hide()
	asset.free()
	var steel:StandardMaterial3D=w._material(Color("6b7275"),.70,.38)
	var dark:StandardMaterial3D=w._material(Color("181b20"),.20,.68)
	var cue:StandardMaterial3D=w._material(Color(.05,.72,.75),.20,.40,.65)
	w._bolt_finish=steel;w._reload_finish=cue
	# The manual charging handle is independent from the shot-cycling carrier.
	w.bolt=w._beveled(Vector3(.032,.012,.022),Vector3(-.045,.064,-.10),steel,.003)
	w.bolt.name="FunctionalAggressorReloadBolt"
	w._box(Vector3(.002,.013,.10),Vector3(-.041,.064,-.085),dark)
	w.firing_carrier=w._beveled(Vector3(.002,.016,.048),Vector3(.041,.05,-.11),steel,.0005)
	w.guide=w._box(Vector3(.013,.013,.013),w.get_magazine_insert_point(),cue);w.guide.hide()
	w.insertion_arrow=Node3D.new();w.model.add_child(w.insertion_arrow);w.insertion_arrow.hide()
	w.charging_arrow=Node3D.new();w.model.add_child(w.charging_arrow);w.charging_arrow.hide()
	w.ammo_label=Label3D.new();w.ammo_label.font_size=28;w.ammo_label.pixel_size=.00065;w.ammo_label.position=Vector3(.048,.035,-.08);w.ammo_label.rotation.y=PI*.5;w.model.add_child(w.ammo_label)
	w.muzzle_flash=w._rod(Vector3(0,.045,-.465),Vector3(0,.045,-.52),.015,w._material(Color(1,.65,.16),0,.5,3),5)
	w.muzzle_flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;w.muzzle_flash.hide()
	# Keep the existing 35m sight datum without overlaying a second sight mesh.
	w.sight_rear=Marker3D.new();w.sight_rear.name="RearReference";w.sight_rear.position=Vector3(0,.14,.03);w.model.add_child(w.sight_rear)
	w.sight_front=Marker3D.new();w.sight_front.name="FrontReference";w.sight_front.position=Vector3(0,.14+(.045-.14)*(.03+.393)/(35.0+.03),-.393);w.model.add_child(w.sight_front)
	w._build_debris_pool()
	for i in range(w.CASING_POOL_SIZE,w._debris.size()):
		w._debris[i].mesh=detached_mesh;w._debris[i].material_override=null
