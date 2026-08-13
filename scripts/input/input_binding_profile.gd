class_name InputBindingProfile
extends Resource

const VERSION := 1
const REQUIRED_ACTIONS := [&"ui_accept", &"ui_cancel", &"pause"]

@export var guid := ""
@export var family: StringName = &"generic"
@export var bindings: Dictionary = {}
@export var version := VERSION

func capture_from_input_map(actions: Array) -> void:
	bindings.clear()
	for action in actions:
		bindings[action] = InputMap.action_get_events(action).duplicate(true)

func apply_to_input_map() -> bool:
	if not is_valid():
		return false
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for event in bindings[action]:
			InputMap.action_add_event(action, event)
	var loop := Engine.get_main_loop() as SceneTree
	var manager := loop.root.get_node_or_null("PromptManager") if loop != null else null
	if manager != null:
		manager.refresh()
	return true

func find_conflict(event: InputEvent, except_action: StringName = &"") -> StringName:
	for action in bindings:
		if action == except_action:
			continue
		for assigned in bindings[action]:
			if (assigned as InputEvent).is_match(event):
				return StringName(action)
	return &""

func assign(action: StringName, event: InputEvent, resolution: StringName = &"replace") -> bool:
	if action in REQUIRED_ACTIONS and event == null:
		return false
	var conflict := find_conflict(event, action)
	if not conflict.is_empty():
		if resolution == &"cancel":
			return false
		if resolution == &"swap":
			var old: Array = bindings.get(action, [])
			bindings[conflict] = old.duplicate(true)
		elif resolution == &"replace":
			bindings[conflict] = []
	bindings[action] = [event]
	return is_valid()

func is_valid() -> bool:
	for action in REQUIRED_ACTIONS:
		if not bindings.has(action) or (bindings[action] as Array).is_empty():
			return false
	return true

func save_to_disk(path: String) -> Error:
	var directory := path.get_base_dir()
	if directory.begins_with("user://"):
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		if error != OK:
			return error
	return ResourceSaver.save(self, path)
