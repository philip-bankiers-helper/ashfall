extends Node3D
## Original procedural impact marks. Fixed pool; only verified static world surfaces.
const CAPACITY:=512
const LIFETIME:=90.0
const FADE_TIME:=10.0
const RIFLE_DIAMETER:=0.085
const PELLET_DIAMETER:=0.045
const SURFACE_OFFSET:=0.003
var marks:Array[MeshInstance3D]=[]
var ages:Array[float]=[]
var sources:Array[WeakRef]=[]
var cursor:=0
var sequence:=0
var paused:=false
var verification:=PhysicsRayQueryParameters3D.new()
var rejected:=0
var accepted:=0

func _ready()->void:
	verification.collision_mask=1|8
	var texture:=_build_texture()
	var quad:=QuadMesh.new()
	quad.size=Vector2.ONE
	for i in range(CAPACITY):
		var mark:=MeshInstance3D.new()
		mark.mesh=quad
		var material:=StandardMaterial3D.new()
		material.albedo_texture=texture
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		# Every impact is independent. Coplanar transparent patches read the
		# opaque world depth but never compete by writing depth against each other.
		material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.roughness=1.0
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		# Dark hole and pale fractured rim remain readable in sun and shadow.
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mark.material_override=material
		mark.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.sorting_offset=float(i)*.000001 # Stable tie-break for identical positions; no surface stacking.
		mark.visible=false
		add_child(mark)
		marks.append(mark);ages.append(-1.0);sources.append(null)

func add_hit(point:Vector3,normal:Vector3,collider:Object,pellet:bool=false)->bool:
	if marks.is_empty() or not point.is_finite() or not normal.is_finite() or normal.length_squared()<0.5:
		rejected+=1;return false
	if not is_instance_valid(collider) or not collider is StaticBody3D or collider.has_method("take_damage") or (collider.collision_layer&(1|8))==0:
		rejected+=1;return false
	if collider.is_in_group("stair_support") or collider.is_in_group("ballistic_proxy_ignore"):
		# Invisible comfort support is not a visible surface for bullet marks.
		rejected+=1;return false
	var excluded:Array[RID]=[]
	for group in ["ballistic_proxy_ignore","stair_support"]:
		for proxy in get_tree().get_nodes_in_group(group):
			if proxy is CollisionObject3D:excluded.append(proxy.get_rid())
	verification.exclude=excluded
	var n:=normal.normalized()
	var helper:=Vector3.RIGHT if absf(n.dot(Vector3.UP))>0.9 else Vector3.UP
	var tangent:=helper.cross(n).normalized()
	var bitangent:=n.cross(tangent).normalized()
	var angle:=float((sequence*137)%360)*PI/180.0
	var surface:=Basis(tangent,bitangent,n)*Basis(Vector3.BACK,angle)
	var diameter:float=(PELLET_DIAMETER if pellet else RIFLE_DIAMETER)*(0.9+float(sequence%5)*0.05)
	# Project a tiny 3x3 patch onto the actual collider. A flat quad's strict
	# 3mm coplanarity test rejected all sampled irregular campaign rock hits.
	# Bounded nine rays and eight triangles allow shallow facet changes, while
	# rejecting edges, other colliders and steep discontinuities.
	var vertices:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	for y in range(3):
		for x in range(3):
			var offset:=Vector3((float(x)/2-.5)*diameter,(float(y)/2-.5)*diameter,0)
			var sample:=point+surface*offset
			verification.from=sample+n*2.0
			verification.to=sample-n*2.0
			var hit:=get_world_3d().direct_space_state.intersect_ray(verification)
			# A small paint stripe may end within the patch. Follow the neighboring
			# static slab instead of rejecting oblique stripe-edge hits or floating
			# the whole patch above it. All nine points still land on real geometry.
			var paint_edge:bool = collider.is_in_group("painted_ballistic_surface") and not hit.is_empty() and hit.collider is StaticBody3D and not hit.collider.has_method("take_damage") and not hit.collider.has_method("hit") and not hit.collider.is_in_group("ballistic_proxy_ignore") and not hit.collider.is_in_group("stair_support") and absf(n.y) > .9
			var edge_fraction:=1.0
			if collider.is_in_group("rendered_ballistic_surface") and not paint_edge and (hit.is_empty() or hit.collider!=collider):
				# Clip the fracture footprint to a narrow rendered rib/plate. A neighbor
				# behind it must not hide the entire bullet hole or float its rim in air.
				verification.from=point+n*2.0;verification.to=point-n*2.0
				var inside_hit:=get_world_3d().direct_space_state.intersect_ray(verification)
				if not inside_hit.is_empty() and inside_hit.collider==collider:
					var inside:=0.0;var outside:=1.0
					for clip_step in 8:
						var fraction:float=(inside+outside)*.5;var candidate:Vector3=point.lerp(sample,fraction)
						verification.from=candidate+n*2.0;verification.to=candidate-n*2.0
						var candidate_hit:=get_world_3d().direct_space_state.intersect_ray(verification)
						if not candidate_hit.is_empty() and candidate_hit.collider==collider and candidate_hit.normal.dot(n)>.7:
							inside=fraction;inside_hit=candidate_hit
						else:outside=fraction
					edge_fraction=inside;hit=inside_hit;sample=point.lerp(sample,inside)
			if hit.is_empty() or (hit.collider!=collider and not paint_edge) or hit.normal.dot(n)<0.7 or hit.position.distance_to(sample)>diameter:
				rejected+=1;return false
			vertices.append(surface.inverse()*(hit.position+hit.normal*SURFACE_OFFSET-point-n*SURFACE_OFFSET)/diameter)
			uvs.append(Vector2(.5+(float(x)/2-.5)*edge_fraction,.5-(float(y)/2-.5)*edge_fraction))
	var indices:=PackedInt32Array()
	for y in range(2):
		for x in range(2):
			var i:=y*3+x
			indices.append_array(PackedInt32Array([i,i+1,i+3,i+1,i+4,i+3]))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	var patch:=ArrayMesh.new()
	patch.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	# No local spacing rejection or merging: global pool/lifetime alone bound marks.
	var mark:=marks[cursor]
	mark.mesh=patch
	mark.global_transform=Transform3D(surface.scaled(Vector3.ONE*diameter),point+n*SURFACE_OFFSET)
	mark.material_override.albedo_color=Color.WHITE
	mark.visible=true
	ages[cursor]=0.0
	sources[cursor]=weakref(collider)
	cursor=(cursor+1)%CAPACITY
	sequence+=1;accepted+=1
	return true

