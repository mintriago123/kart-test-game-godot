@tool
class_name TrackEditorSelection
extends RefCounted

enum Kind {
	NONE,
	ROUTE_POINT,
	ITEM,
	PROP,
	SHORTCUT_MIDPOINT,
}

var kind := Kind.NONE
var point_index := -1
var node_path := NodePath()


static func none() -> TrackEditorSelection:
	return TrackEditorSelection.new()


static func route_point(index: int) -> TrackEditorSelection:
	var selection := TrackEditorSelection.new()
	selection.kind = Kind.ROUTE_POINT
	selection.point_index = index
	selection.node_path = NodePath("MainRoute")
	return selection


static func node(selection_kind: int, path: NodePath) -> TrackEditorSelection:
	var selection := TrackEditorSelection.new()
	selection.kind = selection_kind
	selection.node_path = path
	return selection


func is_empty() -> bool:
	return kind == Kind.NONE


func is_same(other: TrackEditorSelection) -> bool:
	return (
		other != null
		and kind == other.kind
		and point_index == other.point_index
		and node_path == other.node_path
	)


func workflow_step() -> int:
	match kind:
		Kind.ROUTE_POINT:
			return 1
		Kind.SHORTCUT_MIDPOINT:
			return 2
		Kind.ITEM, Kind.PROP:
			return 3
		_:
			return -1
