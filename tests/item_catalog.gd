extends SceneTree

const CATALOG: ItemCatalog = preload("res://items/item_catalog.tres")

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_validity()
	_test_position_bands()
	_test_seeded_draws()
	_test_invalid_catalogs()
	quit(1 if _has_failed else 0)


func _test_catalog_validity() -> void:
	_check(CATALOG.items.size() == 6, "Catalog exposes all six tropical items.")
	_check(CATALOG.validate().is_empty(), "Catalog identifiers and weights are valid.")
	for band_index in ItemCatalog.POSITION_BAND_COUNT:
		var total := 0
		for item in CATALOG.items:
			total += item.position_weights[band_index]
		_check(
			total == ItemCatalog.EXPECTED_WEIGHT_TOTAL,
			"Position band %d sums to 100 percent." % band_index
		)


func _test_position_bands() -> void:
	var all_mappings_match := true
	for racer_count in range(1, 33):
		for position in range(1, racer_count + 1):
			var expected := roundi(
				float(position - 1)
				* 3.0
				/ float(maxi(racer_count - 1, 1))
			)
			all_mappings_match = (
				all_mappings_match
				and ItemCatalog.get_position_band(position, racer_count)
				== expected
			)
	_check(
		all_mappings_match,
		"Every field size from 1 to 32 maps positions to the four bands."
	)


func _test_seeded_draws() -> void:
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 7262026
	second_rng.seed = 7262026
	var sequences_match := true
	for draw_index in 256:
		var racer_count := 2 + draw_index % 15
		var position := 1 + draw_index % racer_count
		var first := CATALOG.draw_item(position, racer_count, first_rng)
		var second := CATALOG.draw_item(position, racer_count, second_rng)
		sequences_match = (
			sequences_match
			and first != null
			and second != null
			and first.id == second.id
		)
	_check(sequences_match, "Seeded catalog draws are deterministic.")


func _test_invalid_catalogs() -> void:
	var duplicate_catalog := ItemCatalog.new()
	duplicate_catalog.items = [
		ItemDefinition.boost(),
		ItemDefinition.boost(),
	]
	_check(
		not duplicate_catalog.validate().is_empty(),
		"Duplicate identifiers invalidate a catalog."
	)
	var broken_weights := ItemDefinition.boost()
	broken_weights.position_weights = PackedInt32Array([99, 99, 99, 99])
	var broken_catalog := ItemCatalog.new()
	broken_catalog.items = [broken_weights]
	_check(
		not broken_catalog.validate().is_empty(),
		"Weight totals other than 100 invalidate a catalog."
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)
