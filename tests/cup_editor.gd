extends SceneTree

var failures := PackedStringArray()


func _init() -> void:
	_test_validation_paths()
	_test_simulation()
	_test_draft_is_not_catalogued()
	_test_editor_layout()
	if failures.is_empty(): print("CUP EDITOR TESTS PASSED")
	else:
		for failure in failures: push_error(failure)
	quit(failures.size())


func _test_validation_paths() -> void:
	var cup := CupDefinition.new()
	cup.medal_thresholds = PackedInt32Array([9, 9, 30])
	var issues := CupEditorValidator.validate(cup)
	_expect(not issues.is_empty(), "An incomplete cup must be rejected.")
	var paths: Array[StringName] = []
	for issue in issues: paths.append(issue.field_path)
	_expect(StringName("tracks") in paths, "Track errors need a navigable field path.")
	_expect(StringName("competition") in paths, "Competition errors need a navigable field path.")
	_expect(StringName("medals") in paths, "Medal errors need a navigable field path.")


func _test_simulation() -> void:
	var catalog := load("res://progression/progression_catalog.tres") as ProgressionCatalog
	var cup := catalog.cups.get_cup(&"tropical")
	var order := PackedStringArray([cup.player_racer.id])
	for racer in cup.opponents: order.append(racer.id)
	var evaluation := CupEvaluator.evaluate(cup, cup.difficulties[0], [order, order, order])
	_expect(evaluation.is_valid(), "A complete three-race simulation must be valid.")
	_expect(evaluation.player_points == cup.scoring_table[0] * 3, "Simulation points are incorrect.")
	_expect(evaluation.medal == UnlockDefinition.GOLD, "Maximum points must award gold.")
	_expect(evaluation.eligible_rewards.size() == 2, "Gold must include every cumulative direct reward configured for the cup.")


func _test_draft_is_not_catalogued() -> void:
	var session := CupEditorSession.new()
	var before := session.catalog.cups.cups.size()
	session.create_cup("Prueba temporal")
	_expect(session.catalog.cups.cups.size() == before, "Creating a draft must not modify CupCatalog.")
	_expect(not session.is_published and session.is_dirty, "A new cup must be a dirty draft.")


func _test_editor_layout() -> void:
	var screen := CupEditorScreen.new()
	root.add_child(screen)
	for size in [Vector2(1280, 720), Vector2(1536, 960), Vector2(1920, 1080)]:
		screen.size = size
		_expect(screen.tabs != null and screen.tabs.get_tab_count() == 6, "The editor must expose six guided steps at %s." % size)
	_expect(screen.reward_options.size() == 3, "The editor exposes one direct reward slot per medal instead of a difficulty grid.")
	_expect(screen.prerequisite_cup_option != null and screen.prerequisite_difficulty_option != null and screen.prerequisite_medal_option != null, "The editor exposes cup, optional difficulty, and medal prerequisites.")
	for node in screen.find_children("*", "Button", true, false):
		_expect(node.custom_minimum_size.y >= 48.0, "Editor buttons must have a 48 px minimum target.")
	screen.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
