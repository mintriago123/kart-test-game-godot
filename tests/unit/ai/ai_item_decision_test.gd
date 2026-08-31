extends SceneTree

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tuning := AiTuning.defaults()
	var decision := AiItemDecision.new()
	decision.tuning = tuning
	var item := ItemDefinition.new()
	item.id = &"test_item"
	item.type = ItemDefinition.ItemType.BOOST

	decision.per_item_cooldown = {&"test_item": 2.0}
	_check(decision._can_use(item) == false,
		"cannot use item with active cooldown")

	decision.per_item_cooldown = {&"test_item": 0.0}
	_check(decision._can_use(item) == true,
		"can use item with zero cooldown")

	decision.notify_item_used(item, 2.5)
	_check(decision._can_use(item) == false,
		"cooldown applied after use")

	decision.update(1.0)
	_check(decision._can_use(item) == false,
		"cooldown still active after 1s")

	decision.update(2.0)
	_check(decision._can_use(item) == true,
		"cooldown expired after total decay")

	var item_b := ItemDefinition.new()
	item_b.id = &"other_item"
	item_b.type = ItemDefinition.ItemType.SEA_BUBBLE
	decision.per_item_cooldown = {&"test_item": 1.0, &"other_item": 0.5}
	_check(decision._can_use(item) == false,
		"per-item cooldown for test_item still active")
	_check(decision._can_use(item_b) == false,
		"per-item cooldown for other_item still active")

	if _failures == 0:
		print("AiItemDecision tests passed.")
		quit(0)
	else:
		push_error("%d AiItemDecision tests failed." % _failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures += 1
	push_error("FAIL: " + message)
