extends Node
## Input arbitration only: placement geometry lives in field_builder.gd.
var actor: Node
var rack: Node
var builder: Node
var game: Node
var _desktop_cancel := false
var team_marks:Node3D
var _build_hand:XRController3D
func setup(player: Node, weapons: Node, construction: Node, campaign: Node) -> void:
	actor = player
	rack = weapons
	builder = construction
	game = campaign
	team_marks=load("res://scripts/team_marks.gd").new();add_child(team_marks);team_marks.setup(actor,rack,game)
	builder.input_eligible=eligible
	process_physics_priority = 90
func eligible() -> bool:
	if actor.get_meta("tactical_map1000",false):return false
	if not actor.input_enabled or game.paused or game.dead or game.complete: return false
	if game.field_menu != null and game.field_menu.is_open: return false
	if not rack.is_holstered or rack.is_selecting: return false
	if rack.reload_state not in ["ready", "needs_mag"]: return false
	if actor.mantling or actor.head_obstructed: return false
	if not rack.weapons.is_empty() and rack.weapons[rack.selected]._rack_grabbed: return false
	if actor.xr_enabled:
		actor.update_objective_grips()
		if _free_build_hand()==null:return false
	return true
func _hand_free(hand:XRController3D)->bool:
	if hand==null or not actor.is_hand_input_ready(hand) or actor.is_hand_grip_reserved(hand):return false
	if actor._grabs.has(hand):return false
	if hand==actor.left_hand and actor.climbing_left:return false
	if hand==actor.right_hand and actor.climbing_right:return false
	return not actor._hand_holds_item(hand) and not actor._reload_claims_hand(hand)
func _free_build_hand()->XRController3D:
	# Pin the preview owner until release/cancel; never steal a climbing anchor.
	if builder.is_active():return _build_hand if _hand_free(_build_hand) else null
	# Either free hand may initiate. A simultaneous press prefers weapon hand.
	for hand in [actor.get_weapon_hand(),actor.get_support_hand()]:
		if _hand_free(hand) and hand.get_float("trigger")>.55:return hand
	for hand in [actor.get_weapon_hand(),actor.get_support_hand()]:
		if _hand_free(hand):return hand
	return null
func sample() -> Dictionary:
	var pose: Transform3D = actor.get_view_camera().global_transform
	var trigger := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var cycle := false
	var cancel := _desktop_cancel
	if actor.xr_enabled:
		var hand = _free_build_hand()
		if hand==null:return {"trigger":false,"eligible":false,"tracking":false}
		_build_hand=hand
		pose = rack.weapons[0].corrected_grip_transform(hand.global_transform) if rack.weapons[0].has_method("corrected_grip_transform") else hand.global_transform*Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3.ZERO)
		trigger = hand.get_float("trigger") > 0.55
		cycle = false # Geometry selects the grid face; B marks.
		cancel = hand.is_button_pressed("ax_button")
	return {"trigger": trigger, "cycle": cycle, "cancel": cancel, "eligible": eligible(), "tracking": actor.tracking_available, "origin": pose.origin, "direction": -pose.basis.z, "head": actor.get_view_camera().global_position}
func _physics_process(_delta: float) -> void:
	if actor == null: return
	builder.tick_input(sample())
	_desktop_cancel = false
func _unhandled_input(event: InputEvent) -> void:
	if actor == null or actor.xr_enabled or not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_V and actor.input_enabled and not game.paused and (game.field_menu == null or not game.field_menu.is_open) and rack.can_switch():
		rack.set_holstered(not rack.is_holstered)
		_desktop_cancel = true
	elif event.physical_keycode == KEY_ESCAPE:
		_desktop_cancel = true

var status: Label3D
func _ready() -> void:
	status = Label3D.new()
	status.font_size = 32
	status.pixel_size = 0.0015
	status.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	status.no_depth_test = false
	add_child(status)
func _process(_delta: float) -> void:
	if builder == null or status == null: return
	status.visible = false # Preview geometry and lightning are the placement cue.
	if not status.visible: return
	status.global_position = builder.preview.global_position + Vector3.UP * 1.5
	var action: String = "RELEASE TRIGGER: PLACE" if builder.preview_valid else builder.invalid_reason.replace("_", " ").to_upper()
	var shape_name:String={"wall":"VERTICAL WALL","floor":"HORIZONTAL FLOOR"}[builder.kinds[builder.piece_index]]
	status.text = "%s  /  %d CHARGES\n%s\n%s" % [shape_name, builder.charges, action, "A/X: CANCEL   B: MARK" if actor.xr_enabled else "V: DRAW/CANCEL   B: MARK"]
