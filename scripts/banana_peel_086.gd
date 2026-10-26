extends RefCounted
## Four independently deforming, double-sided quarter-shells. Length remains .22m.
static func strip_mesh(index:int,amount:float)->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:Array[PackedVector3Array]=[]
	for step in 25:
		var t:=float(step)/24;var ring:=PackedVector3Array()
		# Curve begins flush at the anchored bottom and rolls back through a half turn.
		# Integrating the tangent preserves length and finishes with the tip hanging down.
		var arc:=amount*PI*1.18
		var radial:=.22*(1.0-cos(arc*t))/maxf(arc,.00001) if arc>.00001 else 0.0
		var height:=.22*sin(arc*t)/maxf(arc,.00001) if arc>.00001 else .22*t
		var center:=preload("res://scripts/field_item_models.gd")._banana_center(t)
		var middle:=float(index)*PI*.5+PI*.25
		var away:=Vector3(cos(middle),0,sin(middle))
		for edge in 7:
			var angle:=float(index)*PI*.5+float(edge)/6*PI*.5
			var normal:=Vector3(cos(angle),0,sin(angle))
			var r:=.0255*(.15+.85*pow(sin(PI*t),.45))
			ring.append(Vector3(center.x,-.11+height,0)+away*radial+normal*r)
		rings.append(ring)
	for row in 24:
		for col in 6:
			var quad:Array[Vector3]=[rings[row][col],rings[row][col+1],rings[row+1][col+1],rings[row+1][col]]
			for k in [0,2,1,0,3,2]:surface.add_vertex(quad[k])
	surface.generate_normals();return surface.commit()
static func update(prop:Node3D,count:int,active:bool,start:Vector3,actor:Node3D)->void:
	var cap:=prop.get_node_or_null("Cap") as Node3D
	if cap!=null:cap.hide()
	var holder:=prop.get_node_or_null("FourPeelStrips") as Node3D
	if holder==null:
		holder=Node3D.new();holder.name="FourPeelStrips";prop.add_child(holder)
		for i in 4:
			var part:=MeshInstance3D.new();part.name="Peel%d"%i
			var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.94,.70,.065);mat.roughness=.65;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;part.material_override=mat;holder.add_child(part)
	var partial:=0.0
	if active and count<4 and actor!=null:
		var held:Node3D=prop.get_parent().held_hand if "held_hand" in prop.get_parent() else null
		var other:Node3D=actor.left_hand if held==actor.right_hand else actor.right_hand
		if is_instance_valid(other):partial=clampf((start.y-prop.to_local(other.global_position).y)/.10,0,1)
	for i in 4:
		var amount:=1.0 if i<count else (partial if i==count else 0.0)
		var part:MeshInstance3D=holder.get_child(i)
		if not is_equal_approx(float(part.get_meta("amount",-1.0)),amount):part.mesh=strip_mesh(i,amount);part.set_meta("amount",amount)
