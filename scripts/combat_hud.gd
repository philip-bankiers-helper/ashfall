extends Node3D

# Three thin meters and short lived bottom-view numeric damage, with no panel.
const MAX_METER := 100.0
const HIT_DURATION := 1.0
const BAR_WIDTH := 0.30
const BAR_HEIGHT := 0.006
const SPRINT_Y := -0.440
const SHIELD_Y := -0.451
const HEALTH_Y := -0.462

var reference_hud:Node3D
var style:="reference"
var actor: Node3D
var game: Node
var camera: Camera3D
var health_fill: MeshInstance3D
var shield_fill: MeshInstance3D
var sprint_fill: MeshInstance3D
var hud_size := 1.0
var outgoing_number: Label3D
var incoming_number: Label3D
var outgoing_remaining := 0.0
var incoming_remaining := 0.0
var outgoing_amount := 0.0
var incoming_amount := 0.0
@export var incoming_numbers_enabled := true # Authored near-bottom placement; reference/headset match remains unverified.
var _outgoing_target := 0
var damage_numbers0992:Node3D
const NUMBER_SECONDS := 1.15

func set_hud_size(value: float) -> void:
	hud_size = clampf(value, .65, 1.75) if is_finite(value) else 1.0
	for child in get_children():
		if child.has_meta("meter_y"):
			child.scale = Vector3(hud_size, hud_size, 1)
			child.position.y = SHIELD_Y + (float(child.get_meta("meter_y")) - SHIELD_Y) * hud_size
			if child.has_meta("meter_x"):child.position.x=float(child.get_meta("meter_x"))*hud_size
	refresh(0.0)
var incoming_fire:Node3D
var hit_arrow: MeshInstance3D
var hit_material: StandardMaterial3D
var hit_source := Vector3.ZERO
var hit_remaining := 0.0

func setup(player: Node3D, game_node: Node) -> void:
	process_priority=110
	actor = player
	game = game_node
	camera = actor.get_view_camera()
	reparent(camera, false)
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	damage_numbers0992=preload("res://scripts/damage_numbers0992.gd").new();game.add_child(damage_numbers0992);damage_numbers0992.setup(actor)
	_build()
	reference_hud=preload("res://scripts/reference_hud_090.gd").new();add_child(reference_hud);reference_hud.setup(game)
	refresh(0.0)

func _build() -> void:
	for y in [SPRINT_Y, SHIELD_Y, HEALTH_Y]:
		_quad("MeterTrack", Vector2(BAR_WIDTH, BAR_HEIGHT), Vector3(0, y, -0.803), Color(0.06, 0.09, 0.10, 0.85))
	sprint_fill = _quad("SprintFill", Vector2(BAR_WIDTH, BAR_HEIGHT), Vector3(0, SPRINT_Y, -0.800), Color(0.93, 0.82, 0.35))
	shield_fill = _quad("ShieldFill", Vector2(BAR_WIDTH, BAR_HEIGHT), Vector3(0, SHIELD_Y, -0.800), Color(0.28, 0.80, 0.98))
	health_fill = _quad("HealthFill", Vector2(BAR_WIDTH, BAR_HEIGHT), Vector3(0, HEALTH_Y, -0.800), Color(0.98, 0.39, 0.32))
	incoming_fire=load("res://scripts/incoming_fire.gd").new()
	incoming_fire.name="IncomingFireChains"
	add_child(incoming_fire)
	incoming_fire.setup(camera)
	hit_arrow=incoming_fire.chains[0]
	hit_material=incoming_fire.materials[0]
	outgoing_number = _label("", Vector3(.18,-.458,-.8), Color(1,.9,.52))
	outgoing_number.name="OutgoingDamageNumber"
	incoming_number = _label("", Vector3(-.18,-.458,-.8), Color(1,.3,.22))
	incoming_number.name="IncomingDamageNumber"
	incoming_number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	for label in [outgoing_number,incoming_number]:
		label.set_meta("meter_y",label.position.y);label.set_meta("meter_x",label.position.x);label.hide()
func _material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = tint
	return material

func _quad(node_name: String, size: Vector2, at: Vector3, tint: Color) -> MeshInstance3D:
	var rect := MeshInstance3D.new()
	rect.layers=1<<19
	rect.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = size
	rect.mesh = mesh
	rect.material_override = _material(tint)
	rect.position = at
	rect.set_meta("meter_y", at.y)
	add_child(rect)
	return rect

