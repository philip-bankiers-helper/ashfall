extends RefCounted
## Smooth locomotion proxies are not the visual surface hit by bullets.
static func exclusions(tree: SceneTree, extra: Array = []) -> Array[RID]:
	var result: Array[RID] = []
	for value in extra:
		if typeof(value) == TYPE_RID: result.append(value)
	for group in ["ballistic_proxy_ignore","stair_support"]:
		for node in tree.get_nodes_in_group(group):
			if is_instance_valid(node) and node is CollisionObject3D:result.append(node.get_rid())
	return result

static func create(tree: SceneTree, from: Vector3, to: Vector3, extra: Array = [], mask: int = 1|4|8) -> PhysicsRayQueryParameters3D:
	return PhysicsRayQueryParameters3D.create(from,to,mask,exclusions(tree,extra))
