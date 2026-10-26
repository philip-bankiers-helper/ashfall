extends StaticBody3D
## Original reusable target. It never attacks or starts the mission encounter.
signal damaged(amount: float, shield_damage: float, health_damage: float)
const RESET_DELAY := 1.5
var health := 100.0
var shield := 100.0
var total_damage := 0.0
var last_damage := 0.0
var _reset_left := 0.0
var _built := false
var _readout: Label3D

func _ready() -> void:
	add_to_group("practice_targets")
	collision_layer = 4 # Authored damageable bodies; production ballistic mask includes 1|4|8.
	collision_mask = 0
	_build()
	reset_target()

func _build() -> void:
	if _built: return
	_built = true
	var shape := CollisionShape3D.new()
	var torso := BoxShape3D.new();torso.size=Vector3(.58,1.43,.30)
	shape.shape=torso;shape.position.y=.84;add_child(shape)
	var head_shape:=CollisionShape3D.new();head_shape.name="HeadHitbox0991"
	var head_box:=BoxShape3D.new();head_box.size=Vector3(.34,.31,.22)
	head_shape.shape=head_box;head_shape.position=Vector3(0,1.72,0);add_child(head_shape)
	_piece(Vector3(.55,.82,.18),Vector3(0,1.14,0),Color(.14,.23,.28))
	_piece(Vector3(.34,.31,.22),Vector3(0,1.72,0),Color(.3,.78,.87))
	_piece(Vector3(.78,.12,.15),Vector3(0,1.46,0),Color(.16,.28,.33))
	_piece(Vector3(.09,.55,.09),Vector3(0,.36,0),Color(.34,.4,.42))
	_piece(Vector3(.85,.08,.6),Vector3(0,.04,0),Color(.11,.14,.16))
	for i in range(3):
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new(); mesh.inner_radius=.05+i*.047; mesh.outer_radius=.058+i*.047
		ring.mesh=mesh; ring.rotation.x=PI/2; ring.position=Vector3(0,1.15,.097+i*.001)
		var mat := StandardMaterial3D.new(); mat.albedo_color=Color(.98,.47,.13); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override=mat; add_child(ring)
	_readout=Label3D.new(); _readout.name="PracticeReadout"; _readout.position=Vector3(0,2.15,0)
	_readout.font_size=40; _readout.pixel_size=.0025; _readout.outline_size=6
	_readout.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y; add_child(_readout)

func _piece(size:Vector3,at:Vector3,tint:Color)->void:
	var part:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=size; part.mesh=mesh
	var mat:=StandardMaterial3D.new(); mat.albedo_color=tint; mat.roughness=.75
	part.material_override=mat; part.position=at; add_child(part)

func take_damage(amount:float)->void:
	_apply(amount,false)

func hit_zone_at0991(point:Vector3)->String:
	return "head" if AABB(Vector3(-.171,1.564,-.111),Vector3(.342,.312,.222)).has_point(to_local(point)) else "body"

func take_melee_damage(amount:float)->void:
	_apply(amount,true)

func _apply(amount:float,direct_health:bool)->void:
	last_damage=0
	if not is_finite(amount) or amount<=0 or health<=0:return
	var absorbed:=minf(shield,amount) if not direct_health else 0.0
	var lost:=minf(health,amount-absorbed)
	shield-=absorbed; health-=lost; last_damage=absorbed+lost; total_damage+=last_damage
	_reset_left=RESET_DELAY
	damaged.emit(last_damage,absorbed,lost)
	_update_readout()

func reset_target()->void:
	health=100; shield=100; last_damage=0; total_damage=0; _reset_left=0
	_update_readout()

func _process(delta:float)->void:
	if _reset_left<=0:return
	_reset_left=maxf(0,_reset_left-maxf(delta,0))
	if _reset_left<=0:reset_target()

func _update_readout()->void:
	if _readout:_readout.text="PRACTICE TARGET\nSHIELD %d  HEALTH %d\nLAST %d  TOTAL %d"%[roundi(shield),roundi(health),roundi(last_damage),roundi(total_damage)]

func get_hit_feedback()->String:
	return ""