func _label(words: String, at: Vector3, tint: Color) -> Label3D:
	var label := Label3D.new()
	label.layers=1<<19
	label.text = words
	label.font_size = 28
	label.pixel_size = 0.0011
	label.outline_size = 5
	label.no_depth_test = false
	label.shaded = false
	label.modulate = tint
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = at
	add_child(label)
	return label

func notify_damage(source_world: Vector3) -> void:
	if not source_world.is_finite():return
	hit_source = source_world
	if incoming_fire:incoming_fire.notify_damage(source_world)
	hit_remaining = HIT_DURATION
	refresh(0.0)

func clear_damage_indicator() -> void:
	hit_remaining = 0.0
	outgoing_remaining=0;incoming_remaining=0;outgoing_amount=0;incoming_amount=0
	if damage_numbers0992:damage_numbers0992.clear()
	if outgoing_number:outgoing_number.hide()
	if incoming_number:incoming_number.hide()
	if incoming_fire:incoming_fire.clear()
	if hit_arrow != null:
		hit_arrow.visible = false

func _process(delta: float) -> void:
	refresh(delta)

func refresh(delta: float) -> void:
	if is_instance_valid(camera):
		global_position=camera.global_position
		global_basis=preload("res://scripts/upright_ui.gd").view_basis(camera.global_basis).scaled(Vector3.ONE*2.5) #Same angular HUD at2m, behind held weapons
	if game == null or camera == null or health_fill == null:
		return
	visible = should_show(bool(game.paused), bool(game.dead), bool(game.complete))
	if not visible:
		clear_damage_indicator()
		return
	if reference_hud!=null:
		reference_hud.visible=style=="reference";reference_hud.scale=Vector3(hud_size,hud_size,1);reference_hud.position.y=SHIELD_Y*(1-hud_size);reference_hud.tick_notices(delta);reference_hud.refresh()
	for child in get_children():
		if str(child.name).begins_with("MeterTrack") or child in [health_fill,shield_fill,sprint_fill]:child.visible=style=="simple"
	var health_fraction := meter_fraction(float(game.health))
	var shield_fraction := meter_fraction(float(game.shield))
	_set_fill(health_fill, health_fraction)
	_set_fill(shield_fill, shield_fraction)
	var stamina := float(actor.get("_sprint_stamina"))
	var maximum := maxf(0.01, float(actor.get("sprint_stamina_seconds")))
	_set_fill(sprint_fill, clampf(stamina / maximum, 0.0, 1.0) if stamina >= 0.0 else 1.0)
	hit_remaining = maxf(0.0, hit_remaining - maxf(delta,0))
	incoming_fire.refresh(delta)
	outgoing_remaining=maxf(0,outgoing_remaining-maxf(delta,0))
	incoming_remaining=maxf(0,incoming_remaining-maxf(delta,0))
	if outgoing_number:outgoing_number.visible=outgoing_remaining>0
	if incoming_number:incoming_number.visible=incoming_remaining>0

func notify_outgoing(amount:float,target_id:int=0,shield_hit:bool=false)->void:
	if not is_finite(amount) or amount<=0:return
	outgoing_remaining=0;outgoing_amount=0
	if outgoing_number:outgoing_number.hide()
	var target:=instance_from_id(target_id) as Node3D
	if is_instance_valid(target):damage_numbers0992.emit_hit(amount,target,shield_hit)

func notify_incoming(amount:float)->void:
	if not incoming_numbers_enabled or not is_finite(amount) or amount<=0 or not incoming_number:return
	if incoming_remaining<=0:incoming_amount=0
	incoming_amount+=amount;incoming_remaining=NUMBER_SECONDS
	incoming_number.text="-%d"%maxi(1,roundi(incoming_amount))
	refresh(0)

func _set_fill(fill: MeshInstance3D, fraction: float) -> void:
	fill.scale.x = maxf(0.0001, fraction) * hud_size
	fill.position.x = -BAR_WIDTH * hud_size * (1.0 - fraction) * 0.5

static func should_show(is_paused: bool, is_dead: bool, is_complete: bool) -> bool:
	return not is_paused and not is_dead and not is_complete

static func meter_fraction(amount: float) -> float:
	return clampf(amount / MAX_METER, 0.0, 1.0)

static func bearing_from_view(view: Transform3D, source_world: Vector3) -> float:
	var offset := source_world - view.origin
	offset.y = 0.0
	if offset.length_squared() < 0.000001:
		return 0.0
	var forward := -view.basis.z
	var right := view.basis.x
	forward.y = 0.0
	right.y = 0.0
	return atan2(offset.dot(right.normalized()), offset.dot(forward.normalized()))


