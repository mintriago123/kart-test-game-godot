class_name Node3DBounds
extends RefCounted


static func get_node_aabb(root: Node3D) -> Dictionary:
	if root == null:
		return {"valid": false, "aabb": AABB()}
	var has_bounds := false
	var combined_bounds := AABB()
	var nodes: Array[Node] = [root]
	while not nodes.is_empty():
		var current: Node = nodes.pop_back()
		for child in current.get_children():
			nodes.append(child)
		if not current is MeshInstance3D:
			continue
		var mesh_instance := current as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_bounds := mesh_instance.get_aabb()
		var relative_transform := _get_transform_including_root(
			mesh_instance,
			root
		)
		for x in [local_bounds.position.x, local_bounds.end.x]:
			for y in [local_bounds.position.y, local_bounds.end.y]:
				for z in [local_bounds.position.z, local_bounds.end.z]:
					var corner := relative_transform * Vector3(x, y, z)
					if has_bounds:
						combined_bounds = combined_bounds.expand(corner)
					else:
						combined_bounds = AABB(corner, Vector3.ZERO)
						has_bounds = true
	return {"valid": has_bounds, "aabb": combined_bounds}


static func _get_transform_including_root(
	node: Node3D,
	root: Node3D
) -> Transform3D:
	var relative_transform := node.transform
	var current := node.get_parent() as Node3D
	while current != null:
		relative_transform = current.transform * relative_transform
		if current == root:
			break
		current = current.get_parent() as Node3D
	return relative_transform