func _process(delta:float)->void:
	if paused:return
	for i in range(CAPACITY):
		if ages[i]<0:continue
		var surface = sources[i].get_ref() if sources[i] != null else null
		if not is_instance_valid(surface) or surface.collision_layer == 0:
			marks[i].visible=false;ages[i]=-1.0;sources[i]=null
			continue
		ages[i]+=maxf(delta,0)
		if ages[i]>=LIFETIME:
			marks[i].visible=false;ages[i]=-1.0
		else:
			marks[i].material_override.albedo_color.a=clampf((LIFETIME-ages[i])/FADE_TIME,0,1)

func set_paused(value:bool)->void:paused=value
func clear_all()->void:
	for i in range(marks.size()):
		marks[i].visible=false;ages[i]=-1.0;sources[i]=null
	cursor=0

static func _build_texture()->ImageTexture:
	var image:=Image.create(64,64,false,Image.FORMAT_RGBA8)
	# Seed-free authored radial fracture silhouette; all variation is deterministic.
	for y in range(64):
		for x in range(64):
			var p:=(Vector2(x,y)-Vector2(31.5,31.5))/32.0
			var radius:=p.length()
			var angle:=atan2(p.y,p.x)
			var edge:=0.67+sin(angle*7)*0.12+sin(angle*13+0.8)*0.07
			var alpha:=clampf((edge-radius)*18,0,1)
			var tone:=0.025 if radius<0.32 else (0.62+0.12*sin(angle*9+radius*15))
			image.set_pixel(x,y,Color(tone,tone*0.94,tone*0.86,alpha))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)







