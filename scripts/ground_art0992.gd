extends RefCounted
## A model-only copy must not inherit held reload guidance or offered ammunition.
static func remove_copy(source:Node3D,copy:Node3D,node:Node)->void:
	if not is_instance_valid(node) or not source.model.is_ancestor_of(node):return
	var counterpart:Node=copy.get_node_or_null(source.model.get_path_to(node))
	if counterpart!=null:counterpart.get_parent().remove_child(counterpart);counterpart.free()
static func prepare(source:Node3D,copy:Node3D)->void:
	for key in ["guide","insertion_arrow","charging_arrow","reload_arrow","swipe_arrow","rocket_arrow","hip_source","loose_magazine","shell_offer","shell_pair","shell_pack","offered","offered_box","held_box","open_contact_cue","chamber_contact_cue","close_contact_cue"]:
		if key in source:remove_copy(source,copy,source.get(key))
	if str(source.get_meta("reference_id",""))=="magnum":
		for cartridge in source.cartridges:remove_copy(source,copy,cartridge)
	if str(source.get_meta("reference_id",""))=="m60":
		var box:Node3D=copy.get_node_or_null(source.model.get_path_to(source.belt_box))
		if box!=null:box.position=source.get_box_seat();box.show()
		var cover:Node3D=copy.get_node_or_null(source.model.get_path_to(source.cover))
		if cover!=null:cover.rotation.x=0
		var belt:Node3D=copy.get_node_or_null(source.model.get_path_to(source.belt))
		if belt!=null:belt.position.x=source.get_meta("m60_donor_delta_088",Vector3.ZERO).x*source.feed_direction()
