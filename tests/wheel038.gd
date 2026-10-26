extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var wheel = load("res://scripts/weapon_wheel.gd").new()
	root.add_child(wheel)
	await process_frame
	wheel.set_weapon_icons([])
	check(wheel.find_children("WeaponIcon*", "Sprite3D", false, false).is_empty(), "empty inventory has no weapon icons")
	var baseline_script := GDScript.new()
	baseline_script.source_code = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../../releases/ASHFALL-Controls-036-20261018/scripts/weapon_wheel.gd"))
	check(baseline_script.reload() == OK, "frozen baseline script loads for geometry comparison")
	var baseline = baseline_script.new()
	root.add_child(baseline)
	var guns := []
	for path in ["res://scripts/weapon.gd", "res://scripts/shotgun.gd", "res://scripts/pistol.gd", "res://scripts/burst_carbine.gd", "res://scripts/pump_shotgun.gd"]:
		var gun = load(path).new()
		gun.set_process(false)
		gun.set_physics_process(false)
		root.add_child(gun)
		gun._build_model()
		guns.append(gun)
	baseline.set_weapon_icons(guns.slice(0,2))
	wheel.set_weapon_icons(guns)
	var old_geometry := count_geometry(baseline)
	var new_geometry := count_geometry(wheel)
	check(new_geometry < old_geometry, "geometry reduced from %d to %d instances" % [old_geometry, new_geometry])
	print("WHEEL038 old geometry=", old_geometry, " new geometry=", new_geometry)
	baseline.queue_free()
	for gun in guns: gun.queue_free()
	var meshes := 0
	var sprites := 0
	for child in wheel.get_children():
		if child is MeshInstance3D: meshes += 1
		if child is Sprite3D:
			sprites += 1
			check(child.texture != null and child.texture.get_width() == 256, "flat original icon loaded")
		check(not child is Label3D, "no wheel text node: " + str(child.name))
		check(not str(child.name).begins_with("EmptySlot"), "no empty decoration: " + str(child.name))
		check(not str(child.name).begins_with("WeaponPreview"), "no weapon model duplicate: " + str(child.name))
	check(sprites == 5, "exactly five owned flat weapon sprites")
	wheel.set_weapon_icons(guns)
	var icons := 0
	for child in wheel.get_children():
		if child is Sprite3D: icons += 1
	check(icons == 5, "icon refresh does not accumulate scenes")
	for yaw in [0.0, 0.7, -1.1]:
		var view := Transform3D(Basis(Vector3.UP, yaw), Vector3(1, 1.7, 2))
		var aim := Transform3D(view.basis.rotated(Vector3.RIGHT, 0.12), view.origin + Vector3(0.15, -0.3, 0))
		wheel.open_at(view, aim)
		check(wheel.visible, "open is visible")
		check(wheel.global_position.distance_to(aim.origin - aim.basis.z * 0.85) < 0.001, "center follows opening aim")
		check(absf(wheel.global_basis.x.length() - 1.2) < 0.001, "twenty percent enlargement survives opening transform")
		for slot in range(8):
			var hit: Vector3 = wheel.to_global(wheel.slot_position(slot, 0.22))
			var ray := Transform3D(Basis.looking_at(hit - view.origin, Vector3.UP), view.origin)
			wheel.point(ray)
			check(wheel.highlighted == slot, "real ray selects wedge %d at yaw %.1f" % [slot, yaw])
			check(wheel.point_action() == wheel.SLOT_ACTIONS[slot], "ray action preserved")
		var cancel := Transform3D(Basis.looking_at(wheel.global_position - view.origin, Vector3.UP), view.origin)
		wheel.point(cancel)
		check(wheel.point_action() == "cancel", "center ray cancels")
	print("WHEEL038 geometry meshes=", meshes, " sprites=", sprites)
	wheel.queue_free()
	await process_frame
	await process_frame
	print("WHEEL038 checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func count_geometry(node: Node) -> int:
	var count := 1 if node is GeometryInstance3D else 0
	for child in node.get_children(): count += count_geometry(child)
	return count

